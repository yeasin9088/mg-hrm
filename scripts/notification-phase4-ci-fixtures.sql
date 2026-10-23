-- Isolated Phase4 fixtures after Phase1->Phase2->Phase3, never production.
CREATE SCHEMA swa_private;
CREATE TABLE swa_private.operator_ids(user_id uuid PRIMARY KEY);
INSERT INTO swa_private.operator_ids
VALUES('11111111-1111-4111-8111-111111111111');
CREATE TABLE notification_private.governance_control(
 singleton boolean PRIMARY KEY DEFAULT true, enabled boolean NOT NULL DEFAULT false);
INSERT INTO notification_private.governance_control VALUES(true,false);

CREATE TABLE public.notification_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 event_type text NOT NULL,entity_type text NOT NULL,entity_id text NOT NULL,
 actor_user_id uuid,event_key text NOT NULL UNIQUE,event_payload jsonb NOT NULL,
 occurred_at timestamptz,processing_status text NOT NULL DEFAULT 'Pending',
 processed_at timestamptz,processing_error text
);
ALTER TABLE public.notifications
 ADD COLUMN event_id bigint,
 ADD COLUMN severity text,
 ADD COLUMN title text,
 ADD COLUMN message text,
 ADD COLUMN action_label text,
 ADD COLUMN action_route text,
 ADD COLUMN action_params jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE TABLE public.notification_jobs(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 notification_id uuid,job_type text,job_status text,locked_by text,
 attempt_count integer DEFAULT 1,maximum_attempts integer DEFAULT 5,
 run_at timestamptz,locked_at timestamptz
);
CREATE TABLE public.push_subscriptions(
 id bigint PRIMARY KEY,user_id uuid,is_active boolean,
 permission_state text,revoked_at timestamptz,
 endpoint text,p256dh_key text,auth_key text
);
-- Phase2 already provides actual-send evidence in notification_deliveries.
-- Keep it intact and extend to the existing dispatch RPC shape.
ALTER TABLE public.notification_deliveries
 ADD COLUMN subscription_id bigint,
 ADD COLUMN provider_status text,
 ADD COLUMN response_metadata jsonb DEFAULT '{}'::jsonb,
 ADD COLUMN attempt_number integer DEFAULT 1;
CREATE FUNCTION public.notification_reminder_mode()
 RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
CREATE FUNCTION notification_private.has_foreground(uuid)
 RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
CREATE FUNCTION notification_private.push_source_ineligible(text,text,uuid)
 RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
CREATE FUNCTION public.notification_schedule_todos(integer)
 RETURNS jsonb LANGUAGE sql AS $$SELECT '{"legacy":"v1_sched"}'::jsonb$$;
CREATE FUNCTION public.notification_run_server_processor(text,integer,interval)
 RETURNS jsonb LANGUAGE sql AS $$SELECT '{"legacy":"v1_processor"}'::jsonb$$;
CREATE FUNCTION public.notification_complete_job(bigint,text)
 RETURNS public.notification_jobs LANGUAGE sql AS $
   SELECT j FROM public.notification_jobs j WHERE j.id=$1
 $;
CREATE FUNCTION public.notification_run_event_processor(text,integer,interval)
 RETURNS jsonb LANGUAGE sql AS $$SELECT '{"v2":"event_processor"}'::jsonb$$;
CREATE FUNCTION public.notification_prepare_deliveries(integer)
 RETURNS jsonb LANGUAGE sql AS $$SELECT '{"v2":"delivery_processor"}'::jsonb$$;
