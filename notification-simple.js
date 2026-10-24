/* Owner's simple reminder policy: no acknowledgement leases, quotas or work steps. */
(function(){
 'use strict';
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const busy=new Set();let settings=null,opening=0;
 const client=()=>window.MGHRM?.client||window.sb;
 async function rpc(name,args={}){const c=client();if(!c)throw Error('Server connection unavailable');const r=await c.rpc(name,args);if(r.error)throw r.error;return r.data;}
 function cfg(s){const p=s.preferences||{};window.MG_TD_CFG=Object.assign({},window.MG_TD_CFG||{},{master:p.notification_enabled!==false,systemPush:p.system_push_enabled!==false,toast:p.toast_enabled!==false,inApp:true,quietOn:false,timezone:'Asia/Dhaka'});}
 function toggle(id,text,value){return '<label class="mg-ns-row"><span class="mg-ns-copy"><strong>'+text+'</strong></span><input class="mg-ns-toggle" type="checkbox" id="'+id+'" '+(value?'checked':'')+'></label>';}
 window.mgOpenNotifSettings=window.mtOpenNotifSettings=async function(){
  const request=++opening;settings=null;
  window.mgNUxClose?.();window.openModal('Notification settings','<p role="status">Loading settings…</p>','');
  try{
   const s=await rpc('notification_simple_settings_read');if(request!==opening)return;settings=s;cfg(s);const p=s.preferences||{};
   const allDay=s.office_start===s.office_end;
   const body='<div id="mgSimpleSettings"><section class="mg-ns-section">'+toggle('mgSimpleMaster','Notifications',p.notification_enabled!==false)+toggle('mgSimplePush','Device notifications',p.system_push_enabled!==false)+toggle('mgSimpleToast','Pop-up while using the app',p.toast_enabled!==false)+toggle('mgSimplePreview','Show note preview',p.show_content_preview!==false)+'</section><section class="mg-ns-section"><h3>Notification hours · Bangladesh</h3>'+toggle('mgSimpleAllDay','24 hours',allDay)+'<div class="mg-ns-grid"><label>From<input class="inp" type="time" id="mgSimpleStart" value="'+esc(s.office_start)+'" '+(allDay?'disabled':'')+'></label><label>Until<input class="inp" type="time" id="mgSimpleEnd" value="'+esc(s.office_end)+'" '+(allDay?'disabled':'')+'></label></div></section><p class="mg-ns-help">Each To-Do uses its own reminder interval. An unread notification will not repeat. Read or Remind next time starts the next interval.</p><div class="mg-ns-device-actions"><button class="btn ghost sm" type="button" onclick="mgEnableDeviceNotifications()">Enable this device</button><button class="btn ghost sm" type="button" onclick="mgTestDevicePush(this)">Test device push</button><button class="btn ghost sm" type="button" onclick="closeModal();mgOpenDeviceNotifications()">Devices</button></div><p id="mgSimpleResult" role="status" aria-live="polite"></p></div>';
   window.openModal('Notification settings',body,'<button type="button" class="btn ghost sm" onclick="closeModal()">Cancel</button><button type="button" class="btn primary sm" id="mgSimpleSave" onclick="mgSaveNotifSettings()">Save changes</button>');
   document.getElementById('mgSimpleAllDay').onchange=function(){const a=document.getElementById('mgSimpleStart'),b=document.getElementById('mgSimpleEnd');a.disabled=b.disabled=this.checked;if(!this.checked&&a.value===b.value){a.value='09:00';b.value='18:00';}};
  }catch(e){if(request===opening)window.openModal('Notification settings','<p role="alert">'+esc(e.message)+'</p>','<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button>');}
 };
 window.mgSaveNotifSettings=window.mtSaveNotifSettings=async function(){
  const button=document.getElementById('mgSimpleSave'),output=document.getElementById('mgSimpleResult');if(!settings||!button||button.disabled)return;
  const checked=id=>document.getElementById(id).checked,allDay=checked('mgSimpleAllDay');
  const changes={office_start:allDay?'00:00':document.getElementById('mgSimpleStart').value,office_end:allDay?'00:00':document.getElementById('mgSimpleEnd').value,
   notification_enabled:checked('mgSimpleMaster'),system_push_enabled:checked('mgSimplePush'),toast_enabled:checked('mgSimpleToast'),show_content_preview:checked('mgSimplePreview')};
  if(!/^\d\d:\d\d$/.test(changes.office_start)||!/^\d\d:\d\d$/.test(changes.office_end)){output.textContent='Enter valid notification hours.';return;}
  button.disabled=true;output.textContent='Saving…';
  try{const saved=await rpc('notification_simple_settings_save',{p_expected_revision:settings.revision,p_changes:changes});
   if(Number(saved.revision)!==Number(settings.revision)+1)throw Error('Save was not confirmed');
   settings=saved;cfg(saved);output.textContent='Saved.';
  }catch(e){output.textContent='Not saved: '+e.message;}finally{button.disabled=false;}
 };
 window.mgTestDevicePush=async function(button){
  const output=document.getElementById('mgSimpleResult');button.disabled=true;
  try{
   const device=await window.mgEnableDeviceNotifications({silent:typeof Notification!=='undefined'&&Notification.permission==='granted'});
   if(!device?.subscription_id)throw Error('Enable this device first.');
   const result=await rpc('notification_test_device_push',{p_subscription_id:device.subscription_id});
   if(result?.queued!==true)throw Error('Push was not queued.');
   output.textContent='Test queued for this device. Check the notification tray within one minute.';
  }catch(e){output.textContent='Test not sent: '+e.message;}finally{button.disabled=false;}
 };
 async function act(id,action){
  if(busy.has(String(id)))return false;busy.add(String(id));
  try{
   const result=await rpc('notification_todo_action',{p_notification_id:id,p_action:action});
   if(result?.ok!==true||!result.notification||!result.todo)throw Error('Server did not confirm this action');
   const row=window.DATA?.todos?.find(t=>String(t.id)===String(result.todo_id));if(row)Object.assign(row,result.todo);
   if(window.NotificationModel)window.MG_BACKEND_NOTIFICATIONS=window.NotificationModel.upsert(window.MG_BACKEND_NOTIFICATIONS||[],result.notification);
   window.mgRebuildNotificationView?.();await window.mgLoadBackendNotifications?.();
   if(typeof renderTodo==='function')renderTodo();
   if(action==='complete')window.toast?.('To-Do completed','success');
   return true;
  }catch(e){window.toast?.('Action was not saved: '+e.message,'error');return false;}finally{busy.delete(String(id));}
 }
 const find=id=>(window.NOTIFICATIONS||[]).find(n=>String(n.id)===String(id));
 const oldRead=window.markNotifAsRead,oldComplete=window.mgBackendNotifComplete,oldOpen=window.handleNotifClick;
 window.mgBackendNotifRemind=id=>act(id,'remind');
 window.markNotifAsRead=id=>find(id)?.isBackend&&find(id).entityType==='todo'?act(id,'read'):oldRead(id);
 window.mgBackendNotifComplete=id=>find(id)?.isBackend&&find(id).entityType==='todo'?act(id,'complete'):oldComplete(id);
 window.handleNotifClick=async function(id){if(find(id)?.isBackend&&find(id).entityType==='todo'&&!await act(id,'read'))return false;return oldOpen(id);};
 window.mgApplyPushAction=async function(id,action){
  if(!['read','remind','complete'].includes(action)||!find(id)?.isBackend)return false;
  return act(id,action);
 };
 const oldTry=window.mgTryPendingPushOpen;
 window.mgTryPendingPushOpen=async function(){
  const query=new URLSearchParams(location.search),action=query.get('notification_action'),id=query.get('notification_id');
  if(!action)return oldTry?.();
  if(!id||!find(id)?.isBackend)return;
  if(!await window.mgApplyPushAction(id,action))return;
  for(const key of ['notification_action','notification_id','notification_route','notification_entity'])query.delete(key);
  history.replaceState(null,'',location.pathname+(query.toString()?'?'+query:'')+location.hash);
 };
 navigator.serviceWorker?.addEventListener('message',async e=>{
  if(e.data?.type==='MG_NOTIFICATION_ACTION_CONFIRMED'){
   await window.mgLoadBackendNotifications?.();
   // Source realtime also updates closed apps when they next reconnect.
   if(window.MGHRM?.loadAll)await window.MGHRM.loadAll();
   if(typeof renderTodo==='function')renderTodo();
  }
 });

 const displayed=new Set();
 try{for(const id of JSON.parse(sessionStorage.getItem('mg-simple-displayed')||'[]'))displayed.add(id);}catch{}
 function popups(){
  if(document.hidden||window.MG_TD_CFG?.master===false||window.MG_TD_CFG?.toast===false)return;
  const rows=(window.NOTIFICATIONS||[]).filter(n=>n.isBackend&&n.entityType==='todo'&&window.NotificationModel?.unread(n));
  let host=document.getElementById('mgSimplePopups');
  if(!host){host=document.createElement('section');host.id='mgSimplePopups';host.className='mg-simple-popups';host.setAttribute('aria-label','Reminders');document.body.appendChild(host);}
  for(const item of host.querySelectorAll('[data-popup-id]'))if(!rows.some(n=>String(n.id)===item.dataset.popupId))item.remove();
  for(const n of rows){
   if(host.children.length>=2)break;if(displayed.has(String(n.id)))continue;
   displayed.add(String(n.id));try{sessionStorage.setItem('mg-simple-displayed',JSON.stringify([...displayed].slice(-500)));}catch{}
   const card=document.createElement('article');card.className='mg-simple-popup';card.dataset.popupId=String(n.id);
   const current=window.NotificationModel.todoPresentation(n,window.DATA?.todos||[]);
   card.innerHTML='<button type="button" class="mg-simple-popup-close" aria-label="Close preview">×</button><p>'+esc(current.title||'To-Do reminder')+'</p><div class="mg-n-row-actions">'+[['read','Mark as read'],['remind','Remind next time'],['complete','Complete']].map(([action,label])=>'<button type="button" class="mg-n-btn" data-do="'+action+'">'+label+'</button>').join('')+'</div>';
   card.querySelector('.mg-simple-popup-close').onclick=()=>{card.remove();popups();};
   for(const button of card.querySelectorAll('[data-do]'))button.onclick=async()=>{button.disabled=true;if(await act(n.id,button.dataset.do))card.remove();else button.disabled=false;popups();};
   host.appendChild(card);
  }
 }
 const rebuild=window.mgRebuildNotificationView;
 window.mgRebuildNotificationView=function(){const result=rebuild?.();popups();return result;};
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)popups();});
})();
