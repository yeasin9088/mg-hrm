const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
function environment({fail=false}={}){
 let modal='',calls=[],revision=0;const elements=new Map();
 const refs={mgNsBody:{appendChild(e){elements.set(e.id,e)}},mgEngineLeaseMinutes:{value:'30'},mgEngineActionResult:{textContent:''}};
 const ctx={console,Date,Map,Set,Number,String,Error,Promise};ctx.window=ctx;
 ctx.document={getElementById(id){return refs[id]||elements.get(id)},createElement(){return {id:'',innerHTML:'',textContent:'',isConnected:true}}};
 ctx.NOTIFICATIONS=[{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',isBackend:true,entityType:'todo',ref:'101'}];
 const data=()=>({checked_at:new Date().toISOString(),source:{actionable:true,reason:'authoritative_source_current'},
  interaction:{revision},decision:{reason_code:'actionable_verified_policy_candidate'},health:{healthy:true,jobs:{},subscriptions:{active:2}},policy:{},open_source_count:3});
 ctx.MGHRM={client:{rpc:async(name,args)=>{calls.push({name,args});if(fail)return {error:{message:'Network unavailable'}};
  if(name==='notification_operator_diagnostics')return {data:data()};
  if(name==='notification_source_interaction'){assert.equal(args.p_expected_revision,revision);revision++;return {data:{saved:true,revision}};}
  throw Error('Unexpected RPC');}}};
 ctx.mgOpenNotifSettings=async()=>{};ctx.openModal=(title,body)=>{modal=body};
 vm.runInNewContext(fs.readFileSync('notification-engine-ui.js','utf8'),ctx);
 return {ctx,calls,refs,elements,get modal(){return modal}};
}
test('Existing settings shows authenticated health; explicit work ACK saves once and verifies',async()=>{
 const e=environment();await e.ctx.mgOpenNotifSettings();assert.match(e.elements.get('mgEngineHealth').innerHTML,/Open To-Do sources/);
 await e.ctx.mgOpenNotificationDetails(e.ctx.NOTIFICATIONS[0].id);assert.match(e.modal,/Acknowledge work/);
 await e.ctx.mgEngineSourceAction(e.ctx.NOTIFICATIONS[0].id,'ack');
 const writes=e.calls.filter(c=>c.name==='notification_source_interaction');assert.equal(writes.length,1);
 assert.equal(writes[0].args.p_entity_type,'todo');assert.equal(writes[0].args.p_entity_id,'101');
 assert.match(e.refs.mgEngineActionResult.textContent,/saved and verified/);
 assert(e.calls.every(c=>!/(?:complete|approve|transfer|swa_act)/.test(c.name)));
});
test('Network failure never claims confirmed health or work acknowledgement',async()=>{
 const e=environment({fail:true});await e.ctx.mgOpenNotifSettings();assert.match(e.elements.get('mgEngineHealth').textContent,/unavailable/);
 await e.ctx.mgOpenNotificationDetails(e.ctx.NOTIFICATIONS[0].id);assert.match(e.modal,/Could not verify/);
 assert(!e.calls.some(c=>c.name==='notification_source_interaction'));
});
