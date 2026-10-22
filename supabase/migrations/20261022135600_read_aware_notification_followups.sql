-- MG-HRM | Read-aware notification follow-ups, reviewed additive migration.
-- Never run against production without explicit approval and verified acceptance.
-- Preserves existing inbox, event, retry and delivery history. No activation changes.
-- Prerequisite: 20261021152333_reliable_reminder_scheduler.sql
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';

-- An alert remains pending until persisted user acknowledgement. Push delivery,
-- background polling, viewing an app page and displaying an OS tray are NOT reads.
CREATE OR REPLACE FUNCTION notification_private.todo_followup_allowed(
 p_todo public.todos,p_recipient uuid,p_now timestamptz
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $mg$
DECLARE last_ack timestamptz; latest_status text; latest_read timestamptz;
 step_minutes integer;
BEGIN
 IF p_recipient IS NULL OR p_todo.id IS NULL THEN RETURN false; END IF;
 -- Historic duplicates from the former scheduler must not block the operator
 -- forever after they acknowledge the NEWEST occurrence of this topic.
 SELECT n.status,n.read_at,coalesce(n.read_at,n.dismissed_at)
 INTO latest_status,latest_read,last_ack
 FROM public.notifications n JOIN public.notification_events e ON e.id=n.event_id
 WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo'
   AND n.entity_id=p_todo.id::text AND e.event_type='TodoReminderDue'
 ORDER BY n.created_at DESC,n.id DESC LIMIT 1;
 IF latest_status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
    AND (latest_read IS NULL OR latest_status='Snoozed')
 THEN RETURN false; END IF;
 -- Preserve a deliberate still-active snooze even if newer historical copies exist.
 IF EXISTS (
   SELECT 1 FROM public.notifications n JOIN public.notification_events e ON e.id=n.event_id
   WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo'
     AND n.entity_id=p_todo.id::text AND e.event_type='TodoReminderDue'
     AND n.status='Snoozed' AND n.snoozed_until>p_now
 ) THEN RETURN false; END IF;
 step_minutes:=CASE coalesce(p_todo.reminder_type,'1h')
   WHEN 'today' THEN 1440
   ELSE greatest(5,least(1440,coalesce(nullif(p_todo.reminder_interval,0),
     CASE p_todo.reminder_type WHEN '30m' THEN 30 WHEN '2h' THEN 120 ELSE 60 END)))
 END;
 RETURN last_ack IS NULL OR p_now>=last_ack+make_interval(mins=>step_minutes);
END $mg$;
REVOKE ALL ON FUNCTION notification_private.todo_followup_allowed(public.todos,uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;

-- Reuse the existing producer logic; change only follow-up eligibility.
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
      AND notification_private.todo_followup_allowed(t,recipient,instant)
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
  IF NOT notification_private.todo_followup_allowed(t,recipient,clock_timestamp()) THEN
     UPDATE public.todos SET next_reminder_at=p_next,
       reminder_enabled=CASE WHEN p_next IS NULL THEN false ELSE reminder_enabled END WHERE id=t.id;
     RETURN jsonb_build_object('claimed',false,'suppressed','unread_or_cooldown');
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



-- Support repeat-only rules with NO actual escalation recipient.
ALTER TABLE public.notification_escalation_rules
 DROP CONSTRAINT notification_escalation_target_required_check;
ALTER TABLE public.notification_escalation_rules
 ADD CONSTRAINT notification_escalation_target_required_check CHECK (
  escalation_target_role IS NOT NULL OR escalation_target_user_id IS NOT NULL
  OR (repeat_every_minutes IS NOT NULL AND maximum_repeat_count > 0)
 );

-- Only actionable events with a supported source-state resolver qualify.
-- Do not auto-repeat disciplinary record creation or general informational events.
INSERT INTO public.notification_escalation_rules
 (rule_key,rule_name,category,event_type,source_priority,
  first_repeat_after_minutes,escalation_after_minutes,
  repeat_every_minutes,maximum_repeat_count,is_enabled)
VALUES
 ('mg-smart-transfer-due-v1','Unconfirmed due transfer review','Transfer',
  'TransferJoiningConfirmationRequired','High',1440,52560000,1440,30,true),
 ('mg-smart-leave-review-v1','Undecided leave review','Leave',
  'LeaveReviewRequired','Low',1440,52560000,1440,14,true),
 ('mg-smart-uniform-review-v1','Pending uniform supply order','Uniform',
  'UniformSupplyOrderActionRequired','Low',1440,52560000,1440,14,true)
ON CONFLICT(rule_key) DO NOTHING;

-- Guard all repeat children at their authoritative INSERT point; the existing
-- recurrence engine increments repeat_count only if this INSERT succeeds.
CREATE OR REPLACE FUNCTION notification_private.prevent_unseen_repeat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public
AS $mg$
DECLARE
 root_n public.notifications%rowtype;
 source_state jsonb;
 last_ack timestamptz;
 repeat_minutes integer;
BEGIN
 IF NEW.parent_notification_id IS NULL OR NEW.repeat_count <= 0
    OR NEW.escalation_level <> 0 THEN RETURN NEW; END IF;
 SELECT * INTO root_n FROM public.notifications WHERE id=NEW.parent_notification_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF root_n.recipient_user_id IS DISTINCT FROM NEW.recipient_user_id
    OR root_n.status NOT IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
    OR root_n.read_at IS NULL OR root_n.status='Snoozed'
 THEN RETURN NULL; END IF;
 source_state:=public.notification_source_state(root_n.entity_type,root_n.entity_id);
 IF NOT coalesce((source_state->>'supported')::boolean,false)
    OR coalesce((source_state->>'resolved')::boolean,false)
    OR source_state->>'state'='Source workflow record not found'
 THEN RETURN NULL; END IF;
 IF EXISTS (
   SELECT 1 FROM public.notifications n
   WHERE n.recipient_user_id=root_n.recipient_user_id
     AND (n.id=root_n.id OR n.parent_notification_id=root_n.id)
     AND n.escalation_level=0
     AND n.status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
     AND (n.read_at IS NULL OR n.status='Snoozed')
 ) THEN RETURN NULL; END IF;
 SELECT r.repeat_every_minutes INTO repeat_minutes
 FROM public.notification_escalation_rules r
 WHERE r.id=NEW.escalation_rule_id AND r.is_enabled AND r.repeat_every_minutes>0;
 IF repeat_minutes IS NULL THEN RETURN NULL; END IF;
 SELECT max(n.read_at) INTO last_ack FROM public.notifications n
 WHERE n.recipient_user_id=root_n.recipient_user_id
   AND (n.id=root_n.id OR n.parent_notification_id=root_n.id)
   AND n.escalation_level=0;
 IF last_ack IS NULL OR clock_timestamp()<last_ack+make_interval(mins=>repeat_minutes)
 THEN RETURN NULL; END IF;
 RETURN NEW;
END $mg$;
REVOKE ALL ON FUNCTION notification_private.prevent_unseen_repeat()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS mg_prevent_unseen_repeat_insert ON public.notifications;
CREATE TRIGGER mg_prevent_unseen_repeat_insert
 BEFORE INSERT ON public.notifications FOR EACH ROW
 EXECUTE FUNCTION notification_private.prevent_unseen_repeat();

-- Prioritize configured action-required source rows when recurring.
CREATE OR REPLACE FUNCTION public.notification_run_recurrence(p_batch_size integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_notification public.notifications%rowtype;
  v_rule public.notification_escalation_rules%rowtype;
  v_source jsonb;
  v_target uuid;

  v_examined integer := 0;
  v_resolved integer := 0;
  v_repeats_created integer := 0;
  v_escalations_created integer := 0;
  v_scope_rules_skipped integer := 0;
  v_missing_targets integer := 0;

  v_repeat_due boolean;
  v_escalation_due boolean;
  v_existing_escalation boolean;
begin
  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 200 then
    raise exception
      'Batch size must be between 1 and 200';
  end if;

  for v_notification in
    select n.*
    from public.notifications n
    where n.status in (
      'Scheduled',
      'Ready',
      'Delivered',
      'Read',
      'Actioned',
      'Snoozed',
      'Failed'
    )
      and n.parent_notification_id is null
    -- Prioritize actionable configured rules, so many older ToDos cannot starve them.
    order by CASE WHEN EXISTS (
      SELECT 1 FROM public.notification_escalation_rules r
      WHERE r.is_enabled AND r.category=n.category
        AND (r.event_type IS NULL OR EXISTS (
          SELECT 1 FROM public.notification_events e
          WHERE e.id=n.event_id AND e.event_type=r.event_type))
    ) THEN 0 ELSE 1 END, n.created_at, n.id
    limit p_batch_size
    for update skip locked
  loop
    v_examined := v_examined + 1;

    v_source :=
      public.notification_source_state(
        v_notification.entity_type,
        v_notification.entity_id
      );

    if coalesce(
      (v_source ->> 'supported')::boolean,
      false
    )
    and coalesce(
      (v_source ->> 'resolved')::boolean,
      false
    ) then

      update public.notifications
      set status = 'Completed'
      where id = v_notification.id
        and status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        );

      update public.notifications
      set status = 'Cancelled'
      where parent_notification_id =
            v_notification.id
        and status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        );

      update public.notification_jobs
      set
        job_status = 'Cancelled',
        locked_at = null,
        locked_by = null
      where notification_id in (
        select n.id
        from public.notifications n
        where n.id = v_notification.id
           or n.parent_notification_id =
              v_notification.id
      )
        and job_status in (
          'Pending',
          'Processing',
          'Failed'
        );

      v_resolved := v_resolved + 1;
      continue;
    end if;


    for v_rule in
      select r.*
      from public.notification_escalation_rules r
      where r.is_enabled = true
        and r.category =
            v_notification.category
        and (
          r.event_type is null
          or exists (
            select 1
            from public.notification_events e
            where e.id =
                  v_notification.event_id
              and e.event_type =
                  r.event_type
          )
        )
        and public.notification_priority_rank(
          v_notification.priority
        ) >= public.notification_priority_rank(
          r.source_priority
        )
      order by r.id
    loop
      v_repeat_due :=
        v_rule.repeat_every_minutes is not null
        and coalesce(
          v_notification.repeat_count,
          0
        ) < coalesce(
          v_rule.maximum_repeat_count,
          0
        )
        and clock_timestamp() >=
          v_notification.created_at
          + make_interval(
              mins =>
                coalesce(
                  v_rule.first_repeat_after_minutes,
                  v_rule.repeat_every_minutes
                )
                +
                (
                  coalesce(
                    v_notification.repeat_count,
                    0
                  )
                  *
                  v_rule.repeat_every_minutes
                )
            );

      if v_repeat_due then
        insert into public.notifications (
          event_id,
          recipient_user_id,
          category,
          severity,
          priority,
          title,
          message,
          entity_type,
          entity_id,
          employee_sys_id,
          project_id,
          action_label,
          action_route,
          action_params,
          status,
          scheduled_for,
          expires_at,
          dedupe_key,
          repeat_count,
          escalation_level,
          parent_notification_id,
          escalation_rule_id
        )
        values (
          v_notification.event_id,
          v_notification.recipient_user_id,
          v_notification.category,
          v_notification.severity,
          v_notification.priority,
          v_notification.title,
          v_notification.message,
          v_notification.entity_type,
          v_notification.entity_id,
          v_notification.employee_sys_id,
          v_notification.project_id,
          v_notification.action_label,
          v_notification.action_route,
          v_notification.action_params,
          'Ready',
          clock_timestamp(),
          v_notification.expires_at,
          v_notification.dedupe_key ||
            ':repeat:' ||
            (
              v_notification.repeat_count + 1
            )::text,
          v_notification.repeat_count + 1,
          v_notification.escalation_level,
          v_notification.id,
          v_rule.id
        )
        on conflict do nothing;

        if found then
          update public.notifications
          set repeat_count =
                repeat_count + 1
          where id = v_notification.id;

          v_notification.repeat_count :=
            v_notification.repeat_count + 1;

          v_repeats_created :=
            v_repeats_created + 1;
        end if;
      end if;


      v_escalation_due :=
        clock_timestamp() >=
          v_notification.created_at
          + make_interval(
              mins =>
                v_rule.escalation_after_minutes
            );

      if not v_escalation_due then
        continue;
      end if;

      select exists (
        select 1
        from public.notifications child
        where child.parent_notification_id =
              v_notification.id
          and child.escalation_rule_id =
              v_rule.id
          and child.escalation_level > 0
      )
      into v_existing_escalation;

      if v_existing_escalation then
        continue;
      end if;

      if v_rule.project_scope_required then
        v_scope_rules_skipped :=
          v_scope_rules_skipped + 1;
        continue;
      end if;


      if v_rule.escalation_target_user_id
         is not null then

        if exists (
          select 1
          from public.profiles p
          where p.id =
                v_rule.escalation_target_user_id
            and p.is_active = true
        ) then
          v_target :=
            v_rule.escalation_target_user_id;
        else
          v_target := null;
          v_missing_targets :=
            v_missing_targets + 1;
        end if;

        if v_target is not null then
          insert into public.notifications (
            event_id,
            recipient_user_id,
            category,
            severity,
            priority,
            title,
            message,
            entity_type,
            entity_id,
            employee_sys_id,
            project_id,
            action_label,
            action_route,
            action_params,
            status,
            scheduled_for,
            expires_at,
            dedupe_key,
            repeat_count,
            escalation_level,
            parent_notification_id,
            escalation_rule_id
          )
          values (
            v_notification.event_id,
            v_target,
            v_notification.category,
            v_notification.severity,
            v_notification.priority,
            v_notification.title,
            v_notification.message,
            v_notification.entity_type,
            v_notification.entity_id,
            v_notification.employee_sys_id,
            v_notification.project_id,
            v_notification.action_label,
            v_notification.action_route,
            v_notification.action_params,
            'Ready',
            clock_timestamp(),
            v_notification.expires_at,
            v_notification.dedupe_key ||
              ':escalation:' ||
              v_rule.id::text ||
              ':' ||
              v_target::text,
            0,
            v_notification.escalation_level + 1,
            v_notification.id,
            v_rule.id
          )
          on conflict do nothing;

          if found then
            v_escalations_created :=
              v_escalations_created + 1;
          end if;
        end if;


      elsif v_rule.escalation_target_role
            is not null then

        for v_target in
          select p.id
          from public.profiles p
          where p.is_active = true
            and p.role =
                v_rule.escalation_target_role
          order by p.id
        loop
          insert into public.notifications (
            event_id,
            recipient_user_id,
            category,
            severity,
            priority,
            title,
            message,
            entity_type,
            entity_id,
            employee_sys_id,
            project_id,
            action_label,
            action_route,
            action_params,
            status,
            scheduled_for,
            expires_at,
            dedupe_key,
            repeat_count,
            escalation_level,
            parent_notification_id,
            escalation_rule_id
          )
          values (
            v_notification.event_id,
            v_target,
            v_notification.category,
            v_notification.severity,
            v_notification.priority,
            v_notification.title,
            v_notification.message,
            v_notification.entity_type,
            v_notification.entity_id,
            v_notification.employee_sys_id,
            v_notification.project_id,
            v_notification.action_label,
            v_notification.action_route,
            v_notification.action_params,
            'Ready',
            clock_timestamp(),
            v_notification.expires_at,
            v_notification.dedupe_key ||
              ':escalation:' ||
              v_rule.id::text ||
              ':' ||
              v_target::text,
            0,
            v_notification.escalation_level + 1,
            v_notification.id,
            v_rule.id
          )
          on conflict do nothing;

          if found then
            v_escalations_created :=
              v_escalations_created + 1;
          end if;
        end loop;

        if not found then
          v_missing_targets :=
            v_missing_targets + 1;
        end if;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'notifications_examined',
      v_examined,
    'resolved_notifications_completed',
      v_resolved,
    'repeat_notifications_created',
      v_repeats_created,
    'escalation_notifications_created',
      v_escalations_created,
    'project_scope_rules_skipped',
      v_scope_rules_skipped,
    'missing_or_inactive_targets',
      v_missing_targets,
    'finished_at',
      clock_timestamp()
  );
end
$function$;


DO $mg$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_trigger t
   WHERE t.tgrelid='public.notifications'::regclass
     AND t.tgname='mg_prevent_unseen_repeat_insert' AND NOT t.tgisinternal)
 THEN RAISE EXCEPTION 'Unread repeat gate is missing'; END IF;
 IF to_regprocedure('notification_private.todo_followup_allowed(public.todos,uuid,timestamptz)') IS NULL
 THEN RAISE EXCEPTION 'ToDo follow-up gate is missing'; END IF;
END $mg$;
COMMIT;
