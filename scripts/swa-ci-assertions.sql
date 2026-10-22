-- Synthetic-only invariants: no production business data is modified.
\set ON_ERROR_STOP on
DO $$
BEGIN
 IF (SELECT count(*) FROM public.swa_work_items WHERE source_module='todo')<>1
 THEN RAISE EXCEPTION 'To-Do backfill failed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.swa_work_items WHERE source_record_id='123' AND manager_required AND stage='waiting_manager')
 THEN RAISE EXCEPTION 'Manager source adapter failed'; END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
DO $$
DECLARE w public.swa_work_items; d public.swa_work_items; k uuid:='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
BEGIN
 SELECT * INTO w FROM public.swa_capture(k,'{"subject":"Synthetic leave starts 08:00","category":"inform_manager","approval_required":true,"execution_required":true,"deadline_at":"2026-10-23T02:00:00Z"}'::jsonb);
 IF w.manager_decision<>'none' OR w.manager_informed_at IS NOT NULL OR w.executed_at IS NOT NULL THEN RAISE EXCEPTION 'Capture conflated states'; END IF;
 SELECT * INTO d FROM public.swa_capture(k,'{"subject":"Synthetic leave starts 08:00","category":"inform_manager"}'::jsonb);
 IF d.id<>w.id THEN RAISE EXCEPTION 'Capture retry duplicated item'; END IF;
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'informed','phone');
 IF w.manager_decision<>'pending' OR w.manager_informed_at IS NULL THEN RAISE EXCEPTION 'Informed conflated with approved'; END IF;
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'decision','approved');
 IF w.executed_at IS NOT NULL OR w.communicated_at IS NOT NULL OR w.stage='completed' THEN RAISE EXCEPTION 'Decision auto executed'; END IF;
 BEGIN PERFORM public.swa_act(w.id,w.row_version,'complete');RAISE EXCEPTION 'Invalid complete accepted';EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM='Invalid complete accepted' THEN RAISE; END IF;
 END;
 BEGIN PERFORM public.swa_act(w.id,w.row_version-1,'ack');RAISE EXCEPTION 'Stale version accepted';EXCEPTION WHEN SQLSTATE '40001' THEN NULL;END;
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'communicated');
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'executed');
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'complete');
 IF w.stage<>'completed' THEN RAISE EXCEPTION 'Complete failed'; END IF;
 SELECT * INTO w FROM public.swa_act(w.id,w.row_version,'reopen','Verify field execution again');
 IF w.stage<>'active' OR w.executed_at IS NOT NULL THEN RAISE EXCEPTION 'Reopen failed'; END IF;
 IF (SELECT count(*) FROM public.swa_work_events WHERE item_id=w.id)<6 THEN RAISE EXCEPTION 'Audit history missing'; END IF;
END $$;
RESET ROLE;
INSERT INTO auth.users VALUES('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false);
DO $$
BEGIN
 IF public.swa_is_operator() THEN RAISE EXCEPTION 'Unauthorized account marked operator'; END IF;
 IF EXISTS(SELECT 1 FROM public.swa_work_items) THEN RAISE EXCEPTION 'RLS information disclosure'; END IF;
 BEGIN
  PERFORM public.swa_capture('cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"subject":"Forbidden"}'::jsonb);
  RAISE EXCEPTION 'Unauthorized capture accepted';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
DO $$
DECLARE response jsonb;
BEGIN
 response:=public.swa_reconcile(200);
 IF response->>'push_v2_enabled'<>'false' THEN RAISE EXCEPTION 'V2 push erroneously on'; END IF;
END $$;
SELECT 'SWA synthetic database acceptance passed' AS test_result;
