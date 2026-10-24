-- Keep already acknowledged reminders consistent when delivery hours change.
BEGIN;
ALTER FUNCTION public.notification_simple_settings_save(bigint,jsonb) RENAME TO notification_simple_settings_save_before_rebase;
REVOKE ALL ON FUNCTION public.notification_simple_settings_save_before_rebase(bigint,jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.notification_simple_settings_save(p_expected_revision bigint,p_changes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE old notification_private.simple_reminder_policy; saved jsonb; t public.todos; acknowledged timestamptz; due timestamptz; instant timestamptz:=clock_timestamp();
BEGIN
 IF auth.uid() IS NULL OR NOT public.swa_is_operator() THEN RAISE EXCEPTION 'Operator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO STRICT old FROM notification_private.simple_reminder_policy WHERE singleton FOR UPDATE;
 saved:=public.notification_simple_settings_save_before_rebase(p_expected_revision,p_changes);
 IF old.office_start IS DISTINCT FROM (saved->>'office_start')::time OR old.office_end IS DISTINCT FROM (saved->>'office_end')::time THEN
  PERFORM set_config('mghrm.scheduler_write','on',true);
  FOR t IN SELECT * FROM public.todos x WHERE x.reminder_enabled AND notification_private.todo_actionable(x)
   AND coalesce(x.assigned_to_user_id,x.owner_user_id)=auth.uid()
   AND notification_private.todo_followup_allowed(x,auth.uid(),instant) FOR UPDATE LOOP
   SELECT max(read_at) INTO acknowledged FROM public.notifications WHERE recipient_user_id=auth.uid() AND entity_type='todo' AND entity_id=t.id::text;
   IF acknowledged IS NULL THEN CONTINUE; END IF;
   t.next_reminder_at:=acknowledged;
   due:=notification_private.todo_next(t,CASE WHEN t.reminder_type='custom' THEN greatest(acknowledged,instant) ELSE acknowledged END);
   IF due IS NOT NULL THEN due:=notification_private.reminder_window(greatest(due,instant)); END IF;
   UPDATE public.todos SET next_reminder_at=due,reminder_enabled=(due IS NOT NULL) WHERE id=t.id;
  END LOOP;
  PERFORM set_config('mghrm.scheduler_write','off',true);
 END IF;
 RETURN saved;
END $$;
REVOKE ALL ON FUNCTION public.notification_simple_settings_save(bigint,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.notification_simple_settings_save(bigint,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
