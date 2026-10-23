/* Exit form and confidential settlement editor. Existing public reports never call these. */
(function(g){
 'use strict';
 const M=g.ExitModel,$=id=>document.getElementById(id),esc=v=>g.escapeHtml(String(v??''));
 let requestId=null,busy=false,editing=null;
 const textFields=['override_reason','expected','deducted','deposited','outcome','reason','deducted_on','deposited_on','receipt_no','deposited_to','approved_by','notes','follow_up_on'];
 function today(){return new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());}
 function field(key,label,type='text',value=''){
  return `<div class="field"><label for="xs_${key}">${label}</label><input id="xs_${key}" type="${type}" value="${esc(value)}" ${type==='number'?'min="0" max="100000000" step="0.01"':''} oninput="ExitUI.update()"></div>`;
 }
 function html(){return `<section class="exit-confidential" aria-label="Confidential exit deduction">
  <h4>Confidential — Exit Deduction & Deposit</h4><p id="xs_tenure" class="small-mute">Select an employee and exit date to calculate service.</p>
  <label><input type="checkbox" id="xs_enabled" onchange="ExitUI.update()">Include deduction tracking</label>
  <div class="field" id="xs_override_wrap"><label for="xs_override_reason">Manual override reason *</label><input id="xs_override_reason" maxlength="1000"></div>
  <div id="xs_fields"><div class="form-grid" style="margin-top:12px">
   ${field('expected','Expected deduction (৳)','number',3000)}
   <div class="field"><label for="xs_outcome">Deduction outcome *</label><select id="xs_outcome" onchange="ExitUI.update()">${Object.entries(M.outcomes).filter(([k])=>k!=='not_applicable').map(([k,v])=>`<option value="${k}" ${k==='pending'?'selected':''}>${esc(v)}</option>`).join('')}</select></div>
   ${field('deducted','Actually deducted (৳)','number',0)}${field('deducted_on','Deduction date','date')}
   ${field('deposited','Actually deposited (৳)','number',0)}${field('deposited_on','Deposit date','date')}
   ${field('receipt_no','Deposit receipt / voucher number')}${field('deposited_to','Deposited to (person / department)')}
   <div class="field"><label for="xs_reason">Reason for missing / partial deduction</label><select id="xs_reason"><option value="">— Select reason —</option>${Object.entries(M.reasons).map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('')}</select></div>
   ${field('approved_by','Waiver authorized by')}${field('follow_up_on','Next follow-up date (optional)','date')}
   <div class="field wide"><label for="xs_notes">Notes / authority decision details</label><textarea id="xs_notes" rows="3" maxlength="4000"></textarea></div>
  </div><div class="exit-balance" id="xs_balance" aria-live="polite"></div></div>
  <p class="small-mute">Records actual deduction and deposit. Amounts are not automatically debited from payroll. Confidential details appear only in the separate confidential report.</p>
 </section>`;}
 function employeeDates(){
  if(editing)return {join:editing.join_date,exit:editing.exit_date};
  const e=g.findEmp($('exEmp')?.value);return {join:e?.JoinDate||e?.join_date||'',exit:$('exDate')?.value||''};
 }
 function update(reset=false){
  if(!$('xs_enabled'))return;
  const d=employeeDates();let t;
  try{t=M.tenure(d.join,d.exit);$('xs_tenure').textContent=`Service: ${t.days} days · ${t.years} completed year(s) · First anniversary: ${t.firstAnniversary}`;}
  catch(e){$('xs_tenure').textContent='Select valid joining and exit dates. '+e.message;}
  if(reset)$('xs_enabled').checked=t?.defaultEnabled||false;
  $('xs_enabled').disabled=!t;
  const enabled=$('xs_enabled').checked;
  $('xs_fields').hidden=!enabled;
  $('xs_override_wrap').hidden=!t||enabled===t.defaultEnabled;
  const s={expected:Number($('xs_expected').value)||0,deducted:Number($('xs_deducted').value)||0,deposited:Number($('xs_deposited').value)||0,outcome:$('xs_outcome').value};
  const b=M.balances(s);$('xs_balance').textContent=`Deduction outstanding: ৳${b.outstanding.toFixed(2)} · Deposit pending: ৳${b.depositPending.toFixed(2)}`;
 }
 function collect(){
  const d=employeeDates(),raw={enabled:$('xs_enabled')?.checked};
  textFields.forEach(k=>raw[k]=$('xs_'+k)?.value||'');
  return M.validate(raw,d.join,d.exit,today());
 }
 function reset(clearValues=false){
  requestId=null;editing=null;
  if(clearValues){textFields.forEach(k=>{if($('xs_'+k))$('xs_'+k).value=({expected:'3000',deducted:'0',deposited:'0',outcome:'pending'})[k]||'';});}
  update(true);
 }
 async function refresh(){
  if(g.MGHRM?.reloadExits)g.DATA.exits=await g.MGHRM.reloadExits();
  if(typeof g.fetchEmployeesDirectly==='function')await g.fetchEmployeesDirectly();
  if(typeof g.phase2RefreshTransferState==='function')await g.phase2RefreshTransferState();
 }
 function submit(){
  if(busy||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  let e,s,payload;
  try{
   e=g.findEmp($('exEmp')?.value);if(!e?.id||String(e.Status||e.status)!=='Active')throw Error('Select an active employee.');
   s=collect();const reason=$('exReason')?.value.trim();if(!reason)throw Error('Exit reason is required.');
   const tc=g.__exitFromTransferContext;
   payload={employee_sys_id:e.id,exit_reason:reason,exit_type:$('exType').value,exit_date:$('exDate').value,issue_date:$('exIssue').value||today(),related_transfer_id:tc&&String(tc.employeeSysId)===String(e.id)?Number(tc.transferId):null};
   requestId=requestId||crypto.randomUUID();
  }catch(err){return g.toast(err.message,'error');}
  busy=true;
  // Capture validated values before opening confirmation; the RPC commits all changes atomically.
  g.mtCustomConfirm('Employee Exit','Confirm exit and save the confidential deduction record?','danger',async()=>{
   if(busy)return;busy=true;
   const button=$('btnSubmitExit');if(button){button.disabled=true;button.textContent='Saving…';}
   let committed=false;
   try{
    await g.ExitService.submit(payload,s,requestId);committed=true;g.__exitFromTransferContext=null;
    try{await refresh();}catch(_){g.toast('Exit saved on the server. Refresh to reload the latest list.','warning');return;}
    g.closeModal();g.toast('Exit and confidential record saved.','success');g.renderExit();if(g.renderEmpTable)g.renderEmpTable();
   }catch(err){g.toast((committed?'Saved; refresh required. ':'Save not confirmed. Retry unchanged values to check safely. ')+err.message,'error');}
   finally{busy=false;if(button){button.disabled=false;button.textContent='Mark as Inactive';}}
  });
  // The confirmation owns no network work until Confirm is clicked; cancellation must allow retry.
  busy=false;
 }
 async function edit(id){
  if(typeof g.guardEdit==='function'&&!g.guardEdit())return;
  try{
   const rows=await g.ExitService.report(null,null,id);const row=rows[0];if(!row)throw Error('Completed exit not found.');editing=row;
   g.openModal('Confidential — Exit Deduction & Deposit',`<p>${esc(row.full_name)} · ${esc(row.employee_id)} · Exit ${esc(row.exit_date)}</p>${html()}<div class="field"><label for="xs_change">Correction / recording reason *</label><textarea id="xs_change" maxlength="1000"></textarea></div>`,`<button class="btn primary" id="xs_save" onclick="ExitUI.saveEdit()">Save confidential record</button><button class="btn" onclick="ExitUI.history(${Number(id)})">History</button><button class="btn" onclick="closeModal()">Close</button>`);
   update(true);
   if(row.settlement){$('xs_enabled').checked=row.settlement.enabled;textFields.forEach(k=>{if($('xs_'+k))$('xs_'+k).value=row.settlement[k]??'';});update();}
  }catch(err){g.toast(err.message,'error');}
 }
 async function saveEdit(){
  if(busy||!editing||typeof g.guardEdit==='function'&&!g.guardEdit())return;
  let s;try{s=collect();if(!$('xs_change').value.trim())throw Error('Explain this recording or correction.');}catch(err){return g.toast(err.message,'error');}
  busy=true;$('xs_save').disabled=true;
  try{await g.ExitService.save(editing.exit_id,s,editing.settlement?.version||0,$('xs_change').value.trim());g.closeModal();editing=null;g.toast('Confidential record saved.','success');if(g.ExitReports)g.ExitReports.reloadIfVisible();}
  catch(err){g.toast(err.message,'error');}finally{busy=false;if($('xs_save'))$('xs_save').disabled=false;}
 }
 async function history(id){
  try{const rows=await g.ExitService.history(id);
   g.openModal('Confidential — Settlement History',`<div class="exit-private-warning">CONFIDENTIAL — Internal authorized use only</div>${rows.map(r=>`<div class="card" style="padding:12px"><strong>Version ${r.version} · ${esc(r.recorded_at)}</strong><p>${esc(r.change_note)}</p><p>Expected ৳${esc(r.after_data.expected)} · Deducted ৳${esc(r.after_data.deducted)} · Deposited ৳${esc(r.after_data.deposited)}</p><details><summary>Full saved details</summary><pre style="white-space:pre-wrap;overflow-wrap:anywhere">${esc(JSON.stringify(r.after_data,null,2))}</pre></details></div>`).join('')||'<p>No recorded history.</p>'}`,`<button class="btn" onclick="ExitUI.edit(${Number(id)})">Back to record</button><button class="btn" onclick="closeModal()">Close</button>`);
  }catch(err){g.toast(err.message,'error');}
 }
 g.ExitUI=Object.freeze({html,update,reset,collect,submit,edit,saveEdit,history,today});
})(window);
