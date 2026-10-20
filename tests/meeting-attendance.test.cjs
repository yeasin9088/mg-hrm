const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const clone = x => JSON.parse(JSON.stringify(x));
const source = fs.readFileSync('meeting-attendance.js', 'utf8');
const core = fs.readFileSync('app-core.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');
function setup() {
  const ctx = vm.createContext({console: {log(){}, warn(){}, error(){}}, crypto, setTimeout, clearTimeout, DATA: {meetings: {}},
    localStorage: {getItem() { return null; }}, document: {getElementById() { return null; }}});
  ctx.window = ctx;
  vm.runInContext(source, ctx);
  vm.runInContext(fs.readFileSync('meeting-ui.js', 'utf8'), ctx);
  vm.runInContext(core, ctx);
  return ctx;
}
function draft(n = 40) {
  const d = {present: {}, absent: {}, representatives: {}, notes: {}, presentOrder: []};
  for (let i = 0; i < n; i++) {
    const p = 'Project ' + i;
    d.present[p] = true;
    d.presentOrder.push(p);
    d.representatives[p] = {id: 'EMP-' + i, name: 'Synthetic ' + i};
  }
  return d;
}
const iso = '2026-10-20';
const empty = () => ({meeting: null, rows: []});
const meta = {agenda: 'Synthetic', started_at: null, ended_at: null};
// Synthetic RPC contract simulator, NOT a claim that the review SQL was executed.
function server() {
  const days = new Map(), calls = [];
  let version = 0, fail = false, loseResponse = false, gate = null;
  return {
    days, calls,
    set fail(v) { fail = v; },
    set loseResponse(v) { loseResponse = v; },
    set gate(v) { gate = v; },
    async rpc(name, args) {
      calls.push(clone(args));
      if (gate) await gate;
      assert.equal(name, 'mghrm_save_meeting_attendance');
      const old = days.get(args.p_date);
      if (old?.request === args.p_request_id) return {data: clone(old.value)};
      if (fail) return {error: {code: '23514', message: 'Synthetic transaction failure'}};
      if (JSON.stringify(old?.value || empty()) !== JSON.stringify(args.p_expected)) {
        return {error: {code: '40001', message: 'Changed on another device'}};
      }
      const v = ++version;
      const value = {
        meeting: {id: v, meeting_id: 'MTG-' + args.p_date, meeting_date: args.p_date, updated_at: String(v), submitted_at: 'saved',
          ...clone(args.p_metadata), attendance_request_id: args.p_request_id},
        rows: args.p_rows.map((r, i) => ({...r, id: i + 1, meeting_id: 'MTG-' + args.p_date,
          meeting_date: args.p_date, updated_at: String(v), deleted_at: null}))
      };
      days.set(args.p_date, {request: args.p_request_id, value});
      if (loseResponse) { loseResponse = false; throw Error('Response lost'); }
      return {data: clone(value)};
    }
  };
}
test('40 representatives save and reconstruct after a clean reload', async () => {
  const c = setup(), s = server(), d = draft();
  const rows = c.MeetingAttendanceStore.plan(d, null, empty(), Object.keys(d.present), []);
  const saved = await c.MeetingAttendanceStore.save(s, iso, empty(), rows, meta);
  const reload = setup();
  reload.MGHRM.reconstructMeetings([saved.meeting], saved.rows, true);
  assert.equal(Object.keys(reload.DATA.meetings[iso].present).length, 40);
  assert.equal(saved.rows.length, 40);
  assert.equal(reload.DATA.meetings[iso].representatives['Project 39'].id, 'EMP-39');
});
test('one employee edit preserves other 39 rows, including hidden historical projects and original remarks', async () => {
  const c = setup(), s = server(), d = draft(), store = c.MeetingAttendanceStore;
  const rows = store.plan(d, null, empty(), Object.keys(d.present), []);
  rows[1].remarks = 'keep | exact | text';
  const saved = await store.save(s, iso, empty(), rows, meta);
  const edit = clone(d); delete edit.present['Project 0']; edit.absent['Project 0'] = true;
  const updated = store.plan(edit, d, saved, ['Project 0'], []);
  assert.equal(updated.length, 40);
  assert.deepEqual(clone(updated.slice(1)), clone(rows.slice(1)));
  const result = await store.save(s, iso, saved, updated, meta);
  assert.equal(result.rows.filter(r => r.status === 'Present').length, 39);
  assert.equal(result.rows[0].status, 'Absent');
});
test('backdated attendance has separate meeting/date identity and cannot alter later attendance', async () => {
  const c = setup(), s = server(), store = c.MeetingAttendanceStore;
  const rows = store.plan(draft(), null, empty(), [], []);
  await store.save(s, iso, empty(), rows, meta);
  const later = clone(s.days.get(iso));
  await store.save(s, '2026-09-01', empty(), rows.slice(0, 1), meta);
  assert.deepEqual(clone(s.days.get(iso)), later);
  assert.equal(s.days.get('2026-09-01').value.rows.length, 1);
  assert.throws(() => store.validate(iso, [later.value.meeting], [{...later.value.rows[0], meeting_date: '2026-09-01'}]), /identity/);
  assert.throws(() => store.validate(iso, [later.value.meeting, later.value.meeting], []), /Multiple/);
  assert.throws(() => store.validate(iso, [later.value.meeting], [later.value.rows[0], later.value.rows[0]]), /identity/);
});
test('Present, Absent, explicit blank and unknown historic values do not become inferred Present/Absent', () => {
  const c = setup(), store = c.MeetingAttendanceStore;
  const d = {present: {P: true}, absent: {A: true}};
  const rows = store.plan(d, null, empty(), ['P', 'A', 'Blank'], []);
  assert.deepEqual(clone(rows.map(r => r.status)), ['Present', 'Absent', null]);
  const meeting = {meeting_id: 'M', meeting_date: iso};
  c.DATA.meetings[iso] = {submitted: true, present: {Blank: true, unknown: true}, absent: {}};
  c.MGHRM.reconstructMeetings([meeting], rows.concat({project_name: 'unknown', status: 'Maybe'}).map(r => ({...r, meeting_id: 'M', meeting_date: iso})));
  assert.deepEqual(Object.keys(c.DATA.meetings[iso].present), ['P']);
  assert.deepEqual(Object.keys(c.DATA.meetings[iso].absent), ['A']);
  assert.throws(() => store.status({present: {P: true}, absent: {P: true}}, 'P'), /Conflicting/);
});
test('server transaction error leaves all records untouched and unchanged draft can retry', async () => {
  const c = setup(), s = server(), store = c.MeetingAttendanceStore;
  const rows = store.plan(draft(), null, empty(), [], []);
  s.fail = true;
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /not confirmed/);
  assert.equal(s.days.size, 0);
  s.fail = false;
  assert.equal((await store.save(s, iso, empty(), rows, meta)).rows.length, 40);
});
test('lost response retry uses same request token, refuses changed draft, never duplicates rows', async () => {
  const c = setup(), s = server(), store = c.MeetingAttendanceStore;
  const rows = store.plan(draft(), null, empty(), [], []);
  s.loseResponse = true;
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /Response lost/);
  await assert.rejects(store.save(s, iso, empty(), rows.slice(1), meta), /uncertain/);
  const saved = await store.save(s, iso, empty(), rows, meta);
  assert.equal(saved.rows.length, 40);
  assert.equal(s.calls[0].p_request_id, s.calls[1].p_request_id);
});
test('two device stale edits conflict; unrelated saved statuses are preserved', async () => {
  const a = setup().MeetingAttendanceStore, b = setup().MeetingAttendanceStore, s = server();
  const rows = a.plan(draft(), null, empty(), [], []);
  const baseline = await a.save(s, iso, empty(), rows, meta);
  const changedA = clone(rows); changedA[0].status = 'Absent';
  await a.save(s, iso, baseline, changedA, meta);
  const changedB = clone(rows); changedB[1].status = 'Absent';
  await assert.rejects(b.save(s, iso, baseline, changedB, meta), /another device/);
  assert.equal(s.days.get(iso).value.rows[0].status, 'Absent');
  assert.equal(s.days.get(iso).value.rows[1].status, 'Present');
});
test('double submission is rejected while first request is pending', async () => {
  const c = setup(), s = server(), store = c.MeetingAttendanceStore;
  let release; s.gate = new Promise(r => { release = r; });
  const rows = store.plan(draft(), null, empty(), [], []);
  const first = store.save(s, iso, empty(), rows, meta);
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /in progress/);
  release(); await first;
  assert.equal(s.calls.length, 1);
});
test('partial/empty response is not success and does not unlock uncertain changed retries', async () => {
  const store = setup().MeetingAttendanceStore;
  const rows = store.plan(draft(), null, empty(), [], []);
  const s = {rpc: async () => ({data: {meeting: {meeting_id: 'M', meeting_date: iso}, rows: []}})};
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /verification failed/);
  await assert.rejects(store.save(s, iso, empty(), [], meta), /uncertain/);
});
test('pagination loads more than 1000 rows even with a smaller server cap; deleted rows never resurrect', async () => {
  const c = setup(), store = c.MeetingAttendanceStore;
  const rows = Array.from({length: 1201}, (_, i) => ({id: i, deleted_at: i === 4 ? 'deleted' : null}));
  let calls = 0;
  const client = {from() {
    return {select() { return this; }, is(k, v) { assert.equal(k, 'deleted_at'); assert.equal(v, null); return this; },
      order(k) { assert.equal(k, 'id'); return this; },
      gt(k,v) {this.after = v; return this;},
      range() { calls++; return Promise.resolve({data: rows.filter(r => !r.deleted_at && (this.after == null || r.id > this.after)).slice(0, 73)}); }};
  }};
  assert.equal((await store.readAll(client, 'meeting_attendance')).length, 1200);
  assert(calls > 16);
  c.MGHRM.reconstructMeetings([{meeting_id: 'M', meeting_date: iso}], [
    {meeting_id: 'M', meeting_date: iso, project_name: 'deleted', status: 'Present', deleted_at: 'deleted'}
  ]);
  assert.equal(Object.keys(c.DATA.meetings[iso].present).length, 0);
});
test('failed pagination throws rather than returning a partial history', async () => {
  const store = setup().MeetingAttendanceStore;
  let page = 0;
  const client = {from() { return {select() {return this;}, is() {return this;}, order() {return this;}, gt() {return this;},
    range() {return Promise.resolve(++page === 1 ? {data: [{id: 1}]} : {error: Error('page failed')});}};}};
  await assert.rejects(store.readAll(client, 'meeting_attendance'), /page failed/);
});
test('background reload preserves an active per-date draft; clearing status removes stale cached marks', () => {
  const c = setup();
  c.DATA.meetings[iso] = {present: {draft: true}, absent: {}};
  c.mtAttendanceEdits = {[iso]: {original: {}}};
  c.MGHRM.reconstructMeetings([{meeting_id: 'M', meeting_date: iso}], [], true);
  assert.equal(c.DATA.meetings[iso].present.draft, true);
  delete c.mtAttendanceEdits[iso];
  c.MGHRM.reconstructMeetings([{meeting_id: 'M', meeting_date: iso}], [
    {meeting_id: 'M', meeting_date: iso, project_name: 'draft', status: null}
  ], true);
  assert.equal(c.DATA.meetings[iso].present.draft, undefined);
});
test('same representative can be retained for two projects; identity is never nulled to bypass constraints', () => {
  const store = setup().MeetingAttendanceStore;
  const d = draft(2); d.representatives['Project 1'] = clone(d.representatives['Project 0']);
  const rows = store.plan(d, null, empty(), [], []);
  assert.equal(rows[0].employee_id, rows[1].employee_id);
});
test('static guards: no destructive fallback, autosync exclusion, review SQL preserves rows and uses RLS', () => {
  const flow = html.slice(html.indexOf('async function mtSaveAttendanceDay'), html.indexOf('function mtUnsubmit'));
  assert(!/\.delete\(|\.upsert\(|from\('meeting_attendance'\)/.test(flow));
  assert.match(core, /if \(k === 'meetings' \|\| k === 'meetingAttendance'\) return;/);
  const sql = fs.readFileSync('docs/database/meeting-attendance-review.sql', 'utf8');
  assert.match(sql, /SECURITY INVOKER/);
  assert.match(sql, /LOCK TABLE public.meetings, public.meeting_attendance/);
  assert.match(sql, /ERRCODE = '40001'/);
  assert.match(sql, /Incomplete attendance set/);
  assert.match(sql, /Soft-deleted attendance requires review/);
  assert(!/\bDELETE FROM\b|\bTRUNCATE\b/i.test(sql));
});

test('old unpaginated 1000-row load reproduces a one-present meeting; paginated reload restores all synthetic rows', async () => {
  const c = setup();
  const m = {meeting_id: 'M', meeting_date: iso};
  const oldRows = Array.from({length: 999}, (_, id) => ({id, meeting_id: 'OLD', meeting_date: '2026-09-01', project_name: 'old-' + id, status: 'Present'}));
  const target = Array.from({length: 40}, (_, i) => ({id: i + 999, meeting_id: 'M', meeting_date: iso, project_name: 'P-' + i, status: 'Present'}));
  const all = oldRows.concat(target);
  c.MGHRM.reconstructMeetings([m], all.slice(0, 1000), true);
  assert.equal(Object.keys(c.DATA.meetings[iso].present).length, 1);
  const client = {from() { return {select() {return this;}, is() {return this;}, order() {return this;},
    gt(k,v) {this.after = v; return this;},
    range(a,b) {return Promise.resolve({data: all.filter(r => this.after == null || r.id > this.after).slice(a,b + 1)});}};}};
  const complete = await c.MeetingAttendanceStore.readAll(client, 'meeting_attendance');
  c.MGHRM.reconstructMeetings([m], complete, true);
  assert.equal(Object.keys(c.DATA.meetings[iso].present).length, 40);
});

test('generic persist cannot replay a stale meeting cache to Supabase', async () => {
  const c = setup();
  c.supabase = {createClient() {return {from() {throw Error('Unexpected database write');}};}};
  await c.MGHRM.connect({url: 'https://synthetic.invalid', anonKey: 'test'});
  c.DATA.meetings = [{id: 1, agenda: 'stale'}];
  c.DATA.meetingAttendance = [{id: 1, meeting_id: 'M', status: 'Absent'}];
  await c.MGHRM.pushAll(true);
});

function uiSetup() {
  const c = setup(), messages = [], d = draft();
  c.DATA.meetings[iso] = d;
  c.DATA.employees = [];
  c.document.querySelectorAll = () => [];
  Object.assign(c, {
    guardEdit: () => true, mtEnsure: date => c.DATA.meetings[date] || (c.DATA.meetings[date] = {}),
    mtEligible: () => Object.fromEntries(Object.keys(d.present).map(p => [p, []])),
    persist: async () => {}, toast: (message, type) => messages.push({message, type}),
    mtAttendanceDate: row => c.MeetingAttendanceStore.dateForRow(row, c.DATA.rawMeetings || []),
    renderMeeting() {}, MT_SELECTED_DATE: iso
  });
  vm.runInContext(html.slice(html.indexOf('// Per-date immutable edit baselines;'), html.indexOf('function mtUnsubmit(iso)')), c);
  return {c, messages, d};
}
test('UI retains draft and shows no success if the required RPC is missing', async () => {
  const {c, messages, d} = uiSetup();
  c.MeetingAttendanceStore.readDay = async () => empty();
  c.sb = {rpc: async () => ({error: {code: 'PGRST202', message: 'Required RPC is not installed'}})};
  await c.mtSaveAttendanceDay(iso, false);
  assert.equal(c.DATA.meetings[iso], d);
  assert.equal(Object.keys(d.present).length, 40);
  assert.equal(messages.some(m => m.type === 'success'), false);
  assert.match(messages[0].message, /NOT confirmed.*RPC/);
  assert.equal(c.mtAttendanceSaving, false);
});
test('UI locks only a verified attendance set and separates later follow-up failures from attendance failure', async () => {
  const {c, messages, d} = uiSetup();
  c.MeetingAttendanceStore.readDay = async () => empty();
  c.sb = server();
  d.notes['Project 0'] = ['Synthetic follow-up'];
  c.appData = {insert: async () => {throw Error('follow-up failed');}};
  await c.mtSaveAttendanceDay(iso, false);
  assert.equal(c.DATA.meetings[iso].submitted, true);
  assert.equal(c.DATA.meetingAttendance.length, 40);
  assert.match(messages[0].message, /Attendance saved; follow-up/);
  assert.equal(messages.some(m => m.type === 'success'), false);
});

test('meeting/date validation rejects invalid calendar dates and missing identifiers before writing', async () => {
  const store = setup().MeetingAttendanceStore;
  await assert.rejects(store.save(server(), '2026-02-30', empty(), [], meta), /Invalid meeting date/);
  assert.throws(() => store.validate(iso, [{meeting_date: iso}], []), /identity/);
  assert.throws(() => store.validate(iso, [{meeting_id: 'M', meeting_date: '2026-09-01'}], []), /identity/);
});

test('incomplete draft cannot erase saved statuses, representatives or notes; explicit clears are supported', () => {
  const store = setup().MeetingAttendanceStore, original = draft();
  original.notes['Project 0'] = ['keep'];
  const snapshot = {meeting: {meeting_id: 'M'}, rows: store.plan(original, null, empty(), [], [])};
  const incomplete = clone(original);
  delete incomplete.present['Project 0'];
  assert.throws(() => store.plan(incomplete, original, snapshot, [], []), /explicit blank/);
  incomplete.attendanceBlanks = {'Project 0': true};
  assert.equal(store.plan(incomplete, original, snapshot, [], [])[0].status, null);
  delete incomplete.representatives['Project 0'];
  assert.throws(() => store.plan(incomplete, original, snapshot, [], []), /Incomplete/);
  incomplete.representatives['Project 0'] = null;
  incomplete.notes['Project 0'] = [];
  const rows = store.plan(incomplete, original, snapshot, [], []);
  assert.equal(rows[0].employee_id, null);
  assert.equal(rows[0].remarks, '');
  assert.equal(rows.length, 40);
  assert.throws(() => store.plan(original, null, snapshot, [], []), /edit snapshot/);
});

test('a soft delete between history pages does not skip the next row', async () => {
  const store = setup().MeetingAttendanceStore;
  const all = Array.from({length: 5}, (_, i) => ({id: i + 1}));
  let first = true;
  const client = {from() {return {select() {return this;}, is() {return this;}, order() {return this;},
    gt(k,v) {this.after = v; return this;},
    range() {
      if (first) {first = false; return Promise.resolve({data: clone(all.slice(0, 2))});}
      return Promise.resolve({data: all.filter(r => r.id !== 1 && r.id > this.after).slice(0, 2)});
    }};}};
  assert.deepEqual(clone((await store.readAll(client, 'meeting_attendance')).map(r => r.id)), [1,2,3,4,5]);
});

test('failed loadAll attendance page preserves complete cached history and reports the failure', async () => {
  const c = setup(), messages = [];
  const prior = {submitted: true, present: {saved: true}, absent: {}};
  c.DATA.meetings[iso] = prior;
  c.DATA.rawMeetings = [{meeting_id: 'M', meeting_date: iso}];
  c.DATA.meetingAttendance = [{id: 1, meeting_id: 'M', meeting_date: iso, project_name: 'saved', status: 'Present'}];
  c.toast = message => messages.push(message);
  c.supabase = {createClient() {return {from(table) {
    return {select() {return this;}, is() {return this;}, order() {return this;}, gt() {return this;},
      range() {return table === 'meeting_attendance' ? Promise.reject(Error('offline page')) : Promise.resolve({data: []});},
      then(resolve,reject) {return Promise.resolve({data: []}).then(resolve,reject);}
    };
  }};}};
  await c.MGHRM.connect({url: 'https://synthetic.invalid', anonKey: 'test'});
  const loaded = await c.MGHRM.loadAll();
  assert.equal(loaded.meetings[iso], prior);
  assert.equal(loaded.meetingAttendance.length, 1);
  assert(messages.some(m => /history refresh failed/.test(m)));
});

test('save waits for an in-flight note translation instead of committing an incomplete draft', async () => {
  const {c, messages} = uiSetup();
  c.MT_NOTE_BUSY = {[iso + '|Project 0']: true};
  c.sb = {rpc() {throw Error('Must not write while a note is pending');}};
  await c.mtSaveAttendanceDay(iso, false);
  assert.match(messages[0].message, /translation to finish/);
  assert.equal(c.mtAttendanceSaving, false);
});

test('missing payload fields and duplicate projects are rejected before any RPC', async () => {
  const store = setup().MeetingAttendanceStore, s = server();
  const rows = clone(store.plan(draft(2), null, empty(), [], []));
  delete rows[0].status;
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /Incomplete/);
  rows[0].status = null;
  delete rows[0].employee_id;
  await assert.rejects(store.save(s, iso, empty(), rows, meta), /Incomplete/);
  await assert.rejects(store.save(s, iso, empty(), [rows[1], rows[1]], meta), /Duplicate/);
  await assert.rejects(store.save(s, iso, empty(), [rows[1]], {agenda: 'incomplete'}), /Incomplete/);
  assert.equal(s.calls.length, 0);
});

test('uncertain PostgREST failure retains idempotency token after possible commit', async () => {
  const store = setup().MeetingAttendanceStore, s = server();
  const rows = store.plan(draft(), null, empty(), [], []);
  let first = true;
  const client = {async rpc(name, args) {
    const result = await s.rpc(name, args);
    if (first) {first = false; return {error: {code: 'PGRSTX', message: 'proxy response interrupted'}};}
    return result;
  }};
  await assert.rejects(store.save(client, iso, empty(), rows, meta), /not confirmed/);
  await store.save(client, iso, empty(), rows, meta);
  assert.equal(s.calls[0].p_request_id, s.calls[1].p_request_id);
  assert.equal(s.days.get(iso).value.rows.length, 40);
});

test('full rows alone cannot prove save success when meeting token or metadata is wrong', async () => {
  for (const field of ['attendance_request_id', 'agenda', 'submitted_at']) {
    const store = setup().MeetingAttendanceStore, s = server();
    const rows = store.plan(draft(), null, empty(), [], []);
    const client = {async rpc(name,args) {
      const result = await s.rpc(name,args);
      result.data.meeting[field] = null;
      return result;
    }};
    await assert.rejects(store.save(client, iso, empty(), rows, meta), /meeting verification failed/);
  }
});

test('historical empty-string blanks survive payload verification unchanged', async () => {
  const store = setup().MeetingAttendanceStore;
  const rows = store.plan(draft(1), null, empty(), [], []);
  rows[0].status = '';
  const saved = await store.save(server(), iso, empty(), rows, meta);
  assert.equal(saved.rows[0].status, '');
});

test('explicit clearing of an existing meeting end time reaches the RPC as null', async () => {
  const {c} = uiSetup(), s = server();
  const original = {...draft(), meetingNote: 'Synthetic', endedAt: '2026-10-20T04:00:00Z'};
  const rows = c.MeetingAttendanceStore.plan(original, null, empty(), [], []);
  const snapshot = await c.MeetingAttendanceStore.save(s, iso, empty(), rows, {...meta, ended_at: original.endedAt});
  c.DATA.meetings[iso] = {...clone(original), endedAt: ''};
  c.mtAttendanceEdits[iso] = {snapshot, original};
  c.sb = s;
  await c.mtSaveAttendanceDay(iso, true);
  assert.equal(s.calls.length, 2);
  assert.equal(s.calls[1].p_metadata.ended_at, null);
});

test('review migration requires complete JSON, preserves RLS, and exposes RPC only after transaction commit', () => {
  const sql = fs.readFileSync('docs/database/meeting-attendance-review.sql','utf8');
  assert.match(sql, /NOT \(item \?& ARRAY\['project_name','status','remarks','employee_id','full_name','designation','sort_order'\]\)/);
  assert.match(sql, /NOT \(p_metadata \?& ARRAY\['agenda','started_at','ended_at'\]\)/);
  assert.match(sql, /SET search_path = pg_catalog, public, pg_temp/);
  assert.match(sql, /SECURITY INVOKER/);
  assert(!/SECURITY DEFINER|DISABLE ROW LEVEL SECURITY/.test(sql));
  assert(sql.indexOf('IN ACCESS EXCLUSIVE MODE') < sql.indexOf('ALTER TABLE'));
  assert(sql.indexOf('NOTIFY pgrst') < sql.lastIndexOf('COMMIT'));
  const preflight = fs.readFileSync('docs/database/meeting-attendance-preflight.sql','utf8');
  assert.match(preflight, /BEGIN TRANSACTION READ ONLY/);
  assert(!/\b(INSERT INTO|UPDATE public|DELETE FROM|ALTER TABLE)\b/.test(preflight));
  const rollback = fs.readFileSync('docs/database/meeting-attendance-rollback-review.sql','utf8');
  assert(!/\b(DELETE FROM|TRUNCATE TABLE|DROP COLUMN)\b/i.test(rollback));
});

function legacyFixture() {
  const meetings = [1,2,3].map(i => ({id:i, meeting_id:'LEGACY-'+i,
    meeting_date:'2026-10-0'+i, deleted_at:null, updated_at:'v1', submitted_at:'saved'}));
  const rows = meetings.flatMap((m,n) => Array.from({length:n === 2 ? 42 : 40}, (_,i) => ({
    id:n*100+i+1, meeting_id:m.meeting_id, meeting_date:null, project_name:'Historical '+i,
    status:'Present', remarks:'', employee_id:'SYNTHETIC-'+i, full_name:null,
    designation:null, sort_order:i, deleted_at:null, updated_at:'v1'
  })));
  const client = {from(table) {
    const filters=[];
    return {select(){return this;}, order(){return this;},
      is(k,v){filters.push(r => r[k] === v);return this;},
      eq(k,v){filters.push(r => r[k] === v);return this;},
      gt(k,v){filters.push(r => r[k] > v);return this;},
      range(a,b){return Promise.resolve({data:clone((table === 'meetings' ? meetings : rows)
        .filter(r => filters.every(f => f(r))).slice(a,b+1))});}
    };
  }};
  return {meetings,rows,client};
}

test('122 legacy NULL dates load through three exact parents without rewriting stored rows', async () => {
  const c=setup(), store=c.MeetingAttendanceStore, f=legacyFixture();
  let count=0;
  for (const m of f.meetings) {
    const snapshot=await store.readDay(f.client,m.meeting_date);
    count+=snapshot.rows.length;
    assert(snapshot.rows.every(r => r.meeting_date === null && r.meeting_id === m.meeting_id));
    c.MGHRM.reconstructMeetings([m],snapshot.rows);
    assert.equal(Object.keys(c.DATA.meetings[m.meeting_date].present).length,snapshot.rows.length);
    assert(snapshot.rows.every(r => store.dateForRow(r,f.meetings) === m.meeting_date));
  }
  assert.equal(count,122);
  assert(f.rows.every(r => r.meeting_date === null));
});

test('legacy load rejects explicit contradictory dates and foreign meetings on the same date', async () => {
  const store=setup().MeetingAttendanceStore;
  for (const mutation of ['wrong-date','foreign-meeting']) {
    const f=legacyFixture(), m=f.meetings[0];
    if (mutation === 'wrong-date') f.rows[0].meeting_date='2026-09-01';
    else {f.rows[40].meeting_date=m.meeting_date;}
    await assert.rejects(store.readDay(f.client,m.meeting_date), /identity/);
  }
});

test('effective legacy date needs one active exact parent; soft-deleted attendance stays excluded', async () => {
  const store=setup().MeetingAttendanceStore, f=legacyFixture(), row=f.rows[0], parent=f.meetings[0];
  assert.equal(store.dateForRow(row,[]),'');
  assert.equal(store.dateForRow(row,[{...parent,deleted_at:'deleted'}]),'');
  assert.equal(store.dateForRow(row,[parent,{...parent,id:99}]),'');
  f.rows[0].deleted_at='deleted';
  const snapshot=await store.readDay(f.client,parent.meeting_date);
  assert.equal(snapshot.rows.length,39);
  assert(!snapshot.rows.some(r => r.id === row.id));
});

test('editing a legacy meeting preserves NULL dates, row IDs and every other employee', async () => {
  const c=setup(), store=c.MeetingAttendanceStore, f=legacyFixture(), m=f.meetings[0];
  const snapshot=await store.readDay(f.client,m.meeting_date);
  c.MGHRM.reconstructMeetings([m],snapshot.rows);
  const original=clone(c.DATA.meetings[m.meeting_date]), edited=clone(original);
  delete edited.present['Historical 0']; edited.absent['Historical 0']=true;
  const desired=store.plan(edited,original,snapshot,[],[]);
  const client={async rpc(name,args) {
    assert.equal(name,'mghrm_save_meeting_attendance');
    assert(args.p_expected.rows.every(r => r.meeting_date === null));
    return {data:{meeting:{...m,...args.p_metadata,attendance_request_id:args.p_request_id},
      rows:snapshot.rows.map(row => ({...row,...args.p_rows.find(r => r.project_name === row.project_name)}))}};
  }};
  const saved=await store.save(client,m.meeting_date,snapshot,desired,meta);
  assert.equal(saved.rows[0].status,'Absent');
  assert.deepEqual(clone(saved.rows.slice(1)),clone(snapshot.rows.slice(1)));
  assert(saved.rows.every(r => r.meeting_date === null));
});

test('legacy RPC and preflight accept NULL dates only through parent identity; no implicit backfill', () => {
  const sql=fs.readFileSync('docs/database/meeting-attendance-review.sql','utf8');
  assert.match(sql,/meeting_id = m\.meeting_id AND meeting_date IS NOT NULL AND meeting_date IS DISTINCT FROM p_date/);
  const update=sql.slice(sql.indexOf('UPDATE public.meeting_attendance SET'),sql.indexOf('WHERE id = old_row.id'));
  assert(!/meeting_date\s*=/.test(update));
  const preflight=fs.readFileSync('docs/database/meeting-attendance-preflight.sql','utf8');
  assert.match(preflight,/a\.meeting_date IS NOT NULL AND a\.meeting_date::text IS DISTINCT FROM m\.meeting_date/);
});

test('legacy UI save replaces cached rows by meeting identity without duplicating NULL-date history', async () => {
  const {c,messages}=uiSetup(), f=legacyFixture(), m=f.meetings[0];
  m.meeting_date=iso;
  const snapshot=await c.MeetingAttendanceStore.readDay(f.client,iso);
  c.MGHRM.reconstructMeetings([m],snapshot.rows);
  const original=clone(c.DATA.meetings[iso]);
  c.DATA.rawMeetings=f.meetings;
  c.DATA.meetingAttendance=clone(f.rows);
  c.mtAttendanceEdits[iso]={snapshot,original};
  delete c.DATA.meetings[iso].present['Historical 0'];
  c.DATA.meetings[iso].absent['Historical 0']=true;
  c.sb={async rpc(name,args) {return {data:{
    meeting:{...m,...args.p_metadata,attendance_request_id:args.p_request_id},
    rows:snapshot.rows.map(row => ({...row,...args.p_rows.find(r => r.project_name === row.project_name)}))
  }};}};
  await c.mtSaveAttendanceDay(iso,true);
  assert.equal(c.DATA.meetingAttendance.length,122);
  assert.equal(new Set(c.DATA.meetingAttendance.map(r => r.id)).size,122);
  assert(c.DATA.meetingAttendance.every(r => r.meeting_date === null));
  assert.equal(c.DATA.meetings[iso].absent['Historical 0'],true);
  assert(messages.some(m => m.type === 'success'));
});
