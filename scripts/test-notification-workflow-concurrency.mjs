import assert from 'node:assert/strict';
import {spawn,spawnSync} from 'node:child_process';
import {setup,operator} from '../tests/notification-workflow-fixture.mjs';
if(process.env.PGDATABASE!=='notification_workflow_ci')throw Error('Dedicated disposable notification_workflow_ci required');
function sql(statement){const r=spawnSync('psql',['-X','-v','ON_ERROR_STOP=1','-At'],{input:statement,encoding:'utf8'});if(r.status!==0)throw Error(r.stderr);return r.stdout.trim();}
await setup({exec:async statement=>sql(statement)});
const auth=`SELECT set_config('request.jwt.claim.sub','${operator}',false);`;
const version=sql("select row_version from public.swa_work_items where source_module='todo' and source_record_id='200'");
function run(statement,onData){return new Promise((resolve,reject)=>{const p=spawn('psql',['-X','-v','ON_ERROR_STOP=1','-At']);let out='',err='';p.stdout.on('data',b=>{out+=b;onData?.(out);});p.stderr.on('data',b=>err+=b);p.on('error',reject);p.on('exit',code=>resolve({code,out,err}));p.stdin.end(statement);});}
let ready;const locked=new Promise(r=>ready=r);
const id=sql("select id from public.swa_work_items where source_record_id='200' and source_module='todo'");
const first=run(`BEGIN;${auth} SELECT public.swa_act('${id}',${version},'informed','phone');SELECT 'WORK_LOCK_HELD';SELECT pg_sleep(2);COMMIT;`,out=>{if(out.includes('WORK_LOCK_HELD'))ready();});
await locked;const start=Date.now();const second=run(`${auth} SELECT public.swa_act('${id}',${version},'decision','approved');`);
const [a,b]=await Promise.all([first,second]);assert.equal(a.code,0);assert.notEqual(b.code,0);assert.match(b.err,/Conflict/);assert(Date.now()-start>=1000);
assert.equal(sql("select manager_decision from public.swa_work_items where id='"+id+"'"),'pending');
const key='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const capture=`${auth} SELECT public.notification_work_capture('${key}','{"category":"permission","subject":"One logical capture"}');`;
const captures=await Promise.all([run(capture),run(capture)]);assert(captures.every(x=>x.code===0));assert.equal(sql("select count(*) from public.todos where work_capture_key='"+key+"'"),'1');
console.log('PASS real PostgreSQL: concurrent manager edits reject stale write; simultaneous retried capture creates one task');
