const {test}=require('node:test');const assert=require('node:assert/strict');
const M=require('../exit-model.js');
const pending={enabled:true,expected:3000,deducted:0,deposited:0,outcome:'pending',reason:'salary_held',follow_up_on:'2026-10-25'};
const check=(s,join='2026-01-01',exit='2026-10-23')=>M.validate({...pending,...s},join,exit,'2026-10-23');
test('anniversary boundary, backdated exit and leap day use calendar years',()=>{
 assert.equal(M.tenure('2025-10-24','2026-10-23').defaultEnabled,true);
 assert.equal(M.tenure('2025-10-23','2026-10-23').defaultEnabled,false);
 assert.equal(M.tenure('2024-02-29','2025-02-28').defaultEnabled,false);
 assert.equal(M.tenure('2024-03-01','2025-02-28').defaultEnabled,true);
 assert.equal(M.tenure('2026-10-23','2026-10-23').days,0);
 assert.throws(()=>M.tenure('2026-02-30','2026-10-23'));
 assert.throws(()=>M.tenure('2026-10-24','2026-10-23'));
});
test('manual override must be explicit, disabled amounts are normalized to zero',()=>{
 assert.throws(()=>check({enabled:false}),/override/);
 assert.equal(check({enabled:false,override_reason:'Approved exception'}).expected,0);
 assert.throws(()=>check({},'2025-01-01'),/override/);
 assert.equal(check({override_reason:'Authority instruction'},'2025-01-01').expected,3000);
});
test('money and outcome validation reject negative, nonfinite, rounding and inconsistent values',()=>{
 for(const deducted of [-1,NaN,Infinity,'0.001','1e3',3001])assert.throws(()=>check({deducted}));
 assert.throws(()=>check({deducted:1000,outcome:'collected'}));
 assert.throws(()=>check({deposited:1000}));
 assert.throws(()=>check({reason:''}));
 assert.throws(()=>check({reason:'other'}));
 assert.throws(()=>check({expected:2500}));
});
test('partial deduction tracks outstanding and deposit independently with exact cents',()=>{
 const s=check({deducted:1000.1,deposited:500.05,outcome:'partial',deducted_on:'2026-10-22',deposited_on:'2026-10-23',receipt_no:'R-1',deposited_to:'Accounts'});
 assert.deepEqual(M.balances(s),{outstanding:1999.9,depositPending:500.05});
});
test('waiver requires authority and decision evidence and creates no false outstanding',()=>{
 assert.throws(()=>check({outcome:'waived',reason:'special_waiver'}));
 const s=check({outcome:'waived',reason:'special_waiver',approved_by:'Manager',notes:'Decision recorded'});
 assert.deepEqual(M.balances(s),{outstanding:0,depositPending:0});
 assert.equal(M.balances(null),null);
});
test('real deductions and deposits require evidence and chronological dates',()=>{
 const s={outcome:'collected',deducted:3000,deposited:3000,deducted_on:'2026-10-22',deposited_on:'2026-10-23',receipt_no:'R-1',deposited_to:'Accounts'};
 assert.equal(check(s).deposited,3000);
 for(const field of ['deducted_on','deposited_on','receipt_no','deposited_to'])assert.throws(()=>check({...s,[field]:''}));
 assert.throws(()=>check({...s,deposited_on:'2026-10-21'}));
 assert.throws(()=>check({...s,deposited_on:'2026-10-24'}));
 assert.throws(()=>M.validate(pending,'2026-01-01','2026-10-24','2026-10-23'));
});
