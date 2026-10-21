-- Containment: restore previous UTC/session-date behavior and publication set.
-- Does not change employee assignments or transfer history.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $preflight$
DECLARE
  signature text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'transfers'
  ) THEN RAISE EXCEPTION 'Transfer publication membership changed'; END IF;
  FOREACH signature IN ARRAY ARRAY[
    'public.confirm_transfer_joining(bigint,date,text)',
    'public.create_transfer_order(jsonb)',
    'public.get_transfer_action_queue()',
    'public.mark_transfer_not_joined(bigint,text,text)',
    'public.reschedule_transfer(bigint,date,text)'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p, unnest(p.proconfig) AS setting
       WHERE p.oid = to_regprocedure(signature)
         AND lower(split_part(setting,'=',1)) = 'timezone'
         AND split_part(setting,'=',2) = 'Asia/Dhaka'
    ) THEN RAISE EXCEPTION 'Transfer RPC timezone changed: %', signature; END IF;
  END LOOP;
END;
$preflight$;

ALTER PUBLICATION supabase_realtime DROP TABLE public.transfers;
ALTER FUNCTION public.confirm_transfer_joining(bigint,date,text) RESET TimeZone;
ALTER FUNCTION public.create_transfer_order(jsonb) RESET TimeZone;
ALTER FUNCTION public.get_transfer_action_queue() RESET TimeZone;
ALTER FUNCTION public.mark_transfer_not_joined(bigint,text,text) RESET TimeZone;
ALTER FUNCTION public.reschedule_transfer(bigint,date,text) RESET TimeZone;
COMMIT;
