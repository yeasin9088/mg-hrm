-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- public.notification_check_core_source(text,bigint) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_check_core_source(p_entity_type text, p_entity_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  v_resolved boolean;
  v_state text;
begin
  if p_entity_id is null then
    raise exception using
      errcode = '22023',
      message = 'Entity ID is required';
  end if;

  if lower(btrim(coalesce(p_entity_type, ''))) = 'todo' then

    select
      (
        t.deleted_at is not null
        or t.solved_at is not null
        or lower(btrim(coalesce(t.status, ''))) in (
          'completed',
          'complete',
          'solved',
          'closed',
          'cancelled',
          'solved_approved',
          'solved_rejected'
        )
      ),
      coalesce(t.status, '[blank]')
    into
      v_resolved,
      v_state
    from public.todos t
    where t.id = p_entity_id;

  elsif lower(btrim(coalesce(p_entity_type, ''))) =
    'transfer' then

    select
      t.status in (
        'Completed',
        'Cancelled'
      ),
      t.status
    into
      v_resolved,
      v_state
    from public.transfers t
    where t.id = p_entity_id
      and t.deleted_at is null;

  elsif lower(btrim(coalesce(p_entity_type, ''))) =
    'exit' then

    select
      e.status in (
        'Completed',
        'Cancelled'
      ),
      e.status
    into
      v_resolved,
      v_state
    from public.exits e
    where e.id = p_entity_id
      and e.deleted_at is null;

  else
    raise exception using
      errcode = '22023',
      message = 'Unsupported core source type';
  end if;

  if v_state is null then
    raise exception using
      errcode = 'P0002',
      message = 'Source workflow record not found';
  end if;

  return jsonb_build_object(
    'entity_type',
    lower(btrim(p_entity_type)),
    'entity_id',
    p_entity_id,
    'resolved',
    coalesce(v_resolved, false),
    'state',
    v_state
  );
end;
$function$;
ALTER FUNCTION public.notification_check_core_source(text,bigint) OWNER TO "postgres";

-- public.notification_check_leave_source(bigint) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_check_leave_source(p_entity_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  v_resolved boolean;
  v_state text;
begin
  if p_entity_id is null then
    raise exception using
      errcode = '22023',
      message = 'Entity ID is required';
  end if;

  select
    lower(btrim(coalesce(l.status, ''))) in (
      'approved',
      'rejected',
      'cancelled',
      'completed',
      'closed'
    ),
    coalesce(l.status, '[blank]')
  into
    v_resolved,
    v_state
  from public.leaves l
  where l.id = p_entity_id
    and l.deleted_at is null;

  if v_state is null then
    raise exception using
      errcode = 'P0002',
      message = 'Leave record not found';
  end if;

  return jsonb_build_object(
    'entity_type', 'leave',
    'entity_id', p_entity_id,
    'resolved', coalesce(v_resolved, false),
    'state', v_state
  );
end;
$function$;
ALTER FUNCTION public.notification_check_leave_source(bigint) OWNER TO "postgres";

-- public.notification_check_uniform_source(text,bigint) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_check_uniform_source(p_entity_type text, p_entity_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  v_type text;
  v_resolved boolean;
  v_state text;
begin
  v_type := lower(btrim(coalesce(p_entity_type, '')));

  if p_entity_id is null then
    raise exception using
      errcode = '22023',
      message = 'Entity ID is required';
  end if;

  if v_type = 'uniform_supply_order' then
    select
      u.status in ('Completed', 'Cancelled'),
      u.status
    into v_resolved, v_state
    from public.uniform_supply_orders u
    where u.id = p_entity_id;

  elsif v_type = 'uniform_delivery_issue' then
    select
      i.resolution_status in ('Resolved', 'Cancelled'),
      i.resolution_status
    into v_resolved, v_state
    from public.uniform_delivery_issues i
    where i.id = p_entity_id;

  elsif v_type = 'uniform_delivery_bill' then
    select
      b.paid = true,
      case
        when b.paid then 'Paid'
        when b.head_office_confirmed then 'Confirmed, payment pending'
        else 'Confirmation pending'
      end
    into v_resolved, v_state
    from public.uniform_delivery_bills b
    where b.id = p_entity_id;

  else
    raise exception using
      errcode = '22023',
      message = 'Unsupported Uniform source type';
  end if;

  if v_state is null then
    raise exception using
      errcode = 'P0002',
      message = 'Uniform source record not found';
  end if;

  return jsonb_build_object(
    'entity_type', v_type,
    'entity_id', p_entity_id,
    'resolved', coalesce(v_resolved, false),
    'state', v_state
  );
end;
$function$;
ALTER FUNCTION public.notification_check_uniform_source(text,bigint) OWNER TO "postgres";

-- public.notification_claim_jobs(text,integer) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_claim_jobs(p_worker_id text, p_batch_size integer DEFAULT 20)
 RETURNS SETOF notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  if length(btrim(p_worker_id)) > 200 then
    raise exception 'Worker ID cannot exceed 200 characters';
  end if;

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 100 then
    raise exception 'Batch size must be between 1 and 100';
  end if;

  return query
  with claimable as (
    select j.id
    from public.notification_jobs j
    where j.job_status in ('Pending', 'Failed')
      and j.run_at <= clock_timestamp()
      and j.attempt_count < j.maximum_attempts
    order by j.run_at, j.id
    limit p_batch_size
    for update skip locked
  )
  update public.notification_jobs j
  set
    job_status = 'Processing',
    attempt_count = j.attempt_count + 1,
    locked_at = clock_timestamp(),
    locked_by = btrim(p_worker_id),
    started_at = clock_timestamp(),
    completed_at = null,
    failed_at = null,
    last_error = null
  from claimable c
  where j.id = c.id
  returning j.*;
end
$function$;
ALTER FUNCTION public.notification_claim_jobs(text,integer) OWNER TO "postgres";

-- public.notification_claim_todo_reminder(bigint,timestamp with time zone,timestamp with time zone) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_claim_todo_reminder(p_todo_id bigint, p_expected_next timestamp with time zone, p_next timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE t public.todos%ROWTYPE; recipient uuid := auth.uid(); due timestamptz; event_identity text;
BEGIN
  IF recipient IS NULL OR public.my_role() NOT IN ('admin','editor') THEN
    RAISE EXCEPTION 'Active operator permission required' USING ERRCODE='42501';
  END IF;
  IF p_next IS NOT NULL AND (p_next <= clock_timestamp() OR p_next > clock_timestamp() + interval '10 years') THEN
    RAISE EXCEPTION 'Invalid next reminder time' USING ERRCODE='22023';
  END IF;
  SELECT * INTO t FROM public.todos WHERE id=p_todo_id FOR UPDATE;
  IF NOT FOUND OR t.deleted_at IS NOT NULL OR t.reminder_enabled IS DISTINCT FROM true OR t.solved_at IS NOT NULL OR
     lower(coalesce(t.status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     lower(coalesce(t.manager_status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     t.next_reminder_at IS DISTINCT FROM p_expected_next OR
     (t.next_reminder_at IS NOT NULL AND t.next_reminder_at > clock_timestamp()) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  IF NOT coalesce((public.notification_effective_preference(recipient,'ToDo')->>'notification_enabled')::boolean,true) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  due := coalesce(t.next_reminder_at,date_trunc('minute',clock_timestamp()));
  event_identity := 'todo-reminder:' || t.id::text || ':' || extract(epoch FROM due)::text;
  INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
  VALUES ('TodoReminderDue','todo',t.id::text,recipient,event_identity,
    jsonb_build_object('recipient_user_id',recipient,'category','ToDo','severity','Info','priority','Normal',
      'title','To-Do reminder','message','A scheduled note needs your attention. Open MG-HRM to review it.',
      'action_label','Review note','action_route','todo','dedupe_key',event_identity,
      'action_params',jsonb_build_object('notification_type','todo_rem'),'scheduled_for',due),due)
  ON CONFLICT (event_key) DO NOTHING;
  UPDATE public.todos SET next_reminder_at=p_next,
    reminder_enabled=CASE WHEN p_next IS NULL THEN false ELSE reminder_enabled END WHERE id=t.id;
  RETURN jsonb_build_object('claimed',true,'event_key',event_identity,'occurred_at',due);
END;
$function$;
ALTER FUNCTION public.notification_claim_todo_reminder(bigint,timestamp with time zone,timestamp with time zone) OWNER TO "postgres";

-- public.notification_claim_web_push_jobs(text,integer) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_claim_web_push_jobs(p_worker_id text, p_batch_size integer DEFAULT 10)
 RETURNS SETOF notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if length(btrim(p_worker_id)) > 200 then
    raise exception
      'Worker ID cannot exceed 200 characters';
  end if;

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 25 then
    raise exception
      'Batch size must be between 1 and 25';
  end if;

  return query
  with claimable as (
    select job_row.id
    from public.notification_jobs job_row
    where job_row.job_type =
      'DeliverWebPush'
      and job_row.job_status in (
        'Pending',
        'Failed'
      )
      and job_row.run_at <=
        clock_timestamp()
      and job_row.attempt_count <
        job_row.maximum_attempts
    order by
      job_row.run_at,
      job_row.id
    limit p_batch_size
    for update skip locked
  )
  update public.notification_jobs job_row
  set
    job_status = 'Processing',
    attempt_count =
      job_row.attempt_count + 1,
    locked_at = clock_timestamp(),
    locked_by = btrim(p_worker_id),
    started_at = clock_timestamp(),
    completed_at = null,
    failed_at = null,
    last_error = null
  from claimable claim_row
  where job_row.id = claim_row.id
  returning job_row.*;
end
$function$;
ALTER FUNCTION public.notification_claim_web_push_jobs(text,integer) OWNER TO "postgres";

-- public.notification_complete_job(bigint,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_complete_job(p_job_id bigint, p_worker_id text)
 RETURNS notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  update public.notification_jobs
  set
    job_status = 'Completed',
    completed_at = clock_timestamp(),
    failed_at = null,
    last_error = null,
    locked_at = null,
    locked_by = null
  where id = p_job_id
    and job_status = 'Processing'
    and locked_by = btrim(p_worker_id)
  returning *
  into v_job;

  if v_job.id is null then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  return v_job;
end
$function$;
ALTER FUNCTION public.notification_complete_job(bigint,text) OWNER TO "postgres";

-- public.notification_cron_tick() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_cron_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_lock_key constant bigint := 73110420261011;
  v_result jsonb;
begin
  if not pg_try_advisory_xact_lock(v_lock_key) then
    return jsonb_build_object(
      'status', 'Skipped',
      'reason', 'Another processor run is active',
      'finished_at', clock_timestamp()
    );
  end if;

  v_result :=
    public.notification_run_server_processor(
      'cron:notification-server-processor',
      25,
      interval '15 minutes'
    );

  return jsonb_build_object(
    'status', 'Completed',
    'processor', v_result,
    'finished_at', clock_timestamp()
  );

exception
  when others then
    raise warning
      'Notification processor Cron tick failed: %',
      sqlerrm;

    return jsonb_build_object(
      'status', 'Failed',
      'error', left(sqlerrm, 4000),
      'finished_at', clock_timestamp()
    );
end
$function$;
ALTER FUNCTION public.notification_cron_tick() OWNER TO "postgres";

-- public.notification_effective_preference(uuid,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_effective_preference(p_user_id uuid, p_category text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_pref public.notification_preferences%rowtype;
  v_category text;
begin
  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  v_category := coalesce(
    nullif(btrim(coalesce(p_category, '')), ''),
    'System'
  );

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_user_id
      and p.is_active = true
  ) then
    raise exception
      'Notification recipient is missing or inactive';
  end if;

  select pref.*
  into v_pref
  from public.notification_preferences pref
  where pref.user_id = p_user_id
    and pref.category in (v_category, '*')
  order by
    case
      when pref.category = v_category then 0
      else 1
    end,
    pref.id
  limit 1;

  if v_pref.id is null then
    return jsonb_build_object(
      'source_category', 'system-default',
      'notification_enabled', true,
      'in_app_enabled', true,
      'toast_enabled', true,
      'system_push_enabled', true,
      'minimum_priority', 'Low',
      'quiet_hours_enabled', true,
      'quiet_hours_start', '22:00:00',
      'quiet_hours_end', '07:00:00',
      'urgent_bypass_enabled', true,
      'timezone', 'Asia/Dhaka',
      'default_snooze_minutes', 15,
      'toast_max_visible', 2,
      'toast_gap_seconds', 60
    );
  end if;

  return jsonb_build_object(
    'preference_id', v_pref.id,
    'source_category', v_pref.category,
    'notification_enabled', v_pref.notification_enabled,
    'in_app_enabled', v_pref.in_app_enabled,
    'toast_enabled', v_pref.toast_enabled,
    'system_push_enabled', v_pref.system_push_enabled,
    'minimum_priority', v_pref.minimum_priority,
    'quiet_hours_enabled', v_pref.quiet_hours_enabled,
    'quiet_hours_start', v_pref.quiet_hours_start::text,
    'quiet_hours_end', v_pref.quiet_hours_end::text,
    'urgent_bypass_enabled', v_pref.urgent_bypass_enabled,
    'timezone', v_pref.timezone,
    'default_snooze_minutes',
      v_pref.default_snooze_minutes,
    'toast_max_visible', v_pref.toast_max_visible,
    'toast_gap_seconds', v_pref.toast_gap_seconds
  );
end
$function$;
ALTER FUNCTION public.notification_effective_preference(uuid,text) OWNER TO "postgres";

-- public.notification_enqueue_pending_events(integer) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_enqueue_pending_events(p_batch_size integer DEFAULT 50)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_enqueued integer := 0;
begin
  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 200 then
    raise exception
      'Batch size must be between 1 and 200';
  end if;

  with pending_events as (
    select e.id
    from public.notification_events e
    where e.processing_status = 'Pending'
    order by e.occurred_at, e.id
    limit p_batch_size
    for update skip locked
  ),
  inserted_jobs as (
    insert into public.notification_jobs (
      event_id,
      job_type,
      run_at,
      job_status,
      attempt_count,
      maximum_attempts,
      job_payload
    )
    select
      p.id,
      'ProcessEvent',
      clock_timestamp(),
      'Pending',
      0,
      5,
      jsonb_build_object(
        'event_id', p.id,
        'queued_at', clock_timestamp()
      )
    from pending_events p
    on conflict do nothing
    returning id
  )
  select count(*)
  into v_enqueued
  from inserted_jobs;

  return v_enqueued;
end
$function$;
ALTER FUNCTION public.notification_enqueue_pending_events(integer) OWNER TO "postgres";

-- public.notification_fail_job(bigint,text,text,interval) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_fail_job(p_job_id bigint, p_worker_id text, p_error text, p_retry_after interval DEFAULT '00:05:00'::interval)
 RETURNS notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  if nullif(btrim(coalesce(p_error, '')), '') is null then
    raise exception 'Failure diagnostics are required';
  end if;

  if p_retry_after is null
     or p_retry_after < interval '1 minute'
     or p_retry_after > interval '24 hours' then
    raise exception
      'Retry interval must be between 1 minute and 24 hours';
  end if;

  update public.notification_jobs
  set
    job_status = case
      when attempt_count >= maximum_attempts
        then 'DeadLetter'
      else 'Failed'
    end,
    run_at = case
      when attempt_count >= maximum_attempts
        then run_at
      else clock_timestamp() + p_retry_after
    end,
    failed_at = clock_timestamp(),
    completed_at = null,
    last_error = left(btrim(p_error), 4000),
    locked_at = null,
    locked_by = null
  where id = p_job_id
    and job_status = 'Processing'
    and locked_by = btrim(p_worker_id)
  returning *
  into v_job;

  if v_job.id is null then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  return v_job;
end
$function$;
ALTER FUNCTION public.notification_fail_job(bigint,text,text,interval) OWNER TO "postgres";

-- public.notification_finalize_web_push_job(bigint,text,interval) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_finalize_web_push_job(p_job_id bigint, p_worker_id text, p_retry_after interval DEFAULT '00:05:00'::interval)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_pending integer := 0;
  v_failed integer := 0;
  v_sent integer := 0;
  v_result public.notification_jobs%rowtype;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if p_retry_after is null
     or p_retry_after <
        interval '1 minute'
     or p_retry_after >
        interval '24 hours' then
    raise exception
      'Retry interval must be between 1 minute and 24 hours';
  end if;

  select job_row.*
  into v_job
  from public.notification_jobs job_row
  where job_row.id = p_job_id
    and job_row.job_type =
      'DeliverWebPush'
    and job_row.job_status =
      'Processing'
    and job_row.locked_by =
      btrim(p_worker_id);

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select
    count(*) filter (
      where delivery_status in (
        'Pending',
        'Processing'
      )
    ),
    count(*) filter (
      where delivery_status =
        'Failed'
    ),
    count(*) filter (
      where delivery_status in (
        'Sent',
        'Delivered'
      )
    )
  into
    v_pending,
    v_failed,
    v_sent
  from public.notification_deliveries
  where notification_id =
        v_job.notification_id
    and channel = 'WebPush';

  if v_pending > 0 then
    raise exception
      'Web Push job % still has % unfinished deliveries',
      p_job_id,
      v_pending;
  end if;

  if v_failed > 0 then
    v_result :=
      public.notification_fail_job(
        p_job_id,
        p_worker_id,
        format(
          '%s Web Push delivery attempt(s) failed; %s accepted',
          v_failed,
          v_sent
        ),
        p_retry_after
      );
  else
    v_result :=
      public.notification_complete_job(
        p_job_id,
        p_worker_id
      );
  end if;

  return jsonb_build_object(
    'job_id',
      v_result.id,
    'job_status',
      v_result.job_status,
    'attempt_count',
      v_result.attempt_count,
    'maximum_attempts',
      v_result.maximum_attempts,
    'sent_deliveries',
      v_sent,
    'failed_deliveries',
      v_failed,
    'pending_deliveries',
      v_pending,
    'run_at',
      v_result.run_at
  );
end
$function$;
ALTER FUNCTION public.notification_finalize_web_push_job(bigint,text,interval) OWNER TO "postgres";

-- public.notification_get_web_push_dispatch(bigint,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_get_web_push_dispatch(p_job_id bigint, p_worker_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_notification public.notifications%rowtype;
  v_deliveries jsonb;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  select job_row.*
  into v_job
  from public.notification_jobs job_row
  where job_row.id = p_job_id
    and job_row.job_type =
      'DeliverWebPush'
    and job_row.job_status =
      'Processing'
    and job_row.locked_by =
      btrim(p_worker_id);

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select notification_row.*
  into v_notification
  from public.notifications notification_row
  where notification_row.id =
    v_job.notification_id;

  if not found then
    raise exception
      'Notification for Web Push job % was not found',
      p_job_id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'delivery_id',
          delivery_row.id,
        'subscription_id',
          subscription_row.id,
        'endpoint',
          subscription_row.endpoint,
        'keys',
          jsonb_build_object(
            'p256dh',
              subscription_row.p256dh_key,
            'auth',
              subscription_row.auth_key
          ),
        'attempt_number',
          delivery_row.attempt_number
      )
      order by delivery_row.id
    ),
    '[]'::jsonb
  )
  into v_deliveries
  from public.notification_deliveries
    delivery_row
  join public.push_subscriptions
    subscription_row
    on subscription_row.id =
       delivery_row.subscription_id
  where delivery_row.notification_id =
        v_notification.id
    and delivery_row.channel =
        'WebPush'
    and delivery_row.delivery_status in (
      'Pending',
      'Failed'
    )
    and subscription_row.user_id =
        v_notification.recipient_user_id
    and subscription_row.is_active = true
    and subscription_row.permission_state =
        'granted'
    and subscription_row.revoked_at is null;

  return jsonb_build_object(
    'job',
      jsonb_build_object(
        'id',
          v_job.id,
        'attempt_count',
          v_job.attempt_count,
        'maximum_attempts',
          v_job.maximum_attempts
      ),
    'notification',
      jsonb_build_object(
        'id',
          v_notification.id,
        'recipient_user_id',
          v_notification.recipient_user_id,
        'title',
          v_notification.title,
        'message',
          v_notification.message,
        'category',
          v_notification.category,
        'priority',
          v_notification.priority,
        'severity',
          v_notification.severity,
        'action_label',
          v_notification.action_label,
        'action_route',
          v_notification.action_route,
        'action_params',
          coalesce(
            v_notification.action_params,
            '{}'::jsonb
          ),
        'entity_type',
          v_notification.entity_type,
        'entity_id',
          v_notification.entity_id,
        'expires_at',
          v_notification.expires_at
      ),
    'deliveries',
      v_deliveries
  );
end
$function$;
ALTER FUNCTION public.notification_get_web_push_dispatch(bigint,text) OWNER TO "postgres";

-- public.notification_next_allowed_at(uuid,text,text,timestamp with time zone) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_next_allowed_at(p_user_id uuid, p_category text, p_priority text, p_requested_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_pref jsonb;
  v_requested timestamptz;
  v_min_priority text;
  v_quiet_start time;
  v_quiet_end time;
  v_timezone text;
  v_local timestamp;
  v_next_local timestamp;
begin
  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  if p_priority not in (
    'Low',
    'Normal',
    'High',
    'Urgent'
  ) then
    raise exception
      'Unsupported notification priority: %',
      p_priority;
  end if;

  v_requested := coalesce(
    p_requested_at,
    clock_timestamp()
  );

  v_pref :=
    public.notification_effective_preference(
      p_user_id,
      p_category
    );

  if not coalesce(
    (v_pref ->> 'notification_enabled')::boolean,
    true
  ) then
    return null;
  end if;

  v_min_priority := coalesce(
    nullif(v_pref ->> 'minimum_priority', ''),
    'Low'
  );

  if public.notification_priority_rank(p_priority)
     < public.notification_priority_rank(v_min_priority) then
    return null;
  end if;

  if not coalesce(
    (v_pref ->> 'quiet_hours_enabled')::boolean,
    true
  ) then
    return v_requested;
  end if;

  if p_priority = 'Urgent'
     and coalesce(
       (v_pref ->> 'urgent_bypass_enabled')::boolean,
       true
     ) then
    return v_requested;
  end if;

  v_quiet_start := coalesce(
    nullif(
      v_pref ->> 'quiet_hours_start',
      ''
    )::time,
    time '22:00'
  );

  v_quiet_end := coalesce(
    nullif(
      v_pref ->> 'quiet_hours_end',
      ''
    )::time,
    time '07:00'
  );

  v_timezone := coalesce(
    nullif(
      btrim(v_pref ->> 'timezone'),
      ''
    ),
    'Asia/Dhaka'
  );

  if not exists (
    select 1
    from pg_timezone_names tz
    where tz.name = v_timezone
  ) then
    raise exception
      'Unsupported notification timezone: %',
      v_timezone;
  end if;

  if v_quiet_start = v_quiet_end then
    return v_requested;
  end if;

  v_local := v_requested at time zone v_timezone;

  if v_quiet_start < v_quiet_end then
    if v_local::time >= v_quiet_start
       and v_local::time < v_quiet_end then
      v_next_local := v_local::date + v_quiet_end;
    else
      return v_requested;
    end if;
  else
    if v_local::time >= v_quiet_start then
      v_next_local :=
        (v_local::date + 1) + v_quiet_end;
    elsif v_local::time < v_quiet_end then
      v_next_local := v_local::date + v_quiet_end;
    else
      return v_requested;
    end if;
  end if;

  return v_next_local at time zone v_timezone;
end
$function$;
ALTER FUNCTION public.notification_next_allowed_at(uuid,text,text,timestamp with time zone) OWNER TO "postgres";

-- public.notification_operations_health() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_operations_health()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'cron'
AS $function$
declare
  v_overdue_jobs bigint := 0;
  v_failed_jobs bigint := 0;
  v_deadletter_jobs bigint := 0;
  v_stale_jobs bigint := 0;

  v_unfinished_push bigint := 0;
  v_failed_push bigint := 0;
  v_successful_push bigint := 0;

  v_active_subscriptions bigint := 0;
  v_subscription_failures bigint := 0;
  v_unhealthy_subscriptions bigint := 0;
  v_inactive_subscriptions bigint := 0;

  v_processor_active boolean := false;
  v_sender_active boolean := false;
  v_maintenance_active boolean := false;

  v_processor_last_status text;
  v_sender_last_status text;
  v_maintenance_last_status text;

  v_healthy boolean := false;
begin
  select
    count(*) filter (
      where job_status = 'Pending'
        and run_at <= clock_timestamp()
    ),
    count(*) filter (
      where job_status = 'Failed'
    ),
    count(*) filter (
      where job_status = 'DeadLetter'
    ),
    count(*) filter (
      where job_status = 'Processing'
        and locked_at <
          clock_timestamp() - interval '15 minutes'
    )
  into
    v_overdue_jobs,
    v_failed_jobs,
    v_deadletter_jobs,
    v_stale_jobs
  from public.notification_jobs;


  select
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status in (
          'Pending',
          'Processing'
        )
    ),
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status = 'Failed'
    ),
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status in (
          'Sent',
          'Delivered'
        )
    )
  into
    v_unfinished_push,
    v_failed_push,
    v_successful_push
  from public.notification_deliveries;


  select
    count(*) filter (
      where is_active = true
        and permission_state = 'granted'
        and revoked_at is null
    ),
    count(*) filter (
      where failure_count > 0
    ),
    count(*) filter (
      where failure_count >= 5
    ),
    count(*) filter (
      where is_active = false
         or revoked_at is not null
         or permission_state in (
           'denied',
           'revoked',
           'unsupported'
         )
    )
  into
    v_active_subscriptions,
    v_subscription_failures,
    v_unhealthy_subscriptions,
    v_inactive_subscriptions
  from public.push_subscriptions;


  select exists (
    select 1
    from cron.job
    where jobname = 'notification-server-processor'
      and active = true
  )
  into v_processor_active;

  select exists (
    select 1
    from cron.job
    where jobname = 'notification-web-push-sender'
      and active = true
  )
  into v_sender_active;

  select exists (
    select 1
    from cron.job
    where jobname = 'notification-operations-maintenance'
      and active = true
  )
  into v_maintenance_active;


  select run_row.status
  into v_processor_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-server-processor'
  order by run_row.start_time desc
  limit 1;


  select run_row.status
  into v_sender_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-web-push-sender'
  order by run_row.start_time desc
  limit 1;


  select run_row.status
  into v_maintenance_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-operations-maintenance'
  order by run_row.start_time desc
  limit 1;


  /*
   * A newly-created maintenance Cron may not have executed yet.
   * A NULL first-run status is therefore accepted.
   * Any recorded non-success status makes health red.
   */
  v_healthy :=
    v_overdue_jobs = 0
    and v_failed_jobs = 0
    and v_deadletter_jobs = 0
    and v_stale_jobs = 0
    and v_unfinished_push = 0
    and v_failed_push = 0
    and v_unhealthy_subscriptions = 0
    and v_processor_active
    and v_sender_active
    and v_maintenance_active
    and v_processor_last_status = 'succeeded'
    and v_sender_last_status = 'succeeded'
    and (
      v_maintenance_last_status is null
      or v_maintenance_last_status = 'succeeded'
    );


  return jsonb_build_object(
    'healthy',
      v_healthy,

    'jobs',
      jsonb_build_object(
        'overdue_pending',
          v_overdue_jobs,
        'failed',
          v_failed_jobs,
        'deadletter',
          v_deadletter_jobs,
        'stale_processing',
          v_stale_jobs
      ),

    'web_push_deliveries',
      jsonb_build_object(
        'unfinished',
          v_unfinished_push,
        'failed',
          v_failed_push,
        'successful',
          v_successful_push
      ),

    'subscriptions',
      jsonb_build_object(
        'active',
          v_active_subscriptions,
        'with_failures',
          v_subscription_failures,
        'unhealthy',
          v_unhealthy_subscriptions,
        'inactive',
          v_inactive_subscriptions
      ),

    'cron',
      jsonb_build_object(
        'notification-server-processor',
          jsonb_build_object(
            'active',
              v_processor_active,
            'last_status',
              v_processor_last_status
          ),

        'notification-web-push-sender',
          jsonb_build_object(
            'active',
              v_sender_active,
            'last_status',
              v_sender_last_status
          ),

        'notification-operations-maintenance',
          jsonb_build_object(
            'active',
              v_maintenance_active,
            'last_status',
              v_maintenance_last_status,
            'first_run_pending',
              v_maintenance_last_status is null
          )
      ),

    'checked_at',
      clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_operations_health() OWNER TO "postgres";

-- public.notification_operations_maintenance() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_operations_maintenance()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_recovered integer := 0;
  v_health jsonb;
begin
  v_recovered :=
    public.notification_recover_stale_jobs(
      interval '15 minutes'
    );

  v_health :=
    public.notification_operations_health();

  return jsonb_build_object(
    'stale_jobs_recovered',
      v_recovered,

    'healthy',
      coalesce(
        (v_health ->> 'healthy')::boolean,
        false
      ),

    'jobs',
      v_health -> 'jobs',

    'web_push_deliveries',
      v_health -> 'web_push_deliveries',

    'subscriptions',
      v_health -> 'subscriptions',

    'finished_at',
      clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_operations_maintenance() OWNER TO "postgres";

-- public.notification_prepare_deliveries(integer) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_prepare_deliveries(p_batch_size integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_notification public.notifications%rowtype;
  v_preference jsonb;

  v_expired integer := 0;
  v_promoted integer := 0;
  v_examined integer := 0;
  v_cancelled integer := 0;

  v_in_app_created integer := 0;
  v_push_deliveries_created integer := 0;
  v_push_jobs_created integer := 0;

  v_insert_count integer := 0;
  v_in_app_enabled boolean;
  v_push_enabled boolean;
  v_notification_enabled boolean;
  v_minimum_priority text;
begin
  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 200 then
    raise exception
      'Batch size must be between 1 and 200';
  end if;

  with expired_rows as (
    select n.id
    from public.notifications n
    where n.expires_at is not null
      and n.expires_at <= clock_timestamp()
      and n.status in (
        'Scheduled',
        'Ready',
        'Delivered',
        'Read',
        'Actioned',
        'Snoozed',
        'Failed'
      )
    order by n.expires_at, n.id
    limit p_batch_size
    for update skip locked
  ),
  updated as (
    update public.notifications n
    set
      status = 'Expired'
    from expired_rows e
    where n.id = e.id
    returning n.id
  )
  select count(*)
  into v_expired
  from updated;


  with due_rows as (
    select n.id
    from public.notifications n
    where n.status in (
        'Scheduled',
        'Snoozed',
        'Failed'
      )
      and n.scheduled_for <= clock_timestamp()
      and (
        n.expires_at is null
        or n.expires_at > clock_timestamp()
      )
    order by n.scheduled_for, n.id
    limit p_batch_size
    for update skip locked
  ),
  updated as (
    update public.notifications n
    set
      status = 'Ready',
      snoozed_until = case
        when n.status = 'Snoozed' then null
        else n.snoozed_until
      end
    from due_rows d
    where n.id = d.id
    returning n.id
  )
  select count(*)
  into v_promoted
  from updated;


  for v_notification in
    select n.*
    from public.notifications n
    where n.status = 'Ready'
      and n.scheduled_for <= clock_timestamp()
      and (
        n.expires_at is null
        or n.expires_at > clock_timestamp()
      )
    order by n.scheduled_for, n.created_at, n.id
    limit p_batch_size
    for update skip locked
  loop
    v_examined := v_examined + 1;

    v_preference :=
      public.notification_effective_preference(
        v_notification.recipient_user_id,
        v_notification.category
      );

    v_notification_enabled := coalesce(
      (
        v_preference
        ->> 'notification_enabled'
      )::boolean,
      true
    );

    v_minimum_priority := coalesce(
      nullif(
        v_preference
        ->> 'minimum_priority',
        ''
      ),
      'Low'
    );

    if not v_notification_enabled
       or public.notification_priority_rank(
         v_notification.priority
       ) < public.notification_priority_rank(
         v_minimum_priority
       ) then

      update public.notifications
      set status = 'Cancelled'
      where id = v_notification.id;

      v_cancelled := v_cancelled + 1;
      continue;
    end if;

    v_in_app_enabled := coalesce(
      (
        v_preference
        ->> 'in_app_enabled'
      )::boolean,
      true
    );

    v_push_enabled := coalesce(
      (
        v_preference
        ->> 'system_push_enabled'
      )::boolean,
      true
    );


    if v_in_app_enabled then
      insert into public.notification_deliveries (
        notification_id,
        subscription_id,
        channel,
        attempt_number,
        delivery_status,
        attempted_at,
        sent_at,
        delivered_at,
        provider_status,
        response_metadata
      )
      values (
        v_notification.id,
        null,
        'InApp',
        1,
        'Delivered',
        clock_timestamp(),
        clock_timestamp(),
        clock_timestamp(),
        'InboxAvailable',
        jsonb_build_object(
          'delivery_mode', 'authoritative-inbox',
          'prepared_at', clock_timestamp()
        )
      )
      on conflict do nothing;

      get diagnostics v_insert_count = row_count;

      v_in_app_created :=
        v_in_app_created + v_insert_count;

      if v_insert_count > 0 then
        update public.notifications
        set
          status = 'Delivered',
          first_delivered_at = coalesce(
            first_delivered_at,
            clock_timestamp()
          ),
          last_delivered_at = clock_timestamp()
        where id = v_notification.id
          and status = 'Ready';
      end if;
    end if;


    if v_push_enabled then
      with active_devices as (
        select s.id
        from public.push_subscriptions s
        where s.user_id =
              v_notification.recipient_user_id
          and s.is_active = true
          and s.permission_state = 'granted'
          and s.revoked_at is null
        order by s.last_seen_at desc, s.id
      ),
      inserted as (
        insert into public.notification_deliveries (
          notification_id,
          subscription_id,
          channel,
          attempt_number,
          delivery_status,
          response_metadata
        )
        select
          v_notification.id,
          d.id,
          'WebPush',
          1,
          'Pending',
          jsonb_build_object(
            'prepared_at',
            clock_timestamp()
          )
        from active_devices d
        on conflict do nothing
        returning id
      )
      select count(*)
      into v_insert_count
      from inserted;

      v_push_deliveries_created :=
        v_push_deliveries_created
        + v_insert_count;

      if v_insert_count > 0 then
        insert into public.notification_jobs (
          notification_id,
          event_id,
          job_type,
          run_at,
          job_status,
          attempt_count,
          maximum_attempts,
          job_payload
        )
        values (
          v_notification.id,
          v_notification.event_id,
          'DeliverWebPush',
          clock_timestamp(),
          'Pending',
          0,
          5,
          jsonb_build_object(
            'notification_id',
            v_notification.id,
            'prepared_at',
            clock_timestamp()
          )
        )
        on conflict do nothing;

        get diagnostics v_insert_count = row_count;

        v_push_jobs_created :=
          v_push_jobs_created + v_insert_count;
      end if;
    end if;
  end loop;


  return jsonb_build_object(
    'expired_notifications', v_expired,
    'due_notifications_promoted', v_promoted,
    'ready_notifications_examined', v_examined,
    'notifications_cancelled_by_preference',
      v_cancelled,
    'in_app_deliveries_created',
      v_in_app_created,
    'web_push_deliveries_created',
      v_push_deliveries_created,
    'web_push_jobs_created',
      v_push_jobs_created,
    'finished_at',
      clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_prepare_deliveries(integer) OWNER TO "postgres";

-- public.notification_priority_rank(text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_priority_rank(p_priority text)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE STRICT SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  case p_priority
    when 'Low' then
      return 1;
    when 'Normal' then
      return 2;
    when 'High' then
      return 3;
    when 'Urgent' then
      return 4;
    else
      raise exception using
        message = format(
          'Unsupported notification priority: %s',
          p_priority
        );
  end case;
end;
$function$;
ALTER FUNCTION public.notification_priority_rank(text) OWNER TO "postgres";

-- public.notification_process_event_job(bigint,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_process_event_job(p_job_id bigint, p_worker_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_event public.notification_events%rowtype;

  v_payload jsonb;
  v_preference jsonb;

  v_recipient uuid;
  v_notification_id uuid;

  v_category text;
  v_severity text;
  v_priority text;
  v_title text;
  v_message text;
  v_dedupe_key text;

  v_action_label text;
  v_action_route text;
  v_action_params jsonb;

  v_requested_at timestamptz;
  v_allowed_at timestamptz;
  v_expires_at timestamptz;
  v_status text;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception 'Worker ID is required';
  end if;

  select *
  into v_job
  from public.notification_jobs
  where id = p_job_id
  for update;

  if v_job.id is null then
    raise exception
      'Notification job % does not exist',
      p_job_id;
  end if;

  if v_job.job_status <> 'Processing'
     or v_job.locked_by is distinct from btrim(p_worker_id) then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  if v_job.job_type <> 'ProcessEvent'
     or v_job.event_id is null then
    raise exception
      'Job % is not a valid ProcessEvent job',
      p_job_id;
  end if;

  select *
  into v_event
  from public.notification_events
  where id = v_job.event_id
  for update;

  if v_event.id is null then
    perform public.notification_fail_job(
      p_job_id,
      p_worker_id,
      'Referenced notification event does not exist',
      interval '5 minutes'
    );

    return null;
  end if;

  if v_event.processing_status in (
    'Processed',
    'Ignored',
    'Cancelled'
  ) then
    perform public.notification_complete_job(
      p_job_id,
      p_worker_id
    );

    return null;
  end if;

  begin
    v_payload := coalesce(
      v_event.event_payload,
      '{}'::jsonb
    );

    if nullif(
      btrim(v_payload ->> 'recipient_user_id'),
      ''
    ) is null then
      raise exception
        'event_payload.recipient_user_id is required';
    end if;

    begin
      v_recipient :=
        (v_payload ->> 'recipient_user_id')::uuid;
    exception
      when invalid_text_representation then
        raise exception
          'event_payload.recipient_user_id must be a valid UUID';
    end;

    if not exists (
      select 1
      from public.profiles p
      where p.id = v_recipient
        and p.is_active = true
    ) then
      raise exception
        'Configured recipient is missing or inactive';
    end if;

    v_category := coalesce(
      nullif(
        btrim(v_payload ->> 'category'),
        ''
      ),
      'System'
    );

    v_severity := coalesce(
      nullif(
        btrim(v_payload ->> 'severity'),
        ''
      ),
      'Info'
    );

    if v_severity not in (
      'Info',
      'Success',
      'Warning',
      'Critical'
    ) then
      raise exception
        'Unsupported severity: %',
        v_severity;
    end if;

    v_priority := coalesce(
      nullif(
        btrim(v_payload ->> 'priority'),
        ''
      ),
      'Normal'
    );

    if v_priority not in (
      'Low',
      'Normal',
      'High',
      'Urgent'
    ) then
      raise exception
        'Unsupported priority: %',
        v_priority;
    end if;

    v_title :=
      nullif(btrim(v_payload ->> 'title'), '');

    v_message :=
      nullif(btrim(v_payload ->> 'message'), '');

    if v_title is null then
      raise exception
        'event_payload.title is required';
    end if;

    if v_message is null then
      raise exception
        'event_payload.message is required';
    end if;

    v_dedupe_key := coalesce(
      nullif(
        btrim(v_payload ->> 'dedupe_key'),
        ''
      ),
      'event:' || v_event.event_key
    );

    v_action_label :=
      nullif(
        btrim(v_payload ->> 'action_label'),
        ''
      );

    v_action_route :=
      nullif(
        btrim(v_payload ->> 'action_route'),
        ''
      );

    v_action_params := coalesce(
      v_payload -> 'action_params',
      '{}'::jsonb
    );

    if jsonb_typeof(v_action_params) <> 'object' then
      raise exception
        'event_payload.action_params must be a JSON object';
    end if;

    begin
      v_requested_at := coalesce(
        nullif(
          v_payload ->> 'scheduled_for',
          ''
        )::timestamptz,
        clock_timestamp()
      );
    exception
      when invalid_datetime_format then
        raise exception
          'event_payload.scheduled_for must be a valid timestamp';
    end;

    begin
      v_expires_at :=
        nullif(
          v_payload ->> 'expires_at',
          ''
        )::timestamptz;
    exception
      when invalid_datetime_format then
        raise exception
          'event_payload.expires_at must be a valid timestamp';
    end;

    if v_expires_at is not null
       and v_expires_at <= clock_timestamp() then
      raise exception
        'event_payload.expires_at must be in the future';
    end if;

    v_preference :=
      public.notification_effective_preference(
        v_recipient,
        v_category
      );

    v_allowed_at :=
      public.notification_next_allowed_at(
        v_recipient,
        v_category,
        v_priority,
        v_requested_at
      );

    if v_allowed_at is null then
      update public.notification_events
      set
        processing_status = 'Ignored',
        processed_at = clock_timestamp(),
        processing_error =
          'Suppressed by recipient notification preference'
      where id = v_event.id;

      perform public.notification_complete_job(
        p_job_id,
        p_worker_id
      );

      return null;
    end if;

    if v_expires_at is not null
       and v_allowed_at >= v_expires_at then
      update public.notification_events
      set
        processing_status = 'Ignored',
        processed_at = clock_timestamp(),
        processing_error =
          'Allowed delivery time is after notification expiry'
      where id = v_event.id;

      perform public.notification_complete_job(
        p_job_id,
        p_worker_id
      );

      return null;
    end if;

    v_status := case
      when v_allowed_at > clock_timestamp()
        then 'Scheduled'
      else 'Ready'
    end;

    update public.notification_events
    set
      processing_status = 'Processing',
      processed_at = null,
      processing_error = null
    where id = v_event.id;

    insert into public.notifications (
      event_id,
      recipient_user_id,
      category,
      severity,
      priority,
      title,
      message,
      entity_type,
      entity_id,
      employee_sys_id,
      project_id,
      action_label,
      action_route,
      action_params,
      status,
      scheduled_for,
      expires_at,
      dedupe_key,
      repeat_count,
      escalation_level
    )
    values (
      v_event.id,
      v_recipient,
      v_category,
      v_severity,
      v_priority,
      v_title,
      v_message,
      v_event.entity_type,
      v_event.entity_id,
      v_event.employee_sys_id,
      v_event.project_id,
      v_action_label,
      v_action_route,
      v_action_params,
      v_status,
      v_allowed_at,
      v_expires_at,
      v_dedupe_key,
      0,
      0
    )
    on conflict do nothing
    returning id
    into v_notification_id;

    if v_notification_id is null then
      select n.id
      into v_notification_id
      from public.notifications n
      where n.recipient_user_id = v_recipient
        and n.dedupe_key = v_dedupe_key
        and n.status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        )
      order by n.created_at desc
      limit 1;

      if v_notification_id is null then
        raise exception
          'Insert skipped but no open duplicate exists';
      end if;
    end if;

    update public.notification_events
    set
      processing_status = 'Processed',
      processed_at = clock_timestamp(),
      processing_error = null
    where id = v_event.id;

    perform public.notification_complete_job(
      p_job_id,
      p_worker_id
    );

    return v_notification_id;

  exception
    when others then
      update public.notification_events
      set
        processing_status = 'Failed',
        processed_at = null,
        processing_error = left(sqlerrm, 4000)
      where id = v_event.id;

      perform public.notification_fail_job(
        p_job_id,
        p_worker_id,
        sqlerrm,
        interval '5 minutes'
      );

      return null;
  end;
end
$function$;
ALTER FUNCTION public.notification_process_event_job(bigint,text) OWNER TO "postgres";

-- public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_record_web_push_result(p_job_id bigint, p_worker_id text, p_delivery_id bigint, p_success boolean, p_provider_status text DEFAULT NULL::text, p_provider_message_id text DEFAULT NULL::text, p_error_code text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_response_metadata jsonb DEFAULT '{}'::jsonb, p_revoke_subscription boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_delivery public.notification_deliveries%rowtype;
  v_subscription public.push_subscriptions%rowtype;
  v_metadata jsonb;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if p_delivery_id is null then
    raise exception
      'Delivery ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if p_success is null then
    raise exception
      'Success state is required';
  end if;

  if p_response_metadata is null
     or jsonb_typeof(
       p_response_metadata
     ) <> 'object' then
    raise exception
      'Response metadata must be a JSON object';
  end if;

  select job_row.*
  into v_job
  from public.notification_jobs job_row
  where job_row.id = p_job_id
    and job_row.job_type =
      'DeliverWebPush'
    and job_row.job_status =
      'Processing'
    and job_row.locked_by =
      btrim(p_worker_id)
  for update;

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select delivery_row.*
  into v_delivery
  from public.notification_deliveries
    delivery_row
  where delivery_row.id =
        p_delivery_id
    and delivery_row.notification_id =
        v_job.notification_id
    and delivery_row.channel =
        'WebPush'
    and delivery_row.delivery_status in (
      'Pending',
      'Failed',
      'Processing'
    )
  for update;

  if not found then
    raise exception
      'Web Push delivery % is unavailable for job %',
      p_delivery_id,
      p_job_id;
  end if;

  select subscription_row.*
  into v_subscription
  from public.push_subscriptions
    subscription_row
  where subscription_row.id =
        v_delivery.subscription_id
  for update;

  if not found then
    raise exception
      'Subscription for delivery % was not found',
      p_delivery_id;
  end if;

  v_metadata :=
    coalesce(
      v_delivery.response_metadata,
      '{}'::jsonb
    )
    || p_response_metadata
    || jsonb_build_object(
      'job_id',
        p_job_id,
      'worker_id',
        btrim(p_worker_id),
      'recorded_at',
        clock_timestamp()
    );

  if p_success then
    update public.notification_deliveries
    set
      delivery_status = 'Sent',
      attempt_number = greatest(
        attempt_number,
        v_job.attempt_count
      ),
      attempted_at = clock_timestamp(),
      sent_at = clock_timestamp(),
      delivered_at = null,
      failed_at = null,
      provider_status = nullif(
        btrim(
          coalesce(
            p_provider_status,
            ''
          )
        ),
        ''
      ),
      provider_message_id = nullif(
        btrim(
          coalesce(
            p_provider_message_id,
            ''
          )
        ),
        ''
      ),
      error_code = null,
      error_message = null,
      response_metadata = v_metadata
    where id = v_delivery.id
    returning *
    into v_delivery;

    update public.push_subscriptions
    set
      last_success_at =
        clock_timestamp(),
      failure_count = 0,
      last_failure_at = null
    where id = v_subscription.id
    returning *
    into v_subscription;

  else
    if nullif(
      btrim(
        coalesce(
          p_error_message,
          ''
        )
      ),
      ''
    ) is null then
      raise exception
        'Failure diagnostics are required';
    end if;

    update public.notification_deliveries
    set
      delivery_status = 'Failed',
      attempt_number = greatest(
        attempt_number,
        v_job.attempt_count
      ),
      attempted_at = clock_timestamp(),
      sent_at = null,
      delivered_at = null,
      failed_at = clock_timestamp(),
      provider_status = nullif(
        btrim(
          coalesce(
            p_provider_status,
            ''
          )
        ),
        ''
      ),
      provider_message_id = null,
      error_code = nullif(
        left(
          btrim(
            coalesce(
              p_error_code,
              ''
            )
          ),
          200
        ),
        ''
      ),
      error_message = left(
        btrim(p_error_message),
        4000
      ),
      response_metadata = v_metadata
    where id = v_delivery.id
    returning *
    into v_delivery;

    update public.push_subscriptions
    set
      failure_count =
        failure_count + 1,
      last_failure_at =
        clock_timestamp(),
      is_active = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then false
        else is_active
      end,
      permission_state = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then 'revoked'
        else permission_state
      end,
      revoked_at = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then coalesce(
          revoked_at,
          clock_timestamp()
        )
        else revoked_at
      end
    where id = v_subscription.id
    returning *
    into v_subscription;
  end if;

  return jsonb_build_object(
    'job_id',
      v_job.id,
    'delivery_id',
      v_delivery.id,
    'delivery_status',
      v_delivery.delivery_status,
    'subscription_id',
      v_subscription.id,
    'subscription_active',
      v_subscription.is_active,
    'permission_state',
      v_subscription.permission_state,
    'failure_count',
      v_subscription.failure_count,
    'subscription_revoked',
      v_subscription.revoked_at
        is not null
  );
end
$function$;
ALTER FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) OWNER TO "postgres";

-- public.notification_recover_stale_jobs(interval) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_recover_stale_jobs(p_stale_after interval DEFAULT '00:15:00'::interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_recovered integer := 0;
begin
  if p_stale_after is null
     or p_stale_after < interval '1 minute'
     or p_stale_after > interval '24 hours' then
    raise exception
      'Stale-lock interval must be between 1 minute and 24 hours';
  end if;

  with stale_jobs as (
    select j.id
    from public.notification_jobs j
    where j.job_status = 'Processing'
      and j.locked_at < clock_timestamp() - p_stale_after
    order by j.locked_at, j.id
    for update skip locked
  ),
  recovered as (
    update public.notification_jobs j
    set
      job_status = case
        when j.attempt_count >= j.maximum_attempts
          then 'DeadLetter'
        else 'Failed'
      end,
      run_at = case
        when j.attempt_count >= j.maximum_attempts
          then j.run_at
        else clock_timestamp() + interval '5 minutes'
      end,
      locked_at = null,
      locked_by = null,
      failed_at = clock_timestamp(),
      last_error = 'Stale processing lock recovered automatically'
    from stale_jobs s
    where j.id = s.id
    returning j.id
  )
  select count(*)
  into v_recovered
  from recovered;

  return v_recovered;
end
$function$;
ALTER FUNCTION public.notification_recover_stale_jobs(interval) OWNER TO "postgres";

-- public.notification_run_event_processor(text,integer,interval) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_run_event_processor(p_worker_id text, p_batch_size integer DEFAULT 20, p_stale_after interval DEFAULT '00:15:00'::interval)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_worker_id text;
  v_recovered integer := 0;
  v_enqueued integer := 0;
  v_claimed integer := 0;
  v_processed integer := 0;
  v_completed integer := 0;
  v_failed integer := 0;
  v_ignored integer := 0;

  v_job public.notification_jobs%rowtype;
  v_notification_id uuid;
  v_event_status text;
begin
  v_worker_id :=
    nullif(btrim(coalesce(p_worker_id, '')), '');

  if v_worker_id is null then
    raise exception 'Worker ID is required';
  end if;

  if length(v_worker_id) > 200 then
    raise exception
      'Worker ID cannot exceed 200 characters';
  end if;

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 100 then
    raise exception
      'Batch size must be between 1 and 100';
  end if;

  if p_stale_after is null
     or p_stale_after < interval '1 minute'
     or p_stale_after > interval '24 hours' then
    raise exception
      'Stale-lock interval must be between 1 minute and 24 hours';
  end if;

  v_recovered :=
    public.notification_recover_stale_jobs(
      p_stale_after
    );

  v_enqueued :=
    public.notification_enqueue_pending_events(
      p_batch_size
    );

  for v_job in
    with claimable as (
      select j.id
      from public.notification_jobs j
      where j.job_type = 'ProcessEvent'
        and j.job_status in ('Pending', 'Failed')
        and j.run_at <= clock_timestamp()
        and j.attempt_count < j.maximum_attempts
      order by j.run_at, j.id
      limit p_batch_size
      for update skip locked
    )
    update public.notification_jobs j
    set
      job_status = 'Processing',
      attempt_count = j.attempt_count + 1,
      locked_at = clock_timestamp(),
      locked_by = v_worker_id,
      started_at = clock_timestamp(),
      completed_at = null,
      failed_at = null,
      last_error = null
    from claimable c
    where j.id = c.id
    returning j.*
  loop
    v_claimed := v_claimed + 1;

    begin
      v_notification_id :=
        public.notification_process_event_job(
          v_job.id,
          v_worker_id
        );

      select e.processing_status
      into v_event_status
      from public.notification_events e
      where e.id = v_job.event_id;

      if v_event_status = 'Processed' then
        v_processed := v_processed + 1;
      elsif v_event_status = 'Ignored' then
        v_ignored := v_ignored + 1;
      elsif v_event_status = 'Failed' then
        v_failed := v_failed + 1;
      end if;

      if exists (
        select 1
        from public.notification_jobs j
        where j.id = v_job.id
          and j.job_status = 'Completed'
      ) then
        v_completed := v_completed + 1;
      elsif exists (
        select 1
        from public.notification_jobs j
        where j.id = v_job.id
          and j.job_status in ('Failed', 'DeadLetter')
      ) then
        v_failed := v_failed + 1;
      end if;

    exception
      when others then
        if exists (
          select 1
          from public.notification_jobs j
          where j.id = v_job.id
            and j.job_status = 'Processing'
            and j.locked_by = v_worker_id
        ) then
          perform public.notification_fail_job(
            v_job.id,
            v_worker_id,
            sqlerrm,
            interval '5 minutes'
          );
        end if;

        v_failed := v_failed + 1;
    end;
  end loop;

  return jsonb_build_object(
    'worker_id', v_worker_id,
    'stale_jobs_recovered', v_recovered,
    'events_enqueued', v_enqueued,
    'jobs_claimed', v_claimed,
    'jobs_completed', v_completed,
    'events_processed', v_processed,
    'events_ignored', v_ignored,
    'failures_observed', v_failed,
    'finished_at', clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_run_event_processor(text,integer,interval) OWNER TO "postgres";

-- public.notification_run_recurrence(integer) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_run_recurrence(p_batch_size integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_notification public.notifications%rowtype;
  v_rule public.notification_escalation_rules%rowtype;
  v_source jsonb;
  v_target uuid;

  v_examined integer := 0;
  v_resolved integer := 0;
  v_repeats_created integer := 0;
  v_escalations_created integer := 0;
  v_scope_rules_skipped integer := 0;
  v_missing_targets integer := 0;

  v_repeat_due boolean;
  v_escalation_due boolean;
  v_existing_escalation boolean;
begin
  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 200 then
    raise exception
      'Batch size must be between 1 and 200';
  end if;

  for v_notification in
    select n.*
    from public.notifications n
    where n.status in (
      'Scheduled',
      'Ready',
      'Delivered',
      'Read',
      'Actioned',
      'Snoozed',
      'Failed'
    )
      and n.parent_notification_id is null
    order by n.created_at, n.id
    limit p_batch_size
    for update skip locked
  loop
    v_examined := v_examined + 1;

    v_source :=
      public.notification_source_state(
        v_notification.entity_type,
        v_notification.entity_id
      );

    if coalesce(
      (v_source ->> 'supported')::boolean,
      false
    )
    and coalesce(
      (v_source ->> 'resolved')::boolean,
      false
    ) then

      update public.notifications
      set status = 'Completed'
      where id = v_notification.id
        and status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        );

      update public.notifications
      set status = 'Cancelled'
      where parent_notification_id =
            v_notification.id
        and status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        );

      update public.notification_jobs
      set
        job_status = 'Cancelled',
        locked_at = null,
        locked_by = null
      where notification_id in (
        select n.id
        from public.notifications n
        where n.id = v_notification.id
           or n.parent_notification_id =
              v_notification.id
      )
        and job_status in (
          'Pending',
          'Processing',
          'Failed'
        );

      v_resolved := v_resolved + 1;
      continue;
    end if;


    for v_rule in
      select r.*
      from public.notification_escalation_rules r
      where r.is_enabled = true
        and r.category =
            v_notification.category
        and (
          r.event_type is null
          or exists (
            select 1
            from public.notification_events e
            where e.id =
                  v_notification.event_id
              and e.event_type =
                  r.event_type
          )
        )
        and public.notification_priority_rank(
          v_notification.priority
        ) >= public.notification_priority_rank(
          r.source_priority
        )
      order by r.id
    loop
      v_repeat_due :=
        v_rule.repeat_every_minutes is not null
        and coalesce(
          v_notification.repeat_count,
          0
        ) < coalesce(
          v_rule.maximum_repeat_count,
          0
        )
        and clock_timestamp() >=
          v_notification.created_at
          + make_interval(
              mins =>
                coalesce(
                  v_rule.first_repeat_after_minutes,
                  v_rule.repeat_every_minutes
                )
                +
                (
                  coalesce(
                    v_notification.repeat_count,
                    0
                  )
                  *
                  v_rule.repeat_every_minutes
                )
            );

      if v_repeat_due then
        insert into public.notifications (
          event_id,
          recipient_user_id,
          category,
          severity,
          priority,
          title,
          message,
          entity_type,
          entity_id,
          employee_sys_id,
          project_id,
          action_label,
          action_route,
          action_params,
          status,
          scheduled_for,
          expires_at,
          dedupe_key,
          repeat_count,
          escalation_level,
          parent_notification_id,
          escalation_rule_id
        )
        values (
          v_notification.event_id,
          v_notification.recipient_user_id,
          v_notification.category,
          v_notification.severity,
          v_notification.priority,
          v_notification.title,
          v_notification.message,
          v_notification.entity_type,
          v_notification.entity_id,
          v_notification.employee_sys_id,
          v_notification.project_id,
          v_notification.action_label,
          v_notification.action_route,
          v_notification.action_params,
          'Ready',
          clock_timestamp(),
          v_notification.expires_at,
          v_notification.dedupe_key ||
            ':repeat:' ||
            (
              v_notification.repeat_count + 1
            )::text,
          v_notification.repeat_count + 1,
          v_notification.escalation_level,
          v_notification.id,
          v_rule.id
        )
        on conflict do nothing;

        if found then
          update public.notifications
          set repeat_count =
                repeat_count + 1
          where id = v_notification.id;

          v_notification.repeat_count :=
            v_notification.repeat_count + 1;

          v_repeats_created :=
            v_repeats_created + 1;
        end if;
      end if;


      v_escalation_due :=
        clock_timestamp() >=
          v_notification.created_at
          + make_interval(
              mins =>
                v_rule.escalation_after_minutes
            );

      if not v_escalation_due then
        continue;
      end if;

      select exists (
        select 1
        from public.notifications child
        where child.parent_notification_id =
              v_notification.id
          and child.escalation_rule_id =
              v_rule.id
          and child.escalation_level > 0
      )
      into v_existing_escalation;

      if v_existing_escalation then
        continue;
      end if;

      if v_rule.project_scope_required then
        v_scope_rules_skipped :=
          v_scope_rules_skipped + 1;
        continue;
      end if;


      if v_rule.escalation_target_user_id
         is not null then

        if exists (
          select 1
          from public.profiles p
          where p.id =
                v_rule.escalation_target_user_id
            and p.is_active = true
        ) then
          v_target :=
            v_rule.escalation_target_user_id;
        else
          v_target := null;
          v_missing_targets :=
            v_missing_targets + 1;
        end if;

        if v_target is not null then
          insert into public.notifications (
            event_id,
            recipient_user_id,
            category,
            severity,
            priority,
            title,
            message,
            entity_type,
            entity_id,
            employee_sys_id,
            project_id,
            action_label,
            action_route,
            action_params,
            status,
            scheduled_for,
            expires_at,
            dedupe_key,
            repeat_count,
            escalation_level,
            parent_notification_id,
            escalation_rule_id
          )
          values (
            v_notification.event_id,
            v_target,
            v_notification.category,
            v_notification.severity,
            v_notification.priority,
            v_notification.title,
            v_notification.message,
            v_notification.entity_type,
            v_notification.entity_id,
            v_notification.employee_sys_id,
            v_notification.project_id,
            v_notification.action_label,
            v_notification.action_route,
            v_notification.action_params,
            'Ready',
            clock_timestamp(),
            v_notification.expires_at,
            v_notification.dedupe_key ||
              ':escalation:' ||
              v_rule.id::text ||
              ':' ||
              v_target::text,
            0,
            v_notification.escalation_level + 1,
            v_notification.id,
            v_rule.id
          )
          on conflict do nothing;

          if found then
            v_escalations_created :=
              v_escalations_created + 1;
          end if;
        end if;


      elsif v_rule.escalation_target_role
            is not null then

        for v_target in
          select p.id
          from public.profiles p
          where p.is_active = true
            and p.role =
                v_rule.escalation_target_role
          order by p.id
        loop
          insert into public.notifications (
            event_id,
            recipient_user_id,
            category,
            severity,
            priority,
            title,
            message,
            entity_type,
            entity_id,
            employee_sys_id,
            project_id,
            action_label,
            action_route,
            action_params,
            status,
            scheduled_for,
            expires_at,
            dedupe_key,
            repeat_count,
            escalation_level,
            parent_notification_id,
            escalation_rule_id
          )
          values (
            v_notification.event_id,
            v_target,
            v_notification.category,
            v_notification.severity,
            v_notification.priority,
            v_notification.title,
            v_notification.message,
            v_notification.entity_type,
            v_notification.entity_id,
            v_notification.employee_sys_id,
            v_notification.project_id,
            v_notification.action_label,
            v_notification.action_route,
            v_notification.action_params,
            'Ready',
            clock_timestamp(),
            v_notification.expires_at,
            v_notification.dedupe_key ||
              ':escalation:' ||
              v_rule.id::text ||
              ':' ||
              v_target::text,
            0,
            v_notification.escalation_level + 1,
            v_notification.id,
            v_rule.id
          )
          on conflict do nothing;

          if found then
            v_escalations_created :=
              v_escalations_created + 1;
          end if;
        end loop;

        if not found then
          v_missing_targets :=
            v_missing_targets + 1;
        end if;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'notifications_examined',
      v_examined,
    'resolved_notifications_completed',
      v_resolved,
    'repeat_notifications_created',
      v_repeats_created,
    'escalation_notifications_created',
      v_escalations_created,
    'project_scope_rules_skipped',
      v_scope_rules_skipped,
    'missing_or_inactive_targets',
      v_missing_targets,
    'finished_at',
      clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_run_recurrence(integer) OWNER TO "postgres";

-- public.notification_run_server_processor(text,integer,interval) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_run_server_processor(p_worker_id text DEFAULT NULL::text, p_batch_size integer DEFAULT 25, p_stale_after interval DEFAULT '00:15:00'::interval)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_worker_id text;
  v_started_at timestamptz;
  v_event_result jsonb;
  v_recurrence_result jsonb;
  v_delivery_result jsonb;
begin
  v_started_at := clock_timestamp();

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 100 then
    raise exception
      'Batch size must be between 1 and 100';
  end if;

  if p_stale_after is null
     or p_stale_after < interval '1 minute'
     or p_stale_after > interval '24 hours' then
    raise exception
      'Stale-lock interval must be between 1 minute and 24 hours';
  end if;

  v_worker_id := nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  );

  if v_worker_id is null then
    v_worker_id :=
      'notification-processor:' ||
      pg_backend_pid()::text ||
      ':' ||
      to_char(
        v_started_at at time zone 'UTC',
        'YYYYMMDDHH24MISSMS'
      );
  end if;

  if length(v_worker_id) > 200 then
    raise exception
      'Worker ID cannot exceed 200 characters';
  end if;

  /*
   * Stage 1:
   * Recover stale locks, enqueue pending events,
   * claim due ProcessEvent jobs and process them.
   */
  v_event_result :=
    public.notification_run_event_processor(
      v_worker_id,
      p_batch_size,
      p_stale_after
    );

  /*
   * Stage 2:
   * Resolve completed workflow sources,
   * generate only configured bounded repeats/escalations.
   */
  v_recurrence_result :=
    public.notification_run_recurrence(
      p_batch_size
    );

  /*
   * Stage 3:
   * Promote due notifications and prepare
   * authoritative Inbox/Web Push delivery records.
   */
  v_delivery_result :=
    public.notification_prepare_deliveries(
      p_batch_size
    );

  return jsonb_build_object(
    'worker_id', v_worker_id,
    'batch_size', p_batch_size,
    'started_at', v_started_at,
    'event_processor', v_event_result,
    'recurrence_processor', v_recurrence_result,
    'delivery_processor', v_delivery_result,
    'finished_at', clock_timestamp()
  );
end
$function$;
ALTER FUNCTION public.notification_run_server_processor(text,integer,interval) OWNER TO "postgres";

-- public.notification_source_state(text,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_source_state(p_entity_type text, p_entity_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_type text;
  v_id bigint;
begin
  v_type := lower(
    btrim(
      coalesce(p_entity_type, '')
    )
  );

  if v_type = ''
     or nullif(
       btrim(coalesce(p_entity_id, '')),
       ''
     ) is null then
    return jsonb_build_object(
      'supported', false,
      'resolved', false,
      'state', 'Source reference unavailable'
    );
  end if;

  if p_entity_id !~ '^[0-9]+$' then
    return jsonb_build_object(
      'supported', false,
      'resolved', false,
      'state', 'Non-numeric source identifier'
    );
  end if;

  v_id := p_entity_id::bigint;

  begin
    if v_type in (
      'todo',
      'transfer',
      'exit'
    ) then
      return
        public.notification_check_core_source(
          v_type,
          v_id
        ) ||
        jsonb_build_object(
          'supported',
          true
        );

    elsif v_type = 'leave' then
      return
        public.notification_check_leave_source(
          v_id
        ) ||
        jsonb_build_object(
          'supported',
          true
        );

    elsif v_type in (
      'uniform_supply_order',
      'uniform_delivery_issue',
      'uniform_delivery_bill'
    ) then
      return
        public.notification_check_uniform_source(
          v_type,
          v_id
        ) ||
        jsonb_build_object(
          'supported',
          true
        );

    else
      return jsonb_build_object(
        'supported', false,
        'resolved', false,
        'state', 'Unsupported source type',
        'entity_type', v_type,
        'entity_id', p_entity_id
      );
    end if;

  exception
    when no_data_found then
      return jsonb_build_object(
        'supported', true,
        'resolved', false,
        'state', 'Source workflow record not found',
        'entity_type', v_type,
        'entity_id', p_entity_id
      );

    when sqlstate 'P0002' then
      return jsonb_build_object(
        'supported', true,
        'resolved', false,
        'state', 'Source workflow record not found',
        'entity_type', v_type,
        'entity_id', p_entity_id
      );
  end;
end
$function$;
ALTER FUNCTION public.notification_source_state(text,text) OWNER TO "postgres";
