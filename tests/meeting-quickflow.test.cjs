const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const uiSource = fs.readFileSync('meeting-ui.js','utf8');
const engineSource = fs.readFileSync('meeting-attendance.js','utf8');
const html = fs.readFileSync('index.html','utf8');
const css = fs.readFileSync('meeting-ui.css','utf8');
const migration = fs.readFileSync('supabase/migrations/20261022053305_meeting_present_representative_guard.sql','utf8');

const store = (()=>{const c=vm.createContext({});vm.runInContext(engineSource,c);return c.MeetingAttendanceStore;})();
function board() {const c=vm.createContext({});vm.runInContext(uiSource,c);return c.MeetingAttendanceUI;}
function rep(id='e1'){return {id, name:'Representative '+id};}

test('Present requires an identified representative; Absent and Pending never do',()=>{
  const ui=board(), d={present:{A:true},absent:{B:true},representatives:{}};
  const check=ui.validation(['A','B'],d,false);
  assert.equal(check.allowed,false);
  assert.deepEqual(Array.from(check.missingRepresentatives),['A']);
  d.representatives.A=rep();
  assert.equal(ui.validation(['A','B'],d,false).allowed,true);
  delete d.representatives.A;
  assert.equal(ui.validation(['A','B'],d,true,{present:{A:true},representatives:{}}).allowed,true,'unchanged incomplete historical row is grandfathered');
  assert.equal(ui.validation(['A','B'],d,true,{present:{A:true},representatives:{A:rep()}}).allowed,false,'cannot remove a saved representative from Present');
});

test('Persistence planner rejects new/changed Present with missing identity but preserves unchanged legacy attendance',()=>{
  const d={present:{A:true},absent:{B:true},representatives:{},notes:{}};
  const snapshot={meeting:null,rows:[]};
  assert.throws(()=>store.plan(d,null,snapshot,['A','B'],[]),/Choose a representative/);
  d.representatives.A=rep();
  const rows=store.plan(d,null,snapshot,['A','B'],[]);
  assert.equal(rows.find(r=>r.project_name==='A').employee_id,'e1');
  assert.equal(rows.find(r=>r.project_name==='B').employee_id,null);
  const old={present:{A:true},absent:{},representatives:{A:null},notes:{},presentOrder:['A']};
  const historical={meeting:{meeting_id:'M',meeting_date:'2026-10-22'},rows:[{project_name:'A',status:'Present',remarks:'',
    employee_id:null,full_name:null,designation:null,sort_order:0}]};
  assert.doesNotThrow(()=>store.plan(JSON.parse(JSON.stringify(old)),old,historical,['A'],[]));
  const changed=JSON.parse(JSON.stringify(old)); changed.representatives.A=rep('e9');
  assert.equal(store.plan(changed,old,historical,['A'],[])[0].employee_id,'e9');
});

test('Clicking Present with no representative never changes attendance; Absent works without representative',()=>{
  const c=vm.createContext({DATA:{},console});
  c.window=c;
  const day={present:{},absent:{},representatives:{},presentOrder:[],attendanceBlanks:{A:true}};
  let persisted=0,required=0,refreshed=0;
  Object.assign(c,{guardEdit:()=>true,mtEnsure:()=>day,persist:()=>persisted++,
    MeetingAttendanceUI:{requestRepresentative:()=>required++,refresh:()=>refreshed++},
    toast:()=>{},mtCheckDirty:()=>{}});
  const a=html.slice(html.indexOf('function mtHasSelectedRep('),html.indexOf('window.mtHasSelectedRep ='));
  const b=html.slice(html.indexOf('function mtSetStatus('),html.indexOf('window.mtSetStatus ='));
  assert(a.includes('function mtHasSelectedRep')&&b.includes('function mtSetStatus'));
  vm.runInContext(a+'\n'+b,c);
  c.mtSetStatus('2026-10-22','A','present');
  assert.equal(required,1);
  assert.equal(persisted,0);
  assert.equal(day.present.A,undefined);
  assert.equal(day.attendanceBlanks.A,true);
  c.mtSetStatus('2026-10-22','A','absent');
  assert.equal(day.absent.A,true);
  assert.equal(persisted,1);
  day.representatives.A=rep('e2');
  c.mtSetStatus('2026-10-22','A','present');
  assert.equal(day.present.A,true);
  assert.equal(day.absent.A,undefined);
  assert.equal(persisted,2);
  assert.equal(refreshed,2);
});

test('Selecting a representative after a failed Present click automatically confirms the status',()=>{
  const day={present:{},absent:{},representatives:{}};
  const c=vm.createContext({}); c.window=c;
  const tiles=['A','B'].map(project=>{
    const classes=new Set();
    const details={attributes:{},setAttribute(k,v){this.attributes[k]=v;}};
    const body={hidden:true},hint={hidden:true,textContent:''},select={value:'',options:[{value:''},{value:'e1|Rep 1|Supervisor'}],focus(){this.focused=true;},showPicker(){this.opened=true;}};
    const tile={dataset:{proj:project},classList:{add(k){classes.add(k)},remove(k){classes.delete(k)},contains(k){return classes.has(k)}},
      querySelector(q){return ({'.mt-details-toggle':details,'.mt-tile-body':body,'.mt-rep-hint':hint,'.mt-rep-select':select})[q];}};
    return {tile,details,body,hint,select};
  });
  const boardEl={isConnected:false,querySelectorAll(q){
    if(q==='.mt-tile')return tiles.map(t=>t.tile);
    if(q==='.mt-tile.expanded')return tiles.map(t=>t.tile).filter(t=>t.classList.contains('expanded'));
    return [];
  }};
  c.document={getElementById(id){return id==='mtTiles'?boardEl:id==='mtSearch'?{value:''}:null;}};
  vm.runInContext(uiSource,c);
  let marks=0;
  c.mtSetStatus=(iso,project,status)=>{assert.equal(status,'present');day.present[project]=true;marks++;};
  c.MeetingAttendanceUI.mount('2026-10-22',day,['A','B'],false);
  c.MeetingAttendanceUI.toggleDetails({closest:()=>tiles[0].tile});
  assert.equal(tiles[0].body.hidden,false);
  c.MeetingAttendanceUI.toggleDetails({closest:()=>tiles[1].tile});
  assert.equal(tiles[0].body.hidden,true);
  assert.equal(tiles[1].body.hidden,false);
  assert.equal(c.MeetingAttendanceUI.requestRepresentative('2026-10-22','A'),true);
  assert.equal(tiles[1].body.hidden,true);
  assert.equal(tiles[0].select.focused,true);
  assert.equal(tiles[0].select.opened,true);
  assert.equal(tiles[0].hint.hidden,false);
  day.representatives.A=rep();
  c.MeetingAttendanceUI.representativeSaved('2026-10-22','A');
  assert.equal(marks,1);
  assert.equal(tiles[0].body.hidden,true);
  assert.equal(day.present.A,true);
});

test('Calendar starts collapsed during attendance, can expand manually, and counts update without a full render',()=>{
  assert.match(html,/mt-calendar-collapsed/);
  assert.match(html,/id="mtCalendarToggle"/);
  assert.match(html,/id="mtCalendarCard"/);
  assert.match(html,/data-meeting-day="\$\{iso\}"/);
  assert.match(html,/class="mt-day-count"/);
  assert.match(uiSource,/label\.textContent = counts\.present \? counts\.present \+ ' ✓' : '✗'/);
  assert.match(css,/#page-meeting \.mt-workspace\.mt-calendar-collapsed/);
  assert.match(css,/#page-meeting #mtCalendarCard\[hidden\]/);
});

test('Migration gates new/modified Present while keeping legacy attendance records',()=>{
  assert.match(migration,/BEFORE INSERT OR UPDATE ON public\.meeting_attendance/);
  assert.match(migration,/OLD\.status IS DISTINCT FROM NEW\.status/);
  assert.match(migration,/OLD\.employee_id IS DISTINCT FROM NEW\.employee_id/);
  assert.match(migration,/NEW\.status = 'Present'/);
  assert.match(migration,/NULLIF\(BTRIM\(NEW\.employee_id\), ''\) IS NULL/);
  assert(!/\bDELETE FROM public\.meeting_attendance|\bTRUNCATE\b/i.test(migration));
});
