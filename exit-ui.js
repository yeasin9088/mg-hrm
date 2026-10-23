/* Progressive confidential deduction decision inside the Employee Exit Process form. */
(function(g){
 'use strict';
 const M=g.ExitModel,$=id=>document.getElementById(id),esc=v=>g.escapeHtml(String(v??''));
 let requestId=null,requestFingerprint='',busy=false,editing=null;
 const textFields=['override_reason','expected','deducted','deposited','outcome','reason','deducted_on','deposited_on','receipt_no','deposited_to','approved_by','notes','follow_up_on'];
 const stamp=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
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
 function html(){return `<div class="exit-confidential" id="xs_scope" hidden aria-label="Confidential exit deduction decision">
  <div class="exit-section-heading"><span class="exit-private-mark" aria-hidden="true">◈</span><span>Deduction Decision <small>Confidential · Employee Exit Process</small></span></div>
  <p id="xs_tenure" class="exit-service-note"></p>
  <div id="xs_optional" class="exit-optional-track" hidden><label class="exit-switch-label"><input type="checkbox" id="xs_enabled" onchange="ExitUI.toggleOptional()"><span>Include deduction tracking for this employee</span></label><p class="exit-muted">The first service anniversary has passed. Tracking is optional.</p></div>
  <div id="xs_required" class="exit-required-note" hidden>Deduction decision required for employees with less than one completed year of service.</div>
  <div id="xs_override_wrap" class="field" hidden><label for="xs_override_reason">Reason for exceptional deduction tracking *</label><input id="xs_override_reason" maxlength="1000" oninput="ExitUI.update()" placeholder="Why is a deduction decision required after one year?"></div>
  <div id="xs_decision_area" hidden>
   <div class="field exit-decision-field"><label for="xs_outcome">Deduction decision *</label><select id="xs_outcome" onchange="ExitUI.choose()"><option value="">— Select deduction decision —</option><option value="collected">Full deduction</option><option value="partial">Partial deduction</option><option value="pending">Not deducted — record reason</option><option value="waived">Approved waiver — authorized decision</option></select></div>
   <div id="xs_detail" class="exit-conditional-details" hidden>
    <div class="form-grid">
     ${field('expected','Expected amount (৳) *','number','3000')}
     <div class="field" id="xs_wrap_deducted" hidden><label for="xs_deducted">Amount deducted (৳) *</label><input id="xs_deducted" type="number" step="0.01" min="0" oninput="ExitUI.update()"></div>
     ${field('deducted_on','Deduction date *','date')}
     <div class="field" id="xs_wrap_reason"><label for="xs_reason">Reason for deduction shortfall *</label><select id="xs_reason" onchange="ExitUI.update()"><option value="">— Select reason —</option>${Object.entries(M.reasons).filter(([k])=>k!=='special_waiver').map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('')}</select></div>
     ${field('approved_by','Waiver approved by *','text','','maxlength="200"')}
     <div class="field" id="xs_wrap_deposit_toggle" hidden><label class="exit-switch-label"><input type="checkbox" id="xs_deposit_now" onchange="ExitUI.toggleDeposit()">Record deposited money now</label><p class="exit-muted">Deducted and deposited amounts are recorded separately.</p></div>
     <div class="exit-deposit-group field wide" id="xs_deposit_group" hidden><div class="exit-subtitle">Deposit evidence</div><div class="form-grid">
      ${field('deposited','Amount deposited (৳) *','number','0')}
      ${field('deposited_on','Deposit date *','date')}
      ${field('receipt_no','Receipt / voucher number *','text','','maxlength="150"')}
      ${field('deposited_to','Deposited to / received by *','text','','maxlength="200"')}
     </div></div>
     ${field('follow_up_on','Next follow-up date (optional)','date')}
     <div class="field wide" id="xs_wrap_notes"><label for="xs_notes" id="xs_notes_label">Additional notes</label><textarea id="xs_notes" rows="2" maxlength="4000" oninput="ExitUI.update()" placeholder="Record relevant details or an approved exception"></textarea></div>
    </div>
    <div class="exit-balance" id="xs_balance" aria-live="polite"></div>
   </div>
  </div>
  <p class="exit-form-feedback" id="xs_feedback" role="status" aria-live="polite"></p>
  <p class="exit-muted">A deduction decision records the settlement; it does not debit payroll. Financial details stay out of the ordinary Monthly Exit Report.</p>
 </div>`;}
 function dates(){
  if(editing)return {join:editing.join_date,exit:editing.exit_date};
  const e=g.findEmp($('exEmp')?.value);return {join:e?.JoinDate||e?.join_date||'',exit:$('exDate')?.value||''};
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
  if(!['partial','pending'].includes(kind))raw.follow_up_on='';
  return M.validate(raw,d.join,d.exit,stamp());
 }
 function syncButton(reason){
  if(editing)return;
  const button=$('btnSubmitExit');if(!button)return;
  let message=reason||'';
  if(!message){
   try{if(!g.findEmp(value('exEmp'))?.id)throw Error('Select an employee.');
    reasonText();collect();}
   catch(err){message=err.message;}
  }
  button.disabled=busy;button.title=message||'';button.setAttribute?.('aria-describedby','xs_feedback');button.dataset.needsAttention=message?'true':'false';
  const feedback=$('xs_feedback');if(feedback)feedback.textContent=message||'Decision complete. You can confirm the employee exit.';
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
  const hasExit=!!dates().exit;
  visible('xs_scope',hasExit);if(!hasExit){syncButton('Choose an Exit Date first.');return;}
  visible('xs_optional',!!tenure&&!tenure.defaultEnabled);
  visible('xs_required',!!tenure&&tenure.defaultEnabled);
  const enabled=!!tenure&&(tenure.defaultEnabled||!!$('xs_enabled')?.checked);
  if($('xs_enabled'))$('xs_enabled').checked=enabled;
  visible('xs_override_wrap',enabled&&!tenure.defaultEnabled);
  visible('xs_decision_area',enabled);
  const outcome=value('xs_outcome');
  visible('xs_detail',enabled&&!!outcome);
  if(tenure){$('xs_tenure').textContent=`Service: ${tenure.days} days · First anniversary: ${tenure.firstAnniversary} · ${tenure.defaultEnabled?'Decision required':'Deduction not normally applicable'}`;}
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
   visible('xs_wrap_follow_up_on',partial||pending);
   const customAmount=Number(value('xs_expected'))!==3000;
   visible('xs_wrap_notes',waived||partial||pending||customAmount);
   $('xs_notes_label').textContent=waived?'Approved waiver details / decision notes *':customAmount?'Reason for adjusted expected amount *':'Additional notes (optional)';
   $('xs_wrap_reason').querySelector('label').textContent=pending?'Reason no deduction was made *':'Reason for partial deduction *';
   const b=M.balances({expected:Number(value('xs_expected')||0),deducted:Number(value('xs_deducted')||0),deposited:Number(value('xs_deposited')||0),outcome});
   $('xs_balance').textContent=`Deduction outstanding: ৳${b.outstanding.toFixed(2)}   ·   Deposit pending: ৳${b.depositPending.toFixed(2)}`;
  }
  if(!tenure)syncButton(error||'Select a valid joining and Exit Date.');
  else syncButton();
 }
 function choose(){
  const type=value('xs_outcome');
  if($('xs_deducted'))$('xs_deducted').value=type==='collected'?value('xs_expected'):'';
  if($('xs_deposit_now'))$('xs_deposit_now').checked=false;
  for(const k of ['deposited','deposited_on','receipt_no','deposited_to','deducted_on','reason','approved_by','follow_up_on']){
   if($('xs_'+k))$('xs_'+k).value=k==='deposited'?'0':'';
  }
  if(type==='pending'||type==='waived')$('xs_deducted').value='0';
  update();
 }
 function toggleOptional(){
  if(!dates().exit)return;
  const tenure=M.tenure(dates().join,dates().exit);
  if(tenure.defaultEnabled){$('xs_enabled').checked=true;return update();}
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
    const key=String(event.key||'');const id=({'1':'exEmp','2':'exReason','3':'exDate','4':'xs_outcome'})[key];
    if(id&&$(id)&&!$(id).closest?.('[hidden]')){event.preventDefault();$(id).focus();}
   }else if((event.ctrlKey||event.metaKey)&&event.key==='Enter'){
    event.preventDefault();submit();
   }
  });
 }
 function reset(clearValues=false){
  requestId=null;requestFingerprint='';editing=null;busy=false;
  bindShortcuts();
  if(clearValues){textFields.forEach(k=>{const el=$('xs_'+k);if(el)el.value=({expected:'3000',deducted:'0',deposited:'0'})[k]||'';});if($('xs_deposit_now'))$('xs_deposit_now').checked=false;}
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
 async function edit(id){
  if(typeof g.guardEdit==='function'&&!g.guardEdit())return;
  try{
   const rows=await g.ExitService.report(null,null,id),row=rows[0];if(!row)throw Error('Completed exit not found.');editing=row;
   g.openModal('Confidential — Exit Deduction & Deposit',`<p>${esc(row.full_name)} · ${esc(row.employee_id)} · Exit ${esc(row.exit_date)}</p><div class="form-grid">${html()}</div><div class="field"><label for="xs_change">Correction / recording reason *</label><textarea id="xs_change" maxlength="1000"></textarea></div>`,`<button class="btn primary" id="xs_save" onclick="ExitUI.saveEdit()">Save confidential record</button><button class="btn" onclick="ExitUI.history(${Number(id)})">History</button><button class="btn" onclick="closeModal()">Close</button>`);
   // update without resetting the stored decision, then hydrate the existing record.
   update();
   if(row.settlement){
    $('xs_enabled').checked=!!row.settlement.enabled;
    textFields.forEach(k=>{if($('xs_'+k))$('xs_'+k).value=row.settlement[k]??'';});
    $('xs_deposit_now').checked=Number(row.settlement.deposited)>0;
   }else{ $('xs_enabled').checked=M.tenure(row.join_date,row.exit_date).defaultEnabled;$('xs_outcome').value=''; }
   update();
  }catch(err){g.toast(err.message,'error');}
 }
 async function saveEdit(){
  if(busy||!editing||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  let settlement;try{settlement=collect();if(!value('xs_change').trim())throw Error('Explain this recording or correction.');}catch(err){return g.toast(err.message,'error');}
  busy=true;if($('xs_save'))$('xs_save').disabled=true;
  try{await g.ExitService.save(editing.exit_id,settlement,editing.settlement?.version||0,value('xs_change').trim());g.closeModal();editing=null;g.toast('Confidential record saved.','success');if(g.ExitReports)g.ExitReports.reloadIfVisible();}
  catch(err){g.toast(err.message,'error');}finally{busy=false;if($('xs_save'))$('xs_save').disabled=false;}
 }
 async function history(id){
  try{const rows=await g.ExitService.history(id);
   g.openModal('Confidential — Settlement History',`<div class="exit-private-warning">CONFIDENTIAL — Internal authorized use only</div>${rows.map(r=>`<div class="card" style="padding:12px"><strong>Version ${r.version} · ${esc(r.recorded_at)}</strong><p>${esc(r.change_note)}</p><p>Expected ৳${esc(r.after_data.expected)} · Deducted ৳${esc(r.after_data.deducted)} · Deposited ৳${esc(r.after_data.deposited)}</p><details><summary>Full saved details</summary><pre style="white-space:pre-wrap;overflow-wrap:anywhere">${esc(JSON.stringify(r.after_data,null,2))}</pre></details></div>`).join('')||'<p>No recorded history.</p>'}`,`<button class="btn" onclick="ExitUI.edit(${Number(id)})">Back to record</button><button class="btn" onclick="closeModal()">Close</button>`);
  }catch(err){g.toast(err.message,'error');}
 }
 g.ExitUI=Object.freeze({html,update,reset,collect,submit,edit,saveEdit,history,today:stamp,choose,toggleOptional,toggleDeposit,reasonSelect,reasonText,reasonChanged,focusMissing,exitReasons});
})(window);