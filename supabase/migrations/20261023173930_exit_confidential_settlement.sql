-- Confidential data stays outside the exposed/public schema and generic exit payloads.
-- Additive migration; existing exit/transfer functions and historical records are preserved.
BEGIN;
-- Repair verified live status/constraint mismatches without adding new employment statuses.
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
      v_employee.id, p_exit_date, p_exit_type)
  );

  return jsonb_build_object('exit', to_jsonb(v_exit), 'employee', to_jsonb(v_employee));
end;
$function$;

CREATE OR REPLACE FUNCTION public.reactivate_employee(p_employee_sys_id bigint, p_new_join_date date, p_new_project text, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_employee public.employees%rowtype;
begin
  IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
  IF p_new_join_date > (now() AT TIME ZONE 'Asia/Dhaka')::date THEN RAISE EXCEPTION 'Future reactivation is not allowed' USING ERRCODE='23514'; END IF;
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

  IF nullif(v_employee.exit_date,'') IS NOT NULL AND p_new_join_date < v_employee.exit_date::date THEN RAISE EXCEPTION 'Rejoining cannot precede previous exit' USING ERRCODE='23514'; END IF;

  update public.employees
     set status = 'Active',
         project_name = btrim(p_new_project),
         join_date = p_new_join_date,
         exit_date = null,
         exit_reason = null,
         updated_at = now()
   where id = p_employee_sys_id
   returning * into v_employee;

  -- A completed exit is historical fact; reactivation starts a new employment period.
  -- Keep original dates, status, financial records and completion remarks intact.

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'reactivate', 'employees', p_employee_sys_id::text,
    format('Employee reactivated at %s%s', btrim(p_new_project),
      case when nullif(btrim(coalesce(p_remarks, '')), '') is null then '' else ': ' || p_remarks end)
  );

  return jsonb_build_object('employee', to_jsonb(v_employee));
end;
$function$;

REVOKE ALL ON FUNCTION public.complete_exit(bigint,date,text,text,text),public.reactivate_employee(bigint,date,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_exit(bigint,date,text,text,text),public.reactivate_employee(bigint,date,text,text) TO authenticated;
CREATE SCHEMA exit_private;
REVOKE ALL ON SCHEMA exit_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA exit_private TO authenticated;

CREATE TABLE exit_private.settlements (
 exit_id bigint PRIMARY KEY REFERENCES public.exits(id) ON DELETE RESTRICT,
 request_id uuid UNIQUE,
 request_payload jsonb,
 enabled boolean NOT NULL,
 default_enabled boolean NOT NULL,
 override_reason text,
 expected numeric(12,2) NOT NULL CHECK(expected >= 0 AND expected <= 100000000),
 deducted numeric(12,2) NOT NULL CHECK(deducted >= 0 AND deducted <= expected),
 deposited numeric(12,2) NOT NULL CHECK(deposited >= 0 AND deposited <= deducted),
 outcome text NOT NULL CHECK(outcome IN ('collected','partial','pending','waived','not_applicable')),
 reason text,
 deducted_on date,
 deposited_on date,
 receipt_no text,
 deposited_to text,
 approved_by text,
 notes text,
 follow_up_on date,
 follow_up_todo_id bigint REFERENCES public.todos(id) ON DELETE RESTRICT,
 version integer NOT NULL DEFAULT 1,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL,
 CHECK(enabled OR (expected=0 AND deducted=0 AND deposited=0 AND outcome='not_applicable')),
 CHECK(outcome <> 'collected' OR (expected>0 AND deducted=expected)),
 CHECK(outcome <> 'partial' OR (deducted>0 AND deducted<expected)),
 CHECK(outcome NOT IN ('pending','waived') OR (expected>0 AND deducted=0))
);
CREATE TABLE exit_private.settlement_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 exit_id bigint NOT NULL REFERENCES exit_private.settlements(exit_id) ON DELETE RESTRICT,
 version integer NOT NULL,
 before_data jsonb,
 after_data jsonb NOT NULL,
 change_note text NOT NULL,
 actor uuid NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(exit_id,version)
);
ALTER TABLE exit_private.settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE exit_private.settlement_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA exit_private FROM PUBLIC, anon, authenticated;
-- No direct table grants. Owner-authorized private functions are the only access path.

CREATE FUNCTION exit_private.save_settlement(p_exit_id bigint,p_data jsonb,p_version integer,p_change_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET timezone='Asia/Dhaka' AS $$
DECLARE
 x public.exits%rowtype; money_key text; old exit_private.settlements%rowtype; s exit_private.settlements%rowtype;
 join_day date; exit_day date; default_on boolean; today date := (now() AT TIME ZONE 'Asia/Dhaka')::date;
 outstanding numeric; todo_id bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO x FROM public.exits WHERE id=p_exit_id AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR x.status NOT IN ('Completed','Reactivated') THEN RAISE EXCEPTION 'A completed exit is required' USING ERRCODE='23514'; END IF;
 SELECT * INTO old FROM exit_private.settlements WHERE exit_id=p_exit_id FOR UPDATE;
 IF coalesce(old.version,0) <> coalesce(p_version,-1) THEN RAISE EXCEPTION 'Record changed on another device. Reload before saving.' USING ERRCODE='40001'; END IF;
 IF old.exit_id IS NOT NULL AND nullif(btrim(p_change_note),'') IS NULL THEN RAISE EXCEPTION 'Explain this correction' USING ERRCODE='23514'; END IF;
 join_day := nullif(x.join_date,'')::date;
 exit_day := coalesce(x.effective_exit_date,nullif(x.exit_date,'')::date);
 IF join_day IS NULL OR exit_day IS NULL OR exit_day<join_day THEN RAISE EXCEPTION 'Valid joining and exit dates are required' USING ERRCODE='23514'; END IF;
 default_on := exit_day < (join_day + interval '1 year')::date;
 s.exit_id := p_exit_id;
 s.enabled := (p_data->>'enabled')::boolean;
 s.default_enabled := default_on;
 s.override_reason := nullif(btrim(p_data->>'override_reason'),'');
 IF s.enabled IS NULL THEN RAISE EXCEPTION 'Choose whether deduction applies' USING ERRCODE='23514'; END IF;
 IF s.enabled <> default_on AND s.override_reason IS NULL THEN RAISE EXCEPTION 'Reason required for manual applicability override' USING ERRCODE='23514'; END IF;
 FOREACH money_key IN ARRAY ARRAY['expected','deducted','deposited'] LOOP
  IF s.enabled AND coalesce(p_data->>money_key,'') !~ '^\d+(\.\d{1,2})?$' THEN RAISE EXCEPTION 'Amounts require at most two decimal places' USING ERRCODE='23514'; END IF;
 END LOOP;
 s.expected := CASE WHEN s.enabled THEN (p_data->>'expected')::numeric ELSE 0 END;
 s.deducted := CASE WHEN s.enabled THEN (p_data->>'deducted')::numeric ELSE 0 END;
 s.deposited := CASE WHEN s.enabled THEN (p_data->>'deposited')::numeric ELSE 0 END;
 s.outcome := CASE WHEN s.enabled THEN p_data->>'outcome' ELSE 'not_applicable' END;
 s.reason := CASE WHEN s.enabled THEN nullif(btrim(p_data->>'reason'),'') END;
 s.deducted_on := CASE WHEN s.deducted>0 THEN nullif(p_data->>'deducted_on','')::date END;
 s.deposited_on := CASE WHEN s.deposited>0 THEN nullif(p_data->>'deposited_on','')::date END;
 s.receipt_no := CASE WHEN s.deposited>0 THEN nullif(btrim(p_data->>'receipt_no'),'') END;
 s.deposited_to := CASE WHEN s.deposited>0 THEN nullif(btrim(p_data->>'deposited_to'),'') END;
 s.approved_by := CASE WHEN s.outcome='waived' THEN nullif(btrim(p_data->>'approved_by'),'') END;
 s.notes := nullif(btrim(p_data->>'notes'),'');
 s.follow_up_on := CASE WHEN s.enabled THEN nullif(p_data->>'follow_up_on','')::date END;
 IF s.enabled AND (s.expected IS NULL OR s.expected<=0 OR s.deducted IS NULL OR s.deposited IS NULL OR s.outcome IS NULL OR s.outcome='not_applicable') THEN RAISE EXCEPTION 'Complete deduction amounts and outcome' USING ERRCODE='23514'; END IF;
 IF s.expected::text IN ('NaN','Infinity','-Infinity') OR s.deducted::text IN ('NaN','Infinity','-Infinity') OR s.deposited::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid money amount' USING ERRCODE='23514'; END IF;
 IF s.enabled AND s.expected<>3000 AND s.notes IS NULL THEN RAISE EXCEPTION 'Explain the adjusted expected amount in notes' USING ERRCODE='23514'; END IF;
 IF s.enabled AND s.deducted<s.expected AND (s.reason IS NULL OR s.reason NOT IN ('salary_paid','insufficient_salary','no_salary_due','salary_held','release_pending','payroll_pending','special_waiver','decision_pending','disputed','other')) THEN RAISE EXCEPTION 'Select a reason for missing or partial deduction' USING ERRCODE='23514'; END IF;
 IF s.reason='other' AND s.notes IS NULL THEN RAISE EXCEPTION 'Other reason requires notes' USING ERRCODE='23514'; END IF;
 IF s.outcome='waived' AND (s.approved_by IS NULL OR s.notes IS NULL OR s.reason<>'special_waiver') THEN RAISE EXCEPTION 'Waiver requires special waiver reason, authority and decision notes' USING ERRCODE='23514'; END IF;
 IF s.outcome<>'waived' AND s.reason='special_waiver' THEN RAISE EXCEPTION 'Use waived outcome for an authorized waiver' USING ERRCODE='23514'; END IF;
 IF s.deducted>0 AND s.deducted_on IS NULL THEN RAISE EXCEPTION 'Deduction date is required' USING ERRCODE='23514'; END IF;
 IF s.deposited>0 AND (s.deposited_on IS NULL OR s.receipt_no IS NULL OR s.deposited_to IS NULL) THEN RAISE EXCEPTION 'Deposit date, receipt and recipient are required' USING ERRCODE='23514'; END IF;
 IF s.deducted_on>today OR s.deposited_on>today OR s.deposited_on<s.deducted_on THEN RAISE EXCEPTION 'Check deduction and deposit dates' USING ERRCODE='23514'; END IF;
 IF length(coalesce(s.notes,''))>4000 OR length(coalesce(s.override_reason,''))>1000 OR length(coalesce(s.receipt_no,''))>150 OR length(coalesce(s.deposited_to,''))>200 OR length(coalesce(s.approved_by,''))>200 OR length(coalesce(p_change_note,''))>1000 THEN RAISE EXCEPTION 'Text exceeds allowed length' USING ERRCODE='23514'; END IF;
 s.version := coalesce(old.version,0)+1;
 s.updated_at := clock_timestamp(); s.updated_by := auth.uid();
 s.request_id := old.request_id; s.request_payload := old.request_payload;
 -- Generic To-Do contains no employee identity, amounts, reasons, notes or receipt.
 outstanding := CASE WHEN s.outcome='waived' THEN 0 ELSE s.expected-s.deducted END + s.deducted-s.deposited;
 todo_id := old.follow_up_todo_id;
 IF outstanding>0 AND s.follow_up_on IS NOT NULL THEN
  IF todo_id IS NULL THEN
   INSERT INTO public.todos(project,who,note,date,status,source,category,priority,remind_on,next_reminder_at,reminder_enabled,reminder_type,owner_user_id,assigned_to_user_id)
   VALUES (NULL,NULL,'Review confidential exit follow-up #'||p_exit_id||' in Exit Deduction & Deposit Report.',today,'open','exit_settlement','task','normal',s.follow_up_on,(s.follow_up_on+time '09:00') AT TIME ZONE 'Asia/Dhaka',true,'once',auth.uid(),auth.uid()) RETURNING id INTO todo_id;
  ELSIF old.follow_up_on IS DISTINCT FROM s.follow_up_on OR EXISTS(SELECT 1 FROM public.todos WHERE id=todo_id AND (deleted_at IS NOT NULL OR solved_at IS NOT NULL)) THEN
   UPDATE public.todos SET status='open',solved_at=NULL,remind_on=s.follow_up_on,next_reminder_at=(s.follow_up_on+time '09:00') AT TIME ZONE 'Asia/Dhaka',reminder_enabled=true,reminder_type='once',deleted_at=NULL,updated_at=now() WHERE id=todo_id;
  END IF;
 ELSIF todo_id IS NOT NULL THEN
  UPDATE public.todos SET status='solved',solved_at=now(),remind_on=NULL,next_reminder_at=NULL,reminder_enabled=false,updated_at=now() WHERE id=todo_id;
 END IF;
 s.follow_up_todo_id := todo_id;
 INSERT INTO exit_private.settlements SELECT (s).* ON CONFLICT(exit_id) DO UPDATE SET
  enabled=excluded.enabled,default_enabled=excluded.default_enabled,override_reason=excluded.override_reason,
  expected=excluded.expected,deducted=excluded.deducted,deposited=excluded.deposited,outcome=excluded.outcome,
  reason=excluded.reason,deducted_on=excluded.deducted_on,deposited_on=excluded.deposited_on,
  receipt_no=excluded.receipt_no,deposited_to=excluded.deposited_to,approved_by=excluded.approved_by,
  notes=excluded.notes,follow_up_on=excluded.follow_up_on,follow_up_todo_id=excluded.follow_up_todo_id,
  version=excluded.version,updated_at=excluded.updated_at,updated_by=excluded.updated_by;
 INSERT INTO exit_private.settlement_history(exit_id,version,before_data,after_data,change_note,actor)
 VALUES(p_exit_id,s.version,CASE WHEN old.exit_id IS NOT NULL THEN to_jsonb(old)-'request_payload' END,to_jsonb(s)-'request_payload',coalesce(nullif(btrim(p_change_note),''),'Initial recording'),auth.uid());
 RETURN to_jsonb(s)-'request_payload';
END $$;

CREATE FUNCTION exit_private.submit_exit(p_exit jsonb,p_settlement jsonb,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET timezone='Asia/Dhaka' AS $$
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
 r := public.complete_exit((r->'exit'->>'id')::bigint,exit_day,p_exit->>'exit_type',p_exit->>'exit_reason','Completed from Employee Exit form');
 saved := exit_private.save_settlement((r->'exit'->>'id')::bigint,p_settlement,0,'Initial recording');
 UPDATE exit_private.settlements SET request_id=p_request_id,request_payload=jsonb_build_object('exit',p_exit,'settlement',p_settlement) WHERE exit_id=(r->'exit'->>'id')::bigint;
 RETURN jsonb_build_object('exit_id',(r->'exit'->>'id')::bigint,'replayed',false);
END $$;

CREATE FUNCTION exit_private.report_rows(p_from date,p_to date,p_exit_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 IF p_exit_id IS NULL AND (p_from IS NULL OR p_to IS NULL OR p_from>p_to) THEN RAISE EXCEPTION 'Valid report date range required' USING ERRCODE='23514'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('exit_id',x.id,'employee_id',x.employee_id,'employee_sys_id',x.employee_sys_id,'full_name',x.full_name,'designation',x.designation,'current_project',x.current_project,'join_date',x.join_date,'exit_date',coalesce(x.effective_exit_date::text,x.exit_date),'employee_status',e.status,'settlement',CASE WHEN s.exit_id IS NULL THEN NULL ELSE to_jsonb(s)-'request_payload'-'request_id' END) ORDER BY coalesce(x.effective_exit_date::text,x.exit_date),x.id),'[]'::jsonb) INTO result
 FROM public.exits x LEFT JOIN exit_private.settlements s ON s.exit_id=x.id LEFT JOIN public.employees e ON e.id=x.employee_sys_id
 WHERE x.deleted_at IS NULL AND x.status IN ('Completed','Reactivated')
 AND (CASE WHEN p_exit_id IS NOT NULL THEN x.id=p_exit_id ELSE coalesce(x.effective_exit_date::text,x.exit_date) BETWEEN p_from::text AND p_to::text END);
 RETURN result;
END $$;
CREATE FUNCTION exit_private.history_rows(p_exit_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 RETURN (SELECT coalesce(jsonb_agg(to_jsonb(h) ORDER BY version DESC),'[]'::jsonb) FROM exit_private.settlement_history h WHERE exit_id=p_exit_id);
END $$;

CREATE FUNCTION exit_private.archive_exit(p_exit_id bigint)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE s exit_private.settlements%rowtype;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.exits WHERE id=p_exit_id AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Exit record not found' USING ERRCODE='P0002'; END IF;
 SELECT * INTO s FROM exit_private.settlements WHERE exit_id=p_exit_id FOR UPDATE;
 IF s.exit_id IS NOT NULL THEN
  INSERT INTO exit_private.settlement_history(exit_id,version,before_data,after_data,change_note,actor)
  VALUES(p_exit_id,s.version+1,to_jsonb(s)-'request_payload',to_jsonb(s)-'request_payload'||jsonb_build_object('archived',true),'Exit record archived by operator; confidential history retained',auth.uid());
  UPDATE exit_private.settlements SET version=version+1,updated_at=now(),updated_by=auth.uid() WHERE exit_id=p_exit_id;
  UPDATE public.todos SET status='solved',solved_at=now(),next_reminder_at=NULL,reminder_enabled=false,updated_at=now() WHERE id=s.follow_up_todo_id;
 END IF;
 UPDATE public.exits SET deleted_at=now(),deleted_by=auth.uid(),updated_at=now() WHERE id=p_exit_id;
 RETURN true;
END $$;
CREATE FUNCTION public.archive_exit_record(p_exit_id bigint) RETURNS boolean
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.archive_exit(p_exit_id) $$;
REVOKE ALL ON FUNCTION public.archive_exit_record(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.archive_exit_record(bigint) TO authenticated;

CREATE FUNCTION public.submit_exit_settlement(p_exit jsonb,p_settlement jsonb,p_request_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.submit_exit(p_exit,p_settlement,p_request_id) $$;
CREATE FUNCTION public.save_exit_settlement(p_exit_id bigint,p_data jsonb,p_version integer,p_change_note text) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.save_settlement(p_exit_id,p_data,p_version,p_change_note) $$;
CREATE FUNCTION public.get_exit_settlement_report(p_from date,p_to date,p_exit_id bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.report_rows(p_from,p_to,p_exit_id) $$;
CREATE FUNCTION public.get_exit_settlement_history(p_exit_id bigint) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.history_rows(p_exit_id) $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA exit_private FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exit_private TO authenticated;
REVOKE ALL ON FUNCTION public.submit_exit_settlement(jsonb,jsonb,uuid),public.save_exit_settlement(bigint,jsonb,integer,text),public.get_exit_settlement_report(date,date,bigint),public.get_exit_settlement_history(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_exit_settlement(jsonb,jsonb,uuid),public.save_exit_settlement(bigint,jsonb,integer,text),public.get_exit_settlement_report(date,date,bigint),public.get_exit_settlement_history(bigint) TO authenticated;
COMMIT;
