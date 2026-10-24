-- One server-owned schedule: requested interval, effective notification window, unread gate.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
ALTER TABLE public.todos ADD COLUMN reminder_due_at timestamptz;
COMMENT ON COLUMN public.todos.reminder_due_at IS 'Natural next occurrence before notification-hour clamping; maintained by the reminder engine.';

-- One visible settings panel is authoritative; obsolete category/quiet-hour overrides cannot contradict it.
CREATE OR REPLACE FUNCTION public.notification_effective_preference(p_user_id uuid,p_category text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p public.notification_preferences;
BEGIN
 IF p_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_user_id AND is_active) THEN RAISE EXCEPTION 'Active notification recipient required'; END IF;
 SELECT * INTO p FROM public.notification_preferences WHERE user_id=p_user_id AND category='*';
 RETURN jsonb_build_object('source_category',coalesce(p.category,'system-default'),
  'notification_enabled',coalesce(p.notification_enabled,true),'system_push_enabled',coalesce(p.system_push_enabled,true),
  'in_app_enabled',true,'toast_enabled',coalesce(p.toast_enabled,true),'show_content_preview',coalesce(p.show_content_preview,true),
  'minimum_priority','Low','quiet_hours_enabled',false,'quiet_hours_start','22:00','quiet_hours_end','07:00',
  'urgent_bypass_enabled',false,'timezone','Asia/Dhaka','default_snooze_minutes',coalesce(p.default_snooze_minutes,15),
  'toast_max_visible',coalesce(p.toast_max_visible,2),'toast_gap_seconds',coalesce(p.toast_gap_seconds,60));
END $$;

CREATE FUNCTION notification_private.effective_reminder_due(t public.todos,p_due timestamptz,p_now timestamptz)
RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE candidate timestamptz; tmp public.todos:=t; i integer;
BEGIN
 IF p_due IS NULL OR NOT notification_private.todo_actionable(t) OR NOT t.reminder_enabled
  OR NOT coalesce((public.notification_effective_preference(coalesce(t.assigned_to_user_id,t.owner_user_id),'ToDo')->>'notification_enabled')::boolean,true)
  OR NOT notification_private.todo_followup_allowed(t,coalesce(t.assigned_to_user_id,t.owner_user_id),p_now) THEN RETURN NULL; END IF;
 candidate:=notification_private.reminder_window(greatest(p_due,p_now));
 IF t.reminder_type='custom' THEN
  tmp.next_reminder_at:=NULL;
  FOR i IN 1..40 LOOP
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.reminder_dates)='array' THEN t.reminder_dates ELSE '[]'::jsonb END) d
    WHERE coalesce(d->>'date',d#>>'{}')=(candidate AT TIME ZONE coalesce(t.reminder_timezone,'Asia/Dhaka'))::date::text) THEN RETURN candidate; END IF;
   candidate:=notification_private.todo_next(tmp,candidate-interval '1 microsecond');
   IF candidate IS NULL THEN RETURN NULL; END IF;
   candidate:=notification_private.reminder_window(candidate);
  END LOOP;
  RETURN NULL;
 END IF;
 RETURN candidate;
END $$;
REVOKE ALL ON FUNCTION notification_private.effective_reminder_due(public.todos,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- Backfill from the last acknowledgement only if the schedule was not edited afterwards.
DO $$ DECLARE t public.todos; ack timestamptz; raw_due timestamptz; BEGIN
 PERFORM set_config('mghrm.scheduler_write','on',true);
 FOR t IN SELECT * FROM public.todos WHERE reminder_enabled AND notification_private.todo_actionable(todos) FOR UPDATE LOOP
  raw_due:=t.next_reminder_at;
  SELECT max(read_at) INTO ack FROM public.notifications WHERE recipient_user_id=coalesce(t.assigned_to_user_id,t.owner_user_id) AND entity_type='todo' AND entity_id=t.id::text;
  IF ack IS NOT NULL AND t.updated_at<=ack+interval '1 second' THEN
   t.next_reminder_at:=ack;raw_due:=notification_private.todo_next(t,ack);
  END IF;
  UPDATE public.todos SET reminder_due_at=raw_due WHERE id=t.id;
 END LOOP;
 PERFORM set_config('mghrm.scheduler_write','off',true);
END $$;

CREATE FUNCTION notification_private.guard_reminder_clock()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE tmp public.todos; changed boolean; instant timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.notification_reminder_mode() OR current_setting('mghrm.scheduler_write',true)='on' THEN RETURN NEW; END IF;
 IF NOT NEW.reminder_enabled OR NOT notification_private.todo_actionable(NEW) THEN NEW.next_reminder_at:=NULL;NEW.reminder_due_at:=NULL;RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND OLD.reminder_type='once' AND NEW.reminder_type='once' AND NOT OLD.reminder_enabled AND NEW.reminder_enabled AND NEW.next_reminder_at IS NULL THEN NEW.reminder_enabled:=false;NEW.reminder_due_at:=NULL;NEW.next_reminder_at:=NULL;RETURN NEW; END IF;
 IF TG_OP='INSERT' THEN
  tmp:=NEW;tmp.next_reminder_at:=NULL;
  NEW.reminder_due_at:=coalesce(NEW.next_reminder_at,notification_private.todo_next(tmp,instant));
 ELSE
  changed:=ROW(NEW.reminder_enabled,NEW.reminder_type,NEW.reminder_interval,NEW.reminder_dates,NEW.reminder_timezone,NEW.owner_user_id,NEW.assigned_to_user_id)
   IS DISTINCT FROM ROW(OLD.reminder_enabled,OLD.reminder_type,OLD.reminder_interval,OLD.reminder_dates,OLD.reminder_timezone,OLD.owner_user_id,OLD.assigned_to_user_id);
  IF NOT changed THEN
   -- Old clients/autosave cannot replace the server clock with a device-computed time.
   NEW.reminder_due_at:=OLD.reminder_due_at;NEW.next_reminder_at:=OLD.next_reminder_at;RETURN NEW;
  END IF;
  tmp:=NEW;tmp.next_reminder_at:=NULL;
  NEW.reminder_due_at:=notification_private.todo_next(tmp,instant);
 END IF;
 IF NOT notification_private.todo_followup_allowed(NEW,coalesce(NEW.assigned_to_user_id,NEW.owner_user_id),instant) THEN NEW.reminder_due_at:=NULL; END IF;
 NEW.next_reminder_at:=notification_private.effective_reminder_due(NEW,NEW.reminder_due_at,instant);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION notification_private.guard_reminder_clock() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER notification_server_clock BEFORE INSERT OR UPDATE ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.guard_reminder_clock();

CREATE FUNCTION notification_private.reconcile_reminder_clocks(p_user uuid,p_now timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; raw_due timestamptz; due timestamptz; prior text:=current_setting('mghrm.scheduler_write',true);
BEGIN
 PERFORM set_config('mghrm.scheduler_write','on',true);
 FOR t IN SELECT * FROM public.todos x WHERE x.reminder_enabled AND notification_private.todo_actionable(x)
  AND (p_user IS NULL OR coalesce(x.assigned_to_user_id,x.owner_user_id)=p_user) FOR UPDATE LOOP
  raw_due:=t.reminder_due_at;
  IF NOT notification_private.todo_followup_allowed(t,coalesce(t.assigned_to_user_id,t.owner_user_id),p_now) THEN raw_due:=NULL;
  ELSIF EXISTS(SELECT 1 FROM public.notification_events e WHERE e.entity_type='todo' AND e.entity_id=t.id::text
    AND e.event_type='TodoReminderDue' AND e.processing_status IN ('Pending','Processing','Failed')) THEN CONTINUE;
  ELSIF raw_due IS NULL THEN t.next_reminder_at:=NULL;raw_due:=notification_private.todo_next(t,p_now);
  END IF;
  due:=notification_private.effective_reminder_due(t,raw_due,p_now);
  UPDATE public.todos SET reminder_due_at=raw_due,next_reminder_at=due WHERE id=t.id
   AND ROW(reminder_due_at,next_reminder_at) IS DISTINCT FROM ROW(raw_due,due);
 END LOOP;
 PERFORM set_config('mghrm.scheduler_write',coalesce(prior,'off'),true);
END $$;
REVOKE ALL ON FUNCTION notification_private.reconcile_reminder_clocks(uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION notification_private.simple_ack_schedule()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; due timestamptz; prior text:=current_setting('mghrm.scheduler_write',true);
BEGIN
 IF NEW.entity_type<>'todo' OR NEW.entity_id !~ '^[0-9]{1,18}$' OR NEW.read_at IS NULL
  OR OLD.read_at IS NOT NULL OR NEW.status IN ('Completed','Cancelled','Expired') THEN RETURN NEW; END IF;
 SELECT * INTO t FROM public.todos WHERE id=NEW.entity_id::bigint FOR UPDATE;
 IF NOT FOUND OR NOT t.reminder_enabled OR NOT notification_private.todo_actionable(t)
  OR coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM NEW.recipient_user_id THEN RETURN NEW; END IF;
 t.next_reminder_at:=NEW.read_at;due:=notification_private.todo_next(t,NEW.read_at);
 PERFORM set_config('mghrm.scheduler_write','on',true);
 UPDATE public.todos SET reminder_due_at=due,next_reminder_at=notification_private.effective_reminder_due(t,due,NEW.read_at),
  reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
 PERFORM set_config('mghrm.scheduler_write',coalesce(prior,'off'),true);
 RETURN NEW;
END $$;

DO $$ DECLARE body text; BEGIN
 SELECT pg_get_functiondef('public.notification_schedule_todos(integer)'::regprocedure) INTO body;
 body:=replace(body,'IF notification_private.reminder_window(instant)>instant THEN',
  'PERFORM notification_private.reconcile_reminder_clocks(NULL,instant); IF notification_private.reminder_window(instant)>instant THEN');
 body:=replace(body,'WHERE x.reminder_enabled AND notification_private.todo_actionable(x)', 'WHERE x.reminder_enabled AND coalesce((public.notification_effective_preference(coalesce(x.assigned_to_user_id,x.owner_user_id),''ToDo'')->>''notification_enabled'')::boolean,true) AND notification_private.todo_actionable(x)');
 body:=replace(body,'SET next_reminder_at=NULL WHERE id=t.id','SET next_reminder_at=NULL,reminder_due_at=NULL WHERE id=t.id');
 EXECUTE body;
 SELECT pg_get_functiondef('notification_private.simple_notification_action(uuid,uuid,text)'::regprocedure) INTO body;
 body:=replace(body,'SET next_reminder_at=CASE WHEN due IS NOT NULL THEN notification_private.reminder_window(due) END',
  'SET reminder_due_at=due,next_reminder_at=notification_private.effective_reminder_due(t,due,instant)');
 EXECUTE body;
 SELECT pg_get_functiondef('public.notification_prepare_deliveries(integer)'::regprocedure) INTO body;
 body:=replace(body,'where n.status = ''Ready''','where n.status = ''Ready'' AND coalesce((public.notification_effective_preference(n.recipient_user_id,n.category)->>''notification_enabled'')::boolean,true)');
 EXECUTE body;
 SELECT pg_get_functiondef('notification_private.todo_schedule_changed()'::regprocedure) INTO body;
 body:=replace(body,
  'ROW(NEW.reminder_enabled,NEW.reminder_type,NEW.reminder_interval,NEW.reminder_dates,NEW.next_reminder_at,NEW.reminder_timezone,NEW.assigned_to_user_id,NEW.owner_user_id)
   IS DISTINCT FROM ROW(OLD.reminder_enabled,OLD.reminder_type,OLD.reminder_interval,OLD.reminder_dates,OLD.next_reminder_at,OLD.reminder_timezone,OLD.assigned_to_user_id,OLD.owner_user_id)',
  'NOT NEW.reminder_enabled OR ROW(NEW.assigned_to_user_id,NEW.owner_user_id) IS DISTINCT FROM ROW(OLD.assigned_to_user_id,OLD.owner_user_id)');
 EXECUTE body;
 -- Disabled delivery is deferred, not permanently discarded. Re-enable releases the same occurrence.
 SELECT pg_get_functiondef('public.notification_get_web_push_dispatch(bigint,text)'::regprocedure) INTO body;
 body:=replace(body,'next_at:=notification_private.reminder_window(instant);',
  'IF NOT coalesce((public.notification_effective_preference(n.recipient_user_id,n.category)->>''notification_enabled'')::boolean,true) OR NOT coalesce((public.notification_effective_preference(n.recipient_user_id,n.category)->>''system_push_enabled'')::boolean,true) THEN
   UPDATE public.notification_jobs SET job_status=''Pending'',run_at=instant+interval ''5 minutes'',locked_at=NULL,locked_by=NULL,attempt_count=greatest(attempt_count-1,0) WHERE id=j.id;
   RETURN jsonb_build_object(''deferred'',true,''deliveries'',''[]''::jsonb); END IF;
   next_at:=notification_private.reminder_window(instant);');
 EXECUTE body;
END $$;

CREATE OR REPLACE FUNCTION public.notification_simple_settings_save(p_expected_revision bigint,p_changes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE saved jsonb; instant timestamptz:=clock_timestamp();
BEGIN
 -- The original atomic validator retains revision checks and the allowlist.
 saved:=public.notification_simple_settings_save_before_rebase(p_expected_revision,p_changes);
 PERFORM notification_private.reconcile_reminder_clocks(auth.uid(),instant);
 UPDATE public.notification_jobs j SET run_at=notification_private.reminder_window(instant)
  FROM public.notifications n WHERE n.id=j.notification_id AND n.recipient_user_id=auth.uid()
   AND j.job_type='DeliverWebPush' AND j.job_status IN ('Pending','Failed');
 PERFORM public.notification_schedule_todos(100);
 RETURN public.notification_simple_settings_read();
END $$;

CREATE FUNCTION public.notification_reminder_state()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE prefs jsonb; rows jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 prefs:=public.notification_simple_settings_read();
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'next_reminder_at',t.next_reminder_at,'reminder_enabled',t.reminder_enabled,
  'state',CASE WHEN NOT t.reminder_enabled THEN 'off'
   WHEN NOT coalesce((prefs->'preferences'->>'notification_enabled')::boolean,true) THEN 'paused'
   WHEN NOT notification_private.todo_followup_allowed(t,auth.uid(),now()) THEN 'unseen'
   WHEN t.next_reminder_at IS NULL THEN 'queued' ELSE 'scheduled' END)),'[]'::jsonb) INTO rows
 FROM public.todos t WHERE coalesce(t.assigned_to_user_id,t.owner_user_id)=auth.uid() AND notification_private.todo_actionable(t);
 RETURN jsonb_build_object('settings',prefs,'todos',rows,'server_time',clock_timestamp());
END $$;
REVOKE ALL ON FUNCTION public.notification_reminder_state() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_reminder_state() TO authenticated;
SELECT notification_private.reconcile_reminder_clocks(NULL,clock_timestamp());
NOTIFY pgrst,'reload schema';
COMMIT;
