const test=require('node:test'),assert=require('node:assert/strict');
const m=require('../swa-model.js');
test('Dhaka boundary: 17:59 execution, 18:00 not, 08:59 not, 09:00 yes',()=>{
 assert.equal(m.officeTime('2026-10-22T11:59:00Z'),true);
 assert.equal(m.officeTime('2026-10-22T12:00:00Z'),false);
 assert.equal(m.officeTime('2026-10-23T02:59:00Z'),false);
 assert.equal(m.officeTime('2026-10-23T03:00:00Z'),true);
});
test('24h communication, deadline not shifted, next office date provisional',()=>{
 const now='2026-10-22T15:00:00Z';
 assert.equal(m.nextOfficeCandidate(now).at,'2026-10-23T03:00:00.000Z');
 assert.equal(m.nextOfficeCandidate(now).calendarVerified,false);
 assert.equal(m.dueRisk({stage:'active',execution_required:true,deadline_at:'2026-10-23T02:00:00Z'},Date.parse(now)).label,'before_office_risk');
});
test('independent states do not conflate informed, approved, communicated, executed',()=>{
 const item={stage:'active',manager_required:true,manager_informed_at:'2026-10-22T15:00:00Z',
  approval_required:true,manager_decision:'approved',communication_required:true,execution_required:true,verification_required:true};
 assert.equal(m.isManagerPending(item),false);
 assert.deepEqual(m.outstanding(item),['সংশ্লিষ্ট পক্ষকে জানান','অফিসীয় কাজ','যাচাই']);
 assert.equal(m.canComplete(item),false);
});
test('Read/dismiss of notifications cannot change source attention',()=>{
 const item={stage:'active',priority:'important',deadline_at:'2026-10-22T03:00:00Z',execution_required:true};
 assert.deepEqual(m.dueRisk({...item,notification_read:true},Date.parse('2026-10-22T12:00:00Z')),
 m.dueRisk({...item,notification_read:false},Date.parse('2026-10-22T12:00:00Z')));
});
test('Snooze cannot hide an overdue real deadline',()=>{
 const i={stage:'active',deadline_at:'2026-10-22T10:00:00Z',snoozed_until:'2026-10-25T10:00:00Z'};
 assert.equal(m.active(i,Date.parse('2026-10-22T15:00:00Z')),true);
});
test('Manager item with a pending decision remains in briefing',()=>{
 assert.equal(m.isManagerPending({stage:'waiting_manager',manager_required:true,manager_informed_at:'2026-10-22T15:00:00Z',manager_decision:'pending'}),true);
});
test('Resolved work is removed from actionable queues',()=>{
 assert.equal(m.active({stage:'completed',deadline_at:'2026-01-01T00:00:00Z'}),false);
 assert.equal(m.isManagerPending({stage:'completed',manager_required:true}),false);
});
