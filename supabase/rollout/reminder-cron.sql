-- PENDING, not an automatic migration. Production backup + isolated restore gates first.
-- Securely provision Vault mg_notification_sender_token and the SAME Edge secret
-- WEB_PUSH_SENDER_TOKEN out-of-band. Never put their values in SQL source or logs.
-- Deploy and authenticate the reviewed sender before replacing its existing Cron.
BEGIN;
CREATE OR REPLACE FUNCTION notification_private.invoke_web_push_sender(p_health boolean DEFAULT false)
RETURNS bigint LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE sender_token text;
BEGIN
 IF (SELECT count(*) FROM vault.secrets WHERE name='mg_notification_sender_token')<>1 THEN
   RAISE EXCEPTION 'Exactly one sender token must be provisioned in Vault';
 END IF;
 SELECT decrypted_secret INTO sender_token FROM vault.decrypted_secrets WHERE name='mg_notification_sender_token';
 IF length(coalesce(sender_token,''))<32 THEN RAISE EXCEPTION 'Sender token configuration is invalid'; END IF;
 RETURN net.http_post(
   url:='https://enkggoozsvvkgbjeghbf.supabase.co/functions/v1/web-push-sender'||CASE WHEN p_health THEN '?health=1' ELSE '' END,
   headers:=jsonb_build_object('Content-Type','application/json','x-web-push-sender-token',sender_token),
   body:='{}'::jsonb,timeout_milliseconds:=50000);
END $$;
REVOKE ALL ON FUNCTION notification_private.invoke_web_push_sender(boolean) FROM PUBLIC,anon,authenticated;
-- Configure in a paused state: fixing the URL must not release the old backlog.
-- Never create a second sender or choose an ambiguous job owned by another role.
DO $$ BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='notification-web-push-sender')<>1 THEN
   RAISE EXCEPTION 'Exactly one existing sender Cron is required';
 END IF;
END $$;
SELECT cron.alter_job(
 job_id:=(SELECT jobid FROM cron.job WHERE jobname='notification-web-push-sender'),
 schedule:='* * * * *',command:='select notification_private.invoke_web_push_sender();',active:=false);
COMMIT;
-- While paused, invoke notification_private.invoke_web_push_sender(true).
-- Inspect that request ID's response for HTTP 200/configured=true; do not run the
-- legacy sender v5 POST with a health parameter: v5 does not implement dry-run.
-- After backup/integration gates, health and explicit backlog review, use
-- reminder-activate.sql. No activation or backlog mutation happens in this file.
