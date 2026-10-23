-- MG-HRM Smart Work Assistant V2: additive, operator-only foundation.
-- Intentionally does not modify HR records or replace the existing notification engine.
CREATE SCHEMA IF NOT EXISTS swa_private;
REVOKE ALL ON SCHEMA swa_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS swa_private.operator_ids (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id)
);
DO $$
BEGIN
  IF (SELECT count(*) FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.is_active)=1
     AND (SELECT count(*) FROM auth.users)=1 THEN
    INSERT INTO swa_private.operator_ids(user_id)
      SELECT p.id FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.is_active
      ON CONFLICT DO NOTHING;
  ELSE
    RAISE EXCEPTION 'SWA bootstrap requires one confirmed active operator; no identity guessed';
  END IF;
END $$;
CREATE OR REPLACE FUNCTION public.swa_is_operator()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS (
  SELECT 1 FROM swa_private.operator_ids o
  JOIN public.profiles p ON p.id=o.user_id AND p.is_active
  WHERE o.user_id=auth.uid())
$$;
REVOKE ALL ON FUNCTION public.swa_is_operator() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.swa_is_operator() TO authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.swa_work_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 capture_key uuid NOT NULL UNIQUE,
 owner_user_id uuid NOT NULL REFERENCES auth.users(id),
 source_module text NOT NULL DEFAULT 'manual',
 source_record_id text,
 source_state text,
 category text NOT NULL DEFAULT 'general' CHECK (category IN ('general','my_task','inform_manager','salary_note')),
 subject text NOT NULL CHECK (length(btrim(subject)) BETWEEN 1 AND 500),
 requestor text, project text, details text,
 next_action text NOT NULL DEFAULT 'পরবর্তী পদক্ষেপ ঠিক করুন',
 next_party text,
 priority text NOT NULL DEFAULT 'important' CHECK (priority IN ('routine','important','urgent','critical')),
 stage text NOT NULL DEFAULT 'captured' CHECK (stage IN ('captured','active','waiting_manager','waiting_external','blocked','verification','completed','cancelled')),
 manager_required boolean NOT NULL DEFAULT false,
 approval_required boolean NOT NULL DEFAULT false,
 manager_informed_at timestamptz, manager_channel text,
 manager_decision text NOT NULL DEFAULT 'none' CHECK (manager_decision IN ('none','pending','approved','rejected','needs_info','postponed')),
 manager_decision_at timestamptz, manager_recorded_at timestamptz,
 communication_required boolean NOT NULL DEFAULT false,
 communicated_at timestamptz,
 execution_required boolean NOT NULL DEFAULT true,
 executed_at timestamptz,
 verification_required boolean NOT NULL DEFAULT false,
 verified_at timestamptz,
 deadline_at timestamptz, event_at timestamptz, promised_at timestamptz,
 next_review_at timestamptz,
 acknowledged_until timestamptz, snoozed_until timestamptz,
 captured_after_hours boolean NOT NULL DEFAULT false,
 captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 row_version integer NOT NULL DEFAULT 1 CHECK (row_version>0),
 completed_at timestamptz, cancelled_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT swa_approval_requires_manager CHECK (NOT approval_required OR manager_required),
 CONSTRAINT swa_source_identity CHECK ((source_module='manual' AND source_record_id IS NULL) OR
       (source_module<>'manual' AND source_record_id IS NOT NULL)),
 CONSTRAINT swa_completed_timestamp CHECK (stage<>'completed' OR completed_at IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS swa_source_identity_uq ON public.swa_work_items(source_module,source_record_id) WHERE source_record_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS swa_owner_attention_idx ON public.swa_work_items(owner_user_id,stage,next_review_at);
CREATE INDEX IF NOT EXISTS swa_due_idx ON public.swa_work_items(deadline_at) WHERE stage NOT IN ('completed','cancelled');
CREATE INDEX IF NOT EXISTS swa_manager_idx ON public.swa_work_items(manager_required,manager_informed_at) WHERE stage NOT IN ('completed','cancelled');

CREATE TABLE IF NOT EXISTS public.swa_brief_sessions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_user_id uuid NOT NULL REFERENCES auth.users(id),
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 closed_at timestamptz,
 note text
);
CREATE TABLE IF NOT EXISTS public.swa_work_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 item_id uuid NOT NULL REFERENCES public.swa_work_items(id),
 session_id uuid REFERENCES public.swa_brief_sessions(id),
 actor_user_id uuid NOT NULL REFERENCES auth.users(id),
 event_type text NOT NULL,
 event_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 channel text,
 payload jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS swa_events_item_idx ON public.swa_work_events(item_id,recorded_at DESC);
CREATE TABLE IF NOT EXISTS public.swa_attention_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 item_id uuid NOT NULL REFERENCES public.swa_work_items(id),
 source_version integer NOT NULL,
 reason text NOT NULL,
 slot_day date NOT NULL,
 delivery_policy text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(item_id,source_version,reason,slot_day)
);
CREATE TABLE IF NOT EXISTS public.swa_preferences(
 owner_user_id uuid PRIMARY KEY REFERENCES auth.users(id),
 timezone text NOT NULL DEFAULT 'Asia/Dhaka' CHECK (timezone='Asia/Dhaka'),
 office_open time NOT NULL DEFAULT '09:00',
 office_close time NOT NULL DEFAULT '18:00',
 morning_digest time NOT NULL DEFAULT '09:05',
 evening_digest time NOT NULL DEFAULT '17:15',
 weekly_off_days smallint[] DEFAULT NULL,
 push_v2_enabled boolean NOT NULL DEFAULT false,
 emergency_override boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO public.swa_preferences(owner_user_id)
 SELECT user_id FROM swa_private.operator_ids ON CONFLICT DO NOTHING;

ALTER TABLE public.swa_work_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swa_brief_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swa_work_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swa_attention_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swa_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.swa_work_items,public.swa_brief_sessions,public.swa_work_events,public.swa_attention_events,public.swa_preferences FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.swa_work_items,public.swa_brief_sessions,public.swa_work_events,public.swa_attention_events,public.swa_preferences TO authenticated;
CREATE POLICY swa_work_read ON public.swa_work_items FOR SELECT TO authenticated USING (owner_user_id=auth.uid() AND public.swa_is_operator());
CREATE POLICY swa_session_read ON public.swa_brief_sessions FOR SELECT TO authenticated USING (owner_user_id=auth.uid() AND public.swa_is_operator());
CREATE POLICY swa_event_read ON public.swa_work_events FOR SELECT TO authenticated USING (public.swa_is_operator() AND EXISTS(SELECT 1 FROM public.swa_work_items w WHERE w.id=item_id AND w.owner_user_id=auth.uid()));
CREATE POLICY swa_attention_read ON public.swa_attention_events FOR SELECT TO authenticated USING (public.swa_is_operator() AND EXISTS(SELECT 1 FROM public.swa_work_items w WHERE w.id=item_id AND w.owner_user_id=auth.uid()));
CREATE POLICY swa_preferences_read ON public.swa_preferences FOR SELECT TO authenticated USING (owner_user_id=auth.uid() AND public.swa_is_operator());

-- All writes are narrowly specified, transactional RPC operations; direct table mutation is denied.
CREATE OR REPLACE FUNCTION public.swa_capture(p_capture_key uuid,p_payload jsonb)
RETURNS public.swa_work_items LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; uid uuid:=auth.uid(); cat text; subj text; prio text;
        mgr boolean; exec_req boolean; comm boolean; app_req boolean; after_hours boolean;
BEGIN
 IF NOT public.swa_is_operator() OR uid IS NULL THEN RAISE EXCEPTION 'Operator authorization required' USING ERRCODE='42501'; END IF;
 IF p_capture_key IS NULL OR jsonb_typeof(p_payload)<>'object' THEN RAISE EXCEPTION 'Invalid capture'; END IF;
 cat:=coalesce(p_payload->>'category','general');
 subj:=btrim(coalesce(p_payload->>'subject',''));
 prio:=coalesce(p_payload->>'priority','important');
 IF cat NOT IN ('general','my_task','inform_manager','salary_note') OR
    prio NOT IN ('routine','important','urgent','critical') OR length(subj) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'Invalid category, priority or subject';
 END IF;
 mgr:=coalesce((p_payload->>'manager_required')::boolean,cat='inform_manager');
 app_req:=coalesce((p_payload->>'approval_required')::boolean,false);
 exec_req:=coalesce((p_payload->>'execution_required')::boolean,cat IN ('my_task','salary_note'));
 comm:=coalesce((p_payload->>'communication_required')::boolean,mgr);
 after_hours:=((clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::time < time '09:00' OR
               (clock_timestamp() AT TIME ZONE 'Asia/Dhaka')::time >= time '18:00');
 INSERT INTO public.swa_work_items(capture_key,owner_user_id,category,subject,project,requestor,details,
 next_action,next_party,priority,manager_required,approval_required,communication_required,execution_required,
 verification_required,deadline_at,event_at,promised_at,next_review_at,captured_after_hours,stage)
 VALUES(p_capture_key,uid,cat,subj,left(nullif(p_payload->>'project',''),200),left(nullif(p_payload->>'requestor',''),200),
 left(nullif(p_payload->>'details',''),4000),coalesce(nullif(left(p_payload->>'next_action',400),''),'পরবর্তী পদক্ষেপ ঠিক করুন'),
 left(nullif(p_payload->>'next_party',''),200),prio,mgr,app_req,comm,exec_req,
 coalesce((p_payload->>'verification_required')::boolean,false),
 nullif(p_payload->>'deadline_at','')::timestamptz,nullif(p_payload->>'event_at','')::timestamptz,
 nullif(p_payload->>'promised_at','')::timestamptz,
 coalesce(nullif(p_payload->>'next_review_at','')::timestamptz,clock_timestamp()+interval '1 day'),
 after_hours,CASE WHEN mgr THEN 'waiting_manager' ELSE 'captured' END)
 ON CONFLICT(capture_key) DO NOTHING RETURNING * INTO w;
 IF w.id IS NULL THEN
   SELECT * INTO w FROM public.swa_work_items WHERE capture_key=p_capture_key AND owner_user_id=uid;
   IF w.id IS NULL THEN RAISE EXCEPTION 'Capture key collision' USING ERRCODE='23505'; END IF;
 ELSE
   INSERT INTO public.swa_work_events(item_id,actor_user_id,event_type,payload)
   VALUES(w.id,uid,'captured',jsonb_build_object('category',cat,'after_hours',after_hours));
 END IF;
 RETURN w;
END $$;

CREATE OR REPLACE FUNCTION public.swa_start_briefing(p_note text DEFAULT NULL)
RETURNS public.swa_brief_sessions LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE s public.swa_brief_sessions;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 INSERT INTO public.swa_brief_sessions(owner_user_id,note) VALUES(auth.uid(),left(p_note,1000)) RETURNING * INTO s;
 RETURN s;
END $$;
CREATE OR REPLACE FUNCTION public.swa_close_briefing(p_id uuid)
RETURNS public.swa_brief_sessions LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE s public.swa_brief_sessions;
BEGIN
 IF NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 UPDATE public.swa_brief_sessions SET closed_at=coalesce(closed_at,clock_timestamp())
 WHERE id=p_id AND owner_user_id=auth.uid() RETURNING * INTO s;
 IF s.id IS NULL THEN RAISE EXCEPTION 'Briefing session not found'; END IF;
 RETURN s;
END $$;

CREATE OR REPLACE FUNCTION public.swa_act(p_item_id uuid,p_expected_version integer,p_action text,
 p_value text DEFAULT NULL,p_occurred_at timestamptz DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS public.swa_work_items LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
     w.stage:='active';w.next_action:=CASE WHEN w.communication_required THEN 'সংশ্লিষ্ট ব্যক্তি/প্রজেক্টকে সিদ্ধান্ত জানান' ELSE 'পরবর্তী অনুমোদিত পদক্ষেপ গ্রহণ করুন' END;
   ELSE w.stage:='waiting_manager'; END IF;
 WHEN 'communicated' THEN
   w.communicated_at:=occurred; w.stage:='active';
 WHEN 'executed' THEN
   IF w.approval_required AND w.manager_decision<>'approved' THEN RAISE EXCEPTION 'Required approval not recorded'; END IF;
   w.executed_at:=occurred; w.stage:=CASE WHEN w.verification_required THEN 'verification' ELSE 'active' END;
 WHEN 'verified' THEN
   IF w.execution_required AND w.executed_at IS NULL THEN RAISE EXCEPTION 'Execution must be recorded first'; END IF;
   w.verified_at:=occurred;w.stage:='active';
 WHEN 'complete' THEN
   IF (w.manager_required AND w.manager_informed_at IS NULL) OR
      (w.approval_required AND w.manager_decision NOT IN ('approved','rejected')) OR
      (w.communication_required AND w.communicated_at IS NULL) OR
      (w.execution_required AND w.executed_at IS NULL) OR
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
END $$;

-- Source adapter: mirror only not-yet-terminal legacy To-Dos, leave originals unmodified.
CREATE OR REPLACE FUNCTION swa_private.sync_todo(p_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
END $$;
CREATE OR REPLACE FUNCTION swa_private.todo_sync_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN PERFORM swa_private.sync_todo(NEW.id); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS swa_todo_sync ON public.todos;
CREATE TRIGGER swa_todo_sync AFTER INSERT OR UPDATE OF note,note_bn,status,solved_at,deleted_at,category,project,who,is_important ON public.todos
FOR EACH ROW EXECUTE FUNCTION swa_private.todo_sync_trigger();
DO $$
DECLARE tid bigint;
BEGIN
 FOR tid IN SELECT id FROM public.todos WHERE deleted_at IS NULL AND solved_at IS NULL
 LOOP PERFORM swa_private.sync_todo(tid); END LOOP;
END $$;
REVOKE ALL ON FUNCTION swa_private.sync_todo(bigint),swa_private.todo_sync_trigger() FROM PUBLIC,anon,authenticated;

-- Authoritative in-app attention reconciliation; no push or existing notification mutation.
CREATE OR REPLACE FUNCTION public.swa_reconcile(p_limit integer DEFAULT 200)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE w public.swa_work_items; n integer:=0; stamp timestamptz:=clock_timestamp(); why text; policy text;
BEGIN
 IF current_setting('request.jwt.claim.role',true) IS DISTINCT FROM 'service_role'
 AND current_user NOT IN ('postgres','supabase_admin') THEN RAISE EXCEPTION 'Service only' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Invalid batch'; END IF;
 IF NOT pg_try_advisory_xact_lock(74261022) THEN RETURN jsonb_build_object('busy',true); END IF;
 FOR w IN SELECT * FROM public.swa_work_items WHERE stage NOT IN ('completed','cancelled')
 AND (next_review_at<=stamp OR deadline_at<=stamp+interval '24 hours' OR promised_at<=stamp+interval '24 hours')
 ORDER BY coalesce(deadline_at,promised_at,next_review_at) NULLS LAST LIMIT p_limit LOOP
   why:=CASE WHEN w.deadline_at<=stamp THEN 'overdue'
     WHEN w.promised_at<=stamp THEN 'promise_breached'
     WHEN w.deadline_at<=stamp+interval '24 hours' THEN 'due_soon'
     WHEN w.promised_at<=stamp+interval '24 hours' THEN 'promise_soon'
     ELSE 'review_due' END;
   policy:=CASE WHEN (stamp AT TIME ZONE 'Asia/Dhaka')::time<time '09:00' OR
                      (stamp AT TIME ZONE 'Asia/Dhaka')::time>=time '18:00'
                THEN 'deferred_for_office_hours' ELSE 'in_app_only' END;
   INSERT INTO public.swa_attention_events(item_id,source_version,reason,slot_day,delivery_policy)
   VALUES(w.id,w.row_version,why,(stamp AT TIME ZONE 'Asia/Dhaka')::date,policy)
   ON CONFLICT DO NOTHING;
   n:=n+1;
 END LOOP;
 RETURN jsonb_build_object('examined',n,'push_v2_enabled',false,'evaluated_at',stamp);
END $$;
REVOKE ALL ON FUNCTION public.swa_capture(uuid,jsonb), public.swa_act(uuid,integer,text,text,timestamptz,uuid),
 public.swa_start_briefing(text),public.swa_close_briefing(uuid),public.swa_reconcile(integer)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.swa_capture(uuid,jsonb), public.swa_act(uuid,integer,text,text,timestamptz,uuid),
 public.swa_start_briefing(text),public.swa_close_briefing(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.swa_reconcile(integer) TO service_role;

COMMENT ON TABLE public.swa_work_items IS 'SWA V2 additive source-linked work obligations. No HR workflow actions may originate here.';
COMMENT ON TABLE public.swa_attention_events IS 'In-app reconciliation policy events only. V2 push is feature-flagged OFF; V1 remains authoritative.';
