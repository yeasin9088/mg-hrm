-- Operator-approved incident containment for Phase 3. Never run routinely.
-- Revokes ONLY new digest build/reconcile privileges. No task, notification,
-- work ledger, delivery, Push subscription or diagnostic row is deleted.
-- Governance V2 remains explicitly disabled.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
UPDATE notification_private.governance_control SET enabled=false WHERE singleton;
REVOKE EXECUTE ON FUNCTION public.notification_digest_prepare_slot(
 uuid,date,text,timestamptz) FROM service_role;
REVOKE EXECUTE ON FUNCTION public.notification_digest_reconcile(
 uuid,timestamptz) FROM service_role;
REVOKE EXECUTE ON FUNCTION notification_private.digest_plan(
 uuid,date,text,timestamptz) FROM service_role;
REVOKE EXECUTE ON FUNCTION notification_private.digest_latest_due(
 timestamptz) FROM service_role;
COMMIT;
-- Re-enable service EXECUTE in a separately reviewed forward migration only.
