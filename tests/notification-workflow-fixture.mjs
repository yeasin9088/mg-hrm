import fs from 'node:fs';
import {setup as integrity} from './notification-integrity-fixture.mjs';
export const workflowMigration='supabase/migrations/20261023130557_notification_workflow_completion.sql';
export const operator='11111111-1111-4111-8111-111111111111';
export async function setup(db){
 await integrity(db);
 await db.exec(`CREATE TABLE auth.users(id uuid PRIMARY KEY); INSERT INTO auth.users VALUES('${operator}');
 DROP TABLE public.swa_work_items;
 CREATE OR REPLACE FUNCTION notification_private.todo_actionable(t public.todos) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT t.deleted_at IS NULL AND t.solved_at IS NULL
 AND lower(btrim(coalesce(t.status,''))) NOT IN ('done','complete','completed','closed','resolved','cancelled','canceled','solved','solved_approved','solved_rejected')
 AND lower(btrim(coalesce(t.manager_status,''))) NOT IN ('done','complete','completed','closed','resolved','cancelled','canceled','solved','solved_approved','solved_rejected') $$;
 ALTER TABLE public.todos ADD COLUMN note_bn text,ADD COLUMN who text,ADD COLUMN project text,ADD COLUMN date date,ADD COLUMN next_reminder_at timestamptz;
 CREATE SEQUENCE test_todo_ids START 10000; ALTER TABLE public.todos ALTER COLUMN id SET DEFAULT nextval('test_todo_ids');`);
 for(const f of ['supabase/migrations/20261022172217_swa_v2_operator_work_ledger.sql','supabase/migrations/20261022173115_swa_rejected_approval_followthrough.sql',workflowMigration,'supabase/migrations/20261023130913_notification_source_truth_alignment.sql','supabase/migrations/20261023142411_notification_acceptance_gaps.sql'])await db.exec(fs.readFileSync(f,'utf8'));
 await db.exec(`SELECT set_config('request.jwt.claim.sub','${operator}',false);`);
}
