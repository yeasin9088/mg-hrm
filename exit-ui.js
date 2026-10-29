/* Progressive confidential deduction decision inside the Employee Exit Process form. */
(function(g){
 'use strict';
 const M=g.ExitModel,$=id=>document.getElementById(editing&&document.getElementById('xe_scope')&&id.startsWith('xs_')?id.replace('xs_','xe_'):id),esc=v=>g.escapeHtml(String(v??''));
 let requestId=null,requestFingerprint='',busy=false,editing=null,editorGeneration=0,privateGeneration=0,privateVisible=false;
 const privateRows=new Map();
 const textFields=['override_reason','expected','deducted','deposited','outcome','reason','deducted_on','deposited_on','receipt_no','deposited_to','approved_by','notes','follow_up_on','follow_up_time'];
 const stamp=()=>{
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit',calendar:'gregory',numberingSystem:'latn'}).formatToParts(new Date());
  const get=type=>parts.find(p=>p.type===type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
 };
 // Shared professional exit-reason catalogue; a single public exit_reason is persisted.
 const exitReasons=Object.freeze([
  ['Formal Resignation','Voluntary / formal resignation'],
  ['Resignation by Verbal or Phone Notice','Resignation communicated verbally or by phone'],
  ['Failed to Return from Approved Leave','Did not return after approved leave'],
  ['Absconded Without Notice','Left duty without informing the employer'],
  ['Unauthorized Absence / Job Abandonment','Unapproved prolonged absence or abandonment'],
  ['Termination – Unsatisfactory Performance','Termination for documented performance concerns'],
  ['Termination – Probation Not Confirmed','Employment not continued after probation'],
  ['Termination – Contractual / Administrative','Termination under employment terms'],
  ['Termination – Workforce Reduction','Role discontinued or workforce restructuring'],
  ['Dismissal – Serious Misconduct','Disciplinary dismissal following applicable procedure'],
  ['Dismissal – Theft, Fraud or Dishonesty','Dismissal for substantiated dishonest conduct'],
  ['Dismissal – Repeated Policy Violations','Dismissal following repeated policy breaches'],
  ['End of Fixed-Term Contract','Contract completed or not renewed'],
  ['End of Project / Assignment','Project or deployment assignment ended'],
  ['Retirement','Retirement from employment'],
  ['Separation by Mutual Agreement','Mutually agreed employment separation'],
  ['Death','Employment ended due to death'],
  ['Other','Other — specify the reason']
 ]);
 function reasonSelect(){return `<select id="exReason" required aria-label="Exit reason" onchange="ExitUI.reasonChanged()">${exitReasons.map(([key,title],i)=>`<option value="${esc(key)}" title="${esc(title)}"${i===0?' selected':''}>${esc(key)}</option>`).join('')}</select>`;}
 function reasonChanged(){visible('exReasonOtherWrap',value('exReason')==='Other');syncButton();}
 function reasonText(){
  const selected=value('exReason');
  if(!exitReasons.some(x=>x[0]===selected))throw Error('Select a valid Exit Reason.');
  if(selected!=='Other')return selected;
  const detail=value('exReasonOther').trim();
  if(detail.length<5)throw Error('Specify the other Exit Reason (at least 5 characters).');
  return 'Other: '+detail;
 }
 function warning(message){
  const safe=esc(message||'Complete the required fields.');
  if(typeof g.openModal==='function'){
   g.openModal('Complete required exit information',`<div class="exit-warning-message" role="alert"><span class="exit-warning-icon" aria-hidden="true">!</span><div><strong>Action required before marking inactive</strong><p>${safe}</p></div></div>`,
    '<button type="button" class="btn primary" onclick="closeModal();ExitUI.focusMissing()">OK</button>');
  }else g.toast(message,'warning');
 }
 function focusMissing(){
  let target='exReason';
  try{reasonText();target='exDate';if(!value('exDate'))throw Error();target='xs_outcome';collect();target='';}
  catch(_){if(value('exReason')==='Other'&&!value('exReasonOther').trim())target='exReasonOther';else if(!value('exDate'))target='exDate';else if($('xs_decision_area')&&!$('xs_decision_area').hidden&&!value('xs_outcome'))target='xs_outcome';}
  if(target&&$(target)){ $(target).focus?.();$(target).scrollIntoView?.({behavior:'smooth',block:'center'}); }
 }

 function field(key,label,type='text',value='',attrs=''){
  return `<div class="field" id="xs_wrap_${key}"><label for="xs_${key}">${label}</label><input id="xs_${key}" type="${type}" value="${esc(value)}" ${type==='number'?'min="0" max="100000000" step="0.01"':''} ${attrs} oninput="ExitUI.update()"></div>`;
 }
 function html(editor=false){const markup=`<div class="exit-confidential" id="xs_scope" hidden aria-label="Confidential exit deduction decision">
  <div class="exit-section-heading"><span class="exit-private-mark" aria-hidden="true">◈</span><span>Deduction · ৳3,000</span></div>
  <p id="xs_tenure" class="exit-service-note"></p>
  <div id="xs_optional" class="exit-optional-track" hidden><label class="exit-switch-label"><input type="checkbox" id="xs_enabled" onchange="ExitUI.toggleOptional()"><span>Track deduction</span></label></div>
  <div id="xs_required" hidden></div>
  <div id="xs_override_wrap" class="field" hidden><label for="xs_override_reason">Tracking reason *</label><input id="xs_override_reason" maxlength="1000" oninput="ExitUI.update()" placeholder="Reason"></div>
  <div id="xs_decision_area" hidden>
   <div class="field exit-decision-field"><label for="xs_outcome">Deduction status *</label><select id="xs_outcome" onchange="ExitUI.choose()"><option value="">— Select —</option><option value="collected">Fully deducted</option><option value="partial">Partly deducted</option><option value="pending">Awaiting deduction</option><option value="waived">Waived</option></select></div>
   <div id="xs_detail" class="exit-conditional-details" hidden>
    <div class="form-grid">
     ${field('expected','Amount due (৳) *','number','3000')}
     <div class="field" id="xs_wrap_deducted" hidden><label for="xs_deducted">Amount deducted (৳) *</label><input id="xs_deducted" type="number" step="0.01" min="0" oninput="ExitUI.update()"></div>
     ${field('deducted_on','Deduction date *','date')}
     <div class="field" id="xs_wrap_reason"><label for="xs_reason">Reason *</label><select id="xs_reason" onchange="ExitUI.update()"><option value="">— Select reason —</option>${Object.entries(M.reasons).filter(([k])=>k!=='special_waiver').map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('')}</select></div>
     ${field('approved_by','Approved by *','text','','maxlength="200"')}
     <div class="field" id="xs_wrap_deposit_toggle" hidden><label class="exit-switch-label"><input type="checkbox" id="xs_deposit_now" onchange="ExitUI.toggleDeposit()">Record deposit</label></div>
     <div class="exit-deposit-group field wide" id="xs_deposit_group" hidden><div class="exit-subtitle">Deposit evidence</div><div class="form-grid">
      ${field('deposited','Amount deposited (৳) *','number','0')}
      ${field('deposited_on','Deposit date *','date')}
      ${field('receipt_no','Receipt / voucher number *','text','','maxlength="150"')}
      ${field('deposited_to','Deposited to / received by *','text','','maxlength="200"')}
     </div></div>
     ${field('follow_up_on','Remind on','date')}
     ${field('follow_up_time','Time','time','09:00')}
     <div class="field wide" id="xs_wrap_notes"><label for="xs_notes" id="xs_notes_label">Additional notes</label><textarea id="xs_notes" rows="2" maxlength="4000" oninput="ExitUI.update()" placeholder="Optional notes"></textarea></div>
    </div>
    <div class="exit-balance" id="xs_balance" aria-live="polite"></div>
   </div>
  </div>
  <p class="exit-form-feedback" id="xs_feedback" role="status" aria-live="polite"></p>

 </div>`;return editor?markup.replace(/xs_/g,'xe_'):markup;}
 // Legacy employee imports contain YYYY/M/D and DD/MM/YYYY text dates.
 // Normalize only at this exit-form boundary; keep model validation strict.
 function joiningDate(raw){
  const value=String(raw??'').trim();
  if(!value)throw Error('Employee joining date is missing. Add it in the employee profile before processing the exit.');
  let match=value.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/),iso=value;
  if(match)iso=`${match[1]}-${match[2].padStart(2,'0')}-${match[3].padStart(2,'0')}`;
  else {
   match=value.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/);
   if(match)iso=`${match[3]}-${match[2].padStart(2,'0')}-${match[1].padStart(2,'0')}`;
  }
  try{M.date(iso);}catch(_){throw Error('Employee joining date is invalid. Correct it in the employee profile before processing the exit.');}
  return iso;
 }
 function dates(){
  const e=editing||g.findEmp($('exEmp')?.value);
  return {join:joiningDate(e?.JoinDate||e?.join_date),exit:editing?value('xe_exit_date'):($('exDate')?.value||'')};
 }
 const visible=(id,show)=>{const el=$(id);if(el)el.hidden=!show;};
 const value=id=>$(id)?.value||'';
 function normalize(){
  const type=value('xs_outcome'),deposit=!!$('xs_deposit_now')?.checked;
  if(type==='collected')$('xs_deducted').value=value('xs_expected');
  else if(type==='pending'||type==='waived')$('xs_deducted').value='0';
  if(!['collected','partial'].includes(type)||!deposit){$('xs_deposited').value='0';}
  if(type==='waived')$('xs_reason').value='';
 }
 function collect(){
  const d=dates(),raw={enabled:!!$('xs_enabled')?.checked};
  const tenure=M.tenure(d.join,d.exit);
  raw.enabled=tenure.defaultEnabled||raw.enabled;
  textFields.forEach(k=>raw[k]=value('xs_'+k));
  if(!raw.enabled){raw.outcome='not_applicable';return M.validate(raw,d.join,d.exit,stamp());}
  const kind=raw.outcome;
  if(!kind||kind==='not_applicable')throw Error('Select a deduction decision to continue.');
  if(kind==='collected')raw.deducted=raw.expected;
  if(kind==='pending'||kind==='waived'){raw.deducted='0';raw.deducted_on='';}
  if(kind==='waived')raw.reason='special_waiver';
  if(kind==='collected')raw.reason='';
  if(!['collected','partial'].includes(kind)||!$('xs_deposit_now')?.checked){raw.deposited='0';raw.deposited_on='';raw.receipt_no='';raw.deposited_to='';}
  if(kind==='waived')raw.follow_up_on='';
  return M.validate(raw,d.join,d.exit,stamp());
 }
 function syncButton(reason){
  if(editing){
   let feedback=reason||'';if(!feedback){try{collect();}catch(err){feedback=err.message;}}
   if($('xs_feedback'))$('xs_feedback').textContent=feedback;
   return;
  }
  const button=$('btnSubmitExit');if(!button)return;
  let message=reason||'';
  if(!message){
   try{if(!g.findEmp(value('exEmp'))?.id)throw Error('Select an employee.');
    reasonText();collect();}
   catch(err){message=err.message;}
  }
  button.disabled=busy;button.title=message||'';button.setAttribute?.('aria-describedby','xs_feedback');button.dataset.needsAttention=message?'true':'false';
  const feedback=$('xs_feedback');if(feedback)feedback.textContent=message;
 }
 function update(reset=false){
  if(!$('xs_scope'))return;
  let tenure=null,error='';try{const d=dates();tenure=M.tenure(d.join,d.exit);}catch(err){error=err.message;}
  if(reset){
   const enabled=$('xs_enabled');if(enabled)enabled.checked=!!tenure?.defaultEnabled;
   const outcome=$('xs_outcome');if(outcome)outcome.value='';
   const deposit=$('xs_deposit_now');if(deposit)deposit.checked=false;
   if($('xs_deducted'))$('xs_deducted').value='0';
   if($('xs_deposited'))$('xs_deposited').value='0';
   requestId=null;requestFingerprint='';
  }
  const hasExit=!!(editing?value('xe_exit_date'):value('exDate'));
  visible('xs_scope',hasExit);if(!hasExit){syncButton('Choose an Exit Date first.');return;}
  visible('xs_optional',!!tenure&&!tenure.defaultEnabled);
  visible('xs_required',!!tenure&&tenure.defaultEnabled);
  const enabled=!!tenure&&(tenure.defaultEnabled||!!$('xs_enabled')?.checked);
  if(editing&&enabled&&!tenure.defaultEnabled&&!value('xs_override_reason'))$('xs_override_reason').value='Existing deduction retained';
  if($('xs_enabled'))$('xs_enabled').checked=enabled;
  visible('xs_override_wrap',enabled&&!tenure.defaultEnabled);
  visible('xs_decision_area',enabled);
  const outcome=value('xs_outcome');
  visible('xs_detail',enabled&&!!outcome);
  if(tenure){$('xs_tenure').textContent=`Service: ${tenure.days} days`;}
  else $('xs_tenure').textContent=error;
  if(enabled&&outcome){
   normalize();
   const full=outcome==='collected',partial=outcome==='partial',pending=outcome==='pending',waived=outcome==='waived';
   visible('xs_wrap_deducted',partial||full);
   $('xs_deducted').readOnly=full;
   visible('xs_wrap_deducted_on',full||partial);
   visible('xs_wrap_reason',partial||pending);
   visible('xs_wrap_approved_by',waived);
   visible('xs_wrap_deposit_toggle',full||partial);
   visible('xs_deposit_group',(full||partial)&&!!$('xs_deposit_now').checked);
   const needsFollowup=!waived&&(Number(value('xs_deducted'))<Number(value('xs_expected'))||Number(value('xs_deposited'))<Number(value('xs_deducted')));
   visible('xs_wrap_follow_up_on',needsFollowup);visible('xs_wrap_follow_up_time',needsFollowup&&!!value('xs_follow_up_on'));
   const customAmount=Number(value('xs_expected'))!==3000;
   visible('xs_wrap_notes',waived||partial||pending||customAmount);
   $('xs_notes_label').textContent=waived?'Waiver note *':customAmount?'Amount adjustment note *':'Notes';
   $('xs_wrap_reason').querySelector('label').textContent=pending?'Reason no deduction was made *':'Reason for partial deduction *';
   const b=M.balances({expected:Number(value('xs_expected')||0),deducted:Number(value('xs_deducted')||0),deposited:Number(value('xs_deposited')||0),outcome});
   $('xs_balance').textContent=`Deduction outstanding: ৳${b.outstanding.toFixed(2)}   ·   Deposit pending: ৳${b.depositPending.toFixed(2)}`;
  }
  if(!tenure)syncButton(error||'Select a valid joining and Exit Date.');
  else syncButton();
 }
 function choose(){
  const type=value('xs_outcome');
  const old=editing?.settlement;
  if(old&&Number(old.deposited)>0&&['pending','waived'].includes(type)){
   $('xs_outcome').value=old.outcome;g.toast('Correct the recorded deposit before changing this status.','warning');return;
  }
  if($('xs_deducted'))$('xs_deducted').value=type==='collected'?value('xs_expected'):type==='partial'?(Number(value('xs_deducted'))<Number(value('xs_expected'))?value('xs_deducted'):''): '0';
  if(type==='pending'&&!value('xs_reason'))$('xs_reason').value='payroll_pending';
  if(type==='collected'&&!value('xs_deducted_on'))$('xs_deducted_on').value=stamp();
  update();
 }
 function toggleOptional(){
  if(!dates().exit)return;
  const tenure=M.tenure(dates().join,dates().exit);
  if(tenure.defaultEnabled||Number(editing?.settlement?.deducted)>0){$('xs_enabled').checked=true;return update();}
  if(!$('xs_enabled').checked){$('xs_outcome').value='';$('xs_override_reason').value='';}
  update();
 }
 function toggleDeposit(){if(!$('xs_deposit_now').checked){for(const k of ['deposited','deposited_on','receipt_no','deposited_to'])$('xs_'+k).value=k==='deposited'?'0':'';}update();}
 function bindShortcuts(){
  if(g.__mgExitShortcutsBound)return;
  g.__mgExitShortcutsBound=true;
  document.addEventListener('keydown',function(event){
   const page=$('page-exit');if(!page||!page.getClientRects||!page.getClientRects().length)return;
   if(event.altKey&&!event.ctrlKey&&!event.metaKey){
    const key=String(event.key||'');const id=(editing?{'2':'xe_exit_reason','3':'xe_exit_date','4':'xs_outcome'}:{'1':'exEmp','2':'exReason','3':'exDate','4':'xs_outcome'})[key];
    if(id&&$(id)&&!$(id).closest?.('[hidden]')){event.preventDefault();$(id).focus();}
   }else if((event.ctrlKey||event.metaKey)&&event.key==='Enter'){
    event.preventDefault();if(editing)saveEdit();else submit();
   }
  });
 }
 function reset(clearValues=false){
  requestId=null;requestFingerprint='';editing=null;busy=false;
  bindShortcuts();
  if(clearValues){textFields.forEach(k=>{const el=$('xs_'+k);if(el)el.value=({expected:'3000',deducted:'0',deposited:'0',follow_up_time:'09:00'})[k]||'';});if($('xs_deposit_now'))$('xs_deposit_now').checked=false;}
  if($('exReason')&&!$('exReason').dataset.exitDecisionBound){$('exReason').addEventListener('change',()=>reasonChanged());$('exReason').dataset.exitDecisionBound='yes';}reasonChanged();
  update(true);
 }
 async function refresh(){
  if(g.MGHRM?.reloadExits)g.DATA.exits=await g.MGHRM.reloadExits();
  if(typeof g.fetchEmployeesDirectly==='function')await g.fetchEmployeesDirectly();
  if(typeof g.phase2RefreshTransferState==='function')await g.phase2RefreshTransferState();
 }
 function submit(){
  if(busy||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  let emp,settlement,payload;
  try{
   emp=g.findEmp(value('exEmp'));if(!emp?.id||String(emp.Status||emp.status)!=='Active')throw Error('Select an active employee.');
   const reason=reasonText();settlement=collect();
   const tc=g.__exitFromTransferContext;
   payload={employee_sys_id:emp.id,exit_reason:reason,exit_date:value('exDate'),issue_date:value('exIssue')||stamp(),related_transfer_id:tc&&String(tc.employeeSysId)===String(emp.id)?Number(tc.transferId):null};
  }catch(err){update();warning(err.message);return;}
  const fingerprint=JSON.stringify([payload,settlement]);
  if(fingerprint!==requestFingerprint){requestId=null;requestFingerprint=fingerprint;}
  const confirmText=settlement.enabled?'Confirm this exit and save its confidential deduction decision?':'Confirm this exit without deduction tracking (one year completed)?';
  g.mtCustomConfirm('Employee Exit',confirmText,'danger',async()=>{
   if(busy)return;busy=true;requestId=requestId||crypto.randomUUID();
   const button=$('btnSubmitExit');if(button){button.disabled=true;button.textContent='Saving…';}
   let committed=false;
   try{
    await g.ExitService.submit(payload,settlement,requestId);committed=true;g.__exitFromTransferContext=null;
    try{await refresh();}catch(_){g.toast('Exit saved. Refresh to see the latest records.','warning');return;}
    g.closeModal();g.toast('Exit and deduction decision saved.','success');g.renderExit();if(g.renderEmpTable)g.renderEmpTable();
   }catch(err){g.toast((committed?'Saved; refresh required. ':'Save not confirmed; retry unchanged values if necessary. ')+err.message,'error');}
   finally{busy=false;if(button){button.textContent='Mark as Inactive';update();}}
  });
 }
 function storedDate(raw){try{return joiningDate(raw);}catch(_){return '';}}
 function original(row){return {exit_date:row.exit_date,issue_date:row.issue_date,exit_reason:row.exit_reason};}
 function onModalClose(){
  editorGeneration++;editing=null;
  if(document.getElementById('xe_scope')||document.getElementById('exit-history')){
   const body=document.getElementById('modalBody');if(body)body.replaceChildren();
  }
 }
 function cancelEdit(){if(busy)return;g.closeModal();onModalClose();}
 async function edit(id){
  if(busy||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  const generation=++editorGeneration;
  try{
   const rows=await g.ExitService.report(null,null,id),row=rows[0];
   if(generation!==editorGeneration)return;
   if(!row)throw Error('Exit record not found.');editing=row;
   g.openModal('Exit Details & Deduction',`<section class="exit-editor" id="exit-editor">
    <div class="exit-editor-person"><strong>${esc(row.full_name)}</strong><span>${esc(row.designation||'')} · ${esc(row.current_project||'')}</span></div>
    <div class="form-grid">
     <div class="field"><label for="xe_exit_date">Exit date *</label><input id="xe_exit_date" type="date" value="${esc(storedDate(row.exit_date))}" oninput="ExitUI.update()"></div>
     <div class="field"><label for="xe_issue_date">Issue date *</label><input id="xe_issue_date" type="date" value="${esc(row.issue_date?storedDate(row.issue_date):stamp())}"></div>
     <div class="field wide"><label for="xe_exit_reason">Exit reason *</label><input id="xe_exit_reason" maxlength="1000" value="${esc(row.exit_reason||'')}"></div>
    </div>${html(true)}
    <div class="field"><label for="xe_change">Change note</label><input id="xe_change" maxlength="1000" placeholder="Optional"></div>
    </section>`,
    `<button type="button" class="btn primary" id="xe_save" onclick="ExitUI.saveEdit()">Save changes</button><button type="button" class="btn" onclick="ExitUI.history(${Number(id)})">History</button><button type="button" class="btn" onclick="ExitUI.profile()">Employee profile</button><button type="button" class="btn" onclick="ExitUI.cancelEdit()">Close</button>`);
   const saved=row.settlement;
   $('xs_enabled').checked=!!saved?.enabled;
   textFields.forEach(k=>{if($('xs_'+k))$('xs_'+k).value=saved?.[k]??({expected:'3000',deducted:'0',deposited:'0',follow_up_time:'09:00'})[k]??'';});
   // Keep the saved HH:MM time, and never touch the create-exit form.
   $('xs_follow_up_time').value=String(saved?.follow_up_time||'09:00').slice(0,5);
   $('xs_deposit_now').checked=Number(saved?.deposited)>0;
   update();
  }catch(err){if(generation===editorGeneration)g.toast(err.message,'error');}
 }
 async function saveEdit(){
  if(busy||!editing||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  const row=editing,generation=editorGeneration;
  let settlement,payload;
  try{
   settlement=collect();payload={exit_date:value('xe_exit_date'),issue_date:value('xe_issue_date'),exit_reason:value('xe_exit_reason').trim()};
   M.date(payload.issue_date);if(payload.issue_date<payload.exit_date)throw Error('Issue date cannot precede exit date.');
   if(!payload.exit_reason)throw Error('Enter the exit reason.');
   if(row.settlement&&(Number(row.settlement.deducted)>0||Number(row.settlement.deposited)>0)&&!settlement.enabled)throw Error('Keep recorded deduction enabled when changing exit dates.');
  }catch(err){g.toast(err.message,'error');return;}
  busy=true;const button=document.getElementById('xe_save');if(button){button.disabled=true;button.textContent='Saving…';}
  let committed=false;
  try{
   await g.ExitService.update(row.exit_id,payload,settlement,row.settlement?.version||0,original(row),value('xe_change'));committed=true;
   await refresh();
   if(generation===editorGeneration){g.closeModal();onModalClose();}
   if(g.renderExitTable)g.renderExitTable();
   if(privateVisible)await loadPrivate();
   if(g.ExitReports)g.ExitReports.reloadIfVisible();
   if(g.MGHRM?.reloadTodos){g.DATA.todos=await g.MGHRM.reloadTodos();if(g.renderTodo)g.renderTodo();}
   g.toast('Exit updated.','success');
  }catch(err){g.toast(committed?'Saved. Refresh to load updated records.':err.message,'error');}
  finally{busy=false;if(button){button.disabled=false;button.textContent='Save changes';}}
 }
 function profile(){const id=editing?.employee_sys_id;if(!id)return;g.closeModal();onModalClose();if(g.openEmpDetail)g.openEmpDetail(String(id));}
 async function openFollowup(todoId,quiet=false){
  const generation=++editorGeneration;
  try{const id=await g.ExitService.followup(todoId);if(generation!==editorGeneration)return quiet;if(!id){if(quiet)return false;throw Error('Linked exit not found.');}if(g.navigate)g.navigate('exit');await edit(id);return true;}
  catch(err){if(!quiet)g.toast(err.message,'error');return false;}
 }
 function leavePage(){clearPrivate();onModalClose();}
 function privateHeaders(){return privateVisible?'<th>Deduction</th><th>Deducted ৳</th><th>Remaining ৳</th><th>Follow-up</th>':'';}
 function tableCells(id){
  if(!privateVisible)return '';
  const s=privateRows.get(String(id)),b=M.balances(s);
  return `<td>${esc(s?M.outcomes[s.outcome]:'Not recorded')}</td><td>${s?esc(s.deducted):'—'}</td><td>${b?esc(b.outstanding)+(b.depositPending>0?`<small>Deposit: ${esc(b.depositPending)}</small>`:''):'—'}</td><td>${esc(s?.follow_up_on?(s.follow_up_on+' '+String(s.follow_up_time||'09:00').slice(0,5)):'—')}</td>`;
 }
 function drawPrivate(){
  const head=document.getElementById('exitPrivateHeaders');if(head)head.innerHTML='<tr><th>#</th><th>ID</th><th>Name</th><th>Designation</th><th>Project</th><th>Exit Date</th><th>Reason</th>'+privateHeaders()+'<th>Action</th></tr>';
  const button=document.getElementById('exitPrivateToggle');if(button){button.textContent=privateVisible?'Hide confidential details':'Show confidential details';button.setAttribute('aria-pressed',String(privateVisible));}
  if(g.renderExitTable)g.renderExitTable();
 }
 async function loadPrivate(){
  const generation=++privateGeneration;
  const rows=await g.ExitService.report('0001-01-01','9999-12-31');
  if(generation!==privateGeneration||!privateVisible)return;
  privateRows.clear();rows.forEach(r=>privateRows.set(String(r.exit_id),r.settlement));drawPrivate();
 }
 async function togglePrivate(){
  if(privateVisible){clearPrivate();return;}
  if(typeof g.guardEdit==='function'&&!g.guardEdit())return;
  privateVisible=true;
  try{await loadPrivate();}catch(err){clearPrivate();g.toast(err.message,'error');}
 }
 function clearPrivate(){privateVisible=false;privateGeneration++;privateRows.clear();drawPrivate();}
 async function history(id){
  if(busy)return;
  try{const rows=await g.ExitService.history(id);
   g.openModal('Exit — Change History',`<div id="exit-history">${rows.map(r=>{
    const before=r.before_data?.exit_details,after=r.after_data?.exit_details;
    return `<div class="card" style="padding:12px;margin-bottom:10px"><strong>${esc(r.recorded_at)}</strong><p>${esc(r.change_note)}</p><p>Due ৳${esc(r.after_data.expected)} · Deducted ৳${esc(r.after_data.deducted)} · Deposited ৳${esc(r.after_data.deposited)}</p>${after?`<p>Exit: ${esc(before?.exit_date||'—')} → ${esc(after.exit_date)} · Issue: ${esc(after.issue_date)}</p><p>${esc(after.exit_reason)}</p>`:''}</div>`;
   }).join('')||'<p>No recorded history.</p>'}</div>`,`<button type="button" class="btn" onclick="ExitUI.edit(${Number(id)})">Back</button><button type="button" class="btn" onclick="closeModal()">Close</button>`);
  }catch(err){g.toast(err.message,'error');}
 }
 g.ExitUI=Object.freeze({html,update,reset,collect,submit,edit,saveEdit,history,today:stamp,choose,toggleOptional,toggleDeposit,reasonSelect,reasonText,reasonChanged,focusMissing,exitReasons,onModalClose,cancelEdit,profile,openFollowup,leavePage,joiningDate,togglePrivate,clearPrivate,tableCells});
})(window);