-- Approved types apply to NEW actions; legacy rows retain their original type and print title.
-- A unique client operation key prevents accidental double creation after a retry.
CREATE UNIQUE INDEX IF NOT EXISTS disciplinary_action_id_unique
  ON public.disciplinary (action_id) WHERE action_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.disciplinary_edit_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  disciplinary_id bigint NOT NULL,
  editor_user_id uuid NOT NULL,
  changed_fields text[] NOT NULL,
  edited_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.disciplinary_edit_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.disciplinary_edit_audit FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.disciplinary_edit_audit_id_seq FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.mghrm_disciplinary_validate_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public, pg_temp AS $$
BEGIN
  IF NEW.action_type IS NULL OR NEW.action_type NOT IN
    ('Show Cause Notice','Warning Letter','Final Warning Letter',
     'Final Show Cause Notice','Suspension Order','Suspension Revocation Order','Dismissal Order')
  THEN
    RAISE EXCEPTION 'Select an approved disciplinary action type' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.mghrm_disciplinary_after_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_key text := 'disciplinary:recorded:v1:' || NEW.id::text;
BEGIN
  -- The existing RLS insert policy checks admin/editor. Never fan out confidential
  -- records to users whose scope or assignment has not been proven here.
  IF NEW.deleted_at IS NOT NULL OR v_actor IS NULL
     OR (SELECT public.my_role()) NOT IN ('admin','editor') THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.notification_events
    (event_type,entity_type,entity_id,employee_sys_id,actor_user_id,
     event_key,event_payload,occurred_at)
  VALUES
    ('DisciplinaryRecordCreated','disciplinary',NEW.id::text,NEW.employee_sys_id,v_actor,
     v_key,jsonb_build_object(
       'recipient_user_id',v_actor,
       'category','Disciplinary','severity','Info','priority','Normal',
       'title','Disciplinary action recorded',
       'message','A ' || NEW.action_type || ' record is ready for authorized review.',
       'dedupe_key',v_key,
       'action_label','Open Record','action_route','disciplinary',
       'action_params',jsonb_build_object('notification_type','disciplinary','record_id',NEW.id),
       'scheduled_for',clock_timestamp()
     ),clock_timestamp())
  ON CONFLICT (event_key) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.mghrm_disciplinary_after_update()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
DECLARE
  v_fields text[] := ARRAY[]::text[];
  v_actor uuid := (SELECT auth.uid());
BEGIN
  IF OLD.incident_date IS DISTINCT FROM NEW.incident_date THEN
    v_fields := array_append(v_fields,'incident_date');
  END IF;
  IF OLD.issue_date IS DISTINCT FROM NEW.issue_date THEN
    v_fields := array_append(v_fields,'issue_date');
  END IF;
  IF OLD.description IS DISTINCT FROM NEW.description THEN
    v_fields := array_append(v_fields,'description');
  END IF;
  IF cardinality(v_fields) > 0 AND v_actor IS NOT NULL THEN
    INSERT INTO public.disciplinary_edit_audit
      (disciplinary_id,editor_user_id,changed_fields)
    VALUES (NEW.id,v_actor,v_fields);
  END IF;
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    UPDATE public.notifications n
      SET status='Cancelled'
      FROM public.notification_events e
      WHERE n.event_id=e.id AND e.event_key='disciplinary:recorded:v1:' || NEW.id::text
        AND n.status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS disciplinary_validate_insert_trg ON public.disciplinary;
CREATE TRIGGER disciplinary_validate_insert_trg BEFORE INSERT ON public.disciplinary
  FOR EACH ROW EXECUTE FUNCTION public.mghrm_disciplinary_validate_insert();
DROP TRIGGER IF EXISTS disciplinary_notify_insert_trg ON public.disciplinary;
CREATE TRIGGER disciplinary_notify_insert_trg AFTER INSERT ON public.disciplinary
  FOR EACH ROW EXECUTE FUNCTION public.mghrm_disciplinary_after_insert();
DROP TRIGGER IF EXISTS disciplinary_audit_update_trg ON public.disciplinary;
CREATE TRIGGER disciplinary_audit_update_trg AFTER UPDATE ON public.disciplinary
  FOR EACH ROW EXECUTE FUNCTION public.mghrm_disciplinary_after_update();

REVOKE ALL ON FUNCTION public.mghrm_disciplinary_validate_insert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mghrm_disciplinary_after_insert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mghrm_disciplinary_after_update() FROM PUBLIC, anon, authenticated;
