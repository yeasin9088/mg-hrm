-- Additive V2-compatible repeat gate, disabled by default.
-- Does not mutate existing notifications or authorize production V2 activation.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';

CREATE OR REPLACE FUNCTION notification_private.prevent_unseen_repeat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public
AS $mg$
DECLARE
 root_n public.notifications%rowtype;
 source_state jsonb;
 last_ack timestamptz;
 repeat_minutes integer;
 todo_row public.todos%rowtype;
 v_governance_enabled boolean;
BEGIN
 IF NEW.parent_notification_id IS NULL OR NEW.repeat_count <= 0
    OR NEW.escalation_level <> 0 THEN RETURN NEW; END IF;
 SELECT * INTO root_n FROM public.notifications WHERE id=NEW.parent_notification_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- Only the To-Do reminder thread participates in V2; the disabled switch
 -- preserves the exact legacy read-aware rule below for every other case.
 SELECT enabled INTO v_governance_enabled
 FROM notification_private.governance_control WHERE singleton;
 IF coalesce(v_governance_enabled,false)
    AND root_n.entity_type='todo' AND root_n.entity_id ~ '^[0-9]{1,18}$'
    AND EXISTS(SELECT 1 FROM public.notification_events e
      WHERE e.id=root_n.event_id AND e.event_type='TodoReminderDue') THEN
   SELECT * INTO todo_row FROM public.todos WHERE id=root_n.entity_id::bigint;
   IF NOT FOUND OR root_n.status NOT IN
       ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
      OR root_n.recipient_user_id IS DISTINCT FROM NEW.recipient_user_id
      OR coalesce(todo_row.assigned_to_user_id,todo_row.owner_user_id)
         IS DISTINCT FROM NEW.recipient_user_id THEN RETURN NULL; END IF;
   IF coalesce((notification_private.governance_evaluate_todo(
        todo_row,NEW.recipient_user_id,clock_timestamp())->>'emit')::boolean,false)
   THEN RETURN NEW; END IF;
   RETURN NULL;
 END IF;
 IF root_n.recipient_user_id IS DISTINCT FROM NEW.recipient_user_id
    OR root_n.status NOT IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
    OR root_n.read_at IS NULL OR root_n.status='Snoozed'
 THEN RETURN NULL; END IF;
 source_state:=public.notification_source_state(root_n.entity_type,root_n.entity_id);
 IF NOT coalesce((source_state->>'supported')::boolean,false)
    OR coalesce((source_state->>'resolved')::boolean,false)
    OR source_state->>'state'='Source workflow record not found'
 THEN RETURN NULL; END IF;
 IF EXISTS (
   SELECT 1 FROM public.notifications n
   WHERE n.recipient_user_id=root_n.recipient_user_id
     AND (n.id=root_n.id OR n.parent_notification_id=root_n.id)
     AND n.escalation_level=0
     AND n.status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed')
     AND (n.read_at IS NULL OR n.status='Snoozed')
 ) THEN RETURN NULL; END IF;
 SELECT r.repeat_every_minutes INTO repeat_minutes
 FROM public.notification_escalation_rules r
 WHERE r.id=NEW.escalation_rule_id AND r.is_enabled AND r.repeat_every_minutes>0;
 IF repeat_minutes IS NULL THEN RETURN NULL; END IF;
 SELECT max(n.read_at) INTO last_ack FROM public.notifications n
 WHERE n.recipient_user_id=root_n.recipient_user_id
   AND (n.id=root_n.id OR n.parent_notification_id=root_n.id)
   AND n.escalation_level=0;
 IF last_ack IS NULL OR clock_timestamp()<last_ack+make_interval(mins=>repeat_minutes)
 THEN RETURN NULL; END IF;
 RETURN NEW;
END $mg$;
REVOKE ALL ON FUNCTION notification_private.prevent_unseen_repeat()
 FROM PUBLIC,anon,authenticated;
COMMIT;
