const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function sw(limit=2,accepted=true){
 const handlers={},shown=[],requests=[],opened=[];
 const self={registration:{scope:'https://yeasinh.me/mg-hrm/',showNotification:async(title,options)=>shown.push({title,options})},clients:{matchAll:async()=>[],openWindow:async url=>opened.push(url)},addEventListener:(type,fn)=>handlers[type]=fn};
 const context={self,URL,Request,console,Intl,Notification:{maxActions:limit},caches:{},fetch:async(url,options)=>{requests.push({url,options});return {ok:accepted,json:async()=>({ok:accepted})};}};
 vm.runInNewContext(fs.readFileSync('sw.js','utf8'),context);
 const event=async(type,data)=>{let done;handlers[type]({...data,waitUntil:p=>done=p});await done;};
 return {shown,requests,opened,event};
}
const token='a'.repeat(64),id='11111111-1111-4111-8111-111111111111';
test('device actions respect zero, one, two and three platform slots',async()=>{
 for(const [limit,expected] of [[0,[]],[1,['complete']],[2,['complete','remind']],[3,['read','remind','complete']]]){
  const s=sw(limit);await s.event('push',{data:{json:()=>({notification_id:id,task_actions:true,action_token:token})}});
  assert.deepEqual(Array.from(s.shown[0].options.actions,a=>a.action),expected);
 }
});
test('Complete can run while the app is closed, with a scoped capability and no exposed credentials',async()=>{
 const s=sw(3);await s.event('notificationclick',{action:'complete',notification:{data:{notificationId:id,actionToken:token,route:'todo'},close(){}}});
 assert.equal(s.requests.length,1);assert.equal(s.opened.length,0);
 assert(s.requests[0].url.endsWith('/functions/v1/notification-device-action'));
 assert.deepEqual(JSON.parse(s.requests[0].options.body),{token,action:'complete'});
 assert(!s.requests[0].options.headers.Authorization);
});
test('unconfirmed background action opens the authenticated app with the same intent',async()=>{
 const s=sw(2,false);await s.event('notificationclick',{action:'remind',notification:{data:{notificationId:id,actionToken:token,route:'todo'},close(){}}});
 const url=new URL(s.opened[0]);assert.equal(url.searchParams.get('notification_action'),'remind');assert.equal(url.searchParams.get('notification_id'),id);assert(!url.href.includes(token));
});
test('preview opt-out still allows task actions without leaking the note',async()=>{
 const {privatePayload}=await import('../supabase/functions/web-push-sender/worker.mjs');
 const payload=JSON.parse(privatePayload({id,category:'ToDo',entity_type:'todo'},{enabled:false,todo_note:'SECRET',action_token:token}));
 assert.equal(payload.action_token,token);assert.equal(payload.task_actions,true);assert(!JSON.stringify(payload).includes('SECRET'));
});
