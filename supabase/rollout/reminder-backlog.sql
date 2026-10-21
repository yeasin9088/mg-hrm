-- Owner-authorized one-time cutover disposition. Retains inbox and all audit rows.
-- Only the reviewed, never-attempted pre-rollout ToDo push backlog is cancelled.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
SELECT pg_advisory_xact_lock(73110420261021);
LOCK TABLE public.notification_jobs,public.notification_deliveries IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE jobs bigint[]; affected integer;
BEGIN
 IF public.notification_reminder_mode() OR EXISTS(SELECT 1 FROM cron.job WHERE jobname='notification-web-push-sender' AND active) THEN
  RAISE EXCEPTION 'Producer must be off and sender paused';
 END IF;
 SELECT array_agg(j.id) INTO jobs FROM public.notification_jobs j JOIN public.notifications n ON n.id=j.notification_id
 WHERE j.job_type='DeliverWebPush' AND j.job_status='Pending' AND j.attempt_count=0
 AND j.created_at<'2026-10-21 16:10:00+00' AND j.created_at<clock_timestamp()-interval '30 minutes'
 AND n.category='ToDo' AND n.entity_type='todo' AND n.status IN ('Read','Delivered','Dismissed','Actioned');
 IF cardinality(jobs) IS DISTINCT FROM 28 THEN RAISE EXCEPTION 'Reviewed 28-job scope changed; inspect again'; END IF;
 IF (SELECT count(*) FROM public.notification_deliveries d WHERE d.channel='WebPush' AND d.delivery_status='Pending'
  AND d.attempted_at IS NULL AND d.notification_id IN (SELECT notification_id FROM public.notification_jobs WHERE id=ANY(jobs)))<>56 THEN
  RAISE EXCEPTION 'Reviewed 56-delivery scope changed; inspect again';
 END IF;
 UPDATE public.notification_deliveries SET delivery_status='Cancelled',provider_status='RolloutSuperseded',
  error_code='STALE_PRE_CUTOVER',error_message='Never-attempted reminder exceeded its delivery TTL before server cutover; inbox retained'
 WHERE channel='WebPush' AND delivery_status='Pending' AND attempted_at IS NULL
 AND notification_id IN (SELECT notification_id FROM public.notification_jobs WHERE id=ANY(jobs));
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>56 THEN RAISE EXCEPTION 'Unexpected delivery count'; END IF;
 UPDATE public.notification_jobs SET job_status='Cancelled',completed_at=clock_timestamp(),locked_by=NULL,locked_at=NULL,
  last_error='STALE_PRE_CUTOVER: reviewed expired push attempt; inbox/history retained'
 WHERE id=ANY(jobs);
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>28 THEN RAISE EXCEPTION 'Unexpected job count'; END IF;
END $$;
COMMIT;
