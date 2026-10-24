// Exercise the real To-Do renderer and confirmed status/move handlers with synthetic records.
import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const source=await fs.readFile('index.html','utf8');
const part=(a,b)=>source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)));
const render=part('function renderTodo(){','// Close secondary menus');
const status=part('window.mtSetTodoStatus = async function(id','window.delTodo');
const move=part('  window.mtOpenMove = function(id){','  window.mtSetTodoFilter = function(key){');
const menu=part('// Close secondary menus','window.mtSetTodoSub =');
const styles=[...source.matchAll(/<style(?:\s[^>]*)?>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
const compact=await fs.readFile('todo-compact.css','utf8');
const browser=await chromium.launch({headless:true,...(process.env.MG_BROWSER_EXECUTABLE?{executablePath:process.env.MG_BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-dev-shm-usage']}: {})});
try {
 for(const width of [320,360,390,768,1024,1440]){
  const page=await browser.newPage({viewport:{width,height:900},hasTouch:width<600});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.setContent('<meta name="viewport" content="width=device-width,initial-scale=1"><div id="page-todo"></div><div id="test-dialog"></div>');
  await page.addStyleTag({content:styles+'\n'+compact});
  await page.evaluate(({render,status,move,menu})=>{
   window.__writes=[];window.__action='';window.__fail=false;
   window.DATA={todos:[
    {id:203,note_bn:'Joining confirmation #203',category:'task',status:'pending',created_at:'2026-10-23T16:30:00Z',date:'2026-10-23',reminder_enabled:true,next_reminder_at:'2099-10-24T11:30:00Z'},
    {id:202,note_bn:'Joining confirmation #202',category:'task',status:'approved',created_at:'2026-10-23T16:30:00Z',date:'2026-10-23'},
    {id:2,note_bn:'Uniform order #2',category:'task',status:'rejected',date:'2026-10-23'}
   ]};
   window.escapeHtml=window.esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
   window.find=id=>DATA.todos.find(t=>String(t.id)===String(id));
   window.tdCatOf=t=>t.category||'note';window.todayISO=()=> '2026-10-24';window.activeProjects=()=>[];
   window.tdMainFilter='task';window.MG_TD_SUB='unsolved';window.MG_RM_TYPES={};
   window.mgRmSummary=()=> 'Every 1 hour';window.updateTodoBadge=()=>{};window.persist=async()=>{};
   window.toast=window.toastSafe=()=>{};window.checkSalaryReminder=()=>{};
   window.appData={update:async(bucket,id,patch)=>{__writes.push({id,patch});return __fail?null:[{id}];}};
   window.mgTdPush=async()=>true;
   window.mtOpenShell=(title,sub,body)=>{document.getElementById('test-dialog').innerHTML='<h2>'+title+'</h2>'+body;};
   window.mtCloseNote=()=>{document.getElementById('test-dialog').innerHTML='';};
   window.mtOpenNote=(id,mode)=>{__action=mode+':'+id;};
   window.mtOpenRemPicker=id=>{__action='reminder:'+id;};window.delTodo=id=>{__action='delete:'+id;};
   window.mtToggleTodoImportant=id=>{find(id).is_important=!find(id).is_important;renderTodo();};
   window.mtSetTodoSub=sub=>{MG_TD_SUB=sub;renderTodo();};
   window.mtSetTodoFilter=key=>{tdMainFilter=key;MG_TD_SUB='unsolved';renderTodo();};
   (0,eval)(render+'\n'+status+'\n'+move+'\n'+menu);renderTodo();
  },{render,status,move,menu});
  const row=page.locator('#td-row-203');
  assert.equal(await page.locator('.td-tab').count(),4);
  for(const card of await page.locator('.td-tab').all()){
   assert((await card.boundingBox()).height>=80,'Original category card height');
   assert(await card.locator('.ic').isVisible(),'Original category icon');
   assert(await card.locator('.ts').isVisible(),'Original category description');
   assert(await card.locator('.ts-done').isVisible(),'Original completed count');
  }
  const font=await row.locator('.td-note').evaluate(el=>({size:getComputedStyle(el).fontSize,weight:getComputedStyle(el).fontWeight}));
  assert.deepEqual(font,{size:'14px',weight:'700'});
  const order=()=>page.locator('.td-row').evaluateAll(rows=>rows.map(el=>el.id));
  const initialOrder=await order();
  await row.getByRole('button',{name:'Mark as important',exact:true}).click();
  assert.deepEqual(await order(),initialOrder,'Important must not move the note');
  await row.locator('.td-note').click();
  assert.equal(await row.locator('.td-more').getAttribute('open'),null);
  assert.equal(await row.locator('.td-note').innerText(),'Joining confirmation #203');
  assert.match(await row.locator('.td-meta').innerText(),/Next: 24 Oct 2099, 5:30 pm/);
  assert.equal(await page.locator('.mg-work-inline,.td-chev,.td-details').count(),0);
  await row.getByRole('button',{name:'Approve',exact:true}).click();
  await row.getByRole('button',{name:'Solve with Approve',exact:true}).waitFor();
  assert.deepEqual(await order(),initialOrder,'Approve must not move the note');
  await row.getByRole('button',{name:'Undo',exact:true}).click();
  // Failed server writes must leave status and controls unchanged.
  await page.evaluate(()=>{__fail=true;});
  await row.getByRole('button',{name:'Approve',exact:true}).click();
  assert.equal(await page.evaluate(()=>find(203).status),'pending');
  await page.evaluate(()=>{__fail=false;});
  for(const [label,expected] of [['Edit','edit:203'],['Extra note','extra:203'],['Reminder','reminder:203'],['Delete','delete:203']]){
   await row.locator('summary').click();
   await row.locator('.td-more-menu').getByRole('button',{name:label,exact:true}).click();
   assert.equal(await page.evaluate(()=>__action),expected);
   assert.equal(await row.locator('.td-more').getAttribute('open'),null);
  }
  await row.locator('summary').click();await page.keyboard.press('Escape');
  assert.equal(await row.locator('.td-more').getAttribute('open'),null);
  await row.locator('summary').click();
  const menuSize=await row.locator('.td-more-menu').boundingBox();
  assert(menuSize.x>=0&&menuSize.x+menuSize.width<=width+1,'More menu stays on screen');
  await page.screenshot({path:(await fs.mkdir('artifacts/todo-compact',{recursive:true}),'artifacts/todo-compact/'+width+'.png'),fullPage:true});
  await row.locator('.td-more-menu').getByRole('button',{name:'Move',exact:true}).click();
  await page.locator('#test-dialog').getByRole('button',{name:'General',exact:true}).click();
  assert.equal(await page.evaluate(()=>find(203).category),'note');
  const rejected=page.locator('#td-row-2');
  await rejected.getByRole('button',{name:'Solve with Reject',exact:true}).click();
  assert.equal(await page.evaluate(()=>find(2).status),'solved_rejected');
  const size=await page.evaluate(()=>({viewport:innerWidth,scroll:document.documentElement.scrollWidth}));
  assert(size.scroll<=size.viewport+1,'No horizontal overflow at '+width);
  assert.deepEqual(errors,[]);
  await page.close();
 }
 console.log('PASS: six widths, direct status/undo/solve, failed-write safety, More actions, Move and reminder metadata.');
} finally {await browser.close();}
