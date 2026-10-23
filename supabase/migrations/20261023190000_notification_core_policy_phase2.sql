-- MG-HRM Notification Rulebook Phase 2: policy intelligence and evidence-aware limits.
-- NO live notification producer/dispatcher/cron is rewired, V2 remains disabled.
-- Approved: P3=1, P2=2 successful notification occurrences / 24h.
-- Not approved: urgent P1 exception, P0 emergency, holiday calendar,
-- user/category ceilings, fixed cooldown thresholds.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE TABLE IF NOT EXISTS notification_private.core_policy_limits(
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 policy_version text NOT NULL DEFAULT 'notification-core-v2-phase2-1',
 push_start time NOT NULL DEFAULT '09:00',
 push_end time NOT NULL DEFAULT '18:00',
 morning_digest_time time NOT NULL DEFAULT '09:05',
 afternoon_digest_time time NOT NULL DEFAULT '17:15',
 p3_item_cap_24h integer NOT NULL DEFAULT 1 CHECK(p3_item_cap_24h>=1),
 p2_item_cap_24h integer NOT NULL DEFAULT 2 CHECK(p2_item_cap_24h>=1),
 p1_item_cap_24h integer CHECK(p1_item_cap_24h IS NULL OR p1_item_cap_24h>=1),
 p1_push_enabled boolean NOT NULL DEFAULT false,
 p0_push_enabled boolean NOT NULL DEFAULT false,
 p1_warning_horizon interval,
 p2_cooldown interval,
 p3_cooldown interval,
 user_cap_24h integer CHECK(user_cap_24h IS NULL OR user_cap_24h>=1),
 category_cap_24h integer CHECK(category_cap_24h IS NULL OR category_cap_24h>=1),
 CHECK(push_start<push_end),
 CHECK(p1_warning_horizon IS NULL OR p1_warning_horizon>interval '0'),
 CHECK(p2_cooldown IS NULL OR p2_cooldown>interval '0'),
 CHECK(p3_cooldown IS NULL OR p3_cooldown>interval '0')
);
INSERT INTO notification_private.core_policy_limits(singleton) VALUES(true)
ON CONFLICT(singleton) DO NOTHING;
ALTER TABLE notification_private.core_policy_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.core_policy_limits FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE IF NOT EXISTS notification_private.core_verified_deadlines(
 entity_type text NOT NULL,
 entity_id text NOT NULL,
 recipient_user_id uuid NOT NULL,
 source_version text NOT NULL,
 actual_deadline_at timestamptz NOT NULL,
 verified_basis text NOT NULL CHECK(verified_basis IN ('manual_verified','authoritative_adapter')),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 5 AND 200),
 verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(entity_type,entity_id,recipient_user_id)
);
ALTER TABLE notification_private.core_verified_deadlines ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.core_verified_deadlines FROM PUBLIC,anon,authenticated,service_role;
-- Source evidence insertion is intentionally unavailable from the Data API.
-- Later verified HRM adapters must record facts through audited, narrowly authorized paths.
ALTER TABLE notification_private.core_decision_audit
 ADD COLUMN IF NOT EXISTS decision_details jsonb NOT NULL DEFAULT '{}'::jsonb;

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
 v_policy notification_private.core_policy_limits%rowtype;
 v_deadline notification_private.core_verified_deadlines%rowtype;
 v_real_deadline timestamptz;
 v_risk_reason text;
 v_warning text;
 v_local_next_open timestamptz;
 v_sent_count integer:=0;
 v_oldest_sent timestamptz;
 v_latest_sent timestamptz;
 v_category_count integer:=0;
 v_user_count integer:=0;
 v_category_oldest timestamptz;
 v_user_oldest timestamptz;
 v_cap integer;
 v_cooldown interval;
 v_work_ack timestamptz;
 v_work_snooze timestamptz;
BEGIN
 IF p_notification_id IS NULL OR p_at IS NULL THEN
   RAISE EXCEPTION 'Notification ID and evaluation instant are required' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_policy FROM notification_private.core_policy_limits WHERE singleton=true;
 IF NOT FOUND THEN
   RAISE EXCEPTION 'Notification core policy configuration missing' USING ERRCODE='P0001';
 END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('decision','NEEDS_VERIFICATION',
     'reason_code','notification_not_found','policy_version',v_policy.policy_version,
     'notification_id',p_notification_id,'evaluated_at',p_at,
     'enforcement','preview_only');
 END IF;
 source_typ:=lower(btrim(coalesce(n.entity_type,'')));
 source_key:=btrim(coalesce(n.entity_id,''));
 tier:='P3'; -- A generic notification label is not verified P1/P0 business evidence.
 local_time:=p_at AT TIME ZONE 'Asia/Dhaka';
 v_local_next_open:=((CASE WHEN local_time::time < v_policy.push_start
   THEN local_time::date ELSE local_time::date+1 END)+v_policy.push_start)
   AT TIME ZONE 'Asia/Dhaka';
 base:=jsonb_build_object(
   'notification_id',n.id,'recipient_user_id',n.recipient_user_id,
   'entity_type',source_typ,'entity_id',source_key,
   'priority_tier',tier,'policy_version',v_policy.policy_version,
   'evaluated_at',p_at,'enforcement','preview_only',
   'read_is_business_completion',false,'source_version',null,'next_eligible_at',null,
   'deadline_verified',false,'actual_deadline_at',null,'risk_reason',null,
   'push_count_per_item_24h',0,'push_cap_per_item_24h',null,
   'snooze_deadline_conflict',false,'calendar_verified',false
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
       SELECT * INTO v_deadline FROM notification_private.core_verified_deadlines d
        WHERE d.entity_type='todo' AND d.entity_id=source_key
          AND d.recipient_user_id=n.recipient_user_id
          AND d.source_version=version
          AND d.verified_at<=p_at
          AND d.verified_basis IN ('manual_verified','authoritative_adapter');
       IF FOUND THEN
         v_real_deadline:=v_deadline.actual_deadline_at;
         IF v_real_deadline<=p_at THEN
           tier:='P1';v_risk_reason:='verified_deadline_breached';
         ELSIF v_real_deadline<=v_local_next_open
           AND (local_time::time>=time '17:15' OR local_time::time<v_policy.push_start) THEN
           tier:='P1';v_risk_reason:='verified_before_next_office_open';
         ELSIF v_policy.p1_warning_horizon IS NOT NULL
           AND v_real_deadline<=p_at+v_policy.p1_warning_horizon THEN
           tier:='P1';v_risk_reason:='verified_imminent_deadline';
         END IF;
       END IF;
       base:=base||jsonb_build_object('source_version',version,'priority_tier',tier,
          'deadline_verified',v_real_deadline IS NOT NULL,
          'actual_deadline_at',v_real_deadline,'risk_reason',v_risk_reason);
       IF NOT notification_private.todo_actionable(t) THEN
         decision:='SUPPRESS_RESOLVED';reason:='source_work_resolved';
       ELSIF coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM n.recipient_user_id THEN
         decision:='NEEDS_VERIFICATION';reason:='source_recipient_changed';
       ELSE
         SELECT max(w.acknowledged_until), max(w.snoozed_until)
           INTO v_work_ack,v_work_snooze
         FROM public.swa_work_items w
         WHERE w.source_module='todo' AND w.source_record_id=source_key
           AND w.owner_user_id=n.recipient_user_id
           AND w.completed_at IS NULL AND w.cancelled_at IS NULL;
         ack_until:=v_work_ack;
         IF n.snoozed_until>p_at OR v_work_snooze>p_at THEN
           next_at:=greatest(coalesce(n.snoozed_until,'-infinity'::timestamptz),
             coalesce(v_work_snooze,'-infinity'::timestamptz));
           decision:='SUPPRESS_SNOOZED';reason:='explicit_snooze_lease';
           base:=base||jsonb_build_object('snooze_deadline_conflict',
             v_real_deadline IS NOT NULL AND next_at>v_real_deadline);
         ELSIF ack_until>p_at THEN
           decision:='SUPPRESS_ACKNOWLEDGED';reason:='explicit_work_acknowledgement';
           next_at:=ack_until;
           base:=base||jsonb_build_object('snooze_deadline_conflict',
             v_real_deadline IS NOT NULL AND ack_until>v_real_deadline);
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
             -- Real accepted network send occurrences: distinct notification IDs,
             -- not delivery rows, because multi-device fan-out is ONE user alert.
             SELECT count(*), min(first_send),max(first_send)
               INTO v_sent_count,v_oldest_sent,v_latest_sent
             FROM (
               SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
               FROM public.notifications h
               JOIN public.notification_deliveries d ON d.notification_id=h.id
               WHERE h.recipient_user_id=n.recipient_user_id
                 AND lower(coalesce(h.entity_type,''))=source_typ
                 AND h.entity_id=source_key
                 AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                 AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                 AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
               GROUP BY h.id
             ) accepted;
             v_cap:=CASE tier WHEN 'P2' THEN v_policy.p2_item_cap_24h
               WHEN 'P3' THEN v_policy.p3_item_cap_24h
               WHEN 'P1' THEN v_policy.p1_item_cap_24h ELSE NULL END;
             v_cooldown:=CASE tier WHEN 'P2' THEN v_policy.p2_cooldown
               WHEN 'P3' THEN v_policy.p3_cooldown ELSE NULL END;
             base:=base||jsonb_build_object('push_count_per_item_24h',v_sent_count,
               'push_cap_per_item_24h',v_cap,'last_actual_push_at',v_latest_sent);
             IF tier='P1' AND
                (NOT v_policy.p1_push_enabled OR v_cap IS NULL) THEN
               decision:='NEEDS_VERIFICATION';reason:='p1_delivery_policy_not_approved';
             ELSIF tier='P0' THEN
               decision:='NEEDS_VERIFICATION';reason:='p0_emergency_policy_not_approved';
             ELSIF v_cap IS NOT NULL AND v_sent_count>=v_cap THEN
               decision:='DEFER';reason:='rolling_per_item_push_cap';
               next_at:=v_oldest_sent+interval '24 hours';
             ELSIF v_cooldown IS NOT NULL AND v_latest_sent IS NOT NULL
               AND v_latest_sent+v_cooldown>p_at THEN
               decision:='DEFER';reason:='per_item_push_cooldown';
               next_at:=v_latest_sent+v_cooldown;
             ELSE
               -- Optional user/category global caps default NULL until approved.
               IF v_policy.user_cap_24h IS NOT NULL OR
                  v_policy.category_cap_24h IS NOT NULL THEN
                 SELECT count(*),min(first_send) INTO v_user_count,v_user_oldest
                 FROM (SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
                   FROM public.notifications h JOIN public.notification_deliveries d
                     ON d.notification_id=h.id
                   WHERE h.recipient_user_id=n.recipient_user_id
                     AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
                   GROUP BY h.id) accepted_user;
                 SELECT count(*),min(first_send) INTO v_category_count,v_category_oldest
                 FROM (SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
                   FROM public.notifications h JOIN public.notification_deliveries d
                     ON d.notification_id=h.id
                   WHERE h.recipient_user_id=n.recipient_user_id AND h.category=n.category
                     AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
                   GROUP BY h.id) accepted_category;
               END IF;
               base:=base||jsonb_build_object('push_count_per_user_24h',v_user_count,
                 'push_count_per_category_24h',v_category_count);
               IF v_policy.user_cap_24h IS NOT NULL
                  AND v_user_count>=v_policy.user_cap_24h THEN
                 decision:='DEFER';reason:='rolling_per_user_push_cap';
                 next_at:=v_user_oldest+interval '24 hours';
               ELSIF v_policy.category_cap_24h IS NOT NULL
                  AND v_category_count>=v_policy.category_cap_24h THEN
                 decision:='DEFER';reason:='rolling_per_category_push_cap';
                 next_at:=v_category_oldest+interval '24 hours';
               ELSIF local_time::time<v_policy.push_start
                  OR local_time::time>=v_policy.push_end THEN
                 decision:='DIGEST';reason:='deferred_for_office_hours';
                 next_at:=((CASE WHEN local_time::time>=v_policy.push_end
                   THEN local_time::date+1 ELSE local_time::date END)
                   +v_policy.morning_digest_time) AT TIME ZONE 'Asia/Dhaka';
               ELSE
                 decision:='SEND_NOW';reason:='actionable_verified_policy_candidate';
               END IF;
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
   decision,reason_code,priority_tier,next_eligible_at,evaluated_at,decision_details
 ) VALUES(
   k,p_notification_id,(j->>'recipient_user_id')::uuid,j->>'entity_type',j->>'entity_id',
   j->>'source_version',j->>'policy_version',p_phase,p_slot,
   j->>'decision',j->>'reason_code',j->>'priority_tier',
   (j->>'next_eligible_at')::timestamptz,(j->>'evaluated_at')::timestamptz,j
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

COMMENT ON FUNCTION notification_private.core_evaluate(uuid,timestamptz) IS
 'Phase 2 preview-only, verified-deadline-aware priority and actual sent-Push rolling limits. No live producer binding.';
COMMIT;
