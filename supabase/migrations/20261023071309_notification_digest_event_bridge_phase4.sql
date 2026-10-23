-- MG-HRM Governance V2 Phase 4 / Slice A:
-- Connect the existing server processor to the previously-built digest planner.
-- No new user interface, cron registration, Push provider or direct HR action.
-- Both the current governance flag and this separate bridge gate default OFF.
-- Production activation REQUIRES later last-mile dispatch + acceptance tests.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

CREATE TABLE IF NOT EXISTS notification_private.digest_bridge_control (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 enabled boolean NOT NULL DEFAULT false,
 policy_version text NOT NULL DEFAULT 'notification-bridge-v2-phase4-preview-1',
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO notification_private.digest_bridge_control(singleton,enabled)
VALUES(true,false) ON CONFLICT(singleton) DO NOTHING;
ALTER TABLE notification_private.digest_bridge_control ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.digest_bridge_control FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS notification_private.digest_publish_audit (
 batch_id bigint PRIMARY KEY REFERENCES notification_private.digest_batches(id),
 event_id bigint NOT NULL REFERENCES public.notification_events(id),
 recipient_user_id uuid NOT NULL,
 source_item_count integer NOT NULL CHECK(source_item_count>0),
 last_evaluated_at timestamptz NOT NULL,
 published_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE notification_private.digest_publish_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.digest_publish_audit FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION notification_private.digest_publish_slot(
 p_recipient uuid,p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE
 v_enabled boolean:=false;
 v_governance boolean:=false;
 v_due jsonb;
 v_batch jsonb;
 v_slot timestamptz;
 v_close timestamptz;
 v_batch_id bigint;
 v_item_count integer;
 v_key text;
 v_event_id bigint;
 v_created boolean:=false;
 v_now_local timestamp;
BEGIN
 SELECT enabled INTO v_enabled FROM notification_private.digest_bridge_control
 WHERE singleton;
 SELECT enabled INTO v_governance FROM notification_private.governance_control
 WHERE singleton;
 IF NOT coalesce(v_enabled,false) OR NOT coalesce(v_governance,false) THEN
   RETURN jsonb_build_object('status','Disabled','published',false,
     'reason_code','phase4_bridge_or_governance_disabled');
 END IF;
 IF p_recipient IS NULL OR p_at IS NULL THEN
   RAISE EXCEPTION 'Recipient and clock required' USING ERRCODE='22023';
 END IF;
 -- No unsafe background notification to another account.
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_recipient AND is_active)
 THEN RETURN jsonb_build_object('status','Suppressed','published',false,
   'reason_code','recipient_inactive'); END IF;
 v_now_local:=p_at AT TIME ZONE 'Asia/Dhaka';
 IF v_now_local::time<time '09:05' OR v_now_local::time>=time '18:00' THEN
   RETURN jsonb_build_object('status','Deferred','published',false,
     'reason_code','outside_authorized_digest_push_window');
 END IF;
 v_due:=notification_private.digest_latest_due(p_at);
 v_slot:=(v_due->>'slot_at')::timestamptz;
 v_close:=((v_due->>'local_day')::date + time '18:00')
   AT TIME ZONE 'Asia/Dhaka';
 IF p_at>v_close OR p_at-v_slot>interval '12 hours' THEN
   RETURN jsonb_build_object('status','Deferred','published',false,
     'reason_code','expired_digest_slot');
 END IF;
 -- Recompute authoritative To-Do source truth before publishing.
 v_batch:=public.notification_digest_reconcile(p_recipient,p_at);
 v_item_count:=(v_batch->>'item_count')::integer;
 IF v_item_count IS NULL OR v_item_count<=0 THEN
   RETURN v_batch||jsonb_build_object('status','Empty','published',false,
     'reason_code','no_outstanding_source_obligations');
 END IF;
 v_batch_id:=(v_batch->>'batch_id')::bigint;
 v_key:=concat('mghrm:work-digest:',p_recipient::text,':',
   v_due->>'local_day',':',v_due->>'digest_kind');
 -- One summary event, NEVER one event per To-Do/source row. Existing
 -- event job processor + notification inbox/Web Push sender own delivery.
 INSERT INTO public.notification_events(
   event_type,entity_type,entity_id,actor_user_id,
   event_key,event_payload,occurred_at
 ) VALUES(
   'OperatorWorkDigest','digest',v_batch_id::text,p_recipient,
   v_key,
   jsonb_build_object(
     'recipient_user_id',p_recipient,
     'category','System','severity','Info','priority','Normal',
     'title','MG-HRM work digest',
     'message','Your work summary is ready in MG-HRM. Open notifications to review pending work.',
     'action_label','Review notifications','action_route','notifications',
     'action_params',jsonb_build_object('digest_batch_id',v_batch_id::text,
       'digest_kind',v_due->>'digest_kind'),
     'scheduled_for',greatest(p_at,v_slot),
     'expires_at',v_close,
     'dedupe_key',v_key
   ),p_at
 ) ON CONFLICT(event_key) DO NOTHING RETURNING id INTO v_event_id;
 v_created:=FOUND;
 IF NOT v_created THEN
   SELECT id INTO v_event_id FROM public.notification_events
   WHERE event_key=v_key;
 END IF;
 IF v_event_id IS NULL THEN
   RAISE EXCEPTION 'Existing digest event missing for stable key'
   USING ERRCODE='P0001';
 END IF;
 INSERT INTO notification_private.digest_publish_audit(
   batch_id,event_id,recipient_user_id,source_item_count,last_evaluated_at
 ) VALUES(v_batch_id,v_event_id,p_recipient,v_item_count,p_at)
 ON CONFLICT(batch_id) DO UPDATE SET
   source_item_count=EXCLUDED.source_item_count,
   last_evaluated_at=EXCLUDED.last_evaluated_at;
 RETURN v_batch||jsonb_build_object('status','Published','event_id',v_event_id,
   'published',v_created,'reason_code',
   CASE WHEN v_created THEN 'single_digest_event_created'
     ELSE 'duplicate_slot_event_reused' END);
END $mg$;
REVOKE ALL ON FUNCTION notification_private.digest_publish_slot(uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_publish_slot(uuid,timestamptz)
 TO service_role;

-- Server scheduler entrypoint: checks only authorized operator IDs, no
-- cross-account fanout, and returns an explicit result for each operator.
CREATE OR REPLACE FUNCTION notification_private.digest_publish_for_operators(
 p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE v_id uuid; v_result jsonb; v_arr jsonb:='[]'::jsonb; v_count int:=0;
BEGIN
 IF p_at IS NULL THEN RAISE EXCEPTION 'Evaluation instant required'
 USING ERRCODE='22023'; END IF;
 IF NOT (SELECT coalesce(enabled,false) FROM notification_private.digest_bridge_control
   WHERE singleton) OR
   NOT (SELECT coalesce(enabled,false) FROM notification_private.governance_control
   WHERE singleton) THEN
   RETURN jsonb_build_object('status','Disabled','events_created',0);
 END IF;
 FOR v_id IN
   SELECT o.user_id FROM swa_private.operator_ids o
     JOIN public.profiles p ON p.id=o.user_id AND p.is_active
 LOOP
   v_result:=notification_private.digest_publish_slot(v_id,p_at);
   v_arr:=v_arr||jsonb_build_array(v_result);
   IF coalesce((v_result->>'published')::boolean,false) THEN v_count:=v_count+1; END IF;
 END LOOP;
 RETURN jsonb_build_object('status','Processed','events_created',v_count,
   'results',v_arr);
END $mg$;
REVOKE ALL ON FUNCTION notification_private.digest_publish_for_operators(timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_publish_for_operators(timestamptz)
 TO service_role;

COMMENT ON TABLE notification_private.digest_bridge_control IS
 'Phase4 closed-by-default safety switch; Governance V2 also required.';
COMMENT ON FUNCTION notification_private.digest_publish_slot(uuid,timestamptz) IS
 'No sender and no separate inbox. One idempotent digest event using existing notification pipeline.';
COMMIT;
