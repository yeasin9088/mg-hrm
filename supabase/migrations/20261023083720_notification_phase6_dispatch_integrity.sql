-- Phase 6: additive dispatch integrity. Does not activate either V2 gate.
-- Source records, subscriptions and historical notifications are never reset.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

CREATE TABLE notification_private.source_interactions (
 recipient_user_id uuid NOT NULL, entity_type text NOT NULL, entity_id text NOT NULL,
 revision bigint NOT NULL DEFAULT 1,
 acknowledged_until timestamptz, snoozed_until timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(recipient_user_id,entity_type,entity_id)
);
CREATE TABLE notification_private.interaction_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 recipient_user_id uuid NOT NULL, entity_type text NOT NULL, entity_id text NOT NULL,
 action text NOT NULL, revision bigint NOT NULL, lease_until timestamptz,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
-- A reservation covers the external side effect until its outcome is recorded.
-- An unknown/crashed attempt is conservatively charged for 24h; never blindly
-- release it on a lock timeout (the provider could already have accepted it).
CREATE TABLE notification_private.push_occurrences (
 notification_id uuid NOT NULL REFERENCES public.notifications(id),
 recipient_user_id uuid NOT NULL, entity_type text NOT NULL, entity_id text NOT NULL,
 source_version text NOT NULL, category text NOT NULL, priority_tier text NOT NULL,
 state text NOT NULL CHECK(state IN ('Reserved','Accepted','Released')),
 reserved_at timestamptz NOT NULL, accepted_at timestamptz,
 PRIMARY KEY(notification_id,entity_type,entity_id)
);
CREATE INDEX push_occurrences_recipient_time ON notification_private.push_occurrences
 (recipient_user_id,reserved_at) WHERE state <> 'Released';
ALTER TABLE notification_private.source_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_private.interaction_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_private.push_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_private.governance_control ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.source_interactions,notification_private.interaction_audit,
 notification_private.push_occurrences FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE notification_private.interaction_audit_id_seq FROM PUBLIC,anon,authenticated,service_role;

-- Explicit, closed adapter registry. Dynamic SQL uses only the literal table
-- names below, and only binds identifiers as values. Raw row data never leaves
-- this function. No inferred dates, approvals or employee/project writes.
CREATE FUNCTION notification_private.source_snapshot(p_type text,p_id text,p_recipient uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE typ text:=lower(btrim(coalesce(p_type,''))); tab text; keycol text:='id';
 r jsonb; st text; active boolean:=true; tier text:='P3'; ver text;
BEGIN
 IF p_recipient IS NULL OR NOT EXISTS(SELECT 1 FROM swa_private.operator_ids o
   JOIN public.profiles p ON p.id=o.user_id AND p.is_active WHERE o.user_id=p_recipient)
 THEN RETURN jsonb_build_object('supported',true,'actionable',false,'reason','recipient_not_operator'); END IF;
 CASE typ
 WHEN 'todo' THEN tab:='todos';
 WHEN 'transfer' THEN tab:='transfers';
 WHEN 'exit' THEN tab:='exits';
 WHEN 'leave' THEN tab:='leaves';
 WHEN 'uniform_supply_order' THEN tab:='uniform_supply_orders';
 WHEN 'uniform_delivery_issue' THEN tab:='uniform_delivery_issues';
 WHEN 'uniform_delivery_bill' THEN tab:='uniform_delivery_bills';
 WHEN 'disciplinary' THEN tab:='disciplinary';
 WHEN 'meeting' THEN tab:='meetings';
 WHEN 'recruitment' THEN tab:='recruitment_archive';keycol:='archive_id';
 ELSE RETURN jsonb_build_object('supported',false,'actionable',false,'reason','unsupported_source_adapter');
 END CASE;
 IF p_id IS NULL OR length(p_id)>128 OR (keycol='id' AND p_id !~ '^[0-9]{1,18}$') THEN
 RETURN jsonb_build_object('supported',true,'actionable',false,'reason','source_identifier_invalid'); END IF;
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE t.%I::text=$1',tab,keycol) INTO r USING p_id;
 IF r IS NULL THEN RETURN jsonb_build_object('supported',true,'actionable',false,'reason','source_missing'); END IF;
 st:=lower(btrim(coalesce(r->>'status',r->>'resolution_status',r->>'result','')));
 active:=(r->>'deleted_at') IS NULL;
 IF typ='todo' THEN
  active:=active AND r->>'solved_at' IS NULL AND st NOT IN ('closed','cancelled','solved','completed')
    AND coalesce(r->>'assigned_to_user_id',r->>'owner_user_id')=p_recipient::text;
  tier:=CASE WHEN coalesce((r->>'is_important')::boolean,false)
    OR lower(coalesce(r->>'priority','')) IN ('high','important','urgent','critical') THEN 'P2' ELSE 'P3' END;
  SELECT md5(concat_ws('|',coalesce(t.updated_at::text,'unset'),coalesce(t.status,''),
    coalesce(t.manager_status,''),coalesce(t.assigned_to_user_id,t.owner_user_id)::text,
    coalesce(t.solved_at::text,''),coalesce(t.deleted_at::text,''))) INTO ver FROM public.todos t WHERE t.id::text=p_id;
 ELSIF typ='transfer' THEN
  active:=active AND st IN ('scheduled','joining pending') AND r->>'joining_confirmed_at' IS NULL
    AND r->>'not_joined_at' IS NULL AND r->>'cancelled_at' IS NULL AND r->>'completed_at' IS NULL
    AND r->>'effective_date' IS NOT NULL
    AND (r->>'effective_date')::date <= (clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::date;
  tier:='P2';
 ELSIF typ='exit' THEN active:=active AND st NOT IN ('completed','cancelled');tier:='P2';
 ELSIF typ='leave' THEN active:=active AND st NOT IN ('approved','rejected','cancelled','completed','closed');tier:='P2';
 ELSIF typ='uniform_supply_order' THEN active:=active AND st NOT IN ('completed','cancelled');
 ELSIF typ='uniform_delivery_issue' THEN active:=active AND st NOT IN ('resolved','cancelled');tier:='P2';
 ELSIF typ='uniform_delivery_bill' THEN active:=active AND NOT coalesce((r->>'paid')::boolean,false);
 ELSIF typ='recruitment' THEN active:=active AND st NOT IN ('rejected','withdrawn','hired','selected','cancelled');
 -- Meeting/disciplinary are informational record events, not invented approval
 -- or punitive workflows. Their reminders are never generated from this adapter.
 END IF;
 IF ver IS NULL THEN ver:=md5(r::text); END IF;
 RETURN jsonb_build_object('supported',true,'actionable',coalesce(active,false),'source_version',ver,
   'priority_tier',tier,'reason',CASE WHEN active THEN 'authoritative_source_current' ELSE 'source_resolved_or_ineligible' END);
EXCEPTION WHEN OTHERS THEN
 RETURN jsonb_build_object('supported',true,'actionable',false,'reason','source_validation_failed');
END $fn$;
REVOKE ALL ON FUNCTION notification_private.source_snapshot(text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.notification_source_interaction(p_entity_type text,p_entity_id text,
 p_action text,p_until timestamptz,p_expected_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE r notification_private.source_interactions%rowtype; s jsonb; deadline_at timestamptz;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 s:=notification_private.source_snapshot(p_entity_type,p_entity_id,auth.uid());
 IF NOT coalesce((s->>'actionable')::boolean,false) THEN RAISE EXCEPTION 'Source unavailable or resolved' USING ERRCODE='22023'; END IF;
 IF p_action IS NULL OR p_action NOT IN ('ack','snooze','resume') OR p_expected_revision IS NULL THEN
 RAISE EXCEPTION 'Valid interaction and revision required' USING ERRCODE='22023'; END IF;
 IF p_action<>'resume' AND (p_until IS NULL OR p_until<=clock_timestamp() OR p_until>clock_timestamp()+interval '7 days') THEN
 RAISE EXCEPTION 'Lease must end within the next 7 days' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,6316));
 SELECT * INTO r FROM notification_private.source_interactions WHERE recipient_user_id=auth.uid()
   AND entity_type=p_entity_type AND entity_id=p_entity_id FOR UPDATE;
 IF coalesce(r.revision,0)<>p_expected_revision THEN RAISE EXCEPTION 'Interaction revision conflict; reload' USING ERRCODE='40001'; END IF;
 SELECT actual_deadline_at INTO deadline_at FROM notification_private.core_verified_deadlines
 WHERE entity_type=p_entity_type AND entity_id=p_entity_id AND recipient_user_id=auth.uid()
  AND source_version=s->>'source_version';
 IF p_action<>'resume' AND deadline_at IS NOT NULL AND p_until>deadline_at THEN
 RAISE EXCEPTION 'Lease crosses a verified deadline; choose an earlier time' USING ERRCODE='22023'; END IF;
 INSERT INTO notification_private.source_interactions(recipient_user_id,entity_type,entity_id,revision,acknowledged_until,snoozed_until)
 VALUES(auth.uid(),p_entity_type,p_entity_id,p_expected_revision+1,
  CASE WHEN p_action='ack' THEN p_until END,CASE WHEN p_action='snooze' THEN p_until END)
 ON CONFLICT(recipient_user_id,entity_type,entity_id) DO UPDATE SET
 revision=EXCLUDED.revision,acknowledged_until=EXCLUDED.acknowledged_until,
 snoozed_until=EXCLUDED.snoozed_until,updated_at=clock_timestamp() RETURNING * INTO r;
 INSERT INTO notification_private.interaction_audit(recipient_user_id,entity_type,entity_id,action,revision,lease_until)
 VALUES(auth.uid(),p_entity_type,p_entity_id,p_action,r.revision,CASE WHEN p_action<>'resume' THEN p_until END);
 RETURN jsonb_build_object('saved',true,'revision',r.revision,'acknowledged_until',r.acknowledged_until,
   'snoozed_until',r.snoozed_until,'source_completed',false);
END $fn$;
REVOKE ALL ON FUNCTION public.notification_source_interaction(text,text,text,timestamptz,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_source_interaction(text,text,text,timestamptz,bigint) TO authenticated;

-- Interactions suppress future reminders across notifications/devices; read
-- and dismissed state are intentionally absent. Keep phase3 planner available
-- as an internal source enumeration, including its verified-deadline grouping.
ALTER FUNCTION notification_private.digest_plan(uuid,date,text,timestamptz) RENAME TO digest_source_plan;
CREATE FUNCTION notification_private.digest_plan(p_recipient uuid,p_day date,p_kind text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE j jsonb; items jsonb; groups jsonb;
BEGIN
 j:=notification_private.digest_source_plan(p_recipient,p_day,p_kind,p_at);
 SELECT coalesce(jsonb_agg(x),'[]'::jsonb) INTO items FROM jsonb_array_elements(j->'items') x
 JOIN public.todos t ON t.id::text=x->>'todo_id'
 WHERE coalesce(t.reminder_enabled,false)
 AND NOT EXISTS(SELECT 1 FROM notification_private.source_interactions a WHERE a.recipient_user_id=p_recipient
  AND a.entity_type='todo' AND a.entity_id=t.id::text
  AND (a.acknowledged_until>p_at OR a.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.swa_work_items w WHERE w.owner_user_id=p_recipient AND w.source_module='todo'
  AND w.source_record_id=t.id::text AND w.completed_at IS NULL AND w.cancelled_at IS NULL
  AND (w.acknowledged_until>p_at OR w.snoozed_until>p_at))
 AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.recipient_user_id=p_recipient
  AND n.entity_type='todo' AND n.entity_id=t.id::text AND n.snoozed_until>p_at);
 SELECT coalesce(jsonb_object_agg(g,c),'{}'::jsonb) INTO groups FROM
 (SELECT x->>'group_key' g,count(*) c FROM jsonb_array_elements(items) x GROUP BY 1) a;
 RETURN j||jsonb_build_object('items',items,'item_count',jsonb_array_length(items),'groups',groups,
  'risk_count',(SELECT count(*) FROM jsonb_array_elements(items) x WHERE x->>'group_key' IN ('OVERDUE','BEFORE_NEXT_OPEN_RISK')));
END $fn$;
REVOKE ALL ON FUNCTION notification_private.digest_source_plan(uuid,date,text,timestamptz),
 notification_private.digest_plan(uuid,date,text,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_plan(uuid,date,text,timestamptz) TO service_role;

-- One source occurrence per user even with several device deliveries. All
-- callers must hold the recipient advisory lock (the dispatcher below does).
CREATE FUNCTION notification_private.push_quota_allowed(p_notification uuid,p_recipient uuid,
 p_type text,p_id text,p_category text,p_tier text,p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE p notification_private.core_policy_limits%rowtype; c int; last_at timestamptz; cool interval; cap int;
BEGIN
 SELECT * INTO STRICT p FROM notification_private.core_policy_limits WHERE singleton;
 cap:=CASE WHEN p_tier='P2' THEN p.p2_item_cap_24h ELSE p.p3_item_cap_24h END;
 cool:=CASE WHEN p_tier='P2' THEN p.p2_cooldown ELSE p.p3_cooldown END;
 WITH history AS (
  SELECT n.id,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) at FROM public.notifications n
  JOIN public.notification_deliveries d ON d.notification_id=n.id
  WHERE n.recipient_user_id=p_recipient AND n.entity_type=p_type AND n.entity_id=p_id
   AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered') GROUP BY n.id
  UNION ALL SELECT o.notification_id,coalesce(o.accepted_at,o.reserved_at) FROM notification_private.push_occurrences o
  WHERE o.recipient_user_id=p_recipient AND o.entity_type=p_type AND o.entity_id=p_id AND o.state<>'Released'
 ), occurrences AS (SELECT id,min(at) at FROM history WHERE id<>p_notification GROUP BY id)
 SELECT count(*),max(at) INTO c,last_at FROM occurrences WHERE at>p_at-interval '24 hours' AND at<=p_at;
 IF c>=cap OR (cool IS NOT NULL AND last_at+cool>p_at) THEN RETURN false; END IF;
 -- Global limits count a digest ONCE, not once for each included task.
 WITH history AS (
  SELECT n.id,n.category,min(coalesce(d.sent_at,d.delivered_at,d.attempted_at)) at FROM public.notifications n
  JOIN public.notification_deliveries d ON d.notification_id=n.id WHERE n.recipient_user_id=p_recipient
   AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered') GROUP BY n.id,n.category
  UNION ALL SELECT o.notification_id,o.category,coalesce(o.accepted_at,o.reserved_at)
   FROM notification_private.push_occurrences o WHERE o.recipient_user_id=p_recipient AND o.state<>'Released'
 ), occurrences AS (SELECT id,min(at) at,bool_or(category=p_category) same_category FROM history WHERE id<>p_notification GROUP BY id)
 SELECT count(*) INTO c FROM occurrences WHERE at>p_at-interval '24 hours' AND at<=p_at
   AND (p.category_cap_24h IS NULL OR same_category);
 IF p.category_cap_24h IS NOT NULL AND c>=p.category_cap_24h THEN RETURN false; END IF;
 IF p.user_cap_24h IS NOT NULL THEN
 SELECT count(DISTINCT id) INTO c FROM (
  SELECT n.id FROM public.notifications n JOIN public.notification_deliveries d ON d.notification_id=n.id
  WHERE n.recipient_user_id=p_recipient AND n.id<>p_notification AND d.channel='WebPush' AND d.delivery_status IN ('Sent','Delivered')
   AND coalesce(d.sent_at,d.delivered_at,d.attempted_at)>p_at-interval '24 hours'
  UNION SELECT notification_id FROM notification_private.push_occurrences WHERE recipient_user_id=p_recipient
   AND notification_id<>p_notification AND state<>'Released' AND coalesce(accepted_at,reserved_at)>p_at-interval '24 hours'
 ) z;
 IF c>=p.user_cap_24h THEN RETURN false; END IF;
 END IF;
 RETURN true;
END $fn$;
REVOKE ALL ON FUNCTION notification_private.push_quota_allowed(uuid,uuid,text,text,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION notification_private.reserve_push(p_notification uuid,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE n public.notifications%rowtype; b notification_private.digest_batches%rowtype;
 p notification_private.core_policy_limits%rowtype; x jsonb; s jsonb; candidates jsonb;
 typ text; source_id text; tier text; c int:=0; frozen boolean; reason text:='quota_or_source_ineligible';
BEGIN
 SELECT * INTO STRICT n FROM public.notifications WHERE id=p_notification;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.recipient_user_id::text,6316));
 SELECT * INTO STRICT p FROM notification_private.core_policy_limits WHERE singleton;
 IF (p_at AT TIME ZONE 'Asia/Dhaka')::time<p.push_start OR (p_at AT TIME ZONE 'Asia/Dhaka')::time>=p.push_end THEN
 RETURN jsonb_build_object('allowed',false,'reason','outside_routine_push_window'); END IF;
 SELECT EXISTS(SELECT 1 FROM notification_private.push_occurrences WHERE notification_id=n.id AND state<>'Released') INTO frozen;
 IF frozen THEN
 SELECT jsonb_agg(jsonb_build_object('entity_type',entity_type,'entity_id',entity_id,'source_version',source_version)) INTO candidates
 FROM notification_private.push_occurrences WHERE notification_id=n.id AND state<>'Released';
 ELSIF n.entity_type='digest' THEN
 SELECT * INTO b FROM notification_private.digest_batches WHERE id::text=n.entity_id AND recipient_user_id=n.recipient_user_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('allowed',false,'reason','digest_batch_missing'); END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('entity_type','todo','entity_id',elem.value->>'todo_id','source_version',elem.value->>'source_version')),'[]'::jsonb)
 INTO candidates FROM jsonb_array_elements(notification_private.digest_plan(n.recipient_user_id,b.local_day,b.digest_kind,p_at)->'items') AS elem(value);
 ELSE candidates:=jsonb_build_array(jsonb_build_object('entity_type',n.entity_type,'entity_id',n.entity_id,
  'source_version',n.action_params->>'governance_source_version')); END IF;
 FOR x IN SELECT * FROM jsonb_array_elements(coalesce(candidates,'[]'::jsonb)) LOOP
 typ:=x->>'entity_type';source_id:=x->>'entity_id';
 s:=notification_private.source_snapshot(typ,source_id,n.recipient_user_id);
 IF NOT coalesce((s->>'actionable')::boolean,false) THEN CONTINUE; END IF;
 IF x->>'source_version' IS NOT NULL AND x->>'source_version' IS DISTINCT FROM s->>'source_version' THEN CONTINUE; END IF;
 IF EXISTS(SELECT 1 FROM notification_private.source_interactions a WHERE a.recipient_user_id=n.recipient_user_id
  AND a.entity_type=typ AND a.entity_id=source_id AND (a.acknowledged_until>p_at OR a.snoozed_until>p_at)) THEN CONTINUE; END IF;
 tier:=s->>'priority_tier';
 IF NOT notification_private.push_quota_allowed(n.id,n.recipient_user_id,typ,source_id,n.category,tier,p_at) THEN CONTINUE; END IF;
 INSERT INTO notification_private.push_occurrences(notification_id,recipient_user_id,entity_type,entity_id,source_version,category,priority_tier,state,reserved_at)
 VALUES(n.id,n.recipient_user_id,typ,source_id,s->>'source_version',n.category,tier,'Reserved',p_at)
 ON CONFLICT(notification_id,entity_type,entity_id) DO UPDATE SET state='Reserved',reserved_at=EXCLUDED.reserved_at,
 source_version=EXCLUDED.source_version WHERE notification_private.push_occurrences.state='Released';
 c:=c+1;
 END LOOP;
 RETURN jsonb_build_object('allowed',c>0,'item_count',c,'reason',CASE WHEN c>0 THEN 'atomic_quota_reserved' ELSE reason END);
END $fn$;
REVOKE ALL ON FUNCTION notification_private.reserve_push(uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

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

  PERFORM pg_advisory_xact_lock(hashtextextended(v_subscription.user_id::text,6316));
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

  IF p_success THEN
    UPDATE notification_private.push_occurrences SET state='Accepted',accepted_at=coalesce(accepted_at,clock_timestamp())
    WHERE notification_id=v_job.notification_id AND state='Reserved';
  ELSIF NOT EXISTS(SELECT 1 FROM public.notification_deliveries WHERE notification_id=v_job.notification_id
    AND channel='WebPush' AND delivery_status IN ('Pending','Processing','Sent','Delivered')) THEN
    -- Definitive failures on EVERY device release quota. Unknown transport/result
    -- writes leave Pending rows, so a possibly accepted attempt stays charged.
    UPDATE notification_private.push_occurrences SET state='Released'
     WHERE notification_id=v_job.notification_id AND state='Reserved';
  END IF;

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

CREATE FUNCTION notification_private.capture_notification_source()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE s jsonb;
BEGIN
 IF NEW.entity_type<>'digest' THEN
 s:=notification_private.source_snapshot(NEW.entity_type,NEW.entity_id,NEW.recipient_user_id);
 IF (s->>'actionable')::boolean THEN
 NEW.action_params:=coalesce(NEW.action_params,'{}')||jsonb_build_object('governance_source_version',s->>'source_version');
 END IF; END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION notification_private.capture_notification_source() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER notification_capture_source BEFORE INSERT ON public.notifications
 FOR EACH ROW EXECUTE FUNCTION notification_private.capture_notification_source();

CREATE FUNCTION public.notification_operator_diagnostics(p_notification_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE result jsonb; n public.notifications%rowtype; s jsonb; items jsonb; lease jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 result:=jsonb_build_object('policy',notification_private.operator_policy_snapshot(),
  'health',public.notification_operations_health(),'checked_at',clock_timestamp(),
  'device_display','Unknown until observed on the device',
  'open_source_count',(SELECT count(*) FROM public.todos t WHERE notification_private.todo_actionable(t)
    AND coalesce(t.assigned_to_user_id,t.owner_user_id)=auth.uid()),
  'uncertain_quota_occurrences',(SELECT count(DISTINCT notification_id) FROM notification_private.push_occurrences
    WHERE recipient_user_id=auth.uid() AND state='Reserved' AND reserved_at>clock_timestamp()-interval '24 hours'),
  'source_adapter_types',jsonb_build_array('todo','transfer','exit','leave','uniform_supply_order',
    'uniform_delivery_issue','uniform_delivery_bill','disciplinary','meeting','recruitment'));
 IF p_notification_id IS NOT NULL THEN
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id AND recipient_user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION 'Notification unavailable' USING ERRCODE='42501'; END IF;
 IF n.entity_type='digest' THEN
 SELECT coalesce(jsonb_agg(jsonb_build_object('todo_id',d.todo_id,'group_key',d.group_key,
  'source_version',d.source_version,'verified_deadline_at',d.verified_deadline_at) ORDER BY d.group_key,d.todo_id),'[]'::jsonb)
 INTO items FROM notification_private.digest_items d JOIN notification_private.digest_batches b ON b.id=d.batch_id
 WHERE b.id::text=n.entity_id AND b.recipient_user_id=auth.uid() AND d.is_current
  AND (notification_private.source_snapshot('todo',d.todo_id::text,auth.uid())->>'actionable')::boolean;
 result:=result||jsonb_build_object('digest_items',items);
 ELSE
 s:=notification_private.source_snapshot(n.entity_type,n.entity_id,auth.uid());
 SELECT jsonb_build_object('revision',revision,'acknowledged_until',acknowledged_until,'snoozed_until',snoozed_until)
 INTO lease FROM notification_private.source_interactions WHERE recipient_user_id=auth.uid()
 AND entity_type=n.entity_type AND entity_id=n.entity_id;
 result:=result||jsonb_build_object('source',s,'interaction',coalesce(lease,'{"revision":0}'::jsonb),
   'decision',notification_private.core_evaluate(n.id,clock_timestamp()));
 END IF;
 result:=result||jsonb_build_object('last_dispatch_reason',(SELECT d.response_metadata->>'gate_reason'
 FROM public.notification_deliveries d WHERE d.notification_id=n.id AND d.channel='WebPush' ORDER BY d.id DESC LIMIT 1));
 END IF;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION public.notification_operator_diagnostics(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_operator_diagnostics(uuid) TO authenticated;
COMMENT ON TABLE notification_private.push_occurrences IS
 '24h conservative atomic Push reservations; accepted provider result counted once across all devices; unknown side effects retain quota.';
ALTER FUNCTION notification_private.core_evaluate(uuid,timestamptz) RENAME TO core_evaluate_phase2;
CREATE FUNCTION notification_private.core_evaluate(p_notification_id uuid,p_at timestamptz DEFAULT clock_timestamp())
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE j jsonb; a notification_private.source_interactions%rowtype;
BEGIN
 j:=notification_private.core_evaluate_phase2(p_notification_id,p_at);
 IF j->>'decision' IN ('SUPPRESS_RESOLVED','EXPIRED') THEN RETURN j; END IF;
 SELECT * INTO a FROM notification_private.source_interactions WHERE recipient_user_id=(j->>'recipient_user_id')::uuid
  AND entity_type=j->>'entity_type' AND entity_id=j->>'entity_id';
 IF a.snoozed_until>p_at THEN RETURN j||jsonb_build_object('decision','SUPPRESS_SNOOZED',
  'reason_code','explicit_source_snooze','next_eligible_at',a.snoozed_until); END IF;
 IF a.acknowledged_until>p_at THEN RETURN j||jsonb_build_object('decision','SUPPRESS_ACKNOWLEDGED',
  'reason_code','explicit_source_work_ack','next_eligible_at',a.acknowledged_until); END IF;
 RETURN j;
END $fn$;
REVOKE ALL ON FUNCTION notification_private.core_evaluate(uuid,timestamptz),
 notification_private.core_evaluate_phase2(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.core_evaluate(uuid,timestamptz) TO service_role;
COMMIT;
