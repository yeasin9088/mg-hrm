-- Phase 6 continuation: obligations embedded in existing To-Do tabs.
-- No employee/payroll/HR execution, no messages, no release gate activation.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
ALTER TABLE public.todos ADD COLUMN IF NOT EXISTS work_capture_key uuid,
 ADD COLUMN IF NOT EXISTS work_source_type text,
 ADD COLUMN IF NOT EXISTS work_source_id text,
 ADD COLUMN IF NOT EXISTS work_managed boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS todo_work_capture_key ON public.todos(work_capture_key) WHERE work_capture_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS todo_work_source_key ON public.todos(work_source_type,work_source_id) WHERE work_source_id IS NOT NULL;
ALTER TABLE public.swa_work_items ADD COLUMN IF NOT EXISTS communication_parties text[] NOT NULL DEFAULT '{}',
 ADD COLUMN IF NOT EXISTS communicated_parties jsonb NOT NULL DEFAULT '{}',
 ADD COLUMN IF NOT EXISTS completion_evidence text,
 ADD COLUMN IF NOT EXISTS hold_reason text,
 ADD COLUMN IF NOT EXISTS context jsonb NOT NULL DEFAULT '{}';
CREATE TABLE notification_private.work_requests(
 request_id uuid PRIMARY KEY, owner_user_id uuid NOT NULL, todo_id bigint NOT NULL,
 request_body jsonb NOT NULL, result jsonb NOT NULL, recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE notification_private.work_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.work_requests FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION swa_private.sync_todo(p_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; uid uuid; w public.swa_work_items; terminal boolean; cat text; subj text;
BEGIN
 SELECT * INTO t FROM public.todos WHERE id=p_id;
 IF NOT FOUND THEN RETURN; END IF;
 uid:=coalesce(t.assigned_to_user_id,t.owner_user_id);
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM swa_private.operator_ids WHERE user_id=uid) THEN RETURN; END IF;
 terminal:=NOT notification_private.todo_actionable(t);
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=t.id::text FOR UPDATE;
 IF terminal THEN
  IF w.id IS NOT NULL AND w.source_state IS DISTINCT FROM 'terminal' THEN
   UPDATE public.swa_work_items SET source_state='terminal',stage=CASE WHEN t.deleted_at IS NOT NULL THEN 'cancelled' ELSE 'completed' END,completed_at=CASE WHEN t.deleted_at IS NULL THEN coalesce(t.solved_at,clock_timestamp()) ELSE completed_at END,cancelled_at=CASE WHEN t.deleted_at IS NOT NULL THEN coalesce(cancelled_at,clock_timestamp()) ELSE cancelled_at END,row_version=row_version+1,updated_at=clock_timestamp()
   WHERE id=w.id;
  END IF;
  RETURN;
 END IF;
 cat:=CASE lower(coalesce(t.category,'')) WHEN 'permission' THEN 'inform_manager' WHEN 'task' THEN 'my_task' WHEN 'salary' THEN 'salary_note' ELSE 'general' END;
 subj:=left(coalesce(nullif(btrim(t.note_bn),''),nullif(btrim(t.note),''),'To-Do #'||t.id),500);
 IF w.id IS NULL THEN
  INSERT INTO public.swa_work_items(capture_key,owner_user_id,source_module,source_record_id,source_state,category,
   subject,requestor,project,priority,manager_required,communication_required,execution_required,verification_required,
   stage,next_action,next_party,next_review_at,captured_after_hours,captured_at)
  VALUES(coalesce(t.work_capture_key,gen_random_uuid()),uid,'todo',t.id::text,t.status,cat,subj,left(t.who,200),left(t.project,200),
   CASE WHEN t.is_important THEN 'important' ELSE 'routine' END,cat='inform_manager',cat='inform_manager',cat IN ('my_task','salary_note'),cat='salary_note',
   CASE WHEN cat='inform_manager' THEN 'waiting_manager' ELSE 'active' END,
   CASE WHEN cat='inform_manager' THEN 'ম্যানেজারকে বিষয়টি জানান' ELSE 'পরবর্তী পদক্ষেপ ঠিক করুন' END,'You',
   coalesce(t.next_reminder_at,clock_timestamp()+interval '1 day'),
   (coalesce(t.created_at,clock_timestamp()) AT TIME ZONE 'Asia/Dhaka')::time NOT BETWEEN time '09:00' AND time '17:59:59.999999',
   coalesce(t.created_at,clock_timestamp()));
 ELSE
  IF w.source_state='terminal' AND w.stage IN ('completed','cancelled') THEN
   UPDATE public.swa_work_items SET stage='active',completed_at=NULL,cancelled_at=NULL,manager_informed_at=NULL,manager_decision='none',manager_decision_at=NULL,communicated_at=NULL,communicated_parties='{}',executed_at=NULL,verified_at=NULL,next_action='পরবর্তী পদক্ষেপ ঠিক করুন',next_review_at=clock_timestamp()+interval '1 day' WHERE id=w.id;
   INSERT INTO public.swa_work_events(item_id,actor_user_id,event_type,payload) VALUES(w.id,uid,'source_reopened',jsonb_build_object('old_work',to_jsonb(w)));
  END IF;
  UPDATE public.swa_work_items SET source_state=t.status,subject=subj,project=left(t.project,200),requestor=left(t.who,200),
   category=cat,updated_at=clock_timestamp(),row_version=row_version+1
  WHERE id=w.id AND (source_state,subject,project,requestor,category) IS DISTINCT FROM (t.status,subj,left(t.project,200),left(t.who,200),cat);
 END IF;
END $$;
-- Reminder-only updates must not manufacture a new workflow version.
DROP TRIGGER IF EXISTS swa_todo_sync ON public.todos;
CREATE TRIGGER swa_todo_sync AFTER INSERT OR UPDATE OF note,note_bn,status,solved_at,deleted_at,category,project,who,is_important ON public.todos
FOR EACH ROW EXECUTE FUNCTION swa_private.todo_sync_trigger();

CREATE FUNCTION notification_private.work_summary(w public.swa_work_items,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE steps jsonb:='[]'; party text; due timestamptz; risk text; action text; grp text; t public.todos; src jsonb; allocation_problem boolean:=false; month_start date;
BEGIN
 SELECT * INTO t FROM public.todos WHERE id::text=w.source_record_id AND w.source_module='todo';
 IF NOT notification_private.todo_actionable(t) THEN RETURN jsonb_build_object('active',false,'steps','[]'::jsonb,'group','resolved'); END IF;
 IF w.stage IN ('completed','cancelled') THEN RETURN jsonb_build_object('active',false,'steps','[]'::jsonb,'group','resolved'); END IF;
 IF w.manager_required AND w.manager_informed_at IS NULL THEN steps:=steps||'"ম্যানেজারকে জানান"'::jsonb; END IF;
 IF w.approval_required AND w.manager_decision NOT IN ('approved','rejected') THEN steps:=steps||'"ম্যানেজারের সিদ্ধান্ত নিন"'::jsonb; END IF;
 IF w.communication_required THEN
  IF cardinality(w.communication_parties)=0 AND w.communicated_at IS NULL THEN steps:=steps||'"সিদ্ধান্ত সংশ্লিষ্ট পক্ষকে জানান"'::jsonb; END IF;
  FOREACH party IN ARRAY w.communication_parties LOOP
   IF NOT w.communicated_parties ? party THEN steps:=steps||jsonb_build_array('জানান: '||party); END IF;
  END LOOP;
 END IF;
 IF w.execution_required AND w.executed_at IS NULL AND NOT(w.approval_required AND w.manager_decision='rejected') THEN steps:=steps||'"অফিসীয় কাজ সম্পাদন করুন"'::jsonb; END IF;
 IF w.verification_required AND w.verified_at IS NULL THEN steps:=steps||'"ফলাফল যাচাই করুন"'::jsonb; END IF;
 IF t.work_source_type IS NOT NULL THEN
  src:=notification_private.source_snapshot(t.work_source_type,t.work_source_id,w.owner_user_id);
  IF NOT coalesce((src->>'supported')::boolean,false) OR src->>'reason' IN ('source_missing','source_validation_failed') OR src->>'reason'='source_resolved_or_ineligible' AND EXISTS(SELECT 1 FROM public.todos q WHERE q.id=t.id AND q.work_source_type IS NOT NULL AND w.stage='blocked') THEN
   steps:=steps||'"মূল রেকর্ডের সংযোগ যাচাই করুন"'::jsonb;
  ELSIF coalesce((src->>'actionable')::boolean,false) OR (t.work_source_type='transfer' AND EXISTS(SELECT 1 FROM public.transfers q WHERE q.id::text=t.work_source_id AND lower(q.status) IN ('scheduled','joining pending') AND q.deleted_at IS NULL)) THEN steps:=steps||'"মূল মডিউলের প্রক্রিয়া সম্পন্ন করুন"'::jsonb; END IF;
 END IF;
 IF w.category='salary_note' AND coalesce((w.context->>'allocation_required')::boolean,false) THEN
  IF coalesce(w.context->>'salary_month','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' OR jsonb_typeof(w.context->'allocations') IS DISTINCT FROM 'array' THEN allocation_problem:=true;
  ELSE
   month_start:=(w.context->>'salary_month'||'-01')::date;
   SELECT EXISTS(SELECT 1 FROM generate_series(month_start::timestamp,(month_start+interval '1 month'-interval '1 day')::timestamp,interval '1 day') d
     WHERE (SELECT count(*) FROM jsonb_array_elements(w.context->'allocations') a WHERE d::date BETWEEN (a->>'from')::date AND (a->>'to')::date)<>1) INTO allocation_problem;
  END IF;
  IF allocation_problem THEN steps:=steps||'"বেতনের প্রকল্পভিত্তিক দিন বণ্টন যাচাই করুন"'::jsonb; END IF;
 END IF;
 SELECT min(x) INTO due FROM unnest(ARRAY[w.deadline_at,w.event_at,w.promised_at]) x;
 risk:=CASE WHEN due<=p_at THEN 'overdue' WHEN ((p_at AT TIME ZONE 'Asia/Dhaka')::time<time '09:00' OR (p_at AT TIME ZONE 'Asia/Dhaka')::time>=time '18:00') AND due<notification_private.next_office_open(p_at) THEN 'before_office_risk'
  WHEN due<=p_at+interval '24 hours' THEN 'due_soon' WHEN due IS NULL THEN 'date_unknown' ELSE 'future' END;
 action:=CASE WHEN w.stage IN ('blocked','waiting_external') THEN w.next_action ELSE coalesce(steps->>0,w.next_action) END;
 grp:=CASE WHEN w.manager_required AND (w.manager_informed_at IS NULL OR w.approval_required AND w.manager_decision NOT IN ('approved','rejected')) THEN 'BRIEF_MANAGER'
 WHEN w.stage IN ('blocked','waiting_external') THEN 'WAITING_FOLLOWUP' ELSE 'ACT_TODAY' END;
 RETURN jsonb_build_object('active',true,'steps',steps,'next_action',action,'next_party',coalesce(nullif(w.next_party,''),'You'),
 'next_review_at',w.next_review_at,'needs_next_action',btrim(coalesce(w.next_action,'')) IN ('','পরবর্তী পদক্ষেপ ঠিক করুন'),
 'needs_review',w.next_review_at IS NULL OR w.next_review_at<=p_at,'stale',w.updated_at<p_at-interval '7 days',
 'risk',risk,'actual_due_at',due,'group',grp,'can_complete',jsonb_array_length(steps)=0,
 'source',src,'source_type',t.work_source_type,'source_id',t.work_source_id,
 'after_hours_captured',w.captured_after_hours,'calendar_verified',false,
 'allocation_needs_verification',allocation_problem,'payroll_cutoff_configured',w.deadline_at IS NOT NULL,'promise_breached',w.promised_at<=p_at,'communication_pending',w.communication_required AND
 (w.communicated_at IS NULL OR EXISTS(SELECT 1 FROM unnest(w.communication_parties) z WHERE NOT w.communicated_parties ? z)));
END $$;

CREATE FUNCTION notification_private.next_office_open(p_at timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT (((p_at AT TIME ZONE 'Asia/Dhaka')::date + CASE WHEN (p_at AT TIME ZONE 'Asia/Dhaka')::time>=time '09:00' THEN 1 ELSE 0 END)+time '09:00') AT TIME ZONE 'Asia/Dhaka'
$$;
CREATE FUNCTION public.notification_work_get(p_todo_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; items jsonb; history jsonb;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 IF p_todo_id IS NULL THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('todo_id',t.id,'work',to_jsonb(s),'summary',notification_private.work_summary(s,clock_timestamp())) ORDER BY s.updated_at DESC),'[]') INTO items
  FROM public.todos t JOIN public.swa_work_items s ON s.source_module='todo' AND s.source_record_id=t.id::text
  WHERE s.owner_user_id=auth.uid() AND t.deleted_at IS NULL;
  RETURN jsonb_build_object('items',items,'checked_at',clock_timestamp());
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.todos WHERE id=p_todo_id AND coalesce(assigned_to_user_id,owner_user_id)=auth.uid()) THEN RAISE EXCEPTION 'Source access denied' USING ERRCODE='42501'; END IF;
 PERFORM swa_private.sync_todo(p_todo_id);
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=p_todo_id::text AND owner_user_id=auth.uid();
 IF w.id IS NULL THEN RAISE EXCEPTION 'Open source workflow unavailable'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.id DESC),'[]') INTO history FROM
 (SELECT event_type,event_at,recorded_at,channel,payload,id FROM public.swa_work_events WHERE item_id=w.id ORDER BY id DESC LIMIT 60) e;
 RETURN jsonb_build_object('work',to_jsonb(w),'summary',notification_private.work_summary(w,clock_timestamp()),'events',history,'checked_at',clock_timestamp());
END $$;

-- Preserve the foundation implementation as a private, uncallable building block.
ALTER FUNCTION public.swa_act(uuid,integer,text,text,timestamptz,uuid) SET SCHEMA swa_private;
ALTER FUNCTION swa_private.swa_act(uuid,integer,text,text,timestamptz,uuid) RENAME TO act_foundation;
REVOKE ALL ON FUNCTION swa_private.act_foundation(uuid,integer,text,text,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.swa_act(p_item_id uuid,p_expected_version integer,p_action text,p_value text DEFAULT NULL,p_occurred_at timestamptz DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS public.swa_work_items LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; before_w public.swa_work_items; summary jsonb; occurred timestamptz:=coalesce(p_occurred_at,clock_timestamp()); party text;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 -- Same lock order as a source edit: source row, then workflow row.
 PERFORM 1 FROM public.todos t JOIN public.swa_work_items s ON s.source_record_id=t.id::text AND s.source_module='todo'
 WHERE s.id=p_item_id AND s.owner_user_id=auth.uid() FOR UPDATE OF t;
 SELECT * INTO w FROM public.swa_work_items WHERE id=p_item_id AND owner_user_id=auth.uid() FOR UPDATE;
 IF w.id IS NULL THEN RAISE EXCEPTION 'Work item unavailable'; END IF;
 IF p_expected_version IS DISTINCT FROM w.row_version THEN RAISE EXCEPTION 'Conflict: refresh this item' USING ERRCODE='40001'; END IF;
 before_w:=w;
 IF p_action='complete' THEN
  summary:=notification_private.work_summary(w,clock_timestamp());
  IF NOT coalesce((summary->>'can_complete')::boolean,false) THEN RAISE EXCEPTION 'Required workflow or source steps remain'; END IF;
  IF length(btrim(coalesce(p_value,'')))<3 THEN RAISE EXCEPTION 'Completion outcome/evidence required'; END IF;
 END IF;
 IF p_action='communicated' AND w.approval_required AND w.manager_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Record the decision before communicating its outcome'; END IF;
 IF p_action='communicated' AND cardinality(w.communication_parties)>0 AND NOT coalesce(p_value,'')=ANY(w.communication_parties) THEN RAISE EXCEPTION 'Choose a required communication party'; END IF;
 IF p_action IN ('ack','snooze') AND least(w.deadline_at,w.event_at,w.promised_at)<(CASE WHEN p_action='ack' THEN clock_timestamp()+interval '4 hours' ELSE p_value::timestamptz END) THEN RAISE EXCEPTION 'Pause crosses the true deadline or promise'; END IF;
 IF p_action='verified' AND w.approval_required AND w.manager_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Required decision remains'; END IF;
 w:=swa_private.act_foundation(p_item_id,p_expected_version,p_action,p_value,p_occurred_at,p_session_id);
 IF p_action='reopen' THEN w.communicated_parties:='{}';w.completion_evidence:=NULL;w.acknowledged_until:=NULL;w.snoozed_until:=NULL; END IF;
 IF p_action='decision' AND before_w.manager_decision IS DISTINCT FROM p_value THEN
  -- New decision invalidates the old outcome steps, retained in the audit below.
  w.communicated_at:=NULL;w.communicated_parties:='{}';w.executed_at:=NULL;w.verified_at:=NULL;
  w.manager_informed_at:=coalesce(w.manager_informed_at,occurred);
 END IF;
 IF p_action='communicated' AND cardinality(w.communication_parties)>0 THEN
  w.communicated_parties:=w.communicated_parties||jsonb_build_object(p_value,occurred);
  IF EXISTS(SELECT 1 FROM unnest(w.communication_parties) z WHERE NOT w.communicated_parties ? z) THEN w.communicated_at:=NULL; END IF;
 END IF;
 IF p_action='complete' THEN w.completion_evidence:=left(p_value,2000); END IF;
 UPDATE public.swa_work_items SET communicated_parties=w.communicated_parties,communicated_at=w.communicated_at,
 manager_informed_at=w.manager_informed_at,executed_at=w.executed_at,verified_at=w.verified_at,completion_evidence=w.completion_evidence,acknowledged_until=w.acknowledged_until,snoozed_until=w.snoozed_until WHERE id=w.id;
 INSERT INTO public.swa_work_events(item_id,actor_user_id,event_type,event_at,channel,payload)
 VALUES(w.id,auth.uid(),'workflow_record',occurred,CASE WHEN p_action IN ('decision','communicated','informed') THEN 'manually_recorded' END,
 jsonb_build_object('action',p_action,'before',to_jsonb(before_w),'after',to_jsonb(w),'evidence_type','operator_recorded'));
 IF w.source_module='todo' THEN
  UPDATE public.todos SET updated_at=clock_timestamp(),
    status=CASE WHEN p_action='reopen' THEN 'pending' WHEN p_action='complete' THEN CASE WHEN w.manager_decision='rejected' THEN 'solved_rejected' ELSE 'solved_approved' END
                WHEN p_action='decision' AND p_value IN ('approved','rejected') THEN p_value ELSE status END,
    solved_at=CASE WHEN p_action='reopen' THEN NULL WHEN p_action='complete' THEN clock_timestamp() ELSE solved_at END,
    manager_status=CASE WHEN p_action='informed' THEN 'asked' WHEN p_action='decision' THEN p_value ELSE manager_status END
   WHERE id::text=w.source_record_id;
 END IF;
 RETURN w;
END $$;

CREATE FUNCTION public.notification_work_save(p_todo_id bigint,p_expected_version integer,p_request_id uuid,p_action text,p_payload jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; old_w public.swa_work_items; cached notification_private.work_requests; body jsonb; result jsonb;
 k text; b boolean; party text; typ text; sid text; s jsonb;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Request identity and payload required'; END IF;
 body:=jsonb_build_object('todo',p_todo_id,'version',p_expected_version,'action',p_action,'payload',p_payload);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,6317));
 SELECT * INTO cached FROM notification_private.work_requests WHERE request_id=p_request_id;
 IF FOUND THEN
  IF cached.owner_user_id<>auth.uid() OR cached.request_body<>body THEN RAISE EXCEPTION 'Request identity conflict'; END IF;
  RETURN cached.result;
 END IF;
 PERFORM 1 FROM public.todos WHERE id=p_todo_id AND coalesce(assigned_to_user_id,owner_user_id)=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Source access denied' USING ERRCODE='42501'; END IF;
 PERFORM swa_private.sync_todo(p_todo_id);
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=p_todo_id::text AND owner_user_id=auth.uid() FOR UPDATE;
 IF w.id IS NULL THEN RAISE EXCEPTION 'Workflow unavailable'; END IF;
 IF w.row_version IS DISTINCT FROM p_expected_version THEN RAISE EXCEPTION 'Conflict: refresh before saving' USING ERRCODE='40001'; END IF;
 old_w:=w;
 IF p_action='plan' THEN
  IF w.stage IN ('completed','cancelled') THEN RAISE EXCEPTION 'Reopen before editing'; END IF;
  IF length(btrim(coalesce(p_payload->>'next_action','')))<3 OR length(btrim(coalesce(p_payload->>'next_party','')))<2 THEN RAISE EXCEPTION 'Next action and responsible party required'; END IF;
  w.next_action:=left(btrim(p_payload->>'next_action'),400); w.next_party:=left(btrim(p_payload->>'next_party'),200);
  w.next_review_at:=nullif(p_payload->>'next_review_at','')::timestamptz;
  IF w.next_review_at IS NULL THEN RAISE EXCEPTION 'Next review time required'; END IF;
  w.deadline_at:=nullif(p_payload->>'deadline_at','')::timestamptz;w.event_at:=nullif(p_payload->>'event_at','')::timestamptz;
  w.promised_at:=nullif(p_payload->>'promised_at','')::timestamptz;
  w.manager_required:=coalesce((p_payload->>'manager_required')::boolean,false);
  w.approval_required:=coalesce((p_payload->>'approval_required')::boolean,false);
  w.communication_required:=coalesce((p_payload->>'communication_required')::boolean,false);
  w.execution_required:=coalesce((p_payload->>'execution_required')::boolean,false);
  w.verification_required:=coalesce((p_payload->>'verification_required')::boolean,false);
  IF w.approval_required AND NOT w.manager_required THEN RAISE EXCEPTION 'Approval requires manager briefing'; END IF;
  IF jsonb_typeof(coalesce(p_payload->'communication_parties','[]'))<>'array' THEN RAISE EXCEPTION 'Communication parties must be a list'; END IF;
  SELECT coalesce(array_agg(DISTINCT z),'{}') INTO w.communication_parties FROM jsonb_array_elements_text(coalesce(p_payload->'communication_parties','[]')) z;
  IF cardinality(w.communication_parties)>6 OR EXISTS(SELECT 1 FROM unnest(w.communication_parties) z WHERE length(btrim(z)) NOT BETWEEN 2 AND 100) THEN RAISE EXCEPTION 'Invalid communication party'; END IF;
  IF p_payload->>'priority' NOT IN ('routine','important','urgent','critical') THEN RAISE EXCEPTION 'Priority required'; END IF;
  w.priority:=p_payload->>'priority';w.context:=coalesce(p_payload->'context','{}');
  IF jsonb_typeof(w.context)<>'object' OR octet_length(w.context::text)>8000 THEN RAISE EXCEPTION 'Invalid context'; END IF;
  IF w.context ? 'allocations' THEN
   IF jsonb_typeof(w.context->'allocations')<>'array' OR jsonb_array_length(w.context->'allocations')>31 THEN RAISE EXCEPTION 'Invalid salary allocations'; END IF;
   FOR s IN SELECT value FROM jsonb_array_elements(w.context->'allocations') LOOP
    IF nullif(s->>'from','')::date IS NULL OR nullif(s->>'to','')::date IS NULL OR (s->>'from')::date>(s->>'to')::date OR length(btrim(coalesce(s->>'project','')))<1 THEN RAISE EXCEPTION 'Allocation project and valid dates required'; END IF;
   END LOOP;
  END IF;
  IF ((old_w.manager_required AND NOT w.manager_required) OR (old_w.approval_required AND NOT w.approval_required) OR (old_w.communication_required AND NOT w.communication_required) OR (old_w.execution_required AND NOT w.execution_required) OR (old_w.verification_required AND NOT w.verification_required)) AND length(btrim(coalesce(p_payload->>'change_reason','')))<3 THEN RAISE EXCEPTION 'Reason required for removing an existing workflow requirement'; END IF;
  w.stage:=coalesce(nullif(p_payload->>'stage',''),'active');
  IF w.stage NOT IN ('active','waiting_manager','waiting_external','blocked','verification') THEN RAISE EXCEPTION 'Invalid open stage'; END IF;
  w.hold_reason:=left(nullif(p_payload->>'hold_reason',''),500);
  IF w.stage='blocked' AND length(btrim(coalesce(w.hold_reason,'')))<3 THEN RAISE EXCEPTION 'Blocked reason required'; END IF;
  typ:=nullif(p_payload->>'source_type','');sid:=nullif(p_payload->>'source_id','');
  IF typ IS NOT NULL THEN
   IF typ='todo' OR sid IS NULL THEN RAISE EXCEPTION 'Choose an original module source'; END IF;
   s:=notification_private.source_snapshot(typ,sid,auth.uid());
   IF NOT coalesce((s->>'supported')::boolean,false) OR s->>'reason' IN ('source_missing','source_identifier_invalid','source_validation_failed') THEN RAISE EXCEPTION 'Original module source unavailable'; END IF;
  END IF;
  UPDATE public.swa_work_items SET next_action=w.next_action,next_party=w.next_party,next_review_at=w.next_review_at,
   deadline_at=w.deadline_at,event_at=w.event_at,promised_at=w.promised_at,manager_required=w.manager_required,
   approval_required=w.approval_required,communication_required=w.communication_required,communication_parties=w.communication_parties,
   execution_required=w.execution_required,verification_required=w.verification_required,priority=w.priority,stage=w.stage,
   context=w.context,hold_reason=w.hold_reason,row_version=row_version+1,updated_at=clock_timestamp() WHERE id=w.id RETURNING * INTO w;
  UPDATE public.todos SET work_managed=true,work_source_type=typ,work_source_id=sid,is_important=(w.priority<>'routine'),priority=CASE WHEN w.priority='routine' THEN 'normal' ELSE 'important' END,updated_at=clock_timestamp() WHERE id=p_todo_id;
  INSERT INTO public.swa_work_events(item_id,actor_user_id,event_type,payload) VALUES(w.id,auth.uid(),'plan_updated',jsonb_build_object('before',to_jsonb(old_w),'after',to_jsonb(w),'change_reason',p_payload->>'change_reason'));
 ELSE
  w:=public.swa_act(w.id,p_expected_version,p_action,p_payload->>'value',nullif(p_payload->>'occurred_at','')::timestamptz,nullif(p_payload->>'session_id','')::uuid);
  IF p_action='complete' THEN
   UPDATE public.todos SET status=CASE WHEN w.manager_decision='rejected' THEN 'solved_rejected' ELSE 'solved_approved' END,solved_at=clock_timestamp() WHERE id=p_todo_id;
  END IF;
 END IF;
 UPDATE public.todos SET updated_at=clock_timestamp() WHERE id=p_todo_id;
 result:=public.notification_work_get(p_todo_id);
 INSERT INTO notification_private.work_requests(request_id,owner_user_id,todo_id,request_body,result) VALUES(p_request_id,auth.uid(),p_todo_id,body,result);
 RETURN result;
END $$;

CREATE FUNCTION notification_private.todo_completion_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; j jsonb;
BEGIN
 IF NOT OLD.work_managed OR notification_private.todo_actionable(NEW) OR NOT notification_private.todo_actionable(OLD) THEN RETURN NEW; END IF;
 IF NEW.deleted_at IS NOT NULL THEN RETURN NEW; END IF;
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=OLD.id::text;
 IF w.id IS NULL THEN RAISE EXCEPTION 'Workflow missing: review this source'; END IF;
 IF w.stage NOT IN ('completed','cancelled') THEN
  j:=notification_private.work_summary(w,clock_timestamp());
  IF NOT coalesce((j->>'can_complete')::boolean,false) THEN RAISE EXCEPTION 'Required workflow steps remain. Open Work steps.'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER notification_todo_completion_guard BEFORE UPDATE OF status,solved_at ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.todo_completion_guard();

CREATE FUNCTION public.notification_work_capture(p_capture_key uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE tid bigint; cat text; txt text;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 IF p_capture_key IS NULL OR jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Capture identity required'; END IF;
 cat:=p_payload->>'category';txt:=btrim(p_payload->>'subject');
 IF cat NOT IN ('note','task','permission','salary') OR length(coalesce(txt,'')) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Valid category and subject required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_capture_key::text,6317));
 SELECT id INTO tid FROM public.todos WHERE work_capture_key=p_capture_key AND coalesce(assigned_to_user_id,owner_user_id)=auth.uid();
 IF tid IS NULL THEN
  INSERT INTO public.todos(note,note_bn,category,project,who,status,date,owner_user_id,assigned_to_user_id,work_capture_key,reminder_enabled)
  VALUES(txt,txt,cat,left(p_payload->>'project',200),left(p_payload->>'requestor',200),'pending',(clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date,auth.uid(),auth.uid(),p_capture_key,true) RETURNING id INTO tid;
 END IF;
 RETURN jsonb_build_object('saved',true,'todo_id',tid,'capture_key',p_capture_key);
END $$;

CREATE FUNCTION notification_private.sync_work_deadline(p_todo_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; s jsonb;
BEGIN
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=p_todo_id::text;
 IF w.id IS NULL OR w.deadline_at IS NULL THEN
  DELETE FROM notification_private.core_verified_deadlines WHERE entity_type='todo' AND entity_id=p_todo_id::text;
  RETURN;
 END IF;
 s:=notification_private.source_snapshot('todo',p_todo_id::text,w.owner_user_id);
 INSERT INTO notification_private.core_verified_deadlines(entity_type,entity_id,recipient_user_id,source_version,actual_deadline_at,verified_basis,evidence_reference)
 VALUES('todo',p_todo_id::text,w.owner_user_id,s->>'source_version',w.deadline_at,'manual_verified','operator work plan '||w.id::text)
 ON CONFLICT(entity_type,entity_id,recipient_user_id) DO UPDATE SET source_version=EXCLUDED.source_version,actual_deadline_at=EXCLUDED.actual_deadline_at,verified_at=clock_timestamp(),evidence_reference=EXCLUDED.evidence_reference;
END $$;
CREATE FUNCTION notification_private.work_deadline_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN PERFORM notification_private.sync_work_deadline(NEW.id);RETURN NEW;END $$;
CREATE TRIGGER notification_work_deadline AFTER INSERT OR UPDATE ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.work_deadline_trigger();

-- One persistent task per original source. The registry deliberately excludes
-- informational meeting/disciplinary records from automatic work creation.
CREATE FUNCTION notification_private.sync_module_work(p_type text,p_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE tab text; keycol text:='id'; r jsonb; uid uuid; snap jsonb; tid bigint; w public.swa_work_items; st text; label text; cat text:='task'; is_open boolean;
BEGIN
 CASE p_type WHEN 'transfer' THEN tab:='transfers';label:='Joining confirmation';
 WHEN 'exit' THEN tab:='exits';label:='Exit follow-up';
 WHEN 'leave' THEN tab:='leaves';label:='Leave request';cat:='permission';
 WHEN 'uniform_supply_order' THEN tab:='uniform_supply_orders';label:='Uniform order';
 WHEN 'uniform_delivery_issue' THEN tab:='uniform_delivery_issues';label:='Uniform delivery issue';
 WHEN 'uniform_delivery_bill' THEN tab:='uniform_delivery_bills';label:='Uniform bill follow-up';
 WHEN 'recruitment' THEN tab:='recruitment_archive';label:='Candidate follow-up';keycol:='archive_id';
 ELSE RETURN; END CASE;
 SELECT o.user_id INTO uid FROM swa_private.operator_ids o JOIN public.profiles p ON p.id=o.user_id AND p.is_active LIMIT 1;
 IF uid IS NULL THEN RETURN; END IF;
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE %I::text=$1',tab,keycol) INTO r USING p_id;
 SELECT id INTO tid FROM public.todos WHERE work_source_type=p_type AND work_source_id=p_id;
 snap:=notification_private.source_snapshot(p_type,p_id,uid);
 is_open:=coalesce((snap->>'actionable')::boolean,false);
 -- Scheduled future joining still needs preparation; date arrival never executes HR.
 IF p_type='transfer' AND r->>'deleted_at' IS NULL AND lower(coalesce(r->>'status','')) IN ('scheduled','joining pending')
 AND r->>'joining_confirmed_at' IS NULL AND r->>'not_joined_at' IS NULL AND r->>'cancelled_at' IS NULL AND r->>'completed_at' IS NULL THEN is_open:=true; END IF;
 IF tid IS NULL AND NOT is_open THEN RETURN; END IF;
 IF tid IS NULL THEN
  INSERT INTO public.todos(note,note_bn,category,project,who,status,date,owner_user_id,assigned_to_user_id,work_source_type,work_source_id,work_managed,reminder_enabled,is_important)
  VALUES(label||' #'||p_id,label||' #'||p_id,cat,left(coalesce(r->>'project_name',r->>'new_project',r->>'current_project',r->>'project_name_snapshot'),200),
   left(coalesce(r->>'full_name',r->>'candidate_name'),200),'pending',(clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date,uid,uid,p_type,p_id,true,true,p_type IN ('leave','transfer','uniform_delivery_issue')) RETURNING id INTO tid;
  UPDATE public.swa_work_items SET execution_required=false,communication_required=(p_type='leave'),manager_required=(p_type='leave'),
   communication_parties=CASE WHEN p_type='leave' THEN ARRAY['Project / Requestor'] ELSE '{}'::text[] END,
   next_action='মূল মডিউলের বর্তমান অবস্থা পর্যালোচনা করুন',context=jsonb_build_object('source_date',coalesce(r->>'effective_date',r->>'from_date'),'date_precision','date_only','adapter_created',true)
  WHERE source_module='todo' AND source_record_id=tid::text;
 END IF;
 SELECT * INTO w FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=tid::text;
 IF r IS NOT NULL AND w.context->>'adapter_source_version' IS DISTINCT FROM md5(r::text) THEN
  UPDATE public.swa_work_items SET context=context||jsonb_build_object('adapter_source_version',md5(r::text),'source_date',coalesce(r->>'effective_date',r->>'from_date')),row_version=row_version+1,updated_at=clock_timestamp() WHERE id=w.id;
  UPDATE public.todos SET updated_at=clock_timestamp() WHERE id=tid;
 END IF;
 IF r IS NULL OR r->>'deleted_at' IS NOT NULL THEN
  UPDATE public.swa_work_items SET hold_reason='Original source missing or deleted; review before closing',stage='blocked',next_action='মূল রেকর্ডটি যাচাই করুন',row_version=row_version+1
   WHERE id=w.id AND hold_reason IS DISTINCT FROM 'Original source missing or deleted; review before closing';
 ELSIF NOT is_open AND coalesce((notification_private.work_summary(w,clock_timestamp())->>'can_complete')::boolean,false) THEN
  -- No outstanding sidecar obligation; authoritative source closure is enough.
  UPDATE public.todos SET status='solved_approved',solved_at=clock_timestamp() WHERE id=tid AND notification_private.todo_actionable(todos);
 END IF;
END $$;
CREATE FUNCTION notification_private.module_work_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN PERFORM notification_private.sync_module_work(TG_ARGV[0],coalesce(to_jsonb(NEW)->>'id',to_jsonb(NEW)->>'archive_id')); RETURN NEW;END $$;
DO $$
DECLARE typ text; tab text;
BEGIN
 FOR typ,tab IN SELECT * FROM (VALUES('transfer','transfers'),('exit','exits'),('leave','leaves'),('uniform_supply_order','uniform_supply_orders'),('uniform_delivery_issue','uniform_delivery_issues'),('uniform_delivery_bill','uniform_delivery_bills'),('recruitment','recruitment_archive')) v(a,b) LOOP
  EXECUTE format('CREATE TRIGGER notification_module_work AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION notification_private.module_work_trigger(%L)',tab,typ);
 END LOOP;
END $$;
CREATE FUNCTION notification_private.reconcile_module_work()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE typ text; tab text; keycol text; ident text; n int:=0;
BEGIN
 FOR typ,tab,keycol IN SELECT * FROM (VALUES('transfer','transfers','id'),('exit','exits','id'),('leave','leaves','id'),('uniform_supply_order','uniform_supply_orders','id'),('uniform_delivery_issue','uniform_delivery_issues','id'),('uniform_delivery_bill','uniform_delivery_bills','id'),('recruitment','recruitment_archive','archive_id')) v(a,b,c) LOOP
  FOR ident IN EXECUTE format('SELECT %I::text FROM public.%I',keycol,tab) LOOP
   PERFORM notification_private.sync_module_work(typ,ident); n:=n+1;
  END LOOP;
 END LOOP;
 RETURN n;
END $$;
-- Replace To-Do-only grouping with source-linked obligation grouping. All work
-- is still an existing To-Do; quotas, leases, preferences and source guards apply.
CREATE OR REPLACE FUNCTION notification_private.digest_plan(p_recipient uuid,p_day date,p_kind text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE j jsonb; items jsonb; grps jsonb;
BEGIN
 j:=notification_private.digest_source_plan(p_recipient,p_day,p_kind,p_at);
 WITH expanded AS (
 SELECT x,t.id,w.id wid,notification_private.work_summary(w,p_at) s,
 least(w.deadline_at,w.promised_at,w.event_at) due
 FROM jsonb_array_elements(j->'items') x JOIN public.todos t ON t.id::text=x->>'todo_id'
 LEFT JOIN public.swa_work_items w ON w.source_module='todo' AND w.source_record_id=t.id::text AND w.owner_user_id=p_recipient
 WHERE coalesce(t.reminder_enabled,false)
 AND (w.id IS NULL OR w.stage NOT IN ('completed','cancelled'))
 AND NOT EXISTS(SELECT 1 FROM notification_private.source_interactions a WHERE a.recipient_user_id=p_recipient AND a.entity_type='todo' AND a.entity_id=t.id::text AND (a.acknowledged_until>p_at OR a.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.swa_work_items a WHERE a.id=w.id AND (a.acknowledged_until>p_at OR a.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo' AND n.entity_id=t.id::text AND n.snoozed_until>p_at)
 ), grouped AS (
 SELECT x||jsonb_build_object('group_key',CASE WHEN due<=p_at THEN 'OVERDUE'
 WHEN p_kind='wrapup' AND due<((p_day+1+time '09:00') AT TIME ZONE 'Asia/Dhaka') THEN 'BEFORE_NEXT_OPEN_RISK'
 WHEN (due AT TIME ZONE 'Asia/Dhaka')::date=p_day THEN 'DUE_TODAY'
 WHEN wid IS NOT NULL THEN coalesce(s->>'group','ACT_TODAY') ELSE x->>'group_key' END,
 'actual_due_at',due,'next_action',s->>'next_action','source_type',s->>'source_type','source_id',s->>'source_id') val FROM expanded
 ) SELECT coalesce(jsonb_agg(val),'[]') INTO items FROM grouped;
 SELECT coalesce(jsonb_object_agg(g,c),'{}') INTO grps FROM (SELECT x->>'group_key' g,count(*) c FROM jsonb_array_elements(items) x GROUP BY 1) a;
 RETURN j||jsonb_build_object('items',items,'item_count',jsonb_array_length(items),'groups',grps,'risk_count',
 (SELECT count(*) FROM jsonb_array_elements(items) x WHERE x->>'group_key' IN ('OVERDUE','BEFORE_NEXT_OPEN_RISK')));
END $$;

-- Sync all existing open To-Dos without resetting their status or reminders.
DO $$DECLARE tid bigint; BEGIN
 FOR tid IN SELECT id FROM public.todos t WHERE notification_private.todo_actionable(t) LOOP PERFORM swa_private.sync_todo(tid); END LOOP;
END $$;
-- Last-mile dispatcher keeps the existing worker contract.
CREATE OR REPLACE FUNCTION public.notification_get_web_push_dispatch(p_job_id bigint, p_worker_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_notification public.notifications%rowtype;
  v_deliveries jsonb;
  v_digest_invalid boolean:=false;
  v_governance boolean:=false;
  v_bridge boolean:=false;
  v_source_blocked boolean;
  v_quota jsonb;
  v_now timestamptz:=clock_timestamp();
  v_next timestamptz;
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
      btrim(p_worker_id)
  FOR UPDATE;

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

  -- A snooze or quiet-hour change can happen after the worker claimed this job.
  -- Defer without consuming a send attempt or permanently skipping a later alert.
  if v_notification.scheduled_for>clock_timestamp() then
    update public.notification_jobs set job_status='Pending',run_at=v_notification.scheduled_for,
      attempt_count=greatest(0,attempt_count-1),locked_at=null,locked_by=null
      where id=v_job.id and locked_by=btrim(p_worker_id);
    return jsonb_build_object('deferred',true,'deliveries','[]'::jsonb);
  end if;

  SELECT enabled INTO v_governance FROM notification_private.governance_control WHERE singleton;
  SELECT enabled INTO v_bridge FROM notification_private.digest_bridge_control WHERE singleton;
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false) AND EXISTS(
    SELECT 1 FROM notification_private.core_policy_limits p WHERE singleton AND
    ((v_now AT TIME ZONE 'Asia/Dhaka')::time<p.push_start OR (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end)
  ) THEN
    SELECT (((v_now AT TIME ZONE 'Asia/Dhaka')::date+
      CASE WHEN (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end THEN 1 ELSE 0 END)+p.push_start)
      AT TIME ZONE 'Asia/Dhaka' INTO v_next FROM notification_private.core_policy_limits p WHERE singleton;
    UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
      attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
    RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','outside_routine_push_window');
  END IF;

  -- Source ACK/Snooze is an explicit new user action, effective in V1 too.
  -- Deferral never completes or removes the source and does not consume retries.
  SELECT greatest(a.acknowledged_until,a.snoozed_until) INTO v_next
  FROM notification_private.source_interactions a WHERE a.recipient_user_id=v_notification.recipient_user_id
    AND a.entity_type=v_notification.entity_type AND a.entity_id=v_notification.entity_id;
  IF v_next>v_now THEN
    UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
      attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
    RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','explicit_source_work_lease');
  END IF;

  v_source_blocked := notification_private.push_source_ineligible(
    v_notification.entity_type, v_notification.entity_id, v_notification.recipient_user_id
  );

  IF coalesce(v_governance,false) AND coalesce(v_bridge,false) AND v_notification.entity_type<>'digest' THEN
    v_source_blocked:=v_source_blocked OR EXISTS(SELECT 1 FROM public.todos t WHERE t.work_source_type=v_notification.entity_type AND t.work_source_id=v_notification.entity_id AND t.deleted_at IS NULL);
    v_source_blocked:=v_source_blocked OR NOT coalesce((notification_private.source_snapshot(
      v_notification.entity_type,v_notification.entity_id,v_notification.recipient_user_id)->>'actionable')::boolean,false);
  END IF;
  SELECT enabled INTO v_governance FROM notification_private.governance_control WHERE singleton;
  SELECT enabled INTO v_bridge FROM notification_private.digest_bridge_control WHERE singleton;
  IF v_notification.entity_type='digest' THEN
    -- A queued digest is NEVER sent after either policy switch is disabled.
    -- This is a permanent containment gate, independent of V1 compatibility.
    v_digest_invalid:=NOT (coalesce(v_governance,false)
      AND coalesce(v_bridge,false)
      AND notification_private.digest_dispatch_allowed(
        v_notification.entity_id,v_notification.recipient_user_id,clock_timestamp()));
  END IF;

  -- Recheck immediately before dispatch, including source, preferences and live presence.
  update public.notification_deliveries d set delivery_status='Skipped',
    provider_status='DispatchIneligible',response_metadata=coalesce(d.response_metadata,'{}'::jsonb)||jsonb_build_object('checked_at',clock_timestamp(),
      'gate_reason',case when v_digest_invalid then 'digest_source_or_window_invalid'
        when v_source_blocked then 'source_ineligible_or_recipient_changed'
        else 'dispatch_ineligible_other' end)
  where d.notification_id=v_notification.id and d.channel='WebPush' and d.delivery_status in ('Pending','Failed')
  and (
    v_notification.status in ('Completed','Cancelled','Expired','Dismissed')
    or (v_notification.expires_at is not null and v_notification.expires_at<=clock_timestamp())
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'notification_enabled')::boolean,true)
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'system_push_enabled')::boolean,true)
    or v_source_blocked
    or v_digest_invalid
    or (public.notification_reminder_mode() and coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'in_app_enabled')::boolean,true) and notification_private.has_foreground(v_notification.recipient_user_id))
    or not exists(select 1 from public.push_subscriptions s where s.id=d.subscription_id and s.user_id=v_notification.recipient_user_id and s.is_active and s.permission_state='granted' and s.revoked_at is null)
  );

  -- Serializes competing job dispatches for this recipient, including digest
  -- and direct-source notifications. Existing preference/source checks ran first.
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false)
    AND EXISTS(SELECT 1 FROM public.notification_deliveries WHERE notification_id=v_notification.id
      AND channel='WebPush' AND delivery_status IN ('Pending','Failed')) THEN
    -- Consistent lock order with result recording: own job, then recipient.
    PERFORM 1 FROM public.notification_jobs WHERE id=v_job.id FOR UPDATE;
    v_quota:=notification_private.reserve_push(v_notification.id,v_now);
    IF v_quota->>'reason'='outside_routine_push_window' THEN
      SELECT (((v_now AT TIME ZONE 'Asia/Dhaka')::date+
        CASE WHEN (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end THEN 1 ELSE 0 END)+p.push_start)
        AT TIME ZONE 'Asia/Dhaka' INTO v_next FROM notification_private.core_policy_limits p WHERE singleton;
      UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
        attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
      RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','outside_routine_push_window');
    END IF;
    IF NOT coalesce((v_quota->>'allowed')::boolean,false) THEN
      UPDATE public.notification_deliveries SET delivery_status='Skipped',provider_status='GovernanceSuppressed',
        response_metadata=coalesce(response_metadata,'{}'::jsonb)||jsonb_build_object('gate_reason',v_quota->>'reason','checked_at',v_now)
      WHERE notification_id=v_notification.id AND channel='WebPush' AND delivery_status IN ('Pending','Failed');
    END IF;
  END IF;

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
          CASE WHEN coalesce(v_governance,false) AND coalesce(v_bridge,false) THEN 'MG-HRM' ELSE v_notification.title END,
        'message',
          CASE WHEN coalesce(v_governance,false) AND coalesce(v_bridge,false) THEN 'Your work summary is ready. Open MG-HRM to review current actions.' ELSE v_notification.message END,
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

CREATE TABLE notification_private.work_engine_runs(
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),last_started_at timestamptz,
 last_succeeded_at timestamptz,last_error text,source_rows_checked int);
INSERT INTO notification_private.work_engine_runs(singleton) VALUES(true);
ALTER TABLE notification_private.work_engine_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.work_engine_runs FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.notification_cron_tick()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE dg jsonb; ev jsonb; delivery jsonb; checked int;
BEGIN
 IF NOT pg_try_advisory_xact_lock(73110420261011) THEN RETURN jsonb_build_object('status','Skipped','reason','Another processor is running'); END IF;
 IF EXISTS(SELECT 1 FROM notification_private.governance_control WHERE singleton AND enabled)
 AND EXISTS(SELECT 1 FROM notification_private.digest_bridge_control WHERE singleton AND enabled) THEN
  UPDATE notification_private.work_engine_runs SET last_started_at=clock_timestamp() WHERE singleton;
  checked:=notification_private.reconcile_module_work();
  PERFORM public.swa_reconcile(500);
  dg:=notification_private.digest_publish_for_operators(clock_timestamp());
  ev:=public.notification_run_event_processor('cron:notification-v2-workflow',25,interval '15 minutes');
  delivery:=public.notification_prepare_deliveries(25);
  UPDATE notification_private.work_engine_runs SET last_succeeded_at=clock_timestamp(),last_error=NULL,source_rows_checked=checked WHERE singleton;
  RETURN jsonb_build_object('status','Completed','mode','governance_digest_bridge','digest',dg,'event_processor',ev,'delivery_processor',delivery,'source_rows_checked',checked,'finished_at',clock_timestamp());
 END IF;
 PERFORM public.notification_schedule_todos(100);
 RETURN jsonb_build_object('status','Completed','mode','legacy','processor',public.notification_run_server_processor('cron:notification-server-processor',25,interval '15 minutes'),'finished_at',clock_timestamp());
EXCEPTION WHEN OTHERS THEN
 UPDATE notification_private.work_engine_runs SET last_error=left(SQLERRM,400) WHERE singleton;
 RAISE WARNING 'Notification workflow reconciliation failed: %',SQLERRM;
 RETURN jsonb_build_object('status','Failed','error',left(SQLERRM,400),'finished_at',clock_timestamp());
END $$;
CREATE FUNCTION public.notification_work_brief_summary(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF NOT public.swa_is_operator() OR NOT EXISTS(SELECT 1 FROM public.swa_brief_sessions WHERE id=p_session_id AND owner_user_id=auth.uid()) THEN RAISE EXCEPTION 'Briefing access denied' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('discussed',count(DISTINCT e.item_id),
 'decision_recorded',count(DISTINCT e.item_id) FILTER(WHERE e.event_type='decision'),
 'pending_decision',count(DISTINCT e.item_id) FILTER(WHERE w.approval_required AND w.manager_decision NOT IN ('approved','rejected')))
 INTO result FROM public.swa_work_events e JOIN public.swa_work_items w ON w.id=e.item_id WHERE e.session_id=p_session_id;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.notification_work_brief_summary(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_work_brief_summary(uuid) TO authenticated;
-- Privilege closure: public RPCs authenticate internally; everything else private.
REVOKE ALL ON FUNCTION notification_private.work_summary(public.swa_work_items,timestamptz),
 notification_private.next_office_open(timestamptz),notification_private.sync_work_deadline(bigint),
 notification_private.work_deadline_trigger(),notification_private.todo_completion_guard(),
 notification_private.sync_module_work(text,text),notification_private.module_work_trigger(),notification_private.reconcile_module_work()
 FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.notification_work_get(bigint),public.notification_work_save(bigint,integer,uuid,text,jsonb),
 public.notification_work_capture(uuid,jsonb),public.swa_act(uuid,integer,text,text,timestamptz,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_work_get(bigint),public.notification_work_save(bigint,integer,uuid,text,jsonb),
 public.notification_work_capture(uuid,jsonb),public.swa_act(uuid,integer,text,text,timestamptz,uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.swa_capture(uuid,jsonb) FROM authenticated;
COMMIT;
