import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {PGlite} from '@electric-sql/pglite';
import {setup} from './notification-operations-fixture.mjs';
import {runSender} from '../supabase/functions/web-push-sender/worker.mjs';
import {randomUUID} from 'node:crypto';
const notification='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const value=async(db,sql,args=[])=>(await db.query(sql,args)).rows[0].v;
async function settings(db,permission='granted'){
 const panel={isConnected:true,innerHTML:'',textContent:''};
 const c={console,Date,Map,Set,Number,String,Error,Promise,Notification:{permission},document:{getElementById:id=>id==='mgEngineHealth'?panel:id==='mgNsBody'?{}:null}};c.window=c;c.mgOpenNotifSettings=async()=>{};
 c.MGHRM={client:{rpc:async name=>({data:await value(db,`select public.${name}(${name==='notification_operator_diagnostics'?'null':''}) v`)})}};
 vm.runInNewContext(fs.readFileSync('notification-engine-ui.js','utf8'),c);await c.mgOpenNotifSettings();return panel.innerHTML;
}
async function job(db,max=3){
 // Synthetic all-day policy exercises the actual V2 reservation path without
 // depending on the wall clock of a CI runner. Production hours are unchanged.
 await db.exec("UPDATE notification_private.governance_control SET enabled=true;UPDATE notification_private.digest_bridge_control SET enabled=true;UPDATE notification_private.core_policy_limits SET push_start='00:00',push_end='23:59:59'");
 const id=await value(db,"insert into public.notification_jobs(notification_id,job_type,job_status,attempt_count,maximum_attempts,run_at) values($1,'DeliverWebPush','Pending',0,$2,now()) returning id v",[notification,max]);
 await db.query("insert into public.notification_deliveries(notification_id,subscription_id,channel,delivery_status) select $1,n,'WebPush','Pending' from generate_series(1,4)n",[notification]);return id;
}
function sender(db,statusFor){
 return runSender({workerId:'actual-db-test',random:()=>0,rpc:async(name,args)=>{
  if(name==='notification_web_push_preview')return {data:{enabled:false}}; // optional preview disabled in this synthetic policy
  return db.transaction(async tx=>{await tx.exec('SET LOCAL ROLE service_role');
   const entries=Object.entries(args);const sql=`select ${name==='notification_claim_web_push_jobs'?'to_jsonb(r)':'r'} v from public.${name}(${entries.map(([k],i)=>k+'=>$'+(i+1)).join(',')}) r`;
   const rows=(await tx.query(sql,entries.map(([,v])=>v))).rows;
   return {data:name==='notification_claim_web_push_jobs'?rows.map(x=>x.v):rows[0]?.v};
  });
 },send:async(sub)=>{const code=statusFor(sub.endpoint);if(code>=400)throw {statusCode:code};return {statusCode:code,headers:{}};}});
}
test('AT-030/028 real service-role claim-dispatch-result-finalize with four devices, 503 retries and bounded dead-letter',async()=>{
 const db=new PGlite();try{await setup(db);const id=await job(db);
 const counts=await value(db,"select jsonb_build_object('todos',(select count(*) from public.todos),'work',(select count(*) from public.swa_work_items)) v");
 let first=true;const sends=new Map();
 const status=endpoint=>{sends.set(endpoint,(sends.get(endpoint)||0)+1);return first&&endpoint.endsWith('/1')?201:503;};
 const a=await sender(db,status);assert.equal(a.providerAccepted,1);assert.equal(a.failed,3);
 let j=await value(db,'select to_jsonb(j) v from public.notification_jobs j where id=$1',[id]);assert.equal(j.job_status,'Failed');assert.equal(j.attempt_count,1);assert(new Date(j.run_at)>new Date());
 first=false;
 for(let i=2;i<=3;i++){await db.query('update public.notification_jobs set run_at=now()-interval \'1 second\' where id=$1',[id]);await sender(db,status);}
 j=await value(db,'select to_jsonb(j) v from public.notification_jobs j where id=$1',[id]);assert.equal(j.job_status,'DeadLetter');assert.equal(j.attempt_count,3);assert.equal(sends.get('https://synthetic.invalid/1'),1);
 assert.equal((await sender(db,status)).claimed,0,'exhausted retries cannot reclaim');
 assert.deepEqual(await value(db,"select jsonb_build_object('todos',(select count(*) from public.todos),'work',(select count(*) from public.swa_work_items)) v"),counts);
 assert((await value(db,'select public.notification_work_get(101) v')).summary.active);
 const health=await value(db,'select public.notification_operations_health() v');assert.equal(health.jobs.deadletter,1);assert.equal(health.healthy,false);
 assert.match(await settings(db),/Delivery retries exhausted/);
 }finally{await db.close();}
});
test('overdue-transition rollback preserves source, delivery and audit data and private ACLs',async()=>{
 const db=new PGlite();try{await setup(db);
 const sql="select jsonb_build_object('todos',(select count(*) from public.todos),'work',(select count(*) from public.swa_work_items),'events',(select count(*) from public.swa_work_events),'notifications',(select count(*) from public.notifications),'deliveries',(select count(*) from public.notification_deliveries)) v";
 const before=await value(db,sql);await db.exec(fs.readFileSync('supabase/rollout/notification-overdue-transition-rollback.sql','utf8'));
 assert.deepEqual(await value(db,sql),before);
 assert.equal(await value(db,"select has_function_privilege('authenticated','notification_private.publish_work_attention(timestamptz)','execute') v"),false);
 }finally{await db.close();}
});
test('AT-040/068 actual failed delivery health reaches visible warnings without removing overnight work',async()=>{
 const db=new PGlite();try{await setup(db);await job(db,1);
 const before=(await value(db,'select public.notification_work_get(null) v')).items.map(x=>x.todo_id);
 await sender(db,()=>503);
 const h=await value(db,'select public.notification_operations_health() v');assert.equal(h.jobs.deadletter,1);assert.equal(h.web_push_deliveries.failed,4);assert.equal(h.healthy,false);
 const html=await settings(db,'denied');assert.match(html,/role="alert"/);assert.match(html,/Delivery retries exhausted/);assert.match(html,/Push is blocked on this device/);
 assert.deepEqual((await value(db,'select public.notification_work_get(null) v')).items.map(x=>x.todo_id),before);
 const digest=await value(db,"select notification_private.digest_plan('11111111-1111-4111-8111-111111111111','2026-10-24','morning','2026-10-24T03:05:00Z') v");assert.equal(digest.item_count,before.length);
 }finally{await db.close();}
});
test('AT-010 urgent approaching -> Read -> overdue re-alert stays within the existing two-per-24h quota',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=(sql,args=[])=>value(db,sql,args),at='2026-10-24T04:00:00Z';
 let d=await q('select public.notification_work_get(200) v');
 d=await q("select public.notification_work_save(200,$1,$2,'plan',$3) v",[d.work.row_version,randomUUID(),{next_action:'Review true deadline',next_party:'You',next_review_at:at,deadline_at:'2026-10-24T05:00:00Z',manager_required:false,approval_required:false,communication_required:false,execution_required:false,verification_required:false,communication_parties:[],priority:'urgent',stage:'active',change_reason:'Independent synthetic urgent task'}]);
 const publish=time=>q('select notification_private.publish_work_attention($1) v',[time]);
 async function occurrence(time,reason,accepted=true){
  const id=randomUUID();await db.query("insert into public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id,action_params) values($1,'11111111-1111-4111-8111-111111111111','ToDo','High','Ready','todo','200',$2)",[id,{policy_reason:reason}]);
  assert.equal((await q('select notification_private.reserve_push($1,$2) v',[id,time])).allowed,true);
  if(accepted)await db.query("update notification_private.push_occurrences set state='Accepted',accepted_at=$2 where notification_id=$1",[id,time]);return id;
 }
 assert.equal(await publish(at),1);const initial=await occurrence(at,'verified_time_risk',false);
 assert.equal(await publish('2026-10-24T05:01:00Z'),0,'unknown provider outcome remains conservatively coalesced');
 await db.query("update notification_private.push_occurrences set state='Accepted',accepted_at=$2 where notification_id=$1",[initial,at]);
 await db.exec("update public.notifications set status='Read',read_at=now()");
 for(let i=0;i<10;i++)assert.equal(await publish('2026-10-24T04:30:00Z'),0);
 assert.equal(await publish('2026-10-24T05:01:00Z'),1,'actual overdue transition is not swallowed by approaching acceptance');
 await occurrence('2026-10-24T05:01:00Z','overdue_work');
 for(let i=0;i<10;i++)assert.equal(await publish('2026-10-24T05:02:00Z'),0);
 const third=randomUUID();await db.query("insert into public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id) values($1,'11111111-1111-4111-8111-111111111111','ToDo','High','Ready','todo','200')",[third]);
 assert.equal((await q('select notification_private.reserve_push($1,$2) v',[third,'2026-10-24T05:03:00Z'])).allowed,false,'P2 quota is unchanged');
 assert.equal((await q('select notification_private.reserve_push($1,$2) v',[third,'2026-10-25T04:01:00Z'])).allowed,true,'rolling quota recovers after the first acceptance ages out');
 assert((await q('select public.notification_work_get(200) v')).summary.active);
 d=await q('select public.notification_work_get(200) v');await q("select public.notification_work_save(200,$1,$2,'complete',$3) v",[d.work.row_version,randomUUID(),{value:'Explicitly resolved after review'}]);
 assert.equal(await publish('2026-10-25T05:02:00Z'),0);
 }finally{await db.close();}
});
