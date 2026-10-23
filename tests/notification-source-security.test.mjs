import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
import {setup,operator} from './notification-workflow-fixture.mjs';
export const guardMigration='supabase/migrations/20261023161105_notification_source_access_guard.sql';
const other='22222222-2222-4222-8222-222222222222';
const tables=['uniform_supply_orders','uniform_delivery_issues','uniform_delivery_bills'];
test('approved operator retains source access; an active unapproved admin and anon cannot use permissive legacy uniform policies',async()=>{
 const db=new PGlite();try{await setup(db);
 await db.exec(`ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'admin';INSERT INTO public.profiles(id,is_active,role) VALUES('${other}',true,'admin');`);
 for(const table of tables)await db.exec(`ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;GRANT SELECT,INSERT,UPDATE,DELETE ON public.${table} TO authenticated,anon;CREATE POLICY legacy_access ON public.${table} FOR ALL TO authenticated USING(true) WITH CHECK(true);`);
 await db.exec(fs.readFileSync(guardMigration,'utf8'));
 const q=async(sql)=>(await db.query(sql)).rows[0].v;
 await db.exec(`SELECT set_config('request.jwt.claim.sub','${operator}',false);SET ROLE authenticated;`);
 assert.equal(await q('select public.my_role() v'),'admin');
 for(const table of tables)assert.equal(await q('select count(*)::int v from public.'+table),1,'approved operator '+table);
 await db.exec(`RESET ROLE;SELECT set_config('request.jwt.claim.sub','${other}',false);SET ROLE authenticated;`);
 assert.equal(await q('select public.my_role() v'),'none','stored admin role cannot bypass approved identity');
 for(const table of tables){
  assert.equal(await q('select count(*)::int v from public.'+table),0,'non-owner '+table);
  assert.equal((await db.query('update public.'+table+' set id=id returning id')).rows.length,0);
  await assert.rejects(()=>db.exec('insert into public.'+table+'(id) values(999)'),/row-level security/);
 }
 await assert.rejects(()=>q('select public.notification_work_get(null) v'),/Operator/);
 await db.exec('RESET ROLE;SET ROLE anon;');
 for(const table of tables)assert.equal(await q('select count(*)::int v from public.'+table),0,'anonymous '+table);
 await db.exec('RESET ROLE;');
 assert.equal(await q('select count(*)::int v from public.todos'),21,'no source rows removed');
 await db.exec(fs.readFileSync('supabase/rollout/notification-source-access-rollback.sql','utf8'));
 assert.equal(await q("select count(*)::int v from pg_policies where policyname='notification_operator_boundary'"),0);
 }finally{await db.close();}
});
