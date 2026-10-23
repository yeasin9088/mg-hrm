-- Disposable PostgreSQL 16 schema only. Never run against production.
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA notification_private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,is_active boolean);
CREATE TABLE public.todos(
 id bigint PRIMARY KEY,owner_user_id uuid,assigned_to_user_id uuid,status text,
 manager_status text,priority text,is_important boolean NOT NULL DEFAULT false,
 updated_at timestamptz,solved_at timestamptz,deleted_at timestamptz,
 note text,reminder_enabled boolean DEFAULT true
);
CREATE FUNCTION notification_private.todo_actionable(t public.todos)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT t.deleted_at IS NULL AND t.solved_at IS NULL
 AND lower(coalesce(t.status,'')) NOT IN ('closed','cancelled','solved','completed')
$$;
CREATE TABLE public.swa_work_items(
 owner_user_id uuid,source_module text,source_record_id text,
 acknowledged_until timestamptz,snoozed_until timestamptz,
 completed_at timestamptz,cancelled_at timestamptz
);
CREATE TABLE public.notifications(
 id uuid PRIMARY KEY,recipient_user_id uuid,category text,priority text,status text,
 entity_type text,entity_id text,scheduled_for timestamptz,expires_at timestamptz,
 first_delivered_at timestamptz,read_at timestamptz,snoozed_until timestamptz
);
CREATE TABLE public.notification_preferences(
 user_id uuid,category text,notification_enabled boolean,system_push_enabled boolean
);
CREATE FUNCTION public.notification_effective_preference(p_user_id uuid,p_category text)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT jsonb_build_object('notification_enabled',notification_enabled,
   'system_push_enabled',system_push_enabled)
   FROM public.notification_preferences WHERE user_id=p_user_id
     AND category=p_category LIMIT 1),'{"notification_enabled":true,"system_push_enabled":true}'::jsonb)
$$;
CREATE FUNCTION public.notification_source_state(p_type text,p_id text)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('supported',p_type='transfer',
   'resolved',p_type='transfer' AND p_id='66','state',
   CASE WHEN p_id='66' THEN 'Completed' ELSE 'Open' END)
$$;
CREATE FUNCTION public.swa_is_operator() RETURNS boolean LANGUAGE sql STABLE
 SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid()='11111111-1111-4111-8111-111111111111'::uuid
$$;
INSERT INTO public.profiles VALUES('11111111-1111-4111-8111-111111111111',true);
INSERT INTO public.todos VALUES
(101,'11111111-1111-4111-8111-111111111111',null,'open','pending','normal',false,
 '2026-10-23 01:00:00+00',null,null,'SECRET SALARY TEXT',true);
INSERT INTO public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111',
'ToDo','Normal','Ready','todo','101');
