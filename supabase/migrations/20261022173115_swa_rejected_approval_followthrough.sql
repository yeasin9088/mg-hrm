-- Correct decision/outcome semantics: a rejected required approval blocks execution,
-- but does not erase communication/verification obligations. Existing rows are unchanged.
CREATE OR REPLACE FUNCTION public.swa_act(p_item_id uuid, p_expected_version integer, p_action text, p_value text DEFAULT NULL::text, p_occurred_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_session_id uuid DEFAULT NULL::uuid)
 RETURNS swa_work_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE w public.swa_work_items; before_row jsonb; now_at timestamptz:=clock_timestamp(); occurred timestamptz;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 SELECT * INTO w FROM public.swa_work_items WHERE id=p_item_id AND owner_user_id=auth.uid() FOR UPDATE;
 IF w.id IS NULL THEN RAISE EXCEPTION 'Work item not found' USING ERRCODE='P0002'; END IF;
 IF p_expected_version IS DISTINCT FROM w.row_version THEN
   RAISE EXCEPTION 'Conflict: work item changed on another device. Refresh before saving.' USING ERRCODE='40001';
 END IF;
 IF p_session_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.swa_brief_sessions WHERE id=p_session_id AND owner_user_id=auth.uid() AND closed_at IS NULL)
 THEN RAISE EXCEPTION 'Invalid or closed briefing session'; END IF;
 before_row:=to_jsonb(w);
 occurred:=coalesce(p_occurred_at,now_at);
 IF occurred>now_at+interval '5 minutes' THEN RAISE EXCEPTION 'Future event time not permitted'; END IF;
 IF w.stage IN ('completed','cancelled') AND p_action<>'reopen' THEN
   RAISE EXCEPTION 'Reopen the resolved work item first';
 END IF;
 CASE p_action
 WHEN 'informed' THEN
   IF NOT w.manager_required THEN RAISE EXCEPTION 'Manager briefing not required'; END IF;
   IF p_value NOT IN ('phone','in_person','message','paper','other') THEN RAISE EXCEPTION 'Select communication channel'; END IF;
   w.manager_informed_at:=occurred;w.manager_channel:=p_value;
   IF w.manager_decision='none' THEN w.manager_decision:='pending'; END IF;
   w.stage:='waiting_manager';
 WHEN 'decision' THEN
   IF NOT w.manager_required OR p_value NOT IN ('approved','rejected','pending','needs_info','postponed') THEN RAISE EXCEPTION 'Invalid manager decision'; END IF;
   w.manager_decision:=p_value;w.manager_decision_at:=occurred;w.manager_recorded_at:=now_at;
   IF p_value IN ('approved','rejected') THEN
     w.stage:='active';w.next_action:=CASE WHEN w.communication_required THEN 'সংশ্লিষ্ট ব্যক্তি/প্রজেক্টকে সিদ্ধান্ত জানান' WHEN p_value='rejected' THEN 'প্রত্যাখ্যানের ফল নথিভুক্ত করে কাজ বন্ধ করুন' ELSE 'পরবর্তী অনুমোদিত পদক্ষেপ গ্রহণ করুন' END;
   ELSE w.stage:='waiting_manager'; END IF;
 WHEN 'communicated' THEN
   w.communicated_at:=occurred; w.stage:='active';
 WHEN 'executed' THEN
   IF w.approval_required AND w.manager_decision<>'approved' THEN RAISE EXCEPTION 'Required approval not recorded'; END IF;
   w.executed_at:=occurred; w.stage:=CASE WHEN w.verification_required THEN 'verification' ELSE 'active' END;
 WHEN 'verified' THEN
   IF w.execution_required AND w.executed_at IS NULL AND NOT(w.approval_required AND w.manager_decision='rejected') THEN RAISE EXCEPTION 'Execution must be recorded first'; END IF;
   w.verified_at:=occurred;w.stage:='active';
 WHEN 'complete' THEN
   IF (w.manager_required AND w.manager_informed_at IS NULL) OR
      (w.approval_required AND w.manager_decision NOT IN ('approved','rejected')) OR
      (w.communication_required AND w.communicated_at IS NULL) OR
      (w.execution_required AND w.executed_at IS NULL AND NOT(w.approval_required AND w.manager_decision='rejected')) OR
      (w.verification_required AND w.verified_at IS NULL) THEN
     RAISE EXCEPTION 'Required manager, communication, execution or verification steps remain';
   END IF;
   w.stage:='completed';w.completed_at:=now_at;
 WHEN 'cancel' THEN
   IF length(btrim(coalesce(p_value,'')))<3 THEN RAISE EXCEPTION 'Cancellation reason required'; END IF;
   w.stage:='cancelled';w.cancelled_at:=now_at;
 WHEN 'reopen' THEN
   IF w.stage NOT IN ('completed','cancelled') OR length(btrim(coalesce(p_value,'')))<3 THEN RAISE EXCEPTION 'Reopen reason/next action required'; END IF;
   w.stage:='active';w.completed_at:=NULL;w.cancelled_at:=NULL;
   w.manager_informed_at:=NULL;w.manager_decision:='none';w.manager_decision_at:=NULL;
   w.communicated_at:=NULL;w.executed_at:=NULL;w.verified_at:=NULL;
   w.next_action:=left(p_value,400); w.next_review_at:=now_at+interval '1 day';
 WHEN 'ack' THEN w.acknowledged_until:=now_at+interval '4 hours';
 WHEN 'snooze' THEN
   IF p_value IS NULL OR p_value::timestamptz<=now_at OR p_value::timestamptz>now_at+interval '30 days'
   THEN RAISE EXCEPTION 'Snooze must be within 30 days'; END IF;
   w.snoozed_until:=p_value::timestamptz;
 WHEN 'followup' THEN
   IF p_value IS NULL OR p_value::timestamptz<now_at-interval '1 minute'
   THEN RAISE EXCEPTION 'Invalid next review'; END IF;
   w.next_review_at:=p_value::timestamptz;
 WHEN 'next_action' THEN
   IF length(btrim(coalesce(p_value,''))) NOT BETWEEN 3 AND 400 THEN RAISE EXCEPTION 'Describe next action'; END IF;
   w.next_action:=btrim(p_value);w.stage:='active';
 WHEN 'waiting_external' THEN
   IF length(btrim(coalesce(p_value,'')))<2 THEN RAISE EXCEPTION 'External party required'; END IF;
   w.next_party:=left(btrim(p_value),200);w.stage:='waiting_external';
 ELSE RAISE EXCEPTION 'Unsupported work action';
 END CASE;
 w.row_version:=w.row_version+1;w.updated_at:=now_at;
 UPDATE public.swa_work_items SET
 stage=w.stage,manager_informed_at=w.manager_informed_at,manager_channel=w.manager_channel,
 manager_decision=w.manager_decision,manager_decision_at=w.manager_decision_at,manager_recorded_at=w.manager_recorded_at,
 next_action=w.next_action,next_party=w.next_party,next_review_at=w.next_review_at,
 communicated_at=w.communicated_at,executed_at=w.executed_at,verified_at=w.verified_at,
 acknowledged_until=w.acknowledged_until,snoozed_until=w.snoozed_until,
 completed_at=w.completed_at,cancelled_at=w.cancelled_at,row_version=w.row_version,updated_at=w.updated_at
 WHERE id=w.id;
 INSERT INTO public.swa_work_events(item_id,session_id,actor_user_id,event_type,event_at,recorded_at,channel,payload)
 VALUES(w.id,p_session_id,auth.uid(),p_action,occurred,now_at,
 CASE WHEN p_action='informed' THEN p_value ELSE NULL END,
 jsonb_build_object('value',left(coalesce(p_value,''),400),'from_version',p_expected_version,'to_version',w.row_version));
 RETURN w;
END $function$
;
