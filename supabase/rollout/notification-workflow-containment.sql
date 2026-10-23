-- Explicit containment only; never run as a production test.
-- Preserves all original and new source/task/audit/history rows.
BEGIN;
SET LOCAL lock_timeout='5s';
UPDATE notification_private.governance_control SET enabled=false WHERE singleton;
UPDATE notification_private.digest_bridge_control SET enabled=false WHERE singleton;
DROP TRIGGER IF EXISTS notification_todo_completion_guard ON public.todos;
DROP TRIGGER IF EXISTS notification_work_deadline ON public.todos;
DROP TRIGGER IF EXISTS notification_module_work ON public.transfers;
DROP TRIGGER IF EXISTS notification_module_work ON public.exits;
DROP TRIGGER IF EXISTS notification_module_work ON public.leaves;
DROP TRIGGER IF EXISTS notification_module_work ON public.uniform_supply_orders;
DROP TRIGGER IF EXISTS notification_module_work ON public.uniform_delivery_issues;
DROP TRIGGER IF EXISTS notification_module_work ON public.uniform_delivery_bills;
DROP TRIGGER IF EXISTS notification_module_work ON public.recruitment_archive;
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
  v_quota jsonb;
  v_now timestamptz:=clock_timestamp();
  v_next timestamptz;
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
      btrim(p_worker_id)
  FOR UPDATE;

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

  SELECT enabled INTO v_governance FROM notification_private.governance_control WHERE singleton;
  SELECT enabled INTO v_bridge FROM notification_private.digest_bridge_control WHERE singleton;
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false) AND EXISTS(
    SELECT 1 FROM notification_private.core_policy_limits p WHERE singleton AND
    ((v_now AT TIME ZONE 'Asia/Dhaka')::time<p.push_start OR (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end)
  ) THEN
    SELECT (((v_now AT TIME ZONE 'Asia/Dhaka')::date+
      CASE WHEN (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end THEN 1 ELSE 0 END)+p.push_start)
      AT TIME ZONE 'Asia/Dhaka' INTO v_next FROM notification_private.core_policy_limits p WHERE singleton;
    UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
      attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
    RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','outside_routine_push_window');
  END IF;

  -- Source ACK/Snooze is an explicit new user action, effective in V1 too.
  -- Deferral never completes or removes the source and does not consume retries.
  SELECT greatest(a.acknowledged_until,a.snoozed_until) INTO v_next
  FROM notification_private.source_interactions a WHERE a.recipient_user_id=v_notification.recipient_user_id
    AND a.entity_type=v_notification.entity_type AND a.entity_id=v_notification.entity_id;
  IF v_next>v_now THEN
    UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
      attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
    RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','explicit_source_work_lease');
  END IF;

  v_source_blocked := notification_private.push_source_ineligible(
    v_notification.entity_type, v_notification.entity_id, v_notification.recipient_user_id
  );

  IF coalesce(v_governance,false) AND coalesce(v_bridge,false) AND v_notification.entity_type<>'digest' THEN
    v_source_blocked:=v_source_blocked OR NOT coalesce((notification_private.source_snapshot(
      v_notification.entity_type,v_notification.entity_id,v_notification.recipient_user_id)->>'actionable')::boolean,false);
  END IF;
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

  -- Serializes competing job dispatches for this recipient, including digest
  -- and direct-source notifications. Existing preference/source checks ran first.
  IF coalesce(v_governance,false) AND coalesce(v_bridge,false)
    AND EXISTS(SELECT 1 FROM public.notification_deliveries WHERE notification_id=v_notification.id
      AND channel='WebPush' AND delivery_status IN ('Pending','Failed')) THEN
    -- Consistent lock order with result recording: own job, then recipient.
    PERFORM 1 FROM public.notification_jobs WHERE id=v_job.id FOR UPDATE;
    v_quota:=notification_private.reserve_push(v_notification.id,v_now);
    IF v_quota->>'reason'='outside_routine_push_window' THEN
      SELECT (((v_now AT TIME ZONE 'Asia/Dhaka')::date+
        CASE WHEN (v_now AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end THEN 1 ELSE 0 END)+p.push_start)
        AT TIME ZONE 'Asia/Dhaka' INTO v_next FROM notification_private.core_policy_limits p WHERE singleton;
      UPDATE public.notification_jobs SET job_status='Pending',run_at=v_next,
        attempt_count=greatest(0,attempt_count-1),locked_at=NULL,locked_by=NULL WHERE id=v_job.id;
      RETURN jsonb_build_object('deferred',true,'deliveries','[]'::jsonb,'reason','outside_routine_push_window');
    END IF;
    IF NOT coalesce((v_quota->>'allowed')::boolean,false) THEN
      UPDATE public.notification_deliveries SET delivery_status='Skipped',provider_status='GovernanceSuppressed',
        response_metadata=coalesce(response_metadata,'{}'::jsonb)||jsonb_build_object('gate_reason',v_quota->>'reason','checked_at',v_now)
      WHERE notification_id=v_notification.id AND channel='WebPush' AND delivery_status IN ('Pending','Failed');
    END IF;
  END IF;

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
$function$
;
CREATE OR REPLACE FUNCTION public.swa_act(p_item_id uuid, p_expected_version integer, p_action text, p_value text DEFAULT NULL::text, p_occurred_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_session_id uuid DEFAULT NULL::uuid)
 RETURNS swa_work_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE w public.swa_work_items; before_row jsonb; now_at timestamptz:=clock_timestamp(); occurred timestamptz;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 SELECT * INTO w FROM public.swa_work_items WHERE id=p_item_id AND owner_user_id=auth.uid() FOR UPDATE;
 IF w.id IS NULL THEN RAISE EXCEPTION 'Work item not found' USING ERRCODE='P0002'; END IF;
 IF p_expected_version IS DISTINCT FROM w.row_version THEN
   RAISE EXCEPTION 'Conflict: work item changed on another device. Refresh before saving.' USING ERRCODE='40001';
 END IF;
 IF p_session_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.swa_brief_sessions WHERE id=p_session_id AND owner_user_id=auth.uid() AND closed_at IS NULL)
 THEN RAISE EXCEPTION 'Invalid or closed briefing session'; END IF;
 before_row:=to_jsonb(w);
 occurred:=coalesce(p_occurred_at,now_at);
 IF occurred>now_at+interval '5 minutes' THEN RAISE EXCEPTION 'Future event time not permitted'; END IF;
 IF w.stage IN ('completed','cancelled') AND p_action<>'reopen' THEN
   RAISE EXCEPTION 'Reopen the resolved work item first';
 END IF;
 CASE p_action
 WHEN 'informed' THEN
   IF NOT w.manager_required THEN RAISE EXCEPTION 'Manager briefing not required'; END IF;
   IF p_value NOT IN ('phone','in_person','message','paper','other') THEN RAISE EXCEPTION 'Select communication channel'; END IF;
   w.manager_informed_at:=occurred;w.manager_channel:=p_value;
   IF w.manager_decision='none' THEN w.manager_decision:='pending'; END IF;
   w.stage:='waiting_manager';
 WHEN 'decision' THEN
   IF NOT w.manager_required OR p_value NOT IN ('approved','rejected','pending','needs_info','postponed') THEN RAISE EXCEPTION 'Invalid manager decision'; END IF;
   w.manager_decision:=p_value;w.manager_decision_at:=occurred;w.manager_recorded_at:=now_at;
   IF p_value IN ('approved','rejected') THEN
     w.stage:='active';w.next_action:=CASE WHEN w.communication_required THEN 'সংশ্লিষ্ট ব্যক্তি/প্রজেক্টকে সিদ্ধান্ত জানান' WHEN p_value='rejected' THEN 'প্রত্যাখ্যানের ফল নথিভুক্ত করে কাজ বন্ধ করুন' ELSE 'পরবর্তী অনুমোদিত পদক্ষেপ গ্রহণ করুন' END;
   ELSE w.stage:='waiting_manager'; END IF;
 WHEN 'communicated' THEN
   w.communicated_at:=occurred; w.stage:='active';
 WHEN 'executed' THEN
   IF w.approval_required AND w.manager_decision<>'approved' THEN RAISE EXCEPTION 'Required approval not recorded'; END IF;
   w.executed_at:=occurred; w.stage:=CASE WHEN w.verification_required THEN 'verification' ELSE 'active' END;
 WHEN 'verified' THEN
   IF w.execution_required AND w.executed_at IS NULL AND NOT(w.approval_required AND w.manager_decision='rejected') THEN RAISE EXCEPTION 'Execution must be recorded first'; END IF;
   w.verified_at:=occurred;w.stage:='active';
 WHEN 'complete' THEN
   IF (w.manager_required AND w.manager_informed_at IS NULL) OR
      (w.approval_required AND w.manager_decision NOT IN ('approved','rejected')) OR
      (w.communication_required AND w.communicated_at IS NULL) OR
      (w.execution_required AND w.executed_at IS NULL AND NOT(w.approval_required AND w.manager_decision='rejected')) OR
      (w.verification_required AND w.verified_at IS NULL) THEN
     RAISE EXCEPTION 'Required manager, communication, execution or verification steps remain';
   END IF;
   w.stage:='completed';w.completed_at:=now_at;
 WHEN 'cancel' THEN
   IF length(btrim(coalesce(p_value,'')))<3 THEN RAISE EXCEPTION 'Cancellation reason required'; END IF;
   w.stage:='cancelled';w.cancelled_at:=now_at;
 WHEN 'reopen' THEN
   IF w.stage NOT IN ('completed','cancelled') OR length(btrim(coalesce(p_value,'')))<3 THEN RAISE EXCEPTION 'Reopen reason/next action required'; END IF;
   w.stage:='active';w.completed_at:=NULL;w.cancelled_at:=NULL;
   w.manager_informed_at:=NULL;w.manager_decision:='none';w.manager_decision_at:=NULL;
   w.communicated_at:=NULL;w.executed_at:=NULL;w.verified_at:=NULL;
   w.next_action:=left(p_value,400); w.next_review_at:=now_at+interval '1 day';
 WHEN 'ack' THEN w.acknowledged_until:=now_at+interval '4 hours';
 WHEN 'snooze' THEN
   IF p_value IS NULL OR p_value::timestamptz<=now_at OR p_value::timestamptz>now_at+interval '30 days'
   THEN RAISE EXCEPTION 'Snooze must be within 30 days'; END IF;
   w.snoozed_until:=p_value::timestamptz;
 WHEN 'followup' THEN
   IF p_value IS NULL OR p_value::timestamptz<now_at-interval '1 minute'
   THEN RAISE EXCEPTION 'Invalid next review'; END IF;
   w.next_review_at:=p_value::timestamptz;
 WHEN 'next_action' THEN
   IF length(btrim(coalesce(p_value,''))) NOT BETWEEN 3 AND 400 THEN RAISE EXCEPTION 'Describe next action'; END IF;
   w.next_action:=btrim(p_value);w.stage:='active';
 WHEN 'waiting_external' THEN
   IF length(btrim(coalesce(p_value,'')))<2 THEN RAISE EXCEPTION 'External party required'; END IF;
   w.next_party:=left(btrim(p_value),200);w.stage:='waiting_external';
 ELSE RAISE EXCEPTION 'Unsupported work action';
 END CASE;
 w.row_version:=w.row_version+1;w.updated_at:=now_at;
 UPDATE public.swa_work_items SET
 stage=w.stage,manager_informed_at=w.manager_informed_at,manager_channel=w.manager_channel,
 manager_decision=w.manager_decision,manager_decision_at=w.manager_decision_at,manager_recorded_at=w.manager_recorded_at,
 next_action=w.next_action,next_party=w.next_party,next_review_at=w.next_review_at,
 communicated_at=w.communicated_at,executed_at=w.executed_at,verified_at=w.verified_at,
 acknowledged_until=w.acknowledged_until,snoozed_until=w.snoozed_until,
 completed_at=w.completed_at,cancelled_at=w.cancelled_at,row_version=w.row_version,updated_at=w.updated_at
 WHERE id=w.id;
 INSERT INTO public.swa_work_events(item_id,session_id,actor_user_id,event_type,event_at,recorded_at,channel,payload)
 VALUES(w.id,p_session_id,auth.uid(),p_action,occurred,now_at,
 CASE WHEN p_action='informed' THEN p_value ELSE NULL END,
 jsonb_build_object('value',left(coalesce(p_value,''),400),'from_version',p_expected_version,'to_version',w.row_version));
 RETURN w;
END $function$
;
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
$function$
;
CREATE OR REPLACE FUNCTION swa_private.sync_todo(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE t public.todos; uid uuid; terminal boolean; cat text; item_subject text;
BEGIN
 SELECT * INTO t FROM public.todos WHERE id=p_id;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT user_id INTO uid FROM swa_private.operator_ids LIMIT 1;
 IF uid IS NULL THEN RETURN; END IF;
 terminal:=t.deleted_at IS NOT NULL OR t.solved_at IS NOT NULL OR
 lower(coalesce(t.status,'')) IN ('solved_approved','solved_rejected','solved','complete','completed','cancelled','canceled','done','closed','resolved');
 cat:=CASE WHEN lower(coalesce(t.category,''))='permission' THEN 'inform_manager'
 WHEN lower(coalesce(t.category,''))='task' THEN 'my_task'
 ELSE 'general' END;
 item_subject:=left(coalesce(nullif(btrim(t.note_bn),''),nullif(btrim(t.note),''),'To-Do #'||t.id),500);
 IF terminal THEN
   UPDATE public.swa_work_items SET source_state='terminal',updated_at=clock_timestamp()
   WHERE source_module='todo' AND source_record_id=t.id::text AND source_state IS DISTINCT FROM 'terminal';
   RETURN;
 END IF;
 INSERT INTO public.swa_work_items(capture_key,owner_user_id,source_module,source_record_id,source_state,
 category,subject,requestor,project,priority,manager_required,communication_required,execution_required,
 stage,next_action,next_review_at,captured_after_hours,captured_at)
 VALUES(gen_random_uuid(),uid,'todo',t.id::text,coalesce(t.status,'pending'),
 cat,item_subject,left(t.who,200),left(t.project,200),
 CASE WHEN t.is_important THEN 'important' ELSE 'routine' END,cat='inform_manager',
 cat='inform_manager',cat='my_task',
 CASE WHEN cat='inform_manager' THEN 'waiting_manager' ELSE 'active' END,
 'মূল To-Do অনুসারে পরবর্তী পদক্ষেপ পর্যালোচনা করুন',
 coalesce(t.next_reminder_at,((clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date+1)::timestamp AT TIME ZONE 'Asia/Dhaka'),
 false,coalesce(t.created_at,clock_timestamp()))
 ON CONFLICT(source_module,source_record_id) WHERE source_record_id IS NOT NULL DO UPDATE
 SET source_state=EXCLUDED.source_state,
     subject=CASE WHEN public.swa_work_items.stage IN ('completed','cancelled') THEN public.swa_work_items.subject ELSE EXCLUDED.subject END,
     updated_at=clock_timestamp();
END $function$
;
REVOKE EXECUTE ON FUNCTION public.notification_work_get(bigint),public.notification_work_save(bigint,integer,uuid,text,jsonb),public.notification_work_capture(uuid,jsonb),public.notification_work_brief_summary(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.swa_capture(uuid,jsonb) TO authenticated;
-- Restore the prior source planner, retaining all private data.
CREATE OR REPLACE FUNCTION notification_private.digest_plan(p_recipient uuid,p_day date,p_kind text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE j jsonb; items jsonb; groups jsonb;
BEGIN
 j:=notification_private.digest_source_plan(p_recipient,p_day,p_kind,p_at);
 SELECT coalesce(jsonb_agg(x),'[]'::jsonb) INTO items FROM jsonb_array_elements(j->'items') x
 JOIN public.todos t ON t.id::text=x->>'todo_id' WHERE coalesce(t.reminder_enabled,false)
 AND NOT EXISTS(SELECT 1 FROM notification_private.source_interactions a WHERE a.recipient_user_id=p_recipient AND a.entity_type='todo' AND a.entity_id=t.id::text AND (a.acknowledged_until>p_at OR a.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.swa_work_items w WHERE w.owner_user_id=p_recipient AND w.source_module='todo' AND w.source_record_id=t.id::text AND w.completed_at IS NULL AND w.cancelled_at IS NULL AND (w.acknowledged_until>p_at OR w.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.recipient_user_id=p_recipient AND n.entity_type='todo' AND n.entity_id=t.id::text AND n.snoozed_until>p_at);
 SELECT coalesce(jsonb_object_agg(g,c),'{}') INTO groups FROM (SELECT x->>'group_key' g,count(*) c FROM jsonb_array_elements(items) x GROUP BY 1) a;
 RETURN j||jsonb_build_object('items',items,'item_count',jsonb_array_length(items),'groups',groups,'risk_count',(SELECT count(*) FROM jsonb_array_elements(items) x WHERE x->>'group_key' IN ('OVERDUE','BEFORE_NEXT_OPEN_RISK')));
END $fn$;
COMMIT;

