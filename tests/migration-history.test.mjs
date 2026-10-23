import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
test('every captured applied Supabase version has its original SQL under the same version',()=>{
 const manifest=JSON.parse(fs.readFileSync('docs/notifications/migration-history-manifest.json','utf8'));
 const names=fs.readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql'));
 assert.equal(new Set(names.map(x=>x.split('_')[0])).size,names.length,'duplicate version');
 for(const m of manifest.migrations){
  const file='supabase/migrations/'+m.version+'_'+m.name+'.sql';
  assert(fs.existsSync(file),'Missing applied migration '+m.version);
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),m.sha256,'Applied SQL changed: '+file);
 }
 const known=new Set(manifest.migrations.map(x=>x.version)),latest=[...known].sort().at(-1);
 for(const name of names)assert(known.has(name.split('_')[0])||name.split('_')[0]>latest,'Untracked historical migration would replay: '+name);
});
test('executable migration references survive historical filename reconciliation',()=>{
 for(const dir of ['tests','scripts','.github/workflows'])for(const file of fs.readdirSync(dir)){
  if(!/\.(?:mjs|cjs|js|yml|py)$/.test(file))continue;
  const text=fs.readFileSync(dir+'/'+file,'utf8');
  for(const match of text.matchAll(/supabase\/migrations\/[0-9]{14}_[a-z0-9_]+\.sql/g))assert(fs.existsSync(match[0]),dir+'/'+file+' references missing '+match[0]);
 }
});
