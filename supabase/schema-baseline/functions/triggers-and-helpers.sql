-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- public.assign_uniform_order_number() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.assign_uniform_order_number()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.order_number is null or btrim(new.order_number) = '' then
    new.order_number := public.next_uniform_order_number(coalesce(new.created_at::date, current_date));
  end if;
  return new;
end;
$function$;
ALTER FUNCTION public.assign_uniform_order_number() OWNER TO "postgres";

-- public.guard_profile_fields() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.guard_profile_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if (select public.my_role()) not in ('admin','owner') then
    if new.role         is distinct from old.role
       or new.is_active     is distinct from old.is_active
       or new.project_scope is distinct from old.project_scope then
      raise exception
        'Only an administrator can change role, is_active or project_scope';
    end if;
  end if;
  return new;
end;
$function$;
ALTER FUNCTION public.guard_profile_fields() OWNER TO "postgres";

-- public.handle_new_user() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'viewer'
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;
ALTER FUNCTION public.handle_new_user() OWNER TO "postgres";

-- public.log_employee_join_date_change() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.log_employee_join_date_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old_date date;
  v_new_date date;
begin
  if old.join_date is distinct from new.join_date then
    begin
      v_old_date := nullif(btrim(old.join_date), '')::date;
      v_new_date := nullif(btrim(new.join_date), '')::date;
    exception
      when invalid_datetime_format or datetime_field_overflow then
        raise exception using
          errcode = '22007',
          message = format(
            'Invalid Join Date. Expected YYYY-MM-DD. Old value: %s, new value: %s',
            coalesce(old.join_date, 'NULL'),
            coalesce(new.join_date, 'NULL')
          );
    end;

    insert into public.employee_join_date_history (
      employee_id,
      old_join_date,
      new_join_date,
      changed_by,
      changed_at
    )
    values (
      new.id,
      v_old_date,
      v_new_date,
      auth.uid(),
      now()
    );
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.log_employee_join_date_change() OWNER TO "postgres";

-- public.log_project_meeting_scope_change() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.log_project_meeting_scope_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.meeting_attendance_enabled is distinct from new.meeting_attendance_enabled then
    insert into public.project_meeting_scope_history (
      project_record_id,
      previous_enabled,
      new_enabled,
      changed_by,
      changed_at
    )
    values (
      new.id::text,
      old.meeting_attendance_enabled,
      new.meeting_attendance_enabled,
      auth.uid(),
      now()
    );
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.log_project_meeting_scope_change() OWNER TO "postgres";

-- public.mghrm_is_employee_inactive(text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.mghrm_is_employee_inactive(p_status text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select lower(btrim(coalesce(p_status, ''))) in ('inactive', 'exited');
$function$;
ALTER FUNCTION public.mghrm_is_employee_inactive(text) OWNER TO "postgres";

-- public.mghrm_normalize_employee_status() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.mghrm_normalize_employee_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if lower(btrim(coalesce(new.status, ''))) = 'exited' then
    new.status := 'Inactive';
  elsif lower(btrim(coalesce(new.status, ''))) = 'active' then
    new.status := 'Active';
  elsif lower(btrim(coalesce(new.status, ''))) = 'inactive' then
    new.status := 'Inactive';
  end if;
  return new;
end;
$function$;
ALTER FUNCTION public.mghrm_normalize_employee_status() OWNER TO "postgres";

-- public.mghrm_resolve_transfers_for_inactive_employee() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.mghrm_resolve_transfers_for_inactive_employee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if lower(btrim(coalesce(new.status, ''))) = 'inactive'
     and lower(btrim(coalesce(old.status, ''))) <> 'inactive' then
    update public.transfers
       set status = 'Cancelled',
           cancelled_at = coalesce(cancelled_at, now()),
           cancelled_by = coalesce(cancelled_by, auth.uid()),
           cancellation_reason = coalesce(
             nullif(btrim(cancellation_reason), ''),
             case
               when new.exit_date is not null or nullif(btrim(coalesce(new.exit_reason, '')), '') is not null
                 then 'Employee became Inactive through Exit workflow: ' || coalesce(nullif(btrim(new.exit_reason), ''), 'Exit completed')
               else 'Employee became Inactive'
             end
           ),
           updated_at = now()
     where employee_sys_id = new.id
       and deleted_at is null
       and status in ('Draft', 'Scheduled', 'Joining Pending', 'Not Joined');
  end if;
  return new;
end;
$function$;
ALTER FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() OWNER TO "postgres";

-- public.mghrm_touch_updated_at() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.mghrm_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end $function$;
ALTER FUNCTION public.mghrm_touch_updated_at() OWNER TO "postgres";

-- public.my_role() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select p.role from public.profiles p
      where p.id = auth.uid() and p.is_active = true),
    'none'
  );
$function$;
ALTER FUNCTION public.my_role() OWNER TO "postgres";

-- public.notification_apply_lifecycle() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.notification_apply_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now timestamp with time zone := now();
begin
  -- ----------------------------------------------------------
  -- Terminal notifications cannot return to an active state.
  -- Any future administrative correction should use a separate,
  -- explicit server-controlled function.
  -- ----------------------------------------------------------

  if tg_op = 'UPDATE'
     and old.status in (
       'Completed',
       'Dismissed',
       'Expired',
       'Cancelled'
     )
     and new.status is distinct from old.status then

    raise exception using
      errcode = '23514',
      message = format(
        'Notification cannot transition from terminal status %s to %s',
        old.status,
        new.status
      );
  end if;

  -- ----------------------------------------------------------
  -- Delivered
  -- ----------------------------------------------------------

  if new.status = 'Delivered' then
    new.first_delivered_at :=
      coalesce(
        new.first_delivered_at,
        case
          when tg_op = 'UPDATE'
            then old.first_delivered_at
          else null
        end,
        v_now
      );

    new.last_delivered_at := v_now;
  end if;

  -- ----------------------------------------------------------
  -- Read
  -- ----------------------------------------------------------

  if new.status = 'Read' then
    new.read_at :=
      coalesce(
        new.read_at,
        case
          when tg_op = 'UPDATE'
            then old.read_at
          else null
        end,
        v_now
      );
  end if;

  -- ----------------------------------------------------------
  -- Actioned
  -- Opening an actionable notification also counts as read.
  -- ----------------------------------------------------------

  if new.status = 'Actioned' then
    new.actioned_at :=
      coalesce(
        new.actioned_at,
        case
          when tg_op = 'UPDATE'
            then old.actioned_at
          else null
        end,
        v_now
      );

    new.read_at :=
      coalesce(
        new.read_at,
        case
          when tg_op = 'UPDATE'
            then old.read_at
          else null
        end,
        v_now
      );
  end if;

  -- ----------------------------------------------------------
  -- Snoozed
  -- ----------------------------------------------------------

  if new.status = 'Snoozed' then
    if new.snoozed_until is null then
      raise exception using
        errcode = '23514',
        message =
          'snoozed_until is required when notification status is Snoozed';
    end if;

    if new.snoozed_until <= v_now then
      raise exception using
        errcode = '23514',
        message =
          'snoozed_until must be in the future';
    end if;

    -- The notification becomes eligible again at snoozed_until.
    new.scheduled_for := new.snoozed_until;
  end if;

  -- Clear obsolete snooze state after leaving Snoozed.
  if tg_op = 'UPDATE'
     and old.status = 'Snoozed'
     and new.status is distinct from 'Snoozed' then

    new.snoozed_until := null;
  end if;

  -- ----------------------------------------------------------
  -- Completed
  -- Completion also counts as read and actioned.
  -- ----------------------------------------------------------

  if new.status = 'Completed' then
    new.completed_at :=
      coalesce(
        new.completed_at,
        case
          when tg_op = 'UPDATE'
            then old.completed_at
          else null
        end,
        v_now
      );

    new.actioned_at :=
      coalesce(
        new.actioned_at,
        case
          when tg_op = 'UPDATE'
            then old.actioned_at
          else null
        end,
        v_now
      );

    new.read_at :=
      coalesce(
        new.read_at,
        case
          when tg_op = 'UPDATE'
            then old.read_at
          else null
        end,
        v_now
      );

    new.snoozed_until := null;
  end if;

  -- ----------------------------------------------------------
  -- Dismissed
  -- Dismissal counts as read, but not as workflow completion.
  -- ----------------------------------------------------------

  if new.status = 'Dismissed' then
    new.dismissed_at :=
      coalesce(
        new.dismissed_at,
        case
          when tg_op = 'UPDATE'
            then old.dismissed_at
          else null
        end,
        v_now
      );

    new.read_at :=
      coalesce(
        new.read_at,
        case
          when tg_op = 'UPDATE'
            then old.read_at
          else null
        end,
        v_now
      );

    new.snoozed_until := null;
  end if;

  -- ----------------------------------------------------------
  -- Expired or Cancelled
  -- ----------------------------------------------------------

  if new.status in (
    'Expired',
    'Cancelled'
  ) then
    new.snoozed_until := null;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.notification_apply_lifecycle() OWNER TO "postgres";
COMMENT ON FUNCTION public.notification_apply_lifecycle() IS 'Maintains notification lifecycle timestamps, validates snooze state and protects terminal notifications.';

-- public.notification_event_apply_lifecycle() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.notification_event_apply_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- Processed, Ignored and Cancelled are terminal states.
  if tg_op = 'UPDATE'
     and old.processing_status in (
       'Processed',
       'Ignored',
       'Cancelled'
     )
     and new.processing_status is distinct from
       old.processing_status then

    raise exception using
      errcode = '23514',
      message = format(
        'Notification event cannot transition from terminal status %s to %s',
        old.processing_status,
        new.processing_status
      );
  end if;

  if new.processing_status = 'Processed' then
    new.processed_at :=
      coalesce(
        new.processed_at,
        case
          when tg_op = 'UPDATE'
            then old.processed_at
          else null
        end,
        now()
      );

    new.processing_error := null;
  end if;

  if new.processing_status = 'Ignored' then
    new.processed_at :=
      coalesce(
        new.processed_at,
        case
          when tg_op = 'UPDATE'
            then old.processed_at
          else null
        end,
        now()
      );
  end if;

  if new.processing_status = 'Failed'
     and nullif(
       btrim(
         coalesce(
           new.processing_error,
           ''
         )
       ),
       ''
     ) is null then

    raise exception using
      errcode = '23514',
      message =
        'processing_error is required when event status is Failed';
  end if;

  if new.processing_status <> 'Failed' then
    new.processing_error := null;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.notification_event_apply_lifecycle() OWNER TO "postgres";
COMMENT ON FUNCTION public.notification_event_apply_lifecycle() IS 'Maintains notification-event processing timestamps, errors and terminal-state protection.';

-- public.notification_job_apply_lifecycle() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.notification_job_apply_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- Completed, Cancelled and DeadLetter jobs are terminal.
  if tg_op = 'UPDATE'
     and old.job_status in (
       'Completed',
       'Cancelled',
       'DeadLetter'
     )
     and new.job_status is distinct from old.job_status then

    raise exception using
      errcode = '23514',
      message = format(
        'Notification job cannot transition from terminal status %s to %s',
        old.job_status,
        new.job_status
      );
  end if;

  -- Processing jobs require a processor identity and lock.
  if new.job_status = 'Processing' then
    new.locked_at :=
      coalesce(
        new.locked_at,
        now()
      );

    new.started_at :=
      coalesce(
        new.started_at,
        now()
      );

    if nullif(
      btrim(
        coalesce(
          new.locked_by,
          ''
        )
      ),
      ''
    ) is null then

      raise exception using
        errcode = '23514',
        message =
          'locked_by is required when job status is Processing';
    end if;
  end if;

  -- Completed jobs receive completion timestamp and release lock.
  if new.job_status = 'Completed' then
    new.completed_at :=
      coalesce(
        new.completed_at,
        case
          when tg_op = 'UPDATE'
            then old.completed_at
          else null
        end,
        now()
      );

    new.failed_at := null;
    new.last_error := null;
    new.locked_at := null;
    new.locked_by := null;
  end if;

  -- Failed jobs require diagnostics and release the active lock.
  if new.job_status = 'Failed' then
    new.failed_at :=
      coalesce(
        new.failed_at,
        now()
      );

    if nullif(
      btrim(
        coalesce(
          new.last_error,
          ''
        )
      ),
      ''
    ) is null then

      raise exception using
        errcode = '23514',
        message =
          'last_error is required when job status is Failed';
    end if;

    new.locked_at := null;
    new.locked_by := null;
  end if;

  -- Dead-letter jobs also require diagnostics.
  if new.job_status = 'DeadLetter' then
    new.failed_at :=
      coalesce(
        new.failed_at,
        now()
      );

    if nullif(
      btrim(
        coalesce(
          new.last_error,
          ''
        )
      ),
      ''
    ) is null then

      raise exception using
        errcode = '23514',
        message =
          'last_error is required when job status is DeadLetter';
    end if;

    new.locked_at := null;
    new.locked_by := null;
  end if;

  -- Cancelled jobs release processing locks.
  if new.job_status = 'Cancelled' then
    new.locked_at := null;
    new.locked_by := null;
  end if;

  -- Pending retry state must not retain an active lock.
  if new.job_status = 'Pending' then
    new.locked_at := null;
    new.locked_by := null;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.notification_job_apply_lifecycle() OWNER TO "postgres";
COMMENT ON FUNCTION public.notification_job_apply_lifecycle() IS 'Maintains notification-job locks, timestamps, diagnostics and terminal-state protection.';

-- public.notification_touch_updated_at() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.notification_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;
ALTER FUNCTION public.notification_touch_updated_at() OWNER TO "postgres";
COMMENT ON FUNCTION public.notification_touch_updated_at() IS 'Maintains updated_at on notification-system records before update.';

-- public.prevent_duplicate_active_uniform_employee() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.prevent_duplicate_active_uniform_employee()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.is_active and exists (
    select 1
    from public.uniform_order_employees uoe
    join public.uniform_supply_orders uo on uo.id = uoe.order_id
    where uoe.employee_id = new.employee_id
      and uoe.is_active = true
      and uoe.id <> coalesce(new.id, 0)
      and uo.status not in ('Completed', 'Cancelled')
  ) then
    raise exception 'Employee is already included in another active uniform order.';
  end if;
  return new;
end;
$function$;
ALTER FUNCTION public.prevent_duplicate_active_uniform_employee() OWNER TO "postgres";

-- public.protect_terminal_uniform_delivery_items() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.protect_terminal_uniform_delivery_items()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_parent_id bigint;
  v_status text;
begin
  v_parent_id := case when tg_op = 'DELETE' then old.delivery_id else new.delivery_id end;

  select o.status into v_status
  from public.uniform_deliveries d
  join public.uniform_supply_orders o on o.id = d.order_id
  where d.id = v_parent_id;

  if v_status in ('Completed', 'Cancelled') then
    raise exception 'Delivery items of a % uniform order are read-only.', lower(v_status);
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;
ALTER FUNCTION public.protect_terminal_uniform_delivery_items() OWNER TO "postgres";

-- public.protect_terminal_uniform_employee_items() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.protect_terminal_uniform_employee_items()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_parent_id bigint;
  v_status text;
begin
  v_parent_id := case when tg_op = 'DELETE' then old.order_employee_id else new.order_employee_id end;

  select o.status into v_status
  from public.uniform_order_employees e
  join public.uniform_supply_orders o on o.id = e.order_id
  where e.id = v_parent_id;

  if v_status in ('Completed', 'Cancelled') then
    raise exception 'Item requirements of a % uniform order are read-only.', lower(v_status);
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;
ALTER FUNCTION public.protect_terminal_uniform_employee_items() OWNER TO "postgres";

-- public.protect_terminal_uniform_order_children() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.protect_terminal_uniform_order_children()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order_id bigint;
  v_status text;
begin
  v_order_id := case
    when tg_op = 'DELETE' then old.order_id
    else new.order_id
  end;

  select status into v_status
  from public.uniform_supply_orders
  where id = v_order_id;

  if v_status in ('Completed', 'Cancelled') then
    raise exception 'Child records of a % uniform order are read-only.', lower(v_status);
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;
ALTER FUNCTION public.protect_terminal_uniform_order_children() OWNER TO "postgres";

-- public.protect_uniform_order_integrity() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.protect_uniform_order_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.status in ('Completed', 'Cancelled') and new is distinct from old then
    raise exception 'A % uniform order is read-only.', lower(old.status);
  end if;

  if old.requisition_approved_at is not null
     and new.approved_sets is distinct from old.approved_sets then
    raise exception 'Approved set quantity cannot be changed after requisition approval.';
  end if;

  if old.order_number is distinct from new.order_number then
    raise exception 'Uniform order number cannot be changed.';
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.protect_uniform_order_integrity() OWNER TO "postgres";

-- public.push_subscription_apply_lifecycle() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.push_subscription_apply_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- A granted and active subscription cannot remain revoked.
  if new.is_active = true
     and new.permission_state = 'granted' then

    new.revoked_at := null;
  end if;

  -- Explicitly revoked or denied subscriptions become inactive.
  if new.permission_state in (
    'revoked',
    'denied',
    'unsupported'
  ) then
    new.is_active := false;

    new.revoked_at :=
      coalesce(
        new.revoked_at,
        case
          when tg_op = 'UPDATE'
            then old.revoked_at
          else null
        end,
        now()
      );
  end if;

  -- Inactive subscriptions receive a revocation timestamp.
  if new.is_active = false then
    new.revoked_at :=
      coalesce(
        new.revoked_at,
        case
          when tg_op = 'UPDATE'
            then old.revoked_at
          else null
        end,
        now()
      );
  end if;

  -- A successful delivery resets consecutive failure state.
  if tg_op = 'UPDATE'
     and new.last_success_at is distinct from
       old.last_success_at
     and new.last_success_at is not null then

    new.failure_count := 0;
  end if;

  -- Failure timestamps require a positive failure count.
  if new.last_failure_at is not null
     and new.failure_count < 1 then

    new.failure_count := 1;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.push_subscription_apply_lifecycle() OWNER TO "postgres";
COMMENT ON FUNCTION public.push_subscription_apply_lifecycle() IS 'Maintains push-subscription active, revoked and delivery-health state.';

-- public.set_updated_at() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;
ALTER FUNCTION public.set_updated_at() OWNER TO "postgres";

-- public.validate_uniform_delivery_bill() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.validate_uniform_delivery_bill()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order_id bigint;
  v_delivery_date date;
begin
  select order_id, delivery_date
    into v_order_id, v_delivery_date
  from public.uniform_deliveries
  where id = new.delivery_id;

  if v_order_id is null then
    raise exception 'Delivery record does not exist.';
  end if;

  if new.order_id <> v_order_id then
    raise exception 'Bill order does not match the selected delivery.';
  end if;

  if new.submission_date is null then
    new.submission_date := v_delivery_date;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.validate_uniform_delivery_bill() OWNER TO "postgres";

-- public.validate_uniform_order_status_change() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.validate_uniform_order_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_assigned bigint := 0;
  v_postponed bigint := 0;
  v_zero_set_without_items bigint := 0;
  v_open_issues bigint := 0;
  v_unpaid_bills bigint := 0;
  v_delivery_without_bill bigint := 0;
  v_deliveries bigint := 0;
begin
  if new.status = old.status then
    return new;
  end if;

  if new.status in (
    'Items Finalized','Requirements Submitted','Assigned to Supplier',
    'In Production','Ready for Delivery','Partially Delivered','Delivered','Completed'
  ) then
    select
      coalesce(sum(case when e.is_active then e.set_quantity else 0 end), 0),
      count(*) filter (
        where e.is_active = true
          and e.set_quantity = 0
          and not exists (
            select 1 from public.uniform_order_employee_items i
            where i.order_employee_id = e.id
          )
      )
    into v_assigned, v_zero_set_without_items
    from public.uniform_order_employees e
    where e.order_id = new.id;

    select coalesce(sum(p.set_quantity), 0)
      into v_postponed
    from public.uniform_order_postponements p
    where p.order_id = new.id
      and p.status in ('Open','Partially Activated');

    if v_assigned + v_postponed <> new.approved_sets then
      raise exception 'Assigned sets plus postponed sets must equal the approved set quantity.';
    end if;

    if v_zero_set_without_items > 0 then
      raise exception 'An employee with zero sets must have at least one additional item.';
    end if;
  end if;

  if new.status in (
    'Requirements Submitted','Assigned to Supplier','In Production','Ready for Delivery',
    'Partially Delivered','Delivered','Completed'
  ) and not exists (
    select 1 from public.uniform_requirement_reports r
    where r.order_id = new.id and r.is_current = true
  ) then
    raise exception 'A current requirement report is required before supplier assignment.';
  end if;

  if new.status in ('Partially Delivered','Delivered','Completed') then
    select count(*) into v_deliveries
    from public.uniform_deliveries d
    where d.order_id = new.id and d.status <> 'Cancelled';

    if v_deliveries = 0 then
      raise exception 'At least one delivery is required for this status.';
    end if;

    select count(*) into v_delivery_without_bill
    from public.uniform_deliveries d
    left join public.uniform_delivery_bills b on b.delivery_id = d.id
    where d.order_id = new.id
      and d.status <> 'Cancelled'
      and b.id is null;

    if v_delivery_without_bill > 0 then
      raise exception 'Every delivery must have a bill or challan.';
    end if;
  end if;

  if new.status = 'Completed' then
    if v_postponed > 0 then
      raise exception 'Postponed sets must be resolved before completion.';
    end if;

    select count(*) into v_open_issues
    from public.uniform_delivery_issues i
    where i.order_id = new.id
      and i.resolution_status in ('Open','In Progress');

    if v_open_issues > 0 then
      raise exception 'All delivery issues must be resolved before completion.';
    end if;

    select count(*) into v_unpaid_bills
    from public.uniform_delivery_bills b
    where b.order_id = new.id
      and (b.head_office_confirmed = false or b.paid = false);

    if v_unpaid_bills > 0 then
      raise exception 'All bills must be confirmed and paid before completion.';
    end if;

    if not exists (
      select 1 from public.uniform_delivery_bills b where b.order_id = new.id
    ) then
      raise exception 'At least one paid bill is required before completion.';
    end if;
  end if;

  return new;
end;
$function$;
ALTER FUNCTION public.validate_uniform_order_status_change() OWNER TO "postgres";
