-- Repeatable isolated assertions; changes rollback automatically.
BEGIN;
DO $test$
DECLARE
 v jsonb; n uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 owner uuid:='11111111-1111-4111-8111-111111111111';
 noon timestamptz:='2026-10-23T06:00:00Z'; -- 12:00 Asia/Dhaka
 night timestamptz:='2026-10-23T15:00:00Z'; -- 21:00 Asia/Dhaka
 ack timestamptz:='2026-10-23T08:00:00Z';
 audit_one jsonb; audit_two jsonb;
BEGIN
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SEND_NOW' OR v->>'reason_code'<>'actionable_todo_candidate'
    OR v->>'priority_tier'<>'P3' THEN
   RAISE EXCEPTION 'Core basic decision incorrect %',v; END IF;
 IF v::text LIKE '%SECRET SALARY%' OR v->>'enforcement'<>'preview_only' THEN
   RAISE EXCEPTION 'Preview must not reveal source text or imply activation'; END IF;
 v:=notification_private.core_evaluate(n,night);
 IF v->>'decision'<>'DIGEST' OR v->>'reason_code'<>'routine_push_outside_window'
    OR (v->>'next_eligible_at')::timestamptz<>'2026-10-24T03:05:00Z' THEN
   RAISE EXCEPTION 'Dhaka morning digest candidate wrong: %',v; END IF;
 UPDATE public.notifications SET read_at='2026-10-23T05:00:00Z' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SEND_NOW' THEN RAISE EXCEPTION 'Reading notification changed business eligibility %',v; END IF;
 UPDATE public.notifications SET scheduled_for='2026-10-23T07:00:00Z' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'DEFER' THEN RAISE EXCEPTION 'Future schedule not deferred %',v; END IF;
 UPDATE public.notifications SET scheduled_for=NULL,snoozed_until=ack WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SUPPRESS_SNOOZED' THEN RAISE EXCEPTION 'Snooze missing %',v; END IF;
 UPDATE public.notifications SET snoozed_until=NULL WHERE id=n;
 INSERT INTO public.swa_work_items(owner_user_id,source_module,source_record_id,acknowledged_until)
 VALUES(owner,'todo','101',ack);
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SUPPRESS_ACKNOWLEDGED' THEN RAISE EXCEPTION 'Explicit ACK lease missing %',v; END IF;
 DELETE FROM public.swa_work_items;
 INSERT INTO public.notification_preferences VALUES(owner,'ToDo',true,false);
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'IN_APP_ONLY' THEN RAISE EXCEPTION 'Push opt out incorrectly blocked inbox %',v; END IF;
 UPDATE public.notification_preferences SET notification_enabled=false;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'BLOCKED_BY_PREFERENCE' THEN RAISE EXCEPTION 'Master opt out missing %',v; END IF;
 DELETE FROM public.notification_preferences;
 UPDATE public.todos SET assigned_to_user_id='22222222-2222-4222-8222-222222222222'
 WHERE id=101;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'NEEDS_VERIFICATION' OR v->>'reason_code'<>'source_recipient_changed' THEN
  RAISE EXCEPTION 'Recipient change not blocked %',v; END IF;
 UPDATE public.todos SET assigned_to_user_id=NULL,solved_at=noon WHERE id=101;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SUPPRESS_RESOLVED' THEN RAISE EXCEPTION 'Resolved source not suppressed %',v; END IF;
 UPDATE public.todos SET solved_at=NULL WHERE id=101;
 UPDATE public.notifications SET first_delivered_at=noon WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SUPPRESS_DUPLICATE' THEN RAISE EXCEPTION 'Delivered occurrence not suppressed %',v; END IF;
 UPDATE public.notifications SET first_delivered_at=NULL,expires_at=noon-interval '1 second' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'EXPIRED' THEN RAISE EXCEPTION 'Expired occurrence not suppressed %',v; END IF;
 UPDATE public.notifications SET expires_at=NULL,entity_type='mystery' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'NEEDS_VERIFICATION' THEN RAISE EXCEPTION 'Unknown module must fail closed %',v; END IF;
 UPDATE public.notifications SET entity_type='transfer',entity_id='66' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SUPPRESS_RESOLVED' THEN RAISE EXCEPTION 'Terminal known source not suppressed %',v; END IF;
 UPDATE public.notifications SET entity_id='65' WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'NEEDS_VERIFICATION' THEN RAISE EXCEPTION 'Unknown transfer owner must be verified %',v; END IF;
 UPDATE public.notifications SET entity_type='todo',entity_id='101' WHERE id=n;
 -- Service-only audit records are recomputed by server, not user-supplied.
 audit_one:=public.notification_core_record_decision(n,'queue',null);
 audit_two:=public.notification_core_record_decision(n,'queue',null);
 IF audit_one->>'inserted'<>'true' OR audit_two->>'inserted'<>'false'
    OR audit_one->>'audit_id'<>audit_two->>'audit_id' THEN
  RAISE EXCEPTION 'Idempotent audit failed % / %',audit_one,audit_two; END IF;
 IF (SELECT count(*) FROM notification_private.core_decision_audit)<>1 THEN
  RAISE EXCEPTION 'Duplicate audit rows created'; END IF;
 IF has_table_privilege('anon','notification_private.core_decision_audit','SELECT')
    OR has_table_privilege('authenticated','notification_private.core_decision_audit','SELECT')
    OR has_function_privilege('anon','public.notification_core_record_decision(uuid,text,timestamptz)','EXECUTE')
    OR has_function_privilege('authenticated','public.notification_core_record_decision(uuid,text,timestamptz)','EXECUTE')
    OR has_function_privilege('anon','public.notification_core_preview(uuid)','EXECUTE') THEN
  RAISE EXCEPTION 'Incorrect grants on core decision/audit'; END IF;
 IF NOT has_function_privilege('service_role','public.notification_core_record_decision(uuid,text,timestamptz)','EXECUTE') THEN
  RAISE EXCEPTION 'Service grant missing'; END IF;
END $test$;
-- Operator preview permission and non-owner denial (SECURITY DEFINER via authenticated).
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $test$ BEGIN
 BEGIN
   PERFORM public.notification_core_preview('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
   RAISE EXCEPTION 'Non-operator was authorized';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $test$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS core decision contract: statuses, privacy, source truth, timezone, authorization and audit idempotency' AS result;
