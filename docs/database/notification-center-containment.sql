-- Containment only. Preserve all state/history. Does not disable existing worker
-- RPCs or restore the former browser scheduler. Do not drop the state table.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.notification_claim_todo_reminder(bigint,timestamptz,timestamptz) FROM authenticated;
REVOKE INSERT, UPDATE ON public.notification_legacy_states FROM authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
