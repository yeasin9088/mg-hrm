-- MG-HRM Phase4 Slice B: gated V1/V2 server pipeline and last-mile digest validation.
-- Must follow Phase3 and Phase4 Slice A migrations. Both flags are false by default.
-- No new cron, public UI, provider, subscriptions or actual send.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION notification_private.digest_dispatch_allowed(
 p_batch_key text,p_recipient uuid,p_at timestamptz
) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE b notification_private.digest_batches%rowtype;
 v_plan jsonb; v_local timestamp;
BEGIN
 IF p_batch_key IS NULL OR p_batch_key !~ '^[0-9]{1,18}$'
   OR p_recipient IS NULL OR p_at IS NULL THEN RETURN false; END IF;
 SELECT * INTO b FROM notification_private.digest_batches d
 WHERE d.id::text=p_batch_key AND d.recipient_user_id=p_recipient;
 IF NOT FOUND THEN RETURN false; END IF;
 v_local:=p_at AT TIME ZONE 'Asia/Dhaka';
 -- Do not wake devices outside an approved routine Push window.
 IF v_local::time<time '09:05' OR v_local::time>=time '18:00'
    OR p_at<b.slot_at OR p_at-b.slot_at>interval '12 hours'
 THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=p_recipient AND p.is_active)
 THEN RETURN false; END IF;
 -- Pending source truth, recipient ownership, terminal state and verified
 -- business deadline are recomputed from real To-Dos, never stale JSON.
 v_plan:=notification_private.digest_plan(p_recipient,b.local_day,b.digest_kind,p_at);
 RETURN coalesce((v_plan->>'item_count')::integer,0)>0;
EXCEPTION WHEN OTHERS THEN
 RETURN false; -- last-mile source validator fails closed
END $mg$;
REVOKE ALL ON FUNCTION notification_private.digest_dispatch_allowed(text,uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_dispatch_allowed(text,uuid,timestamptz)
 TO service_role;
CREATE OR REPLACE FUNCTION public.notification_cron_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_lock_key constant bigint := 73110420261011;
  v_result jsonb;
  v_digest jsonb;
  v_event jsonb;
  v_delivery jsonb;
  v_governance boolean:=false;
  v_bridge boolean:=false;
begin
  if not pg_try_advisory_xact_lock(v_lock_key) then
    return jsonb_build_object(
      'status', 'Skipped',
      'reason', 'Another processor run is active',
      'finished_at', clock_timestamp()
    );
  end if;

  SELECT enabled INTO v_governance FROM notification_private.governance_control WHERE singleton;
  SELECT enabled INTO v_bridge FROM notification_private.digest_bridge_control WHERE singleton;
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false) THEN
    -- Phase4 gated path: source-authoritative grouped digests, ONE event per slot.
    -- Do not run the V1 To-Do producer or V1 unread recurrence here.
    v_digest:=notification_private.digest_publish_for_operators(clock_timestamp());
    v_event:=public.notification_run_event_processor('cron:notification-v2-digest',25,interval '15 minutes');
    v_delivery:=public.notification_prepare_deliveries(25);
    RETURN jsonb_build_object('status','Completed','mode','governance_digest_bridge',
      'digest',v_digest,'event_processor',v_event,'delivery_processor',v_delivery,
      'finished_at',clock_timestamp());
  END IF;
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
REVOKE ALL ON FUNCTION public.notification_cron_tick() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.notification_get_web_push_dispatch(p_job_id bigint, p_worker_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_notification public.notifications%rowtype;
  v_deliveries jsonb;
  v_digest_invalid boolean:=false;
  v_governance boolean:=false;
  v_bridge boolean:=false;
  v_source_blocked boolean;
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

  v_source_blocked := notification_private.push_source_ineligible(
    v_notification.entity_type, v_notification.entity_id, v_notification.recipient_user_id
  );

  SELECT enabled INTO v_governance FROM notification_private.governance_control WHERE singleton;
  SELECT enabled INTO v_bridge FROM notification_private.digest_bridge_control WHERE singleton;
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false)
     AND v_notification.entity_type='digest' THEN
    v_digest_invalid:=NOT notification_private.digest_dispatch_allowed(
      v_notification.entity_id,v_notification.recipient_user_id,clock_timestamp());
  END IF;

  -- Recheck immediately before dispatch, including source, preferences and live presence.
  update public.notification_deliveries d set delivery_status='Skipped',
    provider_status='DispatchIneligible',response_metadata=coalesce(d.response_metadata,'{}'::jsonb)||jsonb_build_object('checked_at',clock_timestamp(),
      'gate_reason',case when v_digest_invalid then 'digest_source_or_window_invalid'
        when v_source_blocked then 'source_ineligible_or_recipient_changed'
        else 'dispatch_ineligible_other' end)
  where d.notification_id=v_notification.id and d.channel='WebPush' and d.delivery_status in ('Pending','Failed')
  and (
    v_notification.status in ('Completed','Cancelled','Expired','Dismissed')
    or (v_notification.expires_at is not null and v_notification.expires_at<=clock_timestamp())
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'notification_enabled')::boolean,true)
    or not coalesce((public.notification_effective_preference(v_notification.recipient_user_id,v_notification.category)->>'system_push_enabled')::boolean,true)
    or v_source_blocked
    or v_digest_invalid
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
REVOKE ALL ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) TO service_role;
COMMIT;
