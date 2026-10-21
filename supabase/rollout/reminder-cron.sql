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
-- Replace the existing named sender job, never add a competing sender schedule.
SELECT cron.schedule('notification-web-push-sender','* * * * *',
  'select notification_private.invoke_web_push_sender();');
COMMIT;
-- After authenticated health=1 succeeds and isolated acceptance + backup gates pass:
-- SELECT public.notification_set_server_reminders(true);
-- Rollback producer mode only (preserves schedules/history):
-- SELECT public.notification_set_server_reminders(false);
