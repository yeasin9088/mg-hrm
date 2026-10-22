const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root,'index.html'),'utf8');
const migration = fs.readFileSync(path.join(root,'supabase/migrations/20261022134500_transfer_due_notifications.sql'),'utf8');

function fn(name){
  const start = html.indexOf('function '+name+'(');
  assert.notEqual(start,-1,name+' exists');
  const next = html.indexOf('\nfunction ',start+1);
  return html.slice(start,next < 0 ? undefined : next);
}
function dueHelpers(){
  const ctx={Date,Intl};
  vm.createContext(ctx);
  vm.runInContext(['transferDhakaDate','transferTodayISO','transferScheduledDate','transferIsJoiningDue']
    .map(fn).join('\n'),ctx);
  return ctx;
}

test('Dhaka due-date boundary: three Nov-1 orders unlock together, but not before',()=>{
  const h=dueHelpers();
  const next=[1,2,3].map(id=>({id,status:'Scheduled',effective_date:'2026-11-01'}));
  for(const row of next){
    assert.equal(h.transferIsJoiningDue(row,'2026-10-31'),false);
    assert.equal(h.transferIsJoiningDue(row,'2026-11-01'),true);
    assert.equal(h.transferIsJoiningDue(row,'2026-11-02'),true);
  }
  assert.equal(h.transferIsJoiningDue({status:'Scheduled',effective_date:'2026-10-08'},'2026-10-22'),true);
  assert.equal(h.transferIsJoiningDue({status:'Not Joined',effective_date:'2026-10-08'},'2026-10-22'),false);
  assert.equal(h.transferIsJoiningDue({status:'Completed',effective_date:'2026-10-08'},'2026-10-22'),false);
  assert.equal(h.transferIsJoiningDue({status:'Cancelled',effective_date:'2026-10-08'},'2026-10-22'),false);
  assert.equal(h.transferIsJoiningDue({status:'Joining Pending',effective_date:'2026-11-01'},'2026-10-22'),false);
  assert.equal(h.transferIsJoiningDue({status:'Scheduled',effective_date:'2026-02-30'},'2026-03-01'),false);
  assert.equal(h.transferIsJoiningDue({status:'Scheduled',effective_date:''},'2026-11-01'),false);
});

test('joining and not-joined actions share one server-compatible Dhaka-date guard',()=>{
  const start=html.indexOf('function openConfirmTransferJoining(');
  const end=html.indexOf('function openNotJoinedFollowUp(',start);
  const source=html.slice(start,end);
  assert.equal((source.match(/transferIsJoiningDue\(item\.dRow \|\| item/g)||[]).length,4);
  assert(!source.includes('effectiveDate <= todayISO()'));
  assert(!source.includes('effectiveDate <= transferTodayISO()'));
  assert(html.includes('const isDueForJoining = !employeeInactive && transferIsJoiningDue(t);'));
  assert(html.includes('const isDueForJoining = transferIsJoiningDue(t);'));
});

test('dashboard makes future orders visible without premature Joined actions',()=>{
  const start=html.indexOf('function dashboardTransferQueueHtml(');
  const end=html.indexOf('function dashboardJoiningCardsHtml(',start);
  assert(start>=0 && end>start);
  const ctx={
    transferTodayISO:()=> '2026-10-22',
    dashboardPendingTransfers:rows=>rows.filter(r=>r.effective_date <= '2026-10-22'),
    dashboardJoiningCardsHtml:rows=>'<div>JOINING '+rows.length+'</div>',
    transferScheduledDate:t=>t.effective_date,
    phase2Esc:v=>String(v),
    phase2Date:v=>v
  };
  vm.createContext(ctx);
  vm.runInContext(html.slice(start,end),ctx);
  const rows=[
    {id:195,status:'Scheduled',effective_date:'2026-10-08',overdue_days:14},
    ...[196,197,198].map(id=>({id,status:'Scheduled',effective_date:'2026-11-01'}))
  ];
  const out=ctx.dashboardTransferQueueHtml(rows,[]);
  assert(out.includes('JOINING 1'));
  assert(out.includes('3 upcoming scheduled transfers'));
  assert(out.includes('2026-11-01'));
  assert(out.includes('Asia/Dhaka'));
  assert(!out.includes('Joined / Not Joined actions become available on their effective date (Asia/Dhaka). </button>'));
});

test('Cron reminder producer remains single-operator, idempotent, private and non-mutating',()=>{
  assert(migration.includes("AT TIME ZONE 'Asia/Dhaka'"));
  assert(migration.includes("v_recipients <> 1"));
  assert(migration.includes('ON CONFLICT (event_key) DO NOTHING'));
  assert(migration.includes("t.status IN ('Scheduled','Joining Pending')"));
  assert(migration.includes('t.effective_date <= v_today'));
  assert(migration.includes("REVOKE ALL ON FUNCTION public.mghrm_sync_due_transfer_notifications() FROM PUBLIC, anon, authenticated"));
  assert(!/update\s+public\.employees\b/i.test(migration));
  assert(!/update\s+public\.transfers\b/i.test(migration));
  assert(migration.includes("'action_route','transfer'"));
  assert(migration.includes("'category','Transfer'"));
});
