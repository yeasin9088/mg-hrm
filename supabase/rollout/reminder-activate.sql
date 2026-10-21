-- PENDING: run only after verified backup/restore, hosted integration and an
-- authenticated read-only sender health response (200, configured=true).
-- Review existing push work explicitly. Never bulk-send or delete old history.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
SELECT pg_advisory_xact_lock(73110420261021);
LOCK TABLE public.notification_events,public.notification_jobs,public.notification_deliveries,public.notifications IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE sender_job bigint;
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='notification-web-push-sender')<>1 THEN
   RAISE EXCEPTION 'Exactly one configured sender Cron is required';
 END IF;
 SELECT jobid INTO sender_job FROM cron.job WHERE jobname='notification-web-push-sender'
   AND command='select notification_private.invoke_web_push_sender();' AND NOT active;
 IF sender_job IS NULL THEN RAISE EXCEPTION 'Sender Cron must be configured and paused'; END IF;
 -- Conservative gate: even future/non-ToDo work must be explicitly reviewed.
 -- An operator can preserve reviewed legacy inbox items while cancelling ONLY
 -- selected stale/duplicate push jobs/attempts in a separately reviewed transaction.
 IF EXISTS(SELECT 1 FROM public.notification_events WHERE processing_status IN ('Pending','Failed'))
    OR EXISTS(SELECT 1 FROM public.notification_jobs WHERE job_type='ProcessEvent' AND job_status IN ('Pending','Failed','Processing'))
    OR EXISTS(SELECT 1 FROM public.notifications WHERE status IN ('Ready','Scheduled','Snoozed','Failed'))
    OR EXISTS(SELECT 1 FROM public.notification_jobs WHERE job_type='DeliverWebPush'
     AND job_status IN ('Pending','Failed','Processing'))
    OR EXISTS(SELECT 1 FROM public.notification_deliveries WHERE channel='WebPush'
     AND delivery_status IN ('Pending','Failed','Processing')) THEN
   RAISE EXCEPTION 'Existing Web Push backlog requires explicit review before activation';
 END IF;
 PERFORM public.notification_set_server_reminders(true);
 PERFORM cron.alter_job(job_id:=sender_job,active:=true);
END $$;
COMMIT;
-- Rollback producer mode under the same lock; pause the sender independently
-- if required. Do not delete audit rows or undo unrelated business records.
