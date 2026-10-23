// Real Chromium rendering and IndexedDB queue with synthetic authenticated RPCs.
// Device Push acceptance and physical Android/Windows are separate observations.
import {chromium} from 'playwright';
import http from 'node:http';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const code=await fs.readFile('notification-workflow-ui.js','utf8');
const css=await fs.readFile('notification-workflow-ui.css','utf8');
const server=http.createServer((req,res)=>{res.writeHead(200,{'content-type':'text/html'});res.end('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><div id="page-todo"></div><div id="modal"></div>');});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({headless:true});
try{for(const width of [320,360,390,768,1024,1440]){
 const context=await browser.newContext({viewport:{width,height:900}}),page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto('http://127.0.0.1:'+server.address().port);await page.addStyleTag({content:css});
 await page.evaluate(({code})=>{
  window.DATA={todos:[{id:200,note:'Test manager request'}]};window.renderTodo=function(){};
  window.openModal=(title,body)=>{document.getElementById('modal').innerHTML='<h2>'+title+'</h2>'+body;};window.closeModal=()=>{document.getElementById('modal').innerHTML='';};
  window.__revision=1;window.__failure=false;window.__conflict=false;window.__captures=0;
  window.__work=()=>({work:{id:'cccccccc-cccc-4ccc-8ccc-cccccccccccc',row_version:window.__revision,subject:'Manager request',category:'inform_manager',next_action:'Tell manager',next_party:'You',next_review_at:'2026-11-01T04:00:00Z',manager_required:true,approval_required:true,communication_required:true,communication_parties:['Project','Admin'],communicated_parties:{},execution_required:true,verification_required:true,priority:'important',stage:'active',manager_decision:'pending',context:{}},summary:{active:true,steps:['Tell manager','Tell project'],risk:'date_unknown',group:'BRIEF_MANAGER',next_action:'Tell manager',next_party:'You',can_complete:false,communication_pending:true},events:[]});
  window.MGHRM={client:{auth:{getSession:async()=>({data:{session:{user:{id:'11111111-1111-4111-8111-111111111111'}}}})},rpc:async(name,args)=>{
   if(name==='notification_work_get')return {data:args.p_todo_id?window.__work():{items:[{todo_id:200,...window.__work()}]}};
   if(name==='notification_work_save'){if(window.__failure)throw Error('Network failed');if(window.__conflict)return {error:{code:'40001',message:'Conflict'}};window.__revision++;return {data:window.__work()};}
   if(name==='notification_work_capture'){if(window.__failure)throw Error('Network failed');window.__captures++;return {data:{saved:true,todo_id:200}};}
   if(name==='swa_start_briefing')return {data:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'}};
   if(name==='swa_close_briefing')return {data:{}};
   if(name==='notification_work_brief_summary')return {data:{discussed:1,decision_recorded:0}};
   return {error:{message:'Unknown RPC '+name}};
  }}};
  (0,eval)(code);
 },{code});
 await page.evaluate(()=>mgWorkOpen(200));
 await page.getByText('Record decision',{exact:true}).click();
 assert.match(await page.locator('#mgWorkStatus').innerText(),/Saved on the server/);
 await page.locator('summary').first().click();
 await page.locator('#mgWork_next_action').fill('Tell the project about the decision');
 await page.getByText('Save action plan',{exact:true}).click();
 assert.match(await page.locator('#mgWorkStatus').innerText(),/Saved on the server/);
 const measured=await page.evaluate(()=>({width:window.innerWidth,scroll:document.documentElement.scrollWidth,min:Math.min(...Array.from(document.querySelectorAll('.mg-work button')).map(x=>x.getBoundingClientRect().height).filter(x=>x>0))}));
 assert(measured.scroll<=measured.width+1,'No horizontal overflow at '+width);assert(measured.min>=43,'44px touch targets');
 // Failed network stores an intent durably and never displays saved.
 await page.evaluate(()=>{window.__failure=true;});
 await page.getByText('Record decision',{exact:true}).click();
 assert.match(await page.locator('#mgWorkStatus').innerText(),/not confirmed/);
 await page.evaluate(()=>mgWorkPending());assert.match(await page.locator('#modal').innerText(),/Waiting for connection/);
 // Reopening / reloading script does not erase IndexedDB intents.
 await page.evaluate(()=>{window.__failure=false;window.__mgWorkSteps=false;});await page.evaluate(code=>{(0,eval)(code);},code);
 await page.evaluate(()=>mgWorkSync());assert.match(await page.locator('#modal').innerText(),/No queued changes/);
 await page.evaluate(()=>mgWorkQuickCapture());
 await page.locator('#mgWork_capture_subject').fill('Offline request');await page.evaluate(()=>{window.__failure=true;});
 await page.locator('#mgWorkCaptureSave').click();assert.match(await page.locator('#modal').innerText(),/not confirmed/);
 await page.evaluate(()=>{window.__failure=false;});await page.evaluate(()=>mgWorkSync());assert.equal(await page.evaluate(()=>window.__captures),1);
 // A cross-device conflict remains queued for explicit review, never overwritten.
 await page.evaluate(()=>mgWorkOpen(200));await page.evaluate(()=>{window.__conflict=true;});
 await page.getByText('Record decision',{exact:true}).click();assert.match(await page.locator('#mgWorkStatus').innerText(),/Another device/);
 await page.evaluate(()=>mgWorkPending());assert.match(await page.locator('#modal').innerText(),/another device/i);
 await fs.mkdir('artifacts/notification-workflow',{recursive:true});await page.screenshot({path:'artifacts/notification-workflow/'+width+'.png',fullPage:true});
 assert.deepEqual(errors,[]);await context.close();
}console.log('PASS workflow UI: six viewports, durable IndexedDB, uncertain save retry and visible revision conflict');}
finally{await browser.close();server.close();}
