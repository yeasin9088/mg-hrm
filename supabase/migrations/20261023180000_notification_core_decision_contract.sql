-- MG-HRM Rulebook v1.1: Phase 1 canonical notification decision contract.
-- BR-003/031/100/102/124/291/292/297/300 (partial; no claims of full AT coverage).
-- This is a dormant decision/evidence service; NO existing producer/cron/push path calls it.
-- Does not change governance_control.enabled, notifications, subscriptions or source records.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

CREATE TABLE IF NOT EXISTS notification_private.core_decision_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 decision_key text NOT NULL UNIQUE CHECK (length(decision_key)=32),
 notification_id uuid NOT NULL,
 recipient_user_id uuid NOT NULL,
 entity_type text NOT NULL,
 entity_id text NOT NULL,
 source_version text,
 policy_version text NOT NULL,
 evaluation_phase text NOT NULL CHECK(evaluation_phase IN ('candidate','queue','dispatch','reconcile')),
 scheduled_slot timestamptz,
 decision text NOT NULL CHECK(decision IN (
   'SEND_NOW','DEFER','DIGEST','IN_APP_ONLY','SUPPRESS_DUPLICATE',
   'SUPPRESS_RESOLVED','SUPPRESS_ACKNOWLEDGED','SUPPRESS_SNOOZED',
   'BLOCKED_BY_PREFERENCE','NEEDS_VERIFICATION','EXPIRED')),
 reason_code text NOT NULL,
 priority_tier text NOT NULL CHECK(priority_tier IN ('P0','P1','P2','P3')),
 next_eligible_at timestamptz,
 evaluated_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS core_decision_audit_notification_idx
 ON notification_private.core_decision_audit(notification_id, created_at DESC);
CREATE INDEX IF NOT EXISTS core_decision_audit_recipient_idx
 ON notification_private.core_decision_audit(recipient_user_id, created_at DESC);
ALTER TABLE notification_private.core_decision_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.core_decision_audit FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE notification_private.core_decision_audit_id_seq FROM PUBLIC,anon,authenticated,service_role;

-- Returns one of the documented decisions; no events/jobs/deliveries are created.
-- Fail CLOSED for unsupported cross-module semantics, until Phase 4 source adapters
-- can prove authoritative ownership, source material version, and real deadline.
CREATE OR REPLACE FUNCTION notification_private.core_evaluate(
 p_notification_id uuid,p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE
 n public.notifications%rowtype;
 t public.todos%rowtype;
 pref jsonb;
 state jsonb;
 base jsonb;
 decision text:='NEEDS_VERIFICATION';
 reason text:='not_evaluated';
 version text;
 tier text:='P3';
 next_at timestamptz;
 ack_until timestamptz;
 source_typ text;
 source_key text;
 local_time timestamp;
 muted boolean;
 enabled boolean;
BEGIN
 IF p_notification_id IS NULL OR p_at IS NULL THEN
   RAISE EXCEPTION 'Notification ID and evaluation instant are required' USING ERRCODE='22023';
 END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('decision','NEEDS_VERIFICATION',
     'reason_code','notification_not_found','policy_version','notification-core-v2-phase1-1',
     'notification_id',p_notification_id,'evaluated_at',p_at,
     'enforcement','preview_only');
 END IF;
 source_typ:=lower(btrim(coalesce(n.entity_type,'')));
 source_key:=btrim(coalesce(n.entity_id,''));
 tier:=CASE WHEN n.priority IN ('High','Urgent') THEN 'P2' ELSE 'P3' END;
 base:=jsonb_build_object(
   'notification_id',n.id,'recipient_user_id',n.recipient_user_id,
   'entity_type',source_typ,'entity_id',source_key,
   'priority_tier',tier,'policy_version','notification-core-v2-phase1-1',
   'evaluated_at',p_at,'enforcement','preview_only',
   'read_is_business_completion',false,'source_version',null,'next_eligible_at',null
 );
 IF n.recipient_user_id IS NULL OR source_typ='' OR source_key='' THEN
   decision:='NEEDS_VERIFICATION';reason:='missing_source_or_recipient';
 ELSIF n.status IN ('Completed','Cancelled','Expired') THEN
   decision:='SUPPRESS_RESOLVED';reason:='notification_terminal';
 ELSIF n.expires_at IS NOT NULL AND n.expires_at<=p_at THEN
   decision:='EXPIRED';reason:='notification_ttl_expired';
 ELSIF source_typ='todo' THEN
   IF source_key !~ '^[0-9]{1,18}$' THEN
     decision:='NEEDS_VERIFICATION';reason:='source_identifier_invalid';
   ELSE
     SELECT * INTO t FROM public.todos WHERE id::text=source_key;
     IF NOT FOUND THEN
       decision:='NEEDS_VERIFICATION';reason:='source_record_missing';
     ELSE
       version:=md5(concat_ws('|',coalesce(t.updated_at::text,'unset'),
         coalesce(t.status,''),coalesce(t.manager_status,''),
         coalesce(t.assigned_to_user_id,t.owner_user_id)::text,
         coalesce(t.solved_at::text,''),coalesce(t.deleted_at::text,'')));
       tier:=CASE WHEN coalesce(t.is_important,false) OR
        lower(coalesce(t.priority,'')) IN ('high','important','urgent','critical')
        THEN 'P2' ELSE 'P3' END;
       base:=base||jsonb_build_object('source_version',version,'priority_tier',tier);
       IF NOT notification_private.todo_actionable(t) THEN
         decision:='SUPPRESS_RESOLVED';reason:='source_work_resolved';
       ELSIF coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM n.recipient_user_id THEN
         decision:='NEEDS_VERIFICATION';reason:='source_recipient_changed';
       ELSIF n.snoozed_until IS NOT NULL AND n.snoozed_until>p_at THEN
         decision:='SUPPRESS_SNOOZED';reason:='notification_snoozed';next_at:=n.snoozed_until;
       ELSE
         SELECT max(greatest(w.acknowledged_until,w.snoozed_until)) INTO ack_until
         FROM public.swa_work_items w
         WHERE w.source_module='todo' AND w.source_record_id=source_key
           AND w.owner_user_id=n.recipient_user_id AND w.completed_at IS NULL
           AND w.cancelled_at IS NULL
           AND ((w.acknowledged_until>p_at) OR (w.snoozed_until>p_at));
         IF ack_until>p_at THEN
           decision:='SUPPRESS_ACKNOWLEDGED';reason:='explicit_work_lease';next_at:=ack_until;
         ELSE
           BEGIN
             pref:=public.notification_effective_preference(n.recipient_user_id,n.category);
           EXCEPTION WHEN OTHERS THEN
             RETURN base||jsonb_build_object('decision','NEEDS_VERIFICATION',
               'reason_code','preference_evaluation_failed','next_eligible_at',null);
           END;
           enabled:=coalesce((pref->>'notification_enabled')::boolean,true);
           muted:=NOT coalesce((pref->>'system_push_enabled')::boolean,true);
           IF NOT enabled THEN
             decision:='BLOCKED_BY_PREFERENCE';reason:='notification_master_disabled';
           ELSIF n.first_delivered_at IS NOT NULL OR n.status='Dismissed' THEN
             decision:='SUPPRESS_DUPLICATE';reason:='notification_occurrence_already_surfaced';
           ELSIF n.scheduled_for IS NOT NULL AND n.scheduled_for>p_at THEN
             decision:='DEFER';reason:='notification_not_due';next_at:=n.scheduled_for;
           ELSIF muted THEN
             decision:='IN_APP_ONLY';reason:='device_push_disabled';
           ELSE
             -- Approved *routine Push pilot* window is independent of office execution.
             local_time:=p_at AT TIME ZONE 'Asia/Dhaka';
             IF local_time::time<time '09:00' OR local_time::time>=time '18:00' THEN
               decision:='DIGEST';reason:='routine_push_outside_window';
               next_at:=((CASE WHEN local_time::time>=time '18:00'
                 THEN local_time::date+1 ELSE local_time::date END)
                 +time '09:05') AT TIME ZONE 'Asia/Dhaka';
             ELSE
               decision:='SEND_NOW';reason:='actionable_todo_candidate';
             END IF;
           END IF;
         END IF;
       END IF;
     END IF;
   END IF;
 ELSE
   -- Existing general source_state only checks terminal state, not ownership/version.
   -- Do not auto-authorize a Web Push based on unsupported/partial adapters.
   BEGIN
     state:=public.notification_source_state(source_typ,source_key);
     IF coalesce((state->>'supported')::boolean,false) AND
        coalesce((state->>'resolved')::boolean,false) THEN
       decision:='SUPPRESS_RESOLVED';reason:='source_work_resolved';
     ELSE
       decision:='NEEDS_VERIFICATION';
       reason:=CASE WHEN coalesce((state->>'supported')::boolean,false)
         THEN 'source_recipient_and_version_unverified'
         ELSE 'unsupported_source_adapter' END;
     END IF;
   EXCEPTION WHEN OTHERS THEN
     decision:='NEEDS_VERIFICATION';reason:='source_check_failed';
   END;
 END IF;
 RETURN base||jsonb_build_object('decision',decision,'reason_code',reason,
   'reason_codes',jsonb_build_array(reason),'next_eligible_at',next_at);
END $mg$;
REVOKE ALL ON FUNCTION notification_private.core_evaluate(uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.core_evaluate(uuid,timestamptz)
 TO service_role;

-- Operator-readable preview within EXISTING Notification Center architecture.
-- No employee names, salaries, note text, URLs or push encryption keys returned.
CREATE OR REPLACE FUNCTION public.notification_core_preview(p_notification_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE n public.notifications%rowtype;
BEGIN
 IF NOT public.swa_is_operator() THEN
   RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id
  AND recipient_user_id=auth.uid();
 IF NOT FOUND THEN
   RAISE EXCEPTION 'Notification not found or inaccessible' USING ERRCODE='42501';
 END IF;
 RETURN notification_private.core_evaluate(n.id,clock_timestamp());
END $mg$;
REVOKE ALL ON FUNCTION public.notification_core_preview(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_core_preview(uuid) TO authenticated;

-- Service-only, database-derived, immutable/idempotent audit. Clients cannot
-- supply fabricated decision/reason values. No notification or HRM writes occur.
CREATE OR REPLACE FUNCTION public.notification_core_record_decision(
 p_notification_id uuid,p_phase text,p_slot timestamptz DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE j jsonb; k text; added boolean:=false; v_id bigint;
BEGIN
 IF p_phase NOT IN ('candidate','queue','dispatch','reconcile') OR p_phase IS NULL THEN
   RAISE EXCEPTION 'Invalid evaluation phase' USING ERRCODE='22023';
 END IF;
 j:=notification_private.core_evaluate(p_notification_id,clock_timestamp());
 IF j->>'recipient_user_id' IS NULL OR j->>'entity_type' IS NULL THEN
   RAISE EXCEPTION 'Cannot audit unbound notification' USING ERRCODE='22023';
 END IF;
 k:=md5(concat_ws('|',p_notification_id::text,p_phase,
   coalesce(to_char(p_slot AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US'),'unslotted'),
   j->>'policy_version',coalesce(j->>'source_version','unverified'),
   j->>'priority_tier',j->>'decision',j->>'reason_code'));
 INSERT INTO notification_private.core_decision_audit(
   decision_key,notification_id,recipient_user_id,entity_type,entity_id,
   source_version,policy_version,evaluation_phase,scheduled_slot,
   decision,reason_code,priority_tier,next_eligible_at,evaluated_at
 ) VALUES(
   k,p_notification_id,(j->>'recipient_user_id')::uuid,j->>'entity_type',j->>'entity_id',
   j->>'source_version',j->>'policy_version',p_phase,p_slot,
   j->>'decision',j->>'reason_code',j->>'priority_tier',
   (j->>'next_eligible_at')::timestamptz,(j->>'evaluated_at')::timestamptz
 ) ON CONFLICT(decision_key) DO NOTHING RETURNING id INTO v_id;
 added:=FOUND;
 IF NOT added THEN
   SELECT id INTO v_id FROM notification_private.core_decision_audit
   WHERE decision_key=k;
 END IF;
 RETURN jsonb_build_object('audit_id',v_id,'inserted',added,'decision_key',k,
   'decision',j->>'decision','reason_code',j->>'reason_code',
   'policy_version',j->>'policy_version');
END $mg$;
REVOKE ALL ON FUNCTION public.notification_core_record_decision(uuid,text,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_core_record_decision(uuid,text,timestamptz)
 TO service_role;

COMMENT ON TABLE notification_private.core_decision_audit IS
 'Phase 1 canonical decision evidence only. Not proof of Web Push dispatch or business completion.';
COMMENT ON FUNCTION notification_private.core_evaluate(uuid,timestamptz) IS
 'Read-only source-aware decision preview. No producer/dispatcher integration; fail-closed unsupported modules.';
COMMIT;
