// Isolated synthetic PostgreSQL only. Never connects to Supabase.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite(),read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const q=async(s,a=[])=>(await db.query(s,a)).rows;
let passed=0;const check=async(n,f)=>{await f();console.log('PASS '+n);passed++;};
const uid='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION public.swa_is_operator() RETURNS boolean LANGUAGE sql STABLE AS $$SELECT auth.uid()='${uid}'::uuid$$;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;SELECT set_config('request.jwt.claim.sub','${uid}',false);`);
 for(const t of ['employees','exits','transfers','activity_log','todos'])await db.exec(await read('supabase/schema-baseline/tables/'+t+'.sql'));
 await db.exec("ALTER TABLE public.exits ADD PRIMARY KEY(id);ALTER TABLE public.todos ADD PRIMARY KEY(id);ALTER TABLE public.employees ADD CONSTRAINT employees_status_check CHECK(status IN ('Active','Inactive'));ALTER TABLE public.exits ADD CONSTRAINT exits_status_check CHECK(status IN ('Draft','Clearance Pending','Completed','Cancelled'));");
 const base=await read('supabase/schema-baseline/functions/hr-workflows.sql');
 for(const name of ['create_exit_draft','complete_exit','cancel_transfer']){const a=base.indexOf('CREATE OR REPLACE FUNCTION public.'+name+'('),b=base.indexOf('$function$;',a);await db.exec(base.slice(a,b+12));}
 for(const name of ['20261023173930_exit_confidential_settlement.sql','20261023181336_exit_mandatory_deduction_decision.sql','20261023183543_exit_reason_unified_compact_form.sql'])await db.exec(await read('supabase/migrations/'+name));
 const migration=process.argv[2]||new URL('../supabase/migrations/'+(await fs.readdir(new URL('../supabase/migrations/',import.meta.url))).find(n=>n.endsWith('_exit_record_control.sql')),import.meta.url);
 await db.exec(await fs.readFile(migration,'utf8'));

 // Install the actual production clock guard with isolated policy/queue fixtures.
 await db.exec(`ALTER TABLE public.todos ADD COLUMN reminder_due_at timestamptz;ALTER TABLE public.todos ADD COLUMN reminder_timezone text NOT NULL DEFAULT 'Asia/Dhaka';
 CREATE SCHEMA notification_private;
 CREATE FUNCTION public.notification_reminder_mode() RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
 CREATE FUNCTION notification_private.todo_actionable(t public.todos) RETURNS boolean LANGUAGE sql AS $$SELECT t.deleted_at IS NULL AND t.solved_at IS NULL AND t.status NOT IN ('solved','done')$$;
 CREATE FUNCTION notification_private.todo_next(t public.todos,p_after timestamptz) RETURNS timestamptz LANGUAGE sql AS $$SELECT coalesce(t.next_reminder_at,p_after)$$;
 CREATE FUNCTION notification_private.reminder_window(p_due timestamptz) RETURNS timestamptz LANGUAGE sql AS $$SELECT p_due+coalesce(nullif(current_setting('test.window_minutes',true),''),'0')::int*interval '1 minute'$$;
 CREATE FUNCTION public.notification_effective_preference(p_user_id uuid,p_category text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"notification_enabled":true}'::jsonb$$;
 CREATE TABLE public.notifications(id uuid PRIMARY KEY,entity_type text,entity_id text,category text,status text,recipient_user_id uuid,read_at timestamptz,snoozed_until timestamptz);
 CREATE TABLE public.notification_events(id uuid PRIMARY KEY,entity_type text,entity_id text,event_type text,processing_status text,processing_error text);
 CREATE TABLE public.notification_deliveries(notification_id uuid,channel text,delivery_status text,provider_status text);
 CREATE TABLE public.notification_jobs(notification_id uuid,event_id uuid,job_status text,locked_by text,locked_at timestamptz);
 CREATE FUNCTION notification_private.todo_followup_allowed(t public.todos,p_recipient uuid,p_now timestamptz) RETURNS boolean LANGUAGE sql AS $$SELECT NOT EXISTS(SELECT 1 FROM public.notifications WHERE entity_type='todo' AND entity_id=t.id::text AND status IN ('Scheduled','Ready','Delivered','Read','Actioned','Snoozed','Failed') AND (read_at IS NULL OR snoozed_until>p_now))$$;`);
 const authority=await read('supabase/migrations/20261024201313_authoritative_reminder_timing.sql');
 for(const name of ['effective_reminder_due','guard_reminder_clock']){const a=authority.indexOf('CREATE FUNCTION notification_private.'+name+'('),b=authority.indexOf('END $$;',a);await db.exec(authority.slice(a,b+7));}
 await db.exec('CREATE TRIGGER notification_server_clock BEFORE INSERT OR UPDATE ON public.todos FOR EACH ROW EXECUTE FUNCTION notification_private.guard_reminder_clock();');
 const clockMigration=process.argv[3]||new URL('../supabase/migrations/'+(await fs.readdir(new URL('../supabase/migrations/',import.meta.url))).find(n=>n.endsWith('_exit_followup_clock.sql')),import.meta.url);
 await db.exec(await fs.readFile(clockMigration,'utf8'));
 await db.exec("INSERT INTO public.employees(id,employee_id,full_name,designation,status,project_name,join_date) VALUES(1,'SYN-1','Synthetic only','Guard','Active','Original','2026/1/22');");
 const future=(await q("select (current_date+15)::text as day"))[0].day;
 let id,version=1,todo;
 let fields={exit_date:'2026-09-21',issue_date:'2026-10-29',exit_reason:'Absconded Without Notice'};
 let settlement={enabled:true,expected:3000,deducted:0,deposited:0,outcome:'pending',reason:'payroll_pending',follow_up_on:future,follow_up_time:'14:30'};
 const edit=async(p,s=settlement,v=version,original=fields)=>q('select public.update_exit_record($1,$2::jsonb,$3::jsonb,$4,$5::jsonb,$6) as r',[id,JSON.stringify(p),JSON.stringify(s),v,JSON.stringify(original),'Synthetic update']);
 await check('initial exit creates one confidential linked task at selected Dhaka time',async()=>{
  const r=await q('select public.submit_exit_settlement($1::jsonb,$2::jsonb,$3::uuid) as r',[JSON.stringify({employee_sys_id:1,...fields}),JSON.stringify(settlement),'11111111-1111-4111-8111-111111111111']);id=r[0].r.exit_id;
  const t=(await q('select * from public.todos'))[0];todo=t.id;assert.equal(t.next_reminder_at.toISOString(),future+'T08:30:00.000Z');assert.equal(t.source,'exit_settlement');assert(!JSON.stringify(t).includes('3000'));
 });
 await check('one atomic save updates exit, same settlement, same todo and audit',async()=>{
  const next={...fields,exit_date:'2026-09-22',exit_reason:'Corrected exit reason'};
  const r=(await edit(next))[0].r;version=r.settlement.version;fields=next;
  assert.equal((await q('select exit_date from public.exits where id=$1',[id]))[0].exit_date,'2026-09-22');
  assert.equal((await q('select count(*) as n from public.todos'))[0].n,1);
  const h=(await q('select public.get_exit_settlement_history($1) as r',[id]))[0].r[0];assert.equal(h.before_data.exit_details.exit_date,'2026-09-21');assert.equal(h.after_data.exit_details.exit_date,'2026-09-22');assert.equal((await q('select exit_date from public.employees where id=1'))[0].exit_date,'2026-09-22');
 });
 await check('stale settlement version or exit snapshot rolls back all changes',async()=>{
  const next={...fields,exit_reason:'Must roll back'};await assert.rejects(edit(next,settlement,0));
  await assert.rejects(edit(next,settlement,version,{...fields,exit_reason:'Old snapshot'}));
  assert.equal((await q('select exit_reason from public.exits where id=$1',[id]))[0].exit_reason,fields.exit_reason);
 });
 await check('full deduction with deposit pending keeps reminder; time update reuses task',async()=>{
  await q("INSERT INTO public.notifications VALUES('cccccccc-cccc-4ccc-8ccc-cccccccccccc','todo',$1,'ToDo','Delivered',$2,null,null)",[String(todo),uid]);
  await db.exec("INSERT INTO public.notification_deliveries VALUES('cccccccc-cccc-4ccc-8ccc-cccccccccccc','WebPush','Pending',null);");
  settlement={...settlement,outcome:'collected',deducted:3000,deposited:0,reason:'',deducted_on:'2026-10-20',follow_up_time:'16:15'};
  const r=(await edit(fields))[0].r;version=r.settlement.version;
  const t=(await q('select * from public.todos where id=$1',[todo]))[0];assert.equal(t.next_reminder_at.toISOString(),future+'T10:15:00.000Z');assert.equal(t.reminder_enabled,true);assert.equal((await q('select count(*) as n from public.todos'))[0].n,1);
  assert.equal(t.reminder_due_at.toISOString(),future+'T10:15:00.000Z');
  assert.equal((await q('select status from public.notifications'))[0].status,'Cancelled');assert.equal((await q('select delivery_status from public.notification_deliveries'))[0].delivery_status,'Cancelled');
  assert.notEqual((await q("select current_setting('mghrm.scheduler_write',true) as flag"))[0].flag,'on');
 });

 await check('ordinary writes cannot alter clocks; source edits still respect office windows',async()=>{
  const before=(await q('select next_reminder_at from public.todos where id=$1',[todo]))[0].next_reminder_at.toISOString();
  await q("update public.todos set next_reminder_at=now()+interval '1 minute' where id=$1",[todo]);
  assert.equal((await q('select next_reminder_at from public.todos where id=$1',[todo]))[0].next_reminder_at.toISOString(),before);
  await db.exec("select set_config('test.window_minutes','30',false)");
  settlement={...settlement,follow_up_time:'17:15'};version=(await edit(fields))[0].r.settlement.version;
  const t=(await q('select * from public.todos where id=$1',[todo]))[0];assert.equal(t.reminder_due_at.toISOString(),future+'T11:15:00.000Z');assert.equal(t.next_reminder_at.toISOString(),future+'T11:45:00.000Z');
  await db.exec("select set_config('test.window_minutes','0',false)");
 });
 await check('invalid settlement after exit edit cannot partially update dates',async()=>{
  await assert.rejects(edit({...fields,exit_date:'2026-09-23'},{...settlement,deposited:4000}));assert.equal((await q('select exit_date from public.exits where id=$1',[id]))[0].exit_date,fields.exit_date);
 });
 await check('settled deposit closes the same task and report retains editable snapshot',async()=>{
  settlement={...settlement,deposited:3000,deposited_on:'2026-10-21',receipt_no:'SYN-R1',deposited_to:'Synthetic accounts',follow_up_on:''};
  version=(await edit(fields))[0].r.settlement.version;
  const t=(await q('select * from public.todos where id=$1',[todo]))[0];assert.equal(t.status,'solved');assert.equal(t.reminder_enabled,false);
  const row=(await q('select public.get_exit_settlement_report(null,null,$1) as r',[id]))[0].r[0];assert.equal(row.issue_date,fields.issue_date);assert.equal(row.exit_reason,fields.exit_reason);assert.equal(row.settlement.deposited,3000);
  assert.equal((await q('select public.get_exit_for_followup($1) as id',[todo]))[0].id,id);
 });
 await check('editing historical exit never changes current project or active employment',async()=>{
  await db.exec("UPDATE public.employees SET status='Active',join_date='2026-10-01',project_name='Rejoined project' WHERE id=1;");
  const next={...fields,exit_reason:'Historical correction'};version=(await edit(next))[0].r.settlement.version;fields=next;
  const e=(await q('select status,project_name,join_date from public.employees where id=1'))[0];assert.equal(e.status,'Active');assert.equal(e.project_name,'Rejoined project');assert.equal(e.join_date,'2026-10-01');
  await assert.rejects(edit({...fields,exit_date:'2026-10-02',issue_date:'2026-10-29'}));
 });
 await check('unauthorized callers cannot read links or update confidential data',async()=>{
  await db.exec("SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false)");await assert.rejects(edit(fields));await assert.rejects(q('select public.get_exit_for_followup($1)',[todo]));
  await db.exec('SET ROLE anon');await assert.rejects(q('select public.get_exit_for_followup($1)',[todo]));
 });
 console.log(`${passed} integration checks passed`);
}finally{await db.close();}
