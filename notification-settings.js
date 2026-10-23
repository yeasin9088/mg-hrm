
(function(){
  function syncMobileBrandLogo(){
    var el=document.getElementById('mobileBrandLogo');
    if(!el)return;
    if(typeof COMPANY!=='undefined'&&COMPANY&&COMPANY.logoDataUrl){
      el.innerHTML='<img src="'+COMPANY.logoDataUrl+'" alt="">';
    }
  }
  function syncMobileNotificationState(){
    var dd=document.getElementById('notifDropdown');
    var btn=document.getElementById('mobileNotifToggle');
    if(btn)btn.setAttribute('aria-expanded',dd&&dd.classList.contains('open')?'true':'false');
  }
  window.mgOpenMobileNotifications=function(ev){
    if(ev){ev.preventDefault();ev.stopPropagation();}
    var dd=document.getElementById('notifDropdown');
    if(!dd)return;
    if(dd.parentNode!==document.body)document.body.appendChild(dd);
    if(typeof renderNotifDropdown==='function')renderNotifDropdown();
    var opening=!dd.classList.contains('open');
    dd.classList.toggle('open',opening);
    document.body.classList.toggle('mg-notif-open',opening);
    var btn=document.getElementById('mobileNotifToggle');
    if(btn)btn.setAttribute('aria-expanded',opening?'true':'false');
  };
  async function lockInstalledAppPortrait(){
    var standalone=window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches;
    if(!standalone||!screen.orientation||typeof screen.orientation.lock!=='function')return;
    try{await screen.orientation.lock('portrait-primary');}catch(e){}
  }
  function init(){
    syncMobileBrandLogo();
    lockInstalledAppPortrait();
    if(typeof updateNotifBadge==='function')updateNotifBadge();
    var dd=document.getElementById('notifDropdown');
    if(dd)new MutationObserver(syncMobileNotificationState).observe(dd,{attributes:true,attributeFilter:['class']});
    document.addEventListener('click',function(e){
      var panel=document.getElementById('notifDropdown'),btn=document.getElementById('mobileNotifToggle');
      if(innerWidth<=768&&panel&&panel.classList.contains('open')&&!panel.contains(e.target)&&!(btn&&btn.contains(e.target))){
        if(typeof mgNUxClose==='function')mgNUxClose();else{panel.classList.remove('open');document.body.classList.remove('mg-notif-open');}
      }
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
  window.addEventListener('load',syncMobileBrandLogo,{once:true});
})();


(function(){
'use strict';
if(window.__mgNotificationUxPhase4)return;window.__mgNotificationUxPhase4=true;
var S={base:null,draft:null,trigger:null,saving:false,devices:[],permission:'unsupported',currentSubscribed:false};
var DEFAULTS={master:true,inApp:true,toast:true,systemPush:true,contentPreview:true,minimumPriority:'Low',quietOn:false,quietStart:'22:00',quietEnd:'07:00',timezone:'Asia/Dhaka',snoozeMin:15,toastMax:2,toastGapSec:60};
function repo(){return window.MGHRM&&window.MGHRM.notifications;}
function esc(v){return typeof escapeHtml==='function'?escapeHtml(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function clone(v){return JSON.parse(JSON.stringify(v));}
function fromRow(r){r=r||{};return {master:r.notification_enabled!==undefined?r.notification_enabled!==false:DEFAULTS.master,inApp:r.in_app_enabled!==undefined?r.in_app_enabled!==false:DEFAULTS.inApp,toast:r.toast_enabled!==undefined?r.toast_enabled!==false:DEFAULTS.toast,systemPush:r.system_push_enabled!==undefined?r.system_push_enabled!==false:DEFAULTS.systemPush,contentPreview:r.show_content_preview!==false,minimumPriority:['Low','Normal','High','Urgent'].indexOf(r.minimum_priority)>=0?r.minimum_priority:DEFAULTS.minimumPriority,quietOn:r.quiet_hours_enabled===true,quietStart:String(r.quiet_hours_start||DEFAULTS.quietStart).slice(0,5),quietEnd:String(r.quiet_hours_end||DEFAULTS.quietEnd).slice(0,5),timezone:String(r.timezone||DEFAULTS.timezone),snoozeMin:Math.max(1,Math.min(240,Number(r.default_snooze_minutes)||DEFAULTS.snoozeMin)),toastMax:Math.max(1,Math.min(3,Number(r.toast_max_visible)||DEFAULTS.toastMax)),toastGapSec:Math.max(10,Math.min(600,Number(r.toast_gap_seconds)||DEFAULTS.toastGapSec))};}
function toRow(d){return {notification_enabled:d.master!==false,in_app_enabled:d.inApp!==false,toast_enabled:d.toast!==false,system_push_enabled:d.systemPush!==false,show_content_preview:d.contentPreview!==false,minimum_priority:d.minimumPriority,quiet_hours_enabled:d.quietOn===true,quiet_hours_start:d.quietStart,quiet_hours_end:d.quietEnd,urgent_bypass_enabled:true,timezone:d.timezone,default_snooze_minutes:d.snoozeMin,toast_max_visible:d.toastMax,toast_gap_seconds:d.toastGapSec};}
function root(){var x=document.getElementById('mgNotifSettingsRoot');if(!x){x=document.createElement('div');x.id='mgNotifSettingsRoot';x.className='mg-ns-backdrop';x.setAttribute('aria-hidden','true');x.innerHTML='<section class="mg-ns-panel" role="dialog" aria-modal="true" aria-labelledby="mgNsTitle"><header class="mg-ns-head"><div class="mg-ns-title"><h2 id="mgNsTitle">Notification Settings</h2><p>Delivery, quiet hours, reminders and devices</p></div><button class="mg-ns-close" type="button" aria-label="Close notification settings" onclick="mgCloseNotifSettings()">×</button></header><div class="mg-ns-body" id="mgNsBody"></div><footer class="mg-ns-foot"><button type="button" class="mg-ns-btn danger" id="mgNsReset" onclick="mgResetNotifSettings()">Reset to defaults</button><div class="mg-ns-live" id="mgNsLive" role="status" aria-live="polite"></div><div class="mg-ns-foot-main"><button type="button" class="mg-ns-btn" onclick="mgCloseNotifSettings()">Cancel</button><button type="button" class="mg-ns-btn primary" id="mgNsSave" onclick="mgSaveNotifSettings()" disabled>Save changes</button></div></footer></section>';document.body.appendChild(x);x.addEventListener('mousedown',function(e){if(e.target===x)window.mgCloseNotifSettings();});}return x;}
function live(msg,type){var e=document.getElementById('mgNsLive');if(e){e.className='mg-ns-live '+(type||'');e.textContent=msg||'';}}
function dirty(){return !!(S.base&&S.draft&&JSON.stringify(S.base)!==JSON.stringify(S.draft));}
function syncSave(){var b=document.getElementById('mgNsSave');if(b)b.disabled=S.saving||!dirty();var r=document.getElementById('mgNsReset');if(r)r.disabled=S.saving;}
function permissionLabel(){if(S.permission==='denied')return 'Blocked by browser';if(S.permission==='default')return 'Permission required';if(S.permission==='granted')return S.currentSubscribed?'Enabled on this device':'Device not registered';return 'Unsupported';}
function render(){var b=document.getElementById('mgNsBody');if(!b||!S.draft)return;var d=S.draft,active=S.devices.filter(function(x){return x.is_active===true&&!x.revoked_at;}).length;b.innerHTML='<section class="mg-ns-section"><h3>Delivery preferences</h3><p class="mg-ns-help">Backend preferences are separate from this browser’s permission and subscription state.</p>'+toggle('mgNsMaster','Notifications','Receive notifications for your account.',d.master)+toggle('mgNsInApp','In-app notifications','Show notifications in the authenticated Inbox.',d.inApp)+toggle('mgNsPush','Browser / device push','Allow push delivery to your registered devices.',d.systemPush)+toggle('mgNsPreview','Show notification content preview','Show To-Do text on the device; confidential HR updates stay brief. Turn off for generic lock-screen alerts.',d.contentPreview)+toggle('mgNsToast','Foreground toast notifications','Show compact alerts while the app is open.',d.toast)+'</section><section class="mg-ns-section"><h3>Priority and quiet hours</h3><p class="mg-ns-help">In legacy V1, the Urgent preference may bypass quiet hours. Verified P0/P1 emergency overrides remain disabled until approved.</p><div class="mg-ns-grid"><div class="mg-ns-field"><label for="mgNsPriority">Minimum priority</label><select class="mg-ns-select" id="mgNsPriority">'+['Low','Normal','High','Urgent'].map(function(x){return '<option'+(x===d.minimumPriority?' selected':'')+'>'+x+'</option>';}).join('')+'</select></div><div class="mg-ns-field"><label for="mgNsTimezone">Timezone</label><input class="mg-ns-input" id="mgNsTimezone" value="'+esc(d.timezone)+'" readonly></div></div>'+toggle('mgNsQuiet','Quiet hours','Supports overnight ranges such as 22:00–07:00.',d.quietOn)+'<div class="mg-ns-grid"><div class="mg-ns-field"><label for="mgNsQuietStart">Start</label><input class="mg-ns-input" type="time" id="mgNsQuietStart" value="'+esc(d.quietStart)+'"'+(d.quietOn?'':' disabled')+'></div><div class="mg-ns-field"><label for="mgNsQuietEnd">End</label><input class="mg-ns-input" type="time" id="mgNsQuietEnd" value="'+esc(d.quietEnd)+'"'+(d.quietOn?'':' disabled')+'></div></div></section><section class="mg-ns-section"><h3>Reminder and foreground behavior</h3><div class="mg-ns-grid"><div class="mg-ns-field"><label for="mgNsSnooze">Default snooze minutes (1–240)</label><input class="mg-ns-input" type="number" min="1" max="240" id="mgNsSnooze" value="'+d.snoozeMin+'"></div><div class="mg-ns-field"><label for="mgNsToastMax">Maximum visible toasts (1–3)</label><input class="mg-ns-input" type="number" min="1" max="3" id="mgNsToastMax" value="'+d.toastMax+'"></div><div class="mg-ns-field"><label for="mgNsToastGap">Minimum toast gap, seconds (10–600)</label><input class="mg-ns-input" type="number" min="10" max="600" id="mgNsToastGap" value="'+d.toastGapSec+'"></div></div></section><section class="mg-ns-section"><h3>Devices</h3><p class="mg-ns-help">Only safe device metadata is displayed. Subscription keys and endpoints are never shown.</p><div class="mg-ns-row"><div class="mg-ns-copy"><strong>Current browser</strong><small>Permission: '+esc(S.permission)+' · Registered devices: '+S.devices.length+' · Active: '+active+'</small></div><span class="mg-ns-status">'+esc(permissionLabel())+'</span></div>'+(S.permission==='denied'?'<p class="mg-ns-help">Notifications are blocked. Enable permission for this site in your browser settings, then reopen this panel.</p>':'')+'<div class="mg-ns-device-actions"><button type="button" class="mg-ns-btn primary" id="mgNsEnableDevice"'+(S.permission==='denied'||S.permission==='unsupported'?' disabled':'')+'>Enable Device Notifications</button><button type="button" class="mg-ns-btn" id="mgNsManageDevices">Manage Devices</button></div></section>';bind();syncSave();}
function toggle(id,title,help,checked){return '<label class="mg-ns-row" for="'+id+'"><span class="mg-ns-copy"><strong>'+esc(title)+'</strong><small>'+esc(help)+'</small></span><input class="mg-ns-toggle" type="checkbox" role="switch" aria-checked="'+(checked?'true':'false')+'" id="'+id+'" '+(checked?'checked':'')+'></label>';}
function bind(){var map={mgNsMaster:'master',mgNsInApp:'inApp',mgNsPush:'systemPush',mgNsPreview:'contentPreview',mgNsToast:'toast',mgNsQuiet:'quietOn',mgNsPriority:'minimumPriority',mgNsQuietStart:'quietStart',mgNsQuietEnd:'quietEnd',mgNsSnooze:'snoozeMin',mgNsToastMax:'toastMax',mgNsToastGap:'toastGapSec'};Object.keys(map).forEach(function(id){var e=document.getElementById(id);if(!e)return;e.addEventListener('change',function(){var k=map[id],v=e.type==='checkbox'?e.checked:e.value;if(['snoozeMin','toastMax','toastGapSec'].indexOf(k)>=0)v=Number(v);S.draft[k]=v;if(e.type==='checkbox')e.setAttribute('aria-checked',v?'true':'false');if(k==='quietOn'){var a=document.getElementById('mgNsQuietStart'),z=document.getElementById('mgNsQuietEnd');if(a)a.disabled=!v;if(z)z.disabled=!v;}syncSave();live('');});});var en=document.getElementById('mgNsEnableDevice');if(en)en.addEventListener('click',async function(){en.disabled=true;await window.mgEnableDeviceNotifications();await loadDevices();render();});var man=document.getElementById('mgNsManageDevices');if(man)man.addEventListener('click',function(){window.mgCloseNotifSettings(false);window.mgOpenDeviceNotifications();});}
async function loadDevices(){S.permission=('Notification' in window)?Notification.permission:'unsupported';S.currentSubscribed=false;try{S.devices=repo()?await repo().listDevices():[];}catch(e){S.devices=[];}try{if('serviceWorker' in navigator&&'PushManager' in window){var reg=await navigator.serviceWorker.ready;S.currentSubscribed=!!(await reg.pushManager.getSubscription());}}catch(e){S.currentSubscribed=false;}}
async function load(){if(!repo())throw new Error('Notification repository is unavailable.');var rows=await repo().getPreferences(),row=(rows||[]).find(function(x){return x.category==='*';})||(rows||[])[0]||{};S.base=fromRow(row);S.draft=clone(S.base);window.MG_TD_CFG=Object.assign({},window.MG_TD_CFG||{},S.base);try{localStorage.setItem('mghrm_notif_cfg',JSON.stringify(window.MG_TD_CFG));}catch(e){}await loadDevices();}
function validate(){var d=S.draft;if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.quietStart)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.quietEnd))return 'Enter valid quiet-hour start and end times.';if(!d.timezone)return 'A saved timezone is required.';if(['Low','Normal','High','Urgent'].indexOf(d.minimumPriority)<0)return 'Select a supported minimum priority.';if(!Number.isFinite(d.snoozeMin)||d.snoozeMin<1||d.snoozeMin>240)return 'Default snooze must be between 1 and 240 minutes.';if(!Number.isFinite(d.toastMax)||d.toastMax<1||d.toastMax>3)return 'Maximum visible toasts must be between 1 and 3.';if(!Number.isFinite(d.toastGapSec)||d.toastGapSec<10||d.toastGapSec>600)return 'Toast gap must be between 10 and 600 seconds.';return '';}
window.mtOpenNotifSettings=window.mgOpenNotifSettings=async function(ev){if(ev&&ev.currentTarget)S.trigger=ev.currentTarget;else S.trigger=document.activeElement;var dd=document.getElementById('notifDropdown');if(dd&&dd.classList.contains('open')){if(typeof window.mgNUxClose==='function')window.mgNUxClose();else{dd.classList.remove('open');document.body.classList.remove('mg-notif-open');}}var x=root();x.classList.add('open');x.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';document.getElementById('mgNsBody').innerHTML='<div class="mg-ns-loading">Loading your notification preferences…</div>';live('');try{await load();render();setTimeout(function(){var f=document.getElementById('mgNsMaster');if(f)f.focus();},0);}catch(e){document.getElementById('mgNsBody').innerHTML='<div class="mg-ns-loading">Could not load notification settings. '+esc((e&&e.message)||e)+'</div>';live('Preference load failed.','error');}};
window.mgCloseNotifSettings=function(restore){var x=document.getElementById('mgNotifSettingsRoot');if(x){x.classList.remove('open');x.setAttribute('aria-hidden','true');}document.body.style.overflow='';if(restore!==false&&S.trigger&&typeof S.trigger.focus==='function')setTimeout(function(){S.trigger.focus();},0);};
window.mgSaveNotifSettings=window.mtSaveNotifSettings=async function(){if(S.saving)return;var error=validate();if(error){live(error,'error');return;}S.saving=true;syncSave();live('Saving…');try{await repo().updatePreferences(toRow(S.draft),'*');await load();render();if(typeof window.mgReminderTick==='function')window.mgReminderTick();if(typeof toast==='function')toast('Notification settings saved','success');live('Settings saved.','success');}catch(e){live('Settings were not saved: '+((e&&e.message)||e),'error');}finally{S.saving=false;syncSave();}};
window.mgResetNotifSettings=window.mtResetNotifSettings=async function(){if(S.saving)return;if(!window.confirm('Reset notification settings to defaults? Device registrations and browser permission will not be changed.'))return;S.saving=true;syncSave();live('Resetting…');try{var next=clone(DEFAULTS);if(S.base&&S.base.timezone)next.timezone=S.base.timezone;await repo().updatePreferences(toRow(next),'*');await load();render();if(typeof window.mgReminderTick==='function')window.mgReminderTick();if(typeof toast==='function')toast('Notification settings reset','success');live('Defaults restored.','success');}catch(e){live('Settings were not reset: '+((e&&e.message)||e),'error');}finally{S.saving=false;syncSave();}};
document.addEventListener('keydown',function(e){var x=document.getElementById('mgNotifSettingsRoot');if(e.key==='Escape'&&x&&x.classList.contains('open'))window.mgCloseNotifSettings();});
})();


(function(){
'use strict';
if(window.__mgNotificationUxPhase5)return;window.__mgNotificationUxPhase5=true;
var D={devices:[],trigger:null,busy:false,permission:'unsupported',subscribed:false,editing:null};
function repo(){return window.MGHRM&&window.MGHRM.notifications;}
function esc(v){return typeof escapeHtml==='function'?escapeHtml(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function root(){var x=document.getElementById('mgDeviceManagerRoot');if(!x){x=document.createElement('div');x.id='mgDeviceManagerRoot';x.className='mg-dm-backdrop';x.setAttribute('aria-hidden','true');x.innerHTML='<section class="mg-dm-panel" role="dialog" aria-modal="true" aria-labelledby="mgDmTitle"><header class="mg-dm-head"><div class="mg-dm-head-copy"><h2 id="mgDmTitle">Device Notifications</h2><p>Manage registered browsers and push delivery safely</p></div><button type="button" class="mg-dm-close" aria-label="Close device manager" onclick="mgCloseDeviceNotifications()">×</button></header><div class="mg-dm-body" id="mgDmBody"></div><footer class="mg-dm-foot"><div class="mg-dm-live" id="mgDmLive" role="status" aria-live="polite"></div><button type="button" class="mg-dm-btn" onclick="mgCloseDeviceNotifications()">Close</button></footer></section>';document.body.appendChild(x);x.addEventListener('mousedown',function(e){if(e.target===x)window.mgCloseDeviceNotifications();});}return x;}
function live(msg,type){var e=document.getElementById('mgDmLive');if(e){e.className='mg-dm-live '+(type||'');e.textContent=msg||'';}}
function fmt(v){if(!v)return 'Not available';var d=new Date(v);return isNaN(d.getTime())?String(v):d.toLocaleString();}
function active(d){return d.is_active===true&&!d.revoked_at&&String(d.permission_state||'').toLowerCase()!=='revoked';}
function state(d){if(d.revoked_at||String(d.permission_state||'').toLowerCase()==='revoked')return 'Revoked';return active(d)?'Active':'Inactive';}
function currentState(){if(D.permission==='denied')return 'Blocked by browser';if(D.permission==='default')return 'Permission required';if(D.permission==='granted')return D.subscribed?'Subscribed':'Not subscribed';return 'Unsupported';}
async function localState(){D.permission=('Notification' in window)?Notification.permission:'unsupported';D.subscribed=false;try{if('serviceWorker' in navigator&&'PushManager' in window){var reg=await navigator.serviceWorker.ready;D.subscribed=!!(await reg.pushManager.getSubscription());}}catch(e){D.subscribed=false;}}
async function load(){if(!repo())throw new Error('Notification repository is unavailable.');var out=await Promise.all([repo().listDevices(),localState()]);D.devices=Array.isArray(out[0])?out[0]:[];}
function deviceMeta(d){var parts=[];if(d.browser_name)parts.push(d.browser_name);if(d.platform_name)parts.push(d.platform_name);return parts.join(' · ')||'Browser device';}
function card(d){var id=String(d.id),editing=String(D.editing)===id;return '<article class="mg-dm-card"><div class="mg-dm-card-top"><div class="mg-dm-device-copy"><strong>'+esc(d.device_label||d.browser_name||'Registered device')+'</strong><small>'+esc(deviceMeta(d))+'<br>Last seen: '+esc(fmt(d.last_seen_at||d.last_seen||d.updated_at))+(d.created_at?'<br>Registered: '+esc(fmt(d.created_at)):'')+'</small></div><span class="mg-dm-status">'+esc(state(d))+'</span></div>'+(editing?'<div class="mg-dm-rename"><input class="mg-dm-input" id="mgDmRenameInput" maxlength="80" aria-label="Device name" value="'+esc(d.device_label||d.browser_name||'Device')+'"><button class="mg-dm-btn primary" type="button" onclick="mgSaveDeviceRename(\''+esc(id)+'\')">Save</button><button class="mg-dm-btn" type="button" onclick="mgCancelDeviceRename()">Cancel</button></div>':'<div class="mg-dm-card-actions"><button class="mg-dm-btn" type="button" onclick="mgStartDeviceRename(\''+esc(id)+'\')"'+(!active(d)?' disabled':'')+'>Rename</button><button class="mg-dm-btn" type="button" onclick="mgTouchNotificationDevice(\''+esc(id)+'\')"'+(!active(d)?' disabled':'')+'>Refresh heartbeat</button><button class="mg-dm-btn danger" type="button" onclick="mgRevokeNotificationDevice(\''+esc(id)+'\')"'+(!active(d)?' disabled':'')+'>Revoke</button></div>')+'</article>';}
function render(){var b=document.getElementById('mgDmBody');if(!b)return;var act=D.devices.filter(active).length;b.innerHTML='<div class="mg-dm-summary"><div class="mg-dm-stat"><strong>'+D.devices.length+'</strong><span>Registered devices</span></div><div class="mg-dm-stat"><strong>'+act+'</strong><span>Active devices</span></div><div class="mg-dm-stat"><strong>'+esc(D.permission)+'</strong><span>Browser permission</span></div></div><section class="mg-dm-current"><div class="mg-dm-current-copy"><strong>Current browser</strong><small>'+esc(navigator.userAgent||'Browser')+'</small></div><span class="mg-dm-status">'+esc(currentState())+'</span><button type="button" class="mg-dm-btn primary" id="mgDmEnable"'+(D.permission==='denied'||D.permission==='unsupported'?' disabled':'')+'>Enable notifications</button></section>'+(D.permission==='denied'?'<div class="mg-dm-card"><div class="mg-dm-device-copy"><strong>Browser permission is blocked</strong><small>Enable notifications for this site in browser settings. Repeated permission prompts are not available while permission remains denied.</small></div></div>':'')+'<div class="mg-dm-list">'+(D.devices.length?D.devices.map(card).join(''):'<div class="mg-dm-empty">No registered devices were returned for this account.</div>')+'</div>';var en=document.getElementById('mgDmEnable');if(en)en.addEventListener('click',async function(){if(D.busy)return;D.busy=true;en.disabled=true;live('Enabling this device…');try{var result=await window.mgEnableDeviceNotifications();if(['blocked','unsupported','error'].includes(result))throw new Error('Device notifications could not be enabled: '+result);await load();render();live('Current device status refreshed.','success');}catch(e){live((e&&e.message)||String(e),'error');}finally{D.busy=false;}});if(D.editing)setTimeout(function(){var i=document.getElementById('mgDmRenameInput');if(i){i.focus();i.select();}},0);}
function find(id){return D.devices.find(function(x){return String(x.id)===String(id);});}
async function refresh(message){await load();render();live(message||'Device list refreshed.','success');}
window.mgOpenDeviceNotifications=async function(ev){if(ev&&ev.currentTarget)D.trigger=ev.currentTarget;else D.trigger=document.activeElement;if(typeof window.mgCloseNotifSettings==='function')window.mgCloseNotifSettings(false);if(typeof closeModal==='function')closeModal();var x=root();x.classList.add('open');x.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';document.getElementById('mgDmBody').innerHTML='<div class="mg-dm-loading">Loading registered devices…</div>';live('');try{await load();render();setTimeout(function(){var c=x.querySelector('.mg-dm-close');if(c)c.focus();},0);}catch(e){document.getElementById('mgDmBody').innerHTML='<div class="mg-dm-loading">Could not load devices. '+esc((e&&e.message)||e)+'</div>';live('Device load failed.','error');}};
window.mgCloseDeviceNotifications=function(){var x=document.getElementById('mgDeviceManagerRoot');if(x){x.classList.remove('open');x.setAttribute('aria-hidden','true');}D.editing=null;document.body.style.overflow='';if(D.trigger&&typeof D.trigger.focus==='function')setTimeout(function(){D.trigger.focus();},0);};
window.mgStartDeviceRename=function(id){D.editing=String(id);render();};window.mgCancelDeviceRename=function(){D.editing=null;render();};
window.mgSaveDeviceRename=async function(id){if(D.busy)return;var d=find(id),input=document.getElementById('mgDmRenameInput'),name=input?input.value.trim():'';if(!d)return;if(!name){live('Enter a device name.','error');return;}if(name.length>80){live('Device name must be 80 characters or fewer.','error');return;}D.busy=true;live('Saving device name…');try{await repo().updateDevice(d.id,{device_label:name,browser_name:d.browser_name||null,platform_name:d.platform_name||null,touch_last_seen:true});D.editing=null;await refresh('Device renamed.');}catch(e){live('Rename failed: '+((e&&e.message)||e),'error');}finally{D.busy=false;}};
window.mgTouchNotificationDevice=async function(id){if(D.busy)return;var d=find(id);if(!d)return;D.busy=true;live('Refreshing heartbeat…');try{await repo().updateDevice(d.id,{device_label:d.device_label||null,browser_name:d.browser_name||null,platform_name:d.platform_name||null,touch_last_seen:true});await refresh('Heartbeat refreshed.');}catch(e){live('Heartbeat refresh failed: '+((e&&e.message)||e),'error');}finally{D.busy=false;}};
window.mgRevokeNotificationDevice=async function(id){if(D.busy)return;var d=find(id);if(!d)return;if(!window.confirm('Revoke '+(d.device_label||d.browser_name||'this device')+'? Push notifications will stop for that registration.'))return;D.busy=true;live('Revoking device…');try{await repo().revokeDevice(d.id);await refresh('Device revoked.');}catch(e){live('Revoke failed: '+((e&&e.message)||e),'error');}finally{D.busy=false;}};
document.addEventListener('keydown',function(e){var x=document.getElementById('mgDeviceManagerRoot');if(e.key==='Escape'&&x&&x.classList.contains('open'))window.mgCloseDeviceNotifications();});
})();


(function(){
'use strict';
if(window.__mgNotificationUxPhase6)return;window.__mgNotificationUxPhase6=true;
function esc(v){return typeof escapeHtml==='function'?escapeHtml(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function find(id){return (window.NOTIFICATIONS||[]).find(function(x){return String(x.id)===String(id);});}
function raw(n){return n&&n.raw&&typeof n.raw==='object'?n.raw:{};}
function repeat(n){return Math.max(0,Number(raw(n).repeat_count!=null?raw(n).repeat_count:n.repeatCount)||0);}
function escalation(n){return Math.max(0,Number(raw(n).escalation_level!=null?raw(n).escalation_level:n.escalationLevel)||0);}
function snoozed(n){var until=n&&(n.snoozedUntil||raw(n).snoozed_until);return until&&Date.parse(until)>Date.now();}
function actionRequired(n){if(!n)return false;var s=String(n.status||'').toLowerCase();return !!n.actionLabel||['ready','pending','action required','action_required','overdue'].indexOf(s)>=0||String(n.priority||'').toLowerCase()==='urgent';}
function fmt(v){if(!v)return 'Not available';var d=new Date(v);return isNaN(d.getTime())?String(v):d.toLocaleString();}
function summary(n){var a=[];if(actionRequired(n))a.push('<span class="mg-n6-chip action">Action required</span>');if(repeat(n)>0)a.push('<span class="mg-n6-chip">Repeated '+repeat(n)+' time'+(repeat(n)===1?'':'s')+'</span>');if(escalation(n)>0)a.push('<span class="mg-n6-chip escalated">Escalation level '+escalation(n)+'</span>');if(snoozed(n))a.push('<span class="mg-n6-chip snoozed">Snoozed until '+esc(fmt(n.snoozedUntil||raw(n).snoozed_until))+'</span>');return a.length?'<div class="mg-n6-summary">'+a.join('')+'</div>':'';}
var previousCard=window.mgNotifCardHtml;
if(previousCard)window.mgNotifCardHtml=function(n,opts){var html=previousCard(n,opts);if(!n||!n.isBackend||opts&&opts.compact)return html;var extra=summary(n)+'<div class="mg-n6-explain">'+(actionRequired(n)?'Open the related HRM item and finish the actual workflow. “Check and complete” only closes this notification when the source item is already resolved.':'This notification currently has no unresolved action requirement.')+'</div><div class="mg-n6-actions"><button type="button" class="mg-n6-btn" onclick="event.stopPropagation();mgOpenSnoozeOptions(\''+esc(n.id)+'\')">Snooze options</button><button type="button" class="mg-n6-btn" onclick="event.stopPropagation();mgOpenNotificationDetails(\''+esc(n.id)+'\')">Reminder details</button></div>';var p=html.lastIndexOf('</div>');return p<0?html+extra:html.slice(0,p)+extra+html.slice(p);};
window.mgOpenSnoozeOptions=function(id){var n=find(id);if(!n||!n.isBackend)return;var def=Math.max(1,Math.min(240,Number((window.MG_TD_CFG||{}).snoozeMin)||15));var options=[def,15,30,60,240].filter(function(v,i,a){return a.indexOf(v)===i;});var body='<div class="mg-n6-dialog"><p>Choose when this reminder should return. Snoozing does not resolve or dismiss the related HRM item.</p><div class="mg-n6-option-grid">'+options.map(function(m){return '<button type="button" class="mg-n6-option" onclick="mgApplySnoozeOption(\''+esc(id)+'\','+m+')">'+(m<60?m+' minutes':m===60?'1 hour':m===240?'4 hours':m+' minutes')+(m===def?' · Default':'')+'</button>';}).join('')+'</div></div>';if(typeof openModal==='function')openModal('Snooze notification',body,'<button type="button" class="btn ghost sm" onclick="closeModal()">Cancel</button>');};
window.mgApplySnoozeOption=async function(id,minutes){if(typeof closeModal==='function')closeModal();await window.mgBackendNotifSnooze(id,minutes);};
window.mgOpenNotificationDetails=function(id){var n=find(id);if(!n)return;var r=raw(n),action=n.actionLabel||r.action_label||'Open related item';var body='<div class="mg-n6-dialog"><dl class="mg-n6-detail-grid"><dt>Status</dt><dd>'+esc(n.status||r.status||'Ready')+'</dd><dt>Priority</dt><dd>'+esc(n.priority||r.priority||'Normal')+'</dd><dt>Category</dt><dd>'+esc(n.category||r.category||'System')+'</dd><dt>Required action</dt><dd>'+esc(action)+'</dd><dt>Scheduled for</dt><dd>'+esc(fmt(n.scheduledFor||r.scheduled_for))+'</dd><dt>Repeated</dt><dd>'+repeat(n)+' time'+(repeat(n)===1?'':'s')+'</dd><dt>Escalation</dt><dd>'+(escalation(n)>0?'Level '+escalation(n):'Not escalated')+'</dd><dt>Snoozed until</dt><dd>'+esc(fmt(n.snoozedUntil||r.snoozed_until))+'</dd></dl><div class="mg-n6-note">Legacy V1 Urgent alerts may bypass quiet hours; this is not approval for V2 P0/P1 emergencies. Repeats and escalation never resolve the underlying HRM work.</div></div>';if(typeof openModal==='function')openModal('Reminder details',body,'<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button>');};
var previousComplete=window.mgBackendNotifComplete;
if(previousComplete)window.mgBackendNotifComplete=async function(id){try{return await previousComplete(id);}catch(e){if(typeof toast==='function')toast('The related HRM item is not resolved yet. Open it and complete the actual workflow first.','warning');throw e;}};
})();


/* Phase 6: a backend-authoritative Smart Policy section INSIDE the existing Settings panel.
 * All privileged writes go through operator-verified, revision-checked RPCs.
 * With migrations pending, show Staged/Unavailable; never simulate a live toggle. */
(function(){
'use strict';
if(window.__mgNotificationPolicyPanel)return;
window.__mgNotificationPolicyPanel=true;
var P={base:null,draft:null,loading:false,saving:false,unavailable:false,problem:'',opening:0};
var fields=[
 ['morning_digest_enabled','Morning digest','toggle','Group outstanding actions at the morning slot.'],
 ['afternoon_digest_enabled','Afternoon wrap-up','toggle','Review outstanding actions and next-office deadline risks.'],
 ['morning_digest_time','Morning digest time','time','Asia/Dhaka; within eligible delivery hours.'],
 ['afternoon_digest_time','Wrap-up digest time','time','Asia/Dhaka; must follow morning time.'],
 ['push_start','Routine Push start','time','Delivery eligibility clock, not the actual business deadline.'],
 ['push_end','Routine Push end','time','Office execution remains a different concept.'],
 ['p3_item_cap_24h','Routine P3 Push / 24h','number','Approved baseline: one successful occurrence per source.'],
 ['p2_item_cap_24h','Important P2 Push / 24h','number','Approved baseline: two successful occurrences per source.'],
 ['p3_cooldown_minutes','P3 cooldown, minutes','optional','Blank means no additional configured cooldown.'],
 ['p2_cooldown_minutes','P2 cooldown, minutes','optional','Blank means no additional configured cooldown.'],
 ['user_cap_24h','Per-user Push cap / 24h','optional','Blank means no approved global user cap.'],
 ['category_cap_24h','Per-category Push cap / 24h','optional','Blank means no approved category cap.']
];
function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function copy(v){return JSON.parse(JSON.stringify(v));}
function client(){return window.MGHRM&&window.MGHRM.client;}
function rpc(name,args){var c=client();if(!c||!c.rpc)return Promise.reject(Error('Backend unavailable'));return c.rpc(name,args||{}).then(function(x){if(x.error)throw x.error;return x.data;});}
function section(){var b=document.getElementById('mgNsBody');if(!b)return null;var e=document.getElementById('mgNsSmartPolicy');if(!e){e=document.createElement('section');e.id='mgNsSmartPolicy';e.className='mg-ns-section mg-ns-engine';e.setAttribute('aria-label','Intelligent notification engine policy');b.appendChild(e);}return e;}
function field(key,title,type,hint){
 var val=P.draft[key],id='mgNsEng_'+key,disabled=P.saving?' disabled':'';
 var control=type==='toggle'?'<input id="'+id+'" type="checkbox" role="switch" '+(val?'checked':'')+disabled+'>'
 :'<input id="'+id+'" type="'+(type==='time'?'time':'number')+'" class="mg-ns-input"'+
 (type==='time'?'': ' min="1" max="'+(key.includes('cooldown')?'1440':key==='user_cap_24h'||key==='category_cap_24h'?'100':'5')+'" step="1"')+
 ' value="'+esc(val==null?'':val)+'" placeholder="'+(type==='optional'?'Not configured':'')+'"'+disabled+'>';
 return '<label class="mg-ns-engine-field" for="'+id+'"><span><strong>'+esc(title)+'</strong><small>'+esc(hint)+'</small></span>'+control+'</label>';
}
function live(message,error){var e=document.getElementById('mgNsEngineLive');if(e){e.textContent=message||'';e.className='mg-ns-engine-live'+(error?' error':'');}}
function valid(){
 var d=P.draft;if(!d)return 'Settings are not loaded';
 var pattern=/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/;
 for(var k of ['push_start','push_end','morning_digest_time','afternoon_digest_time'])if(!pattern.test(d[k]))return 'Please provide valid 24-hour time values.';
 if(!(d.push_start<d.morning_digest_time&&d.morning_digest_time<d.afternoon_digest_time&&d.afternoon_digest_time<d.push_end))return 'Digest times must be inside routine Push hours, in chronological order.';
 for(var k of ['p2_item_cap_24h','p3_item_cap_24h'])if(!Number.isInteger(d[k])||d[k]<1||d[k]>5)return 'Priority Push caps must be 1–5.';
 for(var k of ['p2_cooldown_minutes','p3_cooldown_minutes','user_cap_24h','category_cap_24h']){
  if(d[k]!==null&&(!Number.isInteger(d[k])||d[k]<1||d[k]>(k.includes('cooldown')?1440:100)))return 'Cooldown or user/category cap is outside the allowed range.';
 }
 return '';
}
function changes(){var result={};if(!P.base||!P.draft)return result;fields.forEach(function(f){var k=f[0];if(P.base[k]!==P.draft[k])result[k]=P.draft[k];});return result;}
function ready(){return !P.loading&&!P.saving&&P.base&&P.draft;}
function render(){
 var e=section();if(!e)return;
 if(P.loading){e.innerHTML='<h3>Intelligent Notification Policy</h3><p class="mg-ns-help" role="status">Checking live engine status…</p>';return;}
 if(!P.base){
 e.innerHTML='<h3>Intelligent Notification Policy</h3><p class="mg-ns-help">The existing V1 notification settings above remain available.</p><div class="mg-ns-engine-status" role="status">V2 policy controls are staged, not active. '+esc(P.problem||'Required backend migration is not installed.')+'</div><p class="mg-ns-help">No changes to core engine settings are possible until the server supports authenticated policy access.</p>';
 return;
 }
 var d=P.draft;
 var active=d.governance_enabled===true&&d.digest_bridge_enabled===true;
 e.innerHTML='<div class="mg-ns-engine-top"><div><h3>Intelligent Notification Policy</h3><p class="mg-ns-help">Authoritative server settings · Asia/Dhaka · '+esc(d.policy_version||'Unknown')+' · Revision '+esc(d.revision)+'</p></div><span class="mg-ns-engine-state">'+(active?'Governance active':'Governance staged')+'</span></div>'+
 '<p class="mg-ns-help">Core policy is '+(active?'active':'not yet live')+'. These options require a successful backend save; reading a notification never completes a task.</p>'+
 '<div class="mg-ns-engine-fields">'+fields.map(function(f){return field(f[0],f[1],f[2],f[3]);}).join('')+'</div>'+
 '<div class="mg-ns-engine-locked"><strong>Safety controls</strong><p>Unverified P0 emergencies, P1 after-hours overrides, statutory holidays and payroll deadlines cannot be enabled without a formally approved policy. Digest times never modify real business deadlines.</p></div>'+
 '<div class="mg-ns-engine-actions"><div id="mgNsEngineLive" class="mg-ns-engine-live" role="status" aria-live="polite"></div><button type="button" class="mg-ns-btn" id="mgNsEngineReload">Reload server values</button><button type="button" class="mg-ns-btn primary" id="mgNsEngineSave" '+(Object.keys(changes()).length&&!P.saving?'':'disabled')+'>Save engine policy</button></div>';
 fields.forEach(function(f){var k=f[0],el=document.getElementById('mgNsEng_'+k);if(!el)return;el.addEventListener('change',function(){
  var value=f[2]==='toggle'?el.checked:f[2]==='time'?el.value:el.value.trim()===''?null:Number(el.value);
  P.draft[k]=value;
  var save=document.getElementById('mgNsEngineSave');if(save)save.disabled=!!valid()||!Object.keys(changes()).length||P.saving;
  live(valid(),!!valid());
 });});
 document.getElementById('mgNsEngineReload').addEventListener('click',function(){load();});
 document.getElementById('mgNsEngineSave').addEventListener('click',save);
}
async function load(){
 var e=section();if(!e)return;
 var token=++P.opening;P.loading=true;P.problem='';render();
 try{
  var data=await rpc('notification_operator_policy_read',{});
  if(token!==P.opening)return;
  if(!data||!Number.isInteger(Number(data.revision)))throw Error('Invalid policy server response');
  P.base=copy(data);P.draft=copy(data);
 }catch(err){
  if(token!==P.opening)return;
  P.base=null;P.draft=null;
  // Never silently claim a successfully staged UI switch can change live V1 behavior.
  P.problem=/not found|schema cache|does not exist|404|Backend unavailable/i.test(String(err&&err.message))?
    'The final policy API is not installed on the connected server.':'Policy status is unavailable. Confirm your authorization and connection.';
 }finally{if(token===P.opening){P.loading=false;render();}}
}
async function save(){
 if(!ready())return;
 var msg=valid();if(msg){live(msg,true);return;}
 var diff=changes();if(!Object.keys(diff).length)return;
 var expected=P.base.revision;
 P.saving=true;render();live('Saving and verifying database revision…');
 try{
  var saved=await rpc('notification_operator_policy_save',{p_expected_revision:expected,p_changes:diff});
  if(!saved||saved.saved!==true||Number(saved.readback_revision)!==Number(expected)+1)
   throw Error('Server did not confirm the policy update');
  var checked=await rpc('notification_operator_policy_read',{});
  if(Number(checked.revision)!==Number(saved.readback_revision))
   throw Error('Server read-back revision mismatch');
  for(var key of Object.keys(diff))if(checked[key]!==diff[key])
   throw Error('Server returned a different saved value for '+key);
  P.base=copy(checked);P.draft=copy(checked);P.saving=false;render();live('Policy saved and verified on server.');
 }catch(err){
  P.saving=false;render();
  var conflict=/40001|revision conflict|concurrent/i.test(String(err&&err.message||''));
  live(conflict?'Another device changed the policy. Reload server values and review before saving.':
   'Policy was not confirmed: '+String(err&&err.message||'Connection error'),true);
 }
}
var previous=window.mgOpenNotifSettings;
if(typeof previous==='function'){
 window.mgOpenNotifSettings=window.mtOpenNotifSettings=async function(ev){
  await previous(ev);
  await load();
 };
}
window.mgReloadEngineSettings=load;
})();