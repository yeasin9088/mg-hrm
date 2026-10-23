-- Read-only postflight after authorized Phase3->Phase4 schema changes.
SELECT
 (to_regclass('notification_private.digest_bridge_control') IS NOT NULL) AS bridge_installed,
 (to_regclass('notification_private.digest_publish_audit') IS NOT NULL) AS audit_installed,
 (to_regprocedure('notification_private.digest_publish_slot(uuid,timestamptz)') IS NOT NULL) AS publish_function_installed,
 (to_regprocedure('notification_private.digest_dispatch_allowed(text,uuid,timestamptz)') IS NOT NULL) AS last_mile_guard_installed,
 (to_regprocedure('notification_private.digest_publish_for_operators(timestamptz)') IS NOT NULL) AS operator_function_installed,
 (SELECT enabled FROM notification_private.governance_control WHERE singleton) AS governance_enabled,
 (SELECT enabled FROM notification_private.digest_bridge_control WHERE singleton) AS bridge_enabled,
 (SELECT count(*) FROM notification_private.digest_publish_audit) AS published_batches,
 (SELECT count(*) FROM public.todos) AS todos,
 (SELECT count(*) FROM public.notifications) AS notifications,
 (SELECT count(*) FROM public.swa_work_items) AS historical_swa,
 (SELECT count(*) FROM public.push_subscriptions WHERE is_active) AS active_push;
SELECT
 has_function_privilege('anon','notification_private.digest_publish_slot(uuid,timestamptz)','EXECUTE') AS anon_publish,
 has_function_privilege('authenticated','notification_private.digest_publish_for_operators(timestamptz)','EXECUTE') AS user_publish,
 has_function_privilege('service_role','notification_private.digest_publish_slot(uuid,timestamptz)','EXECUTE') AS worker_publish,
 has_table_privilege('authenticated','notification_private.digest_publish_audit','SELECT') AS user_can_read_audit;
