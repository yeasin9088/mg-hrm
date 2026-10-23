-- Staged Phase 5 contract: digest switches really participate in event
-- generation AND last-mile Web Push suppression; never cosmetic toggles.
-- Requires Phase3 then Phase4 A/B/C then Phase5 settings API.
-- NOT APPLIED until final supervised migration. Flags remain OFF.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION notification_private.digest_slot_setting_allowed(
 p_kind text
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
 SELECT EXISTS(
   SELECT 1 FROM notification_private.core_policy_limits p
   WHERE p.singleton AND
     ((p_kind='morning' AND p.morning_digest_enabled)
       OR (p_kind='wrapup' AND p.afternoon_digest_enabled))
 );
$mg$;
REVOKE ALL ON FUNCTION notification_private.digest_slot_setting_allowed(text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_slot_setting_allowed(text)
 TO service_role;

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
 IF NOT notification_private.digest_slot_setting_allowed(v_due->>'digest_kind') THEN
   RETURN jsonb_build_object('status','Suppressed','published',false,
     'reason_code','operator_disabled_digest_slot');
 END IF;
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
CREATE OR REPLACE FUNCTION notification_private.digest_dispatch_allowed(
 p_batch_key text,p_recipient uuid,p_at timestamptz
) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE b notification_private.digest_batches%rowtype;
 v_plan jsonb; v_local timestamp;
BEGIN
 IF p_batch_key IS NULL OR p_batch_key !~ '^[0-9]{1,18}$'
   OR p_recipient IS NULL OR p_at IS NULL THEN RETURN false; END IF;
 SELECT * INTO b FROM notification_private.digest_batches d
 WHERE d.id::text=p_batch_key AND d.recipient_user_id=p_recipient;
 IF NOT FOUND THEN RETURN false; END IF;
 IF NOT notification_private.digest_slot_setting_allowed(b.digest_kind) THEN
   RETURN false;
 END IF;
 v_local:=p_at AT TIME ZONE 'Asia/Dhaka';
 -- Do not wake devices outside an approved routine Push window.
 IF v_local::time<time '09:05' OR v_local::time>=time '18:00'
    OR p_at<b.slot_at OR p_at-b.slot_at>interval '12 hours'
 THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=p_recipient AND p.is_active)
 THEN RETURN false; END IF;
 -- Pending source truth, recipient ownership, terminal state and verified
 -- business deadline are recomputed from real To-Dos, never stale JSON.
 v_plan:=notification_private.digest_plan(p_recipient,b.local_day,b.digest_kind,p_at);
 RETURN coalesce((v_plan->>'item_count')::integer,0)>0;
EXCEPTION WHEN OTHERS THEN
 RETURN false; -- last-mile source validator fails closed
END $mg$;
REVOKE ALL ON FUNCTION notification_private.digest_dispatch_allowed(text,uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_dispatch_allowed(text,uuid,timestamptz)
 TO service_role;
COMMIT;
