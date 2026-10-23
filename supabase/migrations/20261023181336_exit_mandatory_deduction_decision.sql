-- Under-one-year exit decisions are mandatory; never permit a hidden tracking-off bypass.
-- Existing private tables, historical records, audit and operator permissions are preserved.
CREATE OR REPLACE FUNCTION exit_private.save_settlement(p_exit_id bigint,p_data jsonb,p_version integer,p_change_note text)
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
 IF default_on AND NOT s.enabled THEN RAISE EXCEPTION 'Deduction decision required before first service anniversary; use no deduction or approved waiver' USING ERRCODE='23514'; END IF;
 IF s.enabled AND NOT default_on AND s.override_reason IS NULL THEN RAISE EXCEPTION 'Reason required for exceptional deduction tracking' USING ERRCODE='23514'; END IF;
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
