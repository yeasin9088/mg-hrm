// Synthetic PostgreSQL WASM tests. Never connects to production.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const db=new PGlite();let passed=0;
const check=async(name,fn)=>{await fn();console.log('PASS '+name);passed++;};
const q=async(sql,args=[])=>(await db.query(sql,args)).rows;
const uid='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const payload={employee_sys_id:1,exit_date:'2026-10-23',exit_type:'Voluntary Resignation',exit_reason:'Synthetic exit',issue_date:'2026-10-23'};
const settlement={enabled:true,expected:3000,deducted:0,deposited:0,outcome:'pending',reason:'salary_held',notes:'SENSITIVE-SYNTHETIC',follow_up_on:'2026-10-25'};
const submit=(p,s,id)=>q('select public.submit_exit_settlement($1::jsonb,$2::jsonb,$3::uuid) as r',[JSON.stringify(p),JSON.stringify(s),id]);
const save=(id,s,version,note='Synthetic correction')=>q('select public.save_exit_settlement($1,$2::jsonb,$3,$4) as r',[id,JSON.stringify(s),version,note]);
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
 CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION public.swa_is_operator() RETURNS boolean LANGUAGE sql STABLE AS $$SELECT auth.uid()='${uid}'::uuid$$;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
 SELECT set_config('request.jwt.claim.sub','${uid}',false);`);
 for(const t of ['employees','exits','transfers','activity_log','todos'])await db.exec(await read('supabase/schema-baseline/tables/'+t+'.sql'));
 await db.exec(`ALTER TABLE public.exits ADD PRIMARY KEY(id);ALTER TABLE public.todos ADD PRIMARY KEY(id);ALTER TABLE public.employees ADD CONSTRAINT employees_status_check CHECK(status IN ('Active','Inactive'));ALTER TABLE public.exits ADD CONSTRAINT exits_status_check CHECK(status IN ('Draft','Clearance Pending','Completed','Cancelled'));`);
 const base=await read('supabase/schema-baseline/functions/hr-workflows.sql');
 for(const name of ['create_exit_draft','complete_exit','cancel_transfer']){
  const start=base.indexOf('CREATE OR REPLACE FUNCTION public.'+name+'('),end=base.indexOf('$function$;',start);
  assert(start>=0&&end>start);await db.exec(base.slice(start,end+12));
 }
 await db.exec(await read('supabase/migrations/20261023173930_exit_confidential_settlement.sql'));
 await db.exec(`INSERT INTO public.employees(id,employee_id,full_name,designation,status,project_name,join_date) SELECT i,'SYNTHETIC-'||i,'Synthetic Employee '||i,'Guard','Active','Source','2026-01-01' FROM generate_series(1,9)i;`);
 const rid='11111111-1111-4111-8111-111111111111';let exitId;
 await check('atomic exit creates confidential record and privacy-safe follow-up',async()=>{
  const r=await submit(payload,settlement,rid);exitId=r[0].r.exit_id;
  assert.equal((await q('select status from public.employees where id=1'))[0].status,'Inactive');
  assert.equal((await q('select outcome from exit_private.settlements'))[0].outcome,'pending');
  const todo=(await q('select * from public.todos'))[0];assert(!JSON.stringify(todo).includes('SENSITIVE'));
  assert(!todo.note.includes('3000'));assert.equal(todo.reminder_enabled,true);assert.equal(todo.next_reminder_at.toISOString(),'2026-10-25T03:00:00.000Z');
 });
 await check('same request replay is idempotent; changed retry is rejected',async()=>{
  assert.equal((await submit(payload,settlement,rid))[0].r.replayed,true);
  assert.equal(Number((await q('select count(*) from public.exits'))[0].count),1);
  await assert.rejects(submit(payload,{...settlement,notes:'changed'},rid));
 });
 await check('new request on exited employee cannot create a duplicate',async()=>{
  await assert.rejects(submit(payload,settlement,'22222222-2222-4222-8222-222222222222'));
 });
 await check('invalid settlement rolls back draft, employee change and activity log',async()=>{
  await assert.rejects(submit({...payload,employee_sys_id:2},{...settlement,deducted:4000},'33333333-3333-4333-8333-333333333333'));
  assert.equal((await q('select status from public.employees where id=2'))[0].status,'Active');
  assert.equal(Number((await q('select count(*) from public.exits where employee_sys_id=2'))[0].count),0);
 });
 await check('exact first anniversary defaults off; manual reenable requires reason',async()=>{
  await db.exec("update public.employees set join_date='2025-10-23' where id=3");
  await assert.rejects(submit({...payload,employee_sys_id:3},settlement,'44444444-4444-4444-8444-444444444444'));
  await submit({...payload,employee_sys_id:3},{enabled:false},'44444444-4444-4444-8444-444444444444');
  assert.equal((await q('select default_enabled from exit_private.settlements where exit_id=(select id from public.exits where employee_sys_id=3)'))[0].default_enabled,false);
 });
 await check('amounts cannot be silently rounded; nonfinite and missing values rejected',async()=>{
  for(const value of ['0.001','NaN','Infinity',null])await assert.rejects(save(exitId,{...settlement,deducted:value},1));
 });
 await check('stale-device save and missing correction reason preserve saved values',async()=>{
  await assert.rejects(save(exitId,settlement,0));await assert.rejects(save(exitId,settlement,1,''));
  assert.equal((await q('select version from exit_private.settlements where exit_id=$1',[exitId]))[0].version,1);
 });
 await check('partial deduction, deposit evidence and immutable version history',async()=>{
  const part={...settlement,outcome:'partial',deducted:1000,deposited:500,deducted_on:'2026-10-22',deposited_on:'2026-10-23',receipt_no:'SYN-R1',deposited_to:'Synthetic Accounts'};
  await assert.rejects(save(exitId,{...part,receipt_no:''},1));
  await save(exitId,part,1);
  assert.equal(Number((await q('select count(*) from exit_private.settlement_history where exit_id=$1',[exitId]))[0].count),2);
  const history=(await q('select public.get_exit_settlement_history($1) as r',[exitId]))[0].r;
  assert.equal(history[0].before_data.deducted,0);assert.equal(history[0].after_data.deducted,1000);
 });
 await check('waiver requires authority; final recorded settlement closes generic follow-up',async()=>{
  await assert.rejects(save(exitId,{...settlement,outcome:'waived',reason:'special_waiver'},2));
  await save(exitId,{...settlement,outcome:'waived',reason:'special_waiver',approved_by:'Synthetic Manager'},2);
  assert.equal((await q('select status from public.todos'))[0].status,'solved');
 });
 await check('report distinguishes unrecorded history and hides retry payload',async()=>{
  await db.exec("insert into public.exits(employee_sys_id,full_name,join_date,exit_date,effective_exit_date,status) values(4,'Synthetic Legacy','2025-01-01','2026-10-23','2026-10-23','Completed')");
  const rows=(await q("select public.get_exit_settlement_report('2026-10-01','2026-10-31',null) as r"))[0].r;
  assert.equal(rows.find(x=>x.full_name==='Synthetic Legacy').settlement,null);
  assert(!JSON.stringify(rows).includes('request_payload'));assert(!JSON.stringify(rows).includes('request_id'));
  const generic=await q('select * from public.exits');assert(!JSON.stringify(generic).includes('SENSITIVE'));
 });
 await check('linked transfer cancellation is atomic and never changes project',async()=>{
  await db.exec("insert into public.transfers(id,employee_sys_id,status,current_project,new_project) values(100,5,'Not Joined','Source','Destination')");
  await assert.rejects(submit({...payload,employee_sys_id:5,related_transfer_id:100},{...settlement,deposited:500},'55555555-5555-4555-8555-555555555555'));
  assert.equal((await q('select status from public.transfers where id=100'))[0].status,'Not Joined');
  await submit({...payload,employee_sys_id:5,related_transfer_id:100},settlement,'55555555-5555-4555-8555-555555555555');
  assert.equal((await q('select status from public.transfers where id=100'))[0].status,'Cancelled');
  assert.equal((await q('select project_name from public.employees where id=5'))[0].project_name,'Source');
 });
 await check('reactivation preserves completed exit snapshots and financial history',async()=>{
  await q("select public.reactivate_employee(1,'2026-10-23','Source','Synthetic rejoining')");
  assert.equal((await q('select status from public.employees where id=1'))[0].status,'Active');
  const x=(await q('select status,join_date from public.exits where id=$1',[exitId]))[0];assert.equal(x.status,'Completed');assert.equal(x.join_date,'2026-01-01');
  assert.equal((await q('select version from exit_private.settlements where exit_id=$1',[exitId]))[0].version,3);
 });
 await check('future and before-joining exits are rejected server-side',async()=>{
  await assert.rejects(submit({...payload,employee_sys_id:6,exit_date:'2099-01-01'},settlement,'66666666-6666-4666-8666-666666666666'));
  await assert.rejects(submit({...payload,employee_sys_id:6,exit_date:'2025-12-31'},settlement,'66666666-6666-4666-8666-666666666666'));
 });
 await check('anonymous and other authenticated identities cannot read or change confidential data',async()=>{
  await db.exec("set role anon");await assert.rejects(q("select public.get_exit_settlement_report('2026-10-01','2026-10-31',null)"));await db.exec('reset role');
  await db.exec("select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false);set role authenticated");
  await assert.rejects(q("select public.get_exit_settlement_report('2026-10-01','2026-10-31',null)"));
  await assert.rejects(save(exitId,settlement,3));await assert.rejects(submit({...payload,employee_sys_id:7},settlement,'77777777-7777-4777-8777-777777777777'));
  await assert.rejects(q('select * from exit_private.settlements'));
  await db.exec('reset role');
 });
 await check('approved operator uses invoker API but cannot bypass private audit tables',async()=>{
  await db.exec(`select set_config('request.jwt.claim.sub','${uid}',false);set role authenticated`);
  const rows=await q("select public.get_exit_settlement_report('2026-10-01','2026-10-31',null) as r");assert(rows[0].r.length>=3);
  await assert.rejects(q('delete from exit_private.settlement_history'));
  await db.exec('reset role');
  const funcs=await q("select prosecdef from pg_proc where proname in ('submit_exit_settlement','save_exit_settlement','get_exit_settlement_report','get_exit_settlement_history')");assert(funcs.every(x=>!x.prosecdef));
 });
 console.log(`${passed} isolated database checks passed.`);
}finally{await db.close();}
