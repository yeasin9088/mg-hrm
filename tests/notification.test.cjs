const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const modelSource = fs.readFileSync('notification-model.js','utf8');
const centerSource = fs.readFileSync('notification-center.js','utf8');
const coreSource = fs.readFileSync('app-core.js','utf8');
const html = fs.readFileSync('index.html','utf8');
const clone = value => JSON.parse(JSON.stringify(value));
function model() {const c=vm.createContext({});vm.runInContext(modelSource,c);return c.NotificationModel;}
const now = Date.parse('2026-10-21T04:00:00Z');
const row = (id='a', patch={}) => ({id,entity_type:'todo',entity_id:'1',created_at:'2026-10-20T03:00:00Z',updated_at:'2026-10-20T03:00:00Z',status:'Ready',title:'Synthetic',message:'Synthetic note',...patch});
test('unread/action counts exclude terminal, future and snoozed records without discarding history',()=>{
  const m=model(), rows=[row(),row('b',{status:'Dismissed'}),row('c',{status:'Scheduled',scheduled_for:'2199-01-01T00:00:00Z'}),row('d',{status:'Snoozed',snoozed_until:'2199-01-01T00:00:00Z'}),row('e',{read_at:'2026-10-20T04:00:00Z'})].map(m.normalize);
  const c=m.counts(rows,now);assert.equal(c.all,5);assert.equal(c.unread,1);assert.equal(c.snoozed,1);assert.equal(m.actionable(rows[1],now),false);
});
test('invalid historical timestamps never resurface as new notifications',()=>{
  const m=model();assert.equal(m.normalize(row('a',{created_at:'invalid'})).createdAt,0);
  assert.equal(m.timestamp(null),0);
});
test('event-specific dedupe preserves later reminder cycles and different business milestones',()=>{
  const m=model(), legacy={id:'legacy1',type:'todo_rem',ref:'1',createdAt:now-86400000};
  const matching=row('a',{created_at:new Date(now-86400000).toISOString()});
  assert.equal(m.merge([matching], [legacy,clone(legacy)]).length,1);
  assert.equal(m.merge([row()], [{...legacy,id:'later',milestone:'later',createdAt:now}]).length,2);
  assert.notEqual(m.legacyKey({...legacy,milestone:'first'}),m.legacyKey({...legacy,milestone:'second'}));
});
test('older Realtime versions cannot overwrite newer state',()=>{
  const m=model(), latest=row('a',{status:'Read',updated_at:'2026-10-21T01:00:00Z'});
  assert.equal(m.upsert([latest],row())[0].status,'Read');
});
function server() {
  return {rows:[row()],states:[],fail:false,
    async list(){return clone(this.rows);},async legacyStates(){return clone(this.states);},
    async setLegacyState(key,patch){if(this.fail)throw Error('Network failure');const saved={event_key:key,...patch};this.states=this.states.filter(r=>r.event_key!==key).concat(saved);return clone(saved);},
    async markRead(id){if(this.fail)throw Error('Network failure');const found=this.rows.find(r=>r.id===id);Object.assign(found,{read_at:new Date().toISOString(),status:'Read'});return{notification:clone(found)};},
    async markAllRead(){if(this.fail)throw Error('Network failure');this.rows.forEach(r=>{r.read_at=new Date().toISOString();});return{updated_count:this.rows.length};},
    async completeIfResolved(id){return{notification:row(id,{status:'Ready'})};}
  };
}
function controller(repo, legacy=[]) {
  const messages=[], events={};
  const c=vm.createContext({console:{warn(){},error(){}},Map,URLSearchParams,Uint8Array,Date,
    document:{readyState:'loading',hidden:false,getElementById:()=>null,addEventListener(){}},
    navigator:{},location:{search:''},localStorage:{getItem:()=>null,setItem(){}},
    setTimeout:()=>1,clearTimeout(){},setInterval(){},toast:(text,type)=>messages.push({text,type})});
  c.window=c;c.addEventListener=(key,fn)=>events[key]=fn;c.NOTIFICATIONS=clone(legacy);
  c.MGHRM={notifications:repo,onChange(fn){c.authChanged=fn;}};
  vm.runInContext(modelSource,c);vm.runInContext(centerSource,c);
  return {c,messages,events};
}
test('read success uses persisted raw state; failed mutations never show optimistic unread success',async()=>{
  const repo=server(),{c,messages}=controller(repo);await c.mgLoadBackendNotifications();
  repo.fail=true;assert.equal(await c.markNotifAsRead('a'),false);assert.equal(c.getUnreadNotifCount(),1);
  repo.fail=false;assert.equal(await c.markNotifAsRead('a'),true);assert.equal(c.getUnreadNotifCount(),0);
  c.mgRebuildNotificationView();assert.equal(c.getUnreadNotifCount(),0);assert.equal(messages[0].type,'error');
});
test('legacy read/dismiss/snooze state synchronizes between two devices without recreating cards',async()=>{
  const repo=server();repo.rows=[];
  const legacy=[{id:'sc1',type:'sc',ref:'1',createdAt:now,title:'Synthetic'}];
  const a=controller(repo,legacy).c,b=controller(repo,legacy).c;
  await a.mgLoadBackendNotifications();await b.mgLoadBackendNotifications();
  await a.markNotifAsRead('sc1');await b.mgLoadBackendNotifications();assert.equal(b.getUnreadNotifCount(),0);
  await a.mgBackendNotifDismiss('sc1');await b.mgLoadBackendNotifications();assert.equal(b.NOTIFICATIONS[0].status,'Dismissed');assert.equal(b.NOTIFICATIONS.length,1);
});
test('completion refuses a non-Completed RPC response and does not show phantom success',async()=>{
  const {c,messages}=controller(server());await c.mgLoadBackendNotifications();
  assert.equal(await c.mgBackendNotifComplete('a'),false);assert(!messages.some(m=>m.type==='success'));
});
test('account change invalidates an in-flight load and clears prior account data',async()=>{
  const repo=server();let release;repo.list=()=>new Promise(resolve=>release=resolve);
  const {c}=controller(repo),pending=c.mgLoadBackendNotifications();c.authChanged('SIGNED_OUT',null);release([row()]);await pending;
  assert.equal(c.NOTIFICATIONS.length,0);assert.equal(c.MG_BACKEND_NOTIFICATIONS.length,0);
});
test('failed page load retains known inbox and exposes retry state',async()=>{
  const repo=server(),{c}=controller(repo);await c.mgLoadBackendNotifications();repo.list=async()=>{throw Error('Second page failed');};
  await c.mgLoadBackendNotifications();assert.equal(c.NOTIFICATIONS.length,1);assert.match(c.MG_NOTIFICATION_STATE.error,/Second page/);
});
test('notification repository keyset pagination reads past 100/200 rows and throws on partial failure',async()=>{
  // Execute the actual repository functions without connecting to Supabase.
  let fail=false;const records=Array.from({length:420},(_,i)=>({id:String(i).padStart(4,'0')})).reverse();
  const c=vm.createContext({});c.window=c;
  c.getSession=async()=>({user:{id:'synthetic'}});
  c._client=()=>({from(){let cursor;return{select(){return this;},eq(){return this;},order(){return this;},lt(k,v){cursor=v;return this;},async limit(){if(fail&&cursor)return{error:Error('Page failed')};return{data:records.filter(r=>!cursor||r.id<cursor).slice(0,125)};}};}});
  vm.runInContext(coreSource.slice(coreSource.indexOf('  function notificationClient()'),coreSource.indexOf('  function notificationGetPreferences()')),c);
  assert.equal((await c.notificationList()).length,420);fail=true;await assert.rejects(c.notificationList(),/Page failed/);
});
test('service worker keeps cold-start identity and uses private lock-screen content',()=>{
  const sw=fs.readFileSync('sw.js','utf8');assert.match(sw,/notification_id=/);assert.match(sw,/const title = 'MG-HRM'/);
  assert(!/const body = String\(payload/.test(sw));assert.match(sw,/pushsubscriptionchange/);
  assert(!/notifs\.length = 200|notifs\.splice\(i, 1\).*RETENTION/.test(html));
});
test('ordinary cache autosync cannot rewind a reminder claim and scheduling does not fire local duplicates',()=>{
  assert.match(coreSource,/if \(k === 'todos'\) delete db.next_reminder_at/);
  const scheduler=html.slice(html.indexOf('let mgReminderClaimRunning'),html.indexOf('window.mgTodoNotifyTick'));
  assert.match(scheduler,/claimTodoReminder/);assert(!scheduler.includes('mgRmFire('));
});
