const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('notification-ui.js', 'utf8');
const model = fs.readFileSync('notification-model.js', 'utf8');
const css = fs.readFileSync('notification-ui.css', 'utf8');

function renderFixture() {
  const events = {};
  const page = {innerHTML: ''};
  const dropdown = {innerHTML: '',classList:{add(){}},setAttribute(){}};
  const document = {
    activeElement: null,
    addEventListener(name, handler) { events[name] = handler; },
    getElementById(id) { return id === 'page-notifications' ? page : id === 'notifDropdown' ? dropdown : null; },
    querySelectorAll() { return []; },
    querySelector() { return null; }
  };
  const c = vm.createContext({document, console, Intl, Date});
  c.window = c;
  c.NOTIFICATIONS = [
    {id: 'n1', type: 'todo_rem', entityType: 'todo', ref: '9',
      title: 'Review staffing plan',detail: 'Project shift coverage review',status: 'Ready',
      priority: 'normal',isBackend: true,createdAt: Date.parse('2026-10-21T12:00:00Z')},
    {id: 'n2',title: 'Already read', detail:'Older update', isRead:true,status:'Read',
      createdAt:Date.parse('2026-10-20T12:00:00Z')}
  ];
  c.DATA = {todos:[]};
  c.MG_NOTIFICATION_STATE = {};
  vm.runInContext(model, c);
  vm.runInContext(source, c);
  const click = async (action, id = '', where = 'page') => {
    const target = {
      disabled: false,
      dataset: {notificationAction: action, id, where},
      setAttribute(){}, removeAttribute(){},
      closest(selector){return selector === '[data-notification-action]' ? this : null;}
    };
    await events.click({target, stopPropagation(){}});
  };
  return {c, page, events, click};
}

test('Notification inbox shows categories as compact tabs and keeps advanced filters hidden on initial render',()=>{
  const {c,page}=renderFixture();
  c.renderNotifications();
  assert.match(page.innerHTML,/mg-n-toolbar-line/);
  assert.match(page.innerHTML,/Notification filters/);
  assert.match(page.innerHTML,/Mark all read/);
  assert.match(page.innerHTML,/aria-controls="mg-n-extra-filters" aria-expanded="false"/);
  assert.match(page.innerHTML,/id="mg-n-extra-filters" class="mg-n-filter-drawer" hidden/);
  assert.match(page.innerHTML,/mg-n-page-list/);
  assert.match(page.innerHTML,/Review staffing plan/);
  assert(!page.innerHTML.includes('data-notification-action="snooze"'));
  assert(!page.innerHTML.includes('data-notification-action="dismiss"'));
});

test('Selecting a notification expands only that row and leaves persisted unread status unchanged',async()=>{
  const {c,page,click}=renderFixture();
  c.renderNotifications();
  const before = c.NOTIFICATIONS[0].isRead;
  await click('toggle','n1');
  assert.match(page.innerHTML,/mg-n-card unread is-expanded/);
  assert.match(page.innerHTML,/aria-expanded="true"/);
  assert.match(page.innerHTML,/data-notification-action="open"/);
  assert.match(page.innerHTML,/data-notification-action="read"/);
  assert.match(page.innerHTML,/data-notification-action="snooze"/);
  assert.match(page.innerHTML,/data-notification-action="dismiss"/);
  assert.match(page.innerHTML,/mg-n-row-detail/);
  assert.equal(c.NOTIFICATIONS[0].isRead,before);
  await click('toggle','n1');
  assert(!page.innerHTML.includes('mg-n-card unread is-expanded'));
  assert(!page.innerHTML.includes('data-notification-action="dismiss"'));
});

test('Advanced search and category filtering remain accessible only after Filters is opened',async()=>{
  const {c,page,click,events}=renderFixture();
  c.renderNotifications();
  await click('filter-toggle');
  assert.match(page.innerHTML,/aria-controls="mg-n-extra-filters" aria-expanded="true"/);
  assert(!page.innerHTML.includes('class="mg-n-filter-drawer" hidden'));
  assert.match(page.innerHTML,/id="notificationSearch"/);
  events.input({target:{id:'notificationSearch',value:'review staffing'}});
  assert.match(page.innerHTML,/Review staffing plan/);
  assert(!page.innerHTML.includes('Already read'));
  await click('filter-toggle');
  assert.match(page.innerHTML,/class="mg-n-filter-drawer" hidden/);
  assert.match(page.innerHTML,/Filters \(1\)/);
  await click('filter-toggle');
  await click('clear');
  assert.match(page.innerHTML,/Already read/);
  assert.match(page.innerHTML,/aria-expanded="true"/);
});

test('Switching page tabs closes expanded actions without marking notifications read',async()=>{
  const {c,page,click}=renderFixture();
  c.renderNotifications();
  await click('toggle','n1');
  await click('tab','unread','page');
  assert(!page.innerHTML.includes('data-notification-action="dismiss"'));
  assert.match(page.innerHTML,/aria-pressed="true" data-where="page"/);
  assert.match(page.innerHTML,/Review staffing plan/);
  assert(!page.innerHTML.includes('Already read'));
  assert.equal(c.NOTIFICATIONS[0].isRead,undefined);
});

test('Text-like actions, compact rows and mobile filter layout keep existing controls discoverable',()=>{
  assert.match(css,/\.mg-n-inbox \.mg-n-row-actions \.mg-n-btn\{[^}]*min-height:30px/);
  assert.match(css,/\.mg-n-inbox \.mg-n-filter-drawer\[hidden\]\{display:none!important/);
  assert.match(css,/\.mg-n-inbox \.mg-n-message\{[^}]*-webkit-line-clamp:1/);
  assert.match(css,/@media\(max-width:600px\)/);
  assert.match(css,/\.mg-n-inbox \.mg-n-toolbar-actions\{flex-wrap:nowrap/);
  assert.match(source,/open:.*global\.handleNotifClick\(id\)/);
  assert.match(source,/snooze:.*global\.mgBackendNotifSnooze\(id/);
  assert.match(source,/dismiss:.*global\.mgBackendNotifDismiss\(id\)/);
  assert.match(source,/complete:.*global\.mgBackendNotifComplete\(id\)/);
});
