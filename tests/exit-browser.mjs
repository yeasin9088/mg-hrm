// Isolated synthetic UI: actual production form/report functions, mocked server, no live app data.
import fs from 'node:fs/promises';import http from 'node:http';import path from 'node:path';
import assert from 'node:assert/strict';import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?require(path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright')):require('playwright');
const root=new URL('../',import.meta.url),html=await fs.readFile(new URL('index.html',root),'utf8');
function fn(name){const a=html.indexOf('function '+name+'(');assert(a>=0,name);const b=html.indexOf('\nfunction ',a+1);return html.slice(a,b<0?undefined:b);}
const css=[...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(x=>x[1]).join('\n');
const harness=`<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>${css}</style><link rel="stylesheet" href="/exit-ui.css"></head><body style="padding:12px"><div id="page-exit"></div><div id="page-reports"><div id="reportOutput"></div></div><div id="modal"><div id="modalBody"></div><div id="modalFooter"></div></div><script>
window.escapeHtml=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
window.todayISO=()=> '2026-10-23';window.num=v=>v;window.ico=()=>'';window.RTE_SVG={search:''};
window.EX_F={q:'',id:'',type:'',project:'',from:'',to:''};window.DATA={employees:[{id:1,EmployeeID:'SYN-1',FullName:'Synthetic Guard',Designation:'Guard',ProjectName:'Source',JoinDate:'2026-01-01',Status:'Active'}],projects:[],exits:[{ExitID:77,EmployeeID:'SYN-1',FullName:'Synthetic Guard',Designation:'Guard',CurrentProject:'Source',ExitDate:'2026-10-23',ExitReason:'Resigned',Status:'Completed'}]};
window.findEmp=()=>DATA.employees[0];window.fillEmpSelect=id=>document.getElementById(id).innerHTML='<option value="1">Synthetic Guard</option>';
window.renderExitTable=()=>{};window.exTypeOptions=()=>[];window.exProjectOptions=()=>[];window.guardEdit=()=>true;
window.toast=(message,type)=>{window.messages.push({message,type})};window.messages=[];window.calls=0;window.shouldFail=false;
window.mtCustomConfirm=(a,b,c,cb)=>{window.confirmCallback=cb;};window.closeModal=()=>document.getElementById('modal').classList.remove('open');
window.openModal=(title,body,footer)=>{document.getElementById('modalBody').innerHTML=body;document.getElementById('modalFooter').innerHTML=footer;document.getElementById('modal').classList.add('open');};
window.parseDate=v=>new Date(v);window.desig=v=>v;window.projName=v=>v;window.fmtDate=v=>v;window.isProjectActive=()=>true;
window.reportContext={start:new Date(2026,9,1).getTime(),end:new Date(2026,10,1).getTime(),label:'October 2026',mode:'month',project:'',designation:'',employeeStatus:'',projectScope:'all'};
window.getReportFilterContext=()=>window.reportContext;window.currentReport='exits';window.reportInRange=(v,c)=>new Date(v)>=c.start&&new Date(v)<c.end;
window.mrepShell2=o=>'<div class="print-doc mrep landscape"><h1>'+o.title+'</h1>'+o.body+'</div>';window.openPrint=v=>{window.printed=v;};window.MGHRM={reloadExits:async()=>DATA.exits};
window.sb={rpc:async(name,args)=>{
 if(name==='submit_exit_settlement'){window.calls++;await new Promise(r=>setTimeout(r,50));return shouldFail?{error:{message:'Synthetic server rejection'}}:{data:{exit_id:77}};}
 if(name==='get_exit_settlement_report')return {data:[{exit_id:77,employee_id:'SYN-1',full_name:'Synthetic Guard',designation:'Guard',current_project:'Source',join_date:'2026-01-01',exit_date:'2026-10-23',employee_status:'Inactive',settlement:{enabled:true,expected:3000,deducted:1000,deposited:500,outcome:'partial',reason:'salary_held',notes:'CONFIDENTIAL-SYNTHETIC <img src=x onerror=window.injected=true>',receipt_no:'=SYNTHETIC',deposited_to:'Accounts',version:1}},{exit_id:78,employee_id:'SYN-2',full_name:'Legacy Guard',designation:'Guard',current_project:'Source',join_date:'2024-01-01',exit_date:'2026-10-22',employee_status:'Inactive',settlement:null}]};
 return {data:[]};
}};
</script><script src="/exit-model.js"></script><script src="/exit-service.js"></script><script src="/exit-ui.js"></script><script src="/exit-reports.js"></script><script>${['renderExit','exFillEmp','getMonthlyReportRows','reportMatches','showReport','exportReport','printReport'].map(fn).join('\n')}
renderExit();
</script></body></html>`;
const server=http.createServer(async(req,res)=>{try{if(req.url==='/__exit-test'){res.setHeader('content-type','text/html');res.end(harness);return;}const file=new URL('.'+req.url,root);if(!file.pathname.startsWith(root.pathname))throw Error('Invalid path');res.setHeader('content-type',req.url.endsWith('.css')?'text/css':'text/javascript');res.end(await fs.readFile(file));}catch(_){res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const browser=await chromium.launch({headless:true,executablePath:process.env.MGHRM_CHROMIUM_PATH||undefined,args:['--no-sandbox','--disable-dev-shm-usage']});
try{
 for(const width of [390,1440]){
  const page=await browser.newPage({viewport:{width,height:900},acceptDownloads:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${port}/__exit-test`);
  await page.locator('#exDate').fill('2026-10-23');await page.locator('#exDate').dispatchEvent('change');
  assert(await page.locator('#xs_enabled').isChecked());
  await page.locator('#xs_outcome').selectOption('pending');await page.locator('#xs_reason').selectOption('salary_held');await page.locator('#exReason').fill('Synthetic resignation');
  await page.evaluate(()=>{ExitUI.submit();window.confirmCallback();window.confirmCallback();});
  await page.waitForFunction(()=>window.calls===1&&window.messages.some(x=>x.type==='success'));
  await page.locator('#exDate').fill('2026-10-23');await page.locator('#exDate').dispatchEvent('change');
  await page.evaluate(()=>{DATA.employees[0].JoinDate='2025-10-23';exFillEmp();});
  assert(!(await page.locator('#xs_enabled').isChecked()));assert(!(await page.locator('#xs_decision_area').isVisible()));
  await page.locator('#xs_enabled').check();assert(await page.locator('#xs_override_wrap').isVisible());
  const hasOverflow=await page.evaluate(()=>document.querySelector('#page-exit').scrollWidth>window.innerWidth);assert(!hasOverflow,'Exit form overflows at '+width);
  await page.evaluate(()=>showReport('exitSettlement'));await page.waitForFunction(()=>!document.getElementById('xs_print').disabled);
  assert((await page.locator('#exitPrivateBody').innerText()).includes('CONFIDENTIAL-SYNTHETIC'));assert(!(await page.evaluate(()=>window.injected)));
  assert((await page.locator('#exitPrivateBody').innerText()).includes('Not recorded'));
  await page.locator('#xs_report_filter').selectOption('deposit_pending');assert(!(await page.locator('#exitPrivateBody').innerText()).includes('Legacy Guard'));
  await page.evaluate(()=>ExitReports.print());assert((await page.evaluate(()=>window.printed)).includes('CONFIDENTIAL-SYNTHETIC'));
  const downloadPromise=page.waitForEvent('download');await page.evaluate(()=>ExitReports.exportCSV());const download=await downloadPromise;const stream=await download.createReadStream();const chunks=[];for await(const c of stream)chunks.push(c);const csv=Buffer.concat(chunks).toString();assert(csv.includes("'=SYNTHETIC"));assert(csv.includes('CONFIDENTIAL'));
  await page.evaluate(()=>{showReport('exits');currentReport='exits';printReport();});
  assert(!(await page.evaluate(()=>window.printed)).includes('CONFIDENTIAL-SYNTHETIC'));assert(!(await page.locator('#reportOutput').innerText()).includes('Deducted'));
  assert.equal(errors.length,0,errors.join('\n'));
  console.log(`PASS ${width}px: form, anniversary override, duplicate clicks, confidential filters, print/export separation, CSV and HTML injection safety`);
  await page.close();
 }
}finally{await browser.close();await new Promise(r=>server.close(r));}
