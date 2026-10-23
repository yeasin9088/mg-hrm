/* Pure inbox rules shared by the controller, presentation and synthetic tests. */
(function (global) {
  'use strict';
  const terminalStates = new Set(['completed', 'dismissed', 'expired', 'cancelled']);
  const readStates = new Set(['read', 'actioned', ...terminalStates]);
  function timestamp(value) {
    const parsed = typeof value === 'number' ? value : Date.parse(value || '');
    return Number.isFinite(parsed) ? parsed : 0;
  }
  function terminal(item) { return terminalStates.has(String(item.status || '').toLowerCase()); }
  function snoozed(item, now = Date.now()) { return timestamp(item.snoozedUntil || item.raw?.snoozed_until) > now; }
  function eligible(item, now = Date.now()) {
    return !terminal(item) && !snoozed(item, now) &&
      (!item.scheduledFor || timestamp(item.scheduledFor) <= now) &&
      (!item.raw?.expires_at || timestamp(item.raw.expires_at) > now);
  }
  function unread(item, now = Date.now()) {
    return eligible(item, now) && !item.isRead && !readStates.has(String(item.status || '').toLowerCase());
  }
  function actionable(item, now = Date.now()) {
    return eligible(item, now) && !!(item.actionLabel || item.actionRoute ||
      ['transfer_join', 'sc', 'rec', 'todo_rem', 'todo_salary'].includes(item.type));
  }
  function legacyKey(item) {
    return String(item.eventKey || item.dedupeKey || ['legacy', item.type || 'general',
      item.ref ?? item.entityId ?? item.id, item.milestone || 'initial'].join(':'));
  }
  function applyLegacyState(item, states) {
    const state = states.get(legacyKey(item));
    if (!state) return item;
    return {...item, status: state.status, isRead: !!state.read_at || state.status === 'Read' || state.status === 'Dismissed',
      snoozedUntil: state.snoozed_until};
  }
  function upsert(rows, record) {
    const old = rows.find(row => String(row.id) === String(record.id));
    if (old && timestamp(old.updated_at) > timestamp(record.updated_at)) return rows;
    return rows.filter(row => String(row.id) !== String(record.id)).concat(record);
  }
  function normalize(row) {
    const aliases = {transfer: 'transfer_join', recruitment: 'rec', disciplinary: 'sc', todo: 'todo_rem', employee: 'rehire'};
    const kind = String(row.action_params?.notification_type || row.event_type || row.entity_type || row.category || 'general').toLowerCase();
    return {id: row.id, backendId: row.id, source: 'backend', isBackend: true,
      type: aliases[kind] || kind.replace(/[^a-z0-9_]+/g, '_'), category: row.category || 'System',
      severity: String(row.severity || 'Info').toLowerCase(), priority: row.priority || 'Normal',
      title: row.title || 'Notification', detail: row.message || '', ref: String(row.entity_id ?? ''),
      entityType: row.entity_type || '', entityId: row.entity_id, actionLabel: row.action_label || '',
      actionRoute: row.action_route || '', actionParams: row.action_params || {}, status: row.status,
      isRead: !!row.read_at || readStates.has(String(row.status || '').toLowerCase()),
      createdAt: timestamp(row.created_at), scheduledFor: row.scheduled_for, snoozedUntil: row.snoozed_until,
      dedupeKey: row.dedupe_key || '', raw: row};
  }
  function merge(backend, legacy, states = new Map()) {
    const canonical = backend.map(normalize);
    const keys = new Set(canonical.map(item => item.dedupeKey).filter(Boolean));
    // Only explicitly matching business identities suppress legacy events. Never
    // merge all milestones for an entity or erase legitimate future reminders.
    const seen = new Set();
    const unique = legacy.filter(item => {
      const key = legacyKey(item);
      if (seen.has(key) || keys.has(key)) return false;
      // An entity can generate several real reminders. A close event time is
      // evidence of the same delivery; a later milestone is not.
      if (['transfer_join','todo_rem','sc','rec'].includes(item.type) && timestamp(item.createdAt) && canonical.some(n =>
        n.type === item.type && n.ref === String(item.ref) &&
        Math.abs(Math.max(timestamp(n.createdAt), timestamp(n.scheduledFor)) - timestamp(item.createdAt)) <= 300000)) return false;
      seen.add(key); return true;
    }).map(item => applyLegacyState(item, states));
    return canonical.concat(unique).sort((a, b) => timestamp(b.createdAt) - timestamp(a.createdAt) || String(a.id).localeCompare(String(b.id)));
  }
  function workThreads(items, now = Date.now()) {
    const groups=new Map(), result=[];
    for(const item of items.flatMap(x=>x.threadMembers||[x])){
      const p=item.actionParams||item.raw?.action_params||{};
      if(!item.isBackend||item.entityType!=='todo'||!p.governance_source_version||!p.policy_reason){result.push(item);continue;}
      const key=String(item.entityId??item.ref), members=groups.get(key)||new Map();
      members.set(String(item.id),item);groups.set(key,members);
    }
    for(const members of groups.values()){
      const all=[...members.values()].sort((a,b)=>timestamp(b.createdAt)-timestamp(a.createdAt)||String(a.id).localeCompare(String(b.id)));
      const representative=all.find(x=>eligible(x,now))||all[0];
      const hasUnread=all.some(x=>unread(x,now));
      result.push({...representative,status:hasUnread?'Ready':representative.status,isRead:!hasUnread,
        threadMembers:all,threadReasons:[...new Set(all.map(x=>(x.actionParams||x.raw?.action_params).policy_reason))]});
    }
    return result.sort((a,b)=>timestamp(b.createdAt)-timestamp(a.createdAt)||String(a.id).localeCompare(String(b.id)));
  }
  function counts(items, now = Date.now()) {
    items=workThreads(items,now);
    return {all: items.length, unread: items.filter(item => unread(item, now)).length,
      action: items.filter(item => actionable(item, now)).length, snoozed: items.filter(item => snoozed(item, now)).length};
  }
  // Presentation only: preserve server identity, state, dedupe keys and schedule.
  function todoPresentation(item, todos = []) {
    if (item.entityType !== 'todo' && !['todo_rem','todo_salary','todo_reminder'].includes(item.type)) return item;
    const id = item.ref || item.entityId || item.actionParams?.todo_id;
    const task = todos.find(task => !task.deleted_at && String(task.id) === String(id));
    if (!task) return item;
    const title = String(task.title || task.note_bn || task.note || task.note_in || '').trim();
    const context = String(task.description || '').trim();
    const due = String(task.due_at || task.due_date || '').trim();
    const schedule = due || item.scheduledFor;
    let when = '';
    if (schedule && /^\d{4}-\d{2}-\d{2}$/.test(schedule)) when = schedule;
    else if (timestamp(schedule)) when = new Intl.DateTimeFormat('en-GB', {timeZone:'Asia/Dhaka',dateStyle:'medium',timeStyle:'short'}).format(new Date(schedule));
    return {...item, title: title ? title.slice(0,160) : item.title,
      detail: [when ? (due ? 'Due: ' : 'Reminder: ') + when : '', context.slice(0,240), item.detail]
        .filter((value,index,all)=>value && all.indexOf(value)===index).join(' · '),
      ref:String(id), actionRoute:'todo'};
  }
  function route(value) {
    const name = String(value || '').replace(/^#?\/?/, '').split('?')[0];
    if (name === 'meetings') return 'meeting';
    return ['dashboard', 'notifications', 'todo', 'transfer', 'employees', 'recruitment', 'disciplinary', 'leave', 'uniform', 'meeting', 'reports'].includes(name) ? name : 'notifications';
  }
  global.NotificationModel = {timestamp, terminal, snoozed, eligible, unread, actionable, legacyKey, applyLegacyState, upsert, normalize, merge, counts, route, todoPresentation,workThreads};
})(typeof window !== 'undefined' ? window : globalThis);
