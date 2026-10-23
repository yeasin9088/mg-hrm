-- Phase 3 notification digest scheduler integration tests.
-- All records are entirely synthetic; transactional assertions roll back changes.
BEGIN;
DO $test$
DECLARE
 owner uuid:='11111111-1111-4111-8111-111111111111';
 other_user uuid:='22222222-2222-4222-8222-222222222222';
 morning_early timestamptz:='2026-10-23T03:04:00Z';
 morning_due timestamptz:='2026-10-23T03:05:00Z';
 wrap_due timestamptz:='2026-10-23T11:15:00Z';
 next_morning timestamptz:='2026-10-24T03:05:00Z';
 v jsonb; p jsonb; again jsonb;
 batch_id bigint; ver text;
BEGIN
 p:=notification_private.digest_plan(owner,'2026-10-23','morning',morning_early);
 IF p->>'status'<>'NOT_DUE' OR (p->>'item_count')::int<>0
   OR p->>'slot_at'<>'2026-10-23T03:05:00+00:00' THEN
   RAISE EXCEPTION '09:05 Dhaka schedule timing wrong %',p; END IF;
 BEGIN
   PERFORM public.notification_digest_prepare_slot(owner,'2026-10-23','morning',morning_early);
   RAISE EXCEPTION 'Early digest must be rejected';
 EXCEPTION WHEN sqlstate '22023' THEN NULL;
 END;
 p:=notification_private.digest_plan(owner,'2026-10-23','morning',morning_due);
 IF (p->>'item_count')::int<>21 OR p->>'calendar_verified'<>'false'
    OR (p->>'push_jobs_created')::int<>0 THEN
    RAISE EXCEPTION '21 actionable (20 overnight), calendar unverified, no pushes %',p; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(p->'items') j
     WHERE (j->>'captured_overnight')::boolean)<>20 THEN
     RAISE EXCEPTION 'Overnight capture grouping count not 20'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(p->'items') j
     WHERE j->>'group_key'='WAITING_FOLLOWUP')<>1 THEN
     RAISE EXCEPTION 'Manager informed/asked was wrongly categorized as uninformed'; END IF;
 IF p::text LIKE '%Sensitive internal work details%' THEN
     RAISE EXCEPTION 'Digest leaks source confidential note'; END IF;
 v:=public.notification_digest_prepare_slot(owner,'2026-10-23','morning',morning_due);
 IF (v->>'item_count')::int<>21 OR (v->>'push_jobs_created')::int<>0 THEN
   RAISE EXCEPTION 'Batch not durable or mistakenly dispatched %',v; END IF;
 batch_id:=(v->>'batch_id')::bigint;
 IF (SELECT count(*) FROM notification_private.digest_items WHERE batch_id=batch_id)<>21 THEN
   RAISE EXCEPTION 'Batch contains wrong number of source IDs'; END IF;
 again:=public.notification_digest_prepare_slot(owner,'2026-10-23','morning',morning_due+interval '1 second');
 IF (again->>'batch_id')::bigint<>batch_id OR
    (SELECT count(*) FROM notification_private.digest_batches)<>1 OR
    (SELECT count(*) FROM notification_private.digest_items)<>21 THEN
    RAISE EXCEPTION 'Same slot replay duplicated batch/items %',again; END IF;
 -- Read or clear in-app notification cannot clear digest-eligible source work.
 UPDATE public.notifications SET read_at=morning_due WHERE entity_type='todo';
 p:=notification_private.digest_plan(owner,'2026-10-23','morning',morning_due);
 IF (p->>'item_count')::int<>21 THEN
    RAISE EXCEPTION 'Mark All Read erased actual outstanding work'; END IF;
 -- Completing the authoritative task invalidates it; history stays.
 UPDATE public.todos SET solved_at=morning_due WHERE id=201;
 again:=public.notification_digest_prepare_slot(owner,'2026-10-23','morning',morning_due+interval '2 seconds');
 IF (again->>'item_count')::int<>20 OR
   (SELECT count(*) FROM notification_private.digest_items
      WHERE batch_id=batch_id AND is_current)=0 OR
   NOT EXISTS(SELECT 1 FROM notification_private.digest_items
      WHERE batch_id=batch_id AND todo_id=201 AND is_current=false) THEN
   RAISE EXCEPTION 'Completed source was not retired with history retained %',again; END IF;
 UPDATE public.todos SET solved_at=NULL WHERE id=201;
 again:=public.notification_digest_prepare_slot(owner,'2026-10-23','morning',morning_due+interval '3 seconds');
 IF (again->>'item_count')::int<>21 OR NOT EXISTS (
   SELECT 1 FROM notification_private.digest_items
   WHERE batch_id=batch_id AND todo_id=201 AND is_current) THEN
   RAISE EXCEPTION 'Reopened source not restored %',again; END IF;
 -- Source/recipient change must make old recipient digest ineligible.
 UPDATE public.todos SET assigned_to_user_id=other_user WHERE id=202;
 p:=notification_private.digest_plan(owner,'2026-10-23','morning',morning_due);
 IF (p->>'item_count')::int<>20 THEN
    RAISE EXCEPTION 'Reassigned source leaked to previous recipient'; END IF;
 UPDATE public.todos SET assigned_to_user_id=NULL WHERE id=202;
 -- Verified next day 08:00 risk is visible in the 17:15 wrap-up.
 p:=notification_private.digest_plan(owner,'2026-10-23','wrapup',wrap_due);
 IF p->>'slot_at'<>'2026-10-23T11:15:00+00:00' THEN
    RAISE EXCEPTION 'Wrong wrap-up Dhaka 17:15 instant %',p; END IF;
 SELECT j->>'source_version' INTO ver FROM jsonb_array_elements(p->'items') j
 WHERE (j->>'todo_id')::bigint=202;
 INSERT INTO notification_private.core_verified_deadlines(
   entity_type,entity_id,recipient_user_id,source_version,
   actual_deadline_at,verified_basis,evidence_reference,verified_at)
 VALUES('todo','202',owner,ver,'2026-10-24T02:00:00Z',
  'manual_verified','Synthetic authoritative 08:00 joining fact',
  '2026-10-22T09:00:00Z');
 p:=notification_private.digest_plan(owner,'2026-10-23','wrapup',wrap_due);
 IF (p->>'risk_count')::int<>1 OR
 NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'items') j
   WHERE (j->>'todo_id')::bigint=202
   AND j->>'group_key'='BEFORE_NEXT_OPEN_RISK'
   AND j->>'verified_deadline_at'='2026-10-24T02:00:00+00:00') THEN
   RAISE EXCEPTION '17:15 failed to preserve real 08:00 risk %',p; END IF;
 v:=public.notification_digest_prepare_slot(owner,'2026-10-23','wrapup',wrap_due);
 IF (v->>'item_count')::int<>21 OR
    (SELECT count(*) FROM notification_private.digest_batches)<>2 THEN
    RAISE EXCEPTION 'Wrap-up must be a separate single batch %',v; END IF;
 -- After-hours/cron outage latest-slot recovery must never replay 20 pushes.
 v:=public.notification_digest_reconcile(owner,'2026-10-23T15:30:00Z');
 IF v->>'digest_kind'<>'wrapup' OR v->>'catchup'<>'true' OR
   (v->>'push_jobs_created')::int<>0 OR
   (SELECT count(*) FROM notification_private.digest_batches)<>2 THEN
   RAISE EXCEPTION 'Night missed cron catchup created duplicate digest %',v; END IF;
 v:=public.notification_digest_reconcile(owner,'2026-10-24T02:59:00Z');
 IF v->>'digest_kind'<>'wrapup' OR v->>'local_day'<>'2026-10-23' THEN
   RAISE EXCEPTION '08:59 local must still reconcile previous wrapup %',v; END IF;
 v:=public.notification_digest_reconcile(owner,next_morning);
 IF v->>'digest_kind'<>'morning' OR v->>'local_day'<>'2026-10-24'
   OR (v->>'item_count')::int<>21 OR
   (SELECT count(*) FROM notification_private.digest_batches)<>3 THEN
   RAISE EXCEPTION 'Next 09:05 missed-work reconciliation failed %',v; END IF;
 p:=notification_private.digest_plan(owner,'2026-10-24','morning',next_morning);
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p->'items') j
   WHERE (j->>'todo_id')::bigint=202 AND j->>'group_key'='OVERDUE') THEN
   RAISE EXCEPTION 'Actual 08:00 deadline must stay overdue at 09:05 %',p; END IF;
 -- No invented holiday/workday rules; next opening is indicative only.
 IF p->>'calendar_verified'<>'false' THEN
   RAISE EXCEPTION 'Invented office holiday calendar'; END IF;
 -- Very stale replay prohibited; latest-slot reconciliation carries real source.
 BEGIN
   PERFORM public.notification_digest_prepare_slot(owner,'2026-10-20','morning',next_morning);
   RAISE EXCEPTION 'Old missed slots must not be replayed';
 EXCEPTION WHEN sqlstate '22023' THEN NULL;
 END;
 -- No new jobs, notifications, source statuses, or push subscriptions are created.
 IF to_regclass('public.notification_jobs') IS NOT NULL THEN
   RAISE EXCEPTION 'Unexpected sender table in Phase 3 isolated fixture';
 END IF;
 IF has_function_privilege('anon','public.notification_digest_prepare_slot(uuid,date,text,timestamptz)','EXECUTE')
 OR has_function_privilege('authenticated','public.notification_digest_reconcile(uuid,timestamptz)','EXECUTE')
 OR has_table_privilege('authenticated','notification_private.digest_batches','SELECT')
 OR has_table_privilege('anon','notification_private.digest_items','SELECT') THEN
   RAISE EXCEPTION 'Unsafe direct grants'; END IF;
END $test$;
-- Disallowed operator must not read digest source identifiers.
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $test$ BEGIN
 BEGIN
  PERFORM public.notification_digest_preview('2026-10-23','morning');
  RAISE EXCEPTION 'Unauthorized preview unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $test$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: Phase 3 09:05+17:15 UTC, 20-item digest, idempotency, source revalidation, privacy, failed-cron catchup and deadline preservation' result;
