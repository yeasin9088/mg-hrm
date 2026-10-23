-- Forward repair: dispatch snapshots use the same terminal-state truth as the
-- canonical source scheduler. No source/status/history rows are modified.
BEGIN;
CREATE OR REPLACE FUNCTION notification_private.source_snapshot(p_type text,p_id text,p_recipient uuid)
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
  SELECT notification_private.todo_actionable(t) AND coalesce(t.assigned_to_user_id,t.owner_user_id)=p_recipient
  INTO active FROM public.todos t WHERE t.id::text=p_id;
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
 ELSIF typ='recruitment' THEN active:=active AND st NOT IN ('rejected','withdrawn','hired','cancelled');
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
COMMIT;
