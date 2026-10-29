const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const M=require('../exit-model.js');
function harness(join='2026-01-01',intl=Intl){
 const elements=new Map();
 const node=(id,value='')=>({id,value,checked:false,disabled:false,hidden:false,readOnly:false,dataset:{},textContent:'',title:'',innerHTML:'',style:{},
  addEventListener(){},setAttribute(k,v){this[k]=v;},querySelector(){return {textContent:''};},replaceChildren(){for(const key of modalIds)elements.delete(key);modalIds.clear();}});
 for(const [id,val] of Object.entries({exEmp:'1',exDate:'',exIssue:'2026-10-23',exReason:'Formal Resignation',exReasonOther:'',exReasonOtherWrap:'',btnSubmitExit:''}))elements.set(id,node(id,val));
 const modalIds=new Set();
 function mount(markup){for(const id of modalIds)elements.delete(id);modalIds.clear();
  for(const m of markup.matchAll(/<([a-z]+)\b([^>]*?)\bid="([^"]+)"([^>]*)>/gi)){const id=m[3],attrs=m[2]+m[4];if(elements.has(id))continue;const raw=attrs.match(/\bvalue="([^"]*)"/);elements.set(id,node(id,raw?.[1]??''));modalIds.add(id);}
 }
 elements.set('modalBody',node('modalBody'));
 const employee={id:1,EmployeeID:'SYN-1',JoinDate:join,Status:'Active',FullName:'Synthetic Guard'};
 const errors=[];let confirmed=null,called=0,warningDialog=null;
 const g={ExitModel:M,escapeHtml:v=>String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'),
  findEmp:()=>employee,guardEdit:()=>true,toast:(message,type)=>errors.push([message,type]),
  mtCustomConfirm:(a,b,c,callback)=>{confirmed=callback;},openModal:(title,body,actions)=>{warningDialog={title,body,actions};mount(body+(actions||''));},ExitService:{submit:async()=>{called++;return {exit_id:12}}},
  DATA:{exits:[]},MGHRM:{reloadExits:async()=>[]},closeModal(){g.ExitUI.onModalClose();},renderExit(){},renderEmpTable(){}};
 const sandbox={window:g,document:{getElementById:id=>elements.get(id)||null,addEventListener(){}},console,Intl:intl,Date,Error,Number,JSON,crypto:require('node:crypto').webcrypto};
 vm.runInNewContext(fs.readFileSync(require.resolve('../exit-ui.js'),'utf8'),sandbox);
 const html=g.ExitUI.html();
 for(const match of html.matchAll(/<([a-z]+)\b([^>]*?)\bid="([^"]+)"([^>]*)>/gi)){
  const attrs=match[2]+match[4],id=match[3];if(elements.has(id))continue;
  const raw=attrs.match(/\bvalue="([^"]*)"/);
  elements.set(id,node(id,raw?.[1]??''));
 }
 const get=id=>{const result=elements.get(id);assert(result,'missing '+id);return result;};
 return {g,get,employee,errors,confirm:async()=>confirmed?.(),calls:()=>called,hasConfirm:()=>!!confirmed,warning:()=>warningDialog};
}
test('exit-date activation: under-one-year mandatory decision with one dropdown only',()=>{
 const h=harness();h.g.ExitUI.reset();
 assert.equal(h.get('xs_scope').hidden,true);
 h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 assert.equal(h.get('xs_scope').hidden,false);
 assert.equal(h.get('xs_optional').hidden,true);
 assert.equal(h.get('xs_required').hidden,false);
 assert.equal(h.get('xs_decision_area').hidden,false);
 assert.equal(h.get('xs_detail').hidden,true);
 assert.equal(h.get('btnSubmitExit').disabled,false);
 assert.match(h.get('xs_feedback').textContent,/decision/);
});
test('full deduction shows only relevant details and requires date',()=>{
 const h=harness();h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 h.get('xs_outcome').value='collected';h.g.ExitUI.choose();
 assert.equal(h.get('xs_wrap_deducted_on').hidden,false);
 assert.equal(h.get('xs_wrap_reason').hidden,true);
 assert.equal(h.get('xs_wrap_approved_by').hidden,true);
 assert.equal(h.get('xs_wrap_follow_up_on').hidden,false);
 assert.equal(h.get('xs_wrap_deducted').hidden,false);
 assert.equal(h.get('xs_deducted').value,'3000');
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_deducted_on').value='2026-10-22';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 assert.equal(h.g.ExitUI.collect().deducted,3000);
});
test('partial deduction reveals reason and optional deposit evidence',()=>{
 const h=harness();h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 h.get('xs_outcome').value='partial';h.g.ExitUI.choose();
 assert.equal(h.get('xs_wrap_reason').hidden,false);
 assert.equal(h.get('xs_wrap_follow_up_on').hidden,false);
 assert.equal(h.get('xs_deposit_group').hidden,true);
 h.get('xs_deducted').value='1200';h.get('xs_deducted_on').value='2026-10-22';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_reason').value='salary_held';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_deposit_now').checked=true;h.g.ExitUI.toggleDeposit();
 assert.equal(h.get('xs_deposit_group').hidden,false);
 h.get('xs_deposited').value='500';h.get('xs_deposited_on').value='2026-10-23';
 h.get('xs_receipt_no').value='SYN-R1';h.get('xs_deposited_to').value='Accounts';h.g.ExitUI.update();
 assert.equal(h.g.ExitUI.collect().deposited,500);
});
test('not deducted requires reason; waiver requires authorized approval and notes',()=>{
 const h=harness();h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 h.get('xs_outcome').value='pending';h.g.ExitUI.choose();
 assert.equal(h.get('xs_wrap_deducted').hidden,true);
 assert.equal(h.get('xs_wrap_reason').hidden,false);
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_reason').value='salary_paid';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_outcome').value='waived';h.g.ExitUI.choose();
 assert.equal(h.get('xs_wrap_reason').hidden,true);
 assert.equal(h.get('xs_wrap_approved_by').hidden,false);
 assert.equal(h.get('xs_wrap_follow_up_on').hidden,true);
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_approved_by').value='Authorized Manager';h.get('xs_notes').value='Waiver decision recorded';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 assert.equal(h.g.ExitUI.collect().reason,'special_waiver');
});
test('one-year completed: off by default, can save without extra fields, opt-in needs reason',()=>{
 const h=harness('2025-10-23');h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 assert.equal(h.get('xs_optional').hidden,false);
 assert.equal(h.get('xs_decision_area').hidden,true);
 assert.equal(h.get('btnSubmitExit').disabled,false);
 assert.equal(h.g.ExitUI.collect().outcome,'not_applicable');
 h.get('xs_enabled').checked=true;h.g.ExitUI.toggleOptional();
 assert.equal(h.get('xs_override_wrap').hidden,false);
 assert.equal(h.get('xs_decision_area').hidden,false);
 h.get('xs_outcome').value='pending';h.g.ExitUI.choose();h.get('xs_reason').value='no_salary_due';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
 h.get('xs_override_reason').value='Operator decision';h.g.ExitUI.update();
 assert.equal(h.get('btnSubmitExit').disabled,false);
});
test('incomplete deduction never opens the confirmation dialog or calls RPC',async()=>{
 const h=harness();h.get('exDate').value='2026-10-23';h.g.ExitUI.update(true);
 h.g.ExitUI.submit();assert.equal(h.hasConfirm(),false);assert.equal(h.calls(),0);assert.match(h.warning().body,/deduction decision/i);assert.match(h.warning().actions,/OK/);
 h.get('xs_outcome').value='pending';h.g.ExitUI.choose();h.get('xs_reason').value='salary_held';h.g.ExitUI.update();
 h.g.ExitUI.submit();assert.equal(h.hasConfirm(),true);assert.equal(h.calls(),0);
 await Promise.all([h.confirm(),h.confirm()]);assert.equal(h.calls(),1);
});

test('reason selector defaults to formal resignation and Other requires detail',()=>{
 const h=harness();h.get('exDate').value='2026-10-23';h.g.ExitUI.reset();
 const choices=h.g.ExitUI.reasonSelect();
 assert.match(choices,/<option value="Formal Resignation"[^>]* selected/);
 assert.match(choices,/Absconded Without Notice/);
 assert.match(choices,/Dismissal/);
 assert.equal(h.g.ExitUI.reasonText(),'Formal Resignation');
 h.get('exReason').value='Other';h.g.ExitUI.reasonChanged();
 assert.equal(h.get('exReasonOtherWrap').hidden,false);
 assert.throws(()=>h.g.ExitUI.reasonText(),/Specify/);
 h.get('exReasonOther').value='Transfer not joined; employee unreachable';
 assert.equal(h.g.ExitUI.reasonText(),'Other: Transfer not joined; employee unreachable');
 h.get('exReason').value='Formal Resignation';h.g.ExitUI.reasonChanged();
 assert.equal(h.get('exReasonOtherWrap').hidden,true);
});

test('legacy joining dates allow September departure issued in October without changing employee data',()=>{
 for(const join of ['2026/1/22','2026-1-22','22/01/2026','22-01-2026','2026-01-22']){
  const h=harness(join);h.get('exDate').value='2026-09-21';h.get('exIssue').value='2026-10-29';
  h.g.ExitUI.update(true);
  assert.equal(h.get('xs_decision_area').hidden,false);
  assert.match(h.get('xs_tenure').textContent,/242 days/);
  h.get('xs_outcome').value='pending';h.g.ExitUI.choose();h.get('xs_reason').value='no_salary_due';
  assert.equal(h.g.ExitUI.collect().outcome,'pending');h.g.ExitUI.submit();
  assert.equal(h.hasConfirm(),true);assert.equal(h.calls(),0);
  assert.equal(h.employee.JoinDate,join);assert.equal(h.employee.Status,'Active');
 }
});
test('tenure uses exit date rather than later certificate issue date',()=>{
 const h=harness('2025/10/01');h.get('exDate').value='2026-09-21';h.get('exIssue').value='2026-10-29';h.g.ExitUI.update(true);
 assert.equal(h.get('xs_required').hidden,false);assert.equal(h.get('xs_optional').hidden,true);
 assert.throws(()=>h.g.ExitUI.collect(),/deduction decision/);
});
test('missing or invalid joining dates identify the employee profile and block submission',()=>{
 for(const join of ['', '2026/02/30','31/04/2026','not a date']){
  const h=harness(join);h.get('exDate').value='2026-09-21';
  assert.doesNotThrow(()=>h.g.ExitUI.update(true));h.g.ExitUI.submit();
  assert.equal(h.hasConfirm(),false);assert.equal(h.calls(),0);
  assert.match(h.warning().body,/Employee joining date is (missing|invalid)/);
 }
});
test('Dhaka today stays ISO even when locale format uses slashes',()=>{
 const intl={DateTimeFormat:function(locale,options){
  assert.equal(options.timeZone,'Asia/Dhaka');
  return {format:()=> '29/10/2026',formatToParts:()=>[
   {type:'day',value:'29'},{type:'literal',value:'/'},{type:'month',value:'10'},
   {type:'literal',value:'/'},{type:'year',value:'2026'}]};
 }};
 const h=harness('2024/1/22',intl);h.get('exDate').value='2026-09-21';h.g.ExitUI.update(true);
 assert.equal(h.g.ExitUI.collect().outcome,'not_applicable');
 h.get('exDate').value='2026-10-30';assert.throws(()=>h.g.ExitUI.collect(),/future exit/);
});


test('editor has unique fields, hydrates saved money and never changes create form',async()=>{
 const h=harness();h.get('xs_expected').value='3000';h.get('xs_notes').value='Unsaved create draft';
 const row={exit_id:55,employee_sys_id:1,join_date:'2026/1/22',exit_date:'2026-09-21',issue_date:'2026-10-29',exit_reason:'Absconded Without Notice',full_name:'Synthetic',settlement:{version:2,enabled:true,expected:2500,deducted:1000,deposited:500,outcome:'partial',reason:'salary_held',notes:'Adjusted amount',deducted_on:'2026-10-20',deposited_on:'2026-10-21',receipt_no:'R1',deposited_to:'Accounts',follow_up_on:'2026-11-15',follow_up_time:'14:30:00'}};
 h.g.ExitService.report=async()=>[row];await h.g.ExitUI.edit(55);
 assert.equal(h.get('xe_expected').value,2500);assert.equal(h.get('xe_deposited').value,500);assert.equal(h.get('xe_follow_up_time').value,'14:30');
 assert.equal(h.get('xs_expected').value,'3000');assert.equal(h.get('xs_notes').value,'Unsaved create draft');
 assert(!h.warning().body.includes('id="xs_'));
 let saved,todoRendered=false;h.g.ExitService.update=async(...args)=>{saved=args;};h.g.renderExitTable=()=>{};
 h.g.MGHRM.reloadTodos=async()=>[{id:77,source:'exit_settlement'}];h.g.renderTodo=()=>{todoRendered=true;};
 h.get('xe_exit_reason').value='Corrected reason';await h.g.ExitUI.saveEdit();
 assert.equal(todoRendered,true);assert.equal(h.g.DATA.todos[0].id,77);
 assert.equal(saved[0],55);assert.equal(saved[1].exit_reason,'Corrected reason');assert.equal(saved[2].deposited,500);assert.equal(saved[3],2);assert.equal(saved[4].exit_reason,row.exit_reason);assert.equal(h.get('xs_notes').value,'Unsaved create draft');
});
test('editor preserves financial tracking across anniversary changes and save errors keep draft',async()=>{
 const h=harness();const row={exit_id:56,join_date:'2025-10-01',exit_date:'2026-09-21',issue_date:'2026-10-29',exit_reason:'Reason',settlement:{version:1,enabled:true,expected:3000,deducted:1000,deposited:0,outcome:'partial',reason:'salary_held',deducted_on:'2026-10-20'}};
 h.g.ExitService.report=async()=>[row];await h.g.ExitUI.edit(56);h.get('xe_exit_date').value='2026-10-10';h.g.ExitUI.update();
 assert.equal(h.get('xe_enabled').checked,true);assert.equal(h.get('xe_deducted').value,1000);assert(h.get('xe_override_reason').value);
 h.g.ExitService.update=async()=>{throw Error('Record changed on another device');};await h.g.ExitUI.saveEdit();
 assert.equal(h.get('xe_deducted').value,1000);assert.equal(h.get('xe_save').disabled,false);assert.match(h.errors.at(-1)[0],/another device/);
});
test('opening historical unrecorded legacy exit works and closing editor restores create form',async()=>{
 const h=harness();h.g.ExitService.report=async()=>[{exit_id:57,join_date:'2026/1/22',exit_date:'2026-09-21',issue_date:'2026-10-29',exit_reason:'Legacy',settlement:null}];
 await h.g.ExitUI.edit(57);assert.equal(h.get('xe_expected').value,'3000');assert.equal(h.get('xe_outcome').value,'');h.g.ExitUI.cancelEdit();
 h.get('exDate').value='2026-09-21';h.g.ExitUI.update();assert.equal(h.get('xs_scope').hidden,false);
});
test('late editor loads cannot replace newer selected exit or reopen a closed editor',async()=>{
 const h=harness();let release;
 h.g.ExitService.report=()=>new Promise(r=>release=r);const load=h.g.ExitUI.edit(1);h.g.ExitUI.onModalClose();release([{exit_id:1}]);await load;assert.equal(h.warning(),null);
});
test('confidential table is opt-in, escapes text and clears stale responses on hide',async()=>{
 const h=harness();assert.equal(h.g.ExitUI.tableCells(1),'');
 h.g.ExitService.report=async()=>[{exit_id:1,settlement:{outcome:'pending',expected:3000,deducted:0,deposited:0,follow_up_on:'2026-11-15',follow_up_time:'14:30'}}];await h.g.ExitUI.togglePrivate();
 assert.match(h.g.ExitUI.tableCells(1),/3000/);assert.match(h.g.ExitUI.tableCells(2),/Not recorded/);h.g.ExitUI.clearPrivate();assert.equal(h.g.ExitUI.tableCells(1),'');
 let resolve;h.g.ExitService.report=()=>new Promise(r=>resolve=r);const pending=h.g.ExitUI.togglePrivate();h.g.ExitUI.clearPrivate();resolve([{exit_id:1,settlement:{expected:3000,deducted:0,deposited:0}}]);await pending;assert.equal(h.g.ExitUI.tableCells(1),'');
});
test('fully deducted money still awaiting deposit retains scheduled reminder',()=>{
 const h=harness();h.get('exDate').value='2026-09-21';h.g.ExitUI.update(true);h.get('xs_outcome').value='collected';h.g.ExitUI.choose();h.get('xs_follow_up_on').value='2026-11-15';h.get('xs_follow_up_time').value='14:30';
 assert.equal(h.g.ExitUI.collect().follow_up_on,'2026-11-15');assert.equal(h.g.ExitUI.collect().follow_up_time,'14:30');
 h.get('xs_deposit_now').checked=true;h.get('xs_deposited').value='3000';h.get('xs_deposited_on').value=h.get('xs_deducted_on').value;h.get('xs_receipt_no').value='R1';h.get('xs_deposited_to').value='Accounts';
 assert.equal(h.g.ExitUI.collect().follow_up_on,'');
});
