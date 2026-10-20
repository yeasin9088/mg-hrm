import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=fileURLToPath(new URL('./',import.meta.url));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'catalog.json'),'utf8'));
const q=s=>"'"+String(s).replaceAll("'","''")+"'";
const qi=s=>'"'+String(s).replaceAll('"','""')+'"';
const obj=(schema,name)=>qi(schema)+'.'+qi(name);
const header='-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.\n-- Source: read-only PostgreSQL '+catalog.postgresVersion+' catalogs, '+catalog.capturedOn+' ('+catalog.timezone+').\nSET standard_conforming_strings = on;\nSET search_path = pg_catalog, public;\n\n';
const outputs=new Map();
function emit(file,body){outputs.set(file,header+body.trimEnd()+'\n');}
function assert(ok,message){if(!ok)throw Error(message);}
function comment(kind,identity,value){return value==null?'':'COMMENT ON '+kind+' '+identity+' IS '+q(value)+';\n';}
assert(catalog.tables.every(t=>t.relkind==='r'&&t.relpersistence==='p'&&!t.reloptions&&!t.tablespace&&!t.relispartition),'Unsupported table properties require explicit generation');
assert(catalog.types.length===0&&catalog.additional_standalone_types.length===0&&catalog.inheritance.length===0,'Unexpected standalone type/inheritance');
assert(catalog.columns.every(c=>!c.options&&!c.acl&&!c.compression&&(c.statistics_target==null||c.statistics_target===-1)&&c.storage===c.type_storage),'Unhandled nondefault column properties');
assert(catalog.indexes.every(i=>i.indisvalid&&i.indisready&&!i.indisclustered&&!i.indisreplident),'Nonstandard index state needs explicit generation');

emit('00-schemas.sql',catalog.schemas.map(s=>'CREATE SCHEMA '+qi(s.name)+';\nALTER SCHEMA '+qi(s.name)+' OWNER TO '+qi(s.owner)+';\n'+comment('SCHEMA',qi(s.name),s.comment)).join('\n')+
'\n-- public already exists in Supabase. This declaration documents ownership;\n-- do not execute it blindly against an existing project.\n');
emit('01-types.sql','-- No application-defined enum, domain, range, multirange, standalone\n-- composite or base types were found in public. Table row types and their arrays\n-- are created by PostgreSQL when the tables are defined. Built-in types and\n-- extension-managed types are external prerequisites; see platform/.\n');

function sequenceOptions(s){return 'START WITH '+s.seqstart+' INCREMENT BY '+s.seqincrement+' MINVALUE '+s.seqmin+' MAXVALUE '+s.seqmax+' CACHE '+s.seqcache+' '+(s.seqcycle?'CYCLE':'NO CYCLE');}
let sequenceSQL='';
for(const s of catalog.sequences){
 assert([s.seqstart,s.seqincrement,s.seqmin,s.seqmax,s.seqcache].every(v=>typeof v==='string'&&/^-?\d+$/.test(v)),'Sequence int8 values must remain exact decimal strings');
 if(s.ownership_dependency!=='i')sequenceSQL+='CREATE SEQUENCE '+obj('public',s.name)+' AS '+s.type+' '+sequenceOptions(s)+';\n';
 else sequenceSQL+='-- '+obj('public',s.name)+' ('+s.type+'): created inline by identity '+obj('public',s.owned_table)+'.'+qi(s.owned_column)+'; '+sequenceOptions(s)+'.\n';
}
emit('02-sequences.sql',sequenceSQL);

for(const t of catalog.tables){
 const identity=obj('public',t.name);
 const cols=catalog.columns.filter(c=>c.table_name===t.name);
 const definitions=cols.map(c=>{
  let line='  '+qi(c.name)+' '+c.type;
  if(c.collation)line+=' COLLATE '+c.collation;
  if(c.identity){
   const sequence=catalog.sequences.find(s=>s.owned_table===t.name&&s.owned_column===c.name&&s.ownership_dependency==='i');
   assert(sequence,'Missing identity sequence for '+t.name+'.'+c.name);
   line+=' GENERATED '+(c.identity==='a'?'ALWAYS':'BY DEFAULT')+' AS IDENTITY (SEQUENCE NAME '+obj('public',sequence.name)+' '+sequenceOptions(sequence)+')';
  }else if(c.generated){assert(c.generated==='s','Unexpected generated column');line+=' GENERATED ALWAYS AS ('+c.default_expression+') STORED';}
  else if(c.default_expression!=null)line+=' DEFAULT '+c.default_expression;
  if(c.not_null)line+=' NOT NULL';
  return line;
 });
 let body='CREATE TABLE '+identity+' (\n'+definitions.join(',\n')+'\n) USING '+qi(t.access_method)+';\n';
 body+='ALTER TABLE '+identity+' OWNER TO '+qi(t.owner)+';\n';
 body+=comment('TABLE',identity,t.comment);
 for(const c of cols)body+=comment('COLUMN',identity+'.'+qi(c.name),c.comment);
 if(t.relreplident!=='d'){
  assert(['n','f'].includes(t.relreplident),'Replica identity index not yet handled');
  body+='ALTER TABLE '+identity+' REPLICA IDENTITY '+(t.relreplident==='f'?'FULL':'NOTHING')+';\n';
 }
 emit('tables/'+t.name+'.sql',body);
}
emit('03-sequence-ownership.sql',catalog.sequences.map(s=>{
 let body='ALTER SEQUENCE '+obj('public',s.name)+' OWNER TO '+qi(s.owner)+';\n';
 if(s.ownership_dependency==='a')body+='ALTER SEQUENCE '+obj('public',s.name)+' OWNED BY '+obj('public',s.owned_table)+'.'+qi(s.owned_column)+';\n';
 return body+comment('SEQUENCE',obj('public',s.name),s.comment);
}).join('\n'));

function constraintDDL(c){
 assert(c.conislocal&&c.coninhcount===0,'Inherited constraint requires explicit handling');
 return 'ALTER TABLE ONLY '+obj('public',c.table_name)+' ADD CONSTRAINT '+qi(c.name)+' '+c.definition+';\n'+comment('CONSTRAINT',qi(c.name)+' ON '+obj('public',c.table_name),c.comment);
}
emit('04-constraints.sql',catalog.constraints.filter(c=>c.contype!=='f').map(constraintDDL).join('\n'));
emit('05-foreign-keys.sql',catalog.constraints.filter(c=>c.contype==='f').map(constraintDDL).join('\n'));

let indexes='';
for(const i of catalog.indexes){
 if(i.constraint_name){
  assert(!i.reloptions&&!i.tablespace,'Constraint-backed index options need explicit reconstruction');
  indexes+='-- '+obj('public',i.name)+' is created by constraint '+qi(i.constraint_name)+' on '+obj('public',i.table_name)+'.\n';
 }else indexes+=i.definition+';\n';
 indexes+=comment('INDEX',obj('public',i.name),i.comment);
}
emit('06-indexes.sql',indexes);

const functionFiles=new Map([
 ['functions/hr-workflows.sql',[]],['functions/uniform.sql',[]],
 ['functions/notifications-user.sql',[]],['functions/notifications-service.sql',[]],
 ['functions/triggers-and-helpers.sql',[]]
]);
const userNotification=/^(notification_(complete_if_resolved|dismiss|mark_all_read|mark_read|open|snooze)|push_subscription_(list_devices|register|revoke|update_device))\(/;
const entries=[];
for(const r of catalog.routines){
 assert(crypto.createHash('md5').update(r.definition).digest('hex')===r.definition_md5,'Unverified/stale function source '+r.identity);
 const file=r.result==='trigger'||['my_role()','mghrm_is_employee_inactive(text)'].includes(r.identity)?'functions/triggers-and-helpers.sql':
  userNotification.test(r.identity)?'functions/notifications-user.sql':
  r.identity.startsWith('notification_')?'functions/notifications-service.sql':
  /^(next_uniform_order_number|uniform_order_accounting|save_uniform_delivery)\(/.test(r.identity)?'functions/uniform.sql':'functions/hr-workflows.sql';
 const kind=r.prokind==='p'?'PROCEDURE':'FUNCTION';
 const identity='public.'+r.identity;
 functionFiles.get(file).push('-- '+identity+' | '+(r.prosecdef?'SECURITY DEFINER':'SECURITY INVOKER')+'\n'+r.definition.trimEnd()+';\nALTER '+kind+' '+identity+' OWNER TO '+qi(r.owner)+';\n'+comment(kind,identity,r.comment));
 entries.push({identity:r.identity,file,definitionMd5:r.definition_md5,security:r.prosecdef?'definer':'invoker',language:r.language});
}
for(const [file,definitions]of functionFiles)emit(file,definitions.join('\n'));

emit('07-triggers.sql',catalog.triggers.map(t=>{
 const identity=obj(t.schema,t.relation);
 const state={O:'ENABLE',D:'DISABLE',R:'ENABLE REPLICA',A:'ENABLE ALWAYS'}[t.tgenabled];
 assert(state,'Unknown trigger enabled state');
 return t.definition+';\nALTER TABLE '+identity+' '+state+' TRIGGER '+qi(t.name)+';\n'+comment('TRIGGER',qi(t.name)+' ON '+identity,t.comment);
}).join('\n'));

let policies='';
for(const t of catalog.tables)policies+='ALTER TABLE '+obj('public',t.name)+' '+(t.relrowsecurity?'ENABLE':'DISABLE')+' ROW LEVEL SECURITY;\nALTER TABLE '+obj('public',t.name)+' '+(t.relforcerowsecurity?'FORCE':'NO FORCE')+' ROW LEVEL SECURITY;\n';
for(const p of catalog.policies){
 const roles=p.roles.slice(1,-1).split(',').map(r=>r==='public'?'PUBLIC':qi(r)).join(', ');
 policies+='\nCREATE POLICY '+qi(p.policyname)+' ON '+obj(p.schemaname,p.tablename)+' AS '+p.permissive+' FOR '+p.cmd+' TO '+roles+
  (p.qual==null?'':' USING ('+p.qual+')')+(p.with_check==null?'':' WITH CHECK ('+p.with_check+')')+';\n';
}
emit('08-rls-policies.sql',policies);

const privilegeNames={r:'SELECT',a:'INSERT',w:'UPDATE',d:'DELETE',D:'TRUNCATE',x:'REFERENCES',t:'TRIGGER',m:'MAINTAIN',X:'EXECUTE',U:'USAGE',C:'CREATE'};
function parseACL(raw){
 assert(raw!=null,'NULL/default ACL requires explicit derivation');
 const entries=raw.slice(1,-1).split(',').filter(Boolean).map(s=>{
  const match=s.match(/^([^=]*)=([^/]*)\/([^/]+)$/);assert(match,'Complex quoted ACL requires explicit parsing');
  const [,grantee,codes,grantor]=match,privileges=[];
  for(let i=0;i<codes.length;i++){
   const name=privilegeNames[codes[i]];assert(name,'Unknown privilege letter');
   const grantOption=codes[i+1]==='*';if(grantOption)i++;
   privileges.push({name,grantOption});
  }
  return {grantee:grantee||'PUBLIC',grantor,privileges};
 });
 return entries;
}
function role(r){return r==='PUBLIC'?'PUBLIC':qi(r);}
function aclDDL(kind,identity,raw,owner){
 const acl=parseACL(raw),roles=[...new Set(['PUBLIC',owner,...acl.map(a=>a.grantee)])].sort();
 let body='-- Original ACL: '+raw+'\nSET ROLE '+qi(owner)+';\nREVOKE ALL PRIVILEGES ON '+kind+' '+identity+' FROM '+roles.map(role).join(', ')+';\nRESET ROLE;\n';
 for(const a of acl)for(const grantOption of [false,true]){
  const privileges=a.privileges.filter(p=>p.grantOption===grantOption).map(p=>p.name);
  if(privileges.length)body+='SET ROLE '+qi(a.grantor)+';\nGRANT '+privileges.join(', ')+' ON '+kind+' '+identity+' TO '+role(a.grantee)+(grantOption?' WITH GRANT OPTION':'')+';\nRESET ROLE;\n';
 }
 return body;
}
let grants='-- Faithful CURRENT grants, including broad legacy grants. No remediation.\n-- SET ROLE preserves recorded grantors; managed role membership is a prerequisite.\n\n';
for(const s of catalog.schemas)grants+=aclDDL('SCHEMA',qi(s.name),s.acl,s.owner)+'\n';
for(const t of catalog.tables)grants+=aclDDL('TABLE',obj('public',t.name),t.acl,t.owner)+'\n';
for(const s of catalog.sequences)grants+=aclDDL('SEQUENCE',obj('public',s.name),s.acl,s.owner)+'\n';
for(const r of catalog.routines)grants+=aclDDL(r.prokind==='p'?'PROCEDURE':'FUNCTION','public.'+r.identity,r.proacl,r.owner)+'\n';
emit('09-privileges.sql',grants);

let defaults='';
const defaultKind={r:'TABLES',S:'SEQUENCES',f:'FUNCTIONS',T:'TYPES',n:'SCHEMAS'};
for(const d of catalog.default_privileges){
 const kind=defaultKind[d.object_type];assert(kind,'Unexpected default privilege kind');
 const prefix='ALTER DEFAULT PRIVILEGES FOR ROLE '+qi(d.owner)+(d.schema?' IN SCHEMA '+qi(d.schema):'');
 const acl=parseACL(d.acl);assert(acl.every(a=>a.grantor===d.owner),'Unexpected default grantor');
 const roles=[...new Set(['PUBLIC',d.owner,...acl.map(a=>a.grantee)])].sort();
 defaults+='-- Original default ACL: '+d.acl+'\nSET ROLE '+qi(d.owner)+';\n'+prefix+' REVOKE ALL PRIVILEGES ON '+kind+' FROM '+roles.map(role).join(', ')+';\n';
 for(const a of acl)for(const grantOption of [false,true]){
  const privileges=a.privileges.filter(p=>p.grantOption===grantOption).map(p=>p.name);
  if(privileges.length)defaults+=prefix+' GRANT '+privileges.join(', ')+' ON '+kind+' TO '+role(a.grantee)+(grantOption?' WITH GRANT OPTION':'')+';\n';
 }
 defaults+='RESET ROLE;\n\n';
}
emit('10-default-privileges.sql',defaults);

let publications='';
for(const p of catalog.publications.filter(p=>p.tables.some(t=>t.schema==='public'))){
 assert(!p.puballtables,'All-table publication requires explicit handling');
 publications+='CREATE PUBLICATION '+qi(p.name)+" WITH (publish = "+q([p.pubinsert?'insert':null,p.pubupdate?'update':null,p.pubdelete?'delete':null,p.pubtruncate?'truncate':null].filter(Boolean).join(', '))+', publish_via_partition_root = '+p.pubviaroot+');\nALTER PUBLICATION '+qi(p.name)+' OWNER TO '+qi(p.owner)+';\n';
 for(const t of p.tables){
  assert(t.schema==='public','Mixed publication needs explicit platform handling');
  publications+='ALTER PUBLICATION '+qi(p.name)+' ADD TABLE '+obj(t.schema,t.table)+(t.row_filter?' WHERE ('+t.row_filter+')':'')+';\n';
 }
}
emit('11-publications.sql',publications+'\n-- Managed Realtime message partitions/publication are inventoried in catalog.json,\n-- not recreated. The application publication currently has all columns/no filters.\n');

emit('platform/extensions.sql','-- REFERENCE ONLY: installed extension names/versions/schemas. Managed bootstrap\n-- and server packages are prerequisites, not reproduced by this application baseline.\n'+catalog.extensions.map(e=>'-- Installed owner: '+e.owner+'; relocatable='+e.relocatable+'\nCREATE EXTENSION '+qi(e.name)+' WITH SCHEMA '+qi(e.schema)+' VERSION '+q(e.version)+';\n').join('\n'));
emit('platform/auth-functions.sql','-- REFERENCE ONLY: Supabase-managed helpers used by application functions/policies.\n-- Do not overwrite managed Auth functions using this documentation baseline.\n'+catalog.external_interfaces.filter(x=>x.kind==='function').map(r=>r.definition.trimEnd().replace(/\n  select (?=\n)/g,'\n  select')+';\n-- Owner '+r.owner+'; original ACL '+r.acl+'\n').join('\n'));

for(const [file,text]of outputs){
 // Catalog comments/defaults/bodies have already been reviewed. Recheck generated output.
 assert(!/eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}|bearer\s+[a-z0-9_.-]{20,}/i.test(text),'Possible credential literal');
 assert(![...text.matchAll(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi)].some(m=>m[0]!=='00000000-0000-0000-0000-000000000000'),'Unreviewed UUID literal');
 const full=path.join(root,file);fs.mkdirSync(path.dirname(full),{recursive:true});fs.writeFileSync(full,text,'utf8');
}
const manifest={
 capturedOn:catalog.capturedOn,projectRef:catalog.projectRef,postgresVersion:catalog.postgresVersion,scope:catalog.scope,
 dataIncluded:false,restoreTested:false,securityRemediationIncluded:false,
 counts:{schemas:catalog.schemas.length,tables:catalog.tables.length,columns:catalog.columns.length,
 constraints:catalog.constraints.length,primaryKeys:catalog.constraints.filter(c=>c.contype==='p').length,
 foreignKeys:catalog.constraints.filter(c=>c.contype==='f').length,uniqueConstraints:catalog.constraints.filter(c=>c.contype==='u').length,
 checks:catalog.constraints.filter(c=>c.contype==='c').length,indexes:catalog.indexes.length,
 constraintBackedIndexes:catalog.indexes.filter(i=>i.constraint_name).length,
 standaloneIndexes:catalog.indexes.filter(i=>!i.constraint_name).length,sequences:catalog.sequences.length,
 routines:catalog.routines.length,securityDefiners:catalog.routines.filter(r=>r.prosecdef).length,policies:catalog.policies.length,
 publicTriggers:catalog.triggers.filter(t=>t.schema==='public').length,authBridgeTriggers:catalog.triggers.filter(t=>t.schema==='auth').length,
 extensions:catalog.extensions.length,applicationPublicationTables:catalog.publications.find(p=>p.name==='supabase_realtime').tables.length,dependencies:catalog.dependencies.length},
 tables:catalog.tables.map(t=>({schema:'public',name:t.name,file:'tables/'+t.name+'.sql',columns:catalog.columns.filter(c=>c.table_name===t.name).length})),
 functions:entries,
 files:[...outputs].map(([file,text])=>({file,sha256:crypto.createHash('sha256').update(text).digest('hex')}))
};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Generated '+outputs.size+' SQL reference files and manifest from reviewed catalog metadata; no database/network access.');
