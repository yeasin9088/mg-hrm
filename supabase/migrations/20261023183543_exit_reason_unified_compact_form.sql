BEGIN;
-- Preserve nonblank historical exit categories within existing reason before removing legacy field.
UPDATE public.exits SET exit_reason = CASE WHEN nullif(btrim(exit_reason),'') IS NULL THEN btrim(exit_type) WHEN position(lower(btrim(exit_type)) in lower(exit_reason))>0 THEN exit_reason ELSE exit_reason || ' [Previous category: ' || btrim(exit_type) || ']' END, updated_at=now() WHERE nullif(btrim(exit_type),'') IS NOT NULL AND (nullif(btrim(exit_reason),'') IS NULL OR position(lower(btrim(exit_type)) in lower(exit_reason))=0);
-- Positional legacy public.complete_exit argument kept for compatible older clients; one reason persisted.
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

  if v_employee.status <> 'Active' then
    raise exception using errcode = '23514', message = 'Only active employees may start an exit';
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
    coalesce(nullif(btrim(p_exit->>'exit_reason'),''),nullif(btrim(p_exit->>'exit_type'),''),'Formal Resignation'),
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
  IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
  IF p_exit_date > (now() AT TIME ZONE 'Asia/Dhaka')::date THEN RAISE EXCEPTION 'Future exit is not allowed' USING ERRCODE='23514'; END IF;
  if p_exit_date is null then
    raise exception using errcode = '23514', message = 'Exit date is required';
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

  if v_employee.status <> 'Active' then
    raise exception using errcode = '23514', message = 'Only an active employee can complete exit';
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
     set status = 'Inactive',
         exit_date = p_exit_date::text,
         exit_reason = btrim(p_exit_reason),
         updated_at = now()
   where id = v_employee.id
   returning * into v_employee;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'complete', 'exits', v_exit.id::text,
    format('Employee system ID %s exited on %s (%s)',
      v_employee.id, p_exit_date, p_exit_reason)
  );

  return jsonb_build_object('exit', to_jsonb(v_exit), 'employee', to_jsonb(v_employee));
end;
$function$;

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
  v_exit_reason := coalesce(nullif(btrim(p_exit->>'exit_reason'), ''), nullif(btrim(p_exit->>'exit_type'), ''), 'Formal Resignation');
  v_exit_type := v_exit_reason; -- legacy positional RPC argument

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

CREATE OR REPLACE FUNCTION exit_private.submit_exit(p_exit jsonb, p_settlement jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
DECLARE r jsonb; previous exit_private.settlements%rowtype; emp public.employees%rowtype; exit_day date; tid bigint; saved jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'Request ID required' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 SELECT * INTO previous FROM exit_private.settlements WHERE request_id=p_request_id;
 IF FOUND THEN
  IF previous.request_payload <> jsonb_build_object('exit',p_exit,'settlement',p_settlement) THEN RAISE EXCEPTION 'Retry payload changed. Review before submitting again.' USING ERRCODE='23514'; END IF;
  RETURN jsonb_build_object('exit_id',previous.exit_id,'replayed',true);
 END IF;
 SELECT * INTO emp FROM public.employees WHERE id=(p_exit->>'employee_sys_id')::bigint AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR emp.status<>'Active' THEN RAISE EXCEPTION 'An active employee is required' USING ERRCODE='23514'; END IF;
 exit_day := (p_exit->>'exit_date')::date;
 IF exit_day IS NULL OR exit_day>(now() AT TIME ZONE 'Asia/Dhaka')::date THEN RAISE EXCEPTION 'Exit date cannot be empty or in the future' USING ERRCODE='23514'; END IF;
 IF nullif(emp.join_date,'') IS NULL OR exit_day<emp.join_date::date THEN RAISE EXCEPTION 'Check joining and exit dates' USING ERRCODE='23514'; END IF;
 tid := nullif(p_exit->>'related_transfer_id','')::bigint;
 IF tid IS NOT NULL THEN
  PERFORM 1 FROM public.transfers WHERE id=tid AND employee_sys_id=emp.id AND deleted_at IS NULL AND status IN ('Draft','Scheduled','Joining Pending','Not Joined','Cancelled') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Linked transfer does not match this exit' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM public.transfers WHERE id=tid AND status<>'Cancelled') THEN
   PERFORM public.cancel_transfer(tid,'Employee exit confirmed by operator');
  END IF;
 END IF;
 r := public.create_exit_draft(p_exit);
 r := public.complete_exit((r->'exit'->>'id')::bigint,exit_day,coalesce(nullif(btrim(p_exit->>'exit_reason'),''),nullif(btrim(p_exit->>'exit_type'),''),'Formal Resignation'),coalesce(nullif(btrim(p_exit->>'exit_reason'),''),nullif(btrim(p_exit->>'exit_type'),''),'Formal Resignation'),'Completed from Employee Exit form');
 saved := exit_private.save_settlement((r->'exit'->>'id')::bigint,p_settlement,0,'Initial recording');
 UPDATE exit_private.settlements SET request_id=p_request_id,request_payload=jsonb_build_object('exit',p_exit,'settlement',p_settlement) WHERE exit_id=(r->'exit'->>'id')::bigint;
 RETURN jsonb_build_object('exit_id',(r->'exit'->>'id')::bigint,'replayed',false);
END $function$;
ALTER TABLE public.exits DROP COLUMN exit_type RESTRICT;
COMMIT;
