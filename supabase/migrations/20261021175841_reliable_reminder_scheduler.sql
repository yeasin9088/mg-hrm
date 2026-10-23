-- Pending rollout. See docs/reminder-rollout.md; owner-authorized rollout; see dated recovery-risk waiver.
-- Additive infrastructure; activation is a separate, explicit service-only transaction.
BEGIN;
CREATE SCHEMA IF NOT EXISTS notification_private;
REVOKE ALL ON SCHEMA notification_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS notification_private.reminder_control (
 singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
 server_authoritative boolean NOT NULL DEFAULT false
);
INSERT INTO notification_private.reminder_control(singleton) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE notification_private.reminder_control ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.reminder_control FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS notification_private.foreground_sessions (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 auth_session_id uuid NOT NULL,
 tab_id uuid NOT NULL,
 device_id uuid NOT NULL,
 foreground boolean NOT NULL,
 last_seen_at timestamptz NOT NULL,
 last_active_at timestamptz NOT NULL,
 PRIMARY KEY(user_id,auth_session_id,tab_id)
);
ALTER TABLE notification_private.foreground_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.foreground_sessions FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS foreground_sessions_expiry_idx ON notification_private.foreground_sessions(last_seen_at);
ALTER TABLE public.todos ADD COLUMN IF NOT EXISTS reminder_timezone text NOT NULL DEFAULT 'Asia/Dhaka';
CREATE INDEX IF NOT EXISTS todos_reminder_due_idx ON public.todos(next_reminder_at,id) WHERE reminder_enabled AND deleted_at IS NULL AND solved_at IS NULL;

CREATE OR REPLACE FUNCTION public.notification_reminder_mode()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $$ SELECT coalesce((SELECT server_authoritative FROM notification_private.reminder_control WHERE singleton),false) $$;
REVOKE ALL ON FUNCTION public.notification_reminder_mode() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_reminder_mode() TO authenticated,service_role;

-- No caller-supplied user or timestamps. Auth session is taken from the signed JWT.
CREATE OR REPLACE FUNCTION public.notification_presence_heartbeat(p_tab_id uuid,p_device_id uuid,p_visible boolean,p_focused boolean,p_recent_activity boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE uid uuid:=auth.uid(); sid uuid:=nullif(auth.jwt()->>'session_id','')::uuid;
BEGIN
 IF uid IS NULL OR sid IS NULL OR p_tab_id IS NULL OR p_device_id IS NULL
    OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=uid AND is_active)
    OR NOT EXISTS(SELECT 1 FROM auth.sessions WHERE id=sid AND user_id=uid AND (not_after IS NULL OR not_after>clock_timestamp())) THEN
  RAISE EXCEPTION 'Authenticated active session required' USING ERRCODE='42501';
 END IF;
 INSERT INTO notification_private.foreground_sessions VALUES(uid,sid,p_tab_id,p_device_id,
   coalesce(p_visible AND p_focused AND p_recent_activity,false),clock_timestamp(),
   CASE WHEN p_recent_activity THEN clock_timestamp() ELSE '-infinity'::timestamptz END)
 ON CONFLICT(user_id,auth_session_id,tab_id) DO UPDATE SET
   foreground=EXCLUDED.foreground,device_id=EXCLUDED.device_id,last_seen_at=EXCLUDED.last_seen_at,
   last_active_at=CASE WHEN p_recent_activity THEN EXCLUDED.last_active_at ELSE foreground_sessions.last_active_at END;
END $$;
REVOKE ALL ON FUNCTION public.notification_presence_heartbeat(uuid,uuid,boolean,boolean,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_presence_heartbeat(uuid,uuid,boolean,boolean,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION notification_private.has_foreground(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM notification_private.foreground_sessions s
 JOIN auth.sessions a ON a.id=s.auth_session_id AND a.user_id=s.user_id AND (a.not_after IS NULL OR a.not_after>statement_timestamp())
 JOIN public.profiles p ON p.id=s.user_id AND p.is_active
 WHERE s.user_id=p_user AND s.foreground AND s.last_seen_at>statement_timestamp()-interval '75 seconds'
 AND s.last_active_at>statement_timestamp()-interval '2 minutes')
$$;
REVOKE ALL ON FUNCTION notification_private.has_foreground(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION notification_private.todo_actionable(t public.todos)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT t.deleted_at IS NULL AND t.solved_at IS NULL
 AND lower(btrim(coalesce(t.status,''))) NOT IN ('done','complete','completed','closed','resolved','cancelled','canceled','solved','solved_approved','solved_rejected')
 AND lower(btrim(coalesce(t.manager_status,''))) NOT IN ('done','complete','completed','closed','resolved','cancelled','canceled','solved','solved_approved','solved_rejected')
$$;
REVOKE ALL ON FUNCTION notification_private.todo_actionable(public.todos) FROM PUBLIC,anon,authenticated;

-- Strictly after p_after, unless preserving a saved future due/snooze.
-- Missing interval falls back to the existing type defaults. Legacy `today` remains daily.
CREATE OR REPLACE FUNCTION notification_private.todo_next(t public.todos,p_after timestamptz)
RETURNS timestamptz LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE kind text:=coalesce(t.reminder_type,'1h'); step_minutes int;
 anchor timestamptz:=t.next_reminder_at; slot timestamptz; best timestamptz;
 entry jsonb; day_start timestamptz; day_end timestamptz; date_text text; zone text:=t.reminder_timezone;
BEGIN
 IF NOT t.reminder_enabled OR NOT notification_private.todo_actionable(t) THEN RETURN NULL; END IF;
 IF anchor>p_after THEN RETURN anchor; END IF;
 IF kind='once' THEN
   IF anchor IS NULL THEN RETURN p_after; ELSE RETURN NULL; END IF;
 END IF;
 step_minutes:=greatest(5,least(1440,coalesce(nullif(t.reminder_interval,0),CASE kind WHEN '30m' THEN 30 WHEN '2h' THEN 120 WHEN 'today' THEN 1440 ELSE 60 END)));
 IF kind='custom' THEN
   IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=zone) THEN zone:='Asia/Dhaka'; END IF;
   FOR entry IN SELECT value FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.reminder_dates)='array' THEN t.reminder_dates ELSE '[]'::jsonb END) LIMIT 20 LOOP
     date_text:=CASE WHEN jsonb_typeof(entry)='object' THEN entry->>'date' ELSE entry#>>'{}' END;
     BEGIN
       IF date_text !~ '^\d{4}-\d{2}-\d{2}$' THEN CONTINUE; END IF;
       day_start:=date_text::date::timestamp AT TIME ZONE zone;
       day_end:=(date_text::date+1)::timestamp AT TIME ZONE zone;
       IF jsonb_typeof(entry)='object' AND entry->>'interval' ~ '^\d{1,5}$' THEN
         step_minutes:=greatest(5,least(1440,(entry->>'interval')::int));
       ELSE
         step_minutes:=greatest(5,least(1440,coalesce(t.reminder_interval,60)));
       END IF;
       slot:=CASE WHEN p_after<day_start THEN day_start ELSE day_start+(floor(extract(epoch FROM(p_after-day_start))/(step_minutes*60))+1)*make_interval(mins=>step_minutes) END;
       IF slot<day_end AND (best IS NULL OR slot<best) THEN best:=slot; END IF;
     EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN CONTINUE;
     END;
   END LOOP;
   RETURN best;
 END IF;
 IF kind='today' THEN step_minutes:=1440; END IF;
 IF anchor IS NULL THEN
   RETURN CASE WHEN kind='today' THEN p_after ELSE p_after+make_interval(mins=>step_minutes) END;
 END IF;
 RETURN anchor+(floor(extract(epoch FROM(p_after-anchor))/(step_minutes*60))+1)*make_interval(mins=>step_minutes);
END $$;
REVOKE ALL ON FUNCTION notification_private.todo_next(public.todos,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.notification_schedule_todos(p_batch_size integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.todos; recipient uuid; due timestamptz; next_at timestamptz;
 instant timestamptz:=clock_timestamp(); identity text; generated int:=0; examined int:=0;
BEGIN
 IF p_batch_size NOT BETWEEN 1 AND 500 OR p_batch_size IS NULL THEN RAISE EXCEPTION 'Invalid batch size'; END IF;
 -- Same transaction lock as the legacy claim; switch cannot race either producer.
 IF NOT pg_try_advisory_xact_lock(73110420261021) THEN RETURN jsonb_build_object('busy',true); END IF;
 IF NOT public.notification_reminder_mode() THEN RETURN jsonb_build_object('enabled',false); END IF;
 PERFORM set_config('mghrm.scheduler_write','on',true);
 DELETE FROM notification_private.foreground_sessions WHERE last_seen_at<instant-interval '1 day';
 FOR t IN SELECT * FROM public.todos x WHERE x.reminder_enabled
 AND (x.next_reminder_at IS NULL OR x.next_reminder_at<=instant)
 AND notification_private.todo_actionable(x)
 AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=coalesce(x.assigned_to_user_id,x.owner_user_id) AND p.is_active)
 ORDER BY x.next_reminder_at NULLS FIRST,x.id LIMIT p_batch_size FOR UPDATE SKIP LOCKED LOOP
   examined:=examined+1;
   recipient:=coalesce(t.assigned_to_user_id,t.owner_user_id);
   IF recipient IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=recipient AND is_active) THEN CONTINUE; END IF;
   due:=t.next_reminder_at;
   IF due IS NULL THEN
     due:=notification_private.todo_next(t,instant);
     IF due IS NULL OR due>instant THEN
       UPDATE public.todos SET next_reminder_at=due,reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
       CONTINUE;
     END IF;
   END IF;
   -- Coalesce missed cycles into one occurrence, then jump strictly into the future.
   t.next_reminder_at:=due;
   next_at:=notification_private.todo_next(t,instant);
   identity:='todo-reminder:'||t.id||':'||extract(epoch FROM due)::text;
   -- A snoozed/quiet-hours occurrence already represents this actionable source.
   IF NOT EXISTS(SELECT 1 FROM public.notification_events e WHERE e.entity_type='todo' AND e.entity_id=t.id::text AND e.event_type='TodoReminderDue' AND e.processing_status IN ('Pending','Failed'))
      AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.entity_type='todo' AND n.entity_id=t.id::text
       AND n.recipient_user_id=recipient AND ((n.status IN ('Scheduled','Snoozed') AND n.scheduled_for>instant)
         OR EXISTS(SELECT 1 FROM public.notification_jobs j WHERE j.notification_id=n.id AND j.job_type='DeliverWebPush' AND j.job_status IN ('Pending','Processing','Failed'))))
      AND coalesce((public.notification_effective_preference(recipient,'ToDo')->>'notification_enabled')::boolean,true) THEN
     INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
     VALUES('TodoReminderDue','todo',t.id::text,recipient,identity,
       jsonb_build_object('recipient_user_id',recipient,'category','ToDo','severity','Info','priority','Normal',
         'title','To-Do reminder','message','A scheduled note needs your attention. Open MG-HRM to review it.',
         'action_label','Review note','action_route','todo','dedupe_key',identity,'scheduled_for',instant,
         'action_params',jsonb_build_object('notification_type','todo_rem','todo_id',t.id,'occurrence',identity)),due)
     ON CONFLICT(event_key) DO NOTHING;
     IF FOUND THEN generated:=generated+1; END IF;
   END IF;
   UPDATE public.todos SET next_reminder_at=next_at,reminder_enabled=(next_at IS NOT NULL) WHERE id=t.id;
 END LOOP;
 PERFORM set_config('mghrm.scheduler_write','off',true);
 RETURN jsonb_build_object('enabled',true,'examined',examined,'events_created',generated,'at',instant);
END $$;
REVOKE ALL ON FUNCTION public.notification_schedule_todos(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_schedule_todos(integer) TO service_role;

-- Keep the legacy RPC contract, but atomically fence browser producers at cutover.
CREATE OR REPLACE FUNCTION public.notification_claim_todo_reminder(p_todo_id bigint, p_expected_next timestamp with time zone, p_next timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE t public.todos%ROWTYPE; recipient uuid := auth.uid(); due timestamptz; event_identity text;
BEGIN
  PERFORM pg_advisory_xact_lock(73110420261021);
  IF public.notification_reminder_mode() THEN RETURN jsonb_build_object('claimed',false,'producer','server'); END IF;
  IF recipient IS NULL OR public.my_role() NOT IN ('admin','editor') THEN
    RAISE EXCEPTION 'Active operator permission required' USING ERRCODE='42501';
  END IF;
  IF p_next IS NOT NULL AND (p_next <= clock_timestamp() OR p_next > clock_timestamp() + interval '10 years') THEN
    RAISE EXCEPTION 'Invalid next reminder time' USING ERRCODE='22023';
  END IF;
  SELECT * INTO t FROM public.todos WHERE id=p_todo_id FOR UPDATE;
  IF NOT FOUND OR coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM recipient OR t.deleted_at IS NOT NULL OR t.reminder_enabled IS DISTINCT FROM true OR t.solved_at IS NOT NULL OR
     lower(coalesce(t.status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     lower(coalesce(t.manager_status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     t.next_reminder_at IS DISTINCT FROM p_expected_next OR
     (t.next_reminder_at IS NOT NULL AND t.next_reminder_at > clock_timestamp()) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  IF NOT coalesce((public.notification_effective_preference(recipient,'ToDo')->>'notification_enabled')::boolean,true) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  due := coalesce(t.next_reminder_at,date_trunc('minute',clock_timestamp()));
  event_identity := 'todo-reminder:' || t.id::text || ':' || extract(epoch FROM due)::text;
  INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
  VALUES ('TodoReminderDue','todo',t.id::text,recipient,event_identity,
    jsonb_build_object('recipient_user_id',recipient,'category','ToDo','severity','Info','priority','Normal',
      'title','To-Do reminder','message','A scheduled note needs your attention. Open MG-HRM to review it.',
      'action_label','Review note','action_route','todo','dedupe_key',event_identity,
      'action_params',jsonb_build_object('notification_type','todo_rem'),'scheduled_for',due),due)
  ON CONFLICT (event_key) DO NOTHING;
  UPDATE public.todos SET next_reminder_at=p_next,
    reminder_enabled=CASE WHEN p_next IS NULL THEN false ELSE reminder_enabled END WHERE id=t.id;
  RETURN jsonb_build_object('claimed',true,'event_key',event_identity,'occurred_at',due);
END;
$function$;

-- Match the source terminal states used by the authoritative scheduler.
CREATE OR REPLACE FUNCTION public.notification_check_core_source(p_entity_type text, p_entity_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  v_resolved boolean;
  v_state text;
begin
  if p_entity_id is null then
    raise exception using
      errcode = '22023',
      message = 'Entity ID is required';
  end if;

  if lower(btrim(coalesce(p_entity_type, ''))) = 'todo' then

    select
      NOT notification_private.todo_actionable(t),
      coalesce(t.status, '[blank]')
    into
      v_resolved,
      v_state
    from public.todos t
    where t.id = p_entity_id;

  elsif lower(btrim(coalesce(p_entity_type, ''))) =
    'transfer' then

    select
      t.status in (
        'Completed',
        'Cancelled'
      ),
      t.status
    into
      v_resolved,
      v_state
    from public.transfers t
    where t.id = p_entity_id
      and t.deleted_at is null;

  elsif lower(btrim(coalesce(p_entity_type, ''))) =
    'exit' then

    select
      e.status in (
        'Completed',
        'Cancelled'
      ),
      e.status
    into
      v_resolved,
      v_state
    from public.exits e
    where e.id = p_entity_id
      and e.deleted_at is null;

  else
    raise exception using
      errcode = '22023',
      message = 'Unsupported core source type';
  end if;

  if v_state is null then
    raise exception using
      errcode = 'P0002',
      message = 'Source workflow record not found';
  end if;

  return jsonb_build_object(
    'entity_type',
    lower(btrim(p_entity_type)),
    'entity_id',
    p_entity_id,
    'resolved',
    coalesce(v_resolved, false),
    'state',
    v_state
  );
end;
$function$;

-- Reuse the already scheduled processor; no second Cron is installed.
CREATE OR REPLACE FUNCTION public.notification_cron_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_lock_key constant bigint := 73110420261011;
  v_result jsonb;
begin
  if not pg_try_advisory_xact_lock(v_lock_key) then
    return jsonb_build_object(
      'status', 'Skipped',
      'reason', 'Another processor run is active',
      'finished_at', clock_timestamp()
    );
  end if;

  perform public.notification_schedule_todos(100);

  v_result :=
    public.notification_run_server_processor(
      'cron:notification-server-processor',
      25,
      interval '15 minutes'
    );

  return jsonb_build_object(
    'status', 'Completed',
    'processor', v_result,
    'finished_at', clock_timestamp()
  );

exception
  when others then
    raise warning
      'Notification processor Cron tick failed: %',
      sqlerrm;

    return jsonb_build_object(
      'status', 'Failed',
      'error', left(sqlerrm, 4000),
      'finished_at', clock_timestamp()
    );
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_get_web_push_dispatch(p_job_id bigint, p_worker_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_notification public.notifications%rowtype;
  v_deliveries jsonb;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  select job_row.*
  into v_job
  from public.notification_jobs job_row
  where job_row.id = p_job_id
    and job_row.job_type =
      'DeliverWebPush'
    and job_row.job_status =
      'Processing'
    and job_row.locked_by =
      btrim(p_worker_id);

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select notification_row.*
  into v_notification
  from public.notifications notification_row
  where notification_row.id =
    v_job.notification_id;

  if not found then
    raise exception
      'Notification for Web Push job % was not found',
      p_job_id;
  end if;

  -- A snooze or quiet-hour change can happen after the worker claimed this job.
  -- Defer without consuming a send attempt or permanently skipping a later alert.
  if v_notification.scheduled_for>clock_timestamp() then
    update public.notification_jobs set job_status='Pending',run_at=v_notification.scheduled_for,
      attempt_count=greatest(0,attempt_count-1),locked_at=null,locked_by=null
      where id=v_job.id and locked_by=btrim(p_worker_id);
    return jsonb_build_object('deferred',true,'deliveries','[]'::jsonb);
  end if;

  -- Recheck immediately before dispatch, including source, preferences and live presence.
  update public.notification_deliveries d set delivery_status='Skipped',
    provider_status='DispatchIneligible',response_metadata=d.response_metadata||jsonb_build_object('checked_at',clock_timestamp())
  where d.notification_id=v_notification.id and d.channel='WebPush' and d.delivery_status in ('Pending','Failed')
  and (
    v_notification.status in ('Completed','Cancelled','Expired','Dismissed')
    or (v_notification.expires_at is not null and v_notification.expires_at<=clock_timestamp())
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'notification_enabled')::boolean,true)
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'system_push_enabled')::boolean,true)
    or (v_notification.entity_type='todo' and not exists(select 1 from public.todos t where t.id::text=v_notification.entity_id and notification_private.todo_actionable(t)))
    or (public.notification_reminder_mode() and coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'in_app_enabled')::boolean,true) and notification_private.has_foreground(v_notification.recipient_user_id))
    or not exists(select 1 from public.push_subscriptions s where s.id=d.subscription_id and s.user_id=v_notification.recipient_user_id and s.is_active and s.permission_state='granted' and s.revoked_at is null)
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'delivery_id',
          delivery_row.id,
        'subscription_id',
          subscription_row.id,
        'endpoint',
          subscription_row.endpoint,
        'keys',
          jsonb_build_object(
            'p256dh',
              subscription_row.p256dh_key,
            'auth',
              subscription_row.auth_key
          ),
        'attempt_number',
          delivery_row.attempt_number
      )
      order by delivery_row.id
    ),
    '[]'::jsonb
  )
  into v_deliveries
  from public.notification_deliveries
    delivery_row
  join public.push_subscriptions
    subscription_row
    on subscription_row.id =
       delivery_row.subscription_id
  where delivery_row.notification_id =
        v_notification.id
    and delivery_row.channel =
        'WebPush'
    and delivery_row.delivery_status in (
      'Pending',
      'Failed'
    )
    and subscription_row.user_id =
        v_notification.recipient_user_id
    and subscription_row.is_active = true
    and subscription_row.permission_state =
        'granted'
    and subscription_row.revoked_at is null;

  return jsonb_build_object(
    'job',
      jsonb_build_object(
        'id',
          v_job.id,
        'attempt_count',
          v_job.attempt_count,
        'maximum_attempts',
          v_job.maximum_attempts
      ),
    'notification',
      jsonb_build_object(
        'id',
          v_notification.id,
        'recipient_user_id',
          v_notification.recipient_user_id,
        'title',
          v_notification.title,
        'message',
          v_notification.message,
        'category',
          v_notification.category,
        'priority',
          v_notification.priority,
        'severity',
          v_notification.severity,
        'action_label',
          v_notification.action_label,
        'action_route',
          v_notification.action_route,
        'action_params',
          coalesce(
            v_notification.action_params,
            '{}'::jsonb
          ),
        'entity_type',
          v_notification.entity_type,
        'entity_id',
          v_notification.entity_id,
        'expires_at',
          v_notification.expires_at
      ),
    'deliveries',
      v_deliveries
  );
end
$function$;

-- Older cached clients can still submit reminder_enabled on ordinary cache autosync.
-- Consumed one-shot schedules cannot restart without an explicit new due time.
CREATE OR REPLACE FUNCTION notification_private.protect_consumed_once()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF public.notification_reminder_mode() AND OLD.reminder_type='once' AND NEW.reminder_type='once'
   AND NOT OLD.reminder_enabled AND NEW.reminder_enabled AND NEW.next_reminder_at IS NULL THEN
   NEW.reminder_enabled:=false;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION notification_private.protect_consumed_once() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS notification_todo_consumed_once ON public.todos;
CREATE TRIGGER notification_todo_consumed_once BEFORE UPDATE ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.protect_consumed_once();

-- Cancel only outstanding delivery work when the source is resolved or its schedule changes.
-- Inbox/history rows remain; no delete or business-state rewrite.
CREATE OR REPLACE FUNCTION notification_private.todo_schedule_changed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT public.notification_reminder_mode() OR current_setting('mghrm.scheduler_write',true)='on' THEN RETURN NEW; END IF;
 IF (NOT notification_private.todo_actionable(NEW)) OR
   ROW(NEW.reminder_enabled,NEW.reminder_type,NEW.reminder_interval,NEW.reminder_dates,NEW.next_reminder_at,NEW.reminder_timezone,NEW.assigned_to_user_id,NEW.owner_user_id)
   IS DISTINCT FROM ROW(OLD.reminder_enabled,OLD.reminder_type,OLD.reminder_interval,OLD.reminder_dates,OLD.next_reminder_at,OLD.reminder_timezone,OLD.assigned_to_user_id,OLD.owner_user_id) THEN
   UPDATE public.notification_events SET processing_status='Ignored',processing_error='Source schedule changed'
    WHERE entity_type='todo' AND entity_id=NEW.id::text AND event_type='TodoReminderDue' AND processing_status IN ('Pending','Failed');
   UPDATE public.notification_deliveries SET delivery_status='Cancelled',provider_status='SourceChanged'
    WHERE channel='WebPush' AND delivery_status IN ('Pending','Failed','Processing') AND notification_id IN
      (SELECT id FROM public.notifications WHERE entity_type='todo' AND entity_id=NEW.id::text AND category='ToDo');
   UPDATE public.notification_jobs SET job_status='Cancelled',locked_by=NULL,locked_at=NULL
    WHERE job_status IN ('Pending','Failed','Processing') AND (notification_id IN
      (SELECT id FROM public.notifications WHERE entity_type='todo' AND entity_id=NEW.id::text AND category='ToDo')
      OR event_id IN (SELECT id FROM public.notification_events WHERE entity_type='todo' AND entity_id=NEW.id::text AND processing_status='Ignored'));
   UPDATE public.notifications SET status='Cancelled' WHERE entity_type='todo' AND entity_id=NEW.id::text AND category='ToDo' AND status IN ('Scheduled','Snoozed','Ready','Failed');
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION notification_private.todo_schedule_changed() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS notification_todo_schedule_changed ON public.todos;
CREATE TRIGGER notification_todo_schedule_changed AFTER UPDATE ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.todo_schedule_changed();

CREATE OR REPLACE FUNCTION public.notification_snooze(p_notification_id uuid, p_snoozed_until timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'Notification ID is required';
  end if;

  if p_snoozed_until is null then
    raise exception using
      errcode = '22023',
      message = 'Snooze time is required';
  end if;

  if p_snoozed_until <= now() then
    raise exception using
      errcode = '23514',
      message = 'Snooze time must be in the future';
  end if;

  select n.*
    into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  if v_notification.status in (
    'Completed',
    'Dismissed',
    'Expired',
    'Cancelled'
  ) then
    raise exception using
      errcode = '23514',
      message = format(
        'Notification cannot be snoozed from status %s',
        v_notification.status
      );
  end if;

  update public.notifications n
     set status = 'Snoozed',
         snoozed_until = p_snoozed_until,
         scheduled_for = p_snoozed_until
   where n.id = p_notification_id
     and n.recipient_user_id = v_user_id
   returning n.*
      into v_notification;

  if v_notification.category='ToDo' and public.notification_reminder_mode() then
    -- Keep prior Sent/Skipped/Cancelled attempts as history. Only a new attempt is pending.
    insert into public.notification_deliveries(notification_id,subscription_id,channel,attempt_number,delivery_status)
    select v_notification.id,s.id,'WebPush',coalesce((select max(d.attempt_number) from public.notification_deliveries d
      where d.notification_id=v_notification.id and d.channel='WebPush' and d.subscription_id=s.id),0)+1,'Pending'
    from public.push_subscriptions s where s.user_id=v_user_id and s.is_active and s.permission_state='granted'
    and s.revoked_at is null and not exists(select 1 from public.notification_deliveries d
      where d.notification_id=v_notification.id and d.subscription_id=s.id and d.channel='WebPush' and d.delivery_status in ('Pending','Failed','Processing'));
    update public.notification_jobs set run_at=p_snoozed_until where notification_id=v_notification.id
      and job_type='DeliverWebPush' and job_status in ('Pending','Failed');
    insert into public.notification_jobs(notification_id,event_id,job_type,run_at,job_status,job_payload)
    values(v_notification.id,v_notification.event_id,'DeliverWebPush',p_snoozed_until,'Pending','{}'::jsonb) on conflict do nothing;
  end if;

  return jsonb_build_object(
    'notification',
    to_jsonb(v_notification),
    'changed',
    true
  );
end;
$function$;

-- Activation is service-only and serialized with both producer paths. No reset of schedules.
CREATE OR REPLACE FUNCTION public.notification_set_server_reminders(p_enabled boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_enabled IS NULL THEN RAISE EXCEPTION 'Explicit mode required'; END IF;
 PERFORM pg_advisory_xact_lock(73110420261021);
 UPDATE notification_private.reminder_control SET server_authoritative=p_enabled WHERE singleton;
END $$;
REVOKE ALL ON FUNCTION public.notification_set_server_reminders(boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_set_server_reminders(boolean) TO service_role;
-- Existing function ACLs are deliberately preserved by CREATE OR REPLACE.
COMMIT;
