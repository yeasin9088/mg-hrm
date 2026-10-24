/* Notification Center presentation. No event generation or database writes here. */
(function (global) {
  'use strict';
  const model = global.NotificationModel;
  const view = {pageTab: 'all', panelTab: 'all', category: 'all', priority: 'all', query: '', visible: 50, filtersOpen: false, expandedId: null};
  const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const items = () => model.workThreads((global.NOTIFICATIONS || []).map(item => model.todoPresentation(item, global.DATA?.todos || [])));
  const category = item => item.category || item.entityType || item.type || 'General';
  function filter(tab) {
    return items().filter(item => (tab === 'all' || (tab === 'unread' && model.unread(item)) ||
      (tab === 'action' && model.actionable(item)) || (tab === 'snoozed' && model.snoozed(item))) &&
      (view.category === 'all' || category(item) === view.category) &&
      (view.priority === 'all' || String(item.priority || 'Normal').toLowerCase() === view.priority) &&
      (!view.query.trim() || [item.title,item.detail,category(item)].join(' ').toLocaleLowerCase().includes(view.query.trim().toLocaleLowerCase())));
  }
  function button(action, label, id = '', extra = '') {
    return '<button type="button" class="mg-n-btn" data-notification-action="'+action+'" data-id="'+escape(id)+'" '+extra+'>'+escape(label)+'</button>';
  }
  function tabs(active, where) {
    const counts = model.counts(items());
    return '<div class="mg-n-tabs" role="group" aria-label="Notification filters">'+
      [['all','All'],['unread','Unread'],['action','Action required'],['snoozed','Snoozed']].map(([key,label]) =>
        button('tab',label+' '+counts[key],key,'aria-pressed="'+(active===key)+'" data-where="'+where+'"')).join('')+'</div>';
  }
  function time(item) {
    const value = model.timestamp(item.createdAt);
    if (!value) return '<span class="mg-n-time">Unknown time</span>';
    const date = new Date(value);
    const text = new Intl.DateTimeFormat(undefined, {timeZone:global.MG_TD_CFG?.timezone || 'Asia/Dhaka',month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}).format(date);
    return '<time class="mg-n-time" datetime="'+date.toISOString()+'" title="'+escape(date.toLocaleString())+'">'+escape(text)+'</time>';
  }
  function card(item, compact) {
    const priority = String(item.priority || 'Normal').toLowerCase();
    const safePriority = ['low','normal','high','urgent'].includes(priority) ? priority : 'normal';
    const unread = model.unread(item);
    const preview = escape(item.detail || item.meta || item.message || '');
    const id = escape(item.id);
    const status = (model.terminal(item) || model.snoozed(item))
      ? '<span class="mg-n-chip">'+escape(item.status || 'Snoozed')+'</span>' : '';
    if (compact) {
      return '<article class="mg-n-card '+(unread?'unread':'read')+'" data-notification-id="'+id+'">'+
        '<div class="mg-n-content"><div class="mg-n-top"><button class="mg-n-open" type="button" data-notification-action="open" data-id="'+id+'">'+escape(item.title||'Notification')+'</button>'+time(item)+
        (unread?'<span class="mg-n-unread-dot" aria-label="Unread"></span>':'')+'</div>'+
        '<p class="mg-n-message">'+preview+'</p><div class="mg-n-meta"><span class="mg-n-chip">'+escape(category(item))+'</span>'+status+'</div></div></article>';
    }
    const expanded = view.expandedId === String(item.id);
    const actionsId = 'mg-n-actions-'+id;
    const isTodo=item.isBackend&&item.entityType==='todo';
    const controls = button('open','Open details',item.id) +
      (unread ? button('read','Mark as read',item.id) : '')+
      (!model.terminal(item) ? (isTodo?button('remind','Remind next time',item.id):button('snooze','Snooze',item.id)+button('dismiss','Dismiss',item.id)) : '')+
      (item.isBackend && model.actionable(item) && ['todo','transfer','exit','leave','uniform_supply_order','uniform_delivery_issue','uniform_delivery_bill'].includes(item.entityType)
        ? button('complete',isTodo?'Complete':'Check resolution',item.id) : '');
    return '<article class="mg-n-card '+(unread?'unread':'read')+(expanded?' is-expanded':'')+
      '" data-notification-id="'+id+'" data-notification-expand-row="'+id+'">'+
      '<div class="mg-n-content"><div class="mg-n-top"><button class="mg-n-open" type="button" data-notification-action="toggle" data-id="'+id+
      '" aria-expanded="'+expanded+'" aria-controls="'+actionsId+'">'+escape(item.title||'Notification')+'</button>'+time(item)+
      (unread?'<span class="mg-n-unread-dot" aria-label="Unread"></span>':'')+
      '<span class="mg-n-expand-icon" aria-hidden="true">'+(expanded?'⌃':'⌄')+'</span></div>'+
      '<p class="mg-n-message">'+preview+'</p>'+
      '<div class="mg-n-row-detail" id="'+actionsId+'"'+(expanded?'':' hidden')+'>'+
      (expanded?'<div class="mg-n-meta">'+
        '<span class="mg-n-chip">'+escape(category(item))+'</span>'+
        '<span class="mg-n-chip mg-n-priority-'+safePriority+'">'+escape(priority)+'</span>'+status+'</div>'+
        (item.threadMembers?'<p class="mg-n-message">'+item.threadMembers.length+' alert occurrence(s) · '+item.threadReasons.map(x=>escape(x.replace(/_/g,' '))).join(' · ')+'</p>':'')+
        '<div class="mg-n-row-actions">'+controls+'</div>':'')+'</div>'+
      '</div></article>';
  }
  function stateBanner() {
    const state = global.MG_NOTIFICATION_STATE || {};
    if (state.error) return '<div class="mg-n-error" role="alert">'+escape(state.error)+button('refresh','Retry')+'</div>';
    if (state.loading) return '<div class="mg-n-refresh" role="status">Refreshing notifications…</div>';
    return '';
  }
  function preserveFocus(render) {
    const active = document.activeElement;
    const id = active?.id, selection = active?.selectionStart;
    const action = active?.dataset?.notificationAction, row = active?.dataset?.id;
    render();
    let next = id ? document.getElementById(id) : null;
    if (!next && action) next = [...document.querySelectorAll('[data-notification-action]')].find(el => el.dataset.notificationAction === action && el.dataset.id === row);
    if (!next && action) next = document.querySelector('.mg-n-page .mg-n-open,.mg-n-page button,.mg-n-panel button');
    if (next) {next.focus({preventScroll:true}); if (selection != null && next.type === 'search') next.setSelectionRange(selection,selection);}
  }
  global.renderNotifications = function () {
    const page = document.getElementById('page-notifications'); if (!page) return;
    preserveFocus(() => {
      const rows = filter(view.pageTab), allItems = items();
      const categories = [...new Set(allItems.map(category))].sort();
      const count = model.counts(allItems);
      const activeFilters = Number(!!view.query.trim())+Number(view.category !== 'all')+Number(view.priority !== 'all');
      page.innerHTML = '<section class="mg-n-page mg-n-inbox" aria-label="Notification Center">'+
        '<header class="mg-n-center-head mg-n-inbox-head"><div><h2>Notifications</h2><p>'+count.unread+' unread</p></div></header>'+
        '<div class="mg-n-toolbar-line"><div class="mg-n-inbox-tabs">'+tabs(view.pageTab,'page')+'</div>'+
        '<div class="mg-n-toolbar-actions">'+button('refresh','Refresh')+button('bulk','Mark all read')+
        button('settings','Settings')+button('filter-toggle','Filters'+(activeFilters?' ('+activeFilters+')':''),'',
        'aria-controls="mg-n-extra-filters" aria-expanded="'+view.filtersOpen+'"')+'</div></div>'+
        stateBanner()+
        '<div id="mg-n-extra-filters" class="mg-n-filter-drawer"'+(view.filtersOpen?'':' hidden')+'>'+
          '<div class="mg-n-tools"><input id="notificationSearch" class="mg-n-search" type="search" aria-label="Search notifications" placeholder="Search notifications" value="'+escape(view.query)+'">'+
          '<select id="notificationCategory" class="mg-n-select" aria-label="Notification category"><option value="all">All categories</option>'+categories.map(c=>'<option value="'+escape(c)+'" '+(view.category===c?'selected':'')+'>'+escape(c)+'</option>').join('')+'</select>'+
          '<select id="notificationPriority" class="mg-n-select" aria-label="Notification priority"><option value="all">All priorities</option>'+['low','normal','high','urgent'].map(p=>'<option '+(p===view.priority?'selected':'')+'>'+p+'</option>').join('')+'</select>'+button('clear','Clear filters')+'</div>'+
        '</div>'+
        '<div class="mg-n-page-list">'+(rows.length ? rows.slice(0,view.visible).map(item=>card(item,false)).join('') : '<div class="mg-n-state">'+(global.MG_NOTIFICATION_STATE?.loading?'Loading notifications…':'No notifications match this view.')+'</div>')+'</div>'+
        (rows.length>view.visible?button('more','Show more ('+(rows.length-view.visible)+')'):'')+'</section>';
    });
  };
  global.renderNotifDropdown = function () {
    const dropdown = document.getElementById('notifDropdown'); if (!dropdown) return;
    preserveFocus(() => {
      const rows = filter(view.panelTab);
      dropdown.setAttribute('role','dialog');dropdown.setAttribute('aria-label','Notifications');
      dropdown.classList.add('mg-n-panel');
      dropdown.innerHTML='<div class="mg-n-panel-head"><h3>Notifications · '+model.counts(items()).unread+' unread</h3>'+button('close','Close')+'</div>'+stateBanner()+tabs(view.panelTab,'panel')+
        '<div class="mg-n-list">'+(rows.length ? rows.slice(0,10).map(item=>card(item,true)).join('') : '<div class="mg-n-state">Nothing pending in this view.</div>')+'</div><div class="mg-n-panel-foot">'+button('all','View all notifications')+button('bulk','Mark all read')+'</div>';
    });
  };
  global.mgNUxClose = function () {
    document.getElementById('notifDropdown')?.classList.remove('open');
    document.body.classList.remove('mg-notif-open');
    document.getElementById('notifBell')?.setAttribute('aria-expanded','false');
    document.getElementById('notifBell')?.focus();
  };
  document.addEventListener('input', event => {
    if (event.target.id !== 'notificationSearch') return;
    view.query=event.target.value;view.visible=50;view.expandedId=null;global.renderNotifications();
  });
  document.addEventListener('change', event => {
    const key = {notificationCategory:'category',notificationPriority:'priority'}[event.target.id];
    if (key) {view[key]=event.target.value;view.visible=50;view.expandedId=null;global.renderNotifications();}
  });
  async function toggleRow(id){
    const opening=view.expandedId!==String(id);
    if(opening&&global.MG_SIMPLE_NOTIFICATIONS&&await global.markNotifAsRead(id)===false)return;
    view.expandedId=opening?String(id):null;global.renderNotifications();
  }
  document.addEventListener('click', async event => {
    const target = event.target.closest?.('[data-notification-action]');
    if (!target) {
      const row = event.target.closest?.('.mg-n-page .mg-n-card[data-notification-expand-row]');
      if (row) await toggleRow(row.dataset.notificationExpandRow);
      return;
    }
    if (target.disabled) return;
    const {notificationAction:action,id,where} = target.dataset;
    event.stopPropagation();
    const applyThread=async(kind)=>{
      const thread=items().find(x=>String(x.id)===String(id));
      const members=(thread?.threadMembers||[thread]).filter(Boolean);
      for(const member of members){
        if(model.terminal(member)||kind==='read'&&!model.unread(member))continue;
        const result=await ({read:()=>global.markNotifAsRead(member.id),snooze:()=>global.mgBackendNotifSnooze(member.id,global.MG_TD_CFG?.snoozeMin||15),dismiss:()=>global.mgBackendNotifDismiss(member.id),complete:()=>global.mgBackendNotifComplete(member.id)})[kind]();
        if(result===false)return false;
      }
      return true;
    };
    const actions = {read:()=>applyThread('read'),open:async()=>{if(await applyThread('read'))return global.handleNotifClick(id);},bulk:()=>global.markAllNotifsAsRead(),
      remind:()=>global.mgBackendNotifRemind(id),snooze:()=>applyThread('snooze'),dismiss:()=>applyThread('dismiss'),complete:()=>applyThread('complete'),refresh:()=>global.mgLoadBackendNotifications()};
    if (actions[action]) {target.disabled=true;target.setAttribute('aria-busy','true');try{await actions[action]();}finally{target.disabled=false;target.removeAttribute('aria-busy');}return;}
    if (action==='toggle') {await toggleRow(id);return;}
    if (action==='filter-toggle') {view.filtersOpen=!view.filtersOpen;global.renderNotifications();return;}
    if (action==='tab') {view[where==='panel'?'panelTab':'pageTab']=id;view.visible=50;view.expandedId=null;(where==='panel'?global.renderNotifDropdown:global.renderNotifications)();}
    if (action==='more') {view.visible+=50;global.renderNotifications();}
    if (action==='clear') {view.query='';view.category='all';view.priority='all';view.visible=50;view.expandedId=null;global.renderNotifications();}
    if (action==='settings') global.mtOpenNotifSettings();
    if (action==='close') global.mgNUxClose();
    if (action==='all') {global.mgNUxClose();global.navigate('notifications');}
  });
  document.addEventListener('keydown', event => {
    const modal = document.querySelector('.mg-dm-backdrop.open,.mg-ns-backdrop.open') ||
      (innerWidth<=768 ? document.querySelector('#notifDropdown.open') : null);
    if (event.key==='Escape' && document.getElementById('notifDropdown')?.classList.contains('open')) global.mgNUxClose();
    if (event.key!=='Tab'||!modal)return;
    const controls=[...modal.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled),[tabindex="0"]')].filter(el=>el.getClientRects().length);
    if(!controls.length)return;
    const edge=event.shiftKey?controls[0]:controls[controls.length-1];
    if(document.activeElement===edge){event.preventDefault();controls[event.shiftKey?controls.length-1:0].focus();}
  });
})(window);
