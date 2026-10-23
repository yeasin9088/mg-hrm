-- Synthetic end-to-end Phase5 operator policy switches through original digest bridge.
-- Requires synthetic Phase1->Phase2->Phase3->Phase4 (A/B/C) + Phase5 migrations.
BEGIN;
DO $test$
DECLARE op uuid:='11111111-1111-4111-8111-111111111111';
 morning timestamptz:='2026-10-23T03:05:00Z';
 wrap timestamptz:='2026-10-23T11:15:00Z';
 x jsonb; b bigint;
BEGIN
 UPDATE notification_private.governance_control SET enabled=true WHERE singleton;
 UPDATE notification_private.digest_bridge_control SET enabled=true WHERE singleton;
 IF NOT notification_private.digest_slot_setting_allowed('morning') OR
    NOT notification_private.digest_slot_setting_allowed('wrapup') OR
    notification_private.digest_slot_setting_allowed('invalid') THEN
   RAISE EXCEPTION 'Incorrect default digest switches'; END IF;
 x:=notification_private.digest_publish_slot(op,morning);
 IF x->>'published'<>'true' THEN RAISE EXCEPTION 'Enabled morning slot not published %',x; END IF;
 b:=(x->>'batch_id')::bigint;
 IF NOT notification_private.digest_dispatch_allowed(b::text,op,morning) THEN
   RAISE EXCEPTION 'Enabled valid source denied before Push'; END IF;
 UPDATE notification_private.core_policy_limits SET morning_digest_enabled=false WHERE singleton;
 x:=notification_private.digest_publish_slot(op,morning);
 IF x->>'reason_code'<>'operator_disabled_digest_slot' OR
   x->>'published'<>'false' OR
   (SELECT count(*) FROM public.notification_events)<>1 THEN
   RAISE EXCEPTION 'Turning off morning did not block new events %',x; END IF;
 IF notification_private.digest_dispatch_allowed(b::text,op,morning) THEN
   RAISE EXCEPTION 'Turning off morning did not block already queued Push'; END IF;
 UPDATE notification_private.core_policy_limits SET morning_digest_enabled=true,
   afternoon_digest_enabled=false WHERE singleton;
 x:=notification_private.digest_publish_slot(op,wrap);
 IF x->>'reason_code'<>'operator_disabled_digest_slot' OR
   (SELECT count(*) FROM public.notification_events)<>1 THEN
   RAISE EXCEPTION 'Afternoon switch not protecting publisher %',x; END IF;
 UPDATE notification_private.core_policy_limits SET afternoon_digest_enabled=true WHERE singleton;
 x:=notification_private.digest_publish_slot(op,wrap);
 IF x->>'published'<>'true' OR
   (SELECT count(*) FROM public.notification_events)<>2 THEN
   RAISE EXCEPTION 'Enabled wrap up did not create exactly one event %',x; END IF;
 UPDATE notification_private.governance_control SET enabled=false WHERE singleton;
 x:=notification_private.digest_publish_slot(op,wrap);
 IF x->>'status'<>'Disabled' OR x->>'published'<>'false' THEN
   RAISE EXCEPTION 'Global rollback did not stop user switches %',x; END IF;
 IF (SELECT count(*) FROM public.notification_deliveries)<>0 THEN
   RAISE EXCEPTION 'Settings toggle leaked a real/synthetic Push'; END IF;
END $test$;
ROLLBACK;
SELECT 'PASS Phase5 digest operator switches constrain source event creation and final Web Push on existing bridge' result;
