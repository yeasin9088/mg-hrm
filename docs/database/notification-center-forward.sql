-- Additive inbox state for existing browser-produced operational reminders.
-- No notification/event/job history is updated or deleted. Existing worker RPCs
-- and single-operator authorization are unchanged.
BEGIN;
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.notification_legacy_states (
  user_id uuid NOT NULL REFERENCES public.profiles(id),
  event_key text NOT NULL CHECK (length(event_key) BETWEEN 1 AND 1024),
  status text NOT NULL CHECK (status IN ('Read','Dismissed','Snoozed')),
  read_at timestamptz,
  snoozed_until timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_key),
  CHECK ((status = 'Snoozed' AND snoozed_until IS NOT NULL) OR
         (status <> 'Snoozed' AND snoozed_until IS NULL))
);
ALTER TABLE public.notification_legacy_states ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_legacy_states_owner ON public.notification_legacy_states
  FOR ALL TO authenticated
  USING (user_id = auth.uid() AND public.my_role() <> 'none')
  WITH CHECK (user_id = auth.uid() AND public.my_role() <> 'none');
REVOKE ALL ON public.notification_legacy_states FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notification_legacy_states TO authenticated;
COMMENT ON TABLE public.notification_legacy_states IS
  'Owned read/dismiss/snooze state for stable legacy business-event identities; no employee/message contents.';
CREATE FUNCTION public.notification_claim_todo_reminder(
  p_todo_id bigint, p_expected_next timestamptz, p_next timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $function$
DECLARE t public.todos%ROWTYPE; recipient uuid := auth.uid(); due timestamptz; event_identity text;
BEGIN
  IF recipient IS NULL OR public.my_role() NOT IN ('admin','editor') THEN
    RAISE EXCEPTION 'Active operator permission required' USING ERRCODE='42501';
  END IF;
  IF p_next IS NOT NULL AND (p_next <= clock_timestamp() OR p_next > clock_timestamp() + interval '10 years') THEN
    RAISE EXCEPTION 'Invalid next reminder time' USING ERRCODE='22023';
  END IF;
  SELECT * INTO t FROM public.todos WHERE id=p_todo_id FOR UPDATE;
  IF NOT FOUND OR t.deleted_at IS NOT NULL OR t.reminder_enabled IS DISTINCT FROM true OR t.solved_at IS NOT NULL OR
     lower(coalesce(t.status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     lower(coalesce(t.manager_status,'')) IN ('done','closed','resolved','completed','solved','solved_approved','solved_rejected') OR
     t.next_reminder_at IS DISTINCT FROM p_expected_next OR
     (t.next_reminder_at IS NOT NULL AND t.next_reminder_at > clock_timestamp()) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  IF NOT coalesce((public.notification_effective_preference(recipient,'ToDo')->>'notification_enabled')::boolean,true) THEN
    RETURN jsonb_build_object('claimed',false);
  END IF;
  due := coalesce(t.next_reminder_at,date_trunc('minute',clock_timestamp()));
  event_identity := 'todo-reminder:' || t.id::text || ':' || extract(epoch FROM due)::text;
  INSERT INTO public.notification_events(event_type,entity_type,entity_id,actor_user_id,event_key,event_payload,occurred_at)
  VALUES ('TodoReminderDue','todo',t.id::text,recipient,event_identity,
    jsonb_build_object('recipient_user_id',recipient,'category','ToDo','severity','Info','priority','Normal',
      'title','To-Do reminder','message','A scheduled note needs your attention. Open MG-HRM to review it.',
      'action_label','Review note','action_route','todo','dedupe_key',event_identity,
      'action_params',jsonb_build_object('notification_type','todo_rem'),'scheduled_for',due),due)
  ON CONFLICT (event_key) DO NOTHING;
  UPDATE public.todos SET next_reminder_at=p_next,
    reminder_enabled=CASE WHEN p_next IS NULL THEN false ELSE reminder_enabled END WHERE id=t.id;
  RETURN jsonb_build_object('claimed',true,'event_key',event_identity,'occurred_at',due);
END;
$function$;
REVOKE ALL ON FUNCTION public.notification_claim_todo_reminder(bigint,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_claim_todo_reminder(bigint,timestamptz,timestamptz) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
