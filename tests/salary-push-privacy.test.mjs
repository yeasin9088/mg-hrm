import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { PGlite } from '@electric-sql/pglite';

test('salary To-Do notes stay off device previews while ordinary notes and opt-out work', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
      CREATE SCHEMA notification_private;
      CREATE TABLE public.notification_jobs(id bigint PRIMARY KEY, notification_id bigint,
        job_type text, job_status text, locked_by text);
      CREATE TABLE public.notifications(id bigint PRIMARY KEY, recipient_user_id uuid,
        entity_type text, entity_id text, category text);
      CREATE TABLE public.notification_preferences(user_id uuid, category text,
        show_content_preview boolean);
      CREATE TABLE public.todos(id bigint PRIMARY KEY, owner_user_id uuid,
        assigned_to_user_id uuid, deleted_at timestamptz, category text,
        note_bn text, note text);
      CREATE FUNCTION notification_private.todo_actionable(public.todos)
        RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
      INSERT INTO public.notifications VALUES
        (1,'11111111-1111-4111-8111-111111111111','todo','42','ToDo');
      INSERT INTO public.notification_jobs VALUES
        (2,1,'DeliverWebPush','Processing','test-worker');
      INSERT INTO public.todos VALUES
        (42,'11111111-1111-4111-8111-111111111111',NULL,NULL,
         'salary','Private payroll figure',NULL);
    `);
    await db.exec(readFileSync(new URL('../supabase/migrations/20261023031049_salary_todo_push_privacy.sql', import.meta.url), 'utf8'));
    const preview = async () => (await db.query(
      "SELECT public.notification_web_push_preview(2,'test-worker') AS result"
    )).rows[0].result;
    assert.deepEqual(await preview(), { enabled: true });
    await db.exec("UPDATE public.todos SET category='task'");
    assert.equal((await preview()).todo_note, 'Private payroll figure');
    await db.exec("INSERT INTO public.notification_preferences VALUES ('11111111-1111-4111-8111-111111111111','*',false)");
    assert.deepEqual(await preview(), { enabled: false });
  } finally {
    await db.close();
  }
});
