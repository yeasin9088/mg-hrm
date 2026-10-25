import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const source=await fs.readFile('sw.js','utf8');
const images=['NOTIFICATION_LOGO','NOTIFICATION_BADGE'].map(key=>source.match(new RegExp("const "+key+" = '([^']+)'"))[1]);
const browser=await chromium.launch({headless:true,...(process.env.MG_BROWSER_EXECUTABLE?{executablePath:process.env.MG_BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-dev-shm-usage']}: {})});
try{
 const context=await browser.newContext();const page=await context.newPage();await context.setOffline(true);
 const dimensions=await page.evaluate(async images=>Promise.all(images.map(src=>new Promise((resolve,reject)=>{
  const image=new Image();image.onload=()=>resolve([image.naturalWidth,image.naturalHeight]);image.onerror=()=>reject(Error('Embedded PNG decoding failed'));image.src=src;
 }))),images);
 assert.deepEqual(dimensions,[[192,192],[96,96]]);
 console.log('PASS: offline Chromium decodes embedded logo and badge. Native Android notification appearance is not covered by this test.');
}finally{await browser.close();}
