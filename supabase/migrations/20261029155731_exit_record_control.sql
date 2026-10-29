ALTER TABLE exit_private.settlements ADD COLUMN IF NOT EXISTS follow_up_time time NOT NULL DEFAULT '09:00';
-- Under-one-year exit decisions are mandatory; never permit a hidden tracking-off bypass.
-- Existing private tables, historical records, audit and operator permissions are preserved.
CREATE OR REPLACE FUNCTION exit_private.save_settlement(p_exit_id bigint,p_data jsonb,p_version integer,p_change_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET timezone='Asia/Dhaka' AS $$
DECLARE
 x public.exits%rowtype; money_key text; old exit_private.settlements%rowtype; s exit_private.settlements%rowtype;
 join_day date; exit_day date; default_on boolean; today date := (now() AT TIME ZONE 'Asia/Dhaka')::date;
 outstanding numeric; todo_id bigint; reminder_at timestamptz;
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
 IF default_on AND NOT s.enabled THEN RAISE EXCEPTION 'Deduction decision required before first service anniversary; use no deduction or approved waiver' USING ERRCODE='23514'; END IF;
 IF s.enabled AND NOT default_on AND s.override_reason IS NULL THEN RAISE EXCEPTION 'Reason required for exceptional deduction tracking' USING ERRCODE='23514'; END IF;
 FOREACH money_key IN ARRAY ARRAY['expected','deducted','deposited'] LOOP
  IF s.enabled AND coalesce(p_data->>money_key,'') !~ '^[0-9]+([.][0-9]{1,2})?$' THEN RAISE EXCEPTION 'Amounts require at most two decimal places' USING ERRCODE='23514'; END IF;
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
 s.follow_up_time := coalesce(nullif(p_data->>'follow_up_time','')::time,old.follow_up_time,time '09:00');
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
  reminder_at := (s.follow_up_on+s.follow_up_time) AT TIME ZONE 'Asia/Dhaka';
  IF (old.follow_up_on IS DISTINCT FROM s.follow_up_on OR old.follow_up_time IS DISTINCT FROM s.follow_up_time) AND reminder_at <= now() THEN RAISE EXCEPTION 'Choose a future reminder date and time' USING ERRCODE='23514'; END IF;
  IF todo_id IS NULL THEN
   INSERT INTO public.todos(project,who,note,date,status,source,category,priority,remind_on,next_reminder_at,reminder_enabled,reminder_type,owner_user_id,assigned_to_user_id)
   VALUES (NULL,NULL,'Review confidential exit follow-up #'||p_exit_id||' in Exit Deduction & Deposit Report.',today,'open','exit_settlement','task','normal',s.follow_up_on,reminder_at,true,'once',auth.uid(),auth.uid()) RETURNING id INTO todo_id;
  ELSIF old.follow_up_on IS DISTINCT FROM s.follow_up_on OR old.follow_up_time IS DISTINCT FROM s.follow_up_time OR EXISTS(SELECT 1 FROM public.todos WHERE id=todo_id AND (deleted_at IS NOT NULL OR solved_at IS NOT NULL)) THEN
   UPDATE public.todos SET status='open',solved_at=NULL,remind_on=s.follow_up_on,next_reminder_at=reminder_at,reminder_enabled=true,reminder_type='once',deleted_at=NULL,updated_at=now() WHERE id=todo_id;
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
  notes=excluded.notes,follow_up_on=excluded.follow_up_on,follow_up_time=excluded.follow_up_time,follow_up_todo_id=excluded.follow_up_todo_id,
  version=excluded.version,updated_at=excluded.updated_at,updated_by=excluded.updated_by;
 INSERT INTO exit_private.settlement_history(exit_id,version,before_data,after_data,change_note,actor)
 VALUES(p_exit_id,s.version,CASE WHEN old.exit_id IS NOT NULL THEN to_jsonb(old)-'request_payload' END,to_jsonb(s)-'request_payload',coalesce(nullif(btrim(p_change_note),''),'Initial recording'),auth.uid());
 RETURN to_jsonb(s)-'request_payload';
END $$;

CREATE OR REPLACE FUNCTION exit_private.edit_record(p_exit_id bigint,p_exit jsonb,p_settlement jsonb,p_version integer,p_original jsonb,p_change_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET timezone='Asia/Dhaka' AS $$
DECLARE x public.exits%rowtype; e public.employees%rowtype; saved jsonb; snapshot jsonb; exit_day date; issue_day date; previous_day date;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO x FROM public.exits WHERE id=p_exit_id AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR x.status NOT IN ('Completed','Reactivated') THEN RAISE EXCEPTION 'Completed exit not found'; END IF;
 snapshot:=jsonb_build_object('exit_date',coalesce(x.effective_exit_date::text,x.exit_date),'issue_date',x.issue_date,'exit_reason',x.exit_reason);
 IF p_original IS NULL OR snapshot IS DISTINCT FROM p_original THEN RAISE EXCEPTION 'Exit changed on another device. Reload before saving.' USING ERRCODE='40001'; END IF;
 exit_day:=nullif(p_exit->>'exit_date','')::date;
 issue_day:=nullif(p_exit->>'issue_date','')::date;
 IF exit_day IS NULL OR issue_day IS NULL OR exit_day<nullif(x.join_date,'')::date OR exit_day>(now() AT TIME ZONE 'Asia/Dhaka')::date OR issue_day<exit_day THEN RAISE EXCEPTION 'Check exit and issue dates'; END IF;
 IF nullif(btrim(p_exit->>'exit_reason'),'') IS NULL OR length(p_exit->>'exit_reason')>1000 THEN RAISE EXCEPTION 'Exit reason is required (maximum 1000 characters)'; END IF;
 previous_day:=coalesce(x.effective_exit_date,nullif(x.exit_date,'')::date);
 SELECT * INTO e FROM public.employees WHERE id=x.employee_sys_id FOR UPDATE;
 IF exit_day IS DISTINCT FROM previous_day AND EXISTS(SELECT 1 FROM public.exits other WHERE other.employee_sys_id=x.employee_sys_id AND other.id<>x.id AND other.deleted_at IS NULL AND nullif(other.join_date,'')::date>previous_day AND exit_day>=nullif(other.join_date,'')::date) THEN RAISE EXCEPTION 'Exit date overlaps a later employment period'; END IF;
 IF e.status='Active' AND nullif(e.join_date,'')::date>previous_day AND exit_day IS DISTINCT FROM previous_day AND exit_day>=nullif(e.join_date,'')::date THEN RAISE EXCEPTION 'Exit date must precede rejoining'; END IF;
 -- Never modify current employment status/project or replay the exit workflow.
 UPDATE public.exits SET exit_date=exit_day::text,effective_exit_date=exit_day,issue_date=issue_day::text,exit_reason=btrim(p_exit->>'exit_reason') WHERE id=x.id;
 IF e.status='Inactive' AND nullif(e.join_date,'')::date=nullif(x.join_date,'')::date AND nullif(e.exit_date,'')::date=previous_day THEN
  UPDATE public.employees SET exit_date=exit_day::text WHERE id=e.id;
 END IF;
 saved:=exit_private.save_settlement(x.id,p_settlement,p_version,coalesce(nullif(btrim(p_change_note),''),'Exit details / deduction updated'));
 UPDATE exit_private.settlement_history SET
  before_data=coalesce(before_data,'{}'::jsonb)||jsonb_build_object('exit_details',snapshot),
  after_data=after_data||jsonb_build_object('exit_details',jsonb_build_object('exit_date',exit_day::text,'issue_date',issue_day::text,'exit_reason',btrim(p_exit->>'exit_reason')))
 WHERE exit_id=x.id AND version=(saved->>'version')::integer;
 RETURN jsonb_build_object('exit_id',x.id,'settlement',saved);
END $$;
REVOKE ALL ON FUNCTION exit_private.edit_record(bigint,jsonb,jsonb,integer,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION exit_private.edit_record(bigint,jsonb,jsonb,integer,jsonb,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.update_exit_record(p_exit_id bigint,p_exit jsonb,p_settlement jsonb,p_version integer,p_original jsonb,p_change_note text DEFAULT '')
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT exit_private.edit_record(p_exit_id,p_exit,p_settlement,p_version,p_original,p_change_note) $$;
REVOKE ALL ON FUNCTION public.update_exit_record(bigint,jsonb,jsonb,integer,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_exit_record(bigint,jsonb,jsonb,integer,jsonb,text) TO authenticated;
-- Resolve a linked reminder server-side; do not put confidential details in generic todos.
CREATE OR REPLACE FUNCTION public.get_exit_for_followup(p_todo_id bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 RETURN (SELECT s.exit_id FROM exit_private.settlements s JOIN public.exits x ON x.id=s.exit_id WHERE s.follow_up_todo_id=p_todo_id AND x.deleted_at IS NULL);
END $$;
REVOKE ALL ON FUNCTION public.get_exit_for_followup(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_exit_for_followup(bigint) TO authenticated;
CREATE OR REPLACE FUNCTION exit_private.report_rows(p_from date,p_to date,p_exit_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 IF p_exit_id IS NULL AND (p_from IS NULL OR p_to IS NULL OR p_from>p_to) THEN RAISE EXCEPTION 'Valid report date range required' USING ERRCODE='23514'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('exit_id',x.id,'employee_id',x.employee_id,'employee_sys_id',x.employee_sys_id,'full_name',x.full_name,'designation',x.designation,'current_project',x.current_project,'join_date',x.join_date,'issue_date',x.issue_date,'exit_reason',x.exit_reason,'exit_date',coalesce(x.effective_exit_date::text,x.exit_date),'employee_status',e.status,'settlement',CASE WHEN s.exit_id IS NULL THEN NULL ELSE to_jsonb(s)-'request_payload'-'request_id' END) ORDER BY coalesce(x.effective_exit_date::text,x.exit_date),x.id),'[]'::jsonb) INTO result
 FROM public.exits x LEFT JOIN exit_private.settlements s ON s.exit_id=x.id LEFT JOIN public.employees e ON e.id=x.employee_sys_id
 WHERE x.deleted_at IS NULL AND x.status IN ('Completed','Reactivated')
 AND (CASE WHEN p_exit_id IS NOT NULL THEN x.id=p_exit_id ELSE coalesce(x.effective_exit_date,nullif(x.exit_date,'')::date)::text BETWEEN p_from::text AND p_to::text END);
 RETURN result;
END $$;
