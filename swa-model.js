/* SWA V2 pure policy functions. No notification READ state is an input. */
(function(root,factory){
 if(typeof module==='object'&&module.exports) module.exports=factory();
 else root.SWAModel=factory();
})(typeof window!=='undefined'?window:globalThis,function(){
 'use strict';
 const CLOSED=new Set(['completed','cancelled']);
 const ACTIVE_DECISIONS=new Set(['none','pending','needs_info','postponed']);
 function dhakaParts(date){
  const d=new Date(date);
  if(!Number.isFinite(d.getTime())) throw Error('Invalid date');
  const local=new Date(d.getTime()+21600000);
  return {year:local.getUTCFullYear(),month:local.getUTCMonth(),day:local.getUTCDate(),
   hour:local.getUTCHours(),minute:local.getUTCMinutes()};
 }
 function officeTime(date){
  const p=dhakaParts(date);return p.hour>=9&&p.hour<18;
 }
 function nextOfficeCandidate(date){
  const p=dhakaParts(date);
  let next=Date.UTC(p.year,p.month,p.day,3,0,0);
  const now=new Date(date).getTime();
  if(now>=Date.UTC(p.year,p.month,p.day,12,0,0)) next+=86400000;
  else if(now>=next) next=now;
  return {at:new Date(next).toISOString(),calendarVerified:false};
 }
 function dueRisk(item,now=Date.now()){
  if(CLOSED.has(item.stage))return {label:'resolved',severe:false};
  const deadline=Date.parse(item.deadline_at||'');
  const promise=Date.parse(item.promised_at||'');
  const event=Date.parse(item.event_at||'');
  const candidate=Math.min(...[deadline,promise,event].filter(Number.isFinite));
  if(!Number.isFinite(candidate))return {label:'no_known_deadline',severe:false};
  if(candidate<=now)return {label:'overdue',severe:true};
  if(item.execution_required&& !officeTime(now)&&candidate<Date.parse(nextOfficeCandidate(now).at))
   return {label:'before_office_risk',severe:true};
  if(candidate-now<=86400000)return {label:'due_soon',severe:true};
  return {label:'future',severe:false};
 }
 function isManagerPending(item){
  return !CLOSED.has(item.stage)&&item.manager_required &&
  (!item.manager_informed_at || ACTIVE_DECISIONS.has(item.manager_decision));
 }
 function outstanding(item){
  if(CLOSED.has(item.stage))return [];
  const steps=[];
  if(item.manager_required&&!item.manager_informed_at)steps.push('ম্যানেজারকে জানান');
  if(item.approval_required&&!['approved','rejected'].includes(item.manager_decision))steps.push('ম্যানেজারের সিদ্ধান্ত');
  if(item.communication_required&&!item.communicated_at)steps.push('সংশ্লিষ্ট পক্ষকে জানান');
  if(item.execution_required&&!item.executed_at&&!(item.approval_required&&item.manager_decision==='rejected'))steps.push('অফিসীয় কাজ');
  if(item.verification_required&&!item.verified_at)steps.push('যাচাই');
  return steps;
 }
 function canComplete(item){return !CLOSED.has(item.stage)&&outstanding(item).length===0;}
 function active(item,now=Date.now()){
  // Universal Action Center is persistent even when ACK or snoozed. Only pushes may be delayed.
  return !CLOSED.has(item.stage);
 }
 function group(item,now=Date.now()){
  if(CLOSED.has(item.stage))return 'resolved';
  if(isManagerPending(item))return 'manager';
  if(item.stage==='waiting_external')return 'external';
  if(item.captured_after_hours)return 'night';
  if(item.execution_required&&!officeTime(now))return 'office';
  return 'action';
 }
 function rank(item,now=Date.now()){
  const impact={critical:0,urgent:1,important:2,routine:3}[item.priority]??2;
  const risk=dueRisk(item,now);
  return (risk.label==='overdue'?0:risk.label==='before_office_risk'?1:risk.label==='due_soon'?2:3)*10+impact;
 }
 return {dhakaParts,officeTime,nextOfficeCandidate,dueRisk,isManagerPending,outstanding,canComplete,active,group,rank};
});