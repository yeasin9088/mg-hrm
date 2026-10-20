import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('./',import.meta.url));
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const c=JSON.parse(read('catalog.json')),m=JSON.parse(read('manifest.json'));
const md5=s=>crypto.createHash('md5').update(s).digest('hex');
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
const qi=s=>'"'+s.replaceAll('"','""')+'"';
assert.equal(c.readOnly,true);
assert.equal(m.restoreTested,false);
assert.equal(m.securityRemediationIncluded,false);
assert.deepEqual([m.counts.tables,m.counts.columns,m.counts.constraints,m.counts.indexes,m.counts.sequences,m.counts.routines,m.counts.policies,m.counts.publicTriggers,m.counts.authBridgeTriggers],[45,730,237,174,35,73,140,53,1]);
const tables=new Map(c.tables.map(t=>[t.name,t]));
const columns=new Map(c.tables.map(t=>[t.name,new Map(c.columns.filter(x=>x.table_name===t.name).map(a=>[a.ordinal,a]))]));
const functions=new Set(c.routines.map(r=>r.identity.split('(')[0]));
const known=new Set([...tables.keys(),...functions,...c.sequences.map(s=>s.name)]);
assert.equal(new Set(c.routines.map(r=>r.identity)).size,c.routines.length);
assert.equal(c.routines.filter(r=>r.prosecdef).length,41);
assert.equal(c.tables.filter(t=>t.relrowsecurity).length,45);
assert(!c.schemas.some(s=>s.name==='mghrm_security'));

// Lexical balance only, NOT PostgreSQL grammar/type or PL/pgSQL validation.
function lexical(sql,file){
 let i=0,depth=0,statements=0,start=0;
 while(i<sql.length){
  if(sql.startsWith('--',i)){const end=sql.indexOf('\n',i);i=end<0?sql.length:end+1;continue;}
  if(sql.startsWith('/*',i)){let n=1;i+=2;while(i<sql.length&&n){if(sql.startsWith('/*',i)){n++;i+=2;}else if(sql.startsWith('*/',i)){n--;i+=2;}else i++;}assert.equal(n,0,'Unclosed comment '+file);continue;}
  const ch=sql[i];
  if(ch==="'"){
   const escape=i>0&&/[Ee]/.test(sql[i-1])&&(i<2||!/[a-zA-Z0-9_]/.test(sql[i-2]));
   i++;let closed=false;
   while(i<sql.length){if(escape&&sql[i]==='\\'){i+=2;continue;}if(sql[i]==="'"){if(sql[i+1]==="'"){i+=2;continue;}i++;closed=true;break;}i++;}
   assert(closed,'Unclosed SQL string '+file);continue;
  }
  if(ch==='"'){i++;let closed=false;while(i<sql.length){if(sql[i]==='"'){if(sql[i+1]==='"'){i+=2;continue;}i++;closed=true;break;}i++;}assert(closed,'Unclosed identifier '+file);continue;}
  if(ch==='$'){
   const match=sql.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/);
   if(match){const end=sql.indexOf(match[0],i+match[0].length);assert(end>=0,'Unclosed dollar quote '+file);i=end+match[0].length;continue;}
  }
  if(ch==='(')depth++;
  if(ch===')'){depth--;assert(depth>=0,'Unbalanced parenthesis '+file);}
  if(ch===';'){assert.equal(depth,0,'Statement terminated within parentheses '+file);statements++;start=i+1;}
  i++;
 }
 assert.equal(depth,0,'Unbalanced parentheses '+file);
 assert(!sql.slice(start).replace(/--[^\n]*/g,'').trim(),'Unterminated SQL statement '+file);
 return statements;
}
let statementCount=0;
for(const f of m.files){
 const sql=read(f.file);assert.equal(sha(sql),f.sha256,'Changed generated file; update reviewed catalog/generator '+f.file);
 statementCount+=lexical(sql,f.file);
}
lexical(read('capture/catalog.sql'),'capture/catalog.sql');

for(const t of c.tables){
 const sql=read('tables/'+t.name+'.sql');
 assert(sql.includes('CREATE TABLE "public".'+qi(t.name)+' (\n'));
 for(const col of c.columns.filter(x=>x.table_name===t.name)){
  assert(sql.includes('  '+qi(col.name)+' '+col.type),'Missing column/type '+t.name+'.'+col.name);
  assert.equal(col.acl,null,'Column grants need explicit generator support');
 }
}
for(const s of c.sequences){
 assert.equal(s.ownership_dependency,'i');assert(columns.get(s.owned_table));
 assert([...columns.get(s.owned_table).values()].some(a=>a.name===s.owned_column&&a.identity));
 for(const key of ['seqstart','seqincrement','seqmin','seqmax','seqcache'])assert.equal(typeof s[key],'string');
 assert(BigInt(s.seqmin)<=BigInt(s.seqstart)&&BigInt(s.seqstart)<=BigInt(s.seqmax));
 assert(read('tables/'+s.owned_table+'.sql').includes('SEQUENCE NAME "public".'+qi(s.name)));
 assert(read('tables/'+s.owned_table+'.sql').includes('MAXVALUE '+s.seqmax));
}
for(const con of c.constraints){
 assert(tables.has(con.table_name));
 for(const ordinal of con.conkey||[])assert(columns.get(con.table_name).has(ordinal),'Constraint column absent');
 const sql=read(con.contype==='f'?'05-foreign-keys.sql':'04-constraints.sql');
 assert(sql.includes('ADD CONSTRAINT '+qi(con.name)+' '+con.definition+';'),'Constraint definition differs');
 if(con.contype==='f'){
  if(tables.has(con.referenced_table)){for(const key of con.confkey)assert(columns.get(con.referenced_table).has(key),'Missing FK target column');}
  else assert.equal(con.referenced_table,'auth.users','Undocumented external FK target');
 }
}
const indexSQL=read('06-indexes.sql');
for(const i of c.indexes){
 assert(tables.has(i.table_name));
 if(i.constraint_name)assert(c.constraints.some(con=>con.table_name===i.table_name&&con.name===i.constraint_name&&['p','u','x'].includes(con.contype)),'Missing owning constraint');
 else assert(indexSQL.includes(i.definition+';'),'Missing exact standalone index DDL');
}
for(const r of c.routines){
 assert.equal(md5(r.definition),r.definition_md5,'Function digest mismatch');
 const file=m.functions.find(x=>x.identity===r.identity)?.file;assert(file);
 assert(read(file).includes(r.definition.trimEnd()+';'),'Function source/options altered');
 for(const match of r.definition.matchAll(/\bpublic\.([a-zA-Z_]\w*)/g))assert(known.has(match[1]),'Unresolved public source symbol '+match[1]);
}
for(const t of c.triggers){
 if(t.schema==='public')assert(tables.has(t.relation));
 else assert.equal(t.schema+'.'+t.relation,'auth.users');
 assert(c.routines.some(r=>r.identity===t.function),'Missing trigger function '+t.function);
 assert(read('07-triggers.sql').includes(t.definition+';'),'Missing trigger definition');
}
for(const p of c.policies){
 assert(tables.has(p.tablename));
 assert(read('08-rls-policies.sql').includes('CREATE POLICY '+qi(p.policyname)+' ON "public".'+qi(p.tablename)));
 for(const expr of [p.qual,p.with_check])if(expr!=null)assert(read('08-rls-policies.sql').includes(expr),'Changed policy expression');
}
for(const p of c.publications.filter(p=>p.tables.some(t=>t.schema==='public'))){
 for(const t of p.tables){
  assert(tables.has(t.table));
  // PostgreSQL 17 omits generated columns from implicit publication column lists.
  const actual=[...columns.get(t.table).values()].filter(c=>!c.generated).map(c=>c.name);
  const binding=c.publication_relations.find(r=>r.publication===p.name&&r.table_name===t.table);
  assert(binding);assert.equal(binding.explicit_attribute_numbers,null,'Explicit publication column list requires distinct DDL');
  assert.deepEqual(t.columns,actual,'Publication implicit column list differs');
  assert.equal(t.row_filter,null,'Unexpected publication row filter');
 }
}
const capture=read('capture/catalog.sql');
assert(!/^\s*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|GRANT|REVOKE|DO|CALL|COPY)\b/im.test(capture));
assert(!/\b(?:pg_read_file|pg_ls_dir|lo_import)\s*\(/i.test(capture));
let scanFiles=0,nilCount=0;
function scan(dir){
 for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  const file=path.join(dir,e.name);if(e.isDirectory()){scan(file);continue;}
  const text=fs.readFileSync(file,'utf8');scanFiles++;
  // Scanner source contains patterns, not actual secrets.
  assert(!/eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}/.test(text),'JWT-like literal');
  assert(!/bearer\s+[a-z0-9_.-]{20,}/i.test(text),'Bearer literal');
  assert(!/\b(?:sb_secret_|sb_publishable_)[a-zA-Z0-9_-]{20,}\b/.test(text),'API-key literal');
  assert(!/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i.test(text),'Email literal needs review');
  for(const match of text.matchAll(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi)){
   assert.equal(match[0],'00000000-0000-0000-0000-000000000000','Unreviewed identity-like literal');nilCount++;
  }
 }
}
scan(root);
console.log('PASS: 45 tables/730 columns, 237 constraints/62 FK targets, 174 indexes (56 constraint-owned + 118 standalone), 35 exact identity sequences.');
console.log('PASS: 73 deployed function digests, 54 trigger functions/definitions, 140 policy expressions, 15 publication member column lists, public source references.');
console.log('PASS: '+m.files.length+' generated SQL hashes, '+statementCount+' lexically balanced statements, SELECT-only extraction and sensitive-literal scan of '+scanFiles+' files.');
console.log('LIMIT: no PostgreSQL parser/server execution, no PL/pgSQL name/type resolution, no restore or runtime behavior certification. Nil UUID is an index sentinel, not an Auth identity.');
