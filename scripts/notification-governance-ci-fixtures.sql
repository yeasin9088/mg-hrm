-- Entirely synthetic PostgreSQL CI fixtures. NEVER execute on production.
CREATE SCHEMA notification_private;
ALTER TABLE public.todos ADD COLUMN reminder_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE public.todos ADD COLUMN reminder_type text DEFAULT '1h';
ALTER TABLE public.todos ADD COLUMN reminder_interval integer DEFAULT 60;
ALTER TABLE public.todos ADD COLUMN assigned_to_user_id uuid;
ALTER TABLE public.todos ADD COLUMN owner_user_id uuid;
ALTER TABLE public.todos ADD COLUMN priority text DEFAULT 'Normal';
ALTER TABLE public.todos ADD COLUMN manager_status text;
UPDATE public.todos SET owner_user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
CREATE TABLE public.notification_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 event_type text NOT NULL,
 entity_type text,
 entity_id text,
 actor_user_id uuid,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE public.notifications(
 id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
 recipient_user_id uuid,
 event_id bigint REFERENCES public.notification_events(id),
 entity_type text,
 entity_id text,
 status text,
 snoozed_until timestamptz,
 created_at timestamptz DEFAULT clock_timestamp(),
 read_at timestamptz,
 dismissed_at timestamptz
);
CREATE FUNCTION notification_private.todo_actionable(p public.todos)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT p.deleted_at IS NULL AND p.solved_at IS NULL AND
 lower(btrim(coalesce(p.status,''))) NOT IN ('solved','closed','completed','cancelled')
$$;
CREATE FUNCTION public.notification_effective_preference(p_user_id uuid,p_category text)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT '{"notification_enabled":true}'::jsonb
$$;
