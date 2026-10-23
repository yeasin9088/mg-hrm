-- Synthetic operator settings contract tests. Requires Phase1 + Phase2 fixtures.
BEGIN;
DO $test$
DECLARE v jsonb; old_revision bigint;
BEGIN
 -- Preview does not unlock any V2 component.
 v:=notification_private.operator_policy_snapshot();
 IF v->>'revision'<>'1' OR v->>'p3_item_cap_24h'<>'1' OR
    v->>'p2_item_cap_24h'<>'2' OR
    v->>'governance_enabled'<>'false' OR
    v->>'digest_bridge_enabled'<>'false' THEN
   RAISE EXCEPTION 'Incorrect default settings contract %',v;
 END IF;
 IF has_function_privilege('anon','public.notification_operator_policy_save(bigint,jsonb)','EXECUTE')
 OR has_function_privilege('anon','public.notification_operator_policy_read()','EXECUTE')
 OR has_table_privilege('authenticated','notification_private.core_policy_limits','UPDATE')
 THEN RAISE EXCEPTION 'Unexpected caller privileges'; END IF;
END $test$;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $test$
DECLARE before jsonb; result jsonb; after jsonb;
BEGIN
 before:=public.notification_operator_policy_read();
 result:=public.notification_operator_policy_save(
 (before->>'revision')::bigint,
 '{"morning_digest_enabled":false,"afternoon_digest_enabled":true,
  "morning_digest_time":"09:10","afternoon_digest_time":"17:20",
  "p2_item_cap_24h":2,"p3_item_cap_24h":1,
  "p2_cooldown_minutes":60,"user_cap_24h":12}'::jsonb
 );
 IF result->>'saved'<>'true' OR result->>'revision'<>'2' OR
    result->>'morning_digest_enabled'<>'false' OR
    result->>'afternoon_digest_time'<>'17:20' OR
    result->>'p2_cooldown_minutes'<>'60' THEN
   RAISE EXCEPTION 'Read-back policy save failed %',result; END IF;
 after:=public.notification_operator_policy_read();
 IF after->>'revision'<>'2' OR after->>'morning_digest_time'<>'09:10' THEN
   RAISE EXCEPTION 'Operator read did not return true server save %',after; END IF;
 -- Android / PC conflicting edits cannot overwrite a more recent server row.
 BEGIN
   PERFORM public.notification_operator_policy_save(1,'{"p3_item_cap_24h":2}'::jsonb);
   RAISE EXCEPTION 'Stale cross-device save must not succeed';
 EXCEPTION WHEN serialization_failure THEN NULL;
 END;
 -- Forbidden emergency and global live-activation toggles must be blocked.
 BEGIN
   PERFORM public.notification_operator_policy_save(2,'{"p0_push_enabled":true}'::jsonb);
   RAISE EXCEPTION 'P0 emergency bypass became writable';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 BEGIN
   PERFORM public.notification_operator_policy_save(2,'{"governance_enabled":true}'::jsonb);
   RAISE EXCEPTION 'V2 activation became writable';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 BEGIN
   PERFORM public.notification_operator_policy_save(2,'{"morning_digest_time":"22:30"}'::jsonb);
   RAISE EXCEPTION 'Outside-office digest time accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 BEGIN
   PERFORM public.notification_operator_policy_save(2,'{"p3_item_cap_24h":0}'::jsonb);
   RAISE EXCEPTION 'Invalid zero quota accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 IF (public.notification_operator_policy_read()->>'revision')::integer<>2 THEN
   RAISE EXCEPTION 'Failed writes must not advance the revision'; END IF;
END $test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $test$
BEGIN
 BEGIN
  PERFORM public.notification_operator_policy_read();
  RAISE EXCEPTION 'Non-operator policy read succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM public.notification_operator_policy_save(2,'{"p2_item_cap_24h":3}'::jsonb);
  RAISE EXCEPTION 'Non-operator policy save succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $test$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: Phase5 Settings API persistence, mobile/desktop optimistic version, least privilege, invalid policy guards' result;
