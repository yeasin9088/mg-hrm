import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const engine=new PGlite();
const read=p=>fs.readFile(p,'utf8');
const db={exec:async(sql,args)=>args?engine.query(sql,args):engine.exec(sql)};
const operator='11111111-1111-4111-8111-111111111111';
const q=async(sql,args=[]) => (await engine.query(sql,args)).rows;
const one=async(sql,args=[]) => (await q(sql,args))[0];
// Reuse the existing isolated baseline bootstrap; never connects to a live database.
before(async()=>{
 const source=await read('scripts/test-reminder-db.mjs');
 const start=source.indexOf(' await db.exec(`CREATE ROLE');
 const end=source.indexOf(" const a='11111111",start);
 assert(start>=0&&end>start);
 await new (Object.getPrototypeOf(async function(){}).constructor)('db','read',source.slice(start,end))(db,read);
 await engine.exec(`CREATE FUNCTION public.swa_is_operator() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT auth.uid()='${operator}'::uuid $$;
 INSERT INTO auth.users(id) VALUES('${operator}'); INSERT INTO public.profiles(id,role,is_active) VALUES('${operator}','admin',true);
 SELECT set_config('request.jwt.claims','{"sub":"${operator}"}',false);`);
 await engine.exec(await read('supabase/migrations/20261024111642_simple_read_aware_reminders.sql'));
 await engine.exec(await read('supabase/migrations/20261024113123_rebase_reminders_after_hours_change.sql'));
 await engine.exec(await read('supabase/migrations/20261024120948_repair_device_push_registration.sql'));
 await engine.exec(await read('supabase/migrations/20261024121149_isolate_manual_device_push_test.sql'));
});
after(()=>engine.close());
async function fixture(){
 await engine.exec('BEGIN');
 await engine.exec(`UPDATE notification_private.simple_reminder_policy SET office_start='00:00',office_end='00:00';
 UPDATE notification_private.reminder_control SET server_authoritative=true;
 INSERT INTO public.todos(id,status,note,category,owner_user_id,assigned_to_user_id,reminder_enabled,reminder_type,reminder_interval,next_reminder_at)
 VALUES(900,'pending','Synthetic task','task','${operator}','${operator}',true,'1h',60,clock_timestamp()-interval '1 minute');`);
}
async function notice(){return (await one(`INSERT INTO public.notifications(recipient_user_id,category,title,message,entity_type,entity_id,status,dedupe_key)
 VALUES($1,'ToDo','Synthetic reminder','Synthetic','todo','900','Delivered',gen_random_uuid()::text) RETURNING id`,[operator])).id;}
async function scenario(fn){await fixture();try{await fn();}finally{await engine.exec('ROLLBACK');}}
test('unseen reminder blocks all repeats, including many hours later',()=>scenario(async()=>{
 await notice();const row=await one('select notification_private.todo_followup_allowed(t,$1,now()+interval \'2 days\') allowed from public.todos t where id=900',[operator]);
 assert.equal(row.allowed,false);
 assert.equal((await one('select public.notification_schedule_todos(100) result')).result.events_created,0);
}));
test('first due occurrence is generated exactly once and the existing processor makes it visible',()=>scenario(async()=>{
 assert.equal((await one('select public.notification_schedule_todos(100) result')).result.events_created,1);
 assert.equal((await one('select public.notification_schedule_todos(100) result')).result.events_created,0);
 await q("select public.notification_run_server_processor('synthetic-simple',100,interval '15 minutes')");
 assert.equal(Number((await one("select count(*) n from public.notifications where entity_type='todo' and entity_id='900'")).n),1);
 assert.equal((await one('select next_reminder_at from public.todos where id=900')).next_reminder_at,null);
}));
test('read sets the next hour once; repeated reads never postpone it or complete the task',()=>scenario(async()=>{
 const id=await notice();await q('select public.notification_mark_read($1)',[id]);
 const first=await one('select next_reminder_at,reminder_enabled,status from public.todos where id=900');
 assert.equal(first.status,'pending');assert.equal(first.reminder_enabled,true);
 assert(Math.abs(new Date(first.next_reminder_at)-Date.now()-3600000)<5000);
 await q('select public.notification_mark_read($1)',[id]);
 assert.equal(String((await one('select next_reminder_at from public.todos where id=900')).next_reminder_at),String(first.next_reminder_at));
 assert.equal((await one('select public.notification_schedule_todos(100) result')).result.events_created,0);
}));
test('remind uses this task interval and completion changes the actual source and stops scheduling',()=>scenario(async()=>{
 await q('update public.todos set reminder_interval=30,reminder_type=\'30m\' where id=900');
 const id=await notice();await q('select public.notification_todo_action($1,\'remind\')',[id]);
 assert(Math.abs(new Date((await one('select next_reminder_at from public.todos where id=900')).next_reminder_at)-Date.now()-1800000)<5000);
 await q('select public.notification_todo_action($1,\'complete\')',[id]);
 const t=await one('select status,reminder_enabled,next_reminder_at,solved_at from public.todos where id=900');
 assert.equal(t.status,'solved');assert.equal(t.reminder_enabled,false);assert(t.solved_at);assert.equal(t.next_reminder_at,null);
 assert.equal((await one('select status from public.notifications where id=$1',[id])).status,'Completed');
 assert.equal((await one('select public.notification_schedule_todos(100) result')).result.events_created,0);
}));
test('office windows support daytime, overnight, and 24-hour delivery',()=>scenario(async()=>{
 await q("update notification_private.simple_reminder_policy set office_start='09:00',office_end='18:00'");
 assert.equal(new Date((await one("select notification_private.reminder_window('2026-10-24T13:00:00Z') next")).next).toISOString(),'2026-10-25T03:00:00.000Z');
 await q("update notification_private.simple_reminder_policy set office_start='22:00',office_end='06:00'");
 assert.equal(new Date((await one("select notification_private.reminder_window('2026-10-24T17:00:00Z') next")).next).toISOString(),'2026-10-24T17:00:00.000Z');
 await q("update notification_private.simple_reminder_policy set office_start='00:00',office_end='00:00'");
 assert.equal(new Date((await one("select notification_private.reminder_window('2026-10-24T08:00:00Z') next")).next).toISOString(),'2026-10-24T08:00:00.000Z');
}));
test('unforgeable device capability is bound to one recipient and notification',()=>scenario(async()=>{
 const id=await notice(),token='a'.repeat(64);
 await q("insert into notification_private.device_action_tokens(token_hash,notification_id,recipient_user_id) values(encode(sha256(convert_to($1,'UTF8')),'hex'),$2,$3)",[token,id,operator]);
 await engine.exec('SAVEPOINT invalid_cap');await assert.rejects(q("select public.notification_device_action($1,'complete')",['b'.repeat(64)]),/capability/);await engine.exec('ROLLBACK TO SAVEPOINT invalid_cap');
 assert.equal((await one("select public.notification_device_action($1,'complete') result",[token])).result.ok,true);
 assert.equal((await one('select status from public.todos where id=900')).status,'solved');
 assert.equal((await one("select has_function_privilege('anon','public.notification_device_action(text,text)','execute') allowed")).allowed,false);
}));
test('settings save has revision protection and keeps only approved simple controls',()=>scenario(async()=>{
 const revision=(await one('select public.notification_simple_settings_read() p')).p.revision;
 const saved=(await one('select public.notification_simple_settings_save($1,$2) p',[revision,{office_start:'00:00',office_end:'00:00',notification_enabled:true}])).p;
 assert.equal(saved.revision,Number(revision)+1);
 await engine.exec('SAVEPOINT stale');await assert.rejects(q('select public.notification_simple_settings_save($1,$2)',[revision,{office_start:'01:00'}]),/another device/);await engine.exec('ROLLBACK TO SAVEPOINT stale');
}));

test('switching to 24-hour delivery rebases old office-clamped timers without acknowledging unread work',()=>scenario(async()=>{
 await q("update notification_private.simple_reminder_policy set office_start='09:00',office_end='18:00'");
 const id=await notice();await q("select public.notification_todo_action($1,'read')",[id]);
 await q("update public.todos set next_reminder_at=now()+interval '7 days' where id=900");
 const revision=(await one('select public.notification_simple_settings_read() p')).p.revision;
 await q('select public.notification_simple_settings_save($1,$2)',[revision,{office_start:'00:00',office_end:'00:00'}]);
 assert(Math.abs(new Date((await one('select next_reminder_at from public.todos where id=900')).next_reminder_at)-Date.now()-3600000)<5000);
}));

test('re-registering a device delivers existing unread work once without changing the source',()=>scenario(async()=>{
 const id=await notice();
 const device=(await one("select public.push_subscription_register('https://fcm.googleapis.com/synthetic-device','key','auth','Synthetic device') result")).result;
 await q("select public.push_subscription_register('https://fcm.googleapis.com/synthetic-device','key','auth','Synthetic device')");
 assert.equal(Number((await one("select count(*) n from public.notification_deliveries where notification_id=$1 and subscription_id=$2",[id,device.subscription_id])).n),1);
 assert.equal((await one('select read_at from public.notifications where id=$1',[id])).read_at,null);
 assert.equal((await one('select status from public.todos where id=900')).status,'pending');
}));
test('device push test queues only the owned active device and does not wait for office hours',()=>scenario(async()=>{
 const device=(await one("select public.push_subscription_register('https://fcm.googleapis.com/synthetic-test','key','auth') result")).result;
 await q("update notification_private.simple_reminder_policy set office_start='00:01',office_end='00:02'");
 const result=(await one('select public.notification_test_device_push($1) result',[device.subscription_id])).result;
 assert.equal(result.queued,true);
 await q("select public.push_subscription_register('https://fcm.googleapis.com/other-device','key','auth')");
 await q('select public.notification_prepare_deliveries(25)');
 assert.equal(Number((await one("select count(*) n from public.notification_deliveries where notification_id=$1 and channel='WebPush'",[result.notification_id])).n),1);
 const job=await one("update public.notification_jobs set job_status='Processing',locked_by='synthetic-device',locked_at=now() where notification_id=$1 returning id",[result.notification_id]);
 const dispatch=(await one("select public.notification_get_web_push_dispatch($1,'synthetic-device') result",[job.id])).result;
 assert.equal(dispatch.deliveries.length,1);
 assert.equal(String(dispatch.deliveries[0].subscription_id),String(device.subscription_id));
 await engine.exec('SAVEPOINT rate_limit');await assert.rejects(q('select public.notification_test_device_push($1)',[device.subscription_id]),/one minute/);await engine.exec('ROLLBACK TO SAVEPOINT rate_limit');
 assert.equal((await one("select has_function_privilege('anon','public.notification_test_device_push(bigint)','execute') allowed")).allowed,false);
}));

test('content previews include the real note and action capability for every To-Do category',()=>scenario(async()=>{
 await q("update public.todos set category='salary' where id=900");const id=await notice();
 const job=await one("insert into public.notification_jobs(notification_id,job_type,job_status,locked_by,locked_at,run_at) values($1,'DeliverWebPush','Processing','preview-test',now(),now()) returning id",[id]);
 const preview=(await one("select public.notification_web_push_preview($1,'preview-test') result",[job.id])).result;
 assert.equal(preview.todo_note,'Synthetic task');assert.match(preview.action_token,/^[0-9a-f]{64}$/);
}));
