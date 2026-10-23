-- Synthetic Phase 2: run against disposable PostgreSQL only.
BEGIN;
DO $test$
DECLARE
 n uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 owner uuid:='11111111-1111-4111-8111-111111111111';
 noon timestamptz:='2026-10-23T06:00:00Z'; -- 12:00 Dhaka
 v jsonb; ver text; old_ver text; 
 h1 uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 h2 uuid:='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 h3 uuid:='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
 old_count integer;
BEGIN
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'SEND_NOW' OR v->>'priority_tier'<>'P3' OR
    v->>'policy_version'<>'notification-core-v2-phase2-1'
    OR v->>'push_cap_per_item_24h'<>'1' THEN
    RAISE EXCEPTION 'P3 approved cap / baseline candidate incorrect %',v; END IF;
 ver:=v->>'source_version';
 -- A reminder date is not an authoritative business deadline.
 IF v->>'deadline_verified'<>'false' OR v->>'actual_deadline_at' IS NOT NULL THEN
    RAISE EXCEPTION 'Unverified deadline fabricated %',v; END IF;
 -- Device fanout counts as ONE human-facing accepted alert.
 INSERT INTO public.notifications
 (id,recipient_user_id,category,priority,status,entity_type,entity_id)
 VALUES(h1,owner,'ToDo','Normal','Delivered','todo','101');
 INSERT INTO public.notification_deliveries(notification_id,channel,delivery_status,sent_at)
 VALUES(h1,'WebPush','Sent',noon-interval '1 hour'),
       (h1,'WebPush','Delivered',noon-interval '1 hour');
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'DEFER' OR v->>'reason_code'<>'rolling_per_item_push_cap'
    OR v->>'push_count_per_item_24h'<>'1' OR
    (v->>'next_eligible_at')::timestamptz<>noon+interval '23 hours' THEN
    RAISE EXCEPTION 'P3 cap or multi-device distinct count broken %',v; END IF;
 UPDATE public.todos SET is_important=true,updated_at=noon WHERE id=101;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'priority_tier'<>'P2' OR v->>'push_cap_per_item_24h'<>'2'
    OR v->>'decision'<>'SEND_NOW' THEN RAISE EXCEPTION 'P2 approved limit incorrectly handled %',v; END IF;
 ver:=v->>'source_version';
 UPDATE notification_private.core_policy_limits SET p2_cooldown=interval '4 hours';
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'DEFER' OR v->>'reason_code'<>'per_item_push_cooldown'
    THEN RAISE EXCEPTION 'P2 configurable cooldown failed %',v; END IF;
 UPDATE notification_private.core_policy_limits SET p2_cooldown=NULL;
 INSERT INTO public.notifications
 (id,recipient_user_id,category,priority,status,entity_type,entity_id)
 VALUES(h2,owner,'ToDo','Normal','Delivered','todo','101');
 INSERT INTO public.notification_deliveries(notification_id,channel,delivery_status,sent_at)
 VALUES(h2,'WebPush','Sent',noon-interval '30 minutes');
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'decision'<>'DEFER' OR v->>'push_count_per_item_24h'<>'2' THEN
    RAISE EXCEPTION 'P2 second actual send did not reach cap %',v; END IF;
 -- A stale/future successful send cannot count in the wrong rolling window.
 UPDATE public.notification_deliveries SET sent_at=noon-interval '25 hours'
 WHERE notification_id=h2;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'push_count_per_item_24h'<>'1' OR v->>'decision'<>'SEND_NOW' THEN
    RAISE EXCEPTION 'Rolling-window expiry incorrect %',v; END IF;
 -- Real verified deadline is independent from To-Do remind_on / execution window.
 INSERT INTO notification_private.core_verified_deadlines(
 entity_type,entity_id,recipient_user_id,source_version,actual_deadline_at,
 verified_basis,evidence_reference,verified_at)
 VALUES('todo','101',owner,ver,'2026-10-24T02:00:00Z',
  'manual_verified','Synthetic confirmed joining at 08:00','2026-10-23T01:00:00Z');
 v:=notification_private.core_evaluate(n,'2026-10-23T11:30:00Z'); -- 17:30 Dhaka
 IF v->>'priority_tier'<>'P1' OR v->>'risk_reason'<>'verified_before_next_office_open'
    OR v->>'reason_code'<>'p1_delivery_policy_not_approved'
    OR v->>'actual_deadline_at'<>'2026-10-24T02:00:00+00:00' THEN
    RAISE EXCEPTION 'Verified next-morning deadline not protected %',v; END IF;
 -- P1 may only propose SEND_NOW after explicit policy approval in isolated test.
 UPDATE notification_private.core_policy_limits
   SET p1_push_enabled=true,p1_item_cap_24h=2;
 v:=notification_private.core_evaluate(n,'2026-10-23T11:30:00Z');
 IF v->>'decision'<>'SEND_NOW' OR v->>'priority_tier'<>'P1' THEN
   RAISE EXCEPTION 'Approved P1 bounded candidate missing %',v; END IF;
 v:=notification_private.core_evaluate(n,'2026-10-23T13:00:00Z'); -- 19:00 Dhaka
 IF v->>'decision'<>'DIGEST' OR v->>'risk_reason'<>'verified_before_next_office_open'
    THEN RAISE EXCEPTION 'No unauthorized after-hours P1 interrupt %',v; END IF;
 -- Verified deadline not silently extended by snooze/ack.
 UPDATE public.notifications SET snoozed_until='2026-10-24T04:00:00Z' WHERE id=n;
 v:=notification_private.core_evaluate(n,'2026-10-23T11:30:00Z');
 IF v->>'decision'<>'SUPPRESS_SNOOZED' OR
   v->>'snooze_deadline_conflict'<>'true' THEN
   RAISE EXCEPTION 'Snooze/deadline conflict warning missing %',v; END IF;
 UPDATE public.notifications SET snoozed_until=NULL WHERE id=n;
 INSERT INTO public.swa_work_items(owner_user_id,source_module,source_record_id,
  acknowledged_until,snoozed_until)
 VALUES(owner,'todo','101','2026-10-24T04:00:00Z',null);
 v:=notification_private.core_evaluate(n,'2026-10-23T11:30:00Z');
 IF v->>'decision'<>'SUPPRESS_ACKNOWLEDGED' OR
    v->>'snooze_deadline_conflict'<>'true' THEN
   RAISE EXCEPTION 'Single nonnull ACK lease / conflict not honored %',v; END IF;
 DELETE FROM public.swa_work_items;
 UPDATE notification_private.core_policy_limits
   SET p1_push_enabled=false,p1_item_cap_24h=NULL;
 UPDATE public.todos SET updated_at=noon+interval '1 minute' WHERE id=101;
 v:=notification_private.core_evaluate(n,'2026-10-23T11:30:00Z');
 IF v->>'deadline_verified'<>'false' OR v->>'priority_tier'<>'P2' THEN
   RAISE EXCEPTION 'Material source version did not invalidate stale deadline %',v; END IF;
 -- Optional global caps are configured but inactive in actual production.
 UPDATE notification_private.core_policy_limits SET user_cap_24h=1;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'reason_code'<>'rolling_per_user_push_cap' THEN
   RAISE EXCEPTION 'User cap not honored %',v; END IF;
 UPDATE notification_private.core_policy_limits SET user_cap_24h=NULL,category_cap_24h=1;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'reason_code'<>'rolling_per_category_push_cap' THEN
   RAISE EXCEPTION 'Category cap not honored %',v; END IF;
 UPDATE notification_private.core_policy_limits SET category_cap_24h=NULL;
 -- Read/Mark All Read is NOT a source-business action and cannot replenish caps.
 UPDATE public.notifications SET read_at=noon WHERE id=n;
 v:=notification_private.core_evaluate(n,noon);
 IF v->>'push_count_per_item_24h'<>'1' THEN
   RAISE EXCEPTION 'Read modified rolling delivered-Push cap %',v; END IF;
 -- Audit must capture exact machine-readable risk and cap evidence.
 PERFORM public.notification_core_record_decision(n,'candidate',noon);
 IF NOT EXISTS(SELECT 1 FROM notification_private.core_decision_audit
   WHERE decision_details ? 'push_count_per_item_24h' AND
     decision_details->>'policy_version'='notification-core-v2-phase2-1') THEN
   RAISE EXCEPTION 'Core audit missing decision facts'; END IF;
 IF has_table_privilege('anon','notification_private.core_verified_deadlines','SELECT')
   OR has_table_privilege('authenticated','notification_private.core_policy_limits','UPDATE')
   OR has_function_privilege('anon','notification_private.core_evaluate(uuid,timestamptz)','EXECUTE')
   THEN RAISE EXCEPTION 'Privacy/role boundary incorrect'; END IF;
END $test$;
ROLLBACK;
SELECT 'PASS Phase 2: verified P1, approved P2/P3 rolling caps, multi-device counting, after hours, source version, snooze conflict, evidence audit' result;
