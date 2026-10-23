import test from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {setup,operator} from './notification-workflow-fixture.mjs';
import {randomUUID} from 'node:crypto';
const plan={next_action:'Tell project after decision',next_party:'You',next_review_at:'2026-11-01T04:00:00Z',manager_required:true,approval_required:true,communication_required:true,communication_parties:['Project','Admin'],execution_required:true,verification_required:true,priority:'important',stage:'active'};
test('existing To-Do workflow: manager decisions, independent handoffs, CAS, idempotency and completion',async()=>{
 const db=new PGlite();try{
 await setup(db);
 const get=async id=>(await db.query('select public.notification_work_get($1) v',[id])).rows[0].v;
 let current=await get(200);
 const save=async(action,payload={},key=randomUUID(),version=current.work.row_version)=>{
 const args=[200,version,key,action,payload];
 const r=(await db.query('select public.notification_work_save($1,$2,$3,$4,$5) v',args)).rows[0].v;
 current=r;return r;
 };
 current=await save('plan',plan);assert.equal(current.work.approval_required,true);
 await assert.rejects(()=>save('complete',{value:'complete evidence'}),/Required/);
 current=await save('informed',{value:'phone',occurred_at:'2026-10-22T15:00:00Z'});
 assert.equal(current.work.manager_decision,'pending','AT004 informed is not approved');
 current=await save('decision',{value:'approved'});
 assert.equal(current.work.executed_at,null,'AT005 approval is not execution');
 assert.equal(current.summary.communication_pending,true);
 current=await save('communicated',{value:'Project'});
 assert.equal(current.work.communicated_at,null,'independent admin communication remains');
 const version=current.work.row_version,key=randomUUID(),payload={value:'Admin'};
 const first=await save('communicated',payload,key,version);
 const replay=await save('communicated',payload,key,version);
 assert.deepEqual(replay,first,'uncertain response retry returns original durable result');
 await assert.rejects(()=>save('executed',{},randomUUID(),version),/Conflict/);
 current=await save('executed');current=await save('verified');
 await assert.rejects(()=>save('complete',{value:''}),/evidence/);
 current=await save('complete',{value:'Completed and verified manually'});
 assert.equal(current.summary.active,false);
 assert.equal((await db.query('select solved_at from public.todos where id=200')).rows[0].solved_at!==null,true);
 assert(current.events.some(e=>e.event_type==='workflow_record'));
 current=await save('reopen',{value:'New follow-up required'});
 assert.equal(current.summary.active,true);assert.equal(current.work.completed_at,null);
 // Required steps also protect direct legacy To-Do completion.
 await assert.rejects(()=>db.exec("UPDATE public.todos SET status='solved',solved_at=now() WHERE id=200"),/Required workflow/);
 // No decision, source, payroll, employee or messaging actions are implicit.
 assert.equal(current.work.manager_decision,'none');
 }finally{await db.close();}
});
test('quick capture retry, distinct requests, module reconciliation and privacy',async()=>{
 const db=new PGlite();try{await setup(db);
 const query=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 const key=randomUUID();const p={category:'salary',subject:'Private salary discrepancy',project:'Test'};
 const a=await query('select public.notification_work_capture($1,$2) v',[key,p]);
 const b=await query('select public.notification_work_capture($1,$2) v',[key,p]);assert.equal(a.todo_id,b.todo_id);
 const c=await query('select public.notification_work_capture($1,$2) v',[randomUUID(),p]);assert.notEqual(c.todo_id,a.todo_id);
 await db.exec('select notification_private.reconcile_module_work()');
 const rows=(await db.query('select work_source_type,work_source_id,count(*) from public.todos where work_source_id is not null group by 1,2')).rows;
 assert.equal(rows.length,7);assert(rows.every(r=>r.count===1));
 await db.exec('select notification_private.reconcile_module_work()');
 assert.equal(await query('select count(*) v from public.todos where work_source_id is not null'),7);
 assert.equal(await query("select count(*) v from public.todos where work_source_type in ('meeting','disciplinary')"),0);
 const digest=await query("select notification_private.digest_plan($1,'2026-10-23','morning','2026-10-23T11:00:00Z') v",[operator]);
 assert(!JSON.stringify(digest).includes('Private salary'),'sensitive text absent from digest payload');
 await db.exec("SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false)");
 await assert.rejects(()=>query('select public.notification_work_get(null) v'),/Operator/);
 assert.equal(await query("select has_function_privilege('anon','public.notification_work_save(bigint,integer,uuid,text,jsonb)','execute') v"),false);
 }finally{await db.close();}
});
test('rejection leaves party communication open, true deadlines survive read and snooze, after-hours records are allowed',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 let d=await q('select public.notification_work_get(200) v');
 const save=async(a,p={})=>{d=await q('select public.notification_work_save(200,$1,$2,$3,$4) v',[d.work.row_version,randomUUID(),a,p]);return d;};
 await save('plan',{...plan,deadline_at:'2026-11-02T02:00:00Z'});
 await save('informed',{value:'phone',occurred_at:'2026-10-22T15:00:00Z'});
 await save('decision',{value:'rejected',occurred_at:'2026-10-22T15:00:00Z'});
 assert(d.summary.communication_pending,'AT006 rejection communication remains');
 assert(!d.summary.steps.includes('অফিসীয় কাজ সম্পাদন করুন'),'rejection cannot authorize execution');
 await assert.rejects(()=>save('executed'),/approval/);
 const risk=await q("select notification_private.work_summary(w,'2026-11-01T16:00:00Z') v from public.swa_work_items w where id=$1",[d.work.id]);
 assert.equal(risk.risk,'before_office_risk','AT052 08:00 deadline remains before next office open');
 const overdue=await q("select notification_private.work_summary(w,'2026-11-02T02:30:00Z') v from public.swa_work_items w where id=$1",[d.work.id]);
 assert.equal(overdue.risk,'overdue','AT066 deadline is not moved to 09:00');
 const before=d.work.deadline_at;
 await db.exec("UPDATE public.notifications SET status='Read',read_at=now()");
 d=await q('select public.notification_work_get(200) v');assert.equal(d.work.deadline_at,before);
 await assert.rejects(()=>save('snooze',{value:'2026-11-02T03:00:00Z'}),/deadline|30 days/);
 await save('communicated',{value:'Project'});await save('communicated',{value:'Admin'});await save('verified');
 assert.equal(d.summary.can_complete,true);
 await save('complete',{value:'Rejection communicated and verified'});assert.equal(d.summary.active,false);
 }finally{await db.close();}
});
test('salary month split, missing or overlapping days and promised next-cycle follow-up',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 const cap=await q('select public.notification_work_capture($1,$2) v',[randomUUID(),{subject:'Salary allocation',category:'salary'}]);
 let d=await q('select public.notification_work_get($1) v',[cap.todo_id]);
 const save=async(context)=>{d=await q('select public.notification_work_save($1,$2,$3,\'plan\',$4) v',[cap.todo_id,d.work.row_version,randomUUID(),{...plan,manager_required:false,approval_required:false,communication_required:true,communication_parties:['Admin','Employee'],promised_at:'2026-12-01T04:00:00Z',context}]);return d;};
 let ctx={allocation_required:true,salary_month:'2026-11',allocations:[{project:'A',from:'2026-11-01',to:'2026-11-15'},{project:'B',from:'2026-11-16',to:'2026-11-30'}]};
 await save(ctx);assert.equal(d.summary.allocation_needs_verification,false);
 ctx.allocations[1].from='2026-11-17';await save(ctx);assert.equal(d.summary.allocation_needs_verification,true,'AT023 missing allocation detected');
 ctx.allocations[1].from='2026-11-15';await save(ctx);assert.equal(d.summary.allocation_needs_verification,true,'overlap detected');
 assert.equal(new Date(d.work.promised_at).toISOString(),'2026-12-01T04:00:00.000Z','AT024 next cycle promise persists');
 const digest=await q("select notification_private.digest_plan($1,'2026-12-01','morning','2026-12-01T04:00:00Z') v",[operator]);
 assert(digest.items.some(x=>Number(x.todo_id)===Number(cap.todo_id)),'promise remains after period rollover');
 }finally{await db.close();}
});
test('source rescheduling invalidates queued versions, terminal source preserves handoffs and no HR mutation',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 await db.exec('UPDATE notification_private.governance_control SET enabled=true; UPDATE notification_private.digest_bridge_control SET enabled=true;select notification_private.reconcile_module_work()');
 const tid=await q("select id v from public.todos where work_source_type='transfer' and work_source_id='1'");
 const before=await q("select notification_private.source_snapshot('todo',$1,$2) v",[String(tid),operator]);
 await db.exec("UPDATE public.transfers SET effective_date=current_date+2");
 const after=await q("select notification_private.source_snapshot('todo',$1,$2) v",[String(tid),operator]);assert.notEqual(after.source_version,before.source_version,'AT015 reschedule invalidates queued fingerprint');
 await db.exec(`INSERT INTO public.notifications(id,recipient_user_id,category,entity_type,entity_id,status) VALUES('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','${operator}','ToDo','transfer','1','Ready'),('ffffffff-ffff-4fff-8fff-ffffffffffff','${operator}','ToDo','transfer','1','Ready');
 INSERT INTO public.notification_deliveries(notification_id,channel,delivery_status,sent_at) VALUES('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','WebPush','Sent','2026-10-23T05:00:00Z'),('ffffffff-ffff-4fff-8fff-ffffffffffff','WebPush','Sent','2026-10-23T05:01:00Z');`);
 assert.equal(await q("select notification_private.push_quota_allowed('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',$1,'todo',$2,'ToDo','P2','2026-10-23T05:02:00Z') v",[operator,String(tid)]),false,'direct historical source sends count towards the linked To-Do cap');

 const pending=await q('select public.notification_work_get($1) v',[tid]);assert.equal(pending.summary.can_complete,false,'future scheduled transfer still needs explicit joining');
 assert.equal(await q("select joining_confirmed_at v from public.transfers where id=1"),null,'AT019 no automatic joining');
 await db.exec("UPDATE public.transfers SET status='Not Joined',not_joined_at=now()");
 assert.equal(await q('select notification_private.todo_actionable(t) v from public.todos t where id=$1',[tid]),false,'AT020 source not-joined ends joining obligation');
 await db.exec("UPDATE public.transfers SET status='Scheduled',not_joined_at=NULL");
 assert.equal(await q('select notification_private.todo_actionable(t) v from public.todos t where id=$1',[tid]),true,'explicit source reopening restores its auto-closed follow-up');
 const leave=await q("select id v from public.todos where work_source_type='leave'");
 await db.exec("UPDATE public.leaves SET status='Approved'");
 const ld=await q('select public.notification_work_get($1) v',[leave]);assert.equal(ld.summary.communication_pending,true,'AT022 source approval retains project handoff');
 assert.equal(ld.summary.active,true);
 }finally{await db.close();}
});
test('fifteen manager notes record independent decisions, exact session summary and concurrency conflicts',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 const s=await q("select to_jsonb(public.swa_start_briefing('Synthetic after-hours session')) v");
 for(let i=0;i<15;i++){
 const cap=await q('select public.notification_work_capture($1,$2) v',[randomUUID(),{subject:'Independent request '+i,category:'permission'}]);
 let d=await q('select public.notification_work_get($1) v',[cap.todo_id]);
 d=await q('select public.notification_work_save($1,$2,$3,\'plan\',$4) v',[cap.todo_id,d.work.row_version,randomUUID(),{...plan}]);
 d=await q('select public.notification_work_save($1,$2,$3,\'informed\',$4) v',[cap.todo_id,d.work.row_version,randomUUID(),{value:'in_person',session_id:s.id}]);
 if(i<10)await q('select public.notification_work_save($1,$2,$3,\'decision\',$4) v',[cap.todo_id,d.work.row_version,randomUUID(),{value:'approved',session_id:s.id}]);
 }
 const summary=await q('select public.notification_work_brief_summary($1) v',[s.id]);assert.deepEqual(summary,{discussed:15,decision_recorded:10,pending_decision:5},'AT050 no bulk approval / unrecorded outcomes visible');
 await q('select public.swa_close_briefing($1) v',[s.id]);
 }finally{await db.close();}
});
test('containment preserves tasks, source records, audit and queued intents while disabling new mutations',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async sql=>(await db.query(sql)).rows[0].v;
 const before=await q("select jsonb_build_object('todos',(select count(*) from public.todos),'events',(select count(*) from public.swa_work_events),'sources',(select count(*) from public.transfers),'items',(select count(*) from public.swa_work_items)) v");
 const fs=await import('node:fs');await db.exec(fs.readFileSync('supabase/rollout/notification-workflow-containment.sql','utf8'));
 assert.deepEqual(await q("select jsonb_build_object('todos',(select count(*) from public.todos),'events',(select count(*) from public.swa_work_events),'sources',(select count(*) from public.transfers),'items',(select count(*) from public.swa_work_items)) v"),before);
 assert.equal(await q("select has_function_privilege('authenticated','public.notification_work_save(bigint,integer,uuid,text,jsonb)','execute') v"),false);
 assert.equal(await q('select enabled v from notification_private.governance_control'),false);
 }finally{await db.close();}
});
test('important near-deadline alerts are bounded between digests and respect exact office clock',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 let d=await q('select public.notification_work_get(200) v');
 d=await q('select public.notification_work_save(200,$1,$2,\'plan\',$3) v',[d.work.row_version,randomUUID(),{...plan,deadline_at:'2026-10-23T11:59:00Z'}]);
 assert.equal(await q("select notification_private.publish_work_attention('2026-10-23T11:58:00Z') v"),1);
 for(let i=0;i<10;i++)assert.equal(await q("select notification_private.publish_work_attention('2026-10-23T11:58:00Z') v"),0,'AT009/010 no tick storm');
 assert.equal(await q("select notification_private.publish_work_attention('2026-10-23T12:00:00Z') v"),0,'AT054 18:00 routine push closed');
 const events=(await db.query("select event_payload from public.notification_events where event_type='TodoWorkAttention'")).rows;
 assert.equal(events.length,1);assert(!JSON.stringify(events).includes('Tell project'));
 }finally{await db.close();}
});
test('required substeps block parent completion and remain independently audited',async()=>{
 const db=new PGlite();try{await setup(db);
 const q=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
 let d=await q('select public.notification_work_get(101) v');
 const save=async(a,p)=>{d=await q('select public.notification_work_save(101,$1,$2,$3,$4) v',[d.work.row_version,randomUUID(),a,p]);return d;};
 const p={...plan,manager_required:false,approval_required:false,communication_required:false,execution_required:false,verification_required:false,change_reason:'Replace default with explicit document checklist',context:{checklist:[{id:'docs',label:'Obtain documents',required:true},{id:'placement',label:'Confirm placement',required:true}]}};
 await save('plan',p);assert.equal(d.summary.can_complete,false);
 await save('check_step',{value:'docs'});assert.equal(d.summary.can_complete,false);
 await assert.rejects(()=>save('complete',{value:'Finished'}),/Required/);
 await assert.rejects(()=>save('plan',{...p,change_reason:'',context:{checklist:[]}}),/Reason required/);
 await save('check_step',{value:'placement'});assert.equal(d.summary.can_complete,true);
 await save('complete',{value:'All documents and placement verified'});
 assert.equal(d.summary.active,false);assert.equal(d.events.filter(e=>e.event_type==='checklist_step_recorded').length,2);
 }finally{await db.close();}
});
