-- Synthetic hosted acceptance: every fixture and mode change rolls back.
-- Sender must be paused. No net calls, provider calls, real-user notifications or
-- persisted Auth users are created. Sequence gaps on rollback are expected.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
SELECT pg_advisory_xact_lock(73110420261021);
LOCK TABLE public.todos,public.notifications,public.notification_events,public.notification_jobs,public.notification_deliveries IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid();
 tab uuid:=gen_random_uuid(); device uuid:=gen_random_uuid(); ev bigint; job bigint; nid uuid;
 dispatch jsonb; result jsonb; first_note bigint:=-91020261021001; second_note bigint:=-91020261021002;
BEGIN
 IF public.notification_reminder_mode() OR EXISTS(SELECT 1 FROM cron.job WHERE jobname='notification-web-push-sender' AND active) THEN RAISE EXCEPTION 'Acceptance requires disabled mode and paused sender'; END IF;
 IF EXISTS(SELECT 1 FROM todos t WHERE reminder_enabled AND notification_private.todo_actionable(t) AND (next_reminder_at IS NULL OR next_reminder_at<'2000-01-01'::timestamptz)) THEN RAISE EXCEPTION 'Fixture ordering precondition changed'; END IF;
 IF EXISTS(SELECT 1 FROM notifications WHERE status IN ('Ready','Scheduled','Snoozed','Failed') OR (expires_at<=clock_timestamp() AND status IN ('Delivered','Read','Actioned'))) THEN RAISE EXCEPTION 'Existing inbox work must not be processed by acceptance'; END IF;
 IF EXISTS(SELECT 1 FROM notification_jobs WHERE job_type='DeliverWebPush' AND job_status IN ('Pending','Processing','Failed')) THEN RAISE EXCEPTION 'Resolve reviewed legacy push backlog first'; END IF;
 INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES(a,a||'@acceptance.invalid','{}'),(b,b||'@acceptance.invalid','{}');
 INSERT INTO auth.sessions(id,user_id,not_after) VALUES(sid,b,now()+interval '1 hour');
 INSERT INTO notification_preferences(user_id,category,quiet_hours_enabled) VALUES(a,'*',false),(b,'*',false);
 INSERT INTO push_subscriptions(user_id,endpoint,endpoint_hash,p256dh_key,auth_key,permission_state)
 SELECT b,'https://synthetic.invalid/'||b||'/'||i,b||':'||i,'synthetic','synthetic',CASE WHEN i=3 THEN 'denied' ELSE 'granted' END FROM generate_series(1,3)i;
 INSERT INTO push_subscriptions(user_id,endpoint,endpoint_hash,p256dh_key,auth_key) VALUES(a,'https://synthetic.invalid/'||a,a::text,'synthetic','synthetic');
 PERFORM notification_set_server_reminders(true);
 INSERT INTO todos(id,note,status,owner_user_id,assigned_to_user_id,reminder_enabled,reminder_type,reminder_interval,next_reminder_at)
 VALUES(first_note,'SYNTHETIC ROLLBACK ACCEPTANCE','pending',a,b,true,'30m',30,'1990-01-01');
 result:=notification_schedule_todos(1);
 IF (result->>'events_created')::int<>1 THEN RAISE EXCEPTION 'Recurring event not generated'; END IF;
 SELECT id INTO ev FROM notification_events WHERE entity_type='todo' AND entity_id=first_note::text;
 IF (SELECT event_payload->>'recipient_user_id' FROM notification_events WHERE id=ev) IS DISTINCT FROM b::text THEN RAISE EXCEPTION 'Assigned-user routing failed'; END IF;
 IF NOT (SELECT next_reminder_at>clock_timestamp() AND next_reminder_at<=clock_timestamp()+interval '30 minutes' FROM todos WHERE id=first_note) THEN RAISE EXCEPTION 'Recurring future slot invalid'; END IF;
 PERFORM set_config('mghrm.scheduler_write','on',true);
 UPDATE todos SET next_reminder_at='1990-01-01' WHERE id=first_note;
 PERFORM set_config('mghrm.scheduler_write','off',true);
 PERFORM notification_schedule_todos(1);
 IF (SELECT count(*) FROM notification_events WHERE entity_id=first_note::text)<>1 THEN RAISE EXCEPTION 'Occurrence duplicated'; END IF;
 IF notification_claim_todo_reminder(first_note,NULL,NULL)->>'producer'<>'server' THEN RAISE EXCEPTION 'Legacy producer not fenced'; END IF;
 PERFORM notification_enqueue_pending_events(1);
 SELECT id INTO job FROM notification_jobs WHERE event_id=ev AND job_type='ProcessEvent';
 UPDATE notification_jobs SET job_status='Processing',locked_by='hosted-acceptance',locked_at=now() WHERE id=job;
 nid:=notification_process_event_job(job,'hosted-acceptance');
 IF nid IS NULL THEN RAISE EXCEPTION 'Inbox creation failed'; END IF;
 PERFORM notification_prepare_deliveries(1);
 IF (SELECT count(*) FROM notification_deliveries WHERE notification_id=nid AND channel='WebPush')<>2 THEN RAISE EXCEPTION 'Fanout or permission isolation failed'; END IF;
 SELECT id INTO job FROM notification_jobs WHERE notification_id=nid AND job_type='DeliverWebPush';
 UPDATE notification_jobs SET job_status='Processing',locked_by='hosted-acceptance',locked_at=now(),attempt_count=1 WHERE id=job;
 dispatch:=notification_get_web_push_dispatch(job,'hosted-acceptance');
 IF jsonb_array_length(dispatch->'deliveries')<>2 THEN RAISE EXCEPTION 'Closed/background delivery eligibility failed'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sid)::text,true);
 PERFORM notification_presence_heartbeat(tab,device,true,true,true);
 IF NOT notification_private.has_foreground(b) OR notification_private.has_foreground(a) THEN RAISE EXCEPTION 'Presence isolation failed'; END IF;
 dispatch:=notification_get_web_push_dispatch(job,'hosted-acceptance');
 IF jsonb_array_length(dispatch->'deliveries')<>0 THEN RAISE EXCEPTION 'Foreground suppression failed'; END IF;
 PERFORM notification_presence_heartbeat(tab,device,false,false,true);
 IF notification_private.has_foreground(b) THEN RAISE EXCEPTION 'Hidden/minimized presence remained active'; END IF;
 PERFORM notification_presence_heartbeat(tab,device,true,true,true);
 UPDATE notification_private.foreground_sessions SET last_seen_at=now()-interval '76 seconds' WHERE user_id=b;
 IF notification_private.has_foreground(b) THEN RAISE EXCEPTION 'Crashed session did not expire'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sid)::text,true);
 BEGIN
  PERFORM notification_presence_heartbeat(gen_random_uuid(),device,true,true,true);
  RAISE EXCEPTION 'Forged session was accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sid)::text,true);
 PERFORM notification_snooze(nid,now()+interval '1 hour');
 IF NOT EXISTS(SELECT 1 FROM notifications WHERE id=nid AND status='Snoozed' AND scheduled_for>now()) THEN RAISE EXCEPTION 'Snooze failed'; END IF;
 UPDATE todos SET next_reminder_at=now()+interval '3 hours' WHERE id=first_note;
 IF EXISTS(SELECT 1 FROM notification_jobs WHERE notification_id=nid AND job_type='DeliverWebPush' AND job_status IN ('Pending','Processing','Failed')) THEN RAISE EXCEPTION 'Reschedule did not cancel old push'; END IF;
 UPDATE todos SET status='solved',solved_at=now() WHERE id=first_note;
 IF notification_private.todo_actionable((SELECT t FROM todos t WHERE id=first_note)) THEN RAISE EXCEPTION 'Solved note remained actionable'; END IF;
 INSERT INTO todos(id,note,status,owner_user_id,assigned_to_user_id,reminder_enabled,reminder_type,next_reminder_at)
 VALUES(second_note,'SYNTHETIC ONE-TIME ROLLBACK','pending',a,b,true,'once','1990-01-01');
 PERFORM notification_schedule_todos(1);
 IF (SELECT reminder_enabled FROM todos WHERE id=second_note) OR (SELECT count(*) FROM notification_events WHERE entity_id=second_note::text)<>1 THEN RAISE EXCEPTION 'One-time schedule failed'; END IF;
 -- Hosted quiet-hour calculation uses a window guaranteed to include the test instant.
 UPDATE notification_preferences SET timezone='UTC',quiet_hours_enabled=true,
  quiet_hours_start=((now() AT TIME ZONE 'UTC')-interval '1 hour')::time,
  quiet_hours_end=((now() AT TIME ZONE 'UTC')+interval '1 hour')::time WHERE user_id=b;
 IF public.notification_next_allowed_at(b,'ToDo','Normal',now())<=now() THEN RAISE EXCEPTION 'Quiet-hours deferral failed'; END IF;
 UPDATE notification_preferences SET quiet_hours_enabled=false WHERE user_id=b;
 -- Retry diagnostics here are simulated provider results, never real acceptance.
 SELECT id INTO ev FROM notification_events WHERE entity_id=second_note::text;
 PERFORM notification_enqueue_pending_events(1);
 SELECT id INTO job FROM notification_jobs WHERE event_id=ev AND job_type='ProcessEvent';
 UPDATE notification_jobs SET job_status='Processing',locked_by='hosted-retry',locked_at=now() WHERE id=job;
 nid:=notification_process_event_job(job,'hosted-retry');
 PERFORM notification_prepare_deliveries(1);
 SELECT id INTO job FROM notification_jobs WHERE notification_id=nid AND job_type='DeliverWebPush';
 UPDATE notification_jobs SET job_status='Processing',locked_by='hosted-retry',locked_at=now(),attempt_count=1 WHERE id=job;
 dispatch:=notification_get_web_push_dispatch(job,'hosted-retry');
 IF jsonb_array_length(dispatch->'deliveries') IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'Retry fixture fanout failed'; END IF;
 PERFORM notification_record_web_push_result(job,'hosted-retry',(dispatch->'deliveries'->0->>'delivery_id')::bigint,false,'410',NULL,'HTTP_410','Synthetic expired endpoint','{}',true);
 PERFORM notification_record_web_push_result(job,'hosted-retry',(dispatch->'deliveries'->1->>'delivery_id')::bigint,false,'503',NULL,'HTTP_503','Synthetic retry','{}',false);
 PERFORM notification_finalize_web_push_job(job,'hosted-retry',interval '2 minutes');
 IF NOT EXISTS(SELECT 1 FROM notification_jobs WHERE id=job AND job_status='Failed' AND run_at>now()) THEN RAISE EXCEPTION 'Retry backoff failed'; END IF;
 IF (SELECT count(*) FROM push_subscriptions WHERE user_id=b AND permission_state='revoked' AND revoked_at IS NOT NULL)<>1 THEN RAISE EXCEPTION 'Expired subscription was not revoked'; END IF;
 UPDATE notification_jobs SET run_at=now() WHERE id=job;
 PERFORM notification_claim_web_push_jobs('hosted-retry-2',1);
 dispatch:=notification_get_web_push_dispatch(job,'hosted-retry-2');
 IF jsonb_array_length(dispatch->'deliveries') IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Retry did not exclude revoked device'; END IF;
 PERFORM notification_record_web_push_result(job,'hosted-retry-2',(dispatch->'deliveries'->0->>'delivery_id')::bigint,true,'201');
 PERFORM notification_finalize_web_push_job(job,'hosted-retry-2');
 IF NOT EXISTS(SELECT 1 FROM notification_jobs WHERE id=job AND job_status='Completed') THEN RAISE EXCEPTION 'Retry completion failed'; END IF;
 IF has_function_privilege('authenticated','public.notification_schedule_todos(integer)','EXECUTE') OR has_function_privilege('authenticated','public.notification_set_server_reminders(boolean)','EXECUTE') THEN RAISE EXCEPTION 'Service grants failed'; END IF;
 IF has_table_privilege('authenticated','notification_private.foreground_sessions','SELECT') THEN RAISE EXCEPTION 'Private presence exposed'; END IF;
 RAISE NOTICE 'PASS hosted synthetic scheduling, deduplication, routing, inbox, fanout, permissions, presence, snooze, reschedule, solved state, quiet hours and retries; all fixtures roll back';
END $$;
ROLLBACK;
SELECT notification_reminder_mode() AS server_mode_after_rollback;
