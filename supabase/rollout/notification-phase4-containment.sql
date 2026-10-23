-- Break-glass containment ONLY, not an activation script.
-- Keep original HRM data, event history, To-Dos and service subscriptions.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
UPDATE notification_private.digest_bridge_control SET enabled=false,updated_at=clock_timestamp()
WHERE singleton=true;
UPDATE notification_private.governance_control SET enabled=false WHERE singleton=true;
COMMIT;
-- Previously queued digest events/Push jobs fail closed via Phase4 event/dispatch guards.
-- Recheck authoritative Inbox/source and notification processor health afterward.
