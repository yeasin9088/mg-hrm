import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const read=p=>fs.readFileSync(p,'utf8');
const operator='11111111-1111-4111-8111-111111111111';
const other='22222222-2222-4222-8222-222222222222';
const n1='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const n2='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const migration='supabase/migrations/20261023081545_notification_phase6_dispatch_integrity.sql';
import {setup} from './notification-integrity-fixture.mjs';
test('Phase6 source, atomic reservation, read independence, ACK and digest safety',async()=>{
 const db=new PGlite();
 try{
 await setup(db);
 const value=async(sql,args)=>(await db.query(sql,args)).rows[0].v;
 const snap=(typ,id='1',user=operator)=>value('select notification_private.source_snapshot($1,$2,$3) v',[typ,id,user]);
 for(const typ of ['transfer','leave','exit','uniform_supply_order','uniform_delivery_issue','uniform_delivery_bill','disciplinary','meeting'])
  assert.equal((await snap(typ)).actionable,true,typ+' verified');
 assert.equal((await snap('todo','101',other)).actionable,false);
 assert.equal((await snap('todo','101')).actionable,true);
 assert.equal((await snap('unsupported')).supported,false);
 assert.equal((await snap('leave','missing')).actionable,false);
 await db.exec(`UPDATE public.leaves SET status='Approved';UPDATE public.transfers SET status='Not Joined';
 UPDATE public.uniform_delivery_issues SET resolution_status='Resolved';UPDATE public.uniform_delivery_bills SET paid=true;
 UPDATE public.recruitment_archive SET result='rejected';UPDATE public.disciplinary SET deleted_at=now();`);
 for(const typ of ['leave','transfer','uniform_delivery_issue','uniform_delivery_bill','disciplinary'])assert.equal((await snap(typ)).actionable,false,typ+' terminal');
 assert.equal((await snap('recruitment','candidate-1')).actionable,false);
 // Explicit known server time: 10:00 Dhaka. Read has no role in a quota.
 const at='2026-10-23T04:00:00Z';
 await db.exec(`INSERT INTO public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id)
 VALUES('${n2}','${operator}','ToDo','Normal','Ready','todo','101');`);
 const reserve=(id,clock=at)=>value('select notification_private.reserve_push($1,$2) v',[id,clock]);
 assert.equal((await reserve(n1)).allowed,true,'first occurrence reserved');
 assert.equal((await reserve(n1)).allowed,true,'second device same occurrence, quota once');
 assert.equal((await reserve(n2)).allowed,false,'second worker cannot overshoot P3 quota');
 await db.exec(`UPDATE public.notifications SET status='Read',read_at=now();`);
 assert.equal((await reserve(n2)).allowed,false,'mark all read does not replenish quota');
 await db.exec(`UPDATE notification_private.push_occurrences SET state='Accepted',accepted_at='${at}';`);
 assert.equal((await reserve(n2,'2026-10-24T03:59:59Z')).allowed,false,'rolling 24h, not midnight reset');
 assert.equal((await reserve(n2,'2026-10-24T04:00:01Z')).allowed,true,'quota recovers after rolling window');
 assert.equal((await reserve(n2,'2026-10-24T12:00:00Z')).allowed,false,'18:00 cutoff');
 assert.equal((await reserve(n2,'2026-10-24T02:59:59Z')).allowed,false,'08:59 cutoff');
 await db.exec(`UPDATE public.todos SET status='solved' WHERE id=101`);
 assert.equal((await reserve(n2,'2026-10-24T04:00:01Z')).allowed,false,'source resolved after reservation');
 await db.exec(`UPDATE public.todos SET status='open' WHERE id=101;
 UPDATE notification_private.push_occurrences SET state='Released';
 SELECT set_config('request.jwt.claim.sub','${operator}',false);`);
 const interact=(action,until,rev)=>value('select public.notification_source_interaction($1,$2,$3,$4,$5) v',['todo','101',action,until,rev]);
 const until=new Date(Date.now()+3600000).toISOString();
 assert.equal((await interact('ack',until,0)).saved,true);
 await assert.rejects(()=>interact('snooze',until,0),/revision conflict/);
 assert.equal((await reserve(n1,new Date().toISOString())).allowed,false,'ACK suppresses sends');
 const d=await value('select public.notification_operator_diagnostics($1) v',[n1]);
 assert.equal(d.interaction.revision,1);
 assert.equal(d.source.actionable,true,'ACK does not complete source');
 await interact('resume',null,1);
 await db.exec(`INSERT INTO notification_private.core_verified_deadlines(entity_type,entity_id,recipient_user_id,source_version,actual_deadline_at,verified_basis,evidence_reference)
 SELECT 'todo','101','${operator}',notification_private.source_snapshot('todo','101','${operator}')->>'source_version',now()+interval '15 minutes','manual_verified','test evidence';`);
 await assert.rejects(()=>interact('snooze',until,2),/crosses a verified deadline/);
 await db.exec(`SELECT set_config('request.jwt.claim.sub','${other}',false);`);
 await assert.rejects(()=>interact('ack',until,0),/Operator access/);
 const privileges=await value(`select jsonb_build_object('anon_diag',has_function_privilege('anon','public.notification_operator_diagnostics(uuid)','execute'),
 'anon_interaction',has_function_privilege('anon','public.notification_source_interaction(text,text,text,timestamptz,bigint)','execute'),
 'client_reserve',has_function_privilege('authenticated','notification_private.reserve_push(uuid,timestamptz)','execute'),
 'client_table',has_table_privilege('authenticated','notification_private.push_occurrences','select')) v`);
 assert.deepEqual(Object.values(privileges),[false,false,false,false]);
 // A frozen digest cannot gain a new task between device sends.
 await db.exec(`UPDATE notification_private.push_occurrences SET state='Released';
 UPDATE public.todos SET reminder_enabled=true;`);
 const batch=await value('select public.notification_digest_prepare_slot($1,$2,$3,$4) v',[operator,'2026-10-23','morning',at]);
 const digest='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 await db.query(`insert into public.notifications(id,recipient_user_id,category,status,entity_type,entity_id) values($1,$2,'System','Ready','digest',$3)`,[digest,operator,String(batch.batch_id)]);
 const initial=await reserve(digest);
 assert.equal(initial.item_count,21,'overnight tasks grouped in one occurrence');
 await db.exec(`INSERT INTO public.todos(id,owner_user_id,status,reminder_enabled,category) VALUES(999,'${operator}','open',true,'task')`);
 assert.equal((await reserve(digest)).item_count,21,'device fanout preserves frozen membership');
 await db.exec(`UPDATE public.todos SET status='solved';`);
 assert.equal((await reserve(digest)).allowed,false,'whole resolved digest suppressed');
 } finally{await db.close();}
});

test('Phase6 real dispatch/result contracts: V1 lease deferral, multi-device accounting and definitive failure release',async()=>{
 const db=new PGlite();
 try{
 await setup(db);
 const value=async(sql,args)=>(await db.query(sql,args)).rows[0].v;
 await db.exec(`
 INSERT INTO public.push_subscriptions(id,user_id,is_active,permission_state,endpoint,p256dh_key,auth_key)
 VALUES(1,'${operator}',true,'granted','https://example.invalid/a','synthetic','synthetic'),
 (2,'${operator}',true,'granted','https://example.invalid/b','synthetic','synthetic');
 INSERT INTO public.notification_jobs(id,notification_id,job_type,job_status,locked_by) OVERRIDING SYSTEM VALUE VALUES(50,'${n1}','DeliverWebPush','Processing','worker');
 INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,delivery_status)
 VALUES('${n1}',1,'WebPush','Pending'),('${n1}',2,'WebPush','Pending');
 INSERT INTO notification_private.source_interactions(recipient_user_id,entity_type,entity_id,acknowledged_until)
 VALUES('${operator}','todo','101',now()+interval '1 hour');`);
 const dispatch=()=>value("select public.notification_get_web_push_dispatch(50,'worker') v");
 const paused=await dispatch();assert.equal(paused.deferred,true);assert.equal(paused.reason,'explicit_source_work_lease','ACK applies even with V2 OFF');
 assert.equal(await value("select attempt_count v from public.notification_jobs where id=50"),0,'lease consumes no send attempt');
 await db.exec(`UPDATE notification_private.source_interactions SET acknowledged_until=null;
 UPDATE notification_private.governance_control SET enabled=true;
 UPDATE notification_private.digest_bridge_control SET enabled=true;
 UPDATE notification_private.core_policy_limits SET push_start='00:00',push_end='23:59:59';
 UPDATE public.notification_jobs SET job_status='Processing',locked_by='worker' WHERE id=50;`);
 const send=await dispatch();assert.equal(send.deliveries.length,2,'one occurrence fans out to two devices');
 const record=(id,success)=>value(`select public.notification_record_web_push_result(50,'worker',$1,$2,'201',null,$3,$4,'{}',false) v`,[id,success,success?null:'HTTP_503',success?null:'Synthetic failure']);
 await record(send.deliveries[0].delivery_id,true);
 assert.equal((await dispatch()).deliveries.length,1,'sent device never retried');
 await record(send.deliveries[1].delivery_id,true);
 assert.equal(await value("select count(*)::int v from notification_private.push_occurrences where state='Accepted'"),1,'two accepted devices consume ONE quota occurrence');
 await db.exec(`INSERT INTO public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id)
 VALUES('${n2}','${operator}','ToDo','Normal','Ready','todo','200');
 INSERT INTO public.notification_jobs(id,notification_id,job_type,job_status,locked_by) OVERRIDING SYSTEM VALUE VALUES(51,'${n2}','DeliverWebPush','Processing','worker2');
 INSERT INTO public.notification_deliveries(notification_id,subscription_id,channel,delivery_status)
 VALUES('${n2}',1,'WebPush','Pending'),('${n2}',2,'WebPush','Pending');`);
 const failed=await value("select public.notification_get_web_push_dispatch(51,'worker2') v");
 assert.equal(failed.deliveries.length,2);
 for(let i=0;i<2;i++){
 await value("select public.notification_record_web_push_result(51,'worker2',$1,false,'503',null,'HTTP_503','Synthetic failure','{}',false) v",[failed.deliveries[i].delivery_id]);
 const state=await value('select state v from notification_private.push_occurrences where notification_id=$1',[n2]);
 assert.equal(state,i===0?'Reserved':'Released','uncertain outcome retains quota; every definite failure releases it');
 }
 }finally{await db.close();}
});
