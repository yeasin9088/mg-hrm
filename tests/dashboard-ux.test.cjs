const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(require('node:path').join(__dirname,'../index.html'),'utf8');
const modelCode = fs.readFileSync(require('node:path').join(__dirname,'../notification-model.js'),'utf8');
const section = (start,end) => html.slice(html.indexOf(start),html.indexOf(end,html.indexOf(start)));
function context(extra={}) {
  const c = {Date,Map,Set,Intl,console,...extra}; c.window=c; vm.createContext(c);return c;
}
function metricsContext(extra={}) {
  const c=context(extra);
  vm.runInContext(section('function dashboardUnique(', 'async function renderDashboard('),c);
  return c;
}
test('Dashboard counts unique live IDs, explicit employment states and exactly 30 Dhaka calendar dates',()=>{
  const c=metricsContext();
  const m=c.dashboardMetrics([
    {id:1,status:'Active',join_date:'2026-09-22'},
    {id:1,status:'Active',join_date:'2026-09-22'},
    {id:2,status:'Inactive',join_date:'2026-10-21'},
    {id:3,status:'Active',join_date:'2026-09-21'},
    {id:4,status:'Active',join_date:'2026-10-22'},
    {id:5,status:'Active',deleted_at:'deleted',join_date:'2026-10-21'},
    {id:6,status:'',join_date:'invalid'},
    {id:7,status:'Inactive',join_date:'2026-09-31'}
  ],[{id:1},{id:1},{id:2,deleted_at:'deleted'}],'2026-10-21');
  assert.equal(m.emps.length,6);assert.equal(m.activeEmps.length,3);
  assert.equal(m.inactiveEmps.length,2);assert.equal(m.projects.length,1);
  assert.deepEqual(Array.from(m.recentJoins,e=>e.id),[1,2]);
  assert.equal(c.dashboardMetrics([],[],'2026-10-21').emps.length,0);
});
test('Dashboard keyset reads continue past a server cap and reject errors or incomplete responses',async()=>{
  const c=metricsContext();let calls=0;
  const data=Array.from({length:1003},(_,i)=>({id:i+1}));
  const client={from(){let after=0;return {select(){return this},is(){return this},order(){return this},limit(){return this},gt(k,id){after=id;return this},then(resolve){calls++;return Promise.resolve({data:data.filter(r=>r.id>after).slice(0,200)}).then(resolve)}}}};
  assert.equal((await c.dashboardReadAll(client,'employees','id')).length,1003);assert.equal(calls,7);
  const bad={from(){return {select(){return this},is(){return this},order(){return this},limit(){return Promise.resolve({error:Error('offline')})}}}};
  await assert.rejects(c.dashboardReadAll(bad,'employees','id'),/offline/);
});
function queueContext(records={}) {
  const c=context({findTransferObject:id=>records[id]||null,findEmp:()=>null,
    transferTodayISO:()=> '2026-10-21',transferScheduledDate:r=>r.effective_date||''});
  vm.runInContext(section('function filterTransferActionQueue(', 'async function loadTransferActionQueue('),c);
  return c;
}
test('Joining queue includes due scheduled/pending orders once, excludes future, terminal and inactive employees',()=>{
  const c=queueContext({9:{emp:{Status:'Inactive'},dRow:{status:'Scheduled',effective_date:'2026-10-20'}}});
  const rows=[{transfer_id:1,queue_status:'Scheduled',effective_date:'2026-10-21'},
    {transfer_id:1,queue_status:'Scheduled',effective_date:'2026-10-21'},
    {transfer_id:2,queue_status:'Joining Pending',effective_date:'2026-10-20'},
    ...['Draft','Completed','Cancelled','Not Joined'].map((status,i)=>({transfer_id:i+3,status,effective_date:'2026-10-20'})),
    {transfer_id:7,status:'Scheduled',effective_date:'2026-10-22'},
    {transfer_id:8,status:'Scheduled',effective_date:''},
    {transfer_id:9,status:'Scheduled',effective_date:'2026-10-20'},
    {transfer_id:10,status:'Scheduled',effective_date:'2026-10-20',deleted_at:'deleted'}];
  assert.deepEqual(Array.from(c.dashboardPendingTransfers(rows),r=>r.transfer_id),[1,2]);
});
test('Reminder suppression survives reload, ignores forced checks/delivery duplicates and admits changed/new confirmations',async()=>{
  const saved=new Map(); const storage={getItem:k=>saved.get(k)||null,setItem:(k,v)=>saved.set(k,v)};
  let toastCount=0,route='';
  const row={transfer_id:1,queue_status:'Joining Pending',stored_status:'Scheduled',effective_date:'2026-10-20',new_project:'Synthetic A'};
  const notification={id:'delivery-1',type:'transfer_join',ref:'1',title:'Confirm',status:'Pending'};
  function boot(user='u1') {
    const c=queueContext(); Object.assign(c,{localStorage:storage,MGHRM:{getSession:async()=>({user:{id:user}})},
      loadTransferActionQueue:async()=>{},MG_TRANSFER_QUEUE:[{...row}],NOTIFICATIONS:[{...notification}],
      toast:(text,kind,open)=>{toastCount++;open()},navigate:r=>{route=r},openTransferPopup:()=>{},openDashboardTransfer:()=>{route='transfer'}});
    vm.runInContext(modelCode,c);
    vm.runInContext(section('function pendingConfirmationKey(', '/* ============ Orchestration'),c);
    return c;
  }
  const a=boot();await Promise.all([a.checkPendingToast(true),a.checkPendingToast(true)]);assert.equal(toastCount,1);assert.equal(route,'transfer');
  const b=boot();b.NOTIFICATIONS[0].id='another-delivery';await b.checkPendingToast(true);assert.equal(toastCount,1);
  b.MG_TRANSFER_QUEUE[0].overdue_days=90;await b.checkPendingToast(true);assert.equal(toastCount,1);
  b.MG_TRANSFER_QUEUE[0].new_project='Synthetic B';await b.checkPendingToast(true);assert.equal(toastCount,2);
  b.MG_TRANSFER_QUEUE.push({...row,transfer_id:2});b.NOTIFICATIONS.push({...notification,id:'delivery-2',ref:'2'});
  await b.checkPendingToast();assert.equal(toastCount,3);
  await boot('u2').checkPendingToast();assert.equal(toastCount,4);
  b.NOTIFICATIONS.forEach(n=>n.isRead=true);await b.checkPendingToast(true);assert.equal(toastCount,4);
  assert(![...saved.values()].join('').includes('Synthetic'));
});
test('To-Do previews use available task content and scheduled reminder time without changing persisted state',()=>{
  const c=context();vm.runInContext(modelCode,c);
  const item={id:'n1',type:'todo_rem',ref:'42',title:'To-Do reminder',detail:'Review note',status:'Pending',scheduledFor:'2026-10-21T04:30:00Z',dedupeKey:'event-1'};
  const result=c.NotificationModel.todoPresentation(item,[{id:42,note:'Review roster',description:'Confirm shift coverage'}]);
  assert.equal(result.title,'Review roster');assert.match(result.detail,/Reminder:.*10:30/);assert.match(result.detail,/Confirm shift coverage/);
  assert.equal(result.actionRoute,'todo');assert.equal(result.ref,'42');assert.equal(result.dedupeKey,item.dedupeKey);assert.equal(item.title,'To-Do reminder');
  assert.equal(c.NotificationModel.todoPresentation(item,[]),item);
  const due=c.NotificationModel.todoPresentation(item,[{id:42,title:'Review',due_date:'2026-10-22'}]);assert.match(due.detail,/Due: 2026-10-22/);
  assert.equal(c.NotificationModel.todoPresentation(item,[{id:42,note:'Hidden',deleted_at:'deleted'}]),item);
});
test('Dashboard renders authoritative totals, preserved sections and empty/loading/error states',async()=>{
  const container={innerHTML:''};
  const c=metricsContext({document:{getElementById:()=>container},MGHRM:{isReady:()=>false}});
  vm.runInContext('let dashboardRenderVersion = 0;'+section('async function renderDashboard(', 'function dashboardMeetingCard('),c);
  await c.renderDashboard();assert.match(container.innerHTML,/Loading workforce overview/);assert(!container.innerHTML.includes('Active Employees'));
  let release;
  const gate = new Promise(resolve=>{release=resolve});
  c.MGHRM={isReady:()=>true,_client:()=>({})};
  c.dashboardReadAll=()=>gate;
  const staleRender = c.renderDashboard();assert.match(container.innerHTML,/Loading workforce overview/);
  Object.assign(c,{
    dashboardReadAll:async()=>[],isProjectActive:()=>true,computeParade:()=>[],computeAlerts:()=>[],monthlyTrend:()=>[],
    transferTodayISO:()=> '2026-10-21',num:String,ico:()=>'',kpi:(label,value)=>label+':'+value,
    dashboardTransferQueueHtml:()=> 'No transfers currently require joining confirmation.',
    dashboardMeetingCard:()=> 'Meeting summary',dashboardMeetingAbsentList:()=>'',renderSchedPanelHTML:()=>'',
    renderTrendChart:()=>'',activityFeed:()=>[],DATA:{},escapeHtml:String
  });
  await c.renderDashboard();assert.match(container.innerHTML,/No employee or project records/);assert.match(container.innerHTML,/Total Projects:0/);
  assert.match(container.innerHTML,/Meeting summary/);assert.match(container.innerHTML,/Quick Actions/);
  // A stale read cannot replace the latest rendered overview.
  release([]);await staleRender;assert.match(container.innerHTML,/Total Projects:0/);
  // Another initial-sync/Realtime refresh must never remove already visible KPI cards.
  const firstMarkup=container.innerHTML;
  let finish;
  const slow=new Promise(resolve=>{finish=resolve;});
  c.dashboardReadAll=()=>slow;
  const reloading=c.renderDashboard();
  assert.equal(container.innerHTML,firstMarkup,'existing dashboard remains visible during refresh');
  finish([]);await reloading;
  assert.equal(container.innerHTML,firstMarkup,'identical snapshots do not tear down the DOM');
  c.dashboardReadAll=async()=>{throw Error('simulated transient outage');};
  await c.renderDashboard();
  assert.equal(container.innerHTML,firstMarkup,'refresh errors preserve verified dashboard');
  assert(html.includes('let transferLastSyncDay = transferTodayISO();'), 'startup transfer sync cannot invent a day rollover');
});
test('Dashboard pending eligibility uses fresh server records instead of stale cached dates/statuses',()=>{
  const c=queueContext({1:{dRow:{status:'Completed',effective_date:'2026-10-01'}}});
  const rows=[{id:1,status:'Scheduled',employee_sys_id:10,effective_date:'2026-10-21'}];
  assert.equal(c.dashboardPendingTransfers(rows,'2026-10-21',[{id:10,status:'Active'}]).length,1);
  assert.equal(c.dashboardPendingTransfers(rows,'2026-10-21',[{id:10,status:'Inactive'}]).length,0);
  assert.equal(c.dashboardPendingTransfers(rows,'2026-10-21',[]).length,0);
});
test('Inbox renders enriched escaped previews with distinct read/unread rows',()=>{
  const page={innerHTML:''};
  const c=context({document:{activeElement:null,getElementById:id=>id==='page-notifications'?page:null,addEventListener(){}},
    DATA:{todos:[{id:1,note:'<script>task</script>',description:'Shift context'}]},
    NOTIFICATIONS:[{id:'a',type:'todo_rem',ref:'1',title:'To-Do reminder',status:'Ready'},{id:'b',title:'Read item',isRead:true,status:'Read'}]});
  vm.runInContext(modelCode,c);vm.runInContext(fs.readFileSync('notification-ui.js','utf8'),c);c.renderNotifications();
  assert.match(page.innerHTML,/&lt;script&gt;task&lt;\/script&gt;/);assert(!page.innerHTML.includes('<script>task'));
  assert.match(page.innerHTML,/mg-n-card unread/);assert.match(page.innerHTML,/mg-n-card read/);assert.match(page.innerHTML,/Shift context/);
});
