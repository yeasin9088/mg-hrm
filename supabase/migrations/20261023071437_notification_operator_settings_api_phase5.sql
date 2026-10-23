-- MG-HRM Phase 4/5 preparation: versioned, single-operator notification policy
-- controls for the FINAL Phase 6 Settings Center. No live activation.
-- Depends on Phase 2 core_policy_limits only. Safe to stage with Phase 3/4
-- but NOT applied as part of this PR.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

ALTER TABLE notification_private.core_policy_limits
  ADD COLUMN IF NOT EXISTS revision bigint NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS morning_digest_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS afternoon_digest_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE notification_private.core_policy_limits
  ADD CONSTRAINT notification_core_revision_positive CHECK(revision>=1);

-- Normalize a strictly allowlisted set of existing policy fields.
-- P0 emergency and P1 after-hours interrupts deliberately cannot be enabled
-- by this API. Governance activation is NEVER exposed by this RPC.
CREATE OR REPLACE FUNCTION notification_private.operator_policy_snapshot()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE v jsonb; v_bridge boolean:=false;
BEGIN
 SELECT jsonb_build_object(
   'revision',p.revision,'policy_version',p.policy_version,'timezone','Asia/Dhaka',
   'push_start',to_char(p.push_start,'HH24:MI'),
   'push_end',to_char(p.push_end,'HH24:MI'),
   'morning_digest_time',to_char(p.morning_digest_time,'HH24:MI'),
   'afternoon_digest_time',to_char(p.afternoon_digest_time,'HH24:MI'),
   'morning_digest_enabled',p.morning_digest_enabled,
   'afternoon_digest_enabled',p.afternoon_digest_enabled,
   'p3_item_cap_24h',p.p3_item_cap_24h,
   'p2_item_cap_24h',p.p2_item_cap_24h,
   'p3_cooldown_minutes',CASE WHEN p.p3_cooldown IS NULL THEN NULL
     ELSE (extract(epoch FROM p.p3_cooldown)/60)::integer END,
   'p2_cooldown_minutes',CASE WHEN p.p2_cooldown IS NULL THEN NULL
     ELSE (extract(epoch FROM p.p2_cooldown)/60)::integer END,
   'user_cap_24h',p.user_cap_24h,'category_cap_24h',p.category_cap_24h,
   'p0_emergency_configured',false,'p1_interrupt_configured',false,
   'calendar_verified',false,
   'enforcement','staged_until_phase6_activation',
   'governance_enabled',(SELECT enabled FROM notification_private.governance_control WHERE singleton)
 ) INTO v FROM notification_private.core_policy_limits p WHERE p.singleton;
 IF v IS NULL THEN RAISE EXCEPTION 'Policy configuration unavailable' USING ERRCODE='P0001'; END IF;
 IF to_regclass('notification_private.digest_bridge_control') IS NOT NULL THEN
   EXECUTE 'SELECT enabled FROM notification_private.digest_bridge_control WHERE singleton'
     INTO v_bridge;
 END IF;
 RETURN v||jsonb_build_object('digest_bridge_enabled',coalesce(v_bridge,false));
END $mg$;
REVOKE ALL ON FUNCTION notification_private.operator_policy_snapshot()
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.notification_operator_policy_read()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
BEGIN
 IF NOT public.swa_is_operator() OR auth.uid() IS NULL THEN
   RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501';
 END IF;
 RETURN notification_private.operator_policy_snapshot();
END $mg$;
REVOKE ALL ON FUNCTION public.notification_operator_policy_read()
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_operator_policy_read() TO authenticated;

CREATE OR REPLACE FUNCTION public.notification_operator_policy_save(
 p_expected_revision bigint,p_changes jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog
AS $mg$
DECLARE
 v_policy notification_private.core_policy_limits%rowtype;
 v_key text;
 v_value text;
 v_policy_changes jsonb;
 v_final jsonb;
 v_start time;
 v_end time;
 v_morning time;
 v_afternoon time;
 v_p2 integer;
 v_p3 integer;
 v_mute2 integer;
 v_mute3 integer;
 v_user integer;
 v_category integer;
 v_morning_enabled boolean;
 v_afternoon_enabled boolean;
BEGIN
 IF NOT public.swa_is_operator() OR auth.uid() IS NULL THEN
   RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501';
 END IF;
 IF p_expected_revision IS NULL OR p_changes IS NULL OR
    jsonb_typeof(p_changes)<>'object' OR p_changes='{}'::jsonb THEN
   RAISE EXCEPTION 'Expected revision and nonempty update object required' USING ERRCODE='22023';
 END IF;
 FOR v_key IN SELECT jsonb_object_keys(p_changes) LOOP
   IF v_key <> ALL(ARRAY[
     'push_start','push_end','morning_digest_time','afternoon_digest_time',
     'morning_digest_enabled','afternoon_digest_enabled',
     'p3_item_cap_24h','p2_item_cap_24h','p3_cooldown_minutes',
     'p2_cooldown_minutes','user_cap_24h','category_cap_24h'
   ]) THEN
     RAISE EXCEPTION 'Unknown or locked setting %',v_key USING ERRCODE='22023';
   END IF;
 END LOOP;
 SELECT * INTO v_policy FROM notification_private.core_policy_limits
 WHERE singleton FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Policy missing' USING ERRCODE='P0001'; END IF;
 IF v_policy.revision<>p_expected_revision THEN
   RAISE EXCEPTION 'Policy revision conflict; reload before saving'
     USING ERRCODE='40001';
 END IF;
 v_start:=v_policy.push_start;v_end:=v_policy.push_end;
 v_morning:=v_policy.morning_digest_time;
 v_afternoon:=v_policy.afternoon_digest_time;
 v_p2:=v_policy.p2_item_cap_24h;v_p3:=v_policy.p3_item_cap_24h;
 v_mute2:=CASE WHEN v_policy.p2_cooldown IS NULL THEN NULL
   ELSE (extract(epoch FROM v_policy.p2_cooldown)/60)::integer END;
 v_mute3:=CASE WHEN v_policy.p3_cooldown IS NULL THEN NULL
   ELSE (extract(epoch FROM v_policy.p3_cooldown)/60)::integer END;
 v_user:=v_policy.user_cap_24h;v_category:=v_policy.category_cap_24h;
 v_morning_enabled:=v_policy.morning_digest_enabled;
 v_afternoon_enabled:=v_policy.afternoon_digest_enabled;
 IF p_changes ? 'push_start' THEN v_start:=(p_changes->>'push_start')::time; END IF;
 IF p_changes ? 'push_end' THEN v_end:=(p_changes->>'push_end')::time; END IF;
 IF p_changes ? 'morning_digest_time' THEN v_morning:=(p_changes->>'morning_digest_time')::time; END IF;
 IF p_changes ? 'afternoon_digest_time' THEN v_afternoon:=(p_changes->>'afternoon_digest_time')::time; END IF;
 IF p_changes ? 'morning_digest_enabled' THEN
   IF jsonb_typeof(p_changes->'morning_digest_enabled')<>'boolean' THEN
     RAISE EXCEPTION 'Boolean morning toggle required' USING ERRCODE='22023';
   END IF;
   v_morning_enabled:=(p_changes->>'morning_digest_enabled')::boolean;
 END IF;
 IF p_changes ? 'afternoon_digest_enabled' THEN
   IF jsonb_typeof(p_changes->'afternoon_digest_enabled')<>'boolean' THEN
     RAISE EXCEPTION 'Boolean afternoon toggle required' USING ERRCODE='22023';
   END IF;
   v_afternoon_enabled:=(p_changes->>'afternoon_digest_enabled')::boolean;
 END IF;
 IF p_changes ? 'p2_item_cap_24h' THEN v_p2:=(p_changes->>'p2_item_cap_24h')::integer; END IF;
 IF p_changes ? 'p3_item_cap_24h' THEN v_p3:=(p_changes->>'p3_item_cap_24h')::integer; END IF;
 IF p_changes ? 'p2_cooldown_minutes' THEN v_mute2:=(p_changes->>'p2_cooldown_minutes')::integer; END IF;
 IF p_changes ? 'p3_cooldown_minutes' THEN v_mute3:=(p_changes->>'p3_cooldown_minutes')::integer; END IF;
 IF p_changes ? 'user_cap_24h' THEN v_user:=(p_changes->>'user_cap_24h')::integer; END IF;
 IF p_changes ? 'category_cap_24h' THEN v_category:=(p_changes->>'category_cap_24h')::integer; END IF;
 IF v_start IS NULL OR v_end IS NULL OR v_morning IS NULL OR v_afternoon IS NULL
   OR v_start>=v_end OR v_morning<v_start OR v_morning>=v_end
   OR v_afternoon<=v_morning OR v_afternoon>=v_end THEN
   RAISE EXCEPTION 'Digest times must be ordered inside the Push eligibility window'
   USING ERRCODE='22023';
 END IF;
 IF v_p2 IS NULL OR v_p3 IS NULL OR v_p2 NOT BETWEEN 1 AND 5
   OR v_p3 NOT BETWEEN 1 AND 5 THEN
   RAISE EXCEPTION 'P2/P3 caps must be 1 to 5 per 24 hours' USING ERRCODE='22023';
 END IF;
 IF (v_mute2 IS NOT NULL AND v_mute2 NOT BETWEEN 1 AND 1440)
 OR (v_mute3 IS NOT NULL AND v_mute3 NOT BETWEEN 1 AND 1440)
 OR (v_user IS NOT NULL AND v_user NOT BETWEEN 1 AND 100)
 OR (v_category IS NOT NULL AND v_category NOT BETWEEN 1 AND 100)
 THEN RAISE EXCEPTION 'Cooldown or global rate cap out of allowed range'
 USING ERRCODE='22023'; END IF;
 UPDATE notification_private.core_policy_limits SET
   revision=revision+1,push_start=v_start,push_end=v_end,
   morning_digest_time=v_morning,afternoon_digest_time=v_afternoon,
   morning_digest_enabled=v_morning_enabled,
   afternoon_digest_enabled=v_afternoon_enabled,
   p2_item_cap_24h=v_p2,p3_item_cap_24h=v_p3,
   p2_cooldown=CASE WHEN v_mute2 IS NULL THEN NULL ELSE make_interval(mins=>v_mute2) END,
   p3_cooldown=CASE WHEN v_mute3 IS NULL THEN NULL ELSE make_interval(mins=>v_mute3) END,
   user_cap_24h=v_user,category_cap_24h=v_category
 WHERE singleton AND revision=p_expected_revision
 RETURNING revision INTO v_policy.revision;
 IF NOT FOUND THEN RAISE EXCEPTION 'Concurrent policy update conflict' USING ERRCODE='40001'; END IF;
 v_final:=notification_private.operator_policy_snapshot();
 RETURN v_final||jsonb_build_object('saved',true,'readback_revision',v_policy.revision);
END $mg$;
REVOKE ALL ON FUNCTION public.notification_operator_policy_save(bigint,jsonb)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_operator_policy_save(bigint,jsonb)
 TO authenticated;
COMMENT ON FUNCTION public.notification_operator_policy_save(bigint,jsonb) IS
 'Operator-only version checked settings; cannot enable V2, P1/P0, or expose secrets.';
COMMIT;
