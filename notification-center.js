/* ===== Notification Inbox server integration: Phase 2C ===== */
(function () {
  'use strict';
  if (window.__mgNotificationPhase2C) return;
  window.__mgNotificationPhase2C = true;

  window.MG_NOTIFICATION_ENGINE_MODE = window.MG_NOTIFICATION_ENGINE_MODE || 'hybrid';
  window.MG_BACKEND_NOTIFICATIONS = window.MG_BACKEND_NOTIFICATIONS || [];
  window.MG_LEGACY_NOTIFICATIONS = window.MG_LEGACY_NOTIFICATIONS || [];
  window.MG_NOTIFICATION_STATE = window.MG_NOTIFICATION_STATE || { loading:false, loaded:false, error:null, lastLoadedAt:null };

  function repo() { return window.MGHRM && window.MGHRM.notifications; }
  const model = window.NotificationModel;
  let states = new Map(), generation = 0, revision = 0, loading = null, reloadTimer = null, invalidated = false;
  const busy = new Set();
  const report = message => { if (typeof toast === 'function') toast(message, 'error'); };
  window.mgNormalizeBackendNotification = model.normalize;
  window.getUnreadNotifCount = () => model.counts(window.NOTIFICATIONS || []).unread;
  window.mgRebuildNotificationView = function () {
    const current = window.NOTIFICATIONS || [];
    const legacy = new Map((window.MG_LEGACY_NOTIFICATIONS || []).map(n => [model.legacyKey(n), n]));
    current.filter(n => n && !n.isBackend).forEach(n => legacy.set(model.legacyKey(n), n));
    window.MG_LEGACY_NOTIFICATIONS = [...legacy.values()];
    const merged = model.merge(window.MG_BACKEND_NOTIFICATIONS || [], [...legacy.values()], states);
    current.splice(0, current.length, ...merged);
    window.NOTIFICATIONS = current;
    if (typeof updateNotifBadge === 'function') updateNotifBadge();
    const dropdown = document.getElementById('notifDropdown');
    if (dropdown?.classList.contains('open') && typeof renderNotifDropdown === 'function') renderNotifDropdown();
    const page = document.getElementById('page-notifications');
    if (page && page.style.display !== 'none' && typeof renderNotifications === 'function') renderNotifications();
    return current;
  };
  window.mgLoadBackendNotifications = function () {
    if (!repo()) return Promise.resolve([]);
    if (loading) return loading;
    const version = generation, stateVersion = revision;
    invalidated = false;
    window.MG_NOTIFICATION_STATE.loading = true;
    window.MG_NOTIFICATION_STATE.error = null;
    loading = (async () => {
      try {
        const [rows, savedStates] = await Promise.all([repo().list(), repo().legacyStates()]);
        if (version !== generation) return [];
        if (stateVersion !== revision) { invalidated = true; return []; }
        window.MG_BACKEND_NOTIFICATIONS = rows;
        states = new Map(savedStates.map(row => [row.event_key, row]));
        window.MG_NOTIFICATION_STATE.loaded = true;
        window.MG_NOTIFICATION_STATE.lastLoadedAt = Date.now();
        return rows;
      } catch (error) {
        if (version === generation) window.MG_NOTIFICATION_STATE.error = error.message || String(error);
        return [];
      } finally {
        if (version === generation) {
          window.MG_NOTIFICATION_STATE.loading = false;
          loading = null;
          window.mgRebuildNotificationView();
          if(window.mgTryPendingPushOpen)window.mgTryPendingPushOpen();
          if (invalidated) reloadTimer = setTimeout(() => window.mgLoadBackendNotifications(), 0);
        }
      }
    })();
    return loading;
  };
  async function change(id, operation) {
    if (busy.has(String(id))) return false;
    busy.add(String(id));
    try {
      const row = await operation();
      revision++;
      if (row) window.MG_BACKEND_NOTIFICATIONS = model.upsert(window.MG_BACKEND_NOTIFICATIONS, row);
      return true;
    } catch (error) { report('Notification change was not confirmed: ' + error.message); return false; }
    finally { busy.delete(String(id)); window.mgRebuildNotificationView(); }
  }
  function find(id) { return (window.NOTIFICATIONS || []).find(n => String(n.id) === String(id)); }
  async function legacyChange(item, status, until) {
    const row = await repo().setLegacyState(model.legacyKey(item), {status, snoozed_until: until || null,
      read_at: status === 'Read' || status === 'Dismissed' ? new Date().toISOString() : (item.isRead ? new Date().toISOString() : null)});
    states.set(row.event_key, row);
  }
  function persisted(result, id) {
    if (!result?.notification || String(result.notification.id) !== String(id)) throw Error('Incomplete persisted notification response');
    return result.notification;
  }
  window.markNotifAsRead = async function (id) {
    const item = find(id); if (!item || item.isRead) return true;
    return change(id, async () => item.isBackend ? persisted(await repo().markRead(id), id) : (await legacyChange(item, 'Read'), null));
  };
  window.markAllNotifsAsRead = async function () {
    return change('bulk-read', async () => {
      await repo().markAllRead();
      for (const item of (window.NOTIFICATIONS || []).filter(n => !n.isBackend && model.unread(n))) await legacyChange(item, 'Read');
      await window.mgLoadBackendNotifications();
      if (window.MG_NOTIFICATION_STATE.error) throw Error(window.MG_NOTIFICATION_STATE.error);
      return null;
    });
  };
  window.handleNotifClick = async function (id) {
    const item = find(id); if (!item) return;
    const success = await change(id, async () => item.isBackend ? persisted(await repo().open(id), id) : (await legacyChange(item, 'Read'), null));
    if (!success) return;
    document.getElementById('notifDropdown')?.classList.remove('open');
    const legacyRoutes = {sc:'disciplinary', rec:'recruitment', transfer_join:'transfer', rehire:'employees', todo_rem:'todo', todo_salary:'todo'};
    const display = model.todoPresentation(item, window.DATA?.todos || []);
    const route = model.route(display.actionRoute || legacyRoutes[item.type] || item.entityType);
    if (route === 'todo' && display.ref && typeof window.mgTodoNotifOpen === 'function') window.mgTodoNotifOpen(display.ref);
    else if (route === 'disciplinary' && item.isBackend && item.entityType === 'disciplinary' &&
      item.ref && typeof window.mgOpenDisciplinaryRecord === 'function') window.mgOpenDisciplinaryRecord(item.ref);
    else if (route === 'transfer' && item.ref && typeof navigate === 'function') {
      if (typeof window.openDashboardTransfer === 'function') window.openDashboardTransfer(item.ref);
      else { navigate('transfer'); if (typeof window.openTransferPopup === 'function') window.openTransferPopup(item.ref); }
    } else if (typeof navigate === 'function') navigate(route);
  };
  window.mgBackendNotifSnooze = async function (id, minutes) {
    const item = find(id); if (!item) return false;
    const until = new Date(Date.now() + Math.max(1, Math.min(10080, Number(minutes) || 15)) * 60000).toISOString();
    return change(id, async () => item.isBackend ? persisted(await repo().snooze(id, until), id) : (await legacyChange(item, 'Snoozed', until), null));
  };
  window.mgBackendNotifDismiss = window.dismissNotif = async function (id) {
    const item = find(id); if (!item) return false;
    return change(id, async () => item.isBackend ? persisted(await repo().dismiss(id), id) : (await legacyChange(item, 'Dismissed'), null));
  };
  window.mgBackendNotifComplete = async function (id) {
    const item = find(id); if (!item?.isBackend) return false;
    return change(id, async () => {
      const result = await repo().completeIfResolved(id);
      const row = persisted(result, id);
      if (row.status !== 'Completed') throw Error('The related workflow is not resolved');
      if (typeof toast === 'function') toast('Notification completed', 'success');
      return row;
    });
  };

  function dbToCfg(r){ return {master:r.notification_enabled!==false,toast:r.toast_enabled!==false,toastMax:r.toast_max_visible||2,toastGapSec:r.toast_gap_seconds||60,snoozeMin:r.default_snooze_minutes||15,quietOn:r.quiet_hours_enabled!==false,quietStart:String(r.quiet_hours_start||'22:00').slice(0,5),quietEnd:String(r.quiet_hours_end||'07:00').slice(0,5),systemPush:r.system_push_enabled!==false,minimumPriority:r.minimum_priority||'Low',timezone:r.timezone||'Asia/Dhaka'}; }
  window.mgNotifCfgLoad=async function(){
    var cached={}; try{cached=JSON.parse(localStorage.getItem('mghrm_notif_cfg')||'{}')||{};}catch(e){}
    window.MG_TD_CFG=Object.assign({},window.MG_TD_CFG_DEFAULTS||{},cached);
    try{var rows=await repo().getPreferences();var row=(rows||[]).find(function(x){return x.category==='*';})||rows[0];if(row){window.MG_TD_CFG=Object.assign({},window.MG_TD_CFG,dbToCfg(row));localStorage.setItem('mghrm_notif_cfg',JSON.stringify(window.MG_TD_CFG));}return window.MG_TD_CFG;}
    catch(e){console.warn('[Notification Preferences]',e);return window.MG_TD_CFG;}
  };
  window.mgNotifCfgSave=async function(patch){
    var previous=Object.assign({},window.MG_TD_CFG||{}); var next=Object.assign({},previous,patch||{}); window.MG_TD_CFG=next;
    var db={notification_enabled:next.master!==false,in_app_enabled:true,toast_enabled:next.toast!==false,system_push_enabled:next.systemPush!==false,minimum_priority:next.minimumPriority||'Low',quiet_hours_enabled:next.quietOn!==false,quiet_hours_start:next.quietStart||'22:00',quiet_hours_end:next.quietEnd||'07:00',urgent_bypass_enabled:true,timezone:next.timezone||'Asia/Dhaka',default_snooze_minutes:Math.max(1,Number(next.snoozeMin)||15),toast_max_visible:Math.max(1,Math.min(3,Number(next.toastMax)||2)),toast_gap_seconds:Math.max(10,Math.min(600,Number(next.toastGapSec)||60))};
    try{await repo().updatePreferences(db,'*');localStorage.setItem('mghrm_notif_cfg',JSON.stringify(next));return true;}
    catch(e){window.MG_TD_CFG=previous;if(typeof toast==='function')toast('Settings were not saved: '+((e&&e.message)||e),'error');return false;}
  };

  window.mgLoadNotificationDevices=async function(){ try{return await repo().listDevices();}catch(e){console.warn('[Notification Devices]',e);return [];} };
  function mgUrlBase64ToUint8Array(value){
    var padding='='.repeat((4-value.length%4)%4);
    var base64=(value+padding).replace(/-/g,'+').replace(/_/g,'/');
    var raw=atob(base64), out=new Uint8Array(raw.length);
    for(var i=0;i<raw.length;i++)out[i]=raw.charCodeAt(i);
    return out;
  }
  function mgPushKey(subscription,name){
    var key=subscription.getKey(name);
    if(!key)throw new Error('Browser did not provide the '+name+' subscription key.');
    var bytes=new Uint8Array(key), binary='';
    for(var i=0;i<bytes.length;i++)binary+=String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  }
  function mgBrowserName(){
    var ua=navigator.userAgent;
    if(/Edg\//.test(ua))return 'Microsoft Edge';
    if(/Firefox\//.test(ua))return 'Firefox';
    if(/Chrome\//.test(ua))return 'Chrome';
    if(/Safari\//.test(ua))return 'Safari';
    return 'Browser';
  }
  window.mgEnableDeviceNotifications=async function(){
    if(!repo())throw new Error('Notification repository is unavailable.');
    if(!window.isSecureContext||!('Notification' in window)||!('serviceWorker' in navigator)||!('PushManager' in window)){
      if(typeof toast==='function')toast('Device notifications are unsupported in this browser or connection.','warning');
      return 'unsupported';
    }
    try{
      var permission=Notification.permission;
      if(permission==='default')permission=await Notification.requestPermission();
      if(permission!=='granted'){
        if(typeof toast==='function')toast('Device notification permission is blocked. Enable it in browser site settings.','warning');
        return 'blocked';
      }
      var registration=await navigator.serviceWorker.ready;
      var config=await repo().getWebPushConfig();
      var subscription=await registration.pushManager.getSubscription();
      if(subscription){
        var options=subscription.options||{};
        var existingKey=options.applicationServerKey?new Uint8Array(options.applicationServerKey):null;
        var expectedKey=mgUrlBase64ToUint8Array(config.publicKey);
        var same=existingKey&&existingKey.length===expectedKey.length&&existingKey.every(function(v,i){return v===expectedKey[i];});
        if(!same){await subscription.unsubscribe();subscription=null;}
      }
      if(!subscription){
        subscription=await registration.pushManager.subscribe({
          userVisibleOnly:true,
          applicationServerKey:mgUrlBase64ToUint8Array(config.publicKey)
        });
      }
      var result=await repo().registerDevice({
        endpoint:subscription.endpoint,
        p256dh_key:mgPushKey(subscription,'p256dh'),
        auth_key:mgPushKey(subscription,'auth'),
        device_label:mgBrowserName()+' on '+(navigator.platform||'device'),
        browser_name:mgBrowserName(),
        platform_name:navigator.platform||null,
        user_agent:navigator.userAgent
      });
      const session = await window.MGHRM.getSession();
      if (session?.user && result?.subscription_id) localStorage.setItem('mghrm-push-device-'+session.user.id,String(result.subscription_id));
      if(typeof toast==='function')toast('Device notifications enabled successfully.','success');
      await window.mgLoadNotificationDevices();
      return result||'enabled';
    }catch(e){
      console.error('[Device Notifications]',e);
      if(typeof toast==='function')toast('Could not enable device notifications: '+((e&&e.message)||String(e)),'error');
      throw e;
    }
  };
  window.mgOpenDeviceNotifications=async function(){
    var supported=('Notification' in window)&&('serviceWorker' in navigator);
    var permission=supported?Notification.permission:'unsupported';
    var devices=await window.mgLoadNotificationDevices();
    var state=!supported?'Unsupported':permission==='denied'?'Blocked':devices.some(function(d){return d.is_active;})?'Enabled':devices.some(function(d){return d.revoked_at||d.permission_state==='revoked';})?'Revoked':'Not configured';
    var rows=devices.length?devices.map(function(d){return '<div style="padding:8px 0;border-top:1px solid var(--border)"><strong>'+escapeHtml(d.device_label||d.browser_name||'Device')+'</strong><div style="font-size:12px;color:var(--text-mute)">'+escapeHtml((d.platform_name||'')+' · '+(d.permission_state||state))+'</div></div>';}).join(''):'<div style="font-size:12px;color:var(--text-mute)">No registered devices.</div>';
    var html='<div style="display:flex;flex-direction:column;gap:12px"><div><strong>Device notifications:</strong> '+escapeHtml(state)+'</div>'+rows+'<div style="font-size:12px;color:var(--text-mute)">Subscription delivery activates after VAPID and the push sender are configured.</div></div>';
    var actions='<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button><button type="button" class="btn primary sm" onclick="mgEnableDeviceNotifications().then(function(){mgOpenDeviceNotifications();})">Enable Device Notifications</button>';
    if(typeof openModal==='function')openModal('Device notifications',html,actions);
  };


  window.mgHandleSystemNotificationClick=function(data){
    data=data||{};
    var route=model.route(data.route);
    var allowed=['dashboard','notifications','todo','transfer','employees','recruitment','disciplinary','leave','uniform','meeting','reports'];
    if(allowed.indexOf(route)===-1)route='notifications';
    if(data.notificationId){
      var n=(window.NOTIFICATIONS||[]).find(function(x){return String(x.id)===String(data.notificationId);});
      if(n&&n.isBackend){window.handleNotifClick(n.id,n.type);return;}
      // A URL supplied by a push may only open a record present in this account's Inbox.
      if(/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(String(data.notificationId))){
        var pending=new URLSearchParams(location.search);pending.set('notification_id',String(data.notificationId));pending.set('notification_route',route);
        history.replaceState(null,'',location.pathname+'?'+pending+location.hash);
        if(!window.MG_NOTIFICATION_STATE.loading)window.mgLoadBackendNotifications();
      }
      return;
    }
    if(route==='todo'&&data.entityId&&typeof window.mgTodoNotifOpen==='function')window.mgTodoNotifOpen(data.entityId);
    else if(typeof navigate==='function')navigate(route);
  };
  window.mgTryPendingPushOpen=function(){
    var q=new URLSearchParams(location.search),id=q.get('notification_id'),route=q.get('notification_route');
    if(!id||!route)return;
    var own=(window.NOTIFICATIONS||[]).find(function(x){return x.isBackend&&String(x.id)===id;});
    if(!own)return; // Keep the intent through a cold Auth start until this user's Inbox loads.
    q.delete('notification_route');q.delete('notification_id');q.delete('notification_entity');
    history.replaceState(null,'',location.pathname+(q.toString()?'?'+q:'')+location.hash);
    window.mgHandleSystemNotificationClick({route:route,notificationId:id});
  };
  if('serviceWorker' in navigator){
    navigator.serviceWorker.addEventListener('message',function(event){
      var data=event.data||{};
      if(data.type==='MG_PUSH_SUBSCRIPTION_CHANGED'){window.MG_NOTIFICATION_STATE.error='Device registration changed. Re-enable this browser in notification settings.';window.mgRebuildNotificationView();}
      if(data.type==='MG_NOTIFICATION_CLICK')window.mgHandleSystemNotificationClick(data);
    });
    if(new URLSearchParams(location.search).has('notification_id'))setTimeout(async function(){await window.mgLoadBackendNotifications();window.mgTryPendingPushOpen();},900);
  }

  window.mgHandleNotificationRealtime = function () {
    invalidated = true;
    if (loading) return;
    // Invalidation avoids reconnect/reload races and out-of-order state regression.
    clearTimeout(reloadTimer);
    reloadTimer = setTimeout(() => window.mgLoadBackendNotifications(), 150);
  };
  let foregroundPresence=null, presenceUser=null;
  async function refreshPresence(session) {
    const version=generation;
    let enabled=false;
    try { enabled=await repo()?.reminderMode?.(); } catch (_) { /* Pre-migration or offline: absence never suppresses push. */ }
    if(version!==generation) return;
    if(foregroundPresence && (!enabled || !session?.user || presenceUser!==session.user.id)) {
      foregroundPresence.stop(); foregroundPresence=null; presenceUser=null;
    }
    if(enabled && session?.user && !foregroundPresence && window.NotificationPresence && window.crypto?.randomUUID && repo()?.presenceHeartbeat) {
      presenceUser=session.user.id;
      foregroundPresence=window.NotificationPresence.create({window,document,heartbeat:params=>repo().presenceHeartbeat(params)});
    }
  }
  async function start() {
    const version=generation;
    const session=await window.MGHRM.getSession();
    if(version!==generation||!session?.user) return;
    refreshPresence(session).catch(()=>{});
    await window.mgLoadBackendNotifications();
    window.mgNotifCfgLoad();
    if (repo()?.subscribe) {
      try { await repo().subscribe(window.mgHandleNotificationRealtime); } catch (error) { report('Realtime unavailable; automatic refresh remains active'); }
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => setTimeout(start, 500));
  else setTimeout(start, 500);
  if (window.MGHRM?.onChange) window.MGHRM.onChange(function (event, session) {
    if(foregroundPresence && (!session?.user || presenceUser!==session.user.id)) { foregroundPresence.stop(); foregroundPresence=null;presenceUser=null; }
    generation++; loading = null;
    window.MG_NOTIFICATION_STATE.loading = false;
    if (session?.user) start();
    else {
      if (repo()?.unsubscribe) repo().unsubscribe();
      window.MG_BACKEND_NOTIFICATIONS = [];
      window.MG_LEGACY_NOTIFICATIONS = [];
      if (window.NOTIFICATIONS) window.NOTIFICATIONS.length = 0;
      states.clear();
      window.MG_NOTIFICATION_STATE.loaded = false;
      window.mgRebuildNotificationView();
    }
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) window.mgHandleNotificationRealtime(); });
  window.addEventListener('online', window.mgHandleNotificationRealtime);
  setInterval(() => { if (!document.hidden) { window.mgHandleNotificationRealtime(); window.MGHRM?.getSession?.().then(refreshPresence).catch(()=>{}); } }, 60000);
})();
