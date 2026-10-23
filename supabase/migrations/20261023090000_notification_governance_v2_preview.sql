-- MG-HRM: Notification Governance V2 policy foundation (no new work UI).
-- Rulebook v1.1: BR-003, 031, 032, 100, 115-124, 125-128, 132, 366-371.
-- ALL V2 decisions remain OFF until office-push/digest policies and integration gates are approved.
-- Additive migration: no existing notification, To-Do or delivery rows are changed.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';

CREATE TABLE IF NOT EXISTS notification_private.governance_control (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 enabled boolean NOT NULL DEFAULT false,
 policy_version text NOT NULL DEFAULT 'notification-governance-v2-preview-1',
 office_start time NOT NULL DEFAULT '09:00',
 office_end time NOT NULL DEFAULT '18:00',
 routine_cooldown interval NOT NULL DEFAULT interval '24 hours',
 important_cooldown interval NOT NULL DEFAULT interval '4 hours',
 routine_max_per_24h integer NOT NULL DEFAULT 1 CHECK(routine_max_per_24h BETWEEN 0 AND 4),
 important_max_per_24h integer NOT NULL DEFAULT 2 CHECK(important_max_per_24h BETWEEN 0 AND 6),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT governance_hours_valid CHECK(office_start < office_end)
);
INSERT INTO notification_private.governance_control(singleton,enabled)
VALUES(true,false) ON CONFLICT(singleton) DO NOTHING;
REVOKE ALL ON notification_private.governance_control FROM PUBLIC,anon,authenticated;

-- Kept verbatim in a private compatibility function, so disabled mode is EXACTLY the V1 behavior.
CREATE OR REPLACE FUNCTION notification_private.todo_followup_v1_allowed(
 p_todo public.todos,p_recipient uuid,p_now timestamptz
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $mg$
DECLARE last_ack timestamptz; latest_status text; latest_read timestamptz;
 step_minutes integer;
BEGIN
 IF p_recipient IS NULL OR p_todo.id IS NULL THEN RETURN false; END IF;
 -- Historic duplicates from the former scheduler must not block the operator
 -- forever after they acknowledge the NEWEST occurrence of this topic.
 SELECT n.status,n.read_at,coalesce(n.read_at,n.dismissed_at)
 INTO latest_status,latest_read,last_ack
 FROM public.notifications n JOIN public.notification_events e ON e.id=n.event_id
 WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo'
   AND n.entity_id=p_todo.id::text AND e.event_type='TodoReminderDue'
 ORDER BY n.created_at DESC,n.id DESC LIMIT 1;
 IF latest_status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
    AND (latest_read IS NULL OR latest_status='Snoozed')
 THEN RETURN false; END IF;
 -- Preserve a deliberate still-active snooze even if newer historical copies exist.
 IF EXISTS (
   SELECT 1 FROM public.notifications n JOIN public.notification_events e ON e.id=n.event_id
   WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo'
     AND n.entity_id=p_todo.id::text AND e.event_type='TodoReminderDue'
     AND n.status='Snoozed' AND n.snoozed_until>p_now
 ) THEN RETURN false; END IF;
 step_minutes:=CASE coalesce(p_todo.reminder_type,'1h')
   WHEN 'today' THEN 1440
   ELSE greatest(5,least(1440,coalesce(nullif(p_todo.reminder_interval,0),
     CASE p_todo.reminder_type WHEN '30m' THEN 30 WHEN '2h' THEN 120 ELSE 60 END)))
 END;
 RETURN last_ack IS NULL OR p_now>=last_ack+make_interval(mins=>step_minutes);
END $mg$;

REVOKE ALL ON FUNCTION notification_private.todo_followup_v1_allowed(public.todos,uuid,timestamptz)
FROM PUBLIC,anon,authenticated;

-- No reads, opens, mark-all-read, or phone tray interactions participate in this policy.
-- A To-Do reminder date is NOT treated as an official business deadline.
-- Only a separately recorded work-item deadline/promised time can affect risk.
CREATE OR REPLACE FUNCTION notification_private.governance_evaluate_todo(
 p_todo public.todos,p_recipient uuid,p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $ng$
DECLARE
 c notification_private.governance_control%rowtype;
 local_now timestamp;
 office_next timestamp;
 priority_class text;
 max_alerts integer;
 cooldown interval;
 last_at timestamptz;
 sent_count integer;
 until_at timestamptz;
 business_due timestamptz;
 v_reason text;
 v_pref jsonb;
BEGIN
 SELECT * INTO c FROM notification_private.governance_control WHERE singleton;
 IF c.singleton IS NULL THEN
   RETURN jsonb_build_object('emit',false,'reason','governance_config_missing');
 END IF;
 IF p_recipient IS NULL OR p_todo.id IS NULL OR NOT p_todo.reminder_enabled
    OR NOT notification_private.todo_actionable(p_todo) THEN
   RETURN jsonb_build_object('emit',false,'reason','source_not_actionable');
 END IF;
 IF coalesce(p_todo.assigned_to_user_id,p_todo.owner_user_id) IS DISTINCT FROM p_recipient THEN
   RETURN jsonb_build_object('emit',false,'reason','recipient_mismatch');
 END IF;
 v_pref:=public.notification_effective_preference(p_recipient,'ToDo');
 IF NOT coalesce((v_pref->>'notification_enabled')::boolean,true) THEN
   RETURN jsonb_build_object('emit',false,'reason','notifications_disabled_by_preference');
 END IF;

 SELECT min(z.deadline_at) INTO business_due
 FROM (
   SELECT CASE WHEN deadline_at IS NULL THEN NULL ELSE deadline_at END AS deadline_at
     FROM public.swa_work_items WHERE source_module='todo' AND source_record_id=p_todo.id::text
       AND owner_user_id=p_recipient AND completed_at IS NULL AND cancelled_at IS NULL
   UNION ALL
   SELECT promised_at FROM public.swa_work_items
     WHERE source_module='todo' AND source_record_id=p_todo.id::text
       AND owner_user_id=p_recipient AND completed_at IS NULL AND cancelled_at IS NULL
 ) z WHERE z.deadline_at IS NOT NULL;
 priority_class:=CASE WHEN coalesce(p_todo.is_important,false)
    OR lower(coalesce(p_todo.priority,'')) IN ('important','high','urgent','critical')
    THEN 'important' ELSE 'routine' END;
 cooldown:=CASE WHEN priority_class='important' THEN c.important_cooldown ELSE c.routine_cooldown END;
 max_alerts:=CASE WHEN priority_class='important' THEN c.important_max_per_24h ELSE c.routine_max_per_24h END;

 -- Snoozed and acknowledged are EXPLICIT actions; Read/Dismiss are not.
 SELECT max(n.snoozed_until) INTO until_at FROM public.notifications n
 JOIN public.notification_events e ON e.id=n.event_id
 WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo'
   AND n.entity_id=p_todo.id::text AND e.event_type='TodoReminderDue'
   AND n.status='Snoozed' AND n.snoozed_until>p_at;
 IF until_at IS NOT NULL THEN
   RETURN jsonb_build_object('emit',false,'reason','user_snoozed','next_eligible_at',until_at,
       'priority_class',priority_class,'business_due_at',business_due);
 END IF;
 SELECT max(acknowledged_until) INTO until_at FROM public.swa_work_items
 WHERE source_module='todo' AND source_record_id=p_todo.id::text
   AND owner_user_id=p_recipient AND completed_at IS NULL AND cancelled_at IS NULL
   AND acknowledged_until>p_at;
 IF until_at IS NOT NULL THEN
   RETURN jsonb_build_object('emit',false,'reason','explicit_ack_lease','next_eligible_at',until_at,
       'priority_class',priority_class,'business_due_at',business_due);
 END IF;

 local_now:=p_at AT TIME ZONE 'Asia/Dhaka';
 IF local_now::time < c.office_start OR local_now::time >= c.office_end THEN
   office_next:=(CASE WHEN local_now::time >= c.office_end THEN local_now::date+1 ELSE local_now::date END)::timestamp+c.office_start;
   RETURN jsonb_build_object('emit',false,'reason','deferred_for_office_hours',
     'next_eligible_at',office_next AT TIME ZONE 'Asia/Dhaka',
     'priority_class',priority_class,'business_due_at',business_due);
 END IF;

 SELECT max(e.created_at),count(*) FILTER (WHERE e.created_at > p_at-interval '24 hours')
 INTO last_at,sent_count
 FROM public.notification_events e
 WHERE e.event_type='TodoReminderDue' AND e.entity_type='todo'
    AND e.entity_id=p_todo.id::text AND e.actor_user_id=p_recipient
    AND e.created_at <= p_at;
 IF coalesce(sent_count,0)>=max_alerts THEN
   RETURN jsonb_build_object('emit',false,'reason','rolling_24h_cap',
      'next_eligible_at',(SELECT min(e.created_at)+interval '24 hours' FROM public.notification_events e
       WHERE e.event_type='TodoReminderDue' AND e.entity_type='todo'
       AND e.entity_id=p_todo.id::text AND e.actor_user_id=p_recipient
       AND e.created_at>p_at-interval '24 hours'),
      'priority_class',priority_class,'business_due_at',business_due);
 END IF;
 IF last_at IS NOT NULL AND last_at+cooldown>p_at THEN
   RETURN jsonb_build_object('emit',false,'reason','meaningful_cooldown',
     'next_eligible_at',last_at+cooldown,'priority_class',priority_class,'business_due_at',business_due);
 END IF;

 v_reason:=CASE WHEN business_due IS NOT NULL AND business_due<=p_at THEN 'real_deadline_overdue'
   WHEN business_due IS NOT NULL AND business_due<=p_at+interval '24 hours' THEN 'real_deadline_near'
   WHEN priority_class='important' THEN 'important_review' ELSE 'routine_review' END;
 RETURN jsonb_build_object('emit',true,'reason',v_reason,'priority_class',priority_class,
   'business_due_at',business_due,'policy_version',c.policy_version,
   'evaluated_at',p_at,'read_state_independent',true);
END $ng$;
REVOKE ALL ON FUNCTION notification_private.governance_evaluate_todo(public.todos,uuid,timestamptz)
FROM PUBLIC,anon,authenticated;

-- Existing producer AND foreground-claim path continue calling this same gate.
-- Activation switch is OFF by default; therefore not even the V1 policy is changed in live operation.
CREATE OR REPLACE FUNCTION notification_private.todo_followup_allowed(
 p_todo public.todos,p_recipient uuid,p_now timestamptz
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $ng$
BEGIN
 IF EXISTS(SELECT 1 FROM notification_private.governance_control WHERE singleton AND enabled) THEN
   RETURN coalesce((notification_private.governance_evaluate_todo(p_todo,p_recipient,p_now)->>'emit')::boolean,false);
 END IF;
 RETURN notification_private.todo_followup_v1_allowed(p_todo,p_recipient,p_now);
END $ng$;
REVOKE ALL ON FUNCTION notification_private.todo_followup_allowed(public.todos,uuid,timestamptz)
FROM PUBLIC,anon,authenticated;

-- Read-only pilot diagnostics inside existing authenticated Notification infrastructure.
-- Never leaks To-Do contents, employee details, salary data or arbitrary user records.
CREATE OR REPLACE FUNCTION public.notification_governance_preview(p_todo_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $ng$
DECLARE t public.todos; recipient uuid; assessment jsonb; enabled boolean;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 recipient:=auth.uid();
 SELECT * INTO t FROM public.todos WHERE id=p_todo_id
   AND coalesce(assigned_to_user_id,owner_user_id)=recipient;
 IF NOT FOUND THEN RAISE EXCEPTION 'To-Do not found or not owned' USING ERRCODE='42501'; END IF;
 assessment:=notification_private.governance_evaluate_todo(t,recipient,clock_timestamp());
 SELECT g.enabled INTO enabled FROM notification_private.governance_control g WHERE singleton;
 RETURN jsonb_build_object('todo_id',t.id,'governance_enabled',coalesce(enabled,false),
   'decision',assessment,'existing_v1_eligible',
   notification_private.todo_followup_v1_allowed(t,recipient,clock_timestamp()));
END $ng$;
REVOKE ALL ON FUNCTION public.notification_governance_preview(bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_governance_preview(bigint) TO authenticated;
COMMENT ON FUNCTION public.notification_governance_preview(bigint) IS
 'Read-only rulebook policy decision; enabled=false means production reminders remain V1.';

COMMIT;
