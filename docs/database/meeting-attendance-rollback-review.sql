-- REVIEW ONLY. Emergency containment, NOT an automatic return to the unsafe old app.
-- Pause all operators/clients FIRST; this does not block legacy direct table writes.
-- Retain all data, request tokens, indexes and RPC definition for investigation.
BEGIN;
REVOKE ALL ON FUNCTION public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid)
  FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;

-- OPTIONAL, SEPARATE APPROVAL: restore the legacy uniqueness model only after
-- the preflight's legacy_employee_constraint_conflicts is zero and all writes
-- remain paused. Do NOT delete rows or null employee IDs to make it succeed.
-- The new function must stay disabled: it supports shared representatives.
--
-- BEGIN;
-- SET LOCAL lock_timeout = '5s';
-- LOCK TABLE public.meetings, public.meeting_attendance IN ACCESS EXCLUSIVE MODE;
-- ALTER TABLE public.meeting_attendance ADD CONSTRAINT unique_attendance
--   UNIQUE (meeting_id, employee_id);
-- DROP INDEX public.attendance_active_project_unique;
-- DROP INDEX public.meetings_active_date_unique;
-- COMMIT;
--
-- Keep attendance_request_id and the disabled function. Dropping the column
-- destroys retry evidence and is not necessary for containment.
