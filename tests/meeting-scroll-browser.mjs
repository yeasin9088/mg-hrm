import {chromium} from 'playwright';import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const source=await fs.readFile('meeting-ui.js','utf8');
const browser=await chromium.launch({headless:true,executablePath:process.env.MG_BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-dev-shm-usage']});
try{for(const width of [390,1366]){for(const nested of [false,true]){
 const page=await browser.newPage({viewport:{width,height:800}});
 await page.setContent(`<style>body{margin:0}.mt-tile{height:160px}${nested?'#page-meeting{height:700px;overflow:auto}':''}</style><div id="page-meeting"><div id="mtTiles"></div></div>`);
 await page.evaluate(()=>{window.draw=()=>{document.getElementById('mtTiles').innerHTML=Array.from({length:50},(_,i)=>`<div class="mt-tile" data-proj="P${i}">Project ${i}<button class="mt-details-toggle"></button><div class="mt-tile-body" hidden>Notes</div></div>`).join('');};draw();window.__testCurrent={iso:'2026-10-27',board:document.getElementById('mtTiles')};});
 await page.addScriptTag({content:source.replace('let current = null;','let current = window.__testCurrent;')});
 const result=await page.evaluate(nested=>{
  const target=nested?document.getElementById('page-meeting'):window;target.scrollTo(0,4200);
  const before=MeetingAttendanceUI.captureViewport('2026-10-27');
  if(MeetingAttendanceUI.captureViewport('other-date')!==null)throw Error('Different date captured');
  for(let i=0;i<4;i++){const snap=MeetingAttendanceUI.captureViewport('2026-10-27');draw();target.scrollTo(0,0);MeetingAttendanceUI.restoreViewport(snap);}
  const after=MeetingAttendanceUI.captureViewport('2026-10-27');return {before:before.project,after:after.project,delta:after.top-before.top};
 },nested);assert.equal(result.before,result.after);assert(Math.abs(result.delta)<2);await page.close();
 }}console.log('PASS: repeated attendance rerenders preserve project and screen position at mobile/desktop widths, for window and nested scrolling.');}finally{await browser.close();}
