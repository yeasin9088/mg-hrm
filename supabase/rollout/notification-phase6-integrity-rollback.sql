-- Break-glass containment, reviewed against the pre-change live functions.
-- Keep all new audit/interaction/quota rows. Do not reset HR data.
BEGIN;
SET LOCAL lock_timeout='5s';
UPDATE notification_private.governance_control SET enabled=false WHERE singleton;
UPDATE notification_private.digest_bridge_control SET enabled=false WHERE singleton;
DROP TRIGGER IF EXISTS notification_capture_source ON public.notifications;
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
  IF v_notification.entity_type='digest' THEN
    -- A queued digest is NEVER sent after either policy switch is disabled.
    -- This is a permanent containment gate, independent of V1 compatibility.
    v_digest_invalid:=NOT (coalesce(v_governance,false)
      AND coalesce(v_bridge,false)
      AND notification_private.digest_dispatch_allowed(
        v_notification.entity_id,v_notification.recipient_user_id,clock_timestamp()));
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
CREATE OR REPLACE FUNCTION public.notification_record_web_push_result(p_job_id bigint, p_worker_id text, p_delivery_id bigint, p_success boolean, p_provider_status text DEFAULT NULL::text, p_provider_message_id text DEFAULT NULL::text, p_error_code text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_response_metadata jsonb DEFAULT '{}'::jsonb, p_revoke_subscription boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_delivery public.notification_deliveries%rowtype;
  v_subscription public.push_subscriptions%rowtype;
  v_metadata jsonb;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if p_delivery_id is null then
    raise exception
      'Delivery ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if p_success is null then
    raise exception
      'Success state is required';
  end if;

  if p_response_metadata is null
     or jsonb_typeof(
       p_response_metadata
     ) <> 'object' then
    raise exception
      'Response metadata must be a JSON object';
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
      btrim(p_worker_id)
  for update;

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select delivery_row.*
  into v_delivery
  from public.notification_deliveries
    delivery_row
  where delivery_row.id =
        p_delivery_id
    and delivery_row.notification_id =
        v_job.notification_id
    and delivery_row.channel =
        'WebPush'
    and delivery_row.delivery_status in (
      'Pending',
      'Failed',
      'Processing'
    )
  for update;

  if not found then
    raise exception
      'Web Push delivery % is unavailable for job %',
      p_delivery_id,
      p_job_id;
  end if;

  select subscription_row.*
  into v_subscription
  from public.push_subscriptions
    subscription_row
  where subscription_row.id =
        v_delivery.subscription_id
  for update;

  if not found then
    raise exception
      'Subscription for delivery % was not found',
      p_delivery_id;
  end if;

  v_metadata :=
    coalesce(
      v_delivery.response_metadata,
      '{}'::jsonb
    )
    || p_response_metadata
    || jsonb_build_object(
      'job_id',
        p_job_id,
      'worker_id',
        btrim(p_worker_id),
      'recorded_at',
        clock_timestamp()
    );

  if p_success then
    update public.notification_deliveries
    set
      delivery_status = 'Sent',
      attempt_number = greatest(
        attempt_number,
        v_job.attempt_count
      ),
      attempted_at = clock_timestamp(),
      sent_at = clock_timestamp(),
      delivered_at = null,
      failed_at = null,
      provider_status = nullif(
        btrim(
          coalesce(
            p_provider_status,
            ''
          )
        ),
        ''
      ),
      provider_message_id = nullif(
        btrim(
          coalesce(
            p_provider_message_id,
            ''
          )
        ),
        ''
      ),
      error_code = null,
      error_message = null,
      response_metadata = v_metadata
    where id = v_delivery.id
    returning *
    into v_delivery;

    update public.push_subscriptions
    set
      last_success_at =
        clock_timestamp(),
      failure_count = 0,
      last_failure_at = null
    where id = v_subscription.id
    returning *
    into v_subscription;

  else
    if nullif(
      btrim(
        coalesce(
          p_error_message,
          ''
        )
      ),
      ''
    ) is null then
      raise exception
        'Failure diagnostics are required';
    end if;

    update public.notification_deliveries
    set
      delivery_status = 'Failed',
      attempt_number = greatest(
        attempt_number,
        v_job.attempt_count
      ),
      attempted_at = clock_timestamp(),
      sent_at = null,
      delivered_at = null,
      failed_at = clock_timestamp(),
      provider_status = nullif(
        btrim(
          coalesce(
            p_provider_status,
            ''
          )
        ),
        ''
      ),
      provider_message_id = null,
      error_code = nullif(
        left(
          btrim(
            coalesce(
              p_error_code,
              ''
            )
          ),
          200
        ),
        ''
      ),
      error_message = left(
        btrim(p_error_message),
        4000
      ),
      response_metadata = v_metadata
    where id = v_delivery.id
    returning *
    into v_delivery;

    update public.push_subscriptions
    set
      failure_count =
        failure_count + 1,
      last_failure_at =
        clock_timestamp(),
      is_active = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then false
        else is_active
      end,
      permission_state = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then 'revoked'
        else permission_state
      end,
      revoked_at = case
        when coalesce(
          p_revoke_subscription,
          false
        )
        then coalesce(
          revoked_at,
          clock_timestamp()
        )
        else revoked_at
      end
    where id = v_subscription.id
    returning *
    into v_subscription;
  end if;

  return jsonb_build_object(
    'job_id',
      v_job.id,
    'delivery_id',
      v_delivery.id,
    'delivery_status',
      v_delivery.delivery_status,
    'subscription_id',
      v_subscription.id,
    'subscription_active',
      v_subscription.is_active,
    'permission_state',
      v_subscription.permission_state,
    'failure_count',
      v_subscription.failure_count,
    'subscription_revoked',
      v_subscription.revoked_at
        is not null
  );
end
$function$;
REVOKE ALL ON FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) TO service_role;
CREATE OR REPLACE FUNCTION notification_private.digest_plan(
 p_recipient uuid,p_day date,p_kind text,p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog
AS $mg$
DECLARE
 v_policy notification_private.core_policy_limits%rowtype;
 v_slot timestamptz;
 v_open timestamptz;
 v_prev_close timestamptz;
 v_items jsonb;
 v_count integer;
 v_groups jsonb;
 v_risks integer;
BEGIN
 IF p_recipient IS NULL OR p_day IS NULL OR p_at IS NULL OR
    p_kind IS NULL OR p_kind NOT IN ('morning','wrapup') THEN
    RAISE EXCEPTION 'Digest recipient, day, kind and time required' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_policy FROM notification_private.core_policy_limits WHERE singleton;
 IF NOT FOUND THEN RAISE EXCEPTION 'Core policy unavailable' USING ERRCODE='P0001'; END IF;
 v_slot:=(p_day + CASE WHEN p_kind='morning'
   THEN v_policy.morning_digest_time ELSE v_policy.afternoon_digest_time END)
   AT TIME ZONE 'Asia/Dhaka';
 v_open:=(p_day+1+v_policy.push_start) AT TIME ZONE 'Asia/Dhaka';
 v_prev_close:=(p_day-1+v_policy.push_end) AT TIME ZONE 'Asia/Dhaka';

 WITH sources AS (
   SELECT t.id AS todo_id, t.category,t.manager_status,t.created_at,
     md5(concat_ws('|',coalesce(t.updated_at::text,'unset'),
       coalesce(t.status,''),coalesce(t.manager_status,''),
       coalesce(t.assigned_to_user_id,t.owner_user_id)::text,
       coalesce(t.solved_at::text,''),coalesce(t.deleted_at::text,''))) AS source_version
   FROM public.todos t
   WHERE coalesce(t.assigned_to_user_id,t.owner_user_id)=p_recipient
     AND notification_private.todo_actionable(t)
     AND t.created_at<=p_at
 ), evidence AS (
   SELECT s.*,v.actual_deadline_at
   FROM sources s LEFT JOIN notification_private.core_verified_deadlines v
      ON v.entity_type='todo' AND v.entity_id=s.todo_id::text
      AND v.recipient_user_id=p_recipient
      AND v.source_version=s.source_version
      AND v.verified_at<=p_at
      AND v.verified_basis IN ('manual_verified','authoritative_adapter')
 ), groups AS (
   SELECT e.*,
     CASE
       WHEN e.actual_deadline_at IS NOT NULL AND e.actual_deadline_at<=p_at
         THEN 'OVERDUE'
       WHEN p_kind='wrapup' AND e.actual_deadline_at IS NOT NULL
            AND e.actual_deadline_at<v_open
         THEN 'BEFORE_NEXT_OPEN_RISK'
       WHEN p_kind='morning' AND e.actual_deadline_at IS NOT NULL
            AND (e.actual_deadline_at AT TIME ZONE 'Asia/Dhaka')::date=p_day
         THEN 'DUE_TODAY'
       WHEN lower(coalesce(e.category,''))='permission'
            AND lower(coalesce(e.manager_status,'')) IN ('asked','informed','waiting')
         THEN 'WAITING_FOLLOWUP'
       WHEN lower(coalesce(e.category,''))='permission'
         THEN 'BRIEF_MANAGER'
       ELSE 'ACT_TODAY'
     END group_key
   FROM evidence e
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
      'todo_id',todo_id,'source_version',source_version,
      'group_key',group_key,
      'verified_deadline_at',actual_deadline_at,
      'captured_overnight',p_kind='morning'
         AND created_at>=v_prev_close AND created_at<v_slot
    ) ORDER BY group_key,todo_id),'[]'::jsonb),
    count(*)::integer,
    count(*) FILTER (WHERE group_key IN
      ('OVERDUE','BEFORE_NEXT_OPEN_RISK'))::integer
 INTO v_items,v_count,v_risks FROM groups;

 SELECT coalesce(jsonb_object_agg(group_key,ct),'{}'::jsonb)
 INTO v_groups FROM (
    SELECT x->>'group_key' group_key,count(*) ct
    FROM jsonb_array_elements(v_items) x GROUP BY x->>'group_key'
 ) grouping;

 RETURN jsonb_build_object(
   'recipient_user_id',p_recipient,
   'local_day',p_day,'digest_kind',p_kind,
   'slot_at',v_slot,'evaluated_at',p_at,
   'is_due',p_at>=v_slot,'status',
     CASE WHEN p_at<v_slot THEN 'NOT_DUE' ELSE 'ELIGIBLE' END,
   'policy_version',v_policy.policy_version,
   'calendar_verified',false,
   'calendar_notice','No approved weekend or holiday calendar',
   'items',CASE WHEN p_at>=v_slot THEN v_items ELSE '[]'::jsonb END,
   'item_count',CASE WHEN p_at>=v_slot THEN v_count ELSE 0 END,
   'risk_count',CASE WHEN p_at>=v_slot THEN v_risks ELSE 0 END,
   'groups',CASE WHEN p_at>=v_slot THEN v_groups ELSE '{}'::jsonb END,
   'push_jobs_created',0,'delivery_connected',false,
   'read_does_not_clear_source',true);
END $mg$;
CREATE OR REPLACE FUNCTION notification_private.core_evaluate(
 p_notification_id uuid,p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE
 n public.notifications%rowtype;
 t public.todos%rowtype;
 pref jsonb;
 state jsonb;
 base jsonb;
 decision text:='NEEDS_VERIFICATION';
 reason text:='not_evaluated';
 version text;
 tier text:='P3';
 next_at timestamptz;
 ack_until timestamptz;
 source_typ text;
 source_key text;
 local_time timestamp;
 muted boolean;
 enabled boolean;
 v_policy notification_private.core_policy_limits%rowtype;
 v_deadline notification_private.core_verified_deadlines%rowtype;
 v_real_deadline timestamptz;
 v_risk_reason text;
 v_warning text;
 v_local_next_open timestamptz;
 v_sent_count integer:=0;
 v_oldest_sent timestamptz;
 v_latest_sent timestamptz;
 v_category_count integer:=0;
 v_user_count integer:=0;
 v_category_oldest timestamptz;
 v_user_oldest timestamptz;
 v_cap integer;
 v_cooldown interval;
 v_work_ack timestamptz;
 v_work_snooze timestamptz;
BEGIN
 IF p_notification_id IS NULL OR p_at IS NULL THEN
   RAISE EXCEPTION 'Notification ID and evaluation instant are required' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_policy FROM notification_private.core_policy_limits WHERE singleton=true;
 IF NOT FOUND THEN
   RAISE EXCEPTION 'Notification core policy configuration missing' USING ERRCODE='P0001';
 END IF;
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('decision','NEEDS_VERIFICATION',
     'reason_code','notification_not_found','policy_version',v_policy.policy_version,
     'notification_id',p_notification_id,'evaluated_at',p_at,
     'enforcement','preview_only');
 END IF;
 source_typ:=lower(btrim(coalesce(n.entity_type,'')));
 source_key:=btrim(coalesce(n.entity_id,''));
 tier:='P3'; -- A generic notification label is not verified P1/P0 business evidence.
 local_time:=p_at AT TIME ZONE 'Asia/Dhaka';
 v_local_next_open:=((CASE WHEN local_time::time < v_policy.push_start
   THEN local_time::date ELSE local_time::date+1 END)+v_policy.push_start)
   AT TIME ZONE 'Asia/Dhaka';
 base:=jsonb_build_object(
   'notification_id',n.id,'recipient_user_id',n.recipient_user_id,
   'entity_type',source_typ,'entity_id',source_key,
   'priority_tier',tier,'policy_version',v_policy.policy_version,
   'evaluated_at',p_at,'enforcement','preview_only',
   'read_is_business_completion',false,'source_version',null,'next_eligible_at',null,
   'deadline_verified',false,'actual_deadline_at',null,'risk_reason',null,
   'push_count_per_item_24h',0,'push_cap_per_item_24h',null,
   'snooze_deadline_conflict',false,'calendar_verified',false
 );
 IF n.recipient_user_id IS NULL OR source_typ='' OR source_key='' THEN
   decision:='NEEDS_VERIFICATION';reason:='missing_source_or_recipient';
 ELSIF n.status IN ('Completed','Cancelled','Expired') THEN
   decision:='SUPPRESS_RESOLVED';reason:='notification_terminal';
 ELSIF n.expires_at IS NOT NULL AND n.expires_at<=p_at THEN
   decision:='EXPIRED';reason:='notification_ttl_expired';
 ELSIF source_typ='todo' THEN
   IF source_key !~ '^[0-9]{1,18}$' THEN
     decision:='NEEDS_VERIFICATION';reason:='source_identifier_invalid';
   ELSE
     SELECT * INTO t FROM public.todos WHERE id::text=source_key;
     IF NOT FOUND THEN
       decision:='NEEDS_VERIFICATION';reason:='source_record_missing';
     ELSE
       version:=md5(concat_ws('|',coalesce(t.updated_at::text,'unset'),
         coalesce(t.status,''),coalesce(t.manager_status,''),
         coalesce(t.assigned_to_user_id,t.owner_user_id)::text,
         coalesce(t.solved_at::text,''),coalesce(t.deleted_at::text,'')));
       tier:=CASE WHEN coalesce(t.is_important,false) OR
        lower(coalesce(t.priority,'')) IN ('high','important','urgent','critical')
        THEN 'P2' ELSE 'P3' END;
       SELECT * INTO v_deadline FROM notification_private.core_verified_deadlines d
        WHERE d.entity_type='todo' AND d.entity_id=source_key
          AND d.recipient_user_id=n.recipient_user_id
          AND d.source_version=version
          AND d.verified_at<=p_at
          AND d.verified_basis IN ('manual_verified','authoritative_adapter');
       IF FOUND THEN
         v_real_deadline:=v_deadline.actual_deadline_at;
         IF v_real_deadline<=p_at THEN
           tier:='P1';v_risk_reason:='verified_deadline_breached';
         ELSIF v_real_deadline<=v_local_next_open
           AND (local_time::time>=time '17:15' OR local_time::time<v_policy.push_start) THEN
           tier:='P1';v_risk_reason:='verified_before_next_office_open';
         ELSIF v_policy.p1_warning_horizon IS NOT NULL
           AND v_real_deadline<=p_at+v_policy.p1_warning_horizon THEN
           tier:='P1';v_risk_reason:='verified_imminent_deadline';
         END IF;
       END IF;
       base:=base||jsonb_build_object('source_version',version,'priority_tier',tier,
          'deadline_verified',v_real_deadline IS NOT NULL,
          'actual_deadline_at',v_real_deadline,'risk_reason',v_risk_reason);
       IF NOT notification_private.todo_actionable(t) THEN
         decision:='SUPPRESS_RESOLVED';reason:='source_work_resolved';
       ELSIF coalesce(t.assigned_to_user_id,t.owner_user_id) IS DISTINCT FROM n.recipient_user_id THEN
         decision:='NEEDS_VERIFICATION';reason:='source_recipient_changed';
       ELSE
         SELECT max(w.acknowledged_until), max(w.snoozed_until)
           INTO v_work_ack,v_work_snooze
         FROM public.swa_work_items w
         WHERE w.source_module='todo' AND w.source_record_id=source_key
           AND w.owner_user_id=n.recipient_user_id
           AND w.completed_at IS NULL AND w.cancelled_at IS NULL;
         ack_until:=v_work_ack;
         IF n.snoozed_until>p_at OR v_work_snooze>p_at THEN
           next_at:=greatest(coalesce(n.snoozed_until,'-infinity'::timestamptz),
             coalesce(v_work_snooze,'-infinity'::timestamptz));
           decision:='SUPPRESS_SNOOZED';reason:='explicit_snooze_lease';
           base:=base||jsonb_build_object('snooze_deadline_conflict',
             v_real_deadline IS NOT NULL AND next_at>v_real_deadline);
         ELSIF ack_until>p_at THEN
           decision:='SUPPRESS_ACKNOWLEDGED';reason:='explicit_work_acknowledgement';
           next_at:=ack_until;
           base:=base||jsonb_build_object('snooze_deadline_conflict',
             v_real_deadline IS NOT NULL AND ack_until>v_real_deadline);
         ELSE
           BEGIN
             pref:=public.notification_effective_preference(n.recipient_user_id,n.category);
           EXCEPTION WHEN OTHERS THEN
             RETURN base||jsonb_build_object('decision','NEEDS_VERIFICATION',
               'reason_code','preference_evaluation_failed','next_eligible_at',null);
           END;
           enabled:=coalesce((pref->>'notification_enabled')::boolean,true);
           muted:=NOT coalesce((pref->>'system_push_enabled')::boolean,true);
           IF NOT enabled THEN
             decision:='BLOCKED_BY_PREFERENCE';reason:='notification_master_disabled';
           ELSIF n.first_delivered_at IS NOT NULL OR n.status='Dismissed' THEN
             decision:='SUPPRESS_DUPLICATE';reason:='notification_occurrence_already_surfaced';
           ELSIF n.scheduled_for IS NOT NULL AND n.scheduled_for>p_at THEN
             decision:='DEFER';reason:='notification_not_due';next_at:=n.scheduled_for;
           ELSIF muted THEN
             decision:='IN_APP_ONLY';reason:='device_push_disabled';
           ELSE
             -- Real accepted network send occurrences: distinct notification IDs,
             -- not delivery rows, because multi-device fan-out is ONE user alert.
             SELECT count(*), min(first_send),max(first_send)
               INTO v_sent_count,v_oldest_sent,v_latest_sent
             FROM (
               SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
               FROM public.notifications h
               JOIN public.notification_deliveries d ON d.notification_id=h.id
               WHERE h.recipient_user_id=n.recipient_user_id
                 AND lower(coalesce(h.entity_type,''))=source_typ
                 AND h.entity_id=source_key
                 AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                 AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                 AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
               GROUP BY h.id
             ) accepted;
             v_cap:=CASE tier WHEN 'P2' THEN v_policy.p2_item_cap_24h
               WHEN 'P3' THEN v_policy.p3_item_cap_24h
               WHEN 'P1' THEN v_policy.p1_item_cap_24h ELSE NULL END;
             v_cooldown:=CASE tier WHEN 'P2' THEN v_policy.p2_cooldown
               WHEN 'P3' THEN v_policy.p3_cooldown ELSE NULL END;
             base:=base||jsonb_build_object('push_count_per_item_24h',v_sent_count,
               'push_cap_per_item_24h',v_cap,'last_actual_push_at',v_latest_sent);
             IF tier='P1' AND
                (NOT v_policy.p1_push_enabled OR v_cap IS NULL) THEN
               decision:='NEEDS_VERIFICATION';reason:='p1_delivery_policy_not_approved';
             ELSIF tier='P0' THEN
               decision:='NEEDS_VERIFICATION';reason:='p0_emergency_policy_not_approved';
             ELSIF v_cap IS NOT NULL AND v_sent_count>=v_cap THEN
               decision:='DEFER';reason:='rolling_per_item_push_cap';
               next_at:=v_oldest_sent+interval '24 hours';
             ELSIF v_cooldown IS NOT NULL AND v_latest_sent IS NOT NULL
               AND v_latest_sent+v_cooldown>p_at THEN
               decision:='DEFER';reason:='per_item_push_cooldown';
               next_at:=v_latest_sent+v_cooldown;
             ELSE
               -- Optional user/category global caps default NULL until approved.
               IF v_policy.user_cap_24h IS NOT NULL OR
                  v_policy.category_cap_24h IS NOT NULL THEN
                 SELECT count(*),min(first_send) INTO v_user_count,v_user_oldest
                 FROM (SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
                   FROM public.notifications h JOIN public.notification_deliveries d
                     ON d.notification_id=h.id
                   WHERE h.recipient_user_id=n.recipient_user_id
                     AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
                   GROUP BY h.id) accepted_user;
                 SELECT count(*),min(first_send) INTO v_category_count,v_category_oldest
                 FROM (SELECT h.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) first_send
                   FROM public.notifications h JOIN public.notification_deliveries d
                     ON d.notification_id=h.id
                   WHERE h.recipient_user_id=n.recipient_user_id AND h.category=n.category
                     AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
                     AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)<=p_at
                   GROUP BY h.id) accepted_category;
               END IF;
               base:=base||jsonb_build_object('push_count_per_user_24h',v_user_count,
                 'push_count_per_category_24h',v_category_count);
               IF v_policy.user_cap_24h IS NOT NULL
                  AND v_user_count>=v_policy.user_cap_24h THEN
                 decision:='DEFER';reason:='rolling_per_user_push_cap';
                 next_at:=v_user_oldest+interval '24 hours';
               ELSIF v_policy.category_cap_24h IS NOT NULL
                  AND v_category_count>=v_policy.category_cap_24h THEN
                 decision:='DEFER';reason:='rolling_per_category_push_cap';
                 next_at:=v_category_oldest+interval '24 hours';
               ELSIF local_time::time<v_policy.push_start
                  OR local_time::time>=v_policy.push_end THEN
                 decision:='DIGEST';reason:='deferred_for_office_hours';
                 next_at:=((CASE WHEN local_time::time>=v_policy.push_end
                   THEN local_time::date+1 ELSE local_time::date END)
                   +v_policy.morning_digest_time) AT TIME ZONE 'Asia/Dhaka';
               ELSE
                 decision:='SEND_NOW';reason:='actionable_verified_policy_candidate';
               END IF;
             END IF;
           END IF;
         END IF;
       END IF;
     END IF;
   END IF;
 ELSE
   -- Existing general source_state only checks terminal state, not ownership/version.
   -- Do not auto-authorize a Web Push based on unsupported/partial adapters.
   BEGIN
     state:=public.notification_source_state(source_typ,source_key);
     IF coalesce((state->>'supported')::boolean,false) AND
        coalesce((state->>'resolved')::boolean,false) THEN
       decision:='SUPPRESS_RESOLVED';reason:='source_work_resolved';
     ELSE
       decision:='NEEDS_VERIFICATION';
       reason:=CASE WHEN coalesce((state->>'supported')::boolean,false)
         THEN 'source_recipient_and_version_unverified'
         ELSE 'unsupported_source_adapter' END;
     END IF;
   EXCEPTION WHEN OTHERS THEN
     decision:='NEEDS_VERIFICATION';reason:='source_check_failed';
   END;
 END IF;
 RETURN base||jsonb_build_object('decision',decision,'reason_code',reason,
   'reason_codes',jsonb_build_array(reason),'next_eligible_at',next_at);
END $mg$;

REVOKE ALL ON FUNCTION public.notification_source_interaction(text,text,text,timestamptz,bigint) FROM authenticated;
COMMIT;
