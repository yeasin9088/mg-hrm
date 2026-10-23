import fs from 'node:fs';
import {setup as integrity} from './notification-integrity-fixture.mjs';
export const workflowMigration='supabase/migrations/20261023122146_notification_workflow_completion.sql';
export const operator='11111111-1111-4111-8111-111111111111';
export async function setup(db){
 await integrity(db);
 await db.exec(`CREATE TABLE auth.users(id uuid PRIMARY KEY); INSERT INTO auth.users VALUES('${operator}');
 DROP TABLE public.swa_work_items;
 ALTER TABLE public.todos ADD COLUMN note_bn text,ADD COLUMN who text,ADD COLUMN project text,ADD COLUMN date date,ADD COLUMN next_reminder_at timestamptz;
 CREATE SEQUENCE test_todo_ids START 10000; ALTER TABLE public.todos ALTER COLUMN id SET DEFAULT nextval('test_todo_ids');`);
 for(const f of ['supabase/migrations/20261022232000_swa_v2_foundation.sql','supabase/migrations/20261022235000_swa_rejected_approval_followthrough.sql',workflowMigration])await db.exec(fs.readFileSync(f,'utf8'));
 await db.exec(`SELECT set_config('request.jwt.claim.sub','${operator}',false);`);
}
