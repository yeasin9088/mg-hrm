-- Read-only Phase 3 release preflight. Capture output before a future migration.
WITH flags AS (
 SELECT
  to_regprocedure('notification_private.core_evaluate(uuid,timestamp with time zone)')
    IS NOT NULL AS phase1_ready,
  to_regclass('notification_private.core_policy_limits') IS NOT NULL AS phase2_ready,
  to_regclass('notification_private.digest_batches') IS NOT NULL AS phase3_already_installed,
  (SELECT enabled FROM notification_private.governance_control WHERE singleton) AS governance_enabled
)
SELECT *, (phase1_ready AND phase2_ready AND NOT phase3_already_installed
   AND NOT governance_enabled) AS ready_for_phase3
FROM flags;
SELECT (SELECT count(*) FROM public.todos) AS todo_count,
 (SELECT count(*) FROM public.notifications) AS existing_notification_count,
 (SELECT count(*) FROM public.swa_work_items) AS historical_swa_rows,
 (SELECT count(*) FROM public.push_subscriptions WHERE is_active) AS active_push_subscriptions,
 (SELECT count(*) FROM public.notification_jobs WHERE job_status IN ('Pending','Processing','Failed')) AS open_notification_jobs,
 (SELECT count(*) FROM cron.job WHERE active AND (jobname ILIKE '%notification%' OR jobname ILIKE '%push%')) AS active_notification_crons;
