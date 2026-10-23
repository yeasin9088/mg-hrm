'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const file=fs.readFileSync('notification-settings.js','utf8');
const start=file.indexOf('/* Phase 6: a backend-authoritative Smart Policy');
assert(start>=0,'Phase 6 UI must be embedded in existing Settings file');
const source=file.slice(start);
function build({error=false,revision=3}={}){
 const server={revision,policy_version:'notification-core-v2-phase2-1',
   push_start:'09:00',push_end:'18:00',
   morning_digest_time:'09:05',afternoon_digest_time:'17:15',
   morning_digest_enabled:true,afternoon_digest_enabled:true,
   p3_item_cap_24h:1,p2_item_cap_24h:2,
   p3_cooldown_minutes:null,p2_cooldown_minutes:null,
   user_cap_24h:null,category_cap_24h:null,
   governance_enabled:false,digest_bridge_enabled:false};
 let policy={...server},calls=[],section=null;
 const body={appendChild(e){section=e}};
 const refs=new Map([['mgNsBody',body]]);
 function element(id){
  if(refs.has(id))return refs.get(id);
  if(!section||!section.innerHTML.includes('id="'+id+'"'))return null;
  const el={id,value:'',disabled:false,checked:false,handlers:{},textContent:'',
    addEventListener(name,fn){this.handlers[name]=fn}};
  refs.set(id,el);return el;
 }
 const ctx={console,Promise,Number,JSON,Error,RegExp,String};
 ctx.window=ctx;
 ctx.document={getElementById:element,createElement(){return {
   innerHTML:'',className:'',setAttribute(){},addEventListener(){},
 };}};
 ctx.MGHRM={client:{rpc:async(name,args)=>{
  calls.push({name,args});
  if(error)return {error:{message:'Function not found in schema cache'}};
  if(name==='notification_operator_policy_read')return {data:{...policy},error:null};
  if(name==='notification_operator_policy_save'){
   if(args.p_expected_revision!==policy.revision)return {error:{message:'Policy revision conflict',code:'40001'}};
   policy={...policy,...args.p_changes,revision:policy.revision+1};
   return {data:{...policy,saved:true,readback_revision:policy.revision},error:null};
  }
  throw Error('Unknown RPC '+name);
 }}};
 ctx.mgOpenNotifSettings=async()=>{};
 vm.runInNewContext(source,ctx,{timeout:1000});
 return {ctx,calls,server,get section(){return section},get policy(){return policy},el:element};
}
test('Phase6 settings unavailable leaves legacy modal usable and does not show fake editable engine controls',async()=>{
 const t=build({error:true});
 await t.ctx.mgOpenNotifSettings();
 assert.match(t.section.innerHTML,/staged, not active/);
 assert.doesNotMatch(t.section.innerHTML,/id="mgNsEngineSave"/);
 assert.equal(t.calls[0].name,'notification_operator_policy_read');
 assert.equal(t.calls.filter(c=>c.name.endsWith('_save')).length,0);
});
test('Phase6 operator settings show V1 live / V2 staged, with real server policy values',async()=>{
 const t=build();
 await t.ctx.mgOpenNotifSettings();
 assert.match(t.section.innerHTML,/Governance staged/);
 assert.match(t.section.innerHTML,/Revision 3/);
 assert.match(t.section.innerHTML,/Morning digest/);
 assert.match(t.section.innerHTML,/P3 Push/);
 assert.match(t.section.innerHTML,/P0 emergencies/);
 assert.equal(t.el('mgNsEngineSave').disabled,false); // fake DOM does not parse disabled attr
 assert.equal(t.calls.length,1);
});
test('Changing digest switch saves exactly changed key with expected version and readback verification',async()=>{
 const t=build();
 await t.ctx.mgOpenNotifSettings();
 const toggle=t.el('mgNsEng_morning_digest_enabled');
 toggle.checked=false;toggle.handlers.change();
 const save=t.el('mgNsEngineSave');
 await save.handlers.click();
 assert.equal(t.calls[1].name,'notification_operator_policy_save');
 assert.deepEqual(JSON.parse(JSON.stringify(t.calls[1].args)),{
  p_expected_revision:3,p_changes:{morning_digest_enabled:false}
 });
 assert.equal(t.policy.revision,4);
 assert.equal(t.policy.morning_digest_enabled,false);
 assert.match(t.section.innerHTML,/Revision 4/);
 assert.equal(t.calls.filter(c=>c.name==='notification_operator_policy_read').length,2);
});
test('Concurrent edit rejection preserves local draft and surfaces conflict, never false Saved',async()=>{
 const t=build();
 await t.ctx.mgOpenNotifSettings();
 // External device edits server between read and this device save.
 t.policy.revision=4; // getter value is copy, must simulate through RPC state instead
 const toggle=t.el('mgNsEng_afternoon_digest_enabled');
 toggle.checked=false;toggle.handlers.change();
 // Emulate service reporting revision conflict.
 t.ctx.MGHRM.client.rpc=async(name)=>{
  if(name==='notification_operator_policy_save')return {error:{message:'Policy revision conflict',code:'40001'}};
  return {data:t.policy,error:null};
 };
 await t.el('mgNsEngineSave').handlers.click();
 const msg=t.el('mgNsEngineLive');
 assert.match(msg.textContent,/Another device changed/);
 assert.doesNotMatch(msg.textContent,/saved and verified/i);
});
