import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const scripts=await Promise.all(['notification-model.js','notification-ui.js','notification-simple.js'].map(p=>fs.readFile(p,'utf8')));
const css=await fs.readFile('notification-ui.css','utf8');
const browser=await chromium.launch({headless:true,...(process.env.MG_BROWSER_EXECUTABLE?{executablePath:process.env.MG_BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-dev-shm-usage']}: {})});
try{for(const width of [320,360,390,768,1024,1440]){
 const page=await browser.newPage({viewport:{width,height:900},hasTouch:width<600});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.setContent('<style>:root{--card:#fff;--text:#262638;--border:#ddd;--text-muted:#666}body{font:14px system-ui;margin:12px}.inp{box-sizing:border-box;max-width:100%}#modal{background:white}</style><div id="page-notifications"></div><div id="notifDropdown"></div><div id="modal"></div><div id="page-todo"></div>');
 await page.addStyleTag({content:css});
 await page.evaluate(([model,ui,simple])=>{
  window.MG_SIMPLE_NOTIFICATIONS=true;window.__fail=false;window.__revision=1;window.__calls=[];window.__messages=[];
  const user='11111111-1111-4111-8111-111111111111';
  window.__task={id:900,note:'Synthetic follow-up',status:'pending',reminder_enabled:true,reminder_interval:60};
  window.__notice={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',recipient_user_id:user,entity_type:'todo',entity_id:'900',title:'Synthetic follow-up',message:'Review this task',category:'ToDo',status:'Ready',action_route:'todo',action_label:'Review',created_at:new Date().toISOString()};
  window.DATA={todos:[__task]};window.MG_TD_CFG={master:true,toast:true};window.MG_BACKEND_NOTIFICATIONS=[__notice];
  window.toast=(message)=>__messages.push(message);window.renderTodo=()=>{document.getElementById('page-todo').textContent=DATA.todos[0].status;};
  window.openModal=(title,body,foot)=>{document.getElementById('modal').innerHTML='<h2>'+title+'</h2>'+body+'<div>'+foot+'</div>';};
  window.closeModal=()=>{document.getElementById('modal').innerHTML='';};
  window.mgNUxClose=()=>{};window.mgEnableDeviceNotifications=()=>{};window.mgOpenDeviceNotifications=()=>{};
  window.MGHRM={client:{rpc:async(name,args)=>{
   __calls.push({name,args});if(__fail)return {error:{message:'Synthetic offline'}};
   const preferences={notification_enabled:true,system_push_enabled:true,toast_enabled:true,show_content_preview:true};
   if(name==='notification_simple_settings_read')return {data:{revision:__revision,office_start:'09:00',office_end:'18:00',preferences}};
   if(name==='notification_simple_settings_save'){if(args.p_expected_revision!==__revision)return {error:{message:'Conflict'}};__revision++;return {data:{revision:__revision,...args.p_changes,preferences}};}
   if(name==='notification_todo_action'){
    if(args.p_action==='complete'){__task.status='solved';__task.reminder_enabled=false;__notice.status='Completed';}
    else{__notice.status='Read';__notice.read_at=new Date().toISOString();__task.next_reminder_at=new Date(Date.now()+3600000).toISOString();}
    return {data:{ok:true,notification:{...__notice},todo:{...__task},todo_id:900}};
   }
   return {error:{message:'Unexpected RPC'}};
  }}};
  (0,eval)(model);
  window.mgRebuildNotificationView=()=>{window.NOTIFICATIONS=MG_BACKEND_NOTIFICATIONS.map(NotificationModel.normalize);window.renderNotifications?.();};
  window.mgLoadBackendNotifications=async()=>mgRebuildNotificationView();
  window.markNotifAsRead=async()=>true;window.mgBackendNotifComplete=async()=>false;window.handleNotifClick=async()=>{};
  window.mgTryPendingPushOpen=()=>{};
  (0,eval)(ui);(0,eval)(simple);mgRebuildNotificationView();renderTodo();
 },scripts);
 await page.locator('.mg-simple-popup').waitFor();
 for(const label of ['Mark as read','Remind next time','Complete'])assert(await page.locator('.mg-simple-popup').getByRole('button',{name:label,exact:true}).isVisible());
 await page.locator('.mg-simple-popup').getByRole('button',{name:'Remind next time',exact:true}).click();
 assert.equal(await page.evaluate(()=>DATA.todos[0].status),'pending');assert(await page.evaluate(()=>Date.parse(DATA.todos[0].next_reminder_at)>Date.now()));
 assert.equal(await page.locator('.mg-simple-popup').count(),0);
 await page.evaluate(()=>mgOpenNotifSettings());
 assert(await page.getByText('Notification hours · Bangladesh',{exact:true}).isVisible());
 assert.equal(await page.locator('#modal').getByText(/quota|P3|Intelligent Notification|lease/i).count(),0);
 await page.locator('#mgSimpleAllDay').check();await page.locator('#mgSimpleSave').click();
 await page.getByText('Saved.',{exact:true}).waitFor();assert.equal(await page.evaluate(()=>__revision),2);
 await page.evaluate(()=>{closeModal();__notice.status='Ready';__notice.read_at=null;MG_BACKEND_NOTIFICATIONS=[{...__notice}];mgRebuildNotificationView();});
 await page.locator('[data-notification-action="toggle"]').click();
 assert.equal(await page.evaluate(()=>__notice.status),'Read');
 await page.evaluate(()=>{__fail=true;});
 await page.locator('[data-notification-action="complete"]').click();
 assert.equal(await page.evaluate(()=>DATA.todos[0].status),'pending');
 await page.evaluate(()=>{__fail=false;});
 await page.locator('[data-notification-action="complete"]').click();
 assert.equal(await page.locator('#page-todo').innerText(),'solved');
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'No overflow at '+width);
 await fs.mkdir('artifacts/notification-simple',{recursive:true});await page.screenshot({path:'artifacts/notification-simple/'+width+'.png',fullPage:true});
 assert.deepEqual(errors,[]);await page.close();
}console.log('PASS: simple settings, 24-hour switch, popup actions, read-on-view and real source completion at six widths.');}
finally{await browser.close();}
