-- Synthetic schema only for CI. Never run this against live MG-HRM.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY REFERENCES auth.users(id),is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.todos (
 id bigint PRIMARY KEY, note_bn text,note text,status text,deleted_at timestamptz,solved_at timestamptz,
 category text,who text,project text,is_important boolean DEFAULT false,
 next_reminder_at timestamptz,created_at timestamptz
);
GRANT USAGE ON SCHEMA auth TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,service_role;
INSERT INTO auth.users VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.profiles VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
INSERT INTO public.todos(id,note_bn,note,status,category,project,is_important)
 VALUES(123,'Synthetic manager permission',NULL,'pending','permission','SYNTHETIC',true);
