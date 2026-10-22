-- Manual rollback ONLY if the new transfer due producer must be disabled.
-- Does not remove historical events/notifications; does not change any transfer/employee rows.
BEGIN;
DO $rollback$
DECLARE v_job integer;
BEGIN
  SELECT jobid INTO v_job FROM cron.job WHERE jobname='mghrm-transfer-due-notifications';
  IF v_job IS NOT NULL THEN PERFORM cron.unschedule(v_job); END IF;
END $rollback$;
DROP FUNCTION IF EXISTS public.mghrm_sync_due_transfer_notifications();
COMMIT;