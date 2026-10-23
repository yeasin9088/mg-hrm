-- MG-HRM Notification Governance V2 — Phase 3: dormant digest/scheduler.
-- Works on existing authoritative To-Do rows, no new Smart Work inbox.
-- Deploy only after ordered Phase 1+2 migrations; no cron, push, or UI changes.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

CREATE TABLE notification_private.digest_batches (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 recipient_user_id uuid NOT NULL,
 local_day date NOT NULL,
 digest_kind text NOT NULL CHECK (digest_kind IN ('morning','wrapup')),
 slot_at timestamptz NOT NULL,
 policy_version text NOT NULL,
 calendar_verified boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'Prepared' CHECK (status IN ('Prepared','Empty')),
 item_count integer NOT NULL DEFAULT 0 CHECK (item_count >= 0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reconciled_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE (recipient_user_id,local_day,digest_kind)
);
CREATE INDEX digest_batches_recipient_idx
 ON notification_private.digest_batches(recipient_user_id,slot_at DESC);
ALTER TABLE notification_private.digest_batches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.digest_batches FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE notification_private.digest_batches_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE notification_private.digest_items (
 batch_id bigint NOT NULL REFERENCES notification_private.digest_batches(id),
 todo_id bigint NOT NULL,
 source_version text NOT NULL,
 group_key text NOT NULL CHECK (group_key IN ('OVERDUE','DUE_TODAY',
  'BEFORE_NEXT_OPEN_RISK','BRIEF_MANAGER','WAITING_FOLLOWUP','ACT_TODAY')),
 verified_deadline_at timestamptz,
 captured_overnight boolean NOT NULL DEFAULT false,
 is_current boolean NOT NULL DEFAULT true,
 first_added_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 last_checked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(batch_id,todo_id)
);
CREATE INDEX digest_items_current_idx
 ON notification_private.digest_items(batch_id,group_key,todo_id) WHERE is_current=true;
ALTER TABLE notification_private.digest_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_private.digest_items FROM PUBLIC,anon,authenticated,service_role;

-- A deterministic, read-only snapshot. Not a new queue or separate work source.
-- "read/dismiss" notification state is intentionally never referenced here.
-- Morning/wrap-up calendar is UNSPECIFIED; every result exposes that limitation.
CREATE FUNCTION notification_private.digest_plan(
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
REVOKE ALL ON FUNCTION notification_private.digest_plan(uuid,date,text,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_plan(uuid,date,text,timestamptz)
 TO service_role;

-- The *latest due* slot only. If cron was down for hours/days, rebuilding
-- outstanding source truth in ONE latest batch avoids replaying many old pushes.
-- No official holiday/weekend assumption; the missing calendar remains explicit.
CREATE FUNCTION notification_private.digest_latest_due(
 p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE v_policy notification_private.core_policy_limits%rowtype;
  v_local timestamp;
  v_day date;
  v_kind text;
  v_slot timestamptz;
BEGIN
 IF p_at IS NULL THEN RAISE EXCEPTION 'Evaluation time required' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_policy FROM notification_private.core_policy_limits WHERE singleton;
 IF NOT FOUND THEN RAISE EXCEPTION 'Policy missing' USING ERRCODE='P0001'; END IF;
 v_local:=p_at AT TIME ZONE 'Asia/Dhaka';
 v_day:=v_local::date;
 IF v_local::time>=v_policy.afternoon_digest_time THEN
   v_kind:='wrapup';
 ELSIF v_local::time>=v_policy.morning_digest_time THEN
   v_kind:='morning';
 ELSE
   v_day:=v_day-1;
   v_kind:='wrapup';
 END IF;
 v_slot:=(v_day+CASE WHEN v_kind='morning' THEN v_policy.morning_digest_time
   ELSE v_policy.afternoon_digest_time END) AT TIME ZONE 'Asia/Dhaka';
 RETURN jsonb_build_object('local_day',v_day,'digest_kind',v_kind,
   'slot_at',v_slot,'catchup',p_at>v_slot+interval '30 minutes',
   'calendar_verified',false);
END $mg$;
REVOKE ALL ON FUNCTION notification_private.digest_latest_due(timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION notification_private.digest_latest_due(timestamptz)
 TO service_role;

-- Server-only durable builder; unique-slot upsert serializes parallel cron
-- invocations. A replay may add newly captured items and mark resolved items
-- inactive, never deletes historical snapshot rows or touches source status.
CREATE FUNCTION public.notification_digest_prepare_slot(
 p_recipient uuid,p_day date,p_kind text,p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE v_plan jsonb;
 v_id bigint;
 v_count integer;
 v_slot timestamptz;
BEGIN
 IF p_at IS NULL OR p_recipient IS NULL THEN
   RAISE EXCEPTION 'Recipient and evaluation time required' USING ERRCODE='22023';
 END IF;
 v_plan:=notification_private.digest_plan(p_recipient,p_day,p_kind,p_at);
 v_slot:=(v_plan->>'slot_at')::timestamptz;
 IF NOT (v_plan->>'is_due')::boolean THEN
   RAISE EXCEPTION 'Digest slot is not due' USING ERRCODE='22023';
 END IF;
 IF p_at-v_slot>interval '48 hours' THEN
   RAISE EXCEPTION 'Old slot cannot be replayed; reconcile latest due slot' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles p
   WHERE p.id=p_recipient AND p.is_active) THEN
   RAISE EXCEPTION 'Digest recipient is inactive' USING ERRCODE='42501';
 END IF;
 INSERT INTO notification_private.digest_batches(
   recipient_user_id,local_day,digest_kind,slot_at,policy_version,reconciled_at
 ) VALUES (
   p_recipient,p_day,p_kind,v_slot,v_plan->>'policy_version',p_at
 )
 ON CONFLICT (recipient_user_id,local_day,digest_kind)
 DO UPDATE SET reconciled_at=EXCLUDED.reconciled_at,
               policy_version=EXCLUDED.policy_version
 RETURNING id INTO v_id;

 -- Inactive snapshots are retained for audit and visibility; no source is removed.
 UPDATE notification_private.digest_items d SET
   is_current=false,last_checked_at=p_at
 WHERE d.batch_id=v_id AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_plan->'items') j
    WHERE (j->>'todo_id')::bigint=d.todo_id
 );

 INSERT INTO notification_private.digest_items(
    batch_id,todo_id,source_version,group_key,
    verified_deadline_at,captured_overnight,is_current,last_checked_at
 )
 SELECT v_id,j.todo_id,j.source_version,j.group_key,
   j.verified_deadline_at,j.captured_overnight,true,p_at
 FROM jsonb_to_recordset(v_plan->'items') AS j(
   todo_id bigint,source_version text,group_key text,
   verified_deadline_at timestamptz,captured_overnight boolean)
 ON CONFLICT(batch_id,todo_id) DO UPDATE SET
   source_version=EXCLUDED.source_version,
   group_key=EXCLUDED.group_key,
   verified_deadline_at=EXCLUDED.verified_deadline_at,
   captured_overnight=EXCLUDED.captured_overnight,
   is_current=true,last_checked_at=EXCLUDED.last_checked_at;

 SELECT count(*) INTO v_count FROM notification_private.digest_items d
 WHERE d.batch_id=v_id AND d.is_current;
 UPDATE notification_private.digest_batches
 SET item_count=v_count,status=CASE WHEN v_count>0 THEN 'Prepared' ELSE 'Empty' END,
   reconciled_at=p_at
 WHERE id=v_id;
 RETURN jsonb_build_object(
   'batch_id',v_id,'digest_kind',p_kind,'local_day',p_day,
   'slot_at',v_slot,'item_count',v_count,
   'status',CASE WHEN v_count>0 THEN 'Prepared' ELSE 'Empty' END,
   'calendar_verified',false,
   'push_jobs_created',0,'delivery_connected',false,
   'next_step','Phase 4 integration must revalidate authoritative source before dispatch');
END $mg$;
REVOKE ALL ON FUNCTION public.notification_digest_prepare_slot(uuid,date,text,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_digest_prepare_slot(uuid,date,text,timestamptz)
 TO service_role;

-- Missed-tick reconciliation: build only the newest eligible slot (not each
-- missed slot). Actionable To-Do source truth is recomputed, so backlog persists.
CREATE FUNCTION public.notification_digest_reconcile(
 p_recipient uuid,p_at timestamptz DEFAULT clock_timestamp()
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE v_due jsonb;v_result jsonb;
BEGIN
 v_due:=notification_private.digest_latest_due(p_at);
 v_result:=public.notification_digest_prepare_slot(p_recipient,
   (v_due->>'local_day')::date,v_due->>'digest_kind',p_at);
 RETURN v_result||jsonb_build_object(
   'catchup',(v_due->>'catchup')::boolean,
   'recovered_slot_at',v_due->>'slot_at');
END $mg$;
REVOKE ALL ON FUNCTION public.notification_digest_reconcile(uuid,timestamptz)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_digest_reconcile(uuid,timestamptz)
 TO service_role;

-- An authorized operator can view a FRESH derived digest in the existing
-- app context; private batch tables remain unreadable to normal clients.
CREATE FUNCTION public.notification_digest_preview(
 p_day date,p_kind text
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
BEGIN
 IF NOT public.swa_is_operator() THEN
   RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;
 RETURN notification_private.digest_plan(auth.uid(),p_day,p_kind,clock_timestamp());
END $mg$;
REVOKE ALL ON FUNCTION public.notification_digest_preview(date,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_digest_preview(date,text)
 TO authenticated;

COMMENT ON TABLE notification_private.digest_batches IS
 'Phase 3 durable slot grouping only; no job and no automatic Push.';
COMMENT ON TABLE notification_private.digest_items IS
 'Privacy-safe source IDs and state fingerprints; source remains authoritative.';
COMMENT ON FUNCTION public.notification_digest_reconcile(uuid,timestamptz) IS
 'Service-only replay-safe latest-slot builder; cron not registered until Phase 4.';
COMMIT;
