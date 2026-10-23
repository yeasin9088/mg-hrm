-- Applied 2026-10-23 16:30:43 UTC by explicit owner authorization.
-- Runtime configuration only. Not a schema migration; no history replay.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(73110420261011);
UPDATE notification_private.governance_control SET enabled=true,updated_at=clock_timestamp() WHERE singleton;
UPDATE notification_private.digest_bridge_control SET enabled=true,updated_at=clock_timestamp() WHERE singleton;
COMMIT;
-- Existing notification_cron_tick automatically selects the V2 path when both flags are true.
-- Containment: existing supabase/rollout/notification-workflow-containment.sql.
