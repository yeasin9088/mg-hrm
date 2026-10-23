import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import {PGlite} from '@electric-sql/pglite';

test('final Web Push dispatch checks authoritative source state and current recipient', async () => {
 const db=new PGlite();
 const alice='11111111-1111-4111-8111-111111111111';
 const bob='22222222-2222-4222-8222-222222222222';
 const nid='33333333-3333-4333-8333-333333333333';
 try {
  await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
  CREATE SCHEMA notification_private;
  CREATE TABLE public.todos(
    id bigint PRIMARY KEY,owner_user_id uuid,assigned_to_user_id uuid,
    status text,solved_at timestamptz,deleted_at timestamptz
  );
  CREATE FUNCTION notification_private.todo_actionable(t public.todos)
  RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS
  $$ SELECT t.deleted_at IS NULL AND t.solved_at IS NULL AND t.status='open' $$;
  CREATE FUNCTION public.notification_source_state(p_type text,p_id text)
  RETURNS jsonb LANGUAGE sql STABLE AS $$
    SELECT jsonb_build_object('supported',true,
      'resolved',p_id='8','state',CASE WHEN p_id='9' THEN 'Source workflow record not found' ELSE 'Open' END)
  $$;
  CREATE FUNCTION public.notification_effective_preference(uuid,text)
  RETURNS jsonb LANGUAGE sql STABLE AS $$
    SELECT '{"notification_enabled":true,"system_push_enabled":true,"in_app_enabled":false}'::jsonb
  $$;
  CREATE FUNCTION public.notification_reminder_mode() RETURNS boolean
  LANGUAGE sql STABLE AS $$ SELECT false $$;
  CREATE FUNCTION notification_private.has_foreground(uuid) RETURNS boolean
  LANGUAGE sql STABLE AS $$ SELECT false $$;
  CREATE TABLE public.notifications(
    id uuid PRIMARY KEY,recipient_user_id uuid,entity_type text,entity_id text,
    status text,scheduled_for timestamptz,expires_at timestamptz,category text,
    priority text,severity text,title text,message text,action_label text,
    action_route text,action_params jsonb
  );
  CREATE TABLE public.notification_jobs(
    id bigint PRIMARY KEY,notification_id uuid,job_type text,job_status text,
    locked_by text,attempt_count integer DEFAULT 1,maximum_attempts integer DEFAULT 4,
    run_at timestamptz,locked_at timestamptz
  );
  CREATE TABLE public.push_subscriptions(
    id bigint PRIMARY KEY,user_id uuid,is_active boolean,
    permission_state text,revoked_at timestamptz,
    endpoint text,p256dh_key text,auth_key text
  );
  CREATE TABLE public.notification_deliveries(
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_id uuid,subscription_id bigint,channel text,
    delivery_status text,provider_status text,response_metadata jsonb DEFAULT '{}'::jsonb,
    attempt_number integer DEFAULT 0
  );
  INSERT INTO public.todos VALUES(101,'${alice}',null,'open',null,null);
  INSERT INTO public.notifications(id,recipient_user_id,entity_type,entity_id,status,category,priority)
    VALUES('${nid}','${alice}','todo','101','Ready','ToDo','Normal');
  INSERT INTO public.notification_jobs VALUES(51,'${nid}','DeliverWebPush','Processing','worker',1,4);
  INSERT INTO public.push_subscriptions VALUES(88,'${alice}',true,'granted',null,'https://example.org/push','key1','key2');
  INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,delivery_status)
    VALUES('${nid}',88,'WebPush','Pending');
  `);
  const sql=readFileSync(new URL('../supabase/migrations/20261023160000_push_final_source_guard.sql',import.meta.url),'utf8');
  await db.exec(sql);
  const source=async(type,id,recipient=alice) =>
    (await db.query('SELECT notification_private.push_source_ineligible($1,$2,$3) AS blocked',[type,id,recipient])).rows[0].blocked;
  assert.equal(await source('todo','101'),false,'valid owner can receive');
  assert.equal(await source('todo','101',bob),true,'wrong recipient blocked');
  assert.equal(await source('todo','nonsense'),true,'invalid ID blocked');
  assert.equal(await source('transfer','7'),false,'verified active source allowed');
  assert.equal(await source('transfer','8'),true,'resolved transfer blocked');
  assert.equal(await source('leave','9'),true,'missing known source blocked');
  assert.equal(await source('disciplinary','7'),false,'unmapped type unchanged pending verified adapter');
  const dispatch=async()=> (await db.query(
    "SELECT public.notification_get_web_push_dispatch(51,'worker') AS result")).rows[0].result;
  assert.equal((await dispatch()).deliveries.length,1,'valid source dispatches');
  await db.exec(`UPDATE public.todos SET assigned_to_user_id='${bob}' WHERE id=101`);
  assert.equal((await dispatch()).deliveries.length,0,'reassigned task cannot Push old user');
  const skipped=(await db.query('SELECT delivery_status,response_metadata FROM public.notification_deliveries')).rows[0];
  assert.equal(skipped.delivery_status,'Skipped');
  assert.equal(skipped.response_metadata.gate_reason,'source_ineligible_or_recipient_changed');
  await db.exec(`UPDATE public.todos SET assigned_to_user_id=null,solved_at=now() WHERE id=101`);
  assert.equal(await source('todo','101'),true,'resolved todo must block');
  const grants=(await db.query(`SELECT
    has_function_privilege('anon','notification_private.push_source_ineligible(text,text,uuid)','EXECUTE') AS anon,
    has_function_privilege('authenticated','notification_private.push_source_ineligible(text,text,uuid)','EXECUTE') AS authenticated`)).rows[0];
  assert.equal(grants.anon,false);
  assert.equal(grants.authenticated,false);
 } finally { await db.close(); }
});
