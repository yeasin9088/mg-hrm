-- Read-only preflight before future Phase4 migration. No production write.
SELECT
 (to_regclass('notification_private.core_policy_limits') IS NOT NULL) AS phase2_ready,
 (to_regclass('notification_private.digest_batches') IS NOT NULL) AS phase3_ready,
 (to_regprocedure('public.notification_digest_reconcile(uuid,timestamptz)') IS NOT NULL) AS phase3_builder_ready,
 (to_regclass('notification_private.digest_bridge_control') IS NOT NULL) AS phase4_already_installed,
 (SELECT enabled FROM notification_private.governance_control WHERE singleton) AS governance_enabled,
 (SELECT count(*) FROM public.todos) AS todos,
 (SELECT count(*) FROM public.notifications) AS notifications,
 (SELECT count(*) FROM public.swa_work_items) AS historical_swa,
 (SELECT count(*) FROM public.push_subscriptions WHERE is_active) AS push_subscriptions,
 (SELECT count(*) FROM cron.job WHERE active AND (jobname ILIKE '%notification%' OR jobname ILIKE '%push%')) AS active_cron,
 (SELECT count(*) FROM public.notification_jobs WHERE job_status IN ('Pending','Processing','Failed')) AS open_jobs;
