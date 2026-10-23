-- Additive, user-owned preference; default allows useful To-Do previews.
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS show_content_preview boolean NOT NULL DEFAULT true;

-- Only the locked sender can resolve a notification to its recipient's current task.
-- The global opt-out always wins, even if a category override exists.
CREATE OR REPLACE FUNCTION public.notification_web_push_preview(p_job_id bigint, p_worker_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  n public.notifications%ROWTYPE;
  enabled boolean;
  task public.todos%ROWTYPE;
BEGIN
  IF p_job_id IS NULL OR nullif(btrim(coalesce(p_worker_id,'')),'') IS NULL THEN
    RAISE EXCEPTION 'Job and worker are required' USING ERRCODE='22023';
  END IF;
  SELECT notification_row.* INTO n
  FROM public.notification_jobs j JOIN public.notifications notification_row ON notification_row.id=j.notification_id
  WHERE j.id=p_job_id AND j.job_type='DeliverWebPush' AND j.job_status='Processing'
    AND j.locked_by=btrim(p_worker_id);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Web Push job is not owned by worker' USING ERRCODE='42501';
  END IF;
  SELECT NOT EXISTS(
    SELECT 1 FROM public.notification_preferences p
    WHERE p.user_id=n.recipient_user_id AND p.category IN ('*',n.category)
      AND p.show_content_preview=false
  ) INTO enabled;
  IF NOT enabled THEN RETURN jsonb_build_object('enabled',false); END IF;
  IF n.entity_type='todo' AND n.category='ToDo' AND n.entity_id ~ '^[0-9]{1,18}$' THEN
    SELECT * INTO task FROM public.todos t
    WHERE t.id=n.entity_id::bigint AND t.deleted_at IS NULL
      AND coalesce(t.assigned_to_user_id,t.owner_user_id)=n.recipient_user_id
      AND notification_private.todo_actionable(t);
    IF FOUND THEN
      RETURN jsonb_build_object('enabled',true,'todo_id',task.id,
        'todo_note',coalesce(nullif(btrim(task.note_bn),''),nullif(btrim(task.note),'')));
    END IF;
  END IF;
  RETURN jsonb_build_object('enabled',true);
END $$;
REVOKE ALL ON FUNCTION public.notification_web_push_preview(bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_web_push_preview(bigint,text) TO service_role;
