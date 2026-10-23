// Disposable PostgreSQL only. PGDATABASE must be a dedicated CI database.
import assert from 'node:assert/strict';
import {spawn,spawnSync} from 'node:child_process';
import {setup} from '../tests/notification-integrity-fixture.mjs';
if(process.env.PGDATABASE!=='notification_integrity_ci')throw Error('Refusing to run outside dedicated notification_integrity_ci');
function sql(text){const r=spawnSync('psql',['-X','-v','ON_ERROR_STOP=1','-At'],{input:text,encoding:'utf8'});if(r.status!==0)throw Error(r.stderr);return r.stdout;}
await setup({exec:async statement=>sql(statement)});
const recipient='11111111-1111-4111-8111-111111111111';
const second='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
sql(`INSERT INTO public.notifications(id,recipient_user_id,category,priority,status,entity_type,entity_id)
 VALUES('${second}','${recipient}','ToDo','Normal','Ready','todo','101');`);
function session(statement,onData){return new Promise((resolve,reject)=>{
 const child=spawn('psql',['-X','-v','ON_ERROR_STOP=1','-At']);let out='',error='';
 child.stdout.on('data',data=>{out+=data;onData?.(out)});child.stderr.on('data',data=>error+=data);
 child.on('error',reject);child.on('exit',code=>code===0?resolve(out):reject(Error(error)));child.stdin.end(statement);
});}
let ready;const locked=new Promise(resolve=>ready=resolve);
const first=session(`BEGIN; SELECT notification_private.reserve_push('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','2026-10-23T04:00:00Z');
 SELECT 'QUOTA_LOCK_HELD';SELECT pg_sleep(2);COMMIT;`,out=>{if(out.includes('QUOTA_LOCK_HELD'))ready();});
await locked;const started=Date.now();
const competitor=session(`SELECT notification_private.reserve_push('${second}','2026-10-23T04:00:00Z');`);
const [a,b]=await Promise.all([first,competitor]);
assert.match(a,/"allowed": true/);assert.match(b,/"allowed": false/);
assert(Date.now()-started>=1000,'competing transaction must wait for the first quota lock');
assert.equal(sql("select count(*) from notification_private.push_occurrences where state='Reserved';").trim(),'1');
console.log('PASS real PostgreSQL: concurrent sessions serialize and only one P3 occurrence is admitted');
