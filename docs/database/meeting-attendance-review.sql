-- REVIEW ONLY. Not executed. Apply only after approval and a backup.
-- Existing duplicate active dates/projects cause this entire transaction to fail.
-- No attendance is deleted, reconstructed, or assigned an inferred status.
-- One-time migration, SQL-first cutover with ALL operators paused.
-- See meeting-attendance-deployment.md. Never apply while old clients can write.
BEGIN;

-- Fail promptly and roll back the entire migration if another session is active.
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.meetings, public.meeting_attendance IN ACCESS EXCLUSIVE MODE;
-- Deliberately no IF NOT EXISTS / OR REPLACE: unexpected prior objects need review.
ALTER TABLE public.meetings ADD COLUMN attendance_request_id uuid;
CREATE UNIQUE INDEX meetings_active_date_unique
  ON public.meetings(meeting_date) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX attendance_active_project_unique
  ON public.meeting_attendance(meeting_id, project_name) WHERE deleted_at IS NULL;
-- Attendance is per project, with a representative who can cover multiple projects.
ALTER TABLE public.meeting_attendance DROP CONSTRAINT unique_attendance;

CREATE FUNCTION public.mghrm_save_meeting_attendance(
  p_date date, p_expected jsonb, p_rows jsonb, p_metadata jsonb, p_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $function$
DECLARE
  m public.meetings%ROWTYPE;
  old_row public.meeting_attendance%ROWTYPE;
  item jsonb;
  actual_versions jsonb;
  expected_versions jsonb;
  result_rows jsonb;
  is_retry boolean := false;
BEGIN
  IF auth.uid() IS NULL OR coalesce(public.my_role(), 'none') NOT IN ('admin', 'editor') THEN
    RAISE EXCEPTION 'Meeting write permission required' USING ERRCODE = '42501';
  END IF;
  IF p_date IS NULL OR p_request_id IS NULL OR
     jsonb_typeof(p_expected) IS DISTINCT FROM 'object' OR
     NOT (p_expected ?& ARRAY['meeting','rows']) OR
     jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR
     jsonb_typeof(p_expected->'rows') IS DISTINCT FROM 'array' OR
     jsonb_typeof(p_metadata) IS DISTINCT FROM 'object' OR
     NOT (p_metadata ?& ARRAY['agenda','started_at','ended_at']) OR
     (p_metadata - ARRAY['agenda','started_at','ended_at']) <> '{}'::jsonb OR
     jsonb_typeof(p_metadata->'agenda') NOT IN ('string','null') OR
     jsonb_typeof(p_metadata->'started_at') NOT IN ('string','null') OR
     jsonb_typeof(p_metadata->'ended_at') NOT IN ('string','null') THEN
    RAISE EXCEPTION 'Invalid attendance request';
  END IF;
  -- Missing fields are NOT intentional blanks. Validate before any mutation.
  FOR item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR
       NOT (item ?& ARRAY['project_name','status','remarks','employee_id','full_name','designation','sort_order']) OR
       (item - ARRAY['project_name','status','remarks','employee_id','full_name','designation','sort_order']) <> '{}'::jsonb OR
       jsonb_typeof(item->'project_name') IS DISTINCT FROM 'string' OR
       jsonb_typeof(item->'status') NOT IN ('string','null') OR
       jsonb_typeof(item->'remarks') NOT IN ('string','null') OR
       jsonb_typeof(item->'employee_id') NOT IN ('string','null') OR
       jsonb_typeof(item->'full_name') NOT IN ('string','null') OR
       jsonb_typeof(item->'designation') NOT IN ('string','null') OR
       jsonb_typeof(item->'sort_order') NOT IN ('number','null') THEN
      RAISE EXCEPTION 'Incomplete or invalid attendance row';
    END IF;
  END LOOP;
  -- Also serializes ordinary REST writes during snapshot validation and commit.
  LOCK TABLE public.meetings, public.meeting_attendance IN SHARE ROW EXCLUSIVE MODE;
  IF (SELECT count(*) FROM public.meetings WHERE meeting_date = p_date::text AND deleted_at IS NULL) > 1 THEN
    RAISE EXCEPTION 'Ambiguous meeting date';
  END IF;
  SELECT * INTO m FROM public.meetings WHERE meeting_date = p_date::text AND deleted_at IS NULL;
  IF m.id IS NOT NULL AND nullif(btrim(m.meeting_id), '') IS NULL THEN
    RAISE EXCEPTION 'Existing meeting identifier requires review';
  END IF;
  -- A legacy NULL date is valid through its exact parent meeting_id. Existing
  -- NULL dates are preserved by UPDATE below; contradictory non-NULL dates fail.
  -- Check identity for retries as well, including writes by legacy clients.
  IF EXISTS (SELECT 1 FROM public.meeting_attendance
             WHERE deleted_at IS NULL AND
               ((meeting_date = p_date AND meeting_id IS DISTINCT FROM m.meeting_id) OR
                (meeting_id = m.meeting_id AND meeting_date IS NOT NULL AND meeting_date IS DISTINCT FROM p_date))) THEN
    RAISE EXCEPTION 'Attendance meeting/date identity mismatch';
  END IF;
  is_retry := m.id IS NOT NULL AND m.attendance_request_id = p_request_id;
  IF coalesce(is_retry, false) AND
    (m.agenda IS DISTINCT FROM p_metadata->>'agenda' OR
     m.started_at IS DISTINCT FROM (p_metadata->>'started_at')::timestamptz OR
     m.ended_at IS DISTINCT FROM (p_metadata->>'ended_at')::timestamptz) THEN
    RAISE EXCEPTION 'Meeting metadata changed after save; reload' USING ERRCODE = '40001';
  END IF;
  IF NOT coalesce(is_retry, false) THEN
    IF m.id IS NULL THEN
      IF p_expected->'meeting' IS DISTINCT FROM 'null'::jsonb OR
         EXISTS (SELECT 1 FROM public.meetings WHERE meeting_date = p_date::text) OR
         EXISTS (SELECT 1 FROM public.meeting_attendance WHERE meeting_date = p_date) THEN
        RAISE EXCEPTION 'Existing or historical records require review; reload';
      END IF;
    ELSIF (p_expected->'meeting'->>'id') IS DISTINCT FROM m.id::text OR
          (p_expected->'meeting'->>'updated_at')::timestamptz IS DISTINCT FROM m.updated_at THEN
      RAISE EXCEPTION 'Meeting changed on another device; reload before editing' USING ERRCODE = '40001';
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'version', updated_at) ORDER BY id), '[]'::jsonb)
      INTO actual_versions FROM public.meeting_attendance
      WHERE meeting_id = m.meeting_id AND deleted_at IS NULL;
    SELECT coalesce(jsonb_agg(jsonb_build_object('id', (r->>'id')::bigint,
        'version', (r->>'updated_at')::timestamptz) ORDER BY (r->>'id')::bigint), '[]'::jsonb)
      INTO expected_versions FROM jsonb_array_elements(p_expected->'rows') r;
    IF actual_versions IS DISTINCT FROM expected_versions THEN
      RAISE EXCEPTION 'Attendance changed on another device; reload before editing' USING ERRCODE = '40001';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) r
      WHERE nullif(btrim(r->>'project_name'), '') IS NULL OR
        (r->>'status' IS NOT NULL AND r->>'status' NOT IN ('Present','Absent',''))) OR
     (SELECT count(*) FROM jsonb_array_elements(p_rows)) <>
     (SELECT count(DISTINCT r->>'project_name') FROM jsonb_array_elements(p_rows) r) THEN
    RAISE EXCEPTION 'Invalid or duplicate attendance project/status';
  END IF;
  IF EXISTS (SELECT 1 FROM public.meeting_attendance a
      WHERE a.meeting_id = m.meeting_id AND a.deleted_at IS NULL AND
        NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) r WHERE r->>'project_name' = a.project_name)) THEN
    RAISE EXCEPTION 'Incomplete attendance set; existing rows must be preserved';
  END IF;
  IF NOT coalesce(is_retry, false) THEN
    IF m.id IS NULL THEN
      INSERT INTO public.meetings(meeting_id, meeting_date, title, venue, created_by)
        VALUES ('MTG-' || p_date::text, p_date::text, 'Morning Coordination Meeting', 'HQ', auth.uid()::text)
        RETURNING * INTO m;
    END IF;
    FOR item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
      SELECT * INTO old_row FROM public.meeting_attendance
        WHERE meeting_id = m.meeting_id AND project_name = item->>'project_name' AND deleted_at IS NULL;
      IF old_row.id IS NULL AND EXISTS (SELECT 1 FROM public.meeting_attendance
          WHERE meeting_id = m.meeting_id AND project_name = item->>'project_name' AND deleted_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Soft-deleted attendance requires review; cannot restore implicitly';
      END IF;
      IF old_row.id IS NULL THEN
        INSERT INTO public.meeting_attendance(meeting_id, meeting_date, project_name, status,
            remarks, employee_id, full_name, designation, sort_order)
          VALUES (m.meeting_id, p_date, item->>'project_name', item->>'status', item->>'remarks',
            item->>'employee_id', item->>'full_name', item->>'designation', (item->>'sort_order')::integer);
      ELSE
        UPDATE public.meeting_attendance SET status = item->>'status', remarks = item->>'remarks',
          employee_id = item->>'employee_id', full_name = item->>'full_name',
          designation = item->>'designation', sort_order = (item->>'sort_order')::integer
          WHERE id = old_row.id;
      END IF;
    END LOOP;
    UPDATE public.meetings SET agenda = p_metadata->>'agenda',
      started_at = (p_metadata->>'started_at')::timestamptz,
      ended_at = (p_metadata->>'ended_at')::timestamptz,
      submitted_at = coalesce(submitted_at, now()), not_held_reason = NULL,
      attendance_request_id = p_request_id
      WHERE id = m.id RETURNING * INTO m;
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id), '[]'::jsonb) INTO result_rows
    FROM public.meeting_attendance a WHERE meeting_id = m.meeting_id AND deleted_at IS NULL;
  -- Verify the persisted values even for an idempotent retry.
  IF jsonb_array_length(result_rows) <> jsonb_array_length(p_rows) OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_rows) wanted
    WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(result_rows) saved
      WHERE saved @> wanted)
  ) THEN
    RAISE EXCEPTION 'Persisted attendance differs from request';
  END IF;
  RETURN jsonb_build_object('meeting', to_jsonb(m), 'rows', result_rows);
END;
$function$;
REVOKE ALL ON FUNCTION public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid) TO authenticated;
-- Delivered at commit. Wait for PostgREST to expose the exact signature before app cutover.
NOTIFY pgrst, 'reload schema';
COMMIT;
