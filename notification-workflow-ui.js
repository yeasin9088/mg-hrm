/* Work steps inside the four existing To-Do tabs. Server-authoritative milestones,
 * identity-scoped offline intents, explicit conflicts, no external sending. */
(function(){
'use strict';
if(window.__mgWorkSteps)return;window.__mgWorkSteps=true;
var cache=new Map(),lastLoad=0,loading=false,active=null,busy=false,sessionId=null,queueOwner=null;
function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function client(){return window.MGHRM&&window.MGHRM.client||window.sb;}
async function rpc(name,args){var c=client();if(!c||!c.rpc)throw Error('Backend unavailable');var r=await c.rpc(name,args||{});if(r.error)throw r.error;return r.data;}
function fmt(v){return v?new Date(v).toLocaleString('en-GB',{timeZone:'Asia/Dhaka'}):'Unknown';}
function localTime(v){if(!v)return '';return new Date(Date.parse(v)+21600000).toISOString().slice(0,16);}
function utcTime(v){return v?new Date(v+':00+06:00').toISOString():null;}
function modal(title,body,foot){window.openModal(title,'<div class="mg-work">'+body+'</div>',foot||'<button class="btn ghost sm" type="button" onclick="closeModal()">Close</button>');}
function status(text,error){var e=document.getElementById('mgWorkStatus');if(e){e.textContent=text;e.className=error?'mg-work-error':'';}}
function toast(text,error){if(typeof window.toast==='function')window.toast(text,error?'warning':'success');}
async function owner(){var c=client();if(!c||!c.auth)throw Error('Sign in before saving work');var r=await c.auth.getSession();var id=r.data&&r.data.session&&r.data.session.user.id;if(!id)throw Error('Sign in before saving work');return id;}
function database(){return new Promise(function(resolve,reject){var r=indexedDB.open('mghrm-work-intents',1);r.onupgradeneeded=function(){r.result.createObjectStore('intents',{keyPath:'key'});};r.onerror=function(){reject(r.error);};r.onsuccess=function(){resolve(r.result);};});}
async function store(mode,operation){var db=await database();return new Promise(function(resolve,reject){var tx=db.transaction('intents',mode),r=operation(tx.objectStore('intents'));var value;r.onsuccess=function(){value=r.result;};tx.oncomplete=function(){db.close();resolve(value);};tx.onerror=function(){db.close();reject(tx.error);};tx.onabort=function(){db.close();reject(tx.error||Error('Offline save failed'));};});}
async function enqueue(call){var uid=await owner();call.owner=uid;call.key=call.args.p_request_id||call.args.p_capture_key;call.created_at=new Date().toISOString();await store('readwrite',function(s){return s.put(call);});return call;}
async function pending(){var uid=await owner();var rows=await store('readonly',function(s){return s.getAll();});return rows.filter(function(x){return x.owner===uid;}).sort(function(a,b){return a.created_at.localeCompare(b.created_at);});}
async function remove(key){await store('readwrite',function(s){return s.delete(key);});}
async function synchronizeSource(id){var c=client();if(!c||!c.from)return;var r=await c.from('todos').select('*').eq('id',id).single();if(r.error)throw r.error;var rows=window.DATA&&window.DATA.todos;if(Array.isArray(rows)){var i=rows.findIndex(function(x){return String(x.id)===String(id);});if(i>=0)rows[i]=r.data;else rows.unshift(r.data);}}
async function flush(){
 if(busy)return;busy=true;
 try{var rows=await pending();queueOwner=await owner();
  for(var call of rows){if(call.conflict)continue;if(await owner()!==call.owner)break;
   try{var result=await rpc(call.name,call.args);await remove(call.key);var id=call.args.p_todo_id||result.todo_id;
    if(result.work)cache.set(String(id),result);try{await synchronizeSource(id);}catch(e){/* save is durable, source refresh may retry */}
   }catch(e){if(e.code&& !['08000','08006','PGRST000','PGRST001','PGRST002'].includes(e.code)||/conflict/i.test(e.message||'')){call.conflict=true;call.problem=e.code==='40001'?'Another device changed this work. Review the current record before retrying.':String(e.message||'Server rejected this queued change; review it.');await store('readwrite',function(s){return s.put(call);});}break;}
  }
 }catch(e){/* queue remains durable; no success claims */}finally{busy=false;lastLoad=0;await refresh();}
}
async function submit(name,args){
 var uid=await owner(),rows=await pending();
 if(args.p_todo_id&&rows.some(function(c){return String(c.args.p_todo_id)===String(args.p_todo_id);}))throw Error('An earlier change for this item is still queued. Review pending saves.');
 var call=await enqueue({name:name,args:args});
 try{if(navigator.onLine===false)throw Error('Offline');if(await owner()!==uid)throw Error('Account changed');var result=await rpc(name,args);await remove(call.key);return {saved:true,data:result};}
 catch(e){if(e.code==='40001'||/conflict/i.test(e.message||'')){call.conflict=true;call.problem='Record changed on another device. Review before retrying.';await store('readwrite',function(s){return s.put(call);});throw e;}
 // Business validation is definitive: do not automatically retry a rejected action.
 if(e.code&& !['08000','08006','PGRST000','PGRST001','PGRST002'].includes(e.code)){call.conflict=true;call.problem=String(e.message||'Server rejected this change. Review before retrying.');await store('readwrite',function(s){return s.put(call);});throw e;}
 return {saved:false,queued:true};}
}
async function refresh(){if(loading)return;loading=true;
 try{var uid=await owner();if(queueOwner&&queueOwner!==uid){cache.clear();active=null;sessionId=null;}queueOwner=uid;
 var data=await rpc('notification_work_get',{p_todo_id:null});cache.clear();(data.items||[]).forEach(function(x){cache.set(String(x.todo_id),x);});lastLoad=Date.now();
 }catch(e){lastLoad=Date.now();}finally{loading=false;if(typeof window.renderTodo==='function')window.renderTodo();}}
window.mgWorkRow=function(id){var entry=cache.get(String(id)),s=entry&&entry.summary;var badge='';
 if(s&&s.active){badge='<span class="mg-work-badge'+(['overdue','before_office_risk'].includes(s.risk)?' risk':'')+'">'+esc(s.risk==='date_unknown'?'Date unknown':s.risk.replace(/_/g,' '))+'</span>';
 if(s.after_hours_captured)badge+='<span class="mg-work-badge">After-hours captured</span>';
 if(s.needs_next_action)badge+='<span class="mg-work-badge risk">Needs next action</span>';
 return '<div class="mg-work-inline">'+badge+'<span>'+esc(s.next_action)+' · '+esc(s.next_party)+'</span><button type="button" class="td-btn b-ghost" onclick="event.stopPropagation();mgWorkOpen(\''+esc(id)+'\')">Work steps</button></div>';}
 return '<button type="button" class="td-btn b-ghost" onclick="event.stopPropagation();mgWorkOpen(\''+esc(id)+'\')">Work steps</button>';
};
window.mgWorkPass=function(id){if(!window.MG_WORK_FOCUS)return true;var x=cache.get(String(id));if(!x||!x.summary)return true;var s=x.summary;return s.active&&(s.needs_next_action||s.needs_review||s.stale||['overdue','before_office_risk','due_soon'].includes(s.risk)||s.group==='BRIEF_MANAGER');};
function toolbar(){var page=document.getElementById('page-todo');if(!page)return;var host=page.querySelector('.td-wrap')||page.querySelector('.td-root')||page;var bar=document.getElementById('mgWorkToolbar');if(!bar){bar=document.createElement('div');bar.id='mgWorkToolbar';bar.className='mg-work-toolbar';host.prepend(bar);}
 var open=Array.from(cache.values()).filter(function(x){return x.summary&&x.summary.active;}),risk=open.filter(function(x){return ['overdue','before_office_risk'].includes(x.summary.risk);}).length;
 bar.innerHTML='<span>'+open.length+' open · '+risk+' deadline risks</span><button type="button" onclick="mgWorkFocus()" aria-pressed="'+!!window.MG_WORK_FOCUS+'">'+(window.MG_WORK_FOCUS?'Show all open':'Needs attention')+'</button><button type="button" onclick="mgWorkBrief()">Brief manager now</button><button type="button" onclick="mgWorkQuickCapture()">Quick capture</button><button type="button" onclick="mgWorkPending()">Pending saves</button>';
}
var render=window.renderTodo;if(typeof render==='function')window.renderTodo=function(){render.apply(this,arguments);toolbar();if(Date.now()-lastLoad>30000&&!loading)refresh();};
window.mgWorkFocus=function(){window.MG_WORK_FOCUS=!window.MG_WORK_FOCUS;window.MG_TD_SUB='unsolved';window.renderTodo();};
window.mgWorkOpen=async function(id){active={id:String(id),data:null};modal('Work steps','<p role="status">Reading current workflow…</p>');try{var d=await rpc('notification_work_get',{p_todo_id:Number(id)});if(!active||active.id!==String(id))return;active.data=d;cache.set(String(id),d);draw();}catch(e){modal('Work steps','<p>'+esc(e.message||'Could not load. Check your connection.')+'</p>');}};
function field(key,label,value,type){return '<label>'+esc(label)+'<input id="mgWork_'+key+'" type="'+(type||'text')+'" value="'+esc(value==null?'':value)+'"></label>';}
function draw(){var d=active.data,w=d.work,s=d.summary,body='<p><strong>'+esc(w.subject)+'</strong></p><p>'+esc(s.next_action||w.next_action)+' · '+esc(s.next_party||w.next_party)+'</p>';
 body+='<div class="mg-work-tags">'+(s.active?'<span>'+esc(s.risk)+'</span>':'<span>Resolved source</span>')+(s.after_hours_captured?'<span>After-hours captured</span>':'')+(s.needs_next_action?'<span>Needs next action</span>':'')+'<span>Manager: '+esc(w.manager_decision)+'</span><span>Communication: '+(s.communication_pending?'pending':'recorded / not required')+'</span></div>';
 if(d.duplicate_candidates&&d.duplicate_candidates.length)body+='<details><summary>Possible duplicate · review only</summary><p>Similar open requests in the same project. They remain independent; no automatic merge.</p>'+d.duplicate_candidates.map(function(x){return '<button type="button" onclick="mgWorkOpen(\''+esc(x.todo_id)+'\')">Review #'+esc(x.todo_id)+' · '+esc(x.subject)+'</button>';}).join('')+'</details>';
 if(s.steps&&s.steps.length)body+='<ul>'+s.steps.map(function(x){return '<li>'+esc(x)+'</li>';}).join('')+'</ul>';
 if(s.source_type)body+='<button type="button" onclick="mgWorkOriginal()">Open original '+esc(s.source_type.replace(/_/g,' '))+' #'+esc(s.source_id)+'</button>';
 body+='<p class="mg-work-help">Office execution 09:00–18:00 · Asia/Dhaka. Manager discussions and manual records are available anytime. Weekly holidays and payroll cutoff are unconfigured.</p>';
 body+='<details><summary>Edit action plan, dates and required steps</summary><div class="mg-work-grid">'+field('next_action','Next action',w.next_action)+field('next_party','Responsible party',w.next_party||'You')+
 field('next_review_at','Next review · Dhaka',localTime(w.next_review_at),'datetime-local')+field('deadline_at','True business deadline · Dhaka',localTime(w.deadline_at),'datetime-local')+
 field('event_at','Actual event time · Dhaka',localTime(w.event_at),'datetime-local')+field('promised_at','Promised response · Dhaka',localTime(w.promised_at),'datetime-local')+
 '<label>Priority<select id="mgWork_priority">'+['routine','important','urgent','critical'].map(function(v){return '<option '+(v===w.priority?'selected':'')+'>'+v+'</option>';}).join('')+'</select></label>'+
 '<label>Stage<select id="mgWork_stage">'+['active','waiting_manager','waiting_external','blocked','verification'].map(function(v){return '<option '+(v===w.stage?'selected':'')+'>'+v+'</option>';}).join('')+'</select></label>'+field('hold_reason','Blocker / hold reason',w.hold_reason)+field('change_reason','Reason for changing required steps','')+field('communication_parties','Tell these parties (comma separated)',(w.communication_parties||[]).join(', '));
 ['manager_required','approval_required','communication_required','execution_required','verification_required'].forEach(function(k){body+='<label class="mg-work-check"><input type="checkbox" id="mgWork_'+k+'" '+(w[k]?'checked':'')+'>'+esc(k.replace(/_/g,' '))+'</label>';});
 body+='<label>Original module<select id="mgWork_source_type"><option value="">Manual / none</option>'+['transfer','leave','exit','recruitment','uniform_supply_order','uniform_delivery_issue','uniform_delivery_bill','disciplinary','meeting'].map(function(v){return '<option value="'+v+'" '+(v===s.source_type?'selected':'')+'>'+esc(v.replace(/_/g,' '))+'</option>';}).join('')+'</select></label>'+field('source_id','Original record ID',s.source_id)+
 '<label class="mg-work-wide">Required checklist · one action per line<textarea id="mgWork_checklist" rows="3">'+esc((w.context.checklist||[]).map(function(x){return x.label;}).join('\n'))+'</textarea></label>'+
 '<label class="mg-work-wide">Salary allocation / external follow-up context (record only)<textarea id="mgWork_context" rows="3">'+esc(w.context&&w.context.note||'')+'</textarea></label></div><button type="button" onclick="mgWorkSavePlan()">Save action plan</button></details>';
 if(w.category==='salary_note')body+='<details><summary>Salary allocation verification</summary><p>Record date ranges and projects without calculating or changing payroll. Missing or overlapping days require verification.</p>'+field('salary_month','Salary month · YYYY-MM',w.context.salary_month||'')+'<label class="mg-work-check"><input type="checkbox" id="mgWork_allocation_required" '+(w.context.allocation_required?'checked':'')+'>Allocation verification required</label><label>Project date ranges · one per line: Project | YYYY-MM-DD | YYYY-MM-DD<textarea id="mgWork_allocations" rows="4">'+esc((w.context.allocations||[]).map(function(a){return a.project+' | '+a.from+' | '+a.to;}).join('\n'))+'</textarea></label><button type="button" onclick="mgWorkSavePlan()">Save allocation context and plan</button></details>';
 body+='<label>Actual occurrence time · Dhaka (optional)<input type="datetime-local" id="mgWork_occurred_at"></label><div class="mg-work-actions">';
 if(s.active){if(w.manager_required)body+='<button type="button" onclick="mgWorkAction(\'informed\',\'phone\')">Manager informed · phone</button><button type="button" onclick="mgWorkAction(\'informed\',\'in_person\')">Manager informed · in person</button>';
 if(w.manager_required)body+='<label>Manually recorded manager decision<select id="mgWorkDecision"><option>approved</option><option>rejected</option><option>pending</option><option>needs_info</option><option>postponed</option></select></label><button type="button" onclick="mgWorkAction(\'decision\',document.getElementById(\'mgWorkDecision\').value)">Record decision</button>';
 if(w.communication_required){var parties=w.communication_parties&&w.communication_parties.length?w.communication_parties:[''];parties.forEach(function(p,i){body+='<button type="button" data-work-party="'+i+'" '+(p&&w.communicated_parties&&w.communicated_parties[p]?'disabled':'')+'>Record communicated'+(p?' · '+esc(p):'')+'</button>';});}
 (w.context.checklist||[]).forEach(function(step,i){body+='<button type="button" data-work-step="'+i+'" '+(step.completed_at?'disabled':'')+'>Record done · '+esc(step.label)+'</button>';});
 if(w.execution_required)body+='<button type="button" onclick="mgWorkAction(\'executed\')" '+(w.executed_at?'disabled':'')+'>Record actual execution</button>';
 if(w.verification_required)body+='<button type="button" onclick="mgWorkAction(\'verified\')" '+(w.verified_at?'disabled':'')+'>Record verified result</button>';
 body+='</div>'+field('outcome','Outcome / evidence reference','')+'<button type="button" onclick="mgWorkComplete()" '+(s.can_complete?'':'disabled')+'>Complete work</button>';
 }else body+='<button type="button" onclick="mgWorkReopen()">Reopen with new action</button></div>';
 body+='<p id="mgWorkStatus" role="status" aria-live="polite"></p><details><summary>Audit history</summary>'+(d.events||[]).map(function(e){return '<p><strong>'+esc(e.event_type)+'</strong> · '+esc(fmt(e.event_at))+'<br><small>Recorded '+esc(fmt(e.recorded_at))+' · '+esc(e.channel||'operator record')+'</small></p>';}).join('')+'</details>';
 modal('Work steps',body);document.querySelectorAll('[data-work-step]').forEach(function(b){b.onclick=function(){return window.mgWorkAction('check_step',w.context.checklist[Number(b.dataset.workStep)].id);};});document.querySelectorAll('[data-work-party]').forEach(function(button){button.onclick=function(){var p=(w.communication_parties||[])[Number(button.dataset.workParty)]||'';window.mgWorkAction('communicated',p);};});
}
async function save(action,payload){if(!active||!active.data||busy)return;var id=active.id;busy=true;status('Saving…');
 try{payload=payload||{};if(sessionId)payload.session_id=sessionId;var r=await submit('notification_work_save',{p_todo_id:Number(id),p_expected_version:active.data.work.row_version,p_request_id:crypto.randomUUID(),p_action:action,p_payload:payload});
 if(r.saved){active.data=r.data;cache.set(id,r.data);draw();status('Saved on the server.');try{await synchronizeSource(id);}catch(e){}if(window.renderTodo)window.renderTodo();}
 else status('Queued on this device. The server has not confirmed this change. Use Pending saves to review.',true);
 }catch(e){status(e.code==='40001'?'Another device changed this item. Close and reopen it, then review Pending saves.':e.message||'Could not save.',true);}finally{busy=false;}}
window.mgWorkOriginal=function(){if(!active||!active.data)return;var s=active.data.summary,id=s.source_id,type=s.source_type;var route=type&&type.startsWith('uniform_')?'uniform':type;if(!['transfer','leave','exit','uniform','recruitment','disciplinary','meeting'].includes(route))return;window.closeModal();if(window.navigate)window.navigate(route);
 if(type==='transfer'&&window.openDashboardTransfer)window.openDashboardTransfer(id);
 else if(type==='disciplinary'&&window.mgOpenDisciplinaryRecord)window.mgOpenDisciplinaryRecord(id);
 else if(type==='uniform_supply_order'&&window.openUniformOrder)window.openUniformOrder(id);
 // Lists expose the original record reference when a module has no ID deep-link API.
 else toast('Original '+type.replace(/_/g,' ')+' reference #'+id+'. Review it in this module.');
};
window.mgWorkAction=function(action,value){var input=document.getElementById('mgWork_occurred_at');return save(action,{value:value||null,occurred_at:utcTime(input&&input.value)});};
window.mgWorkComplete=function(){return save('complete',{value:document.getElementById('mgWork_outcome').value});};
window.mgWorkReopen=function(){var value=window.prompt('New next action and reopening reason');if(value)return save('reopen',{value:value});};
window.mgWorkSavePlan=function(){var w=active.data.work,p={};['next_action','next_party','priority','stage','hold_reason','change_reason','source_type','source_id'].forEach(function(k){p[k]=document.getElementById('mgWork_'+k).value;});
 ['next_review_at','deadline_at','event_at','promised_at'].forEach(function(k){p[k]=utcTime(document.getElementById('mgWork_'+k).value);});
 ['manager_required','approval_required','communication_required','execution_required','verification_required'].forEach(function(k){p[k]=document.getElementById('mgWork_'+k).checked;});
 p.communication_parties=document.getElementById('mgWork_communication_parties').value.split(',').map(function(x){return x.trim();}).filter(Boolean);p.context=Object.assign({},w.context,{note:document.getElementById('mgWork_context').value});p.context.checklist=document.getElementById('mgWork_checklist').value.split('\n').map(function(x){return x.trim();}).filter(Boolean).map(function(label){return (w.context.checklist||[]).find(function(s){return s.label===label;})||{id:crypto.randomUUID(),label:label,required:true};});var alloc=document.getElementById('mgWork_allocations');if(alloc){p.context.salary_month=document.getElementById('mgWork_salary_month').value;p.context.allocation_required=document.getElementById('mgWork_allocation_required').checked;p.context.allocations=alloc.value.split('\n').filter(function(x){return x.trim();}).map(function(x){var a=x.split('|').map(function(v){return v.trim();});return {project:a[0],from:a[1],to:a[2]};});}return save('plan',p);};
window.mgWorkQuickCapture=function(){modal('Quick capture','<label>Tab<select id="mgWorkCaptureCategory"><option value="note">General</option><option value="task">My Task</option><option value="permission">Inform to Manager</option><option value="salary">Salary Note</option></select></label>'+field('capture_subject','Request / next action','')+field('capture_project','Project','')+field('capture_requestor','Reported by','')+'<p id="mgWorkStatus" role="status"></p><button type="button" id="mgWorkCaptureSave">Save request</button>');
 var key=crypto.randomUUID();document.getElementById('mgWorkCaptureSave').onclick=async function(){if(busy)return;var button=this;busy=true;button.disabled=true;try{var r=await submit('notification_work_capture',{p_capture_key:key,p_payload:{category:document.getElementById('mgWorkCaptureCategory').value,subject:document.getElementById('mgWork_capture_subject').value,project:document.getElementById('mgWork_capture_project').value,requestor:document.getElementById('mgWork_capture_requestor').value}});
 if(r.saved){try{await synchronizeSource(r.data.todo_id);}catch(e){}await window.mgWorkOpen(r.data.todo_id);toast('Request saved.');lastLoad=0;}
 else {modal('Request queued','<p>This request is stored on this device. The server has not confirmed it yet.</p><button type="button" onclick="mgWorkPending()">Review pending saves</button>');return;}}
 catch(e){status(e.message,true);}finally{busy=false;if(button.isConnected)button.disabled=false;}};};
window.mgWorkPending=async function(){try{var rows=await pending();modal('Pending work saves','<p>Queued changes remain on this device until the server confirms them. Conflicts require review; discarding a queued change does not alter the server record.</p>'+rows.map(function(x){return '<article><strong>'+esc(x.name==='notification_work_capture'?x.args.p_payload.subject:'To-Do #'+x.args.p_todo_id+' · '+x.args.p_action)+'</strong><p>'+esc(x.problem||'Waiting for connection / server confirmation')+'</p>'+(x.args.p_todo_id?'<button type="button" onclick="mgWorkOpen(\''+esc(x.args.p_todo_id)+'\')">Review current record</button>':'')+'<button type="button" data-discard="'+esc(x.key)+'">Discard queued change</button></article>';}).join('')+(rows.length?'':'<p>No queued changes.</p>')+'<button type="button" onclick="mgWorkSync()">Retry connected saves</button>');document.querySelectorAll('[data-discard]').forEach(function(b){b.onclick=async function(){if(window.confirm('Discard only this unsaved change?')){await remove(b.dataset.discard);window.mgWorkPending();}};});}catch(e){modal('Pending work saves','<p>'+esc(e.message)+'</p>');}};
window.mgWorkSync=async function(){await flush();window.mgWorkPending();};
window.mgWorkBrief=async function(){try{await refresh();if(!sessionId){var s=await rpc('swa_start_briefing',{p_note:'Manager briefing from existing To-Do'});sessionId=(Array.isArray(s)?s[0]:s).id;}
 var rows=Array.from(cache.entries()).filter(function(x){return x[1].summary&&x[1].summary.active&&x[1].summary.group==='BRIEF_MANAGER';});
 modal('Brief manager now','<p>Record each discussion independently. Decisions are manually recorded; approval leaves communication and execution steps open.</p>'+rows.map(function(x){return '<article><strong>'+esc(x[1].work.subject)+'</strong><p>'+esc(x[1].summary.next_action)+'</p><button type="button" onclick="mgWorkOpen(\''+esc(x[0])+'\')">Review this request</button></article>';}).join('')+(rows.length?'':'<p>No manager requests are waiting.</p>')+'<button type="button" onclick="mgWorkCloseBrief()">Finish session and review outcomes</button>');
 }catch(e){modal('Manager briefing','<p>'+esc(e.message)+'</p>');}};
window.mgWorkCloseBrief=async function(){try{var summary=sessionId?await rpc('notification_work_brief_summary',{p_session_id:sessionId}):{};if(sessionId)await rpc('swa_close_briefing',{p_id:sessionId});sessionId=null;await refresh();var rows=Array.from(cache.values()).filter(function(x){return x.summary&&x.summary.active;});modal('Briefing review','<p>'+Number(summary.discussed||0)+' discussed · '+Number(summary.decision_recorded||0)+' decisions recorded in this session.</p><p>'+rows.filter(function(x){return x.summary.group==='BRIEF_MANAGER';}).length+' manager requests still need discussion or decision.</p><p>'+rows.filter(function(x){return x.summary.communication_pending;}).length+' requests still need communication. Execution remains separate.</p>');}catch(e){toast(e.message,true);}};
var legacyManager=window.mtSetManagerStatus;
if(legacyManager)window.mtSetManagerStatus=async function(id,state){
 try{await window.mgWorkOpen(id);if(!active||!active.data)return false;
 if(state==='asked')return window.mgWorkAction('informed','other');
 if(['approved','verbal','rejected'].includes(state))return window.mgWorkAction('decision',state==='verbal'?'approved':state);
 return legacyManager(id,state);
 }catch(e){toast(e.message,true);return false;}
};
window.addEventListener('online',flush);
// Poll only while the app is in use; notification scheduling remains server-side.
window.setInterval(function(){if(document.visibilityState==='visible')flush();},60000);
})();
