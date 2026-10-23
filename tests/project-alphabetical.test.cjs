const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const begin=html.indexOf('function projectNameAZ(');
const end=html.indexOf('\n\nconst DESIG_RANK',begin);
assert(begin>=0&&end>begin,'project alphabetical helper exists');
const {projectNameAZ,projectNamesAZ,usageSortedProjects}=new Function(html.slice(begin,end)+'\nreturn {projectNameAZ,projectNamesAZ,usageSortedProjects};')();

test('projects sort A–Z irrespective of capitalization or staff popularity',()=>{
  const names=['Zenith','beta','Alpha','M/S Shoinik','apex','Biswas','zebra'];
  const original=names.slice();
  const sorted=usageSortedProjects(names,{Zenith:999,'M/S Shoinik':600});
  assert.deepEqual(sorted,['Alpha','apex','beta','Biswas','M/S Shoinik','zebra','Zenith']);
  assert.deepEqual(names,original,'source and stored project order must not change');
  assert.deepEqual(projectNamesAZ(names),sorted);
});
test('project names support numeric suffixes and do not modify identifiers',()=>{
  const names=['Unit 10','Unit 2','unit 1'];
  assert.deepEqual(projectNamesAZ(names),['unit 1','Unit 2','Unit 10']);
  const objects=[{id:45,ProjectName:'Zebra'},{id:12,ProjectName:'Alpha'}];
  const selected=45;
  const sorted=objects.slice().sort((a,b)=>projectNameAZ(a.ProjectName,b.ProjectName));
  assert.deepEqual(sorted.map(p=>p.id),[12,45]);
  assert.equal(sorted.find(p=>p.id===selected).ProjectName,'Zebra');
  assert.equal(objects[0].id,45);
});
test('employee, transfer, reactivation, reports, To-Do and uniform pickers use A–Z',()=>{
  for(const marker of [
    'projectNamesAZ(projectChoices).map(',
    'function usageSortedProjects(values, counts){ return projectNamesAZ(values); }',
    'DATA.projects.slice().sort((a,b)=>projectNameAZ(a.ProjectName,b.ProjectName)).map(',
    'const activeProjs = activeProjects().sort((a,b)=>projectNameAZ(',
    "return Array.from(set).sort(projectNameAZ);",
    "(DATA.projects||[]).slice().sort((a,b)=>projectNameAZ(",
    "sort((a,b)=>projectNameAZ(projectName(a),projectName(b)))",
    "sort(function(a, b){ return projectNameAZ(a && a.ProjectName,b && b.ProjectName); })"
  ])assert(html.includes(marker), 'missing alphabetical picker: '+marker);
});
