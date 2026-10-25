const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('index.html','utf8');
function part(start,end){const a=source.indexOf(start);assert(a>=0,start);const b=source.indexOf(end,a);assert(b>a,end);return source.slice(a,b);}
const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const note=(id,patch={})=>({id,category:'note',status:'pending',note_bn:'নিরাপত্তা কর্মীর অনুসরণ '+id,date:'2026-10-20',created_at:'2026-10-20T10:00:00Z',...patch});
function fixture(rows=[note(1)],initialSub='all'){
 let markup='',elements={};
 const input=()=>({value:'',style:{},scrollHeight:64,focus(){},setSelectionRange(){}});
 const page={get innerHTML(){return markup},set innerHTML(v){markup=v;elements={...elements,tdQuickNote:input(),tdQuickRemindType:input(),tdQuickCat:{value:c.MG_TD_CAT_PICK||'note'}};}};
 const c=vm.createContext({console,Date,Intl,Set,Map,
  document:{activeElement:null,getElementById:id=>id==='page-todo'?page:elements[id]||null},
  DATA:{todos:rows},escapeHtml:escape,tdCatOf:t=>t.category||'note',todayISO:()=> '2026-10-21',activeProjects:()=>[],
  mgRmSummary:()=> 'Every 1 hour',updateTodoBadge(){},persist:async()=>{},toast(){},checkSalaryReminder(){},
  MG_RM_TYPES:{'1h':{interval:60}},MG_TD_SUB:initialSub});
 c.window=c;
 vm.runInContext(part('function renderTodo(){','// Close secondary menus'),c);
 c.renderTodo();
 return {c,page,get elements(){return elements},render(){c.renderTodo();return markup},rows(){return [...markup.matchAll(/class="td-row[^\"]*" id="td-row-([^\"]+)"/g)].map(m=>Number(m[1]))}};
}
test('all four categories retain their open/solved counts and historical records without render-time mutations',()=>{
 const rows=[note(1),note(2,{status:'solved_approved'}),note(3,{category:'task'}),note(4,{category:'permission',manager_status:'asked'}),note(5,{category:'salary',status:'done'}),note(6,{deleted_at:'2026-10-21'})];
 const before=JSON.stringify(rows),f=fixture(rows);
 for(const text of ['General','My Task','Inform to Manager','Salary Notes'])assert(f.page.innerHTML.includes(text));
 assert.deepEqual(f.rows(),[2,1]);assert.match(f.page.innerHTML,/Solved 1/);
 f.c.tdMainFilter='salary';f.render();assert.deepEqual(f.rows(),[5]);assert.match(f.page.innerHTML,/Cleared 1/);
 f.c.tdMainFilter='mgr';f.render();assert.deepEqual(f.rows(),[4]);assert.match(f.page.innerHTML,/Inform to Manager/);
 assert.equal(JSON.stringify(rows),before);
});
test('Open is the default status for General, My Task, Inform to Manager and Salary Notes',()=>{
 const data=[
  note(1,{category:'note'}),note(2,{category:'note',status:'solved_approved'}),
  note(3,{category:'task'}),note(4,{category:'task',status:'done'}),
  note(5,{category:'permission'}),note(6,{category:'permission',status:'solved_rejected'}),
  note(7,{category:'salary'}),note(8,{category:'salary',status:'done'})
 ];
 const f=fixture(data,null);
 assert.match(source,/window\.MG_TD_SUB = window\.MG_TD_SUB \|\| 'unsolved'/);
 assert.match(source,/window\.mtSetTodoSub\('unsolved'\)/);
 assert.equal(f.c.MG_TD_SUB,null);
 for(const [tab,expected] of [['general',1],['task',3],['mgr',5],['salary',7]]){
   f.c.tdMainFilter=tab;
   const rendered=f.render();
   assert.deepEqual(f.rows(),[expected],tab);
   assert.match(rendered,/class="td-chipbtn on" aria-pressed="true" onclick="mtSetTodoSub\('unsolved'\)"/,tab);
 }
 // A user can still deliberately select All and view previously solved notes.
 f.c.MG_TD_SUB='all';
 f.c.tdMainFilter='general';
 f.render();
 assert.deepEqual(f.rows(),[2,1]);
 // Changing tabs explicitly resets the status to Open as requested.
 f.c.tdSec=(k)=>({key:k,cat:({general:'note',task:'task',mgr:'permission',salary:'salary'})[k],label:({general:'General',task:'My Task',mgr:'Inform to Manager',salary:'Salary Notes'})[k],sub:'',icon:'list'});
 f.c.mtSetTodoSub=(k)=>{f.c.MG_TD_SUB=k;};
 vm.runInContext(part("window.mtSetTodoFilter = function(key){","function host(){"),f.c);
 for(const [tab,expected] of [['task',3],['mgr',5],['salary',7],['general',1]]){
   f.c.MG_TD_SUB='all';
   f.c.mtSetTodoFilter(tab);
   assert.equal(f.c.MG_TD_SUB,'unsolved');
   assert.deepEqual(f.rows(),[expected]);
 }
});
test('notes stay fully visible with compact direct actions and a secondary More menu',()=>{
 const f=fixture([note(1,{is_important:true,reminder_enabled:true,extra_notes:[{raw:'Historical reply'}]})]);
 const html=f.render();
 assert.equal((html.match(/mtToggleTodoImportant/g)||[]).length,1);
 assert.match(html,/id="td-important-1" aria-label="Remove important" aria-pressed="true"/);
 assert.match(html,/<div id="td-preview-1" class="td-note">/);
 assert(!html.includes('td-expand'));assert(!html.includes('td-details'));assert(!html.includes('mtToggleTodoOpen'));
 assert.match(html,/Approve<\/button>/);assert.match(html,/Reject<\/button>/);
 assert.match(html,/<details class="td-more"><summary>More ···<\/summary>/);
 for(const action of ['Edit','Extra note','Move','Delete','mtOpenRemPicker'])assert(html.includes(action),action);
 assert(!html.includes('Historical reply')); // Still available in the existing Extra note editor.
 assert.match(html,/Every 1 hour/);assert.match(html,/Next: not scheduled/);
});
test('reminder metadata uses the saved timestamp in Dhaka and hides disabled or solved schedules',()=>{
 const f=fixture([note(1,{reminder_enabled:true,next_reminder_at:'2099-10-24T11:30:00Z'}),note(2,{reminder_enabled:false,next_reminder_at:'2099-10-24T11:30:00Z'}),note(3,{reminder_enabled:true,status:'solved_approved',next_reminder_at:'2099-10-24T11:30:00Z'})]);
 const html=f.render();
 assert.equal((html.match(/td-next-reminder/g)||[]).length,1);
 assert.match(html,/Next: 24 Oct 2099, 5:30 pm/);
 f.c.DATA.todos[0].next_reminder_at='invalid';assert.match(f.render(),/Next: not scheduled/);
 f.c.DATA.todos[0].next_reminder_at='2000-01-01T00:00:00Z';assert.match(f.render(),/Due:/);
});
test('all/open/pending/approved/solved/important filters and Bengali/history search keep existing ordering',()=>{
 const f=fixture([note(1),note(2,{status:'approved',is_important:true}),note(3,{status:'solved_rejected',is_important:true,extra_notes:[{raw:'Unique history'}]})]);
 assert.match(f.page.innerHTML,/Important 2<\/button>/);
 for(const [filter,expected] of [['all',[3,2,1]],['unsolved',[2,1]],['pending',[1]],['approved',[2]],['solved',[3]],['important',[3,2]]]){
  f.c.MG_TD_SUB=filter;f.render();assert.deepEqual(f.rows(),expected,filter);
 }
 f.c.MG_TD_SUB='all';f.c.MG_TD_Q='unique history';f.render();assert.deepEqual(f.rows(),[3]);
 f.c.MG_TD_Q='নিরাপত্তা';f.render();assert.equal(f.rows().length,3);
});
test('composer text and schedule survive list refreshes and note previews escape markup safely',()=>{
 const f=fixture([note(1,{note_bn:'<script>alert(1)</script>'})]);
 f.elements.tdQuickNote.value='অসমাপ্ত খসড়া';f.elements.tdQuickRemindType.value='custom';
 f.c.MG_TD_SUB='solved';f.render();assert.equal(f.elements.tdQuickNote.value,'অসমাপ্ত খসড়া');assert.equal(f.elements.tdQuickRemindType.value,'custom');
 f.c.MG_TD_SUB='all';f.render();assert.match(f.page.innerHTML,/&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
 assert(!f.page.innerHTML.includes('<script>alert(1)'));
 for(const option of ['30m','1h','2h','today','custom'])assert(f.page.innerHTML.includes('value="'+option+'"'));
});
test('every tab keeps creation-time order through decisions, stars, manager state and edits',()=>{
 for(const [tab,category] of [['general','note'],['task','task'],['mgr','permission'],['salary','salary']]){
  const data=[note(90,{category,created_at:'2026-10-20T09:00:00Z'}),note(10,{category,created_at:'2026-10-20T11:00:00Z'}),note(50,{category,created_at:'2026-10-20T10:00:00Z'})];
  const f=fixture(data,'unsolved');f.c.tdMainFilter=tab;f.render();
  assert.deepEqual(f.rows(),[10,50,90],tab);
  Object.assign(data[2],{status:'approved',is_important:true,manager_status:'approved',updated_at:'2099-01-01T00:00:00Z'});
  f.render();assert.deepEqual(f.rows(),[10,50,90],tab+' approved/starred');
  data[2].status='rejected';f.render();assert.deepEqual(f.rows(),[10,50,90],tab+' rejected');
  data[2].status='approved';data[0].status='approved';f.c.MG_TD_SUB='approved';f.render();assert.deepEqual(f.rows(),[50,90]);
  data[2].status='solved_approved';f.render();assert.deepEqual(f.rows(),[90]);
  f.c.MG_TD_SUB='all';f.render();assert.deepEqual(f.rows(),[10,50,90],tab+' solved does not reorder All');
 }
});
test('creation-date fallback ignores updated_at and equal times have stable ID order',()=>{
 const f=fixture([note(1,{created_at:null,date:'2026-10-20',updated_at:'2099-01-01'}),note(2,{created_at:'invalid',date:'2026-10-21'}),note(3,{created_at:null,date:'2026-10-20'})]);
 assert.deepEqual(f.rows(),[2,3,1]);
});
test('synthetic note creation preserves category, pending state and existing reminder options',async()=>{
 const f=fixture([]);const writes=[];f.c.appData={insert:async(bucket,t)=>{writes.push({t});return [t]}};
 f.c.toastSafe=()=>{};f.c.setTimeout=()=>{};
 vm.runInContext(part('  var MG_TD_LOADING = [];', '\n  tdLoadRestore();'),f.c);
 vm.runInContext(part('window.mtQuickAddTodo = async function(event)', 'window.mtRequestSalaryNotif'),f.c);
 f.elements.tdQuickNote.value='নতুন নোট';f.elements.tdQuickCat.value='permission';f.elements.tdQuickRemindType.value='1h';
 const result=await f.c.mtQuickAddTodo();assert.equal(result.status,'pending');assert.equal(result.category,'permission');assert.equal(result.manager_status,'asked');assert.equal(result.reminder_interval,60);assert.equal(writes.length,1);assert.equal(f.elements.tdQuickNote.value,'');
 f.elements.tdQuickNote.value='  ';assert.equal(await f.c.mtQuickAddTodo(),null);assert.equal(writes.length,1);
});
test('star and completion invoke existing transitions using isolated data',async()=>{
 const f=fixture([note(1)]),writes=[];
 f.c.appData={update:async(bucket,id,patch)=>{writes.push({bucket,id,patch});return [{id}]}};
 f.c.mgTdFlagWrite=async(t,patch)=>{Object.assign(t,patch);f.render();return true};
 vm.runInContext(part('window.mtToggleTodoImportant = function(id)','window.mtQuickAddTodo'),f.c);
 f.c.mtToggleTodoImportant(1);await Promise.resolve();assert.equal(f.c.DATA.todos[0].is_important,true);
 vm.runInContext(part('window.mtSetTodoStatus = async function(id','window.delTodo'),f.c);
 await f.c.mtToggleTodoStatus(1);assert.equal(f.c.DATA.todos[0].status,'approved');
 await f.c.mtToggleTodoStatus(1);assert.equal(f.c.DATA.todos[0].status,'solved_approved');assert(f.c.DATA.todos[0].solved_at);
 await f.c.mtToggleTodoStatus(1);assert.equal(f.c.DATA.todos[0].status,'pending');assert.equal(f.c.DATA.todos[0].solved_at,null);
 assert.equal(writes.length,3);
});
test('existing editor preserves completion, reminder metadata and replies while updating note text',async()=>{
 const f=fixture([note(1,{status:'solved_approved',solved_at:'2026-10-20',reminder_type:'custom',extra_notes:[{raw:'Past reply'}]})]);
 Object.assign(f.elements,{mgEdNote:{value:'সংশোধিত নোট'},mgEdProj:{value:'Synthetic'},mgEdDate:{value:'2026-10-20'},mgEdCat:{value:'note'},mgEdImp:{checked:false},mgEdMgr:{checked:false}});
 Object.assign(f.c,{MG_TD_EDIT_ID:1,find:id=>f.c.DATA.todos.find(t=>t.id===id),el:id=>f.elements[id],busy(){},translate:async raw=>({ok:true,bn:raw}),nowIso:()=> '2026-10-21',toastSafe(){},mtCloseNote(){},mgTdPush:async()=>true});
 vm.runInContext(part('window.mtSaveNote = async function(){','window.mtAddExtra'),f.c);
 await f.c.mtSaveNote();const row=f.c.DATA.todos[0];assert.equal(row.note_bn,'সংশোধিত নোট');assert.equal(row.status,'solved_approved');assert.equal(row.reminder_type,'custom');assert.equal(row.extra_notes[0].raw,'Past reply');
});
test('failed and concurrent status writes never claim a solved To-Do',async()=>{
 const f=fixture([note(9)]);
 f.c.console={error(){}};
 let release;
 f.c.appData={update:()=>new Promise(resolve=>{release=resolve})};
 vm.runInContext(part('window.mtSetTodoStatus = async function(id','window.delTodo'),f.c);
 const first=f.c.mtSetTodoStatus(9,'solved_approved');
 assert.equal(f.c.DATA.todos[0].status,'pending');
 assert.equal(await f.c.mtSetTodoStatus(9,'approved'),false);
 release(null);
 assert.equal(await first,false);
 assert.equal(f.c.DATA.todos[0].status,'pending');
 assert.equal(f.c.DATA.todos[0].solved_at,undefined);
 f.c.appData.update=async()=>[{id:9}];
 assert.equal(await f.c.mtSetTodoStatus(9,'solved_approved'),true);
 assert.equal(f.c.DATA.todos[0].status,'solved_approved');
});
test('notification deep link selects the source category and keeps a closed source visible',()=>{
 const f=fixture([note(1,{category:'salary',status:'solved'})]);
 f.c.mgTdFindTodo=()=>f.c.DATA.todos[0];f.c.navigate=()=>{};f.c.mgRmIsClosed=()=>true;f.c.setTimeout=()=>{};
 f.c.mtSetTodoFilter=tab=>{f.c.tdMainFilter=tab;};
 vm.runInContext(part('window.mgTodoNotifOpen = function(ref)','window.mgTodoNotifSolved'),f.c);
 f.c.mgTodoNotifOpen(1);
 assert.equal(f.c.tdMainFilter,'salary');assert.equal(f.c.MG_TD_SUB,'solved');assert.deepEqual(f.rows(),[1]);
});
