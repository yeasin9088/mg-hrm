-- Phase4 Slice C: prevent stale/disabled grouped digest entering the Inbox.
-- Retains exact V1 behavior for every other existing business event.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION public.notification_process_event_job(p_job_id bigint, p_worker_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_event public.notification_events%rowtype;

  v_payload jsonb;
  v_preference jsonb;

  v_recipient uuid;
  v_notification_id uuid;

  v_category text;
  v_severity text;
  v_priority text;
  v_title text;
  v_message text;
  v_dedupe_key text;

  v_action_label text;
  v_action_route text;
  v_action_params jsonb;

  v_requested_at timestamptz;
  v_allowed_at timestamptz;
  v_expires_at timestamptz;
  v_status text;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception 'Worker ID is required';
  end if;

  select *
  into v_job
  from public.notification_jobs
  where id = p_job_id
  for update;

  if v_job.id is null then
    raise exception
      'Notification job % does not exist',
      p_job_id;
  end if;

  if v_job.job_status <> 'Processing'
     or v_job.locked_by is distinct from btrim(p_worker_id) then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  if v_job.job_type <> 'ProcessEvent'
     or v_job.event_id is null then
    raise exception
      'Job % is not a valid ProcessEvent job',
      p_job_id;
  end if;

  select *
  into v_event
  from public.notification_events
  where id = v_job.event_id
  for update;

  if v_event.id is null then
    perform public.notification_fail_job(
      p_job_id,
      p_worker_id,
      'Referenced notification event does not exist',
      interval '5 minutes'
    );

    return null;
  end if;

  if v_event.processing_status in (
    'Processed',
    'Ignored',
    'Cancelled'
  ) then
    perform public.notification_complete_job(
      p_job_id,
      p_worker_id
    );

    return null;
  end if;

  -- In-flight digest events cannot enter the Inbox after a rollback.
  -- The ordinary V1 event types still use their untouched processing path.
  IF v_event.event_type='OperatorWorkDigest' THEN
    IF NOT coalesce((SELECT enabled FROM notification_private.governance_control
       WHERE singleton),false)
       OR NOT coalesce((SELECT enabled FROM notification_private.digest_bridge_control
         WHERE singleton),false)
       OR NOT notification_private.digest_dispatch_allowed(
         v_event.entity_id,v_event.actor_user_id,clock_timestamp())
    THEN
      UPDATE public.notification_events SET processing_status='Ignored',
        processed_at=clock_timestamp(),
        processing_error='Digest suppressed after source/policy revalidation'
      WHERE id=v_event.id;
      PERFORM public.notification_complete_job(p_job_id,p_worker_id);
      RETURN null;
    END IF;
  END IF;

  begin
    v_payload := coalesce(
      v_event.event_payload,
      '{}'::jsonb
    );

    if nullif(
      btrim(v_payload ->> 'recipient_user_id'),
      ''
    ) is null then
      raise exception
        'event_payload.recipient_user_id is required';
    end if;

    begin
      v_recipient :=
        (v_payload ->> 'recipient_user_id')::uuid;
    exception
      when invalid_text_representation then
        raise exception
          'event_payload.recipient_user_id must be a valid UUID';
    end;

    if not exists (
      select 1
      from public.profiles p
      where p.id = v_recipient
        and p.is_active = true
    ) then
      raise exception
        'Configured recipient is missing or inactive';
    end if;

    v_category := coalesce(
      nullif(
        btrim(v_payload ->> 'category'),
        ''
      ),
      'System'
    );

    v_severity := coalesce(
      nullif(
        btrim(v_payload ->> 'severity'),
        ''
      ),
      'Info'
    );

    if v_severity not in (
      'Info',
      'Success',
      'Warning',
      'Critical'
    ) then
      raise exception
        'Unsupported severity: %',
        v_severity;
    end if;

    v_priority := coalesce(
      nullif(
        btrim(v_payload ->> 'priority'),
        ''
      ),
      'Normal'
    );

    if v_priority not in (
      'Low',
      'Normal',
      'High',
      'Urgent'
    ) then
      raise exception
        'Unsupported priority: %',
        v_priority;
    end if;

    v_title :=
      nullif(btrim(v_payload ->> 'title'), '');

    v_message :=
      nullif(btrim(v_payload ->> 'message'), '');

    if v_title is null then
      raise exception
        'event_payload.title is required';
    end if;

    if v_message is null then
      raise exception
        'event_payload.message is required';
    end if;

    v_dedupe_key := coalesce(
      nullif(
        btrim(v_payload ->> 'dedupe_key'),
        ''
      ),
      'event:' || v_event.event_key
    );

    v_action_label :=
      nullif(
        btrim(v_payload ->> 'action_label'),
        ''
      );

    v_action_route :=
      nullif(
        btrim(v_payload ->> 'action_route'),
        ''
      );

    v_action_params := coalesce(
      v_payload -> 'action_params',
      '{}'::jsonb
    );

    if jsonb_typeof(v_action_params) <> 'object' then
      raise exception
        'event_payload.action_params must be a JSON object';
    end if;

    begin
      v_requested_at := coalesce(
        nullif(
          v_payload ->> 'scheduled_for',
          ''
        )::timestamptz,
        clock_timestamp()
      );
    exception
      when invalid_datetime_format then
        raise exception
          'event_payload.scheduled_for must be a valid timestamp';
    end;

    begin
      v_expires_at :=
        nullif(
          v_payload ->> 'expires_at',
          ''
        )::timestamptz;
    exception
      when invalid_datetime_format then
        raise exception
          'event_payload.expires_at must be a valid timestamp';
    end;

    if v_expires_at is not null
       and v_expires_at <= clock_timestamp() then
      raise exception
        'event_payload.expires_at must be in the future';
    end if;

    v_preference :=
      public.notification_effective_preference(
        v_recipient,
        v_category
      );

    v_allowed_at :=
      public.notification_next_allowed_at(
        v_recipient,
        v_category,
        v_priority,
        v_requested_at
      );

    if v_allowed_at is null then
      update public.notification_events
      set
        processing_status = 'Ignored',
        processed_at = clock_timestamp(),
        processing_error =
          'Suppressed by recipient notification preference'
      where id = v_event.id;

      perform public.notification_complete_job(
        p_job_id,
        p_worker_id
      );

      return null;
    end if;

    if v_expires_at is not null
       and v_allowed_at >= v_expires_at then
      update public.notification_events
      set
        processing_status = 'Ignored',
        processed_at = clock_timestamp(),
        processing_error =
          'Allowed delivery time is after notification expiry'
      where id = v_event.id;

      perform public.notification_complete_job(
        p_job_id,
        p_worker_id
      );

      return null;
    end if;

    v_status := case
      when v_allowed_at > clock_timestamp()
        then 'Scheduled'
      else 'Ready'
    end;

    update public.notification_events
    set
      processing_status = 'Processing',
      processed_at = null,
      processing_error = null
    where id = v_event.id;

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
      escalation_level
    )
    values (
      v_event.id,
      v_recipient,
      v_category,
      v_severity,
      v_priority,
      v_title,
      v_message,
      v_event.entity_type,
      v_event.entity_id,
      v_event.employee_sys_id,
      v_event.project_id,
      v_action_label,
      v_action_route,
      v_action_params,
      v_status,
      v_allowed_at,
      v_expires_at,
      v_dedupe_key,
      0,
      0
    )
    on conflict do nothing
    returning id
    into v_notification_id;

    if v_notification_id is null then
      select n.id
      into v_notification_id
      from public.notifications n
      where n.recipient_user_id = v_recipient
        and n.dedupe_key = v_dedupe_key
        and n.status in (
          'Scheduled',
          'Ready',
          'Delivered',
          'Read',
          'Actioned',
          'Snoozed',
          'Failed'
        )
      order by n.created_at desc
      limit 1;

      if v_notification_id is null then
        raise exception
          'Insert skipped but no open duplicate exists';
      end if;
    end if;

    update public.notification_events
    set
      processing_status = 'Processed',
      processed_at = clock_timestamp(),
      processing_error = null
    where id = v_event.id;

    perform public.notification_complete_job(
      p_job_id,
      p_worker_id
    );

    return v_notification_id;

  exception
    when others then
      update public.notification_events
      set
        processing_status = 'Failed',
        processed_at = null,
        processing_error = left(sqlerrm, 4000)
      where id = v_event.id;

      perform public.notification_fail_job(
        p_job_id,
        p_worker_id,
        sqlerrm,
        interval '5 minutes'
      );

      return null;
  end;
end
$function$;
REVOKE ALL ON FUNCTION public.notification_process_event_job(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_process_event_job(bigint,text) TO service_role;
COMMIT;
