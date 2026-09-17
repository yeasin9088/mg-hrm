const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

html = html.replace(/function submitTransfer\(\)\{[\s\S]*?renderTransfer\(\);\n\}/, `async function submitTransfer(){
  if(!guardEdit()) return;
  const rid = document.getElementById('trEmp').value;
  const np = document.getElementById('trNew').value;
  const td = document.getElementById('trDate').value;
  if(!rid||!np||!td){ toast('Fill Employee, New Project, and Date', 'error'); return; }
  const e = assertActiveEmp(rid); if(!e) return;
  const isFuture = new Date(td)>new Date();
  const newId = Math.max(0,...DATA.transfers.map(t=>+t.TransferID))+1;
  const payload = {
    TransferID:String(newId), RecordID:e.RecordID, EmployeeID:e.EmployeeID,
    FullName:e.FullName, Designation:e.Designation,
    CurrentProject:e.ProjectName, NewProject:np, TransferDate:td,
    'Issues Date':document.getElementById('trIssue').value,
    Notes:document.getElementById('trNotes').value,
    IsProceed:isFuture?'0':'1', Status:isFuture?'Scheduled':'Recorded',
  };
  
  try {
    const btn = event && event.target ? event.target : document.getElementById('btnSubmitTransfer');
    if (btn) { btn.disabled = true; btn.innerHTML = 'Saving...'; }
    await window.MGHRM.insert('transfers', payload);
    if (btn) { btn.disabled = false; btn.innerHTML = 'Submit Transfer'; }
    
    toast(isFuture 
      ? 'Scheduled — employee project NOT changed (edit on Employees tab)'
      : 'Recorded in history — employee project NOT changed', 'success');
      
    renderTransfer();
  } catch (err) {
    const btn = event && event.target ? event.target : document.getElementById('btnSubmitTransfer');
    if (btn) { btn.disabled = false; btn.innerHTML = 'Submit Transfer'; }
    toast('Transfer failed to save: ' + err.message, 'error');
  }
}`);

html = html.replace(/function submitDisciplinary\(\)\{[\s\S]*?renderDisciplinary\(\);\n\}/, `async function submitDisciplinary(){
  if(!guardEdit()) return;
  const rid = document.getElementById('dcEmp').value;
  if(!rid){ toast('Select employee first','error'); return; }
  const e = assertActiveEmp(rid); if(!e) return;
  const type = document.getElementById('dcType').value;
  const newId = Math.max(0,...DATA.disciplinary.map(x=>+x.ActionID))+1;
  const payload = {
    ActionID:String(newId),
    RefNo:document.getElementById('dcRef').value,
    RecordID:e.RecordID, EmployeeID:e.EmployeeID,
    FullName:e.FullName, Designation:e.Designation, ProjectName:e.ProjectName,
    ActionType:DC_TEMPLATES[type].label.en,
    IncidentDate:document.getElementById('dcIncident').value,
    IssueDate:document.getElementById('dcIssue').value,
    Description:document.getElementById('dcDesc').value,
  };
  
  try {
    const btn = event && event.target ? event.target : document.getElementById('btnSubmitDisc');
    if (btn) { btn.disabled = true; btn.innerHTML = 'Saving...'; }
    await window.MGHRM.insert('disciplinary', payload);
    if (btn) { btn.disabled = false; btn.innerHTML = 'Submit Action'; }
    
    toast(DC_TEMPLATES[type].label.en + ' saved successfully', 'success');
    renderDisciplinary();
  } catch (err) {
    const btn = event && event.target ? event.target : document.getElementById('btnSubmitDisc');
    if (btn) { btn.disabled = false; btn.innerHTML = 'Submit Action'; }
    toast('Disciplinary action failed to save: ' + err.message, 'error');
  }
}`);

fs.writeFileSync('index.html', html);
console.log('Updated submitTransfer and submitDisciplinary to use async MGHRM.insert and English toasts.');
