const test=require('node:test');
const assert=require('node:assert/strict');
const presence=require('../notification-presence.js');
const worker=import('../supabase/functions/web-push-sender/worker.mjs');
function harness({statuses=[201,201],eligible=true,failRecord=false}={}) {
 const rows=statuses.map((status,i)=>({delivery_id:i+1,endpoint:'https://synthetic.invalid/'+i,keys:{p256dh:'SYNTHETIC',auth:'SYNTHETIC'},status}));
 const calls=[],sent=[];let final=false;
 const rpc=async(name,p)=>{
  calls.push({name,p});
  if(name==='notification_claim_web_push_jobs') return {data:[{id:1,attempt_count:2}]};
  if(name==='notification_get_web_push_dispatch') return {data:{notification:{id:'occurrence-1',title:'CONFIDENTIAL',message:'PRIVATE NOTE'},deliveries:eligible?rows.filter(r=>r.result!=='sent'&&!r.revoked):[]}};
  if(name==='notification_web_push_preview') return {data:{enabled:false}};
  if(name==='notification_record_web_push_result') {
    if(failRecord) return {error:{message:'SENSITIVE ENDPOINT'}};
    const r=rows.find(r=>r.delivery_id===p.p_delivery_id);r.result=p.p_success?'sent':'failed';r.revoked=p.p_revoke_subscription;return {data:{}};
  }
  if(name==='notification_finalize_web_push_job') {final=true;return {data:{}};}
  if(name==='notification_fail_job') return {data:{}};
  throw Error('unexpected RPC');
 };
 const send=async(subscription,payload,options)=>{
   sent.push({subscription,payload:JSON.parse(payload),options});
   const row=rows.find(r=>r.endpoint===subscription.endpoint);
   if(row.status>=400) throw {statusCode:row.status,message:'SECRET',body:'RAW PROVIDER SECRET'};
   return {statusCode:row.status,headers:{location:'SENSITIVE CAPABILITY'}};
 };
 return {rpc,send,calls,sent,rows,get finalized(){return final;}};
}
test('server sender fans out to authorized devices using generic payloads and distinct occurrence IDs',async()=>{
 const {runSender,privatePayload}=await worker;const h=harness();
 const result=await runSender({...h,workerId:'synthetic',random:()=>0});assert.equal(result.providerAccepted,2);
 assert.equal(h.sent.length,2);assert(h.finalized);
 for(const r of h.sent) {assert.equal(r.payload.title,'MG-HRM');assert(!JSON.stringify(r.payload).includes('CONFIDENTIAL'));assert.equal(r.options.timeout,8000);}
 assert.notEqual(privatePayload({id:'next-cycle'}),privatePayload({id:'previous-cycle'}));
 assert(h.calls.filter(c=>c.name==='notification_record_web_push_result').every(c=>c.p.p_provider_message_id===null));
});
test('dispatch suppression prevents sends while retaining the database inbox',async()=>{
 const {runSender}=await worker;const h=harness({eligible:false});await runSender({...h,workerId:'synthetic'});
 assert.equal(h.sent.length,0);assert(h.finalized);assert(!h.calls.some(c=>/delete|dismiss/.test(c.name)));
});
test('expired subscriptions revoked and transport failures retried without secret diagnostics',async()=>{
 const {runSender,retryAfter}=await worker;const h=harness({statuses:[410,429,503]});
 const result=await runSender({...h,workerId:'synthetic',random:()=>0});assert.equal(result.revoked,1);assert.equal(result.failed,3);
 assert(h.rows[0].revoked);assert(!h.rows[1].revoked);
 assert(!JSON.stringify(h.calls).includes('RAW PROVIDER SECRET'));assert(!JSON.stringify(h.calls).includes('SECRET'));
 assert.equal(retryAfter(1,()=>0),'60 seconds');assert.equal(retryAfter(4,()=>0),'480 seconds');assert.equal(retryAfter(100,()=>1),'3600 seconds');
});
test('accepted devices are not re-sent on retry of failed devices',async()=>{
 const {runSender}=await worker;const h=harness({statuses:[201,503]});await runSender({...h,workerId:'synthetic'});
 await runSender({...h,workerId:'synthetic'});assert.equal(h.sent.filter(s=>s.subscription.endpoint.endsWith('/0')).length,1);
 assert.equal(h.sent.filter(s=>s.subscription.endpoint.endsWith('/1')).length,2);
});
test('database result failure is released for recovery without claiming a successful device delivery',async()=>{
 const {runSender}=await worker;const h=harness({statuses:[201],failRecord:true});const result=await runSender({...h,workerId:'synthetic'});
 assert.equal(result.jobErrors,1);assert.equal(result.providerAccepted,0);assert(h.calls.some(c=>c.name==='notification_fail_job'));
 assert(!JSON.stringify(h.calls).includes('SENSITIVE ENDPOINT'));
});
test('presence requires visible focused recent online activity',()=>{
 const base={visible:true,focused:true,lastActivity:100,now:1000,online:true};assert(presence.foreground(base));
 for(const patch of [{visible:false},{focused:false},{online:false},{now:121000}]) assert.equal(presence.foreground({...base,...patch}),false);
});
test('per-tab presence lifecycle reports background transitions and clears listeners',async()=>{
 const events=new Map(),calls=[];let time=1000,focused=true,cleared=false;
 const target={addEventListener:(n,fn)=>events.set(n,fn),removeEventListener:n=>events.delete(n)};
 const w={...target,crypto:{randomUUID:()=> '11111111-1111-4111-8111-111111111111'},navigator:{onLine:true},localStorage:{getItem:()=>null,setItem:()=>{}},setInterval:()=>1,clearInterval:()=>{cleared=true;}};
 const d={...target,visibilityState:'visible',hasFocus:()=>focused};
 const tracker=presence.create({window:w,document:d,now:()=>time,heartbeat:async p=>{calls.push(p);}});await new Promise(setImmediate);
 assert(calls.at(-1).p_recent_activity);focused=false;events.get('blur')();await new Promise(setImmediate);
 assert.equal(calls.at(-1).p_focused,false);focused=true;time+=130000;await tracker.pulse();assert.equal(calls.at(-1).p_recent_activity,false);
 tracker.stop();await new Promise(setImmediate);assert(cleared);assert.equal(events.size,0);assert.equal(calls.at(-1).p_recent_activity,false);
});

test('unsupported and permission-denied browsers do not subscribe or call push registration',async()=>{
 const fs=require('node:fs'),vm=require('node:vm');
 let writes=0;
 const c=vm.createContext({console,Map,URLSearchParams,Uint8Array,Date,location:{search:''},
   document:{readyState:'loading',addEventListener(){},getElementById:()=>null},navigator:{},
   setInterval(){},setTimeout(){},clearTimeout(){}});
 c.window=c;c.addEventListener=()=>{};c.MGHRM={notifications:{registerDevice(){writes++;}}};
 vm.runInContext(fs.readFileSync('notification-model.js','utf8'),c);
 vm.runInContext(fs.readFileSync('notification-center.js','utf8'),c);
 assert.equal(await c.mgEnableDeviceNotifications(),'unsupported');
 c.isSecureContext=true;c.Notification={permission:'denied',requestPermission(){throw Error('must not request again');}};
 c.PushManager=function(){};c.navigator.serviceWorker={};
 assert.equal(await c.mgEnableDeviceNotifications(),'blocked');assert.equal(writes,0);
});

test('UI distinguishes one-shot, legacy daily and actual saved interval; server mode prevents browser claims',async()=>{
 const fs=require('node:fs'),vm=require('node:vm');const source=fs.readFileSync('index.html','utf8');
 const c=vm.createContext({Date,Intl,Promise,console});c.window=c;
 vm.runInContext(source.slice(source.indexOf('window.MG_RM_TYPE_ORDER ='),source.indexOf('window.mgRmApply =')),c);
 const now=Date.now(),t={reminder_enabled:true,status:'pending',reminder_type:'once',next_reminder_at:new Date(now-1000).toISOString()};
 assert.equal(c.mgRmNextAt(t,now),null);assert.equal(c.mgRmSummary(t),'Once now');
 assert.equal(c.mgRmSummary({...t,reminder_type:'today'}),'Daily (legacy)');
 assert.equal(c.mgRmSummary({...t,reminder_type:'1h',reminder_interval:30}),'every 30 min');
 let claims=0;c.MGHRM={notifications:{reminderMode:async()=>true,claimTodoReminder:async()=>{claims++;}}};
 c.MG_TD_CFG={master:true};c.DATA={todos:[t]};
 vm.runInContext(source.slice(source.indexOf('let mgReminderClaimRunning'),source.indexOf('window.mgTodoNotifyTick')),c);
 await c.mgReminderTick();assert.equal(claims,0);
});
test('ordinary note autosync cannot re-enable or overwrite a server-owned schedule',()=>{
 const fs=require('node:fs'),vm=require('node:vm'),s=fs.readFileSync('app-core.js','utf8');
 const c=vm.createContext({TABLE_MAP:{todos:{pk:'id'}},memoryRecords:{},toDb:(_k,r)=>({...r}),hashOf:JSON.stringify});c.global=c;
 vm.runInContext(s.slice(s.indexOf('  function isTempKey('),s.indexOf('  function hashOf(')),c);
 c.DATA={todos:[{id:1,note:'Saved',reminder_enabled:false,next_reminder_at:null}]};
 c.captureBaseline(c.DATA);c.DATA.todos[0].reminder_enabled=true;c.DATA.todos[0].next_reminder_at='2026-10-22';
 assert.equal(c.collectChangedRows('todos').rows.length,0);
 c.DATA.todos[0].note='Edited';const result=c.collectChangedRows('todos').rows[0];
 assert.equal(result.note,'Edited');assert(!('reminder_enabled' in result));assert(!('next_reminder_at' in result));
});

function edgeHandler(overrides={}) {
 const fs=require('node:fs'),vm=require('node:vm'),{stripTypeScriptTypes}=require('node:module');
 const source=fs.readFileSync('supabase/functions/web-push-sender/index.ts','utf8').replace(/^import .*;\n/gm,'');
 const env={WEB_PUSH_SENDER_TOKEN:'synthetic-token-32-bytes-not-a-secret',WEB_PUSH_VAPID_SUBJECT:'mailto:synthetic@example.invalid',WEB_PUSH_VAPID_PUBLIC_KEY:'SYNTHETIC_PUBLIC',WEB_PUSH_VAPID_PRIVATE_KEY:'SYNTHETIC_PRIVATE',SUPABASE_URL:'https://synthetic.invalid',SUPABASE_SERVICE_ROLE_KEY:'SYNTHETIC_SERVICE',...overrides};
 const calls=[];let handler;
 const c=vm.createContext({Request,Response,URL,TextEncoder,crypto:require('node:crypto').webcrypto,
   console:{log(){},error(){}},Deno:{env:{get:k=>env[k]},serve:fn=>{handler=fn;}},
   webpush:{setVapidDetails(){},sendNotification(){throw Error('must not send');}},
   createClient:()=>({rpc:async name=>{calls.push(name);return {data:false,error:null};}}),
   runSender:async()=>{calls.push('RUN_SENDER');return {jobErrors:0};}});
 vm.runInContext(stripTypeScriptTypes(source,{mode:'strip'}),c);
 return {handler,calls,token:env.WEB_PUSH_SENDER_TOKEN};
}
test('authenticated health returns capability without claiming jobs or sending notifications',async()=>{
 const h=edgeHandler();const response=await h.handler(new Request('https://synthetic.invalid/?health=1',{method:'POST',headers:{'x-web-push-sender-token':h.token}}));
 assert.equal(response.status,200);assert.equal((await response.json()).configured,true);
 assert.deepEqual(h.calls,['notification_reminder_mode']);
});
test('missing or mismatched custom credentials reject before database or transport access',async()=>{
 for(const headers of [{},{'x-web-push-sender-token':'wrong-token'}]){
   const h=edgeHandler();assert.equal((await h.handler(new Request('https://synthetic.invalid/?health=1',{method:'POST',headers}))).status,401);
   assert.equal(h.calls.length,0);
 }
});
test('missing secret configuration fails closed without returning secrets',async()=>{
 const h=edgeHandler({WEB_PUSH_VAPID_PRIVATE_KEY:''});const response=await h.handler(new Request('https://synthetic.invalid/?health=1',{method:'POST',headers:{'x-web-push-sender-token':h.token}}));
 assert.equal(response.status,503);assert(!JSON.stringify(await response.json()).includes(h.token));assert.equal(h.calls.length,0);
});
