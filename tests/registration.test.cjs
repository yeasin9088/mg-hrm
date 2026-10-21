const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const core=fs.readFileSync('app-core.js','utf8');
const html=fs.readFileSync('index.html','utf8');
const ddl=fs.readFileSync('supabase/schema-baseline/04-constraints.sql','utf8');
const statusDDL=ddl.split('\n').find(s=>s.includes('"employees_status_check"'));
const statuses=[...statusDDL.matchAll(/'([^']+)'::text/g)].map(m=>m[1]);
const segment=(start,end)=>{const a=html.indexOf(start),b=html.indexOf(end,a);assert(a>=0&&b>a);return html.slice(a,b);};
const clone=x=>JSON.parse(JSON.stringify(x));

async function setup({records=[],fail=null,zero=false,gate=null}={}){
  const db=clone(records),calls=[],messages=[],nodes={},events={};
  let serial=100;
  const state={db,calls,messages,nodes,events,focused:null,activeTab:'naBasic',closed:false};
  const client={from(table){
    const q={table,action:'read',filters:[],singleRow:false,
      insert(rows){this.action='insert';this.payload=rows[0];return this;},
      update(row){this.action='update';this.payload=row;return this;},
      select(cols='*'){this.columns=cols;return this;},
      eq(k,v){this.filters.push([k,v]);return this;},
      or(filters){this.orFilter=filters;return this;},
      single(){this.singleRow=true;return this;},
      then(resolve,reject){return (async()=>{
        calls.push({table,action:this.action,payload:this.payload&&clone(this.payload),filters:clone(this.filters)});
        if(gate&&this.action==='insert')await gate;
        if(fail&&this.action!=='read')return {data:null,error:fail};
        if(this.action==='read'){
          let rows=db.filter(r=>this.filters.every(([k,v])=>String(r[k])===String(v)));
          if(this.orFilter)rows=rows.filter(r=>this.orFilter.split(',').some(f=>{const [k,,...v]=f.split('.');return String(r[k])===v.join('.');}));
          return {data:clone(this.singleRow?rows[0]||null:rows),error:null};
        }
        if(zero)return {data:[],error:null};
        if(this.payload.status&&!statuses.includes(this.payload.status))return {data:null,error:{code:'23514',message:'employees_status_check'}};
        if(this.action==='insert'){const row={...clone(this.payload),id:serial++};db.push(row);return {data:[clone(row)],error:null};}
        const rows=db.filter(r=>this.filters.every(([k,v])=>String(r[k])===String(v)));
        rows.forEach(r=>Object.assign(r,clone(this.payload)));
        return {data:clone(rows),error:null};
      })().then(resolve,reject);}
    };return q;
  }};
  const sandbox={console:{error(){},warn(){},log(){}},Date,Intl,Number,Set,Map,JSON,Promise,
    setTimeout,clearTimeout,fetch(){throw Error('NETWORK FORBIDDEN');},
    localStorage:{getItem(){return null;}},
    supabase:{createClient(){return client;}},
    DATA:{employees:[],exits:[]},RECRUITMENT:[],
    document:{
      getElementById(id){return nodes[id]||null;},
      querySelectorAll(){return Object.values(nodes).filter(n=>n.tagName==='INPUT'||n.tagName==='BUTTON');},
      addEventListener(name,fn){events[name]=fn;}
    }
  };
  sandbox.window=sandbox;
  const ctx=vm.createContext(sandbox);
  vm.runInContext(core,ctx);
  await ctx.MGHRM.connect({url:'https://synthetic.invalid',anonKey:'synthetic-test-key'});
  Object.assign(ctx,{
    toast:(m,type)=>messages.push({m,type}),guardEdit:()=>true,
    normalizeDateOnly:x=>x||'',todayISO:()=>new Date().toISOString().slice(0,10),
    findEmp:id=>ctx.DATA.employees.find(e=>String(e.id)===String(id)||(e.EmployeeID&&String(e.EmployeeID)===String(id))),
    renderEmpTable(){},renderPendingRecruitment(){},renderRecruitment(){},syncRecruitmentFromEmployees(){},
    confirmSensitiveJoinDateChange:async()=>true,
    switchTab:(_,tab)=>{state.activeTab=tab;},
    naRefreshPrimary(){},
    closeModal(){state.closed=true;},
    resetApplicantForm(){state.reset=true;},
    salaryFor:()=>12800,
    employeeGeoBangla:()=>'',composeBanglaAddress:()=>''
  });
  function node(id,value='',tagName='INPUT'){
    const panel={id:'tab-'+({ec1m:'naEc',ec2m:'naEc',rfm:'naRef',gross:'naJob',joinDate:'naJob',dutyHours:'naJob'}[id.replace('na_','')]||'naBasic')};
    return nodes[id]={id,value,tagName,disabled:false,isConnected:true,innerHTML:'Save',style:{},
      focus(){state.focused=id;},closest(){return panel;},
      click(){if(!ctx.__naSaving)state.activeTab=id.replace('natab-','');}
    };
  }
  const values={nameEn:'Synthetic Applicant',name:'পরীক্ষামূলক আবেদনকারী',phone:'+880 1700-000001',phoneBn:'',
    nid:'১২৩৪ ৫৬৭৮৯০',nidBn:'',dob:'2000-02-29',weight:'60',joinDate:'',
    education:'SSC',religion:'Islam',height:'5 ft 6',maritalStatus:'Unmarried',desig:'',project:'',
    gross:'',dutyHours:'12',editKey:''};
  for(const [key,value]of Object.entries(values))node('na_'+key,value);
  for(const id of ['naPrimaryBtn','btnSaveBasicInfo','btnSaveJobComplete','btnSaveEmergency','btnSaveReferences'])node(id,'','BUTTON');
  for(const id of ['naAddr','naEc','naRef','naJob'])node('natab-'+id);
  for(const id of ['ec1n','ec1r','ec1m','ec2n','ec2r','ec2m','rfn','rfd','rfo','rfm'])node('na_'+id);
  vm.runInContext(segment('function normEmployee(row) {','window.normEmployee = normEmployee;'),ctx);
  vm.runInContext(segment('function cleanEmployeePayload(payload) {','window.cleanEmployeePayload = cleanEmployeePayload;'),ctx);
  vm.runInContext(segment('function naRegistrationError(err){','function resetApplicantForm(){'),ctx);
  // Keep the actual section save logic, while the harness controls only UI rendering.
  vm.runInContext(segment('async function saveAddressAndContinue(){','const NA_TAB_ORDER ='),ctx);
  ctx.confirmSensitiveJoinDateChange=async()=>true;
  ctx.DATA.employees=db.map(r=>ctx.normEmployee(r));
  ctx.__naIsNewRegistration=records.length===0;
  ctx.__naSavedSections={naBasic:!!records.length,naAddr:!!records.length,naEc:!!records.length,naRef:!!records.length};
  if(records.length){ctx.currentRecruitId=records[0].id;ctx.currentEditEmployeeId=records[0].id;nodes.na_editKey.value=String(records[0].id);}
  return Object.assign(state,{ctx,client,node});
}
function writes(h){return h.calls.filter(c=>c.action!=='read');}
function validPersonal(overrides={}){return {nameEn:'Synthetic Person',name:'পরীক্ষার্থী',nid:'1234567890',phone:'01700000001',dob:'2000-02-29',...overrides};}

test('deployed constraint has only employment states; candidate serializes to Inactive with metadata',async()=>{
  assert.deepEqual(statuses,['Active','Inactive']);
  const {ctx}=await setup();const R=ctx.MGHRM.registration;
  const p=R.writePayload({status:'Candidate',remarks:'{"stage":"DataEntry","reference":{"name":"Synthetic"}}'});
  assert.equal(p.status,'Inactive');assert.equal(R.displayStatus(p.status,p.remarks),'Candidate');
  assert.equal(JSON.parse(p.remarks).reference.name,'Synthetic');
  assert.equal(R.displayStatus('Inactive','{"stage":"DataEntry"}'),'Inactive');
  assert.equal(R.displayStatus('Inactive',p.remarks,'2020-01-01'),'Inactive');
  assert.equal(R.displayStatus('Active',p.remarks),'Active');
  assert.equal(ctx.MGHRM.toDb('employees',{Status:'Candidate',Remarks:'{"stage":"Signed"}'}).status,'Inactive');
  assert.equal(ctx.MGHRM.fromDb('employees',{id:1,status:'Inactive',remarks:p.remarks}).Status,'Candidate');
});
test('Bangla digits, formatted NID/mobile, exact dates, optional inputs and invalid values',async()=>{
  const {ctx}=await setup();const R=ctx.MGHRM.registration;
  const x=R.personal(validPersonal({nid:'১২৩৪-৫৬৭৮৯০',phone:'+৮৮০ (১৭০০) ০০০০০১'}),true);
  assert.equal(x.nid,'1234567890');assert.equal(x.phone,'01700000001');
  for(const nid of ['1234567890123','12345678901234567'])assert.equal(R.personal(validPersonal({nid}),true).nid,nid);
  for(const input of [{nid:'123x4567890'},{nid:'123'},{phone:'01200000000'},{phone:'01700000001ext'},{name:''},{nameEn:''},{dob:'2025-02-29'},{dob:'2099-01-01'},{weight:'-1'},{phoneBn:'01800000002'}]){
    assert.throws(()=>R.personal(validPersonal(input),true));
  }
  assert.equal(R.optionalMobile('','ec1m'),'');assert.equal(R.date('2024-02-29'),'2024-02-29');
  assert.equal(R.date('2024-02-30'),null);assert.equal(R.mobile('008801700000001'),'01700000001');
  assert.throws(()=>R.optionalMobile('abc','rfm'));
});
test('registration saves one real returned ID; pending survives reload and blank joining date is not invented',async()=>{
  const h=await setup();await h.ctx.saveBasicInfoAndContinue();
  assert.equal(writes(h).length,1);assert.equal(h.db.length,1);
  assert.equal(h.db[0].status,'Inactive');assert.equal(h.db[0].nid,'1234567890');
  assert.equal(h.db[0].phone,'01700000001');assert.equal(h.db[0].join_date,null);
  assert.equal(h.ctx.currentRecruitId,100);assert.equal(h.ctx.DATA.employees[0].Status,'Candidate');
  assert.equal(h.ctx.normEmployee(h.db[0]).Status,'Candidate');assert.equal(h.activeTab,'naAddr');
  assert.equal(h.ctx.__naSaving,false);assert(h.messages.some(m=>m.type==='success'));
  assert.equal(h.db[0].employee_id,''); // official numbering unchanged; system id is server-owned
});
test('rapid second submission produces exactly one insert',async()=>{
  let release;const gate=new Promise(r=>release=r);const h=await setup({gate});
  const first=h.ctx.saveBasicInfoAndContinue();await Promise.resolve();await Promise.resolve();
  await h.ctx.saveBasicInfoAndContinue();release();await first;
  assert.equal(writes(h).length,1);assert.equal(h.db.length,1);
});
test('failed or empty saves preserve fields and do not invent IDs/success/advance',async()=>{
  for(const mode of [{fail:{code:'42501',message:'denied'}},{zero:true}]){
    const h=await setup(mode);const before=h.nodes.na_nameEn.value;
    await h.ctx.saveBasicInfoAndContinue();
    assert.equal(h.nodes.na_nameEn.value,before);assert.equal(h.ctx.currentRecruitId,null);
    assert.equal(h.ctx.DATA.employees.length,0);assert.equal(h.activeTab,'naBasic');
    assert(!h.messages.some(m=>m.type==='success'));assert.equal(h.ctx.__naSaving,false);
    assert.equal(h.nodes.naPrimaryBtn.disabled,false);
  }
});
test('invalid required fields cause zero writes and focus the relevant tab/field',async()=>{
  const h=await setup();h.nodes.na_nid.value='bad';await h.ctx.saveBasicInfoAndContinue();
  assert.equal(writes(h).length,0);assert.equal(h.focused,'na_nid');
});
test('matching name/mobile alone is allowed; normalized NID duplicate is blocked; self edits excluded',async()=>{
  const h=await setup();h.db.push({id:3,nid:'9876543210',phone:'01700000001',full_name:'Synthetic Applicant'});
  await h.ctx.saveBasicInfoAndContinue();assert.equal(writes(h).length,1);
  const duplicate=await setup();duplicate.db.push({id:3,nid:'1234567890'});
  await duplicate.ctx.saveBasicInfoAndContinue();assert.equal(writes(duplicate).length,0);
  const self=await setup({records:[{id:4,full_name:'Synthetic Applicant',full_name_bn:'পরীক্ষার্থী',phone:'01700000001',nid:'1234567890',status:'Active',join_date:'2020-01-01',employee_id:'MG-001'}]});
  self.nodes.na_joinDate.value='2020-01-01';await self.ctx.saveBasicInfoAndContinue();
  assert.equal(writes(self).length,1);assert.equal(self.db[0].status,'Active');assert.equal(self.db[0].employee_id,'MG-001');
  assert(!Object.hasOwn(writes(self)[0].payload,'status'));
  assert(!Object.hasOwn(writes(self)[0].payload,'project_name'));
});
test('section failures never strip joining/address fields and retry a partial save',async()=>{
  const h=await setup({fail:{code:'42804',message:'trigger failed'}});
  await assert.rejects(h.ctx.executeRecruitUpdate({join_date:'2020-01-01',present_address_details:'Synthetic address'},5));
  assert.equal(writes(h).length,1);assert.equal(writes(h)[0].payload.join_date,'2020-01-01');
  const empty=await setup({zero:true});await assert.rejects(empty.ctx.executeRecruitUpdate({ec_name:'Synthetic'},5));
});
test('completion requires prior tab saves, valid pay/date/hours and retains form on failure',async()=>{
  const h=await setup();await h.ctx.saveBasicInfoAndContinue();
  h.nodes.na_joinDate.value='2020-01-01';h.nodes.na_desig.value='Security Guard';h.nodes.na_project.value='Synthetic Project';h.nodes.na_gross.value='12800';
  await h.ctx.saveJobAndComplete();assert.equal(writes(h).length,1);assert.equal(h.closed,false);
  h.ctx.__naSavedSections={naBasic:true,naAddr:true,naEc:true,naRef:true};
  for(const gross of ['-1','Infinity','not-a-number']){
    h.nodes.na_gross.value=gross;await h.ctx.saveJobAndComplete();assert.equal(writes(h).length,1);
  }
  h.nodes.na_gross.value='12800';h.nodes.na_dutyHours.value='25';await h.ctx.saveJobAndComplete();assert.equal(writes(h).length,1);
  h.nodes.na_dutyHours.value='12';await h.ctx.saveJobAndComplete();
  assert.equal(writes(h).length,2);assert.equal(h.db[0].status,'Inactive');assert.equal(h.db[0].join_date,'2020-01-01');
  assert.equal(h.db[0].project_name,'Synthetic Project');assert.equal(h.closed,true);
});
test('active profile project cannot move through registration instead of joining confirmation',async()=>{
  const h=await setup({records:[{id:4,status:'Active',project_name:'Synthetic Source',join_date:'2020-01-01',remarks:'{}'}]});
  await assert.rejects(h.ctx.executeRecruitUpdate({project_name:'Synthetic Destination'},4));
  assert.equal(writes(h).length,0);
});
test('candidate decisions use allowed states, keep remarks and require returned saved rows',async()=>{
  const h=await setup({records:[{id:4,status:'Inactive',remarks:'{"registrationPending":true,"reference":{"name":"Synthetic"}}'}]});
  const rows=await h.ctx.MGHRM.rejectCandidate(4);
  assert.equal(rows[0].status,'Inactive');assert.equal(h.ctx.normEmployee(rows[0]).Status,'Application Rejected');
  assert.equal(JSON.parse(rows[0].remarks).reference.name,'Synthetic');
  const approved=await setup({records:[{id:5,status:'Inactive',remarks:'{"registrationPending":true,"joinDate":"2020-01-01"}',join_date:'2020-01-01'}]});
  await approved.ctx.MGHRM.approveCandidate(5);
  assert.equal(approved.db[0].status,'Active');assert.equal(approved.db[0].join_date,'2020-01-01');
  assert.equal(JSON.parse(approved.db[0].remarks).registrationPending,false);
});
test('all five existing tabs save against one employee ID and retain print/reference/contact data',async()=>{
  const h=await setup();await h.ctx.saveBasicInfoAndContinue();
  await h.ctx.saveAddressAndContinue();
  h.nodes.na_ec1n.value='Synthetic Guardian';h.nodes.na_ec1m.value='+8801700000002';
  await h.ctx.saveEmergencyAndContinue();
  h.nodes.na_rfn.value='Synthetic Reference';h.nodes.na_rfm.value='০১৭০০০০০০০৩';
  await h.ctx.saveReferencesAndContinue();
  h.nodes.na_joinDate.value='2020-01-01';h.nodes.na_desig.value='Security Guard';
  h.nodes.na_project.value='Synthetic Project';h.nodes.na_gross.value='12800';
  await h.ctx.saveJobAndComplete();
  assert.equal(h.db.length,1);assert.equal(writes(h).filter(x=>x.action==='insert').length,1);
  assert.equal(writes(h).filter(x=>x.action==='update').length,4);
  assert.equal(h.db[0].ec_phone,'01700000002');
  const remarks=JSON.parse(h.db[0].remarks);
  assert.equal(remarks.reference.mobile,'01700000003');
  assert.equal(remarks.registrationPending,true);assert.equal(remarks.stage,'DataEntry');
  const printable=h.ctx.MGHRM.getCandidateRecord(100);
  assert.equal(printable.id,100);assert.equal(printable.nameEn,'Synthetic Applicant');
  assert.equal(printable.reference.name,'Synthetic Reference');assert.equal(printable.joinDate,'2020-01-01');
});
test('optional contact validation fails before writes and invalid stored outcomes are rejected',async()=>{
  const h=await setup();await h.ctx.saveBasicInfoAndContinue();const count=writes(h).length;
  h.nodes.na_ec1m.value='123';await h.ctx.saveEmergencyAndContinue();
  assert.equal(writes(h).length,count);assert.equal(h.focused,'na_ec1m');
  h.nodes.na_rfm.value='not a phone';await h.ctx.saveReferencesAndContinue();
  assert.equal(writes(h).length,count);assert.equal(h.focused,'na_rfm');
  assert.throws(()=>h.ctx.MGHRM.registration.savedRow([{id:100,join_date:'2000-01-01'}],{join_date:'2000-02-02'}));
  assert.throws(()=>h.ctx.MGHRM.registration.savedRow([{id:1},{id:2}],{}));
});
test('direct data-layer registration and section APIs use valid statuses and reject zero-row updates',async()=>{
  const h=await setup();
  await h.ctx.MGHRM.saveRecruitBasicInfo({full_name:' Synthetic Person ',full_name_bn:'পরীক্ষার্থী',phone:'+8801700000001',nid:'১২৩৪৫৬৭৮৯০'});
  assert.equal(h.db[0].status,'Inactive');assert.equal(h.db[0].full_name,'Synthetic Person');
  assert.equal(h.db[0].nid,'1234567890');
  await assert.rejects(h.ctx.MGHRM.updateRecruitSection({join_date:'2020-01-01'},999));
  assert.equal(h.ctx.MGHRM.toDb('employees',{Status:'Exited'}).status,'Exited');
  const failed=await setup({fail:{code:'42804',message:'trigger'}});
  await assert.rejects(failed.ctx.MGHRM.updateRecruitSection({join_date:'2020-01-01'},4));
  assert.equal(writes(failed).length,1);
});
test('zero-row completion keeps the form open with the pending draft and original values',async()=>{
  const h=await setup({records:[{id:4,full_name:'Synthetic',full_name_bn:'পরীক্ষার্থী',phone:'01700000001',nid:'1234567890',status:'Inactive',remarks:'{"registrationPending":true}'}],zero:true});
  h.nodes.na_joinDate.value='2020-01-01';h.nodes.na_desig.value='Security Guard';
  h.nodes.na_project.value='Synthetic Project';h.nodes.na_gross.value='12800';
  await h.ctx.saveJobAndComplete();
  assert.equal(h.closed,false);assert.equal(h.nodes.na_gross.value,'12800');
  assert(!h.messages.some(m=>m.type==='success'));assert.equal(h.db[0].status,'Inactive');
});
test('permissions and cancelled joining-date confirmation prevent writes',async()=>{
  const denied=await setup();denied.ctx.guardEdit=()=>false;
  await denied.ctx.saveBasicInfoAndContinue();assert.equal(writes(denied).length,0);
  const h=await setup({records:[{id:4,status:'Active',join_date:'2020-01-01'}]});
  h.ctx.confirmSensitiveJoinDateChange=async()=>false;
  await assert.rejects(h.ctx.executeRecruitUpdate({join_date:'2020-02-01'},4));
  assert.equal(writes(h).length,0);assert.equal(h.db[0].join_date,'2020-01-01');
});
test('data-layer basic edit cannot claim success for a zero-row update',async()=>{
  const h=await setup({zero:true});
  await assert.rejects(h.ctx.MGHRM.saveRecruitBasicInfo({full_name:'Synthetic',phone:'01700000001',nid:'1234567890'},999));
});
test('unsaved programmatic changes after a Personal save cannot be reported as completed',async()=>{
  const h=await setup();
  h.nodes['tab-naBasic']={querySelectorAll:()=>[h.nodes.na_nameEn]};
  await h.ctx.saveBasicInfoAndContinue();
  h.ctx.__naSavedSections={naBasic:true,naAddr:true,naEc:true,naRef:true};
  h.nodes.na_nameEn.value='Changed but not saved';
  h.nodes.na_joinDate.value='2020-01-01';h.nodes.na_desig.value='Security Guard';
  h.nodes.na_project.value='Synthetic Project';h.nodes.na_gross.value='12800';
  await h.ctx.saveJobAndComplete();
  assert.equal(writes(h).length,1);assert.equal(h.closed,false);assert.equal(h.activeTab,'naBasic');
});
test('all inline scripts and data layer compile without loading credentials or external libraries',()=>{
  new vm.Script(core);let n=0;
  for(const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){if(/\bsrc\s*=/.test(m[1]))continue;new vm.Script(m[2]);n++;}
  assert(n >= 1);
  for (const m of html.matchAll(/<script\b[^>]*src="\.\/([^"]+)"[^>]*>/gi)) {
    if (m[1] !== 'config.js') new vm.Script(fs.readFileSync(m[1], 'utf8'));
  }
});
