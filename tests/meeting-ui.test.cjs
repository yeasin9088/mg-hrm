const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const {spawn} = require('node:child_process');
const {pathToFileURL} = require('node:url');
const html = fs.readFileSync('index.html', 'utf8');
const source = fs.readFileSync('meeting-ui.js', 'utf8');
const css = fs.readFileSync('meeting-ui.css', 'utf8');
const context = vm.createContext({});
vm.runInContext(source, context);
const ui = context.MeetingAttendanceUI;

test('summary counts 40 unique projects, includes Absent in progress and ignores unrelated marks', () => {
  const projects = Array.from({length: 40}, (_, i) => 'P' + i);
  const day = {present: {outside: true}, absent: {}};
  projects.slice(0, 25).forEach(p => day.present[p] = true);
  projects.slice(25, 35).forEach(p => day.absent[p] = true);
  const c = ui.summarize([...projects, projects[0]], day);
  assert.deepEqual([c.total, c.present, c.absent, c.pending, c.percent], [40, 25, 10, 5, 88]);
  assert.equal(ui.summarize([], {}).percent, 0);
});
test('filters compose with case-insensitive search and do not treat unknown status as Absent', () => {
  assert(ui.matches('North Office', 'pending', 'pending', '  NORTH '));
  assert(!ui.matches('North Office', 'present', 'pending', 'north'));
  assert(!ui.matches('North Office', 'absent', 'all', 'South'));
  assert.equal(ui.status({attendanceBlanks: {P: true}}, 'P'), 'pending');
});
test('new final submission requires completion; historical blanks are never forced or mutated', () => {
  const day = {present: {A: true}, absent: {}, attendanceBlanks: {B: true}};
  const before = JSON.stringify(day);
  assert(!ui.validation(['A', 'B'], day, false).allowed);
  assert(ui.validation(['A', 'B'], day, true, {present:{A:true}, representatives:{}}).allowed);
  assert.equal(JSON.stringify(day), before);
  day.absent.B = true;
  assert(!ui.validation(['A', 'B'], day, false).allowed, 'Present requires representative');
  day.representatives = {A: {id: 'E-A', name: 'Representative A'}};
  assert(ui.validation(['A', 'B'], day, false).allowed);
});
test('direct new-day save with Pending performs zero database calls, even without the submit button', async () => {
  let writes = 0;
  const c = vm.createContext({console, document: {}, DATA: {}});
  c.window = c;
  vm.runInContext(source, c);
  Object.assign(c, {guardEdit: () => true, mtEnsure: () => ({present: {}, absent: {}}),
    mtEligible: () => ({A: []}), toast() {}, sb: {rpc() { writes++; }}});
  vm.runInContext(html.slice(html.indexOf('// Per-date immutable edit baselines;'), html.indexOf('function mtUnsubmit(iso)')), c);
  await c.mtSaveAttendanceDay('2026-01-01', false);
  assert.equal(writes, 0);
  assert.equal(c.mtAttendanceSaving, false);
});
test('a newly required project during snapshot loading blocks submission and retains the draft', async () => {
  let required = ['A'], writes = 0;
  const day = {present: {A: true}, absent: {}};
  const c = vm.createContext({console: {error() {}}, document: {getElementById() {}, querySelectorAll: () => []}, DATA: {}});
  c.window = c;
  vm.runInContext(source, c);
  Object.assign(c, {guardEdit: () => true, mtEnsure: () => day, mtEligible: () => Object.fromEntries(required.map(p => [p, []])),
    toast() {}, sb: {}, renderMeeting() {}, MeetingAttendanceStore: {
      async readDay() {required.push('B'); return {meeting: null, rows: []};},
      save() {writes++;}, plan() {throw Error('Should validate before planning');}
    }});
  vm.runInContext(html.slice(html.indexOf('// Per-date immutable edit baselines;'), html.indexOf('function mtUnsubmit(iso)')), c);
  await c.mtSaveAttendanceDay('2026-01-01', false);
  assert.equal(writes, 0);
  assert.equal(day.present.A, true);
  assert.equal(c.mtAttendanceSaving, false);
});

// Real template + styles, fake data only. No app bootstrap, credentials or network requests.
function browserFixture() {
  const start = html.indexOf('<div class="mt-summary"');
  const end = html.indexOf('</div>`}', start) + '</div>'.length;
  const template = html.slice(start, end);
  const day = {present: {P0: true}, absent: {P1: true}, representatives: {P0: {id: 'E0', name: 'Rep 0'}}, notes: {}};
  const projects = Array.from({length: 40}, (_, i) => 'P' + i);
  const escapeHtml = x => String(x).replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
  const params = {today: '2026-01-01', rec: day, projNames: projects,
    num: String, escapeHtml, mtGetProjectReps: p => [{id: 'E' + p.slice(1), FullName: 'Rep ' + p.slice(1), Designation: 'Supervisor'}], mtBuildNotesSection: () => '<textarea aria-label="Project note"></textarea>',
    projName: p => 'Project ' + p, projStaffCount: () => 1, ico: () => ''};
  const rendered = Function(...Object.keys(params), 'return `' + template + '`;')(...Object.values(params));
  const originalStyles = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m => m[1]).join('\n');
  const setStatus = html.slice(html.indexOf('function mtSetStatus('), html.indexOf('window.mtSetStatus ='));
  const saveRep = html.slice(html.indexOf('function mtSaveRep('), html.indexOf('window.mtSaveRep ='));
  const validRep = html.slice(html.indexOf('function mtHasSelectedRep('), html.indexOf('window.mtHasSelectedRep ='));
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <style>${originalStyles}\n${css}\nbody{margin:0}.main{max-width:1400px;margin:auto}#result{position:fixed;bottom:0;background:white;z-index:99}</style>
    <main class="main"><div class="grid-2 mt-workspace"><section class="card mt-attendance-card"><div class="card-body">${rendered}</div></section><aside>Monthly calendar (existing workflow)</aside></div></main><pre id="result">RUNNING</pre>
    <script>${source}</script><script>
    const day=${JSON.stringify(day)}, projects=${JSON.stringify(projects)};
    function guardEdit(){return true} function mtEnsure(){return day} function persist(){} function toast(){}
    function mtSaveMeetingNote(){}
    function mtSetFilter(f){MeetingAttendanceUI.setFilter(f)}
    ${validRep}
    ${saveRep}
    ${setStatus}
    window.mtSetStatus = mtSetStatus;
    function check(ok,message){if(!ok)throw Error(message)}
    try {
      MeetingAttendanceUI.mount('2026-01-01',day,projects,false);
      check(document.getElementById('mtCount-pending').textContent==='38','initial pending');
      check(document.getElementById('mtSubmitDayBtn').disabled,'pending disables submission');
      MeetingAttendanceUI.setFilter('pending');
      check(document.querySelectorAll('.mt-tile:not([hidden])').length===38,'pending filter');
      const tile=document.querySelector('.mt-tile:not([hidden])');
      const button=tile.querySelector('[data-status="present"]'); button.focus(); button.click();
      check(document.getElementById('mtCount-present').textContent==='1','no Present without representative');
      check(tile.classList.contains('expanded'),'picker expands on Present');
      const rep=tile.querySelector('.mt-rep-select');
      rep.value=rep.options[1].value; rep.dispatchEvent(new Event('change',{bubbles:true}));
      check(document.getElementById('mtCount-present').textContent==='2','selecting representative auto-confirms Present');
      check(tile.hidden,'marked project leaves pending view');
      check(document.activeElement!==button && document.activeElement.dataset.status==='present','keyboard moves to next pending');
      MeetingAttendanceUI.search('no matching project');
      check(!document.getElementById('mtEmptyFilter').hidden,'empty feedback');
      MeetingAttendanceUI.reviewPending();
      check(document.getElementById('mtPendingList').children.length===37,'pending list');
      document.getElementById('mtPendingList').firstElementChild.click();
      check(document.activeElement.dataset.status==='present','pending jump focuses action');
      MeetingAttendanceUI.reset();
      const details=document.querySelector('.mt-details-toggle');details.click();
      check(details.getAttribute('aria-expanded')==='true','keyboard-accessible details');
      const note=details.closest('.mt-tile').querySelector('textarea');note.value='Unsaved note';
      mtSetStatus('2026-01-01','P0','absent');
      check(note.isConnected && note.value==='Unsaved note','status preserves note DOM');
      MeetingAttendanceUI.search('P19');
      MeetingAttendanceUI.mount('2026-01-02',{},projects,false);
      check(document.getElementById('mtSearch').value==='','date-specific search');
      MeetingAttendanceUI.mount('2026-01-01',day,projects,true);
      check(document.getElementById('mtSearch').value==='P19','same-date search retained');
      check(document.getElementById('mtDraftHelp').textContent.includes('historical blanks'),'historical editing explanation');
      MeetingAttendanceUI.reset();
      check(document.documentElement.scrollWidth<=innerWidth,'no horizontal overflow');
      const action=document.querySelector('[data-status="present"]');
      check(action.getBoundingClientRect().height>=44,'touch target');
      if(innerWidth<=600) check(getComputedStyle(document.querySelector('.mt-grid')).gridTemplateColumns.split(' ').length===1,'mobile single column');
      check(getComputedStyle(document.querySelector('.mt-summary')).position==='sticky','sticky summary CSS');
      window.scrollTo(0,600);
      requestAnimationFrame(()=>{try{
        check(document.querySelector('.mt-summary').getBoundingClientRect().top>=0,'summary remains visible after scroll');
        window.scrollTo(0,0);document.getElementById('result').textContent='PASS browser board';
      }catch(e){document.getElementById('result').textContent='FAIL '+e.message}});
    } catch(e){document.getElementById('result').textContent='FAIL '+e.message}
    </script>`;
}
const browser = process.env.MGHRM_TEST_BROWSER || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
test('real browser: 390/768/1366px layouts, filters, focus, sticky summary and draft notes', {skip: !fs.existsSync(browser)}, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mghrm-meeting-ui-'));
  const fixture = path.join(dir, 'board.html');
  fs.writeFileSync(fixture, browserFixture());
  const profile = path.join(dir, 'profile');
  const child = spawn(browser, ['--headless', '--disable-gpu', '--no-first-run', '--disable-background-networking',
    '--user-data-dir=' + profile, '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0', 'about:blank'],
    {stdio: 'ignore', windowsHide: true});
  const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
  let socket;
  try {
    const portFile = path.join(profile, 'DevToolsActivePort');
    for (let i=0; i<100 && !fs.existsSync(portFile); i++) await pause(100);
    assert(fs.existsSync(portFile), 'Isolated browser debugger did not start');
    const port = Number(fs.readFileSync(portFile, 'utf8').split('\n')[0]);
    const targets = await (await fetch('http://127.0.0.1:' + port + '/json/list')).json();
    socket = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {socket.onopen=resolve;socket.onerror=reject;});
    let nextId=0; const waiting=new Map();
    socket.onmessage = event => {
      const data=JSON.parse(event.data), entry=waiting.get(data.id);
      if(entry){clearTimeout(entry.timer);waiting.delete(data.id);data.error?entry.reject(Error(data.error.message)):entry.resolve(data.result);}
    };
    const send = (method, params={}) => new Promise((resolve,reject) => {
      const id=++nextId;
      const timer=setTimeout(()=>{waiting.delete(id);reject(Error('Browser command timed out: '+method));},15000);
      waiting.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
    });
    await send('Page.enable');
    for (const width of [390,768,1366]) {
      await send('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:width===390});
      await send('Page.navigate',{url:pathToFileURL(fixture).href+'?width='+width});
      let result;
      for(let i=0;i<100;i++) {
        result=(await send('Runtime.evaluate',{expression:"document.getElementById('result')?.textContent",returnByValue:true})).result.value;
        if(result && result!=='RUNNING')break;
        await pause(50);
      }
      assert.equal(result,'PASS browser board',width+'px: '+result);
      const metrics=(await send('Runtime.evaluate',{expression:"({width:innerWidth,right:document.querySelector('.mt-summary').getBoundingClientRect().right})",returnByValue:true})).result.value;
      assert.equal(metrics.width,width,'Exact viewport width');
      assert(metrics.right<=width,'Summary must not be clipped');
      const screenshot=await send('Page.captureScreenshot',{format:'png'});
      fs.writeFileSync(path.join(dir,'board-'+width+'.png'),Buffer.from(screenshot.data,'base64'));
    }
    console.log('Synthetic responsive preview: '+dir);
    await send('Browser.close');
  } finally { if(socket)socket.close(); if(child.exitCode===null)child.kill(); }
});
