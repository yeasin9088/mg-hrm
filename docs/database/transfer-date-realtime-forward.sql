-- Reviewed metadata-only transfer cutover. Run with psql -X -v ON_ERROR_STOP=1.
-- Requires a fresh encrypted backup and tested isolated restore before execution.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
DECLARE
  expected record;
  actual record;
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'PostgreSQL 17 or newer is required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c WHERE c.oid = 'public.transfers'::regclass
      AND c.relrowsecurity AND c.relreplident = 'd'
      AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid=c.oid AND k.contype='p')
  ) OR NOT has_table_privilege('authenticated', 'public.transfers', 'SELECT')
    OR EXISTS (
      SELECT 1 FROM pg_policy p WHERE p.polrelid = 'public.transfers'::regclass
        AND p.polcmd = 'r' AND 'anon'::regrole = ANY(p.polroles)
    ) THEN
    RAISE EXCEPTION 'Transfer RLS, replica identity or authenticated read contract drifted';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
      AND NOT puballtables AND pubinsert AND pubupdate AND pubdelete
  ) OR EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'transfers'
  ) THEN
    RAISE EXCEPTION 'Realtime publication contract drifted';
  END IF;

  FOR expected IN SELECT * FROM (VALUES
    ('public.confirm_transfer_joining(bigint,date,text)', '4b2e78afc6352c79c1086ff581ab9bdc'),
    ('public.create_transfer_order(jsonb)', 'f3c3e055238d2bff5a9eb5ab0693f42b'),
    ('public.get_transfer_action_queue()', '8e3b5a1cdfa0cbea9fd927964839559c'),
    ('public.mark_transfer_not_joined(bigint,text,text)', '4c5caa03553468be3102f914f727f5e1'),
    ('public.reschedule_transfer(bigint,date,text)', 'd2b82a3c766643609f57967b438ee45d')
  ) AS v(signature, definition_md5) LOOP
    SELECT p.prosecdef, p.proconfig, md5(pg_get_functiondef(p.oid)) AS definition_md5
      INTO actual FROM pg_proc p WHERE p.oid = to_regprocedure(expected.signature);
    IF NOT FOUND OR actual.prosecdef OR actual.definition_md5 <> expected.definition_md5
       OR actual.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[] THEN
      RAISE EXCEPTION 'Transfer RPC contract drifted: %', expected.signature;
    END IF;
  END LOOP;
END;
$preflight$;

-- CURRENT_DATE inside these unchanged SECURITY INVOKER bodies now uses the
-- Bangladesh business day. This never calls a transfer RPC or updates a row.
ALTER FUNCTION public.confirm_transfer_joining(bigint,date,text) SET TimeZone TO 'Asia/Dhaka';
ALTER FUNCTION public.create_transfer_order(jsonb) SET TimeZone TO 'Asia/Dhaka';
ALTER FUNCTION public.get_transfer_action_queue() SET TimeZone TO 'Asia/Dhaka';
ALTER FUNCTION public.mark_transfer_not_joined(bigint,text,text) SET TimeZone TO 'Asia/Dhaka';
ALTER FUNCTION public.reschedule_transfer(bigint,date,text) SET TimeZone TO 'Asia/Dhaka';

-- Keep DEFAULT replica identity: clients invalidate and perform RLS-checked
-- reads. No full old-row images and no additional table are published.
ALTER PUBLICATION supabase_realtime ADD TABLE public.transfers;
COMMIT;
