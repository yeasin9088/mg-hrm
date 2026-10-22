const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const worker=import('../supabase/functions/web-push-sender/worker.mjs');
const generic='You have a new notification. Open MG-HRM to review it.';

test('authorized Bengali and English To-Do notes become concise push previews',async()=>{
  const {privatePayload}=await worker;
  const n={id:'123',category:'ToDo',priority:'High',title:'Generic reminder',message:'Generic body'};
  let p=JSON.parse(privatePayload(n,{enabled:true,todo_id:42,todo_note:'সাত্তার আউটসোর্স নবায়ন ডিউটি বিলের বিষয়ে সিদ্ধান্ত নিতে হবে।'}));
  assert.equal(p.title,'MG-HRM · To-Do Reminder');
  assert.equal(p.body,'সাত্তার আউটসোর্স নবায়ন ডিউটি বিলের বিষয়ে সিদ্ধান্ত নিতে হবে।');
  assert.equal(p.action_route,'todo');assert.equal(p.entity_id,'42');
  p=JSON.parse(privatePayload(n,{enabled:true,todo_id:42,todo_note:'Review the renewal decision'}));
  assert.equal(p.body,'Review the renewal decision');
  p=JSON.parse(privatePayload(n,{enabled:true,todo_id:42,todo_note:'বাংলা'.repeat(160)}));
  assert(Array.from(new Intl.Segmenter('bn',{granularity:'grapheme'}).segment(p.body)).length<=180);assert(p.body.endsWith('…'));
  assert(!p.body.includes('\ufffd'));
});
test('missing or restricted content falls back; sensitive categories reveal only fixed summaries',async()=>{
  const {privatePayload}=await worker;
  const n={id:'123',category:'ToDo',title:'PRIVATE',message:'secret employee data'};
  for(const preview of [{enabled:true},{enabled:false,todo_id:42,todo_note:'private'},{enabled:true,todo_id:42,todo_note:null}]) {
    const p=JSON.parse(privatePayload(n,preview));assert.equal(p.body,generic);assert.equal(p.entity_id,null);
  }
  for(const category of ['Disciplinary','Exit','Leave','Recruitment','Transfer','Uniform','Meeting']) {
    const p=JSON.parse(privatePayload({...n,category},{enabled:true}));
    assert(p.title.includes(category));assert(!JSON.stringify(p).includes('PRIVATE'));
    assert(!JSON.stringify(p).includes('secret employee data'));
  }
  const p=JSON.parse(privatePayload({...n,category:'ToDo'},{enabled:true,todo_id:2,todo_note:'Call me at hello@example.org; password: abc123 <b>urgent</b>'}));
  assert(!p.body.includes('hello@example.org'));assert(!p.body.includes('abc123'));assert(!p.body.includes('<b>'));
});
function serviceWorker(){
  const listeners={},shown=[],opened=[];
  const self={registration:{scope:'https://yeasinh.me/mg-hrm/',showNotification:async(title,options)=>{shown.push({title,options});}},
    clients:{matchAll:async()=>[],openWindow:async url=>{opened.push(url);}},addEventListener:(kind,fn)=>listeners[kind]=fn,
    skipWaiting(){}};
  vm.runInNewContext(fs.readFileSync('sw.js','utf8'),{self,URL,Request,console,caches:{},fetch(){throw Error('no network');}});
  async function push(payload){let promise;listeners.push({data:payload===null?null:{json:()=>payload},waitUntil:p=>{promise=p;}});await promise;return shown.at(-1);}
  async function click(notification){let promise;listeners.notificationclick({notification:{data:notification.options.data,close(){}},waitUntil:p=>{promise=p;}});await promise;return opened.at(-1);}
  return {push,click,shown};
}
test('Android/Windows Service Worker displays safe payload and opens a cold To-Do route',async()=>{
  const sw=serviceWorker(),id='11111111-1111-4111-8111-111111111111';
  let shown=await sw.push({notification_id:id,title:'MG-HRM · To-Do Reminder',body:'বাংলা নোট',entity_type:'todo',entity_id:'42',action_route:'todo',priority:'Urgent'});
  assert.equal(shown.options.body,'বাংলা নোট');assert.equal(shown.options.requireInteraction,true);
  const url=new URL(await sw.click(shown));assert.equal(url.searchParams.get('notification_id'),id);
  assert.equal(url.searchParams.get('notification_route'),'todo');assert.equal(url.searchParams.get('notification_entity'),'42');
  shown=await sw.push({notification_id:'22222222-2222-4222-8222-222222222222',title:'MG-HRM · To-Do Reminder',body:'Next occurrence'});
  assert.notEqual(sw.shown[0].options.tag,shown.options.tag);
  assert.equal((await sw.push({title:'<script>bad</script>',body:'<b>English</b>'})).options.body,'English');
  assert.equal((await sw.push({title:7,body:{bad:'data'}})).options.body,generic);
  assert.equal((await sw.push(null)).options.body,generic);
});
test('notification settings map the user preference to a persisted column',()=>{
  const source=fs.readFileSync('notification-settings.js','utf8');
  const snippet=source.slice(source.indexOf('var DEFAULTS='),source.indexOf('function root(){'));
  const context=vm.createContext({window:{}});vm.runInContext(snippet,context);
  assert.equal(vm.runInContext('fromRow({}).contentPreview',context),true);
  assert.equal(vm.runInContext('fromRow({show_content_preview:false}).contentPreview',context),false);
  assert.equal(vm.runInContext('toRow({contentPreview:false}).show_content_preview',context),false);
  assert(source.includes("mgNsPreview:'contentPreview'"));
});
test('cold-start click waits for the authenticated Inbox and ignores foreign record IDs',async()=>{
  const id='11111111-1111-4111-8111-111111111111',opened=[];
  const location={pathname:'/mg-hrm/index.html',search:'?notification_route=todo&notification_id='+id,hash:''};
  const context=vm.createContext({console,Map,URLSearchParams,Date,location,
    document:{readyState:'loading',addEventListener(){},getElementById:()=>null},
    navigator:{serviceWorker:{addEventListener(){}}},setTimeout(){return 1;},clearTimeout(){},setInterval(){return 1;},
    history:{replaceState(_a,_b,url){location.search=new URL(url,'https://example.invalid').search;}},
    navigate:route=>opened.push(route),localStorage:{getItem(){return null;},setItem(){}}});
  context.window=context;context.addEventListener=()=>{};context.NOTIFICATIONS=[];
  context.MGHRM={notifications:{async list(){return [];},async legacyStates(){return [];}}};
  vm.runInContext(fs.readFileSync('notification-model.js','utf8'),context);
  vm.runInContext(fs.readFileSync('notification-center.js','utf8'),context);
  context.mgHandleSystemNotificationClick({route:'todo',notificationId:id,entityId:'42'});
  context.mgTryPendingPushOpen();assert.deepEqual(opened,[]);assert(location.search.includes(id));
  context.NOTIFICATIONS=[context.NotificationModel.normalize({id,entity_type:'todo',entity_id:'42',action_route:'todo',status:'Ready'})];
  context.mgTodoNotifOpen=ref=>opened.push(ref);
  context.handleNotifClick=ref=>opened.push(ref);
  context.mgTryPendingPushOpen();assert.deepEqual(opened,[id]);assert(!location.search.includes(id));
});
