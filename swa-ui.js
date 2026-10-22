/* MG-HRM SWA V2 UI: isolated from legacy To-Do and notification actions.
   Works only after authenticated server response; no offline save claims. */
(function(){
 'use strict';
 if(window.__MG_SWA_UI)return;window.__MG_SWA_UI=true;
 const policy=window.SWAModel;
 const state={items:[],view:'attention',open:false,loading:false,working:false,session:null,briefIndex:0,
   captureKey:null,historyId:null,events:[],user:null,loaded:false,error:''};
 const $=s=>document.querySelector(s);
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const format=v=>v?new Intl.DateTimeFormat('bn-BD',{timeZone:'Asia/Dhaka',dateStyle:'medium',timeStyle:'short'}).format(new Date(v)):'নির্ধারিত নেই';
 function db(){const client=window.MGHRM?._client?.()||window.MGHRM?.client||window.sb;if(!client)throw Error('সার্ভার সংযোগ প্রস্তুত নয়');return client;}
 async function query(p){
  const result=await db().from(p).select('*').limit(500);
  if(result.error)throw result.error;return result.data||[];
 }
 async function rpc(name,args){
  const result=await db().rpc(name,args);if(result.error)throw result.error;return result.data;
 }
 function notify(message,error=false){
  const box=$('#swa-toast');if(!box)return;
  box.textContent=message;box.classList.toggle('error',error);box.hidden=false;
  clearTimeout(notify.timer);notify.timer=setTimeout(()=>box.hidden=true,5500);
 }
 function runtimeRisk(item){
  const risk=policy.dueRisk(item);
  return risk.label==='overdue'?'মেয়াদ পেরিয়েছে':risk.label==='before_office_risk'?'অফিস খোলার আগে ঝুঁকি':risk.label==='due_soon'?'শীঘ্রই সময়সীমা':'';
 }
 function openUI(view='attention'){
  if(!state.user){notify('প্রথমে MG-HRM-এ সাইন ইন করুন',true);return;}
  state.view=view;state.open=true;
  $('#swa-shell').hidden=false;$('#swa-launcher').setAttribute('aria-expanded','true');
  document.body.classList.add('swa-open');
  render();load();
 }
 function closeUI(){
  state.open=false;$('#swa-shell').hidden=true;$('#swa-launcher').setAttribute('aria-expanded','false');
  document.body.classList.remove('swa-open');$('#swa-launcher').focus();
 }
 async function load(){
  if(!state.user||state.loading)return;state.loading=true;state.error='';render();
  try{
   const rows=await query('swa_work_items');
   state.items=rows;state.loaded=true;
   if(state.historyId)await loadHistory(state.historyId,false);
  }catch(e){state.error='সার্ভার থেকে কাজের তালিকা আনা যায়নি: '+(e.message||e);}
  finally{state.loading=false;render();}
 }
 function selection(){
  const now=Date.now();
  const rows=state.items.filter(item=>policy.active(item,now)).sort((a,b)=>policy.rank(a,now)-policy.rank(b,now) ||
    Date.parse(a.next_review_at||0)-Date.parse(b.next_review_at||0));
  switch(state.view){
   case 'manager':return rows.filter(policy.isManagerPending);
   case 'night':return rows.filter(x=>x.captured_after_hours);
   case 'office':return rows.filter(x=>x.execution_required&&!x.executed_at);
   case 'external':return rows.filter(x=>x.stage==='waiting_external');
   case 'salary':return rows.filter(x=>x.category==='salary_note');
   case 'resolved':return state.items.filter(x=>['completed','cancelled'].includes(x.stage)).sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at));
   default:return rows;
  }
 }
 function card(item,brief=false){
  const todo=item.source_module==='todo'&&/^\d+$/.test(String(item.source_record_id||''));
  const steps=policy.outstanding(item);
  const isClosed=['completed','cancelled'].includes(item.stage);
  const due=runtimeRisk(item);
  const managerControls=item.manager_required&&!isClosed?'<div class="swa-controls"><label>যোগাযোগ মাধ্যম <select id="swa-channel-'+item.id+'"><option value="phone">ফোন</option><option value="in_person">সরাসরি</option><option value="message">মেসেজ</option><option value="paper">লিখিত</option><option value="other">অন্যান্য</option></select></label>'+
    '<button data-do="informed" data-id="'+item.id+'">ম্যানেজারকে জানিয়েছি</button><label>বাস্তব সিদ্ধান্ত <select id="swa-decision-'+item.id+'"><option value="pending">সিদ্ধান্ত অপেক্ষমাণ</option><option value="approved">অনুমোদন দিয়েছেন</option><option value="rejected">না-মঞ্জুর করেছেন</option><option value="needs_info">আরও তথ্য চেয়েছেন</option><option value="postponed">পরে আলোচনা</option></select></label><button data-do="decision" data-id="'+item.id+'">সিদ্ধান্ত রেকর্ড</button></div>':'';
  return '<article class="swa-card" data-card="'+item.id+'">'+
   '<div class="swa-itemtop"><span class="swa-tag">'+safe({general:'General',my_task:'My Task',inform_manager:'Inform to Manager',salary_note:'Salary Note'}[item.category]||item.category)+'</span>'+
   '<span class="swa-priority '+safe(item.priority)+'">'+safe(item.priority)+'</span>'+ (due?'<strong class="swa-risk">'+safe(due)+'</strong>':'')+'</div>'+
   '<h3>'+safe(item.subject)+'</h3>'+
   '<p class="swa-sub">'+[item.project,item.requestor].filter(Boolean).map(safe).join(' · ')+'</p>'+
   '<p><b>পরবর্তী কাজ:</b> '+safe(item.next_action)+'</p>'+
   (item.next_party?'<p>অপেক্ষমাণ ব্যক্তি/পক্ষ: '+safe(item.next_party)+'</p>':'')+
   '<div class="swa-times">'+(item.deadline_at?'<span>Deadline: '+safe(format(item.deadline_at))+'</span>':'')+
   (item.promised_at?'<span>প্রতিশ্রুতি: '+safe(format(item.promised_at))+'</span>':'')+
   (item.next_review_at?'<span>ফলো-আপ: '+safe(format(item.next_review_at))+'</span>':'')+'</div>'+
   (item.manager_required?'<p class="swa-sub">ম্যানেজার: '+(item.manager_informed_at?'জানানো হয়েছে ('+safe(format(item.manager_informed_at))+')' :'নতুন Work Ledger-এ যোগাযোগ নথিবদ্ধ নয়')+
   ' · সিদ্ধান্ত: '+safe(item.manager_decision)+' · '+(item.manager_decision_at?'ম্যানুয়ালি নথিবদ্ধ':'নতুন Work Ledger-এ সিদ্ধান্ত নথিবদ্ধ নয়')+'</p>':'')+
   (steps.length?'<p class="swa-steps">বাকি: '+safe(steps.join(' → '))+'</p>':'<p class="swa-steps">আবশ্যক ধাপগুলো নথিবদ্ধ হয়েছে</p>')+
   (todo?'<button class="swa-link" data-do="source" data-id="'+item.id+'">মূল To-Do দেখুন ↗</button>':'')+
   managerControls+
   (isClosed?'<div class="swa-controls"><button data-do="reopen" data-id="'+item.id+'">পুনরায় খুলুন</button><button data-do="history" data-id="'+item.id+'">ইতিহাস</button></div>':
    '<details class="swa-more" '+(brief?'':'')+'><summary>পরবর্তী পদক্ষেপ ও অন্যান্য অ্যাকশন</summary><div class="swa-controls">'+
     (item.communication_required&&!item.communicated_at?'<button data-do="communicated" data-id="'+item.id+'">সংশ্লিষ্ট পক্ষকে জানিয়েছি</button>':'')+
     (item.execution_required&&!item.executed_at&&!(item.approval_required&&item.manager_decision==='rejected')?'<button data-do="executed" data-id="'+item.id+'">অফিসীয় কাজ করেছি</button>':'')+
     (item.verification_required&&!item.verified_at?'<button data-do="verified" data-id="'+item.id+'">যাচাই করেছি</button>':'')+
     '<button data-do="next_action" data-id="'+item.id+'">Next Action</button><button data-do="waiting_external" data-id="'+item.id+'">External Reply</button>'+
     '<button data-do="followup" data-id="'+item.id+'">Follow-up সময়</button><button data-do="ack" data-id="'+item.id+'">৪ ঘণ্টা Acknowledge</button>'+
     '<button data-do="snooze" data-id="'+item.id+'">Remind Later</button><button data-do="history" data-id="'+item.id+'">Timeline</button>'+
     (policy.canComplete(item)?'<button class="swa-primary" data-do="complete" data-id="'+item.id+'">Completed</button>':'')+
     '<button data-do="cancel" data-id="'+item.id+'">বাতিল</button></div></details>')+'</article>';
 }
 function render(){
  if(!state.open)return;
  const title={attention:'Needs Attention',manager:'Brief Manager Now',night:'Night Inbox',office:'Office Action Queue',
   external:'Waiting for External',salary:'Salary Notes',resolved:'Completed & Cancelled'}[state.view];
  $('#swa-title').textContent=title;
  const nav=['attention','manager','night','office','external','salary','resolved'];
  const labels=['সব কাজ','Brief Manager Now','Night Inbox','Office Queue','Waiting Reply','Salary','শেষ হয়েছে'];
  $('#swa-tabs').innerHTML=nav.map((v,i)=>'<button class="'+(state.view===v?'selected':'')+'" data-view="'+v+'" aria-pressed="'+(state.view===v)+'">'+labels[i]+'</button>').join('');
  const view=selection();
  $('#swa-summary').textContent=state.loading?'সার্ভার সিঙ্ক হচ্ছে…':state.error||('সার্ভারে সংরক্ষিত '+view.length+'টি বিষয় · সময় Asia/Dhaka · সাপ্তাহিক ছুটির ক্যালেন্ডার এখনও নিশ্চিত নয়');
  const latest=$('#swa-list');
  if(state.view==='manager'){
   const index=Math.min(Math.max(0,state.briefIndex),Math.max(view.length-1,0));state.briefIndex=index;
   $('#swa-manager-tools').hidden=false;
   $('#swa-manager-tools').innerHTML='<button data-do="session">'+(state.session?'সেশন চালু':'ব্রিফিং সেশন শুরু')+'</button>'+
   (state.session?'<button data-do="end_session">সেশন শেষ ও সারাংশ</button>':'')+
   '<button data-do="prev" '+(!index?'disabled':'')+'>← আগেরটি</button><b>'+(view.length?index+1:0)+' / '+view.length+'</b>'+
   '<button data-do="next" '+(index>=view.length-1?'disabled':'')+'>পরবর্তী →</button>';
   latest.innerHTML=view.length?card(view[index],true):'<p class="swa-empty">ম্যানেজারের সঙ্গে আলোচনার জন্য অপেক্ষমাণ কোনো বিষয় নেই।</p>';
  }else{
   $('#swa-manager-tools').hidden=true;
   latest.innerHTML=view.length?view.slice(0,200).map(item=>card(item)).join(''):
     '<p class="swa-empty">'+(state.loaded?'এই ভিউতে কোনো কাজ নেই।':'তালিকা লোড হচ্ছে…')+'</p>';
  }
  if(state.historyId){
   $('#swa-timeline').hidden=false;
   $('#swa-timeline').innerHTML='<div class="swa-historyhead"><strong>পরিবর্তনের ইতিহাস</strong><button data-do="close_history">বন্ধ</button></div>'+
   state.events.map(e=>'<p>'+safe(format(e.recorded_at))+' · '+safe(e.event_type)+
      (e.channel?' · '+safe(e.channel):'')+'</p>').join('');
  }else $('#swa-timeline').hidden=true;
 }
 async function loadHistory(id,r=true){
  const resp=await db().from('swa_work_events').select('event_type,recorded_at,channel').eq('item_id',id).order('recorded_at',{ascending:false}).limit(30);
  if(resp.error)throw resp.error;state.historyId=id;state.events=resp.data||[];if(r)render();
 }
 async function act(id,action,value){
  if(state.working)return;
  const item=state.items.find(x=>x.id===id);if(!item)return;
  state.working=true;$('#swa-list').setAttribute('aria-busy','true');
  try{
   const updated=await rpc('swa_act',{p_item_id:id,p_expected_version:item.row_version,p_action:action,
    p_value:value??null,p_session_id:state.session?.id||null});
   state.items=state.items.map(x=>x.id===id?updated:x);render();notify('সার্ভারে সংরক্ষিত হয়েছে');
  }catch(e){
   notify('সংরক্ষণ হয়নি: '+e.message,true);
   if(/conflict|changed on another device/i.test(e.message||''))await load();
  }finally{state.working=false;$('#swa-list').removeAttribute('aria-busy');}
 }
 function valueFor(action,item){
  const id=item.id;
  if(action==='informed')return $('#swa-channel-'+id)?.value||'phone';
  if(action==='decision'){
   const value=$('#swa-decision-'+id)?.value||'pending';
   if(['approved','rejected'].includes(value)&&!confirm('আপনি কি ম্যানেজারের বাস্তব সিদ্ধান্ত নিজে যাচাই করে রেকর্ড করছেন? এটি ডিজিটাল অনুমোদন নয়।'))return null;
   return value;
  }
  if(action==='complete'&&!confirm('সব প্রয়োজনীয় বাস্তব ধাপ সম্পন্ন হয়েছে নিশ্চিত?'))return null;
  if(action==='cancel')return prompt('বাতিলের কারণ (কমপক্ষে ৩ অক্ষর):');
  if(action==='reopen')return prompt('পুনরায় খোলার কারণ/পরবর্তী পদক্ষেপ:');
  if(action==='next_action')return prompt('পরবর্তী করণীয়:',item.next_action);
  if(action==='waiting_external')return prompt('যার উত্তরের অপেক্ষা:',item.next_party||'');
  if(action==='followup'){
   const date=prompt('পরবর্তী ফলো-আপ (Asia/Dhaka), YYYY-MM-DD HH:MM:');
   return date?dhakaISO(date.replace(' ','T')):null;
  }
  if(action==='snooze'){
   const minutes=Number(prompt('কত মিনিট পরে মনে করাব? (১৫–১৪৪০)', '60'));
   if(!Number.isFinite(minutes)||minutes<15||minutes>1440)return null;
   const expiry=new Date(Date.now()+minutes*60000).toISOString();
   if(item.deadline_at&&Date.parse(expiry)>Date.parse(item.deadline_at))
     if(!confirm('স্নুজ বাস্তব deadline পেরিয়ে যাবে। Deadline ও overdue warning সক্রিয় থাকবে। চালাবেন?'))return null;
   return expiry;
  }
  if(action==='communicated'||action==='executed'||action==='verified'){
   if(!confirm('এই কাজটি বাস্তবে করা হয়েছে এবং আপনি তা ম্যানুয়ালি নথিভুক্ত করছেন?'))return null;
  }
  return '';
 }
 function dhakaISO(value){
  if(!value)return null;
  const txt=value.trim().replace(' ','T');
  if(!/^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(txt))throw Error('সঠিক তারিখ ও সময় লিখুন');
  const d=new Date(txt+':00+06:00');
  if(!Number.isFinite(d.getTime()))throw Error('তারিখ/সময় সঠিক নয়');
  return d.toISOString();
 }
 function setup(){
  const launcher=document.createElement('button');
  launcher.id='swa-launcher';launcher.type='button';launcher.hidden=true;launcher.textContent='✦ Smart Work';
  launcher.setAttribute('aria-haspopup','dialog');launcher.setAttribute('aria-expanded','false');
  document.body.appendChild(launcher);
  const shell=document.createElement('div');shell.id='swa-shell';shell.hidden=true;
  shell.innerHTML='<div class="swa-backdrop" data-do="close"></div><section class="swa-panel" role="dialog" aria-modal="true" aria-labelledby="swa-title">'+
   '<header class="swa-header"><div><small>MG-HRM · Smart Work Assistant V2</small><h2 id="swa-title">Needs Attention</h2></div>'+
   '<button data-do="close" class="swa-close" aria-label="বন্ধ করুন">✕</button></header>'+
   '<nav id="swa-tabs" class="swa-tabs" aria-label="Work queues"></nav>'+
   '<div class="swa-toolbar"><button data-do="capture" class="swa-primary">+ Quick Capture</button><button data-do="reload">↻ Refresh</button>'+
   '<span id="swa-summary" role="status"></span></div>'+
   '<div id="swa-manager-tools" class="swa-manager-tools" hidden></div>'+
   '<form id="swa-capture" hidden><div class="swa-capture-head"><b>নতুন কাজ / Night Capture</b><button type="button" data-do="hide_capture">✕</button></div>'+
   '<label>বিষয় *<textarea name="subject" required maxlength="500" rows="2" placeholder="কী কাজ/অনুরোধ এসেছে?"></textarea></label>'+
   '<div class="swa-fields"><label>ট্যাব<select name="category"><option value="general">General</option><option value="my_task">My Task</option><option value="inform_manager">Inform to Manager</option><option value="salary_note">Salary Note</option></select></label>'+
   '<label>গুরুত্ব<select name="priority"><option value="important">Important</option><option value="routine">Routine</option><option value="urgent">Urgent</option><option value="critical">Critical (verified incident only)</option></select></label>'+
   '<label>কে জানিয়েছেন<input name="requestor" maxlength="200" placeholder="ব্যক্তি / অফিসার"></label>'+
   '<label>প্রজেক্ট<input name="project" maxlength="200" placeholder="প্রজেক্ট/অফিস"></label></div>'+
   '<label>পরবর্তী করণীয়<input name="next_action" maxlength="400" placeholder="যেমন ম্যানেজারকে জানাতে হবে"></label>'+
   '<details><summary>সময়, নির্ভরতা ও অতিরিক্ত তথ্য</summary><div class="swa-fields">'+
   '<label>বাস্তব Deadline (ঢাকা)<input name="deadline_at" type="datetime-local"></label>'+
   '<label>ঘটনা ঘটবে (ঢাকা)<input name="event_at" type="datetime-local"></label>'+
   '<label>প্রতিশ্রুত উত্তর (ঢাকা)<input name="promised_at" type="datetime-local"></label>'+
   '<label>ফলো-আপ (ঢাকা)<input name="next_review_at" type="datetime-local"></label>'+
   '<label>উত্তর/কাজ যার কাছে<input name="next_party" maxlength="200"></label></div>'+
   '<label>বিস্তারিত নোট<textarea name="details" rows="2" maxlength="4000"></textarea></label></details>'+
   '<div class="swa-checks"><label><input name="manager_required" type="checkbox"> ম্যানেজারকে জানাতে হবে</label>'+
   '<label><input name="approval_required" type="checkbox"> অনুমোদনের সিদ্ধান্ত প্রয়োজন</label>'+
   '<label><input name="communication_required" type="checkbox"> সংশ্লিষ্ট পক্ষকে জানাতে হবে</label>'+
   '<label><input name="execution_required" type="checkbox"> অফিসীয় কাজ করতে হবে</label>'+
   '<label><input name="verification_required" type="checkbox"> ফল যাচাই করতে হবে</label></div>'+
   '<p class="swa-hint">রাতে নথিভুক্ত করা যাবে; office execution ০৯:০০–১৮:০০। সাপ্তাহিক ছুটির দিন এখনো যাচাইকৃত নয়।</p>'+
   '<button class="swa-primary" type="submit">সার্ভারে সেভ করুন</button></form>'+
   '<div class="swa-content"><div id="swa-list"></div><aside id="swa-timeline" hidden></aside></div>'+
   '<footer class="swa-footer">কোনো সিদ্ধান্ত/অনুমোদন বা বাইরের মেসেজ স্বয়ংক্রিয় পাঠানো হয় না। Push V2 এখনও বন্ধ; পুরোনো নোটিফিকেশন আলাদা।</footer></section>'+
   '<div id="swa-toast" role="alert" hidden></div>';
  document.body.appendChild(shell);
  launcher.addEventListener('click',()=>openUI('attention'));
  shell.addEventListener('click',async e=>{
   const b=e.target.closest('[data-view],[data-do]');if(!b)return;
   if(b.dataset.view){state.view=b.dataset.view;state.briefIndex=0;render();return;}
   const action=b.dataset.do,id=b.dataset.id;
   if(action==='close'){closeUI();return;}
   if(action==='capture'){state.captureKey=state.captureKey||crypto.randomUUID();$('#swa-capture').hidden=false;$('#swa-capture [name=subject]').focus();return;}
   if(action==='hide_capture'){$('#swa-capture').hidden=true;return;}
   if(action==='reload'){await load();return;}
   if(action==='prev'||action==='next'){state.briefIndex+=action==='prev'?-1:1;render();return;}
   if(action==='close_history'){state.historyId=null;render();return;}
   if(action==='history'){try{await loadHistory(id);}catch(err){notify(err.message,true);}return;}
   if(action==='source'){
    const item=state.items.find(x=>x.id===id);closeUI();
    if(typeof navigate==='function')navigate('todo');
    if(item?.source_record_id&&typeof window.mgTodoNotifOpen==='function')window.mgTodoNotifOpen(item.source_record_id);
    return;
   }
   if(action==='session'){
    try{state.session=await rpc('swa_start_briefing',{p_note:null});state.briefIndex=0;render();notify('ম্যানেজার ব্রিফিং সেশন শুরু হয়েছে');}
    catch(err){notify('সেশন শুরু হয়নি: '+err.message,true);}return;
   }
   if(action==='end_session'){
    if(!state.session)return;
    try{
     const sid=state.session.id;
     await rpc('swa_close_briefing',{p_id:sid});
     const rows=await db().from('swa_work_events').select('item_id,event_type').eq('session_id',sid);
     state.session=null;render();
     const records=rows.data||[];
     notify('সেশন শেষ। আলোচনা: '+new Set(records.map(x=>x.item_id)).size+'; সিদ্ধান্ত নথিবদ্ধ: '+records.filter(x=>x.event_type==='decision').length);
    }catch(err){notify(err.message,true);}return;
   }
   const item=state.items.find(x=>x.id===id);
   if(!item)return;
   try{
    const value=valueFor(action,item);
    if(value===null)return;
    await act(id,action,value);
   }catch(err){notify(err.message,true);}
  });
  const form=$('#swa-capture');
  form.addEventListener('change',e=>{
   if(e.target.name==='category'){
    const cat=e.target.value;
    form.elements.manager_required.checked=cat==='inform_manager';
    form.elements.communication_required.checked=cat==='inform_manager';
    form.elements.execution_required.checked=cat==='my_task'||cat==='salary_note';
   }
   if(e.target.name==='approval_required'&&e.target.checked)form.elements.manager_required.checked=true;
  });
  form.addEventListener('submit',async e=>{
   e.preventDefault();if(state.working)return;
   const fd=new FormData(form),payload={};
   for(const [key,val] of fd)if(key!=='subject'&&val)payload[key]=val;
   payload.subject=String(fd.get('subject')||'').trim();
   for(const key of ['manager_required','approval_required','communication_required','execution_required','verification_required'])
    payload[key]=form.elements[key].checked;
   state.working=true;const button=form.querySelector('[type=submit]');button.disabled=true;
   try{
    for(const key of ['deadline_at','event_at','promised_at','next_review_at'])
     if(payload[key])payload[key]=dhakaISO(payload[key]);
    await rpc('swa_capture',{p_capture_key:state.captureKey||crypto.randomUUID(),p_payload:payload});
    state.captureKey=null;form.reset();form.hidden=true;
    await load();notify('কাজটি সার্ভারে স্থায়ীভাবে সংরক্ষিত হয়েছে');
   }catch(err){notify('কাজটি সেভ হয়নি; আবার চেষ্টা করুন: '+err.message,true);}
   finally{state.working=false;button.disabled=false;}
  });
  window.addEventListener('keydown',e=>{if(e.key==='Escape'&&state.open)closeUI();});
  window.addEventListener('online',()=>{if(state.open)load();});
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&state.open)load();});
  setInterval(()=>{if(state.open&&!document.hidden)load();},60000);
  async function signedIn(){
   try{const session=await window.MGHRM?.getSession?.();state.user=session?.user||null;launcher.hidden=!state.user;
    if(!state.user){state.items=[];state.loaded=false;if(state.open)closeUI();}
   }catch{launcher.hidden=true;}
  }
  signedIn();
  window.MGHRM?.onChange?.(()=>{signedIn();});
  window.MGSWA={open:openUI,refresh:load};
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',setup);else setup();
})();