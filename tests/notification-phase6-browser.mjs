// Synthetic in-browser Settings Center acceptance at real Chromium viewports.
// This is NOT a real Android phone, production auth, or provider Push receipt.
import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import path from 'node:path';
const css=await fs.readFile('notification-ui.css','utf8');
const js=await fs.readFile('notification-settings.js','utf8');
const at=js.indexOf('/* Phase 6: a backend-authoritative Smart Policy');
assert(at>=0,'Phase6 panel source must exist');
const source=js.slice(at);
const base={
 revision:9,policy_version:'notification-core-v2-phase2-1',
 governance_enabled:false,digest_bridge_enabled:false,
 push_start:'09:00',push_end:'18:00',morning_digest_time:'09:05',
 afternoon_digest_time:'17:15',morning_digest_enabled:true,
 afternoon_digest_enabled:true,p3_item_cap_24h:1,p2_item_cap_24h:2,
 p2_cooldown_minutes:null,p3_cooldown_minutes:null,
 user_cap_24h:null,category_cap_24h:null
};
const browser=await chromium.launch({headless:true});
try{
 for(const width of [320,360,390,768,1024,1440]){
  const context=await browser.newContext({viewport:{width,height:800},
    isMobile:width<=390,hasTouch:width<=390,deviceScaleFactor:1});
  const page=await context.newPage();
  await page.setContent(`<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>${css}</style>
  </head><body style="margin:0"><div id="mgNotifSettingsRoot" class="mg-ns-backdrop open" aria-hidden="false">
    <section class="mg-ns-panel" role="dialog" aria-modal="true" aria-labelledby="mgNsTitle">
      <header class="mg-ns-head"><h2 id="mgNsTitle">Notification Settings</h2></header>
      <div class="mg-ns-body" id="mgNsBody"></div>
    </section></div></body></html>`);
  await page.evaluate(({code,record})=>{
    window.__policy={...record};
    window.__saveCalls=[];
    window.mgOpenNotifSettings=async()=>{};
    window.MGHRM={client:{rpc:async(name,args)=>{
      if(name==='notification_operator_policy_read')return {data:{...window.__policy},error:null};
      if(name==='notification_operator_policy_save'){
        window.__saveCalls.push(args);
        if(args.p_expected_revision!==window.__policy.revision)
          return {data:null,error:{code:'40001',message:'Policy revision conflict'}};
        window.__policy={...window.__policy,...args.p_changes,
          revision:window.__policy.revision+1};
        return {data:{...window.__policy,saved:true,readback_revision:window.__policy.revision},error:null};
      }
      return {data:null,error:{message:'Unknown mock RPC'}};
    }}};
    (0,eval)(code);
  },{code:source,record:base});
  await page.evaluate(()=>window.mgOpenNotifSettings());
  await page.locator('#mgNsSmartPolicy').waitFor();
  assert.equal(await page.locator('#mgNsSmartPolicy input').count(),12,'all 12 backend controls rendered');
  let measurements=await page.evaluate(()=>({
    scroll:document.documentElement.scrollWidth,
    inner:window.innerWidth,
    panel:document.querySelector('.mg-ns-panel').getBoundingClientRect().width,
    save:document.querySelector('#mgNsEngineSave').getBoundingClientRect().height,
    title:document.querySelector('#mgNsSmartPolicy').textContent
  }));
  assert(measurements.scroll<=measurements.inner+1,
    `Viewport overflow at ${width}: ${JSON.stringify(measurements)}`);
  assert(measurements.save>=44,`Save touch target too small at ${width}`);
  assert.match(measurements.title,/Governance staged/);
  await page.locator('#mgNsEng_afternoon_digest_enabled').uncheck();
  await page.locator('#mgNsEngineSave').click();
  await page.locator('#mgNsEngineLive').getByText('Policy saved and verified on server.').waitFor();
  const updated=await page.evaluate(()=>({policy:window.__policy,calls:window.__saveCalls}));
  assert.equal(updated.policy.afternoon_digest_enabled,false);
  assert.equal(updated.policy.revision,10);
  assert.equal(updated.calls.length,1);
  assert.deepEqual(JSON.parse(JSON.stringify(updated.calls[0].p_changes)),{afternoon_digest_enabled:false});
  await fs.mkdir('artifacts/notification-phase6',{recursive:true});
  await page.screenshot({path:`artifacts/notification-phase6/settings-${width}px.png`,fullPage:true});
  console.log(`PASS Chromium Phase6 viewport ${width}px: responsive, 12 controls, authenticated-CAS mock, readback and 44px target`);
  await context.close();
 }
}finally{await browser.close();}
