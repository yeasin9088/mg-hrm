-- SYNTHETIC LOCAL ONLY. Explicit target guard; all fixtures roll back.
BEGIN;
DO $test$ BEGIN
  IF current_database() <> 'mghrm_test' OR host(inet_server_addr()) <> '127.0.0.1' OR inet_server_port() <> 55432 THEN
    RAISE EXCEPTION 'Isolated local notification test target required';
  END IF;
END $test$;
INSERT INTO public.profiles(id,role,is_active) VALUES
 ('11111111-1111-4111-8111-111111111111','admin',true),
 ('22222222-2222-4222-8222-222222222222','viewer',true);
INSERT INTO public.notification_preferences(user_id,category,quiet_hours_enabled)
 VALUES('11111111-1111-4111-8111-111111111111','*',false);
INSERT INTO public.todos(id,note,status,reminder_enabled,next_reminder_at)
 VALUES(900000000001,'LOCAL SYNTHETIC','open',true,now()-interval '1 hour');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims='{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
INSERT INTO public.notification_legacy_states(user_id,event_key,status,read_at)
 VALUES(auth.uid(),'local-test:read','Read',now());
DO $test$
DECLARE result jsonb; due timestamptz;
BEGIN
  BEGIN
    INSERT INTO public.notification_legacy_states(user_id,event_key,status)
     VALUES('22222222-2222-4222-8222-222222222222','local-test:forged','Read');
    RAISE EXCEPTION 'Forged state unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- The due time is supplied as a compare-and-set precondition by each device.
  RESET ROLE;
  SELECT next_reminder_at INTO due FROM public.todos WHERE id=900000000001;
  SET LOCAL ROLE authenticated;
  result:=public.notification_claim_todo_reminder(900000000001,due,now()+interval '1 day');
  IF result->>'claimed' <> 'true' THEN RAISE EXCEPTION 'Genuine due event not claimed'; END IF;
  result:=public.notification_claim_todo_reminder(900000000001,due,now()+interval '1 day');
  IF result->>'claimed' <> 'false' THEN RAISE EXCEPTION 'Retry created another event'; END IF;
END $test$;
RESET ROLE;
SELECT public.notification_run_event_processor('local-notification-test',20);
DO $test$ BEGIN
  IF (SELECT count(*) FROM public.notification_events WHERE entity_id='900000000001')<>1 OR
     (SELECT count(*) FROM public.notifications WHERE entity_id='900000000001')<>1 THEN
    RAISE EXCEPTION 'Event pipeline duplicated or lost a genuine event';
  END IF;
END $test$;
SELECT public.notification_run_event_processor('local-notification-retry',20);
SELECT public.notification_prepare_deliveries(20);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE notification_id uuid; result jsonb;
BEGIN
  RESET ROLE;
  SELECT id INTO notification_id FROM public.notifications WHERE entity_id='900000000001';
  SET LOCAL ROLE authenticated;
  result:=public.notification_mark_read(notification_id);
  IF result->'notification'->>'status'<>'Read' THEN RAISE EXCEPTION 'Read state failed'; END IF;
  result:=public.notification_snooze(notification_id,now()+interval '1 hour');
  IF result->'notification'->>'status'<>'Snoozed' THEN RAISE EXCEPTION 'Snooze failed'; END IF;
  BEGIN
    PERFORM public.notification_complete_if_resolved(notification_id);
    RAISE EXCEPTION 'Unresolved source unexpectedly completed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  result:=public.notification_dismiss(notification_id);
  IF result->'notification'->>'status'<>'Dismissed' THEN RAISE EXCEPTION 'Dismiss failed'; END IF;
END $test$;
SET LOCAL request.jwt.claims='{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';
DO $test$ BEGIN
  IF (SELECT count(*) FROM public.notification_legacy_states)<>0 THEN RAISE EXCEPTION 'Other account state leaked'; END IF;
  BEGIN
    PERFORM public.notification_claim_todo_reminder(900000000001,null,now()+interval '1 day');
    RAISE EXCEPTION 'Viewer claimed a reminder';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $test$;
SET LOCAL ROLE anon;
DO $test$ BEGIN
  BEGIN
    PERFORM public.notification_claim_todo_reminder(900000000001,null,now()+interval '1 day');
    RAISE EXCEPTION 'Anonymous reminder claim accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $test$;
ROLLBACK;
