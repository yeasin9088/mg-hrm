-- Integration: saved Settings Center clocks affect actual publisher/last-mile guard.
-- Run after isolated Phase1->2->3->4->5 migrations + Phase6 configurable window.
BEGIN;
DO $test$
DECLARE
 op uuid:='11111111-1111-4111-8111-111111111111';
 morning timestamptz:='2026-10-23T03:10:00Z'; -- 09:10 Dhaka
 evening timestamptz:='2026-10-23T11:20:00Z'; -- 17:20 Dhaka
 x jsonb; morning_batch text; evening_batch text;
BEGIN
 UPDATE notification_private.core_policy_limits SET
   push_start='09:00',push_end='17:30',
   morning_digest_time='09:10',afternoon_digest_time='17:20'
 WHERE singleton;
 UPDATE notification_private.governance_control SET enabled=true WHERE singleton;
 UPDATE notification_private.digest_bridge_control SET enabled=true WHERE singleton;
 x:=notification_private.digest_publish_slot(op,morning);
 IF x->>'published'<>'true' OR x->>'digest_kind'<>'morning' THEN
   RAISE EXCEPTION 'Configurable 09:10 morning delivery not obeyed %',x; END IF;
 morning_batch:=x->>'batch_id';
 IF NOT notification_private.digest_dispatch_allowed(morning_batch,op,morning) THEN
   RAISE EXCEPTION 'Valid morning source incorrectly blocked'; END IF;
 x:=notification_private.digest_publish_slot(op,evening);
 IF x->>'published'<>'true' OR x->>'digest_kind'<>'wrapup' THEN
   RAISE EXCEPTION 'Configurable 17:20 wrap-up delivery missing %',x; END IF;
 evening_batch:=x->>'batch_id';
 IF (SELECT event_payload->>'expires_at' FROM public.notification_events
   WHERE entity_id=evening_batch)<>'2026-10-23T11:30:00+00:00' THEN
   RAISE EXCEPTION 'Staged publisher ignored saved 17:30 push cutoff'; END IF;
 IF NOT notification_private.digest_dispatch_allowed(
    evening_batch,op,'2026-10-23T11:29:00Z') THEN
    RAISE EXCEPTION 'Valid before cutoff denied'; END IF;
 IF notification_private.digest_dispatch_allowed(
    evening_batch,op,'2026-10-23T11:30:00Z') THEN
    RAISE EXCEPTION 'Push allowed after configured 17:30 close'; END IF;
 x:=notification_private.digest_publish_slot(op,'2026-10-23T11:35:00Z');
 IF x->>'reason_code'<>'outside_authorized_digest_push_window' OR
    x->>'published'<>'false' OR
    (SELECT count(*) FROM public.notification_events)<>2 THEN
   RAISE EXCEPTION 'Late cron produced additional Push after custom cutoff %',x; END IF;
 -- A disabled digest switch still defeats any time-based acceptance.
 UPDATE notification_private.core_policy_limits SET afternoon_digest_enabled=false
 WHERE singleton;
 IF notification_private.digest_dispatch_allowed(
    evening_batch,op,'2026-10-23T11:25:00Z') THEN
    RAISE EXCEPTION 'Disabled wrap-up switch was ignored'; END IF;
END $test$;
ROLLBACK;
SELECT 'PASS configurable Phase6 Asia/Dhaka slot and delivery window enforcement without duplicate events' result;
