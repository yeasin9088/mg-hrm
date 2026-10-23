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
const source=js.slice(at)+'\n'+await fs.readFile('notification-engine-ui.js','utf8');
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
    window.__sourceRevision=0;
    window.NOTIFICATIONS=[{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',isBackend:true,entityType:'todo',ref:'101'}];
    window.openModal=(title,body)=>{let e=document.getElementById('mockDetails');if(!e){e=document.createElement('section');e.id='mockDetails';e.style.cssText='position:fixed;inset:0;z-index:99999;background:white;overflow:auto;padding:12px;box-sizing:border-box';document.body.append(e)}e.innerHTML=body;};
    window.closeModal=()=>document.getElementById('mockDetails')?.remove();
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
      if(name==='notification_operator_diagnostics')return {data:{checked_at:new Date().toISOString(),
        policy:{...window.__policy},health:{healthy:true,jobs:{},web_push_deliveries:{},subscriptions:{active:2}},
        open_source_count:20,source:{actionable:true,reason:'authoritative_source_current'},
        interaction:{revision:window.__sourceRevision},decision:{reason_code:'actionable_verified_policy_candidate'}},error:null};
      if(name==='notification_source_interaction'){
        if(args.p_expected_revision!==window.__sourceRevision)return {error:{message:'revision conflict'}};
        window.__sourceRevision++;return {data:{saved:true,revision:window.__sourceRevision},error:null};
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
  await page.locator('#mgEngineHealth').getByText('Open To-Do sources').waitFor();
  await page.evaluate(()=>window.mgOpenNotificationDetails(window.NOTIFICATIONS[0].id));
  await page.getByRole('button',{name:'Acknowledge work',exact:true}).click();
  await page.locator('#mgEngineActionResult').getByText('Source reminder state saved and verified. Business status is unchanged.').waitFor();
  assert.equal(await page.evaluate(()=>window.__sourceRevision),1);
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1));
  await page.screenshot({path:`artifacts/notification-phase6/source-details-${width}px.png`,fullPage:true});
  await context.close();
 }
}finally{await browser.close();}
