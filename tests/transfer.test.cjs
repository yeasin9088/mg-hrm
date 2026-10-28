const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync(require('node:path').join(__dirname, '..', 'index.html'), 'utf8');
const core = fs.readFileSync(require('node:path').join(__dirname, '..', 'app-core.js'), 'utf8');

test('application inline JavaScript parses', () => {
  let count = 0;
  for (const match of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
    if (match[1].trim()) {
      new vm.Script(match[1], {filename: `inline-script-${++count}.js`});
    }
  }
  assert.ok(count > 0);
});

function loadTransferHelpers() {
  const names = ['transferTodayISO', 'transferDhakaDate', 'transferScheduledDate', 'transferCompletedDate', 'transferSummaryCounts'];
  const code = names.map(name => {
    const start = html.indexOf(`function ${name}(`);
    assert.ok(start >= 0, `${name} must exist`);
    const next = html.indexOf('\nfunction ', start + 1);
    return html.slice(start, next);
  }).join('\n');
  const context = {Intl, Date, String};
  vm.createContext(context);
  vm.runInContext(code, context);
  return context;
}

test('scheduled date stays distinct from actual joining and legacy history', () => {
  const h = loadTransferHelpers();
  const scheduled = {status:'Scheduled', effective_date:'2026-10-22', transfer_date:'2026-10-20'};
  const completed = {status:'Completed', actual_joining_date:'2026-10-24', effective_date:'2026-10-22'};
  assert.equal(h.transferScheduledDate(scheduled), '2026-10-22');
  assert.equal(h.transferCompletedDate(scheduled), '');
  assert.equal(h.transferCompletedDate(completed), '2026-10-24');
  assert.equal(h.transferCompletedDate({status:'Completed',completed_at:'2026-10-20T20:00:00Z'}), '2026-10-21');
  assert.equal(h.transferCompletedDate({status:'Completed', transfer_date:'2020-01-01'}), '');
});

test('transfer summary counts each order once using effective date and status', () => {
  const h = loadTransferHelpers();
  const records = [
    {id:1,status:'Scheduled',effective_date:'2026-10-22'},
    {id:2,status:'Scheduled',effective_date:'2026-10-21'},
    {id:3,status:'Joining Pending',effective_date:'2026-10-20'},
    {id:4,status:'Not Joined',effective_date:'2026-10-20'},
    {id:5,status:'Completed',actual_joining_date:'2026-10-21'},
    {id:6,status:'Cancelled'},
    {id:7,status:'Completed',deleted_at:'2026-10-21T00:00:00Z'}
  ];
  const result = Object.fromEntries(h.transferSummaryCounts(records, '2026-10-21'));
  assert.deepEqual(JSON.parse(JSON.stringify(result)), {
    'Total orders':6, 'Scheduled':1, 'Joining due':2,
    'Not joined':1, 'Completed':1, 'Cancelled':1
  });
});

test('Bangladesh business date remains stable across UTC midnight', () => {
  const h = loadTransferHelpers();
  const OriginalDate = h.Date;
  h.Date = class extends OriginalDate { constructor(...args) { super(...(args.length ? args : ['2026-10-20T20:00:00Z'])); } };
  assert.equal(h.transferTodayISO(), '2026-10-21');
});

test('transfer filters use rescheduled date and retain searchable history', () => {
  const h = loadTransferHelpers();
  const start = html.indexOf('function trFilteredRows(){');
  const end = html.indexOf('function trRenderChips(){', start);
  assert.ok(start >= 0 && end > start);
  const context = {
    transferScheduledDate:h.transferScheduledDate,
    window:{TR_F:{q:'rahim',id:'',status:'',project:'',from:'2026-10-20',to:'2026-10-25'}},
    DATA:{transfers:[
      {id:1,FullName:'Rahim',CurrentProject:'A',NewProject:'B',TransferDate:'2026-10-01',effective_date:'2026-10-22',status:'Scheduled'},
      {id:2,FullName:'Rahim',CurrentProject:'B',NewProject:'C',TransferDate:'2026-10-01',effective_date:'2026-11-01',status:'Completed'},
      {id:3,FullName:'Karim',CurrentProject:'A',NewProject:'B',effective_date:'2026-10-22',status:'Cancelled'}
    ]},
    projectRecordVisible:()=>true,
    findEmpByAction:()=>null
  };
  vm.createContext(context);
  vm.runInContext(html.slice(start,end), context);
  assert.deepEqual(Array.from(context.trFilteredRows(), x=>x.id), [1]);
  context.window.TR_F = {q:'',id:'',status:'Completed',project:'',from:'',to:''};
  assert.deepEqual(Array.from(context.trFilteredRows(), x=>x.id), [2]);
});

test('joining confirmation changes no local project before verified server completion', async () => {
  const start = html.indexOf('async function confirmTransferJoined(');
  const end = html.indexOf('window.confirmTransferJoined = confirmTransferJoined;', start);
  assert.ok(start >= 0 && end > start);
  const employee = {ProjectName:'Source'};
  const transfer = {status:'Joining Pending',effective_date:'2026-10-20',new_project:'Destination',full_name:'Synthetic Employee'};
  let refreshes = 0;
  let response = {transfer:{status:'Scheduled'},employee:{project_name:'Source'}};
  const messages = [];
  const context = {
    guardEdit:()=>true,
    findTransferObject:()=>transfer,
    document:{getElementById:()=>null},
    todayISO:()=> '2026-10-21',
    transferTodayISO:()=> '2026-10-21',
    transferIsJoiningDue:()=>true,
    window:{MGHRM:{confirmTransferJoining:async()=>response}},
    toast:(message,type)=>messages.push([message,type]),
    phase2RefreshTransferState:async()=>{refreshes++;},
    closeModal:()=>{},
    console:{error:()=>{}},
    logActivity:()=>{}
  };
  vm.createContext(context);
  context.projectVisibilityData=x=>x;if(!context.window)context.window=context;
  vm.runInContext(html.slice(start,end),context);
  await context.confirmTransferJoined(1,'2026-10-21','');
  assert.equal(employee.ProjectName,'Source');
  assert.equal(refreshes,0);
  assert.equal(messages.at(-1)[1],'error');
  response = {transfer:{status:'Completed'},employee:{project_name:'Destination'}};
  await context.confirmTransferJoined(1,'2026-10-21','');
  assert.equal(refreshes,1);
  assert.equal(messages.at(-1)[1],'success');
});

test('project movement counts only confirmed actual joins, never scheduled destinations', () => {
  const start = html.indexOf('function getWorkforceSummaryData(){');
  const end = html.indexOf('function workforceSummaryHtml(',start);
  assert.ok(start >= 0 && end > start);
  const transfers = [
    {id:1,status:'Scheduled',CurrentProject:'A',NewProject:'B',effective_date:'2026-10-21'},
    {id:2,status:'Completed',CurrentProject:'A',NewProject:'B',actual_joining_date:'2026-10-21'},
    {id:3,status:'Completed',CurrentProject:'A',NewProject:'B',transfer_date:'2020-01-01'}
  ];
  const context = {
    DATA:{transfers},
    getReportFilterContext:()=>({}),
    getMonthlyReportRows:kind=>({rows:kind==='transfers'?transfers:[]}),
    reportInRange:()=>true
  };
  vm.createContext(context);
  context.projectVisibilityData=x=>x;if(!context.window)context.window=context;
  vm.runInContext(html.slice(start,end),context);
  const summary=context.getWorkforceSummaryData();
  assert.equal(summary.completed,2);
  assert.deepEqual(Array.from(summary.projects,x=>[x.project,x.incoming,x.outgoing,x.net]),[
    ['A',0,1,-1],['B',1,0,1]
  ]);
});

test('Realtime transfer invalidations are filtered, debounced and refreshed on reconnect', async () => {
  const start=html.indexOf('let transferSyncInFlight = false;');
  const end=html.indexOf('function isoDateInput(',start);
  assert.ok(start>=0 && end>start);
  const data={transfers:[]};
  let calls=0, renders=0;
  const context={
    DATA:data,document:{hidden:false,getElementById:()=>null,addEventListener:()=>{}},
    window:{MGHRM:{reloadTransfers:async()=>{calls++;data.transfers=[{id:1,status:'Scheduled',updated_at:'v1'}];return data.transfers;}},addEventListener:()=>{}},
    setInterval:()=>0,setTimeout,clearTimeout,
    transferTodayISO:()=> '2026-10-21',
    renderTransferTable:()=>{renders++;},toast:()=>{}
  };
  vm.createContext(context);
  vm.runInContext("let currentPage='transfer';\n"+html.slice(start,end),context);
  context.window.mgTransferRealtimeChanged({table:'employees',eventType:'UPDATE'});
  context.window.mgTransferRealtimeChanged({table:'transfers',eventType:'UPDATE'});
  context.window.mgTransferRealtimeChanged({table:'transfers',eventType:'UPDATE'});
  await new Promise(resolve=>setTimeout(resolve,360));
  assert.equal(calls,1);
  assert.equal(renders,1);
  context.window.mgTransferRealtimeConnected();
  await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(calls,2);
  vm.runInContext("currentPage='reports'",context);
  context.window.mgTransferRealtimeConnected();
  await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(calls,3);
});

test('failed employee reconciliation after completion retries on the next transfer refresh', async () => {
  const start=html.indexOf('let transferSyncInFlight = false;');
  const end=html.indexOf('function isoDateInput(',start);
  const data={transfers:[{id:1,status:'Scheduled',updated_at:'v1'}]};
  let employeeFetches=0, employeeRenders=0;
  const context={
    DATA:data,document:{hidden:false,getElementById:()=>null,addEventListener:()=>{}},
    window:{MGHRM:{reloadTransfers:async()=>{data.transfers=[{id:1,status:'Completed',updated_at:'v2'}];return data.transfers;}},addEventListener:()=>{}},
    setInterval:()=>0,setTimeout,clearTimeout,
    transferTodayISO:()=> '2026-10-21',
    fetchEmployeesDirectly:async()=> ++employeeFetches>1 ? [{id:1,project_name:'Destination'}] : null,
    renderEmpTable:()=>{employeeRenders++;},toast:()=>{}
  };
  vm.createContext(context);
  vm.runInContext("let currentPage='employees';\n"+html.slice(start,end),context);
  await context.syncTransfersFromServer(true);
  assert.equal(employeeFetches,1);
  assert.equal(employeeRenders,0);
  await context.syncTransfersFromServer(true);
  assert.equal(employeeFetches,2);
  assert.equal(employeeRenders,1);
});

test('older transfer reload response cannot replace a newer server snapshot', async () => {
  const start=core.indexOf('  function reloadBucket(bucket) {');
  const end=core.indexOf('  function loadTransferActionQueue()',start);
  assert.ok(start>=0 && end>start);
  const pending=[];
  const state={DATA:{transfers:[]}};
  const query={select(){return this;},is(){return this;},order(){return new Promise(resolve=>pending.push(resolve));}};
  const context={
    ready:true,sb:{from:()=>query},TABLE_MAP:{transfers:{table:'transfers',pk:'id'}},
    _transferReloadSequence:0,global:state,fromDb:(bucket,row)=>row,captureBaseline:()=>{}
  };
  vm.createContext(context);
  vm.runInContext(core.slice(start,end),context);
  const older=context.reloadBucket('transfers');
  const newer=context.reloadBucket('transfers');
  pending[1]({data:[{id:1,status:'Completed',updated_at:'v2'}],error:null});
  await newer;
  pending[0]({data:[{id:1,status:'Scheduled',updated_at:'v1'}],error:null});
  await older;
  assert.equal(state.DATA.transfers[0].status,'Completed');
});
