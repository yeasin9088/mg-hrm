/* Pure exit calculation/validation rules. No network, UI, or persisted employee data. */
(function(root){
 'use strict';
 const reasons=Object.freeze({salary_paid:'Salary already withdrawn',insufficient_salary:'Insufficient salary balance',no_salary_due:'No salary payable',salary_held:'Entire salary held by institution',release_pending:'Held salary not released',payroll_pending:'Final salary calculation pending',special_waiver:'Waived by authorized recommendation',decision_pending:'Authority decision pending',disputed:'Deduction disputed',other:'Other (notes required)'});
 const outcomes=Object.freeze({collected:'Full deduction',partial:'Partial deduction',pending:'No deduction — reason required',waived:'Approved waiver — authorized decision',not_applicable:'Not applicable'});
 function date(value){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value||'')) throw Error('A valid YYYY-MM-DD date is required.');
  const d=new Date(value+'T00:00:00Z');
  if(!Number.isFinite(d.getTime())||d.toISOString().slice(0,10)!==value) throw Error('Invalid calendar date.');
  return d;
 }
 function anniversary(value,years=1){
  const d=date(value),y=d.getUTCFullYear()+years,m=d.getUTCMonth();
  return new Date(Date.UTC(y,m,Math.min(d.getUTCDate(),new Date(Date.UTC(y,m+1,0)).getUTCDate()))).toISOString().slice(0,10);
 }
 function tenure(join,exit){
  const a=date(join),b=date(exit);
  if(b<a) throw Error('Exit date cannot be before joining date.');
  let years=b.getUTCFullYear()-a.getUTCFullYear();
  if(exit<anniversary(join,years)) years--;
  return {days:Math.round((b-a)/86400000),years,firstAnniversary:anniversary(join),defaultEnabled:exit<anniversary(join)};
 }
 function money(v,label){
  const str=String(v??'').trim();
  if(!/^\d+(\.\d{1,2})?$/.test(str)||Number(str)>100000000) throw Error(label+' must be a nonnegative amount with at most two decimals.');
  return Number(str);
 }
 const cents=n=>Math.round(Number(n)*100);
 function balances(s){
  if(!s) return null;
  return {outstanding:s.outcome==='waived'?0:(cents(s.expected)-cents(s.deducted))/100,depositPending:(cents(s.deducted)-cents(s.deposited))/100};
 }
 function validate(input,join,exit,today){
  const t=tenure(join,exit);date(today);
  if(exit>today) throw Error('A future exit cannot mark an employee inactive.');
  const s={...input,enabled:!!input.enabled};
  for(const k of ['override_reason','reason','receipt_no','deposited_to','approved_by','notes']) s[k]=String(s[k]||'').trim();
  if(t.defaultEnabled&&!s.enabled) throw Error('Deduction decision is mandatory before the first service anniversary. Select No deduction or Approved waiver if no money is collected.');
  if(s.enabled&&!t.defaultEnabled&&!s.override_reason) throw Error('Explain why deduction tracking is manually enabled.');
  if(!s.enabled) return {...s,expected:0,deducted:0,deposited:0,outcome:'not_applicable',reason:'',deducted_on:'',deposited_on:'',receipt_no:'',deposited_to:'',approved_by:'',follow_up_on:''};
  s.expected=money(s.expected,'Expected deduction');s.deducted=money(s.deducted,'Deducted');s.deposited=money(s.deposited,'Deposited');
  if(s.expected<=0||s.deducted>s.expected||s.deposited>s.deducted) throw Error('Expected must be positive; deposited ≤ deducted ≤ expected.');
  if(s.expected!==3000&&!s.notes) throw Error('Explain the adjusted expected amount in notes.');
  if(!outcomes[s.outcome]||s.outcome==='not_applicable') throw Error('Select a deduction decision.');
  if(s.outcome==='collected'&&s.deducted!==s.expected||s.outcome==='partial'&&!(s.deducted>0&&s.deducted<s.expected)||['pending','waived'].includes(s.outcome)&&s.deducted!==0) throw Error('Outcome does not match the deducted amount.');
  if(s.deducted<s.expected&&!reasons[s.reason]) throw Error('Select a reason for missing or partial deduction.');
  if(s.reason==='other'&&!s.notes) throw Error('Other reason requires notes.');
  if(s.outcome==='waived'&&(!s.approved_by||!s.notes||s.reason!=='special_waiver')) throw Error('Waiver requires special waiver reason, authority and decision notes.');
  if(s.outcome!=='waived'&&s.reason==='special_waiver') throw Error('Select approved waiver for this reason.');
  if(s.outcome==='collected')s.reason='';
  if(s.outcome==='waived'||(s.deducted===s.expected&&s.deposited===s.deducted))s.follow_up_on='';
  if(s.deducted>0){date(s.deducted_on);if(s.deducted_on>today)throw Error('Deduction date cannot be in the future.');}else s.deducted_on='';
  if(s.deposited>0){
   date(s.deposited_on);
   if(!s.receipt_no||!s.deposited_to)throw Error('Deposit receipt and recipient are required.');
   if(s.deposited_on>today||s.deposited_on<s.deducted_on)throw Error('Check deposit date.');
  }else Object.assign(s,{deposited_on:'',receipt_no:'',deposited_to:''});
  if(s.follow_up_on){date(s.follow_up_on);if(!/^([01][0-9]|2[0-3]):[0-5][0-9](?::00)?$/.test(s.follow_up_time||'09:00'))throw Error('Choose a valid reminder time.');}
  s.follow_up_time=s.follow_up_time||'09:00';
  return s;
 }
 const api=Object.freeze({reasons,outcomes,date,anniversary,tenure,money,balances,validate});
 root.ExitModel=api;if(typeof module==='object'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
