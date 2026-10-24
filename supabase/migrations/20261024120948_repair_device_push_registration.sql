-- Repair stale device registrations and allow an explicit per-device push test.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
ALTER FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) RENAME TO push_subscription_register_before_repair;
REVOKE ALL ON FUNCTION public.push_subscription_register_before_repair(text,text,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.push_subscription_register(p_endpoint text,p_p256dh_key text,p_auth_key text,p_device_label text DEFAULT NULL,p_browser_name text DEFAULT NULL,p_platform_name text DEFAULT NULL,p_user_agent text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; source public.notifications; device_id bigint; inserted integer;
BEGIN
 IF EXISTS(SELECT 1 FROM public.push_subscriptions WHERE endpoint=btrim(p_endpoint) AND user_id=auth.uid()
  AND revoked_at IS NOT NULL AND last_failure_at>=revoked_at-interval '1 second') THEN
  RAISE EXCEPTION 'PUSH_ENDPOINT_EXPIRED' USING ERRCODE='22023';
 END IF;
 result:=public.push_subscription_register_before_repair(p_endpoint,p_p256dh_key,p_auth_key,p_device_label,p_browser_name,p_platform_name,p_user_agent);
 device_id:=(result->>'subscription_id')::bigint;
 PERFORM 1 FROM public.push_subscriptions WHERE id=device_id AND user_id=auth.uid() FOR UPDATE;
 -- Deliver an existing unseen occurrence once to the new device without regenerating it.
 FOR source IN SELECT n.* FROM public.notifications n JOIN public.todos t ON t.id::text=n.entity_id
  WHERE n.recipient_user_id=auth.uid() AND n.entity_type='todo' AND n.read_at IS NULL
   AND n.status IN ('Ready','Delivered') AND (n.expires_at IS NULL OR n.expires_at>clock_timestamp())
   AND notification_private.todo_actionable(t) AND t.reminder_enabled
   AND coalesce(t.assigned_to_user_id,t.owner_user_id)=auth.uid()
   AND NOT EXISTS(SELECT 1 FROM public.notification_deliveries d WHERE d.notification_id=n.id AND d.subscription_id=device_id AND d.channel='WebPush')
  ORDER BY n.created_at DESC LIMIT 20
 LOOP
  INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,attempt_number,delivery_status)
   VALUES(source.id,device_id,'WebPush',1,'Pending') ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS inserted=ROW_COUNT;
  IF inserted>0 THEN
   INSERT INTO public.notification_jobs(notification_id,event_id,job_type,run_at,job_status,job_payload)
    VALUES(source.id,source.event_id,'DeliverWebPush',clock_timestamp(),'Pending','{}'::jsonb) ON CONFLICT DO NOTHING;
  END IF;
 END LOOP;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) TO authenticated;
-- Visible To-Do content includes Salary Notes when the owner enables previews.
DO $$ DECLARE body text; BEGIN
 SELECT pg_get_functiondef('public.notification_preview_before_simple(bigint,text)'::regprocedure) INTO body;
 body:=replace(body,'IF FOUND AND lower(coalesce(task.category,'''')) <> ''salary'' THEN','IF FOUND THEN');
 EXECUTE body;
 -- Explicit diagnostics alone bypass office hours and foreground suppression.
 SELECT pg_get_functiondef('public.notification_dispatch_before_simple(bigint,text)'::regprocedure) INTO body;
 body:=replace(body,'v_notification.entity_type<>''todo'' and','v_notification.entity_type NOT IN (''todo'',''device_test'') and');
 EXECUTE body;
 SELECT pg_get_functiondef('public.notification_get_web_push_dispatch(bigint,text)'::regprocedure) INTO body;
 body:=replace(body,'IF next_at>instant THEN','IF next_at>instant AND n.entity_type IS DISTINCT FROM ''device_test'' THEN');
 EXECUTE body;
END $$;
CREATE FUNCTION public.notification_test_device_push(p_subscription_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE uid uuid:=auth.uid(); nid uuid; device public.push_subscriptions;
BEGIN
 IF uid IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO device FROM public.push_subscriptions WHERE id=p_subscription_id AND user_id=uid FOR UPDATE;
 IF NOT FOUND OR NOT device.is_active OR device.revoked_at IS NOT NULL OR device.permission_state<>'granted' THEN
  RAISE EXCEPTION 'Enable this device first' USING ERRCODE='42501';
 END IF;
 IF NOT coalesce((public.notification_effective_preference(uid,'System')->>'notification_enabled')::boolean,true)
  OR NOT coalesce((public.notification_effective_preference(uid,'System')->>'system_push_enabled')::boolean,true) THEN
  RAISE EXCEPTION 'Enable device notifications in settings first';
 END IF;
 IF EXISTS(SELECT 1 FROM public.notifications WHERE recipient_user_id=uid AND entity_type='device_test'
  AND entity_id=p_subscription_id::text AND created_at>clock_timestamp()-interval '1 minute') THEN
  RAISE EXCEPTION 'Wait one minute before testing again';
 END IF;
 INSERT INTO public.notifications(recipient_user_id,category,title,message,entity_type,entity_id,status,dedupe_key,expires_at,action_route)
 VALUES(uid,'System','MG-HRM · Device push test','Device notifications and content preview are working.','device_test',p_subscription_id::text,'Ready',gen_random_uuid()::text,clock_timestamp()+interval '10 minutes','notifications') RETURNING id INTO nid;
 INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,attempt_number,delivery_status)
 VALUES(nid,p_subscription_id,'WebPush',1,'Pending');
 INSERT INTO public.notification_jobs(notification_id,job_type,run_at,job_status,job_payload)
 VALUES(nid,'DeliverWebPush',clock_timestamp(),'Pending','{}'::jsonb);
 RETURN jsonb_build_object('queued',true,'notification_id',nid);
END $$;
REVOKE ALL ON FUNCTION public.notification_test_device_push(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_test_device_push(bigint) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
