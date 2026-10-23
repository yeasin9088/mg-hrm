-- Preserve historical Present records while preventing any new or changed
-- Present attendance from being stored without a selected representative.
-- Existing 27 legacy incomplete Present rows (aggregate preflight) are never rewritten.
BEGIN;
CREATE OR REPLACE FUNCTION public.mghrm_present_representative_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$
DECLARE validate_selection boolean := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    validate_selection := true;
  ELSE
    validate_selection :=
      OLD.status IS DISTINCT FROM NEW.status
      OR OLD.employee_id IS DISTINCT FROM NEW.employee_id
      OR OLD.full_name IS DISTINCT FROM NEW.full_name
      OR (OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL);
  END IF;
  IF validate_selection AND NEW.deleted_at IS NULL AND NEW.status = 'Present'
    AND (NULLIF(BTRIM(NEW.employee_id), '') IS NULL
       OR NULLIF(BTRIM(NEW.full_name), '') IS NULL) THEN
    RAISE EXCEPTION 'Select a representative before marking a project Present'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.mghrm_present_representative_guard()
  FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS mghrm_present_representative_required
  ON public.meeting_attendance;
CREATE TRIGGER mghrm_present_representative_required
BEFORE INSERT OR UPDATE ON public.meeting_attendance
FOR EACH ROW EXECUTE FUNCTION public.mghrm_present_representative_guard();
COMMIT;
