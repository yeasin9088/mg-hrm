'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {pathToFileURL} = require('node:url');
const root = path.join(__dirname, '..');
const scope = 'https://yeasinh.me/mg-hrm/';
const logo = scope + 'icon-192.png?notification-icon=v39';
const badge = scope + 'notification-small-m-96.png?notification-badge=v39';
const script = fs.readFileSync(path.join(root,'sw.js'),'utf8');
function factory(fetcher = async () => { throw Error('offline'); }) {
  const listeners={},stored=new Map(),shown=[],windows=[],calls=[];
  let skipCalls=0;
  const normalize = item => typeof item === 'string' ? new URL(item, scope).href : item.url;
  const cache = {
    put:async(item,response) => stored.set(normalize(item),response),
    addAll:async() => { throw Error('synthetic shell failure'); }
  };
  const caches = {
    open:async()=>cache,
    match:async item=>stored.get(normalize(item)),
    keys:async()=>['unrelated-app-cache','mghrm-v50','mghrm-v51'],
    delete:async key=>{calls.push(['delete',key]);return true;}
  };
  const self={
    registration:{scope,showNotification:async(title,options)=>{shown.push({title,options});}},
    clients:{claim:async()=>{}, matchAll:async()=>[],openWindow:async url=>windows.push(url)},
    skipWaiting:()=>{skipCalls++;return Promise.resolve();},
    addEventListener:(name,fn)=>listeners[name]=fn
  };
  const fetch = async req => {calls.push(['fetch',normalize(req)]);return fetcher(req);};
  vm.runInNewContext(script,{self,URL,Request,Response,caches,fetch,console,Intl});
  async function event(name,data) {
    let pending;
    let output;
    listeners[name]({...data,waitUntil:p=>pending=p,respondWith:p=>output=p});
    if(pending) await pending;
    return output ? output : pending;
  }
  return {event,listeners,self,cache,caches,stored,shown,windows,calls,get skips(){return skipCalls;}};
}
test('web manifest has a stable ID, valid scope, icons, and existing shortcuts',()=>{
  const m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
  assert.equal(m.id,'./index.html'); assert.equal(m.display,'standalone');
  assert.equal(m.start_url,'./index.html');assert.equal(m.scope,'./');
  assert(m.icons.some(x=>x.sizes==='512x512'));assert(m.shortcuts.length>=2);
  assert(m.icons.every(x=>x.purpose!=='maskable')); // unverified icon safe zone
});
test('GitHub Pages PWA enhancement is idempotent and does not alter app code',async()=>{
  const {injectPwaEnhancements}=await import(pathToFileURL(path.join(root,'scripts/pwa-inject.mjs')).href);
  const original='<html><head><title>MG HRM</title></head><body><script>window.existingWorkflow=1</script></body></html>';
  const first=injectPwaEnhancements(original);
  assert(first.includes('window.existingWorkflow=1'));
  assert.equal((first.match(/pwa-experience\.js/g)||[]).length,1);
  assert.equal((first.match(/pwa-experience\.css/g)||[]).length,1);
  assert.equal(injectPwaEnhancements(first),first);
  assert.throws(()=>injectPwaEnhancements('<html/>'),/missing/);
  const build=fs.readFileSync(path.join(root,'scripts/build-pages.mjs'),'utf8');
  assert(build.includes("'notification-badge-96.png'"));
  assert(build.includes("'pwa-experience.js'"));
  assert(build.includes("'offline.html'"));
});
test('push branding still installs despite unrelated shell warmup error',async()=>{
  const mockResponse = () => new Response('png',{status:200,headers:{'Content-Type':'image/png'}});
  const sw=factory(async req=>mockResponse());
  await sw.event('install',{});
  assert.deepEqual(sw.calls.filter(a=>a[0]==='fetch').map(a=>a[1]),[logo,badge]);
  assert(sw.stored.has(logo) && sw.stored.has(badge));
  assert.equal(sw.skips,0); // no forced takeover of open app forms
});
test('unexpected HTML for push brand asset aborts installation',async()=>{
  const sw=factory(async()=>new Response('<html>not an image</html>',{status:200,headers:{'Content-Type':'text/html'}}));
  await assert.rejects(sw.event('install',{}),/valid PNG/);
});
test('Supabase and dynamic API data bypass Service Worker caching',async()=>{
  const sw=factory();
  const ignored=[
    'https://enkggoozsvvkgbjeghbf.supabase.co/rest/v1/employees',
    scope+'api/employees',scope+'bd-geo.json?private=1',scope+'employee-data.json',
    'https://cdn.jsdelivr.net/npm/x@1.0.0',scope+'index.html?user-record=1'
  ];
  for(const item of ignored){
    let wasIntercepted=false;
    sw.listeners.fetch({request:{url:item,method:'GET',mode:'cors',respondWith:()=>{wasIntercepted=true;}},respondWith:()=>{wasIntercepted=true;}});
    assert.equal(wasIntercepted,false,item);
  }
  const authUrl=scope+'app-core.js';
  let hit=false;
  sw.listeners.fetch({request:{url:authUrl,method:'GET',mode:'cors',headers:{has:k=>k.toLowerCase()==='authorization'}},respondWith:()=>{hit=true;}});
  assert.equal(hit,false);
});
test('static JS response never falls back to application HTML',async()=>{
  const sw=factory();
  sw.stored.set(scope+'app-core.js',new Response('<html/>',{status:200,headers:{'Content-Type':'text/html'}}));
  const response=await sw.event('fetch',{request:new Request(scope+'app-core.js')});
  assert.equal((await response).type,'error');
});
test('offline navigation shows safe branded offline page and does not expose cached records',async()=>{
  const sw=factory();
  const offlineHtml=fs.readFileSync(path.join(root,'offline.html'),'utf8');
  sw.stored.set(scope+'offline.html',new Response(offlineHtml,{headers:{'Content-Type':'text/html'}}));
  const response=await sw.event('fetch',{request:{url:scope+'index.html',method:'GET',mode:'navigate'}});
  const body=await (await response).text();
  assert(body.includes('ইন্টারনেট সংযোগ নেই'));
  assert(!body.includes('employee_sys_id'));
});
test('old caches removed selectively; unrelated app caches retained',async()=>{
  const sw=factory();await sw.event('activate',{});
  assert.deepEqual(sw.calls.filter(a=>a[0]==='delete'),[['delete','mghrm-v50']]);
});
test('skipWaiting occurs only after explicit App Center message',async()=>{
  const sw=factory();await sw.event('install',{}).catch(()=>{});
  assert.equal(sw.skips,0);
  await sw.event('message',{data:{type:'MG_PWA_SKIP_WAITING'}});
  assert.equal(sw.skips,1);
});
test('Web Push notification opens precise authenticated To-Do route',async()=>{
  const sw=factory();
  await sw.event('push',{data:{json:()=>({notification_id:'11111111-1111-4111-8111-111111111111',title:'MG-HRM · To-Do Reminder',body:'বাংলা নোট',entity_type:'todo',entity_id:'42',action_route:'todo',priority:'Urgent'})}});
  const n=sw.shown[0];assert.equal(n.options.icon,logo);assert.equal(n.options.badge,badge);
  assert.equal(n.options.body,'বাংলা নোট');assert.equal(n.options.requireInteraction,true);
  await sw.event('notificationclick',{notification:{data:n.options.data,close(){}}});
  const url=new URL(sw.windows[0]);assert.equal(url.searchParams.get('notification_entity'),'42');
  assert.equal(url.searchParams.get('notification_route'),'todo');
});
