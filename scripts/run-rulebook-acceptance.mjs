// Executable evidence for all 69 AT IDs. Synthetic assertions never certify
// physical device display, provider delivery, or elapsed pilot time.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
const catalogue=JSON.parse(fs.readFileSync('docs/notifications/rulebook-acceptance-catalogue.json','utf8'));
if(catalogue.scenarios.length!==69||new Set(catalogue.scenarios.map(x=>x.id)).size!==69)throw Error('Expected 69 unique ATs');
const r=spawnSync(process.execPath,['--test','--test-reporter=tap','tests/rulebook-acceptance.test.mjs','tests/notification-source-security.test.mjs','tests/notification-operations.test.mjs','tests/notification-inbox-ux.test.cjs','tests/notification-engine-ui.test.cjs'],{encoding:'utf8',maxBuffer:8*1024*1024});
const fingerprint=crypto.createHash('sha256');
for(const file of ['tests/rulebook-acceptance.test.mjs','tests/notification-workflow-fixture.mjs','tests/notification-integrity-fixture.mjs','todo-compact.css','notification-engine-ui.js','notification-model.js','notification-ui.js','tests/notification-source-security.test.mjs','tests/notification-operations.test.mjs','tests/notification-operations-fixture.mjs','tests/fixtures/notification-operations-live-2026-10-23.sql','tests/notification-inbox-ux.test.cjs','tests/notification-engine-ui.test.cjs','sw.js',...fs.readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')).sort().map(x=>'supabase/migrations/'+x)])fingerprint.update(file+'\0').update(fs.readFileSync(file));
const scenarios=catalogue.scenarios.map(s=>{
 const line=(r.stdout||'').split('\n').find(x=>new RegExp('^(?:not )?ok \\d+ - '+s.id+' automated scope(?: |$)').test(x));
 const result=!line?'MISSING':line.startsWith('not ok')?'FAIL':line.includes('# SKIP')?'NOT_RUN':'PASS';
 return {...s,automation_result:result};
});
const result={checked_at:new Date().toISOString(),environment:'isolated synthetic PGlite and sender mock; external evidence separately referenced',source_fingerprint:fingerprint.digest('hex'),supporting_suites_pass:r.status===0,counts:{total:69,automation_pass:scenarios.filter(x=>x.automation_result==='PASS').length,automation_fail:scenarios.filter(x=>['FAIL','MISSING'].includes(x.automation_result)).length,automation_not_run:scenarios.filter(x=>x.automation_result==='NOT_RUN').length,synthetic_pass:scenarios.filter(x=>x.acceptance_status==='PASS_SYNTHETIC').length,partial:scenarios.filter(x=>x.acceptance_status==='PARTIAL').length,blocked:scenarios.filter(x=>x.acceptance_status==='BLOCKED').length},scenarios};
fs.mkdirSync('artifacts/rulebook-acceptance',{recursive:true});
fs.writeFileSync('artifacts/rulebook-acceptance/results.json',JSON.stringify(result,null,2)+'\n');
fs.writeFileSync('artifacts/rulebook-acceptance/test-output.tap',(r.stdout||'')+(r.stderr||''));
console.log(JSON.stringify(result.counts,null,2));
if(r.status!==0||result.counts.automation_fail){console.error((r.stdout||'')+(r.stderr||''));process.exitCode=1;}
