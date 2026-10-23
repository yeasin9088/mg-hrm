/* Server-backed diagnostics and explicit work leases in the existing settings
 * and notification detail dialogs. No parallel inbox or HR workflow mutation. */
(function(){
'use strict';
if(window.__mgEngineDiagnostics)return;
window.__mgEngineDiagnostics=true;
var opening=0,details=new Map(),pending=new Set();
function esc(value){return String(value==null?'':value).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function time(value){if(!value)return 'Not recorded';var d=new Date(value);return Number.isNaN(d.getTime())?'Unavailable':d.toLocaleString('en-GB',{timeZone:'Asia/Dhaka'});}
async function rpc(name,args){var c=window.MGHRM&&window.MGHRM.client;if(!c||!c.rpc)throw Error('Backend unavailable');var r=await c.rpc(name,args||{});if(r.error)throw r.error;return r.data;}
function message(text,error){var e=document.getElementById('mgEngineActionResult');if(e){e.textContent=text;e.className='mg-ns-help'+(error?' error':'');}}
async function health(){
 var body=document.getElementById('mgNsBody');if(!body)return;
 var panel=document.getElementById('mgEngineHealth');if(!panel){panel=document.createElement('section');panel.id='mgEngineHealth';panel.className='mg-ns-section';body.appendChild(panel);}
 var token=++opening;panel.textContent='Checking scheduler and delivery health…';
 try{
  var d=await rpc('notification_operator_diagnostics',{p_notification_id:null});if(token!==opening||!panel.isConnected)return;
  var h=d.health||{},jobs=h.jobs||{},push=h.web_push_deliveries||{},devices=h.subscriptions||{},policy=d.policy||{};
  panel.innerHTML='<h3>Scheduler and delivery health</h3><p class="mg-ns-help">'+(h.healthy===true?'Scheduler checks passed.':'Review delivery diagnostics.')+' Checked '+esc(time(d.checked_at))+' · Asia/Dhaka</p>'+
   '<dl class="mg-n6-detail-grid"><dt>Engine</dt><dd>'+esc(policy.governance_enabled&&policy.digest_bridge_enabled?'V2 enabled':'V1 live · V2 staged')+'</dd>'+
   '<dt>Open To-Do sources</dt><dd>'+esc(d.open_source_count)+'</dd><dt>Active Push devices</dt><dd>'+esc(devices.active)+'</dd>'+
   '<dt>Overdue / failed / dead-letter jobs</dt><dd>'+esc(jobs.overdue_pending||0)+' / '+esc(jobs.failed||0)+' / '+esc(jobs.deadletter||0)+'</dd>'+
   '<dt>Provider accepted / failed deliveries</dt><dd>'+esc(push.successful||0)+' / '+esc(push.failed||0)+'</dd>'+
   '<dt>Unconfirmed quota reservations</dt><dd>'+esc(d.uncertain_quota_occurrences||0)+'</dd></dl>'+
   '<p class="mg-ns-help">Provider acceptance does not prove that a notification appeared on a device. Read and device clearing never complete a source task. Holiday calendar and payroll cutoff remain unconfigured.</p>'+
   '<button type="button" class="mg-ns-btn" id="mgEngineHealthRefresh">Refresh diagnostics</button>';
  var refresh=document.getElementById('mgEngineHealthRefresh');if(refresh)refresh.addEventListener('click',health);
 }catch(e){if(token===opening)panel.textContent='Delivery diagnostics unavailable. Reopen settings after checking your connection and operator access.';}
}
var previousSettings=window.mgOpenNotifSettings;
if(typeof previousSettings==='function')window.mgOpenNotifSettings=window.mtOpenNotifSettings=async function(event){await previousSettings(event);await health();};
var previousDetails=window.mgOpenNotificationDetails;
window.mgOpenNotificationDetails=async function(id){
 var n=(window.NOTIFICATIONS||[]).find(function(item){return String(item.id)===String(id);});
 if(!n||!n.isBackend){if(previousDetails)return previousDetails(id);return;}
 if(typeof window.openModal!=='function')return;
 var token=++opening;
 window.openModal('Notification policy and source','<p role="status">Reading current server state…</p>','<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button>');
 try{
  var d=await rpc('notification_operator_diagnostics',{p_notification_id:id});if(token!==opening)return;
  details.set(String(id),{notification:n,data:d});
  var source=d.source||{},interaction=d.interaction||{revision:0},decision=d.decision||{};
  var body='<div class="mg-n6-dialog"><p class="mg-ns-help">Live server check · '+esc(time(d.checked_at))+' · Asia/Dhaka</p>';
  if(Array.isArray(d.digest_items)){
   body+='<p>This digest links to current source work. Reading this summary does not complete those items.</p><div class="mg-engine-source-list">';
   if(!d.digest_items.length)body+='<p>No current source work remains in this digest.</p>';
   d.digest_items.forEach(function(item){var key=String(item.todo_id);if(!/^\d{1,18}$/.test(key))return;
    body+='<button type="button" class="mg-ns-btn" onclick="mgEngineOpenTodo(\''+key+'\')">To-Do #'+esc(key)+' · '+esc(String(item.group_key).replace(/_/g,' '))+'</button>';});body+='</div>';
  }else{
   body+='<dl class="mg-n6-detail-grid"><dt>Source</dt><dd>'+esc(source.reason||'Unverified')+'</dd>'+
    '<dt>Policy decision</dt><dd>'+esc(decision.reason_code||'Source adapter validation')+'</dd>'+
    '<dt>Last dispatch reason</dt><dd>'+esc(d.last_dispatch_reason||'No suppression recorded')+'</dd>'+
    '<dt>Work ACK until</dt><dd>'+esc(time(interaction.acknowledged_until))+'</dd>'+
    '<dt>Source snooze until</dt><dd>'+esc(time(interaction.snoozed_until))+'</dd></dl>';
   if(source.actionable===true){
    body+='<p>Work ACK means “I am tracking this.” It pauses reminders for the selected lease and never marks work complete. A lease crossing a verified deadline is rejected.</p>'+
     '<label class="mg-ns-field">Pause duration<select class="mg-ns-select" id="mgEngineLeaseMinutes"><option value="30">30 minutes</option><option value="60">1 hour</option><option value="120">2 hours</option><option value="240">4 hours</option></select></label><div class="mg-n6-actions">';
    ['ack','snooze','resume'].forEach(function(action){body+='<button type="button" class="mg-ns-btn" onclick="mgEngineSourceAction(\''+esc(id)+'\',\''+action+'\')">'+({ack:'Acknowledge work',snooze:'Snooze source',resume:'Resume reminders'})[action]+'</button>';});body+='</div>';
   }
  }
  body+='<p id="mgEngineActionResult" role="status" aria-live="polite"></p></div>';
  window.openModal('Notification policy and source',body,'<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button>');
 }catch(e){if(token===opening)window.openModal('Notification policy and source','<p>Could not verify current server state. Check the connection and reopen this notification.</p>','<button type="button" class="btn ghost sm" onclick="closeModal()">Close</button>');}
};
window.mgEngineOpenTodo=function(id){if(!/^\d{1,18}$/.test(String(id)))return;if(typeof window.closeModal==='function')window.closeModal();if(typeof window.mgTodoNotifOpen==='function')window.mgTodoNotifOpen(id);};
window.mgEngineSourceAction=async function(id,action){
 if(pending.has(String(id)))return;var entry=details.get(String(id));if(!entry)return;
 var n=entry.notification,d=entry.data,raw=n.raw||{};
 var type=n.entityType||raw.entity_type,sourceId=n.ref||raw.entity_id;
 if(!type||!sourceId){message('Source reference unavailable. Reopen the notification.',true);return;}
 var select=document.getElementById('mgEngineLeaseMinutes'),minutes=Number(select&&select.value||30);
 if(![30,60,120,240].includes(minutes))return;
 pending.add(String(id));message('Saving source reminder state…');
 try{
  var until=action==='resume'?null:new Date(Date.parse(d.checked_at)+minutes*60000).toISOString();
  var saved=await rpc('notification_source_interaction',{p_entity_type:type,p_entity_id:String(sourceId),p_action:action,p_until:until,p_expected_revision:(d.interaction||{}).revision||0});
  if(!saved||saved.saved!==true)throw Error('Server did not confirm the update');
  var checked=await rpc('notification_operator_diagnostics',{p_notification_id:id});
  if(Number((checked.interaction||{}).revision)!==Number(saved.revision))throw Error('Source changed again; reopen details to review');
  details.set(String(id),{notification:n,data:checked});message('Source reminder state saved and verified. Business status is unchanged.');
 }catch(e){message(/40001|revision conflict/i.test(String(e.code||'')+' '+String(e.message||''))?'Another device changed this source. Reopen details and review before saving.':String(e.message||'Could not confirm the update. Reopen details before retrying.'),true);}
 finally{pending.delete(String(id));}
};
})();
