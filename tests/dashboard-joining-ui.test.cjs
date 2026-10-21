const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync(require('node:path').join(__dirname,'../index.html'),'utf8');
const start = html.indexOf('function dashboardJoiningCardsHtml(rows){');
const end = html.indexOf('async function openDashboardTransfer(',start);
assert(start !== -1 && end > start, 'Dashboard joining card renderer exists');

function render(rows) {
  const source = html.slice(start,end);
  const context = {
    phase2Esc: value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])),
    phase2Date: value => String(value || '')
  };
  vm.createContext(context);
  vm.runInContext(source,context);
  return context.dashboardJoiningCardsHtml(rows);
}
const sample = {
  transfer_id:195,employee_sys_id:245,full_name:'Synthetic Employee',queue_status:'Joining Pending',
  current_project:'Very long source project name that must wrap naturally without truncation',
  new_project:'Very long destination project name that must remain fully visible on mobile',
  effective_date:'2026-10-08',overdue_days:13
};
test('Dashboard joining card includes full project names, metadata and review action',()=>{
  const result=render([sample]);
  for(const value of [sample.full_name,sample.current_project,sample.new_project,
    'Employee #245','Order #195','Effective:','13d overdue','openDashboardTransfer(195)']){
    assert(result.includes(value),value);
  }
  assert(!result.includes('Confirm Joined'));
});
test('Cards support multiple records, pending badge, capped list and escaping',()=>{
  const rows=Array.from({length:10},(_,i)=>({...sample,transfer_id:i+1,full_name:i===0?'<script>alert(1)</script>':'Synthetic',overdue_days:i===0?0:2}));
  const result=render(rows);
  assert.match(result,/10 pending/);
  assert.match(result,/9 overdue/);
  assert.match(result,/Pending/);
  assert.match(result,/2 more confirmations/);
  assert(!result.includes('<script>'));
  assert(result.includes('&lt;script&gt;'));
  assert.equal((result.match(/class="dj-entry"/g)||[]).length,8);
});
test('Responsive dashboard joining layout avoids fixed-width clipped route pills',()=>{
  const css=html.slice(0,html.indexOf('</style>'));
  assert.match(css,/\.dj-route\{[^}]*grid-template-columns:minmax\(0,1fr\)/);
  assert.match(css,/\.dj-project\{[^}]*overflow-wrap:anywhere/);
  assert.match(css,/@media\(max-width:600px\)/);
  assert.match(css,/\.dj-route\{grid-template-columns:minmax\(0,1fr\)/);
  assert.match(css,/\.dj-review\{width:100%/);
  assert(!html.slice(start,end).includes('trq-route-pill'));
});
test('Dashboard joining UI only links to existing review workflow',()=>{
  const section=html.slice(start,end);
  assert(section.includes('openDashboardTransfer('));
  assert(!section.includes('confirmTransferJoined('));
  assert(!section.includes('employees.project_name'));
  assert(!section.includes('.update('));
});
