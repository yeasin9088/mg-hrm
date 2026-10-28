const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const html=fs.readFileSync('index.html','utf8');
function compute(source){const c={DATA:source};c.window=c;vm.createContext(c);vm.runInContext(html.slice(html.indexOf('function isProjectActive(p)'),html.indexOf('window.isProjectActive =')),c);vm.runInContext(html.slice(html.indexOf('function computeParade('),html.indexOf('window.computeParade =')),c);return c.computeParade(source);}
module.exports={compute};
test('every active project appears once regardless of meeting inclusion or demand; closed/deleted are absent',()=>{
 const source={projects:[{id:1,project_name:'Alpha',is_active:true,meeting_attendance_enabled:false},{id:2,project_name:'Beta',status:'Active'},{id:3,project_name:'Zero',status:'Active'},{id:4,project_name:'Closed',is_active:false},{id:5,project_name:'Deleted',deleted_at:'2026-01-01'}],demand:[{project_name:'Beta',demand_guard:2},{project_name:'Zero',demand_guard:0},{project_name:'Closed',demand_guard:10}],employees:[{project_name:'Alpha',designation:'Security Guard',status:'Active'},{project_name:'Closed',designation:'Security Guard',status:'Active'},{project_name:'Alpha',designation:'Security Guard',status:'Inactive'}]};
 const rows=compute(source);assert.deepEqual(Array.from(rows,r=>r.project),['Alpha','Beta','Zero']);assert.equal(rows[0].actualTotal,1);assert.equal(rows[0].demandConfigured,false);assert.equal(rows[2].demandConfigured,true);assert.equal(rows.reduce((s,r)=>s+r.demandTotal,0),2);
});
test('project name aliases and IDs aggregate employees into one canonical row without duplicate demand',()=>{
 const rows=compute({projects:[{id:7,ProjectName:'Alpha Project',ProjectNameBangla:'আলফা'}],demand:[{ProjectName:' alpha   project ',DemandSecurityGuard:3},{project_name:'7',demand_guard:3}],employees:[{ProjectName:'আলফা',Designation:'Security Guard',Status:'Active'},{project_name:'7',designation:'Lady Guard',status:'Active'},{project_name:'ALPHA PROJECT',designation:'Security Supervisor',status:'Active',deleted_at:'2026-01-01'}]});
 assert.equal(rows.length,1);assert.equal(rows[0].actualTotal,2);assert.equal(rows[0].demandTotal,3);assert.equal(rows[0].actual.Lady,1);
});
test('assistant supervisor substitution retains existing demand total',()=>{
 const [r]=compute({projects:[{project_name:'A'}],demand:[{project_name:'A',demand_supervisor:2,demand_assst_sup:1}],employees:[{project_name:'A',designation:'Asst Security Supervisor',status:'Active'}]});assert.equal(r.demand.Supervisor,1);assert.equal(r.demand.AsstSup,2);assert.equal(r.demandTotal,3);
});
test('presentation scope excludes closed project aliases and report records without mutating stored history',()=>{
 const c={DATA:{projects:[{id:1,ProjectName:'Active',is_active:true},{id:2,ProjectName:'Closed',ProjectNameBangla:'বন্ধ',status:'Closed'}],employees:[{ProjectName:'Active'},{ProjectName:'বন্ধ'}],transfers:[{CurrentProject:'Active',NewProject:'Closed'}]}};c.window=c;vm.createContext(c);
 vm.runInContext(html.slice(html.indexOf('function isProjectNameActive('),html.indexOf('function computeParade(')),c);
 vm.runInContext(html.slice(html.indexOf('function isProjectActive(p)'),html.indexOf('/* Central resolver for Meeting Attendance Project Scope */')),c);
 const view=c.projectVisibilityData(c.DATA);assert.equal(view.projects.length,1);assert.equal(view.employees.length,1);assert.equal(view.transfers.length,0);assert.equal(c.DATA.employees.length,2);assert.equal(c.DATA.projects.length,2);assert.equal(c.isProjectNameActive('বন্ধ'),false);assert.equal(c.projectRecordVisible({current_project:'Closed'}),false);
});
