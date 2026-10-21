// Synthetic isolated PostgreSQL WASM only. This is NOT a production backup/restore test.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url);
const read=p=>fs.readFile(new URL(p,root),'utf8');
const engine=new PGlite();
const db={async exec(sql,params){
 try {
 if(params) return engine.query(sql,params);
 const results=await engine.exec(sql);return results.at(-1)||{rows:[]};
 } catch(e) { const error=new Error(e.message);error.code=e.code;throw error; }
}};
let passed=0;
const check=async(name,fn)=>{await fn();passed++;console.log('PASS '+name);};
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
 CREATE TABLE auth.sessions(id uuid primary key,user_id uuid references auth.users(id),not_after timestamptz);
 CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(auth.jwt()->>'sub','')::uuid $$;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon,service_role;`);
 // Reconstruct only the notification dependencies from the checked-in catalog reference.
 const tables=['profiles','todos','notifications','notification_events','notification_jobs','notification_deliveries','notification_preferences','push_subscriptions','notification_escalation_rules','notification_legacy_states'];
 for(const table of tables) await db.exec(await read(`supabase/schema-baseline/tables/${table}.sql`));
 for(const file of ['04-constraints.sql','06-indexes.sql']) {
   const text=(await read('supabase/schema-baseline/'+file)).replace(/^--.*$/gm,'');
   for(const statement of text.split(';')) {
     if(tables.some(t=>statement.includes(`"public"."${t}"`)||new RegExp(`ON public\\.${t}\\b`).test(statement))) await db.exec(statement+';');
   }
 }
 // PL/pgSQL workflow branches outside notifications are intentionally not exercised.
 for(const file of ['triggers-and-helpers.sql','notifications-service.sql','notifications-user.sql']) {
   const text=await read('supabase/schema-baseline/functions/'+file);
   const fns=text.match(/CREATE OR REPLACE FUNCTION[\s\S]*?\$function\$;/g)||[];
   for(const fn of fns) if(/FUNCTION public\.(notification_|my_role\(|push_subscription_)/.test(fn)) await db.exec(fn);
 }
 const triggers=await read('supabase/schema-baseline/07-triggers.sql');
 for(const statement of triggers.split(';')) if(/EXECUTE FUNCTION notification_/.test(statement)&&tables.some(t=>new RegExp(`ON (public\\.)?${t}\\b`).test(statement))) await db.exec(statement+';');
 const grants=(await read('supabase/schema-baseline/09-privileges.sql')).replace(/^--.*$/gm,'');
 for(const statement of grants.split(';')) if(/^(?:\s*)(?:GRANT|REVOKE)[\s\S]*ON FUNCTION public\.(?:notification_|push_subscription_)/.test(statement)) await db.exec(statement+';');
 const migration=await read('supabase/migrations/20261021152333_reliable_reminder_scheduler.sql');
 await db.exec(migration);await db.exec(migration); // Replay must preserve configuration and rows.
 const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',sid='33333333-3333-4333-8333-333333333333';
 await db.exec('INSERT INTO auth.users(id) VALUES($1),($2)',[a,b]);
 await db.exec("INSERT INTO public.profiles(id,role) VALUES($1,'admin'),($2,'admin')",[a,b]);
 await db.exec('INSERT INTO auth.sessions(id,user_id) VALUES($1,$2)',[sid,a]);
 await db.exec("INSERT INTO notification_preferences(user_id,category,quiet_hours_enabled) VALUES($1,'*',false),($2,'*',false)",[a,b]);
 const todo=async(id,type='30m')=>db.exec("INSERT INTO todos(id,note,status,reminder_enabled,reminder_type,reminder_interval,next_reminder_at,owner_user_id,assigned_to_user_id) VALUES($1,'SYNTHETIC','pending',true,$2,30,now()-interval '2 hours',$3,$3)",[id,type,a]);
 const tick=()=>db.exec('select notification_schedule_todos()');
 const count=async(table,where)=>Number((await db.exec(`select count(*) n from ${table} where ${where}`)).rows[0].n);
 await check('migration idempotency and default-off cutover',async()=>{assert.equal((await db.exec('select notification_reminder_mode() mode')).rows[0].mode,false);});
 await db.exec('select notification_set_server_reminders(true)');
 await check('closed-app recurring schedule coalesces outage into one event',async()=>{
   await todo(1);await tick();assert.equal(await count('notification_events',"entity_id='1'"),1);
   assert.equal((await db.exec("select next_reminder_at>now() and next_reminder_at<=now()+interval '30 minutes' ok from todos where id=1")).rows[0].ok,true);
   await tick();assert.equal(await count('notification_events',"entity_id='1'"),1);
 });
 await check('one-time reminder completes its schedule once',async()=>{
   await todo(2,'once');await tick();await tick();assert.equal(await count('notification_events',"entity_id='2'"),1);
   assert.equal((await db.exec('select reminder_enabled from todos where id=2')).rows[0].reminder_enabled,false);
 });
 await check('consumed one-shot cannot be resurrected by a stale cache update',async()=>{
   await db.exec('update todos set reminder_enabled=true where id=2');await tick();
   assert.equal(await count('notification_events',"entity_id='2'"),1);
   assert.equal((await db.exec('select reminder_enabled from todos where id=2')).rows[0].reminder_enabled,false);
 });
 await check('queued scheduler invocations produce one occurrence (WASM serializes sessions)',async()=>{
   await todo(3);
   await Promise.all([1,2,3].map(()=>db.exec('select notification_schedule_todos()')));
   assert.equal(await count('notification_events',"entity_id='3'"),1);
 });
 await check('legacy browser claims fenced after cutover',async()=>{
   assert.equal((await db.exec('select notification_claim_todo_reminder(3,null,null) r')).rows[0].r.claimed,false);
 });
 await check('future reschedule and solved/cancelled/deleted/manager-resolved stop scheduling',async()=>{
   for(const [id,patch] of [[4,"status='solved'"],[5,"status='cancelled'"],[6,"deleted_at=now()"],[7,"manager_status='solved_approved'"],[8,"next_reminder_at=now()+interval '3 hours'"]]) {
     await todo(id);await db.exec(`update todos set ${patch} where id=$1`,[id]);
   }await tick();for(const id of [4,5,6,7,8]) assert.equal(await count('notification_events',`entity_id='${id}'`),0);
 });
 await check('custom dates use explicit timezone and interval',async()=>{
   await todo(9,'custom');await db.exec("update todos set reminder_dates=jsonb_build_array(jsonb_build_object('date',(now() at time zone 'Asia/Dhaka')::date::text,'interval',30)),next_reminder_at=null where id=9");
   await tick();assert.equal((await db.exec("select next_reminder_at>now() or reminder_enabled=false ok from todos where id=9")).rows[0].ok,true);
 });
 await check('existing event processor and delivery queue fan out once per active device',async()=>{
   for(const [i,uid,active,permission] of [[1,a,true,'granted'],[2,a,true,'granted'],[3,b,true,'granted'],[4,a,false,'granted'],[5,a,true,'denied']])
     await db.exec("insert into push_subscriptions(id,user_id,endpoint,endpoint_hash,p256dh_key,auth_key,is_active,permission_state) values($1,$2,$3,$4,'synthetic','synthetic',$5,$6)",[i,uid,'https://synthetic.invalid/'+i,'synthetic-'+i,active,permission]);
   await db.exec("select notification_run_server_processor('synthetic',100)");
   assert.equal(await count('notifications',"entity_type='todo' and entity_id='1'"),1);
   assert.equal(await count('notification_deliveries',"channel='WebPush' and notification_id in(select id from notifications where entity_id='1')"),2);
   assert.equal(await count('notification_jobs',"job_type='DeliverWebPush' and notification_id in(select id from notifications where entity_id='1')"),1);
 });
 const auth=async(uid=a,session=sid)=>{await db.exec('set role authenticated');await db.exec("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,session_id:session})]);};
 const reset=()=>db.exec('reset role');
 const beat=async(visible=true,focused=true)=>{await auth();await db.exec('select notification_presence_heartbeat($1,$2,$3,$4,true)',[crypto.randomUUID(),crypto.randomUUID(),visible,focused]);await reset();};
 await check('foreground presence is user-isolated; private tables inaccessible',async()=>{
   await beat();assert.equal((await db.exec('select notification_private.has_foreground($1) ok',[a])).rows[0].ok,true);
   assert.equal((await db.exec('select notification_private.has_foreground($1) ok',[b])).rows[0].ok,false);
   await auth();await assert.rejects(db.exec('select * from notification_private.foreground_sessions'),{code:'42501'});await reset();
 });
 await check('background and stale sessions conservatively allow push',async()=>{
   await db.exec('truncate notification_private.foreground_sessions');await beat(false,false);
   assert.equal((await db.exec('select notification_private.has_foreground($1) ok',[a])).rows[0].ok,false);
   await beat();await db.exec("update notification_private.foreground_sessions set last_seen_at=now()-interval '2 minutes'");
   assert.equal((await db.exec('select notification_private.has_foreground($1) ok',[a])).rows[0].ok,false);
 });
 await check('forged auth session cannot suppress another account; service RPC denied',async()=>{
   await auth(b,sid);await assert.rejects(db.exec('select notification_presence_heartbeat($1,$2,true,true,true)',[crypto.randomUUID(),crypto.randomUUID()]),{code:'42501'});await reset();
   assert.equal((await db.exec('select notification_private.has_foreground($1) ok',[b])).rows[0].ok,false);
   await auth();await assert.rejects(db.exec('select notification_set_server_reminders(false)'),{code:'42501'});await reset();
 });
 await check('real SQL dispatch suppresses foreground fanout and preserves inbox',async()=>{
   await db.exec('truncate notification_private.foreground_sessions');await beat();
   const jobs=(await db.exec("select * from notification_claim_web_push_jobs('synthetic-dispatch',25)")).rows;
   const notification=(await db.exec("select id from notifications where entity_id='1'")).rows[0].id;
   const job=jobs.find(j=>j.notification_id===notification);assert(job);
   const dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'synthetic-dispatch') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deliveries.length,0);
   assert.equal(await count('notification_deliveries',`notification_id='${notification}' and channel='InApp' and delivery_status='Delivered'`),1);
   await db.exec("select notification_finalize_web_push_job($1,'synthetic-dispatch')",[job.id]);
 });
 await check('real SQL background fanout, revoked subscription exclusion and provider acceptance',async()=>{
   await db.exec('truncate notification_private.foreground_sessions');await beat(false,false);
   const job=(await db.exec("select j.* from notification_jobs j join notifications n on n.id=j.notification_id where j.job_type='DeliverWebPush' and n.entity_id='2'")).rows[0];
   let dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'synthetic-dispatch') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deliveries.length,2);
   await db.exec('update push_subscriptions set is_active=false where id=1');
   dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'synthetic-dispatch') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deliveries.length,1);
   await db.exec("select notification_record_web_push_result($1,'synthetic-dispatch',$2,true,'201')",[job.id,dispatch.deliveries[0].delivery_id]);
   assert.equal(await count('notification_deliveries',`notification_id='${job.notification_id}' and delivery_status='Sent' and delivered_at is null`),1);
   await db.exec("select notification_finalize_web_push_job($1,'synthetic-dispatch')",[job.id]);
 });
 await check('snooze keeps history, schedules a new attempt and defers a claimed job',async()=>{
   const notification=(await db.exec("select id from notifications where entity_id='1'")).rows[0].id;
   await auth();await db.exec("select notification_snooze($1,now()+interval '1 hour')",[notification]);await reset();
   assert.equal(await count('notification_deliveries',`notification_id='${notification}' and delivery_status='Skipped'`),2);
   assert.equal(await count('notification_deliveries',`notification_id='${notification}' and delivery_status='Pending'`),1);
   // Model the worker/snooze race explicitly: job was claimed before snooze committed.
   const job=(await db.exec("update notification_jobs set job_status='Processing',locked_by='snooze-race',attempt_count=1 where notification_id=$1 and job_type='DeliverWebPush' and job_status='Pending' returning id",[notification])).rows[0];
   const dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'snooze-race') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deferred,true);
   assert.equal((await db.exec('select job_status from notification_jobs where id=$1',[job.id])).rows[0].job_status,'Pending');
 });
 await check('solving a queued source cancels outstanding delivery work immediately',async()=>{
   await db.exec("update todos set solved_at=now(),status='solved' where id=3");
   assert.equal(await count('notification_jobs',"job_type='DeliverWebPush' and job_status in ('Pending','Processing','Failed') and notification_id in(select id from notifications where entity_id='3')"),0);
   assert.equal(await count('notification_deliveries',"channel='WebPush' and delivery_status in ('Pending','Failed') and notification_id in(select id from notifications where entity_id='3')"),0);
 });
 await check('quiet hours defer explicit ToDo reminders and coalesce intervening cycles',async()=>{
   await db.exec("update notification_preferences set timezone='UTC',quiet_hours_enabled=true,quiet_hours_start=((now() at time zone 'UTC')-interval '1 hour')::time,quiet_hours_end=((now() at time zone 'UTC')+interval '1 hour')::time where user_id=$1",[a]);
   await todo(10);await tick();await db.exec("select notification_run_server_processor('quiet-test',100)");
   assert.equal((await db.exec("select scheduled_for>now() ok from notifications where entity_id='10'")).rows[0].ok,true);
   await db.exec("select set_config('mghrm.scheduler_write','on',false);update todos set next_reminder_at=now()-interval '1 minute' where id=10;select set_config('mghrm.scheduler_write','off',false)");
   await tick();assert.equal(await count('notification_events',"entity_id='10'"),1);
 });
 await check('real delivery retry revokes expired device and sends only remaining eligible attempt',async()=>{
   await db.exec("update notification_preferences set quiet_hours_enabled=false where user_id=$1",[a]);
   await db.exec('update push_subscriptions set is_active=true,revoked_at=null where id=1');
   await todo(11);await tick();await db.exec("select notification_run_server_processor('retry-fixture',100)");
   const jobs=(await db.exec("select * from notification_claim_web_push_jobs('retry-worker',25)")).rows;
   const nid=(await db.exec("select id from notifications where entity_id='11'")).rows[0].id;
   const job=jobs.find(j=>j.notification_id===nid);assert(job);
   let dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'retry-worker') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deliveries.length,2);
   await db.exec("select notification_record_web_push_result($1,'retry-worker',$2,false,'410',null,'HTTP_410','Synthetic expired endpoint','{}',true)",[job.id,dispatch.deliveries[0].delivery_id]);
   await db.exec("select notification_record_web_push_result($1,'retry-worker',$2,false,'503',null,'HTTP_503','Synthetic retry')",[job.id,dispatch.deliveries[1].delivery_id]);
   await db.exec("select notification_finalize_web_push_job($1,'retry-worker','2 minutes')",[job.id]);
   assert.equal((await db.exec('select job_status,run_at>now() later from notification_jobs where id=$1',[job.id])).rows[0].later,true);
   await db.exec('update notification_jobs set run_at=now() where id=$1',[job.id]);
   await db.exec("select * from notification_claim_web_push_jobs('retry-worker-2',25)");
   dispatch=(await db.exec("select notification_get_web_push_dispatch($1,'retry-worker-2') r",[job.id])).rows[0].r;
   assert.equal(dispatch.deliveries.length,1);
   await db.exec("select notification_record_web_push_result($1,'retry-worker-2',$2,true,'201')",[job.id,dispatch.deliveries[0].delivery_id]);
   await db.exec("select notification_finalize_web_push_job($1,'retry-worker-2')",[job.id]);
   assert.equal((await db.exec('select job_status from notification_jobs where id=$1',[job.id])).rows[0].job_status,'Completed');
 });
 await check('migration replay preserves enabled cutover and historical rows; failure rolls back atomically',async()=>{
   const before=await count('notification_events','true');await db.exec(migration);
   assert.equal((await db.exec('select notification_reminder_mode() mode')).rows[0].mode,true);
   assert.equal(await count('notification_events','true'),before);
   const broken=migration.replace('COMMIT;',"UPDATE notification_private.reminder_control SET server_authoritative=false; SELECT 1/0; COMMIT;");
   await assert.rejects(db.exec(broken),{code:'22012'});await db.exec('ROLLBACK');
   assert.equal((await db.exec('select notification_reminder_mode() mode')).rows[0].mode,true);
   assert.equal(await count('notification_events','true'),before);
 });
 await check('two-phase rollout configures one paused sender; health is non-sending and backlog blocks activation',async()=>{
   // Interface stubs only: this is NOT hosted pg_cron/pg_net/Vault validation.
   await db.exec(`CREATE SCHEMA cron;CREATE SCHEMA vault;CREATE SCHEMA net;
     CREATE TABLE cron.job(jobid bigint PRIMARY KEY,jobname text,schedule text,command text,active boolean);
     INSERT INTO cron.job VALUES(2,'notification-web-push-sender','* * * * *','synthetic previous command',true);
     CREATE FUNCTION cron.alter_job(job_id bigint,schedule text DEFAULT NULL,command text DEFAULT NULL,database text DEFAULT NULL,username text DEFAULT NULL,active boolean DEFAULT NULL)
     RETURNS void LANGUAGE sql AS $$ UPDATE cron.job j SET schedule=coalesce($2,j.schedule),command=coalesce($3,j.command),active=coalesce($6,j.active) WHERE j.jobid=$1 $$;
     CREATE TABLE vault.secrets(name text,decrypted_secret text);
     CREATE VIEW vault.decrypted_secrets AS SELECT * FROM vault.secrets;
     CREATE TABLE net.recorded_http_calls(id bigint GENERATED ALWAYS AS IDENTITY,url text,headers jsonb,body jsonb);
     CREATE FUNCTION net.http_post(url text,body jsonb DEFAULT '{}',params jsonb DEFAULT '{}',headers jsonb DEFAULT '{}',timeout_milliseconds int DEFAULT 2000)
     RETURNS bigint LANGUAGE sql AS $$ INSERT INTO net.recorded_http_calls(url,headers,body) VALUES($1,$4,$2) RETURNING id $$;`);
   await db.exec('select notification_set_server_reminders(false)');
   await db.exec(await read('supabase/rollout/reminder-cron.sql'));
   assert.equal(await count('cron.job',"jobname='notification-web-push-sender'"),1);
   assert.equal((await db.exec('select active from cron.job where jobid=2')).rows[0].active,false);
   await assert.rejects(db.exec('select notification_private.invoke_web_push_sender(true)'),{code:'P0001'});
   assert.equal(await count('net.recorded_http_calls','true'),0);
   await db.exec("insert into vault.secrets values('mg_notification_sender_token','synthetic-token-32-bytes-not-a-secret')");
   await db.exec('select notification_private.invoke_web_push_sender(true)');
   const request=(await db.exec('select * from net.recorded_http_calls')).rows[0];
   assert.equal(request.url,'https://enkggoozsvvkgbjeghbf.supabase.co/functions/v1/web-push-sender?health=1');
   assert.equal(request.headers['x-web-push-sender-token'],'synthetic-token-32-bytes-not-a-secret');
   const activate=await read('supabase/rollout/reminder-activate.sql');
   await assert.rejects(db.exec(activate),{code:'P0001'});await db.exec('rollback');
   assert.equal((await db.exec('select notification_reminder_mode() enabled')).rows[0].enabled,false);
   assert.equal((await db.exec('select active from cron.job where jobid=2')).rows[0].active,false);
   // Resolve ONLY in-memory synthetic fixtures for the successful activation branch.
   await db.exec("update notification_jobs set job_status='Cancelled',locked_by=null,locked_at=null where job_status in ('Pending','Failed','Processing');update notification_deliveries set delivery_status='Cancelled' where delivery_status in ('Pending','Failed','Processing');update notifications set status='Cancelled' where status in ('Ready','Scheduled','Snoozed','Failed');update notification_events set processing_status='Ignored' where processing_status in ('Pending','Failed')");
   const notes=await count('todos','true'),events=await count('notification_events','true');
   await db.exec(activate);
   assert.equal((await db.exec('select notification_reminder_mode() enabled')).rows[0].enabled,true);
   assert.equal((await db.exec('select active from cron.job where jobid=2')).rows[0].active,true);
   assert.equal(await count('todos','true'),notes);assert.equal(await count('notification_events','true'),events);
   assert.equal(await count('net.recorded_http_calls','true'),1);
 });
 await check('reviewed stale-push disposition rejects changed scope and preserves inbox/history',async()=>{
   await db.exec('select notification_set_server_reminders(false);update cron.job set active=false where jobid=2');
   const create=async(from,to)=>{
     await db.exec(`insert into notifications(recipient_user_id,category,title,message,entity_type,entity_id,status,scheduled_for,dedupe_key)
       select $1,'ToDo','SYNTHETIC','SYNTHETIC','todo','rollout-fixture:'||i,'Read',now(),'rollout-fixture:'||i from generate_series($2::int,$3::int)i`,[a,from,to]);
     await db.exec(`insert into notification_jobs(notification_id,job_type,run_at,created_at)
       select n.id,'DeliverWebPush',now(),'2000-01-01' from notifications n where n.dedupe_key like 'rollout-fixture:%'
       and not exists(select 1 from notification_jobs j where j.notification_id=n.id)`);
     await db.exec(`insert into notification_deliveries(notification_id,subscription_id,channel)
       select n.id,s.id,'WebPush' from notifications n cross join push_subscriptions s
       where n.dedupe_key like 'rollout-fixture:%' and s.id in (1,2) on conflict do nothing`);
   };
   const dispose=await read('supabase/rollout/reminder-backlog.sql');
   await create(1,27);
   await assert.rejects(db.exec(dispose),{code:'P0001'});await db.exec('rollback');
   assert.equal(await count('notification_jobs',"last_error like 'STALE_PRE_CUTOVER:%'"),0);
   await create(28,28);
   const inbox=await count('notifications','true'),events=await count('notification_events','true'),notes=await count('todos','true');
   await db.exec(dispose);
   assert.equal(await count('notification_jobs',"last_error like 'STALE_PRE_CUTOVER:%' and job_status='Cancelled'"),28);
   assert.equal(await count('notification_deliveries',"error_code='STALE_PRE_CUTOVER' and delivery_status='Cancelled'"),56);
   assert.equal(await count('notifications','true'),inbox);assert.equal(await count('notification_events','true'),events);assert.equal(await count('todos','true'),notes);
   assert.equal(await count('notifications',"dedupe_key like 'rollout-fixture:%' and status='Read'"),28);
 });
 console.log(`PASS ${passed} isolated PostgreSQL acceptance groups (synthetic data only)`);
} finally {
 await engine.close();
}
