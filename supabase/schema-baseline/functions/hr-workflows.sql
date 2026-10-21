-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- public.cancel_exit(bigint,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.cancel_exit(p_exit_id bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_exit public.exits%rowtype;
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Cancellation reason is required';
  end if;

  select * into v_exit
    from public.exits
   where id = p_exit_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Exit workflow not found';
  end if;

  if v_exit.status not in ('Draft', 'Clearance Pending') then
    raise exception using errcode = '23514',
      message = format('Exit cannot be cancelled from status %s', v_exit.status);
  end if;

  update public.exits
     set status = 'Cancelled',
         cancelled_at = now(),
         cancelled_by = auth.uid(),
         cancellation_reason = btrim(p_reason),
         updated_at = now()
   where id = v_exit.id
   returning * into v_exit;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (auth.uid(), 'cancel', 'exits', v_exit.id::text, 'Exit cancelled: ' || p_reason);

  return to_jsonb(v_exit);
end;
$function$;
ALTER FUNCTION public.cancel_exit(bigint,text) OWNER TO "postgres";

-- public.cancel_transfer(bigint,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.cancel_transfer(p_transfer_id bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_transfer public.transfers%rowtype;
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Cancellation reason is required';
  end if;

  select * into v_transfer
    from public.transfers
   where id = p_transfer_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Transfer not found';
  end if;

  if v_transfer.status not in ('Draft', 'Scheduled', 'Joining Pending', 'Not Joined') then
    raise exception using errcode = '23514',
      message = format('Transfer cannot be cancelled from status %s', v_transfer.status);
  end if;

  update public.transfers
     set status = 'Cancelled',
         cancelled_at = now(),
         cancelled_by = auth.uid(),
         cancellation_reason = btrim(p_reason),
         updated_at = now()
   where id = v_transfer.id
   returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'cancel', 'transfers', v_transfer.id::text,
    format('Transfer cancelled for employee system ID %s: %s',
      v_transfer.employee_sys_id, p_reason)
  );

  return to_jsonb(v_transfer);
end;
$function$;
ALTER FUNCTION public.cancel_transfer(bigint,text) OWNER TO "postgres";

-- public.commit_exit(jsonb) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.commit_exit(p_exit jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_created jsonb;
  v_exit_id bigint;
  v_exit_date date;
  v_exit_type text;
  v_exit_reason text;
begin
  v_exit_date := nullif(coalesce(p_exit->>'effective_exit_date', p_exit->>'exit_date'), '')::date;
  v_exit_type := coalesce(nullif(p_exit->>'exit_type', ''), 'Other');
  v_exit_reason := coalesce(nullif(p_exit->>'exit_reason', ''), v_exit_type);

  v_created := public.create_exit_draft(p_exit || jsonb_build_object('clearance_pending', false));
  v_exit_id := (v_created->'exit'->>'id')::bigint;

  return public.complete_exit(
    v_exit_id,
    v_exit_date,
    v_exit_type,
    v_exit_reason,
    p_exit->>'completion_remarks'
  );
end;
$function$;
ALTER FUNCTION public.commit_exit(jsonb) OWNER TO "postgres";

-- public.commit_transfer(jsonb,boolean) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.commit_transfer(p_transfer jsonb, p_apply_now boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- Never call confirm_transfer_joining here. An order created today or in the
  -- past must remain Joining Pending until the explicit confirmation RPC runs.
  return public.create_transfer_order(p_transfer);
end;
$function$;
ALTER FUNCTION public.commit_transfer(jsonb,boolean) OWNER TO "postgres";

-- public.complete_exit(bigint,date,text,text,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.complete_exit(p_exit_id bigint, p_exit_date date, p_exit_type text, p_exit_reason text, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_exit public.exits%rowtype;
  v_employee public.employees%rowtype;
  v_blocking_transfer_id bigint;
  v_join_date date;
begin
  if p_exit_date is null then
    raise exception using errcode = '23514', message = 'Exit date is required';
  end if;

  if nullif(btrim(coalesce(p_exit_type, '')), '') is null then
    raise exception using errcode = '23514', message = 'Exit type is required';
  end if;

  if nullif(btrim(coalesce(p_exit_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Exit reason is required';
  end if;

  select * into v_exit
    from public.exits
   where id = p_exit_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Exit workflow not found';
  end if;

  if v_exit.status not in ('Draft', 'Clearance Pending') then
    raise exception using errcode = '23514',
      message = format('Exit cannot be completed from status %s', v_exit.status);
  end if;

  select * into v_employee
    from public.employees
   where id = v_exit.employee_sys_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Employee not found';
  end if;

  if v_employee.status = 'Exited' then
    raise exception using errcode = '23514', message = 'Employee is already Exited';
  end if;

  if v_employee.join_date ~ '^\d{4}-\d{2}-\d{2}$' then
    v_join_date := v_employee.join_date::date;
    if p_exit_date < v_join_date then
      raise exception using errcode = '23514', message = 'Exit date cannot be before join date';
    end if;
  end if;

  select t.id into v_blocking_transfer_id
    from public.transfers t
   where t.employee_sys_id = v_employee.id
     and t.deleted_at is null
     and t.status in ('Draft', 'Scheduled', 'Joining Pending')
   limit 1;

  if v_blocking_transfer_id is not null then
    raise exception using errcode = '23514',
      message = format('Pending transfer %s must be cancelled or marked Not Joined before exit completion',
        v_blocking_transfer_id);
  end if;

  update public.exits
     set status = 'Completed',
         exit_type = btrim(p_exit_type),
         exit_reason = btrim(p_exit_reason),
         exit_date = p_exit_date::text,
         effective_exit_date = p_exit_date,
         completion_remarks = nullif(btrim(coalesce(p_remarks, '')), ''),
         completed_at = now(),
         completed_by = auth.uid(),
         updated_at = now()
   where id = v_exit.id
   returning * into v_exit;

  update public.employees
     set status = 'Exited',
         exit_date = p_exit_date::text,
         exit_reason = btrim(p_exit_reason),
         updated_at = now()
   where id = v_employee.id
   returning * into v_employee;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'complete', 'exits', v_exit.id::text,
    format('Employee system ID %s exited on %s (%s)',
      v_employee.id, p_exit_date, p_exit_type)
  );

  return jsonb_build_object('exit', to_jsonb(v_exit), 'employee', to_jsonb(v_employee));
end;
$function$;
ALTER FUNCTION public.complete_exit(bigint,date,text,text,text) OWNER TO "postgres";

-- public.confirm_transfer_joining(bigint,date,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.confirm_transfer_joining(p_transfer_id bigint, p_actual_joining_date date, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
declare
  v_transfer public.transfers%rowtype;
  v_employee public.employees%rowtype;
begin
  if p_actual_joining_date is null then
    raise exception using errcode = '23514', message = 'Actual joining date is required';
  end if;
  if p_actual_joining_date > current_date then
    raise exception using errcode = '23514', message = 'Actual joining date cannot be in the future';
  end if;

  select * into v_transfer
    from public.transfers
   where id = p_transfer_id and deleted_at is null
   for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Transfer not found';
  end if;

  if v_transfer.status not in ('Scheduled', 'Joining Pending') then
    raise exception using errcode = '23514',
      message = format('Transfer cannot be confirmed from status %s', v_transfer.status);
  end if;
  if v_transfer.effective_date is null then
    raise exception using errcode = '23514', message = 'Transfer effective date is missing';
  end if;
  if v_transfer.effective_date > current_date then
    raise exception using errcode = '23514', message = 'Transfer is not yet due';
  end if;
  if p_actual_joining_date < v_transfer.effective_date then
    raise exception using errcode = '23514', message = 'Actual joining date cannot be before the effective date';
  end if;

  select * into v_employee
    from public.employees
   where id = v_transfer.employee_sys_id and deleted_at is null
   for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Employee not found';
  end if;
  if lower(btrim(coalesce(v_employee.status, ''))) <> 'active' then
    raise exception using errcode = '23514', message = 'Inactive employee cannot complete a transfer';
  end if;
  if lower(btrim(coalesce(v_employee.project_name, ''))) <>
     lower(btrim(coalesce(v_transfer.current_project, ''))) then
    raise exception using errcode = '40001',
      message = 'Employee current project no longer matches the transfer source project';
  end if;

  update public.employees
     set project_name = v_transfer.new_project, updated_at = now()
   where id = v_employee.id
   returning * into v_employee;

  update public.transfers
     set status = 'Completed',
         actual_joining_date = p_actual_joining_date,
         joining_confirmed_at = now(), joining_confirmed_by = auth.uid(),
         completed_at = now(), completed_by = auth.uid(),
         notes = case
           when nullif(btrim(coalesce(p_remarks, '')), '') is null then notes
           when nullif(btrim(coalesce(notes, '')), '') is null then p_remarks
           else notes || E'\nJoining confirmation: ' || p_remarks
         end,
         updated_at = now()
   where id = v_transfer.id
   returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'complete', 'transfers', v_transfer.id::text,
    format('Joining confirmed for employee system ID %s at %s', v_employee.id, v_transfer.new_project)
  );

  return jsonb_build_object('transfer', to_jsonb(v_transfer), 'employee', to_jsonb(v_employee));
end;
$function$;
ALTER FUNCTION public.confirm_transfer_joining(bigint,date,text) OWNER TO "postgres";

-- public.create_exit_draft(jsonb) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.create_exit_draft(p_exit jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_employee public.employees%rowtype;
  v_exit public.exits%rowtype;
  v_employee_id bigint;
  v_related_transfer_id bigint;
  v_existing_exit_id bigint;
  v_exit_date date;
begin
  v_employee_id := nullif(p_exit->>'employee_sys_id', '')::bigint;
  if v_employee_id is null then
    raise exception using errcode = '22023', message = 'employee_sys_id is required';
  end if;

  select * into v_employee
    from public.employees
   where id = v_employee_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Employee not found';
  end if;

  if v_employee.status = 'Exited' then
    raise exception using errcode = '23514', message = 'Employee is already Exited';
  end if;

  select id into v_existing_exit_id
    from public.exits
   where employee_sys_id = v_employee_id
     and deleted_at is null
     and status in ('Draft', 'Clearance Pending')
   limit 1;

  if v_existing_exit_id is not null then
    raise exception using errcode = '23505',
      message = format('Employee already has an open exit workflow (ID %s)', v_existing_exit_id);
  end if;

  v_related_transfer_id := nullif(p_exit->>'related_transfer_id', '')::bigint;
  v_exit_date := nullif(coalesce(p_exit->>'effective_exit_date', p_exit->>'exit_date'), '')::date;

  insert into public.exits (
    employee_sys_id,
    employee_id,
    full_name,
    designation,
    current_project,
    join_date,
    exit_reason,
    exit_type,
    exit_date,
    effective_exit_date,
    issue_date,
    related_transfer_id,
    status,
    completion_remarks
  ) values (
    v_employee.id,
    v_employee.employee_id,
    v_employee.full_name,
    v_employee.designation,
    v_employee.project_name,
    v_employee.join_date,
    p_exit->>'exit_reason',
    p_exit->>'exit_type',
    case when v_exit_date is null then null else v_exit_date::text end,
    v_exit_date,
    coalesce(nullif(p_exit->>'issue_date', ''), current_date::text),
    v_related_transfer_id,
    case when coalesce((p_exit->>'clearance_pending')::boolean, false)
      then 'Clearance Pending' else 'Draft' end,
    p_exit->>'completion_remarks'
  ) returning * into v_exit;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'create', 'exits', v_exit.id::text,
    format('Exit workflow created for employee system ID %s', v_employee.id)
  );

  return jsonb_build_object('exit', to_jsonb(v_exit), 'employee', to_jsonb(v_employee));
end;
$function$;
ALTER FUNCTION public.create_exit_draft(jsonb) OWNER TO "postgres";

-- public.create_transfer_order(jsonb) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.create_transfer_order(p_transfer jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
declare
  v_employee public.employees%rowtype;
  v_transfer public.transfers%rowtype;
  v_employee_id bigint;
  v_destination text;
  v_effective_date date;
  v_issue_date text;
  v_status text;
  v_open_transfer_id bigint;
begin
  v_employee_id := nullif(p_transfer->>'employee_sys_id', '')::bigint;
  if v_employee_id is null then
    raise exception using errcode = '22023', message = 'employee_sys_id is required';
  end if;

  select * into v_employee
    from public.employees
   where id = v_employee_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Employee not found';
  end if;

  if lower(btrim(coalesce(v_employee.status, ''))) <> 'active' then
    raise exception using errcode = '23514', message = 'Only Active employees can be transferred';
  end if;

  v_destination := nullif(btrim(coalesce(p_transfer->>'new_project', '')), '');
  if v_destination is null then
    raise exception using errcode = '23514', message = 'Destination project is required';
  end if;

  if lower(btrim(coalesce(v_employee.project_name, ''))) = lower(v_destination) then
    raise exception using errcode = '23514', message = 'Source and destination projects cannot be the same';
  end if;

  if nullif(btrim(coalesce(p_transfer->>'current_project', '')), '') is not null
     and lower(btrim(p_transfer->>'current_project')) <> lower(btrim(coalesce(v_employee.project_name, ''))) then
    raise exception using errcode = '40001', message = 'Employee current project changed. Reload and try again';
  end if;

  v_effective_date := coalesce(
    nullif(p_transfer->>'effective_date', '')::date,
    nullif(p_transfer->>'transfer_date', '')::date
  );

  if v_effective_date is null then
    raise exception using errcode = '23514', message = 'Transfer effective date is required';
  end if;

  select id into v_open_transfer_id
    from public.transfers
   where employee_sys_id = v_employee_id
     and deleted_at is null
     and status in ('Draft', 'Scheduled', 'Joining Pending', 'Not Joined')
   limit 1;

  if v_open_transfer_id is not null then
    raise exception using errcode = '23505',
      message = format('Employee already has an unresolved transfer (ID %s)', v_open_transfer_id);
  end if;

  v_status := case when v_effective_date <= current_date then 'Joining Pending' else 'Scheduled' end;
  v_issue_date := coalesce(nullif(p_transfer->>'issues_date', ''), current_date::text);

  insert into public.transfers (
    employee_sys_id, employee_id, employee_id_bn,
    full_name, full_name_bn, designation, designation_bn,
    current_project, current_project_bn, new_project, new_project_bn,
    transfer_date, transfer_date_bn, effective_date,
    issues_date, issues_date_bn, status, notes
  ) values (
    v_employee.id, v_employee.employee_id, p_transfer->>'employee_id_bn',
    v_employee.full_name, v_employee.full_name_bn, v_employee.designation, p_transfer->>'designation_bn',
    v_employee.project_name, p_transfer->>'current_project_bn', v_destination, p_transfer->>'new_project_bn',
    v_effective_date::text, p_transfer->>'transfer_date_bn', v_effective_date,
    v_issue_date, p_transfer->>'issues_date_bn', v_status, p_transfer->>'notes'
  ) returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'create', 'transfers', v_transfer.id::text,
    format('Transfer created for employee system ID %s: %s to %s',
      v_employee.id, coalesce(v_employee.project_name, 'Unassigned'), v_destination)
  );

  return jsonb_build_object('transfer', to_jsonb(v_transfer), 'employee', to_jsonb(v_employee));
end;
$function$;
ALTER FUNCTION public.create_transfer_order(jsonb) OWNER TO "postgres";

-- public.get_transfer_action_queue() | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.get_transfer_action_queue()
 RETURNS TABLE(transfer_id bigint, employee_sys_id bigint, employee_id text, full_name text, designation text, current_project text, new_project text, effective_date date, stored_status text, queue_status text, overdue_days integer, not_joined_reason text, not_joined_remarks text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
  select
    t.id,
    t.employee_sys_id,
    t.employee_id,
    t.full_name,
    t.designation,
    t.current_project,
    t.new_project,
    t.effective_date,
    t.status,
    case
      when t.status = 'Scheduled' and t.effective_date <= current_date then 'Joining Pending'
      else t.status
    end,
    case
      when t.effective_date is null or t.effective_date > current_date then 0
      else (current_date - t.effective_date)::integer
    end,
    t.not_joined_reason,
    t.not_joined_remarks
  from public.transfers t
  where t.deleted_at is null
    and t.status in ('Scheduled', 'Joining Pending', 'Not Joined')
  order by
    case
      when t.status = 'Not Joined' then 0
      when t.effective_date < current_date then 1
      when t.effective_date = current_date then 2
      else 3
    end,
    t.effective_date,
    t.id;
$function$;
ALTER FUNCTION public.get_transfer_action_queue() OWNER TO "postgres";

-- public.mark_transfer_not_joined(bigint,text,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.mark_transfer_not_joined(p_transfer_id bigint, p_reason text, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
declare
  v_transfer public.transfers%rowtype;
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Not-joined reason is required';
  end if;

  select * into v_transfer
    from public.transfers
   where id = p_transfer_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Transfer not found';
  end if;

  if v_transfer.status not in ('Scheduled', 'Joining Pending') then
    raise exception using errcode = '23514',
      message = format('Transfer cannot be marked Not Joined from status %s', v_transfer.status);
  end if;

  if v_transfer.effective_date > current_date then
    raise exception using errcode = '23514', message = 'Transfer is not yet due';
  end if;

  update public.transfers
     set status = 'Not Joined',
         not_joined_at = now(),
         not_joined_by = auth.uid(),
         not_joined_reason = btrim(p_reason),
         not_joined_remarks = nullif(btrim(coalesce(p_remarks, '')), ''),
         updated_at = now()
   where id = v_transfer.id
   returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'not_joined', 'transfers', v_transfer.id::text,
    format('Employee system ID %s did not join destination project: %s',
      v_transfer.employee_sys_id, p_reason)
  );

  return to_jsonb(v_transfer);
end;
$function$;
ALTER FUNCTION public.mark_transfer_not_joined(bigint,text,text) OWNER TO "postgres";

-- public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.mghrm_save_meeting_attendance(p_date date, p_expected jsonb, p_rows jsonb, p_metadata jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  m public.meetings%ROWTYPE;
  old_row public.meeting_attendance%ROWTYPE;
  item jsonb;
  actual_versions jsonb;
  expected_versions jsonb;
  result_rows jsonb;
  is_retry boolean := false;
BEGIN
  IF auth.uid() IS NULL OR coalesce(public.my_role(), 'none') NOT IN ('admin', 'editor') THEN
    RAISE EXCEPTION 'Meeting write permission required' USING ERRCODE = '42501';
  END IF;
  IF p_date IS NULL OR p_request_id IS NULL OR
     jsonb_typeof(p_expected) IS DISTINCT FROM 'object' OR
     NOT (p_expected ?& ARRAY['meeting','rows']) OR
     jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR
     jsonb_typeof(p_expected->'rows') IS DISTINCT FROM 'array' OR
     jsonb_typeof(p_metadata) IS DISTINCT FROM 'object' OR
     NOT (p_metadata ?& ARRAY['agenda','started_at','ended_at']) OR
     (p_metadata - ARRAY['agenda','started_at','ended_at']) <> '{}'::jsonb OR
     jsonb_typeof(p_metadata->'agenda') NOT IN ('string','null') OR
     jsonb_typeof(p_metadata->'started_at') NOT IN ('string','null') OR
     jsonb_typeof(p_metadata->'ended_at') NOT IN ('string','null') THEN
    RAISE EXCEPTION 'Invalid attendance request';
  END IF;
  -- Missing fields are NOT intentional blanks. Validate before any mutation.
  FOR item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR
       NOT (item ?& ARRAY['project_name','status','remarks','employee_id','full_name','designation','sort_order']) OR
       (item - ARRAY['project_name','status','remarks','employee_id','full_name','designation','sort_order']) <> '{}'::jsonb OR
       jsonb_typeof(item->'project_name') IS DISTINCT FROM 'string' OR
       jsonb_typeof(item->'status') NOT IN ('string','null') OR
       jsonb_typeof(item->'remarks') NOT IN ('string','null') OR
       jsonb_typeof(item->'employee_id') NOT IN ('string','null') OR
       jsonb_typeof(item->'full_name') NOT IN ('string','null') OR
       jsonb_typeof(item->'designation') NOT IN ('string','null') OR
       jsonb_typeof(item->'sort_order') NOT IN ('number','null') THEN
      RAISE EXCEPTION 'Incomplete or invalid attendance row';
    END IF;
  END LOOP;
  -- Also serializes ordinary REST writes during snapshot validation and commit.
  LOCK TABLE public.meetings, public.meeting_attendance IN SHARE ROW EXCLUSIVE MODE;
  IF (SELECT count(*) FROM public.meetings WHERE meeting_date = p_date::text AND deleted_at IS NULL) > 1 THEN
    RAISE EXCEPTION 'Ambiguous meeting date';
  END IF;
  SELECT * INTO m FROM public.meetings WHERE meeting_date = p_date::text AND deleted_at IS NULL;
  IF m.id IS NOT NULL AND nullif(btrim(m.meeting_id), '') IS NULL THEN
    RAISE EXCEPTION 'Existing meeting identifier requires review';
  END IF;
  -- A legacy NULL date is valid through its exact parent meeting_id. Existing
  -- NULL dates are preserved by UPDATE below; contradictory non-NULL dates fail.
  -- Check identity for retries as well, including writes by legacy clients.
  IF EXISTS (SELECT 1 FROM public.meeting_attendance
             WHERE deleted_at IS NULL AND
               ((meeting_date = p_date AND meeting_id IS DISTINCT FROM m.meeting_id) OR
                (meeting_id = m.meeting_id AND meeting_date IS NOT NULL AND meeting_date IS DISTINCT FROM p_date))) THEN
    RAISE EXCEPTION 'Attendance meeting/date identity mismatch';
  END IF;
  is_retry := m.id IS NOT NULL AND m.attendance_request_id = p_request_id;
  IF coalesce(is_retry, false) AND
    (m.agenda IS DISTINCT FROM p_metadata->>'agenda' OR
     m.started_at IS DISTINCT FROM (p_metadata->>'started_at')::timestamptz OR
     m.ended_at IS DISTINCT FROM (p_metadata->>'ended_at')::timestamptz) THEN
    RAISE EXCEPTION 'Meeting metadata changed after save; reload' USING ERRCODE = '40001';
  END IF;
  IF NOT coalesce(is_retry, false) THEN
    IF m.id IS NULL THEN
      IF p_expected->'meeting' IS DISTINCT FROM 'null'::jsonb OR
         EXISTS (SELECT 1 FROM public.meetings WHERE meeting_date = p_date::text) OR
         EXISTS (SELECT 1 FROM public.meeting_attendance WHERE meeting_date = p_date) THEN
        RAISE EXCEPTION 'Existing or historical records require review; reload';
      END IF;
    ELSIF (p_expected->'meeting'->>'id') IS DISTINCT FROM m.id::text OR
          (p_expected->'meeting'->>'updated_at')::timestamptz IS DISTINCT FROM m.updated_at THEN
      RAISE EXCEPTION 'Meeting changed on another device; reload before editing' USING ERRCODE = '40001';
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'version', updated_at) ORDER BY id), '[]'::jsonb)
      INTO actual_versions FROM public.meeting_attendance
      WHERE meeting_id = m.meeting_id AND deleted_at IS NULL;
    SELECT coalesce(jsonb_agg(jsonb_build_object('id', (r->>'id')::bigint,
        'version', (r->>'updated_at')::timestamptz) ORDER BY (r->>'id')::bigint), '[]'::jsonb)
      INTO expected_versions FROM jsonb_array_elements(p_expected->'rows') r;
    IF actual_versions IS DISTINCT FROM expected_versions THEN
      RAISE EXCEPTION 'Attendance changed on another device; reload before editing' USING ERRCODE = '40001';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) r
      WHERE nullif(btrim(r->>'project_name'), '') IS NULL OR
        (r->>'status' IS NOT NULL AND r->>'status' NOT IN ('Present','Absent',''))) OR
     (SELECT count(*) FROM jsonb_array_elements(p_rows)) <>
     (SELECT count(DISTINCT r->>'project_name') FROM jsonb_array_elements(p_rows) r) THEN
    RAISE EXCEPTION 'Invalid or duplicate attendance project/status';
  END IF;
  IF EXISTS (SELECT 1 FROM public.meeting_attendance a
      WHERE a.meeting_id = m.meeting_id AND a.deleted_at IS NULL AND
        NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) r WHERE r->>'project_name' = a.project_name)) THEN
    RAISE EXCEPTION 'Incomplete attendance set; existing rows must be preserved';
  END IF;
  IF NOT coalesce(is_retry, false) THEN
    IF m.id IS NULL THEN
      INSERT INTO public.meetings(meeting_id, meeting_date, title, venue, created_by)
        VALUES ('MTG-' || p_date::text, p_date::text, 'Morning Coordination Meeting', 'HQ', auth.uid()::text)
        RETURNING * INTO m;
    END IF;
    FOR item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
      SELECT * INTO old_row FROM public.meeting_attendance
        WHERE meeting_id = m.meeting_id AND project_name = item->>'project_name' AND deleted_at IS NULL;
      IF old_row.id IS NULL AND EXISTS (SELECT 1 FROM public.meeting_attendance
          WHERE meeting_id = m.meeting_id AND project_name = item->>'project_name' AND deleted_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Soft-deleted attendance requires review; cannot restore implicitly';
      END IF;
      IF old_row.id IS NULL THEN
        INSERT INTO public.meeting_attendance(meeting_id, meeting_date, project_name, status,
            remarks, employee_id, full_name, designation, sort_order)
          VALUES (m.meeting_id, p_date, item->>'project_name', item->>'status', item->>'remarks',
            item->>'employee_id', item->>'full_name', item->>'designation', (item->>'sort_order')::integer);
      ELSE
        UPDATE public.meeting_attendance SET status = item->>'status', remarks = item->>'remarks',
          employee_id = item->>'employee_id', full_name = item->>'full_name',
          designation = item->>'designation', sort_order = (item->>'sort_order')::integer
          WHERE id = old_row.id;
      END IF;
    END LOOP;
    UPDATE public.meetings SET agenda = p_metadata->>'agenda',
      started_at = (p_metadata->>'started_at')::timestamptz,
      ended_at = (p_metadata->>'ended_at')::timestamptz,
      submitted_at = coalesce(submitted_at, now()), not_held_reason = NULL,
      attendance_request_id = p_request_id
      WHERE id = m.id RETURNING * INTO m;
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id), '[]'::jsonb) INTO result_rows
    FROM public.meeting_attendance a WHERE meeting_id = m.meeting_id AND deleted_at IS NULL;
  -- Verify the persisted values even for an idempotent retry.
  IF jsonb_array_length(result_rows) <> jsonb_array_length(p_rows) OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_rows) wanted
    WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(result_rows) saved
      WHERE saved @> wanted)
  ) THEN
    RAISE EXCEPTION 'Persisted attendance differs from request';
  END IF;
  RETURN jsonb_build_object('meeting', to_jsonb(m), 'rows', result_rows);
END;
$function$;
ALTER FUNCTION public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid) OWNER TO "postgres";

-- public.reactivate_employee(bigint,date,text,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.reactivate_employee(p_employee_sys_id bigint, p_new_join_date date, p_new_project text, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_employee public.employees%rowtype;
begin
  if p_employee_sys_id is null then
    raise exception using errcode = '22023', message = 'Employee system ID is required';
  end if;
  if p_new_join_date is null then
    raise exception using errcode = '23514', message = 'New join date is required';
  end if;
  if nullif(btrim(coalesce(p_new_project, '')), '') is null then
    raise exception using errcode = '23514', message = 'New project is required';
  end if;

  select * into v_employee
    from public.employees
   where id = p_employee_sys_id and deleted_at is null
   for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Employee not found';
  end if;
  if lower(btrim(coalesce(v_employee.status, ''))) = 'active' then
    raise exception using errcode = '23514', message = 'Employee is already Active';
  end if;

  update public.employees
     set status = 'Active',
         project_name = btrim(p_new_project),
         join_date = p_new_join_date,
         exit_date = null,
         exit_reason = null,
         updated_at = now()
   where id = p_employee_sys_id
   returning * into v_employee;

  update public.exits
     set status = 'Reactivated',
         completion_remarks = case
           when nullif(btrim(coalesce(p_remarks, '')), '') is null then completion_remarks
           when nullif(btrim(coalesce(completion_remarks, '')), '') is null then p_remarks
           else completion_remarks || E'\nReactivation: ' || p_remarks
         end
   where employee_sys_id = p_employee_sys_id
     and deleted_at is null
     and status = 'Completed';

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'reactivate', 'employees', p_employee_sys_id::text,
    format('Employee reactivated at %s%s', btrim(p_new_project),
      case when nullif(btrim(coalesce(p_remarks, '')), '') is null then '' else ': ' || p_remarks end)
  );

  return jsonb_build_object('employee', to_jsonb(v_employee));
end;
$function$;
ALTER FUNCTION public.reactivate_employee(bigint,date,text,text) OWNER TO "postgres";

-- public.reschedule_transfer(bigint,date,text) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.reschedule_transfer(p_transfer_id bigint, p_new_effective_date date, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
declare
  v_transfer public.transfers%rowtype;
begin
  if p_new_effective_date is null then
    raise exception using errcode = '23514', message = 'New effective date is required';
  end if;

  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Reschedule reason is required';
  end if;

  select * into v_transfer
    from public.transfers
   where id = p_transfer_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Transfer not found';
  end if;

  if v_transfer.status not in ('Scheduled', 'Joining Pending', 'Not Joined') then
    raise exception using errcode = '23514',
      message = format('Transfer cannot be rescheduled from status %s', v_transfer.status);
  end if;

  update public.transfers
     set previous_effective_date = effective_date,
         effective_date = p_new_effective_date,
         transfer_date = p_new_effective_date::text,
         status = case when p_new_effective_date <= current_date then 'Joining Pending' else 'Scheduled' end,
         rescheduled_at = now(),
         rescheduled_by = auth.uid(),
         not_joined_at = null,
         not_joined_by = null,
         not_joined_reason = null,
         not_joined_remarks = null,
         notes = case
           when nullif(btrim(coalesce(notes, '')), '') is null then 'Rescheduled: ' || p_reason
           else notes || E'\nRescheduled: ' || p_reason
         end,
         updated_at = now()
   where id = v_transfer.id
   returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'reschedule', 'transfers', v_transfer.id::text,
    format('Transfer rescheduled for employee system ID %s to %s: %s',
      v_transfer.employee_sys_id, p_new_effective_date, p_reason)
  );

  return to_jsonb(v_transfer);
end;
$function$;
ALTER FUNCTION public.reschedule_transfer(bigint,date,text) OWNER TO "postgres";
