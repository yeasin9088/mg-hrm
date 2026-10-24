-- Owner-approved replacement: one unseen occurrence per To-Do, repeat after acknowledgement.
-- Existing notification/delivery history is retained. No source HR workflow is auto-approved.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE TABLE notification_private.simple_reminder_policy (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 office_start time NOT NULL DEFAULT '09:00',office_end time NOT NULL DEFAULT '18:00',
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0)
);
INSERT INTO notification_private.simple_reminder_policy DEFAULT VALUES;
ALTER TABLE notification_private.simple_reminder_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.simple_reminder_policy FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE notification_private.device_action_tokens (
 token_hash text PRIMARY KEY,notification_id uuid NOT NULL REFERENCES public.notifications(id),
 recipient_user_id uuid NOT NULL,expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '14 days'
);
ALTER TABLE notification_private.device_action_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.device_action_tokens FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX device_action_token_expiry ON notification_private.device_action_tokens(expires_at);

CREATE FUNCTION notification_private.reminder_window(p_at timestamptz)
RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p notification_private.simple_reminder_policy; local_at timestamp:=p_at AT TIME ZONE 'Asia/Dhaka';
BEGIN
 SELECT * INTO STRICT p FROM notification_private.simple_reminder_policy WHERE singleton;
 IF p.office_start=p.office_end THEN RETURN p_at; END IF;
 IF p.office_start<p.office_end THEN
  IF local_at::time>=p.office_start AND local_at::time<p.office_end THEN RETURN p_at; END IF;
  RETURN ((local_at::date+CASE WHEN local_at::time>=p.office_end THEN 1 ELSE 0 END)+p.office_start) AT TIME ZONE 'Asia/Dhaka';
 END IF;
 IF local_at::time>=p.office_start OR local_at::time<p.office_end THEN RETURN p_at; END IF;
 RETURN (local_at::date+p.office_start) AT TIME ZONE 'Asia/Dhaka';
END $$;
REVOKE ALL ON FUNCTION notification_private.reminder_window(timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION notification_private.todo_followup_allowed(p_todo public.todos,p_recipient uuid,p_now timestamptz)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
BEGIN
 IF p_recipient IS NULL OR NOT notification_private.todo_actionable(p_todo) OR NOT p_todo.reminder_enabled
 OR coalesce(p_todo.assigned_to_user_id,p_todo.owner_user_id) IS DISTINCT FROM p_recipient THEN RETURN false; END IF;
 RETURN NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.entity_type='todo' AND n.entity_id=p_todo.id::text
  AND n.recipient_user_id=p_recipient AND n.status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
  AND (n.read_at IS NULL OR n.snoozed_until>p_now));
END $$;
REVOKE ALL ON FUNCTION notification_private.todo_followup_allowed(public.todos,uuid,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.notification_schedule_todos(p_batch_size integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; recipient uuid; due timestamptz; instant timestamptz:=clock_timestamp();
 identity text; generated int:=0; examined int:=0;
BEGIN
 IF p_batch_size IS NULL OR p_batch_size NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Invalid batch size'; END IF;
 IF NOT pg_try_advisory_xact_lock(73110420261021) THEN RETURN jsonb_build_object('busy',true); END IF;
 IF NOT public.notification_reminder_mode() THEN RETURN jsonb_build_object('enabled',false); END IF;
 IF notification_private.reminder_window(instant)>instant THEN RETURN jsonb_build_object('events_created',0,'outside_office',true); END IF;
 PERFORM set_config('mghrm.scheduler_write','on',true);
 FOR t IN SELECT * FROM public.todos x WHERE x.reminder_enabled AND notification_private.todo_actionable(x)
 AND (x.next_reminder_at IS NULL OR x.next_reminder_at<=instant)
 AND notification_private.todo_followup_allowed(x,coalesce(x.assigned_to_user_id,x.owner_user_id),instant)
 AND NOT EXISTS(SELECT 1 FROM public.notification_events e WHERE e.entity_type='todo' AND e.entity_id=x.id::text AND e.event_type='TodoReminderDue' AND e.processing_status IN ('Pending','Processing','Failed'))
 ORDER BY x.next_reminder_at NULLS FIRST,x.id LIMIT p_batch_size FOR UPDATE SKIP LOCKED LOOP
  examined:=examined+1; recipient:=coalesce(t.assigned_to_user_id,t.owner_user_id);
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=recipient AND is_active)
   OR NOT notification_private.todo_followup_allowed(t,recipient,instant) THEN CONTINUE; END IF;
  IF EXISTS(SELECT 1 FROM public.notification_events e WHERE e.entity_type='todo' AND e.entity_id=t.id::text
   AND e.event_type='TodoReminderDue' AND e.processing_status IN ('Pending','Processing','Failed')) THEN CONTINUE; END IF;
  due:=t.next_reminder_at;
  IF due IS NULL THEN
   due:=notification_private.todo_next(t,instant);
   IF due IS NULL OR due>instant THEN
    UPDATE public.todos SET next_reminder_at=notification_private.reminder_window(due),reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
    CONTINUE;
   END IF;
  END IF;
  IF NOT coalesce((public.notification_effective_preference(recipient,'ToDo')->>'notification_enabled')::boolean,true) THEN CONTINUE; END IF;
  identity:='todo-reminder:'||t.id||':'||extract(epoch FROM due)::text;
  INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
  VALUES('TodoReminderDue','todo',t.id::text,recipient,identity,jsonb_build_object('recipient_user_id',recipient,'category','ToDo',
   'severity','Info','priority','Normal','title','To-Do reminder','message','A scheduled note needs your attention.',
   'action_label','Review note','action_route','todo','dedupe_key',identity,'scheduled_for',instant,
   'action_params',jsonb_build_object('notification_type','todo_rem','todo_id',t.id,'occurrence',identity)),due)
  ON CONFLICT(event_key) DO NOTHING;
  IF FOUND THEN generated:=generated+1; END IF;
  -- The next time is established by a persisted acknowledgement, never by displaying a push.
  UPDATE public.todos SET next_reminder_at=NULL WHERE id=t.id;
 END LOOP;
 PERFORM set_config('mghrm.scheduler_write','off',true);
 RETURN jsonb_build_object('enabled',true,'examined',examined,'events_created',generated);
END $$;
REVOKE ALL ON FUNCTION public.notification_schedule_todos(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_schedule_todos(integer) TO service_role;

CREATE FUNCTION notification_private.simple_ack_schedule()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; due timestamptz;
BEGIN
 IF NEW.entity_type<>'todo' OR NEW.entity_id !~ '^[0-9]{1,18}$' OR NEW.read_at IS NULL
 OR OLD.read_at IS NOT NULL OR NEW.status IN ('Completed','Cancelled','Expired') THEN RETURN NEW; END IF;
 SELECT * INTO t FROM public.todos WHERE id=NEW.entity_id::bigint FOR UPDATE;
 IF NOT FOUND OR NOT t.reminder_enabled OR NOT notification_private.todo_actionable(t)
 OR coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM NEW.recipient_user_id THEN RETURN NEW; END IF;
 t.next_reminder_at:=NEW.read_at;
 due:=notification_private.todo_next(t,NEW.read_at);
 PERFORM set_config('mghrm.scheduler_write','on',true);
 UPDATE public.todos SET next_reminder_at=CASE WHEN due IS NOT NULL THEN notification_private.reminder_window(due) END,
  reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
 PERFORM set_config('mghrm.scheduler_write','off',true);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION notification_private.simple_ack_schedule() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER simple_ack_schedule AFTER UPDATE OF read_at ON public.notifications FOR EACH ROW EXECUTE FUNCTION notification_private.simple_ack_schedule();
DROP TRIGGER IF EXISTS notification_todo_completion_guard ON public.todos;

CREATE FUNCTION notification_private.simple_todo_closed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF notification_private.todo_actionable(NEW) AND NEW.reminder_enabled THEN RETURN NEW; END IF;
 UPDATE public.notifications SET status=CASE WHEN notification_private.todo_actionable(NEW) THEN 'Cancelled' ELSE 'Completed' END,
  completed_at=CASE WHEN NOT notification_private.todo_actionable(NEW) THEN coalesce(completed_at,clock_timestamp()) ELSE completed_at END
 WHERE entity_type='todo' AND entity_id=NEW.id::text AND status NOT IN ('Completed','Cancelled','Expired','Dismissed');
 UPDATE public.notification_jobs SET job_status='Cancelled',locked_at=NULL,locked_by=NULL
 WHERE notification_id IN (SELECT id FROM public.notifications WHERE entity_type='todo' AND entity_id=NEW.id::text)
 AND job_status IN ('Pending','Processing','Failed');
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION notification_private.simple_todo_closed() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER simple_todo_closed AFTER UPDATE OF status,solved_at,deleted_at,reminder_enabled ON public.todos
 FOR EACH ROW EXECUTE FUNCTION notification_private.simple_todo_closed();

-- Preserve unrelated source adapters, retries, privacy and provider result recording.
DO $$ DECLARE body text; BEGIN
 SELECT pg_get_functiondef('public.notification_run_recurrence(integer)'::regprocedure) INTO body;
 body:=replace(body,'and n.parent_notification_id is null', 'and n.parent_notification_id is null and n.entity_type IS DISTINCT FROM ''todo''');
 EXECUTE body;
 SELECT pg_get_functiondef('public.notification_get_web_push_dispatch(bigint,text)'::regprocedure) INTO body;
 body:=replace(body,'or (public.notification_reminder_mode() and', 'or (v_notification.entity_type<>''todo'' and public.notification_reminder_mode() and');
 EXECUTE body;
END $$;
ALTER FUNCTION public.notification_get_web_push_dispatch(bigint,text) RENAME TO notification_dispatch_before_simple;
REVOKE ALL ON FUNCTION public.notification_dispatch_before_simple(bigint,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.notification_get_web_push_dispatch(p_job_id bigint,p_worker_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE n public.notifications; j public.notification_jobs; next_at timestamptz; instant timestamptz:=clock_timestamp();
BEGIN
 SELECT * INTO j FROM public.notification_jobs WHERE id=p_job_id AND job_type='DeliverWebPush' AND job_status='Processing' AND locked_by=p_worker_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Job ownership required'; END IF;
 SELECT * INTO STRICT n FROM public.notifications WHERE id=j.notification_id;
 next_at:=notification_private.reminder_window(instant);
 IF next_at>instant THEN
  UPDATE public.notification_jobs SET job_status='Pending',run_at=next_at,locked_at=NULL,locked_by=NULL,attempt_count=greatest(attempt_count-1,0) WHERE id=j.id;
  RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb);
 END IF;
 IF n.entity_type='todo' AND (n.read_at IS NOT NULL OR NOT EXISTS(SELECT 1 FROM public.todos t WHERE t.id::text=n.entity_id
  AND notification_private.todo_actionable(t) AND t.reminder_enabled AND coalesce(t.assigned_to_user_id,t.owner_user_id)=n.recipient_user_id)) THEN
  UPDATE public.notification_deliveries SET delivery_status='Skipped',provider_status='AcknowledgedOrClosed' WHERE notification_id=n.id AND channel='WebPush' AND delivery_status IN ('Pending','Failed');
 END IF;
 RETURN public.notification_dispatch_before_simple(p_job_id,p_worker_id);
END $$;
REVOKE ALL ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) TO service_role;

CREATE FUNCTION notification_private.simple_notification_action(p_user uuid,p_id uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE n public.notifications; t public.todos; due timestamptz; instant timestamptz:=clock_timestamp();
BEGIN
 IF p_action NOT IN ('read','remind','complete') OR p_action IS NULL THEN RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023'; END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_id AND recipient_user_id=p_user FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_user AND is_active) THEN RAISE EXCEPTION 'Notification access denied' USING ERRCODE='42501'; END IF;
 IF n.entity_type IS DISTINCT FROM 'todo' OR n.entity_id !~ '^[0-9]{1,18}$' THEN RAISE EXCEPTION 'This action requires a To-Do reminder'; END IF;
 SELECT * INTO t FROM public.todos WHERE id=n.entity_id::bigint FOR UPDATE;
 IF NOT FOUND OR t.deleted_at IS NOT NULL OR coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM p_user THEN RAISE EXCEPTION 'Source access denied' USING ERRCODE='42501'; END IF;
 IF p_action='complete' THEN
  UPDATE public.todos SET status=CASE WHEN status IN ('rejected','solved_rejected') THEN 'solved_rejected' WHEN status IN ('approved','solved_approved') THEN 'solved_approved' ELSE 'solved' END,
   solved_at=coalesce(solved_at,instant),reminder_enabled=false,next_reminder_at=NULL WHERE id=t.id;
 ELSIF notification_private.todo_actionable(t) THEN
  -- A topic acknowledged on one device is acknowledged on every device.
  UPDATE public.notifications SET read_at=coalesce(read_at,instant),status='Read',snoozed_until=NULL
   WHERE entity_type='todo' AND entity_id=t.id::text AND recipient_user_id=p_user
    AND status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed');
  IF p_action='remind' AND t.reminder_enabled THEN
   t.next_reminder_at:=instant;due:=notification_private.todo_next(t,instant);
   PERFORM set_config('mghrm.scheduler_write','on',true);
   UPDATE public.todos SET next_reminder_at=CASE WHEN due IS NOT NULL THEN notification_private.reminder_window(due) END,reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
   PERFORM set_config('mghrm.scheduler_write','off',true);
  END IF;
 END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_id;
 SELECT source.* INTO t FROM public.todos source WHERE source.id=t.id;
 RETURN jsonb_build_object('ok',true,'notification',to_jsonb(n),'todo_id',t.id,'todo',to_jsonb(t),'action',p_action);
END $$;
REVOKE ALL ON FUNCTION notification_private.simple_notification_action(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.notification_todo_action(p_notification_id uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 RETURN notification_private.simple_notification_action(auth.uid(),p_notification_id,p_action);
END $$;
REVOKE ALL ON FUNCTION public.notification_todo_action(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_todo_action(uuid,text) TO authenticated;

ALTER FUNCTION public.notification_web_push_preview(bigint,text) RENAME TO notification_preview_before_simple;
REVOKE ALL ON FUNCTION public.notification_preview_before_simple(bigint,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.notification_web_push_preview(p_job_id bigint,p_worker_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE preview jsonb; n public.notifications; token text;
BEGIN
 preview:=public.notification_preview_before_simple(p_job_id,p_worker_id);
 SELECT n1.* INTO n FROM public.notifications n1 JOIN public.notification_jobs j ON j.notification_id=n1.id
 WHERE j.id=p_job_id AND j.locked_by=p_worker_id AND j.job_status='Processing';
 IF n.entity_type='todo' AND n.entity_id ~ '^[0-9]{1,18}$' THEN
  token:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  DELETE FROM notification_private.device_action_tokens WHERE expires_at<clock_timestamp();
  INSERT INTO notification_private.device_action_tokens(token_hash,notification_id,recipient_user_id)
  VALUES(encode(sha256(convert_to(token,'UTF8')),'hex'),n.id,n.recipient_user_id);
  preview:=preview||jsonb_build_object('action_token',token,'task_actions',true);
 END IF;
 RETURN preview;
END $$;
REVOKE ALL ON FUNCTION public.notification_web_push_preview(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_web_push_preview(bigint,text) TO service_role;
CREATE FUNCTION public.notification_device_action(p_token text,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE cap notification_private.device_action_tokens; result jsonb;
BEGIN
 IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Invalid action capability' USING ERRCODE='42501'; END IF;
 SELECT * INTO cap FROM notification_private.device_action_tokens WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') AND expires_at>clock_timestamp();
 IF NOT FOUND THEN RAISE EXCEPTION 'Action capability expired' USING ERRCODE='42501'; END IF;
 result:=notification_private.simple_notification_action(cap.recipient_user_id,cap.notification_id,p_action);
 RETURN jsonb_build_object('ok',true);
END $$;
REVOKE ALL ON FUNCTION public.notification_device_action(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_device_action(text,text) TO service_role;

CREATE FUNCTION public.notification_simple_settings_read()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p notification_private.simple_reminder_policy; pref jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO STRICT p FROM notification_private.simple_reminder_policy WHERE singleton;
 pref:=public.notification_effective_preference(auth.uid(),'*');
 RETURN jsonb_build_object('revision',p.revision,'office_start',to_char(p.office_start,'HH24:MI'),'office_end',to_char(p.office_end,'HH24:MI'),'preferences',pref);
END $$;
CREATE FUNCTION public.notification_simple_settings_save(p_expected_revision bigint,p_changes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p notification_private.simple_reminder_policy; key text; start_at time; end_at time;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO STRICT p FROM notification_private.simple_reminder_policy WHERE singleton FOR UPDATE;
 IF p_expected_revision IS DISTINCT FROM p.revision THEN RAISE EXCEPTION 'Settings changed on another device; reload' USING ERRCODE='40001'; END IF;
 IF jsonb_typeof(p_changes) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid settings'; END IF;
 FOR key IN SELECT jsonb_object_keys(p_changes) LOOP
  IF key NOT IN ('office_start','office_end','notification_enabled','system_push_enabled','toast_enabled','show_content_preview') THEN RAISE EXCEPTION 'Unsupported setting'; END IF;
 END LOOP;
 IF (p_changes ? 'office_start' AND (p_changes->>'office_start') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
 OR (p_changes ? 'office_end' AND (p_changes->>'office_end') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN RAISE EXCEPTION 'Invalid office time'; END IF;
 start_at:=coalesce((p_changes->>'office_start')::time,p.office_start);end_at:=coalesce((p_changes->>'office_end')::time,p.office_end);
 UPDATE notification_private.simple_reminder_policy SET office_start=start_at,office_end=end_at,revision=revision+1 WHERE singleton;
 INSERT INTO public.notification_preferences(user_id,category) VALUES(auth.uid(),'*') ON CONFLICT(user_id,category) DO NOTHING;
 UPDATE public.notification_preferences SET
  notification_enabled=coalesce((p_changes->>'notification_enabled')::boolean,notification_enabled),
  system_push_enabled=coalesce((p_changes->>'system_push_enabled')::boolean,system_push_enabled),
  toast_enabled=coalesce((p_changes->>'toast_enabled')::boolean,toast_enabled),
  show_content_preview=coalesce((p_changes->>'show_content_preview')::boolean,show_content_preview),
  quiet_hours_enabled=false,minimum_priority='Low',in_app_enabled=true
 WHERE user_id=auth.uid() AND category='*';
 RETURN public.notification_simple_settings_read();
END $$;
REVOKE ALL ON FUNCTION public.notification_simple_settings_read(),public.notification_simple_settings_save(bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_simple_settings_read(),public.notification_simple_settings_save(bigint,jsonb) TO authenticated;

-- Retire the competing governance/digest producer. Keep old data and functions for audit.
DO $$ BEGIN
 IF to_regclass('notification_private.governance_control') IS NOT NULL THEN EXECUTE 'UPDATE notification_private.governance_control SET enabled=false WHERE singleton'; END IF;
 IF to_regclass('notification_private.digest_bridge_control') IS NOT NULL THEN EXECUTE 'UPDATE notification_private.digest_bridge_control SET enabled=false WHERE singleton'; END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
