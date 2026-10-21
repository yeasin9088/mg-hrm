-- Synthetic isolated PostgreSQL test. Requires baseline transfer RPC definitions,
-- employees/transfers/activity_log tables, cancel_transfer and the forward migration. Rolls back.
BEGIN;
SET LOCAL TimeZone TO 'UTC';

DO $test$
DECLARE
  before_midnight timestamptz := '2026-10-20 17:59:59+00';
  at_midnight timestamptz := '2026-10-20 18:00:00+00';
  v_employee_id bigint;
  v_transfer_id bigint;
  v_second_employee_id bigint;
  v_second_transfer_id bigint;
  v_result jsonb;
  v_project text;
  v_today date := (now() AT TIME ZONE 'Asia/Dhaka')::date;
  boundary_hour integer;
BEGIN
  IF (before_midnight AT TIME ZONE 'Asia/Dhaka')::date <> DATE '2026-10-20'
     OR (at_midnight AT TIME ZONE 'Asia/Dhaka')::date <> DATE '2026-10-21'
     OR (at_midnight AT TIME ZONE 'UTC')::date <> DATE '2026-10-20' THEN
    RAISE EXCEPTION 'Bangladesh midnight boundary failed';
  END IF;
  FOR boundary_hour IN 0..5 LOOP
    IF ((at_midnight + make_interval(hours => boundary_hour)) AT TIME ZONE 'Asia/Dhaka')::date <> DATE '2026-10-21'
       OR ((at_midnight + make_interval(hours => boundary_hour)) AT TIME ZONE 'UTC')::date <> DATE '2026-10-20' THEN
      RAISE EXCEPTION 'Bangladesh 00:00-06:00 boundary failed at hour %', boundary_hour;
    END IF;
  END LOOP;
  IF ((at_midnight + interval '6 hours') AT TIME ZONE 'UTC')::date <> DATE '2026-10-21' THEN
    RAISE EXCEPTION 'UTC rollover control failed';
  END IF;

  INSERT INTO public.employees(employee_id,full_name,status,project_name)
  VALUES ('SYNTHETIC-TRANSFER-1','Synthetic Employee','Active','Source')
  RETURNING id INTO v_employee_id;

  v_result := public.create_transfer_order(jsonb_build_object(
    'employee_sys_id',v_employee_id,'new_project','Destination',
    'current_project','Source','effective_date',(v_today + 1)::text
  ));
  v_transfer_id := (v_result->'transfer'->>'id')::bigint;
  IF v_result->'transfer'->>'status' <> 'Scheduled' THEN
    RAISE EXCEPTION 'Future transfer should remain Scheduled';
  END IF;
  SELECT project_name INTO v_project FROM public.employees WHERE id = v_employee_id;
  IF v_project <> 'Source' THEN RAISE EXCEPTION 'Creation changed current project'; END IF;

  BEGIN
    PERFORM public.confirm_transfer_joining(v_transfer_id,v_today + 1,NULL);
    RAISE EXCEPTION 'Future joining was accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;

  v_result := public.reschedule_transfer(v_transfer_id,v_today,'Synthetic schedule correction');
  IF v_result->>'status' <> 'Joining Pending' THEN
    RAISE EXCEPTION 'Same-day reschedule did not become joining pending';
  END IF;
  SELECT project_name INTO v_project FROM public.employees WHERE id = v_employee_id;
  IF v_project <> 'Source' THEN RAISE EXCEPTION 'Reschedule changed current project'; END IF;

  BEGIN
    PERFORM public.confirm_transfer_joining(v_transfer_id,v_today - 1,NULL);
    RAISE EXCEPTION 'Before-effective-date joining was accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;

  v_result := public.confirm_transfer_joining(v_transfer_id,v_today,'Synthetic confirmation');
  IF v_result->'transfer'->>'status' <> 'Completed'
     OR v_result->'employee'->>'project_name' <> 'Destination' THEN
    RAISE EXCEPTION 'Explicit joining did not atomically complete assignment';
  END IF;
  BEGIN
    PERFORM public.confirm_transfer_joining(v_transfer_id,v_today,NULL);
    RAISE EXCEPTION 'Duplicate completion was accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;

  INSERT INTO public.employees(employee_id,full_name,status,project_name)
  VALUES ('SYNTHETIC-TRANSFER-2','Second Synthetic Employee','Active','Source')
  RETURNING id INTO v_second_employee_id;
  v_result := public.create_transfer_order(jsonb_build_object(
    'employee_sys_id',v_second_employee_id,'new_project','Destination',
    'current_project','Source','effective_date',v_today::text
  ));
  v_second_transfer_id := (v_result->'transfer'->>'id')::bigint;
  IF v_result->'transfer'->>'status' <> 'Joining Pending'
     OR NOT EXISTS (SELECT 1 FROM public.get_transfer_action_queue() WHERE transfer_id=v_second_transfer_id) THEN
    RAISE EXCEPTION 'Same-day transfer action queue failed';
  END IF;
  v_result := public.mark_transfer_not_joined(v_second_transfer_id,'Synthetic no-show',NULL);
  IF v_result->>'status' <> 'Not Joined' THEN RAISE EXCEPTION 'Not Joined transition failed'; END IF;
  v_result := public.reschedule_transfer(v_second_transfer_id,v_today + 1,'Synthetic retry');
  IF v_result->>'status' <> 'Scheduled' THEN RAISE EXCEPTION 'Future reschedule failed'; END IF;
  v_result := public.cancel_transfer(v_second_transfer_id,'Synthetic cancellation');
  IF v_result->>'status' <> 'Cancelled' THEN RAISE EXCEPTION 'Cancellation failed'; END IF;
  SELECT project_name INTO v_project FROM public.employees WHERE id=v_second_employee_id;
  IF v_project <> 'Source' THEN RAISE EXCEPTION 'Uncompleted transfer changed project'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p WHERE p.oid='public.confirm_transfer_joining(bigint,date,text)'::regprocedure
      AND 'TimeZone=Asia/Dhaka'=ANY(p.proconfig) AND NOT p.prosecdef
  ) THEN RAISE EXCEPTION 'Function timezone or SECURITY INVOKER drifted'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
      AND schemaname='public' AND tablename='transfers'
  ) THEN RAISE EXCEPTION 'Transfer publication membership missing'; END IF;
END;
$test$;

-- Test broad table GRANT with RLS: anon still sees no transfer rows.
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.transfers TO anon, authenticated;
SET LOCAL ROLE anon;
DO $test$ BEGIN
  IF (SELECT count(*) FROM public.transfers) <> 0 THEN
    RAISE EXCEPTION 'Anonymous role can read transfer rows';
  END IF;
END $test$;
RESET ROLE;
ROLLBACK;
