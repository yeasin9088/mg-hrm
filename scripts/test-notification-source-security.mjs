// Runs after the workflow concurrency fixture, in a disposable real PG database.
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
if(process.env.PGDATABASE!=='notification_workflow_ci')throw Error('Disposable notification_workflow_ci required');
function sql(statement){const r=spawnSync('psql',['-X','-v','ON_ERROR_STOP=1','-At'],{input:statement,encoding:'utf8'});if(r.status!==0)throw Error(r.stderr);return r.stdout.trim();}
sql("ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'admin';INSERT INTO public.profiles(id,is_active,role) VALUES('22222222-2222-4222-8222-222222222222',true,'admin');");
for(const table of ['uniform_supply_orders','uniform_delivery_issues','uniform_delivery_bills'])sql(`GRANT SELECT,UPDATE ON public.${table} TO authenticated,anon;CREATE POLICY legacy_access ON public.${table} FOR ALL TO authenticated USING(true) WITH CHECK(true);`);
sql(fs.readFileSync('supabase/migrations/20261023161105_notification_source_access_guard.sql','utf8'));
const own="SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);SET ROLE authenticated;";
const other="SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);SET ROLE authenticated;";
assert.equal(sql(own+'SELECT public.my_role();').split('\n').at(-1),'admin');
assert.equal(sql(other+'SELECT public.my_role();').split('\n').at(-1),'none');
for(const table of ['uniform_supply_orders','uniform_delivery_issues','uniform_delivery_bills']){
 assert.equal(sql(own+'SELECT count(*) FROM public.'+table+';').split('\n').at(-1),'1');
 assert.equal(sql(other+'SELECT count(*) FROM public.'+table+';').split('\n').at(-1),'0');
 assert.equal(sql('SET ROLE anon;SELECT count(*) FROM public.'+table+';').split('\n').at(-1),'0');
}
console.log('PASS real PostgreSQL: approved source access retained; unapproved active admin and anon denied');
