-- Read-only Phase 3 postflight: run only after authorized future migration.
SELECT
 to_regclass('notification_private.digest_batches') IS NOT NULL AS phase3_batches_installed,
 to_regclass('notification_private.digest_items') IS NOT NULL AS phase3_items_installed,
 to_regprocedure('notification_private.digest_plan(uuid,date,text,timestamp with time zone)')
 IS NOT NULL AS planner_installed,
 to_regprocedure('notification_private.digest_latest_due(timestamp with time zone)')
 IS NOT NULL AS slot_resolver_installed,
 to_regprocedure('public.notification_digest_prepare_slot(uuid,date,text,timestamp with time zone)')
 IS NOT NULL AS builder_installed,
 to_regprocedure('public.notification_digest_reconcile(uuid,timestamp with time zone)')
 IS NOT NULL AS recovery_installed,
 to_regprocedure('public.notification_digest_preview(date,text)')
 IS NOT NULL AS operator_preview_installed,
 (SELECT enabled FROM notification_private.governance_control WHERE singleton) AS governance_enabled;
SELECT
 has_function_privilege('anon','public.notification_digest_prepare_slot(uuid,date,text,timestamptz)','EXECUTE') AS anon_can_build,
 has_function_privilege('authenticated','public.notification_digest_reconcile(uuid,timestamptz)','EXECUTE') AS normal_user_can_reconcile,
 has_function_privilege('service_role','public.notification_digest_prepare_slot(uuid,date,text,timestamptz)','EXECUTE') AS trusted_worker_can_build,
 has_table_privilege('anon','notification_private.digest_batches','SELECT') AS anon_can_view_batches,
 has_table_privilege('authenticated','notification_private.digest_items','SELECT') AS normal_user_can_view_items;
SELECT (SELECT count(*) FROM public.todos) AS todo_count,
 (SELECT count(*) FROM public.notifications) AS existing_notification_count,
 (SELECT count(*) FROM public.swa_work_items) AS historical_swa_rows,
 (SELECT count(*) FROM public.push_subscriptions WHERE is_active) AS active_push_subscriptions,
 (SELECT count(*) FROM public.notification_jobs WHERE job_status IN ('Pending','Processing','Failed')) AS open_notification_jobs,
 (SELECT count(*) FROM notification_private.digest_batches) AS new_digest_batches,
 (SELECT count(*) FROM notification_private.digest_items) AS new_digest_items;
