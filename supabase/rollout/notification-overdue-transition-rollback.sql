-- Restore prior approaching-alert coalescence without deleting work or history.
BEGIN;
CREATE OR REPLACE FUNCTION notification_private.publish_work_attention(p_at timestamptz)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; t public.todos; due timestamptz; fp text; key text; n int:=0; reason text; pol notification_private.core_policy_limits;
BEGIN
 SELECT * INTO pol FROM notification_private.core_policy_limits WHERE singleton;
 IF (p_at AT TIME ZONE 'Asia/Dhaka')::time<pol.push_start OR (p_at AT TIME ZONE 'Asia/Dhaka')::time>=pol.push_end THEN RETURN 0; END IF;
 FOR w IN SELECT * FROM public.swa_work_items WHERE source_module='todo' AND stage NOT IN ('completed','cancelled')
 AND priority IN ('important','urgent','critical') LOOP
  SELECT * INTO t FROM public.todos WHERE id::text=w.source_record_id;
  IF NOT notification_private.todo_actionable(t) OR NOT coalesce(t.reminder_enabled,false) THEN CONTINUE; END IF;
  due:=least(w.deadline_at,w.event_at,w.promised_at);
  IF due IS NULL OR due>p_at+interval '4 hours' THEN CONTINUE; END IF;
  reason:=CASE WHEN due<=p_at THEN 'overdue_work' ELSE 'verified_time_risk' END;
  fp:=notification_private.source_snapshot('todo',t.id::text,w.owner_user_id)->>'source_version';
  -- A grouped occurrence already represents this exact source version. New
  -- captures/changed plans may surface, but overlapping policies do not buzz twice.
  IF EXISTS(SELECT 1 FROM notification_private.push_occurrences o WHERE o.recipient_user_id=w.owner_user_id AND o.entity_type='todo' AND o.entity_id=t.id::text AND o.source_version=fp AND o.state<>'Released' AND coalesce(o.accepted_at,o.reserved_at)>p_at-interval '24 hours')
  OR EXISTS(SELECT 1 FROM notification_private.digest_items di JOIN notification_private.digest_batches b ON b.id=di.batch_id
    JOIN public.notification_events e ON e.entity_type='digest' AND e.entity_id=b.id::text
    WHERE b.recipient_user_id=w.owner_user_id AND di.todo_id=t.id AND di.source_version=fp AND di.is_current
    AND (e.processing_status IN ('Pending','Failed') OR EXISTS(SELECT 1 FROM public.notification_jobs j WHERE j.event_id=e.id AND j.job_status IN ('Pending','Processing','Failed'))))
  THEN CONTINUE; END IF;
  key:='work-attention:'||t.id||':'||fp||':'||reason||':'||(p_at AT TIME ZONE 'Asia/Dhaka')::date;
  INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
  VALUES('TodoWorkAttention','todo',t.id::text,w.owner_user_id,key,jsonb_build_object(
   'recipient_user_id',w.owner_user_id,'category','ToDo','severity','Warning','priority','High',
   'title','MG-HRM work needs attention','message','A time-sensitive work item needs review. Open MG-HRM for current details.',
   'action_label','Review work','action_route','todo','dedupe_key',key,'scheduled_for',p_at,
   'expires_at',((p_at AT TIME ZONE 'Asia/Dhaka')::date+pol.push_end) AT TIME ZONE 'Asia/Dhaka',
   'action_params',jsonb_build_object('todo_id',t.id,'governance_source_version',fp,'policy_reason',reason)),p_at)
  ON CONFLICT(event_key) DO NOTHING;
  IF FOUND THEN n:=n+1; END IF;
 END LOOP;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION notification_private.publish_work_attention(timestamptz) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
