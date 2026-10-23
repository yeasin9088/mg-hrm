-- Phase4 integration: actual versioned migration and existing pipeline contract.
BEGIN;
DO $test$
DECLARE
 owner uuid:='11111111-1111-4111-8111-111111111111';
 n uuid:='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
 morning timestamptz:='2026-10-23T03:05:00Z';
 wrap timestamptz:='2026-10-23T11:15:00Z';
 v jsonb; v2 jsonb; k text; b bigint; e bigint;
BEGIN
 -- V1 remains unchanged with both policy switches initially disabled.
 v:=notification_private.digest_publish_slot(owner,morning);
 IF v->>'status'<>'Disabled' OR
    (SELECT count(*) FROM public.notification_events)<>0 OR
    (SELECT count(*) FROM notification_private.digest_batches)<>0 THEN
   RAISE EXCEPTION 'Disabled Phase4 must not touch source/event/queue %',v; END IF;
 IF (public.notification_cron_tick()->>'processor'->>'legacy') IS NULL THEN
   -- Parser-safe compatibility assertion performed via explicit JSON below.
   NULL;
 END IF;
 v:=public.notification_cron_tick();
 IF v->>'status'<>'Completed' OR v->'processor'->>'legacy'<>'v1_processor' THEN
   RAISE EXCEPTION 'V1 cron must remain unchanged while disabled %',v; END IF;
 UPDATE notification_private.governance_control SET enabled=true WHERE singleton;
 v:=notification_private.digest_publish_slot(owner,morning);
 IF v->>'status'<>'Disabled' THEN
   RAISE EXCEPTION 'Second bridge safety switch must stay closed'; END IF;
 UPDATE notification_private.digest_bridge_control SET enabled=true WHERE singleton;
 v:=notification_private.digest_publish_slot(owner,morning);
 IF v->>'status'<>'Published' OR v->>'published'<>'true' OR
   (SELECT count(*) FROM public.notification_events)<>1 THEN
   RAISE EXCEPTION 'One work digest event for 20+ sources required %',v; END IF;
 b:=(v->>'batch_id')::bigint;e:=(v->>'event_id')::bigint;
 SELECT event_key INTO k FROM public.notification_events WHERE id=e;
 IF k NOT LIKE 'mghrm:work-digest:%:morning' OR
    (SELECT event_payload->>'category' FROM public.notification_events WHERE id=e)<>'System' OR
    (SELECT event_payload->>'action_route' FROM public.notification_events WHERE id=e)<>'notifications' OR
    (SELECT event_payload->>'expires_at' FROM public.notification_events WHERE id=e)
      <>'2026-10-23T12:00:00+00:00' THEN
    RAISE EXCEPTION 'Digest must route safely through original Notification Center'; END IF;
 IF (SELECT event_payload::text FROM public.notification_events WHERE id=e)
    LIKE '%Sensitive internal work details%' THEN
    RAISE EXCEPTION 'Digest event leaked source notes'; END IF;
 v2:=notification_private.digest_publish_slot(owner,morning+interval '1 second');
 IF v2->>'published'<>'false' OR
    (v2->>'event_id')::bigint<>e OR
    (SELECT count(*) FROM public.notification_events)<>1 OR
    (SELECT count(*) FROM notification_private.digest_publish_audit)<>1 THEN
    RAISE EXCEPTION 'Cron retries must not create duplicate digest event %',v2; END IF;
 v:=notification_private.digest_publish_slot(owner,'2026-10-23T15:30:00Z');
 IF v->>'status'<>'Deferred' OR
    (SELECT count(*) FROM public.notification_events)<>1 THEN
    RAISE EXCEPTION 'No routine nighttime digest Push %',v; END IF;
 v:=notification_private.digest_publish_slot(owner,wrap);
 IF v->>'status'<>'Published' OR
    (SELECT count(*) FROM public.notification_events)<>2 THEN
    RAISE EXCEPTION 'Wrap-up must be one DISTINCT slot event %',v; END IF;
 -- Create synthetic processed digest notification and one Push subscription.
 INSERT INTO public.notifications(
 id,recipient_user_id,category,priority,status,entity_type,entity_id,
 scheduled_for,expires_at,title,message,action_route)
 VALUES (n,owner,'System','Normal','Ready','digest',b::text,
   morning,'2026-10-23T12:00:00Z','Digest','Review pending work','notifications');
 INSERT INTO public.notification_jobs(notification_id,job_type,job_status,locked_by)
 VALUES(n,'DeliverWebPush','Processing','worker');
 INSERT INTO public.push_subscriptions VALUES(
  31,owner,true,'granted',null,'https://example.invalid/push','p256dh','auth');
 INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,delivery_status)
 VALUES(n,31,'WebPush','Pending');
 IF NOT notification_private.digest_dispatch_allowed(b::text,owner,morning)
   OR notification_private.digest_dispatch_allowed(b::text,
     '22222222-2222-4222-8222-222222222222',morning)
   OR notification_private.digest_dispatch_allowed(b::text,owner,'2026-10-23T15:30:00Z') THEN
   RAISE EXCEPTION 'Digest source, recipient or nighttime guard failed'; END IF;
 v:=public.notification_get_web_push_dispatch(
 (SELECT id FROM public.notification_jobs WHERE notification_id=n),'worker');
 IF jsonb_array_length(v->'deliveries')<>1 THEN
   RAISE EXCEPTION 'Valid digest must use existing Web Push dispatch %',v; END IF;
 UPDATE public.todos SET solved_at=morning WHERE id BETWEEN 200 AND 219 OR id=101;
 IF notification_private.digest_dispatch_allowed(b::text,owner,morning) THEN
   RAISE EXCEPTION 'Resolved source cannot authorize stale digest delivery'; END IF;
 v:=public.notification_get_web_push_dispatch(
 (SELECT id FROM public.notification_jobs WHERE notification_id=n),'worker');
 IF jsonb_array_length(v->'deliveries')<>0 OR
    NOT EXISTS(SELECT 1 FROM public.notification_deliveries
      WHERE notification_id=n AND delivery_status='Skipped') THEN
   RAISE EXCEPTION 'Existing dispatcher did not suppress stale digest %',v; END IF;
 IF has_function_privilege('anon','notification_private.digest_publish_slot(uuid,timestamptz)','EXECUTE')
 OR has_function_privilege('authenticated','notification_private.digest_publish_for_operators(timestamptz)','EXECUTE')
 OR has_table_privilege('anon','notification_private.digest_publish_audit','SELECT') THEN
   RAISE EXCEPTION 'Digest bridge escaped private authorization boundary'; END IF;
 -- Disabling governance immediately restores old cron branch.
 UPDATE notification_private.governance_control SET enabled=false WHERE singleton;
 v:=public.notification_cron_tick();
 IF v->'processor'->>'legacy'<>'v1_processor' THEN
   RAISE EXCEPTION 'V1 rollback toggle failed %',v; END IF;
END $test$;
ROLLBACK;
SELECT 'PASS Phase4: single summarized existing event, V1 feature gate, delivery source revalidation, no nighttime push, private grants' result;
