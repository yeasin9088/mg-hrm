/* Per-tab foreground presence. No credentials or user identity are stored here. */
(function(root,factory){
  if(typeof module==='object'&&module.exports) module.exports=factory();
  else root.NotificationPresence=factory();
})(typeof window!=='undefined'?window:globalThis,function(){
  'use strict';
  function foreground({visible,focused,lastActivity,now,online}) {
    return visible===true&&focused===true&&online!==false&&now-lastActivity<120000;
  }
  function create({window:w,document:d,heartbeat,uuid=()=>w.crypto.randomUUID(),now=Date.now}) {
    const tabId=uuid(); // Unique to this document, including duplicated tabs.
    let deviceId;
    try {deviceId=w.localStorage.getItem('mg-presence-device');if(!/^[0-9a-f-]{36}$/i.test(deviceId||'')){deviceId=uuid();w.localStorage.setItem('mg-presence-device',deviceId);}}
    catch {deviceId=uuid();}
    let lastActivity=now(), stopped=false, inFlight=false, again=false;
    const events=[];
    async function pulse() {
      if(stopped) return;
      if(inFlight) {again=true;return;}
      inFlight=true;
      const visible=d.visibilityState==='visible',focused=d.hasFocus();
      try {await heartbeat({p_tab_id:tabId,p_device_id:deviceId,p_visible:visible,p_focused:focused,
        p_recent_activity:foreground({visible,focused,lastActivity,now:now(),online:w.navigator.onLine})});}
      catch { /* Missing/uncertain presence expires on the server; allow push. */ }
      finally {inFlight=false;if(again){again=false;pulse();}}
    }
    function active(){lastActivity=now();pulse();}
    function listen(target,event,handler){target.addEventListener(event,handler,{passive:true});events.push(()=>target.removeEventListener(event,handler));}
    // Throttle input-driven heartbeats; the regular 25s pulse carries recent activity.
    function input(){const previous=lastActivity;lastActivity=now();if(now()-previous>25000) pulse();}
    listen(d,'pointerdown',input);listen(d,'keydown',input);listen(d,'scroll',input);listen(d,'touchstart',input);listen(d,'visibilitychange',pulse);
    listen(w,'focus',active);listen(w,'blur',pulse);listen(w,'online',pulse);listen(w,'offline',pulse);
    listen(w,'pagehide',()=>{lastActivity=-Infinity;pulse();});
    const timer=w.setInterval(pulse,25000);pulse();
    return {stop(){lastActivity=-Infinity;pulse();stopped=true;events.forEach(fn=>fn());w.clearInterval(timer);},pulse};
  }
  return {foreground,create};
});
