-- AT-047/053/067: capture visibility, preclose risk and suggestion-only duplicates.
-- No HR source actions, gate activation, calendar assumptions or record merging.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';
CREATE OR REPLACE FUNCTION notification_private.work_summary(w public.swa_work_items,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE steps jsonb:='[]'; party text; due timestamptz; risk text; action text; grp text; t public.todos; src jsonb; allocation_problem boolean:=false; month_start date; step jsonb;
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
 FOR step IN SELECT value FROM jsonb_array_elements(coalesce(w.context->'checklist','[]')) LOOP
  IF coalesce((step->>'required')::boolean,true) AND step->>'completed_at' IS NULL THEN steps:=steps||jsonb_build_array(step->>'label'); END IF;
 END LOOP;
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
 risk:=CASE WHEN due<=p_at THEN 'overdue' WHEN ((p_at AT TIME ZONE 'Asia/Dhaka')::time<time '09:00' OR (p_at AT TIME ZONE 'Asia/Dhaka')::time>=time '18:00' OR due>=(((p_at AT TIME ZONE 'Asia/Dhaka')::date+time '18:00') AT TIME ZONE 'Asia/Dhaka')) AND due<notification_private.next_office_open(p_at) THEN 'before_office_risk'
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

-- Reuse the original guarded RPC. Candidate matches are suggestions only;
-- project/category/requestor boundaries are retained and no row is merged.
ALTER FUNCTION public.notification_work_get(bigint) SET SCHEMA notification_private;
ALTER FUNCTION notification_private.notification_work_get(bigint) RENAME TO work_get_foundation;
REVOKE ALL ON FUNCTION notification_private.work_get_foundation(bigint) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.notification_work_get(p_todo_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; matches jsonb;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 result:=notification_private.work_get_foundation(p_todo_id);
 IF p_todo_id IS NULL THEN RETURN result; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('todo_id',c.id,'subject',left(coalesce(nullif(c.note_bn,''),c.note,''),500)) ORDER BY c.id),'[]') INTO matches
 FROM public.todos t JOIN public.todos c ON c.id<>t.id
 AND coalesce(c.assigned_to_user_id,c.owner_user_id)=auth.uid()
 AND c.category IS NOT DISTINCT FROM t.category
 AND lower(btrim(coalesce(c.project,'')))=lower(btrim(coalesce(t.project,'')))
 AND lower(btrim(coalesce(c.who,'')))=lower(btrim(coalesce(t.who,'')))
 AND lower(btrim(coalesce(nullif(c.note_bn,''),c.note,'')))=lower(btrim(coalesce(nullif(t.note_bn,''),t.note,'')))
 WHERE t.id=p_todo_id AND coalesce(t.assigned_to_user_id,t.owner_user_id)=auth.uid()
 AND notification_private.todo_actionable(c);
 RETURN result||jsonb_build_object('duplicate_candidates',matches);
END $$;
REVOKE ALL ON FUNCTION public.notification_work_get(bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.notification_work_get(bigint) TO authenticated;
REVOKE ALL ON FUNCTION notification_private.work_summary(public.swa_work_items,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
