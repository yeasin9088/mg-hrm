const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function fixture({permission='granted',revoked=false,manual=false}={}){
 const calls={register:0,subscribe:0,unsubscribe:0,prompt:0};
 const device={id:23,device_label:'My phone',revoked_at:revoked?'2026-10-24T03:00:00Z':null,last_failure_at:revoked&&!manual?'2026-10-24T03:00:00Z':null};
 const subscription={endpoint:'https://fcm.googleapis.com/synthetic',options:{applicationServerKey:new Uint8Array([1])},getKey:()=>new Uint8Array([1,2]).buffer,unsubscribe:async()=>{calls.unsubscribe++;}};
 const Notification={permission,requestPermission:async()=>{calls.prompt++;return 'granted';}};
 const repo={getWebPushConfig:async()=>({publicKey:'AQ'}),registerDevice:async()=>{calls.register++;return {subscription_id:24};},listDevices:async()=>[device]};
 const navigator={platform:'Linux arm',userAgent:'Chrome/150',serviceWorker:{ready:Promise.resolve({pushManager:{getSubscription:async()=>subscription,subscribe:async()=>{calls.subscribe++;return subscription;}}}),addEventListener(){}}};
 const storage=new Map([['mghrm-push-device-user','23']]);
 const window={Notification,PushManager:function(){},isSecureContext:true,NotificationModel:{normalize:x=>x},MGHRM:{notifications:repo,getSession:async()=>({user:{id:'user'}})},addEventListener(){}};
 const context={window,navigator,Notification,document:{readyState:'loading',addEventListener(){},getElementById(){return null;}},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},setInterval(){},setTimeout(){},clearTimeout(){},URLSearchParams,location:{search:''},console,Uint8Array,atob,btoa};
 vm.runInNewContext(fs.readFileSync('notification-center.js','utf8'),context);
 return {window,calls,storage};
}
test('expired phone subscription is renewed and registered without another permission prompt',async()=>{
 const f=fixture({revoked:true});await f.window.mgSyncDevicePush(true);
 assert.equal(f.calls.unsubscribe,1);assert.equal(f.calls.subscribe,1);assert.equal(f.calls.register,1);assert.equal(f.calls.prompt,0);
 assert.equal(f.storage.get('mghrm-push-device-user'),'24');
});
test('granted existing device is reconciled with the server without replacing valid keys',async()=>{
 const f=fixture();await Promise.all([f.window.mgSyncDevicePush(true),f.window.mgSyncDevicePush(true)]);
 assert.equal(f.calls.register,1);assert.equal(f.calls.unsubscribe,0);assert.equal(f.calls.subscribe,0);
});
test('automatic repair respects manual revocation and never prompts when permission is missing',async()=>{
 const revoked=fixture({revoked:true,manual:true});await revoked.window.mgSyncDevicePush(true);assert.equal(revoked.calls.register,0);
 const missing=fixture({permission:'default'});await missing.window.mgSyncDevicePush(true);assert.equal(missing.calls.prompt,0);assert.equal(missing.calls.register,0);
});
