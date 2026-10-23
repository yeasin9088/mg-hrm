-- Disposable PostgreSQL 16 test extension for Phase 3; never run in production.
ALTER TABLE public.todos ADD COLUMN created_at timestamptz NOT NULL
  DEFAULT '2026-10-20T09:00:00Z';
ALTER TABLE public.todos ADD COLUMN category text NOT NULL DEFAULT 'task';
-- Twenty independent overnight To-Dos, one unique operator and no Push jobs.
INSERT INTO public.todos(id,owner_user_id,assigned_to_user_id,status,
  manager_status,priority,is_important,updated_at,solved_at,deleted_at,note,
  reminder_enabled,created_at,category)
SELECT n,'11111111-1111-4111-8111-111111111111',NULL,
  'pending',CASE WHEN n=200 THEN 'asked' ELSE 'none' END,
  'normal',false,'2026-10-22T18:00:00Z',NULL,NULL,
  'Sensitive internal work details never allowed in digest preview',
  true,'2026-10-22T18:00:00Z',
  CASE WHEN n=200 THEN 'permission' ELSE 'task' END
FROM generate_series(200,219) AS n;
