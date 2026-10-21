-- One-time secure cutover from the existing Cron credential, without exporting it.
-- No credential literals. Existing Edge secret is retained; health proves equality.
BEGIN;
DO $$
DECLARE token text; existing text; sender_job bigint;
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='notification-web-push-sender')<>1 THEN RAISE EXCEPTION 'Expected exactly one sender Cron'; END IF;
 SELECT jobid,substring(command from '"x-web-push-sender-token"[[:space:]]*:[[:space:]]*"([^"]+)"') INTO sender_job,token FROM cron.job WHERE jobname='notification-web-push-sender';
 IF (SELECT count(*) FROM vault.secrets WHERE name='mg_notification_sender_token')>1 THEN RAISE EXCEPTION 'Ambiguous sender credential'; END IF;
 SELECT decrypted_secret INTO existing FROM vault.decrypted_secrets WHERE name='mg_notification_sender_token';
 IF existing IS NULL THEN
  IF length(coalesce(token,''))<32 THEN RAISE EXCEPTION 'Existing sender credential is not usable'; END IF;
  PERFORM vault.create_secret(token,'mg_notification_sender_token','Existing MG-HRM sender credential; migrated internally from Cron without disclosure');
 ELSIF length(existing)<32 OR (token IS NOT NULL AND existing IS DISTINCT FROM token) THEN
  RAISE EXCEPTION 'Existing Vault configuration requires secure reconciliation';
 END IF;
 PERFORM cron.alter_job(job_id:=sender_job,active:=false);
END $$;
COMMIT;
