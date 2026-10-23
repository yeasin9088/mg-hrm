-- Unit-level SQL tests over disposable data only.
BEGIN;
DO $test$
DECLARE
 t public.todos; recipient uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 v jsonb; event_id_v bigint;
 noon timestamptz:='2026-10-24T06:00:00Z';
BEGIN
 SELECT * INTO t FROM public.todos WHERE id=123;
 IF NOT notification_private.todo_followup_allowed(t,recipient,noon) THEN
  RAISE EXCEPTION 'V1 compatibility: first delivery must be allowed';
 END IF;
 INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,created_at)
 VALUES('TodoReminderDue','todo','123',recipient,'2026-10-24T01:00:00Z') RETURNING id INTO event_id_v;
 INSERT INTO public.notifications(event_id,recipient_user_id,entity_type,entity_id,status,created_at)
 VALUES(event_id_v,recipient,'todo','123','Delivered','2026-10-24T01:00:00Z');
 IF notification_private.todo_followup_allowed(t,recipient,noon) THEN
  RAISE EXCEPTION 'V1 compatibility: unread must remain blocked in disabled mode';
 END IF;
 UPDATE notification_private.governance_control SET enabled=true;
 v:=notification_private.governance_evaluate_todo(t,recipient,noon);
 IF v->>'reason'<>'important_review' OR v->>'emit'<>'true' THEN
  RAISE EXCEPTION 'V2 read-independent due action failed: %',v;
 END IF;
 IF NOT notification_private.todo_followup_allowed(t,recipient,noon) THEN
  RAISE EXCEPTION 'Active V2 mode must no longer use unread as hard gate';
 END IF;
 UPDATE public.notifications SET status='Read',read_at=noon WHERE event_id=event_id_v;
 v:=notification_private.governance_evaluate_todo(t,recipient,noon);
 IF v->>'emit'<>'true' THEN
  RAISE EXCEPTION 'Reading a notification cannot flip business eligibility: %',v;
 END IF;
 v:=notification_private.governance_evaluate_todo(t,recipient,'2026-10-24T15:00:00Z');
 IF v->>'reason'<>'deferred_for_office_hours' THEN
  RAISE EXCEPTION '21:00 Dhaka must defer normal office work: %',v;
 END IF;
 v:=notification_private.governance_evaluate_todo(t,recipient,'2026-10-24T03:00:00Z');
 IF v->>'emit'<>'false' OR v->>'reason'<>'meaningful_cooldown' THEN
  RAISE EXCEPTION 'Recent important reminder must cooldown: %',v;
 END IF;
 UPDATE public.notifications SET status='Snoozed',snoozed_until=noon+interval '2 hours' WHERE event_id=event_id_v;
 v:=notification_private.governance_evaluate_todo(t,recipient,noon);
 IF v->>'reason'<>'user_snoozed' THEN RAISE EXCEPTION 'Explicit snooze must hold: %',v; END IF;
 UPDATE public.notifications SET status='Delivered',snoozed_until=null WHERE event_id=event_id_v;
 UPDATE public.todos SET solved_at=noon WHERE id=123;
 SELECT * INTO t FROM public.todos WHERE id=123;
 v:=notification_private.governance_evaluate_todo(t,recipient,noon);
 IF v->>'reason'<>'source_not_actionable' THEN
  RAISE EXCEPTION 'Resolved work must never create reminder: %',v;
 END IF;
 UPDATE notification_private.governance_control SET enabled=false;
 IF notification_private.todo_followup_allowed(t,recipient,noon) THEN
  RAISE EXCEPTION 'V1 resolved test unexpectedly eligible';
 END IF;
END $test$;
ROLLBACK;
SELECT 'PASS notification governance: V1 reversible, V2 read independent, cooldown, Dhaka office window, snooze, source terminal' AS result;
