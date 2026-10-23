/* Explicit confidential report route. Never enriches DATA.exits or ordinary exports. */
(function(g){
 'use strict';
 const M=g.ExitModel,esc=v=>g.escapeHtml(String(v??''));
 const title='Exit Deduction & Deposit Report (Confidential)';
 let generation=0,visible=false,records=[],context=null,outcome='',query='';
 const amount=v=>Number(v).toFixed(2);
 function clear(){generation++;visible=false;records=[];context=null;}
 function day(ms){const d=new Date(ms);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
 function matches(r){
  const s=r.settlement,b=M.balances(s);
  if(outcome==='unrecorded'&&s||outcome==='deposit_pending'&&(!b||b.depositPending<=0)||outcome==='outstanding'&&(!b||b.outstanding<=0))return false;
  if(outcome&&!['unrecorded','deposit_pending','outstanding'].includes(outcome)&&s?.outcome!==outcome)return false;
  return !query||[r.full_name,r.employee_id,s?.receipt_no,s?.deposited_to].some(v=>String(v||'').toLowerCase().includes(query));
 }
 function filtered(){return records.filter(matches);}
 const headers=['Employee / Project','Joining / Exit / Service','Outcome','Expected ৳','Deducted ৳','Outstanding ৳','Deposited ৳','Deposit pending ৳','Dates / Receipt / Recipient','Reason / Authority / Notes','Override / Follow-up'];
 function cells(r){
  const s=r.settlement,b=M.balances(s);let service='Invalid / missing joining date';try{const t=M.tenure(r.join_date,r.exit_date);service=`${t.days} days / ${t.years} completed year(s)`;}catch(_){}
  return [
   `${r.employee_id||'—'} · ${r.full_name||''}\n${r.designation||''}\n${r.current_project||''}`,
   `Joined: ${r.join_date||'—'}\nExit: ${r.exit_date||'—'}\n${service}`,
   s?M.outcomes[s.outcome]:'Not recorded',
   s?amount(s.expected):'—',s?amount(s.deducted):'—',b?amount(b.outstanding):'—',s?amount(s.deposited):'—',b?amount(b.depositPending):'—',
   s?`Deducted: ${s.deducted_on||'—'}\nDeposited: ${s.deposited_on||'—'}\nReceipt: ${s.receipt_no||'—'}\nTo: ${s.deposited_to||'—'}`:'—',
   s?[M.reasons[s.reason]||'',s.approved_by?'Authority: '+s.approved_by:'',s.notes||''].filter(Boolean).join('\n'):'—',
   s?[s.override_reason?'Override: '+s.override_reason:'',s.follow_up_on?'Follow-up: '+s.follow_up_on:''].filter(Boolean).join('\n'):'—'
  ];
 }
 function body(print=false){
  const rows=filtered(),recorded=rows.filter(r=>r.settlement),totals=recorded.reduce((a,r)=>{const s=r.settlement,b=M.balances(s);a.expected+=Number(s.expected);a.deducted+=Number(s.deducted);a.deposited+=Number(s.deposited);a.outstanding+=b.outstanding;a.depositPending+=b.depositPending;if(s.outcome==='waived')a.waived+=Number(s.expected);return a;},{expected:0,deducted:0,deposited:0,outstanding:0,depositPending:0,waived:0});
  return `<div class="exit-private-warning">CONFIDENTIAL — Internal authorized use only. Contains restricted financial records.</div>
   <p>${esc(context?.label||'')} · ${rows.length} exits · ${rows.length-recorded.length} not recorded${outcome?' · Filter: '+esc(outcome):''}${query?' · Search: '+esc(query):''}</p>
   <p>Expected ৳${amount(totals.expected)} · Deducted ৳${amount(totals.deducted)} · Waived ৳${amount(totals.waived)} · Outstanding ৳${amount(totals.outstanding)} · Deposited ৳${amount(totals.deposited)} · Deposit pending ৳${amount(totals.depositPending)}</p>
   <p class="small-mute">Totals include recorded entries only. Waived amounts are excluded from outstanding. Missing historical data is not evidence of non-deduction.</p>
   <div class="table-wrap"><table class="exit-private-table"><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}${print?'':'<th>Record</th>'}</tr></thead><tbody>${rows.map(r=>`<tr>${cells(r).map(v=>`<td>${esc(v).replace(/\n/g,'<br>')}</td>`).join('')}${print?'':`<td><button class="btn sm" onclick="ExitUI.edit(${Number(r.exit_id)})">${r.settlement?'Update':'Record'}</button></td>`}</tr>`).join('')||`<tr><td colspan="${headers.length+(print?0:1)}">No exits match these filters.</td></tr>`}</tbody></table></div>`;
 }
 function draw(){if(visible&&document.getElementById('exitPrivateBody'))document.getElementById('exitPrivateBody').innerHTML=body();}
 async function show(ctx){
  clear();visible=true;context=ctx;const token=generation;
  const target=document.getElementById('reportOutput');
  target.innerHTML=`<div class="card"><div class="card-header"><h3>${title}</h3><div class="btn-row"><button id="xs_export" class="btn sm" disabled onclick="ExitReports.exportCSV()">CSV / Excel</button><button id="xs_print" class="btn sm" disabled onclick="ExitReports.print()">Print / PDF</button></div></div><div class="card-body"><div class="exit-private-toolbar"><select aria-label="Settlement filter" id="xs_report_filter" onchange="ExitReports.filter(this.value)"><option value="">All outcomes</option>${Object.entries(M.outcomes).map(([k,v])=>`<option value="${k}" ${k===outcome?'selected':''}>${esc(v)}</option>`).join('')}<option value="unrecorded" ${outcome==='unrecorded'?'selected':''}>Not recorded</option><option value="deposit_pending" ${outcome==='deposit_pending'?'selected':''}>Deposit pending</option><option value="outstanding" ${outcome==='outstanding'?'selected':''}>Deduction outstanding</option></select><input aria-label="Search confidential exits" placeholder="Name, employee ID, receipt, recipient" value="${esc(query)}" oninput="ExitReports.search(this.value)"><button class="btn sm" onclick="ExitReports.reloadIfVisible()">Refresh</button></div><div id="exitPrivateBody" style="margin-top:14px" aria-live="polite">Loading confidential records…</div></div></div>`;
  try{
   if(!Number.isFinite(ctx.start)||!Number.isFinite(ctx.end)||ctx.start>=ctx.end)throw Error('Choose a valid report date range.');
   const rows=await g.ExitService.report(day(ctx.start),day(ctx.end-1));
   if(token!==generation||!visible)return;
   records=rows.filter(r=>g.reportMatches({CurrentProject:r.current_project,Designation:r.designation,Status:r.employee_status},ctx,['CurrentProject'],['Designation']));
   draw();document.getElementById('xs_export').disabled=false;document.getElementById('xs_print').disabled=false;
  }catch(err){if(token===generation&&visible)document.getElementById('exitPrivateBody').textContent='Could not load confidential report: '+err.message;}
 }
 function print(){if(!visible||!context)return;g.openPrint(g.mrepShell2({title,subtitle:esc(context.label),meta:'CONFIDENTIAL · Internal authorized use only',landscape:true,body:body(true)}),title);}
 const safeCSV=v=>{const text=String(v??'');return '"'+(/^[\s]*[=+\-@]/.test(text)?"'":'')+text.replace(/"/g,'""')+'"';};
 function exportCSV(){
  if(!visible||!context)return;
  // Full details use individual columns in Excel; every cell is formula-safe.
  const csvHeaders=['CONFIDENTIAL — Internal authorized use only','Employee ID','Name','Designation','Project','Join date','Exit date','Outcome','Expected','Deducted','Outstanding','Waived','Deposited','Deposit pending','Deduction date','Deposit date','Receipt','Deposited to','Reason','Waiver authority','Notes','Manual override reason','Follow-up date'];
  const data=filtered().map(r=>{const s=r.settlement,b=M.balances(s);return ['CONFIDENTIAL',r.employee_id,r.full_name,r.designation,r.current_project,r.join_date,r.exit_date,s?M.outcomes[s.outcome]:'Not recorded',s?.expected??'',s?.deducted??'',b?.outstanding??'',s?.outcome==='waived'?s.expected:0,s?.deposited??'',b?.depositPending??'',s?.deducted_on,s?.deposited_on,s?.receipt_no,s?.deposited_to,M.reasons[s?.reason]||'',s?.approved_by,s?.notes,s?.override_reason,s?.follow_up_on];});
  const csv=[csvHeaders,...data].map(row=>row.map(safeCSV).join(',')).join('\r\n');
  const url=URL.createObjectURL(new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8'})),a=document.createElement('a');a.href=url;a.download=`CONFIDENTIAL_exit_deduction_deposit_${day(context.start)}_${day(context.end-1)}.csv`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }
 g.ExitReports=Object.freeze({title,show,clear,print,exportCSV,filter:v=>{outcome=v;draw();},search:v=>{query=String(v).trim().toLowerCase();draw();},reloadIfVisible:()=>{if(visible)show(g.getReportFilterContext());}});
})(window);
