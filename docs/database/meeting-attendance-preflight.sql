-- Read-only preflight. Production read-only investigation is authorized.
-- Returns counts only; no employee identities, dates, project names or attendance values.
BEGIN TRANSACTION READ ONLY;
SELECT
  (SELECT count(*) FROM (
    SELECT meeting_date FROM public.meetings WHERE deleted_at IS NULL
    GROUP BY meeting_date HAVING count(*) > 1
  ) d) AS duplicate_active_date_groups,
  (SELECT count(*) FROM (
    SELECT meeting_id, project_name FROM public.meeting_attendance WHERE deleted_at IS NULL
    GROUP BY meeting_id, project_name HAVING count(*) > 1
  ) d) AS duplicate_active_project_groups,
  (SELECT count(*) FROM public.meetings WHERE deleted_at IS NULL AND
    (nullif(btrim(meeting_id), '') IS NULL OR meeting_date IS NULL OR
     meeting_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR
     NOT pg_catalog.pg_input_is_valid(meeting_date, 'date'))) AS invalid_active_meeting_identity,
  (SELECT count(*) FROM public.meeting_attendance a
    LEFT JOIN public.meetings m ON m.meeting_id = a.meeting_id
    WHERE a.deleted_at IS NULL AND
      (m.id IS NULL OR m.deleted_at IS NOT NULL OR
       -- Legacy NULL dates resolve through the exact, valid parent ID.
       (a.meeting_date IS NOT NULL AND a.meeting_date::text IS DISTINCT FROM m.meeting_date) OR
       nullif(btrim(a.project_name), '') IS NULL)) AS unresolved_active_attendance_identity,
  (SELECT count(*) FROM public.meeting_attendance
    WHERE deleted_at IS NULL AND status IS NOT NULL AND status NOT IN ('Present','Absent',''))
    AS unsupported_active_status_rows,
  -- Relevant to a later constraint rollback; includes soft-deleted rows, as the old constraint does.
  (SELECT count(*) FROM (
    SELECT meeting_id, employee_id FROM public.meeting_attendance WHERE employee_id IS NOT NULL
    GROUP BY meeting_id, employee_id HAVING count(*) > 1
  ) d) AS legacy_employee_constraint_conflicts;
COMMIT;
