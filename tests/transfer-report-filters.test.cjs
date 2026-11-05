const test=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('index.html','utf8');
function fn(name){const start=source.indexOf(`function ${name}(`);assert(start>=0);return source.slice(start,source.indexOf('\nfunction ',start+1));}
function fixture(){
 const elements={reportDateMode:{value:'month'},reportMonth:{value:'2026-11'},reportProject:{value:'Other'},reportProjectScope:{value:'all'},reportOutput:{},transferReportFilters:{}};
 const selections={from:[],to:[]};
 const c={DATA:{projects:[],employees:[],transfers:[],exits:[],disciplinary:[]},document:{getElementById:id=>elements[id]||null,querySelectorAll:selector=>selector.includes('checkbox')?(selections[selector.includes('-from')?'from':'to'].map(value=>({value}))):[]},projectVisibilityData:x=>x,projectRecordVisible:()=>true,parseDate:v=>v?new Date(v+'T00:00:00'):null,todayISO:()=> '2026-11-05',escapeHtml:v=>String(v??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;'),num:x=>x,fmtDate:x=>x,projName:x=>x,ico:()=>'',ExitReports:{clear:()=>{}},openPrint:html=>{c.printed=html},mrepShell2:x=>[x.subtitle,x.meta,x.body].join('\n'),toast:()=>{},Blob,URL:{createObjectURL:blob=>{c.exported=blob;return 'blob:test'},revokeObjectURL:()=>{}}};
 c.document.createElement=()=>({click:()=>{}});c.window=c;vm.createContext(c);
 vm.runInContext(['transferScheduledDate','selectedTransferReportProjects','transferReportMatches','transferReportFilterSummary','getReportFilterContext','reportInRange','reportMatches','getMonthlyReportRows','showReport','printReport','exportReport'].map(fn).join('\n')+"\nlet currentReport='transfers';",c);
 return {c,elements,selections,ids:()=>Array.from(c.getMonthlyReportRows('transfers').rows,r=>r.id)};
}
function records(){return [
 {id:1,CurrentProject:'বিশ্বাস ১',NewProject:'Other',effective_date:'2026-11-02',TransferDate:'2026-10-01',FullName:'One',Status:'Completed'},
 {id:2,CurrentProject:'বিশ্বাস ২',NewProject:'Other',effective_date:'2026-11-03',FullName:'Two',Status:'Scheduled'},
 {id:3,current_project:'Other',new_project:'বিশ্বাস ১',effective_date:'2026-11-04',full_name:'Three',status:'Completed'},
 {id:4,CurrentProject:'বিশ্বাস ১',NewProject:'বিশ্বাস ২',effective_date:'2026-11-05',FullName:'Four',Status:'Completed'},
 {id:5,CurrentProject:'বিশ্বাস ১',NewProject:'Other',effective_date:'2026-12-01',FullName:'Five'},
 {id:6,CurrentProject:'বিশ্বাস ১০',NewProject:'Other',effective_date:'2026-11-06',FullName:'Six'}];}
test('multiple From and To projects: OR within each side, AND between sides, exact names and month boundaries',()=>{
 const f=fixture();f.c.DATA.transfers=records();assert.deepEqual(f.ids(),[1,2,3,4,6]);
 f.selections.from=['বিশ্বাস ১','বিশ্বাস ২'];assert.deepEqual(f.ids(),[1,2,4]);
 f.selections.from=[];f.selections.to=['বিশ্বাস ১','বিশ্বাস ২'];assert.deepEqual(f.ids(),[3,4]);
 f.selections.from=['বিশ্বাস ১'];assert.deepEqual(f.ids(),[4]);
 f.selections.to=['Missing'];assert.deepEqual(f.ids(),[]);
});
test('screen, print and CSV share selection, scheduled dates and statuses, with filter names on print',async()=>{
 const f=fixture();f.c.DATA.transfers=records();f.selections.from=['বিশ্বাস ১','বিশ্বাস ২'];f.selections.to=['Other'];
 f.c.showReport('transfers');assert.equal(f.elements.reportProject.hidden,true);assert.equal(f.elements.transferReportFilters.hidden,false);
 assert.match(f.elements.reportOutput.innerHTML,/One/);assert.doesNotMatch(f.elements.reportOutput.innerHTML,/Three/);
 f.c.printReport();assert.match(f.c.printed,/From: বিশ্বাস ১, বিশ্বাস ২ · To: Other/);assert.match(f.c.printed,/2026-11-02/);assert.match(f.c.printed,/Scheduled/);assert.doesNotMatch(f.c.printed,/2026-10-01|Three/);
 f.c.exportReport('transfers');const csv=await f.c.exported.text();assert.match(csv,/One/);assert.match(csv,/2026-11-02/);assert.doesNotMatch(csv,/Three|2026-10-01/);
});
test('transfer selections never constrain other reports and previous shared project choice is restored',()=>{
 const f=fixture();f.c.DATA.transfers=records();f.selections.from=['Missing'];f.c.DATA.employees=[{ProjectName:'Other',JoinDate:'2026-11-02',FullName:'Employee'}];f.c.desig=x=>x;
 f.c.showReport('newJoins');assert.equal(f.elements.reportProject.hidden,false);assert.equal(f.elements.transferReportFilters.hidden,true);assert.equal(f.c.getMonthlyReportRows('newJoins').rows.length,1);assert.equal(f.c.getReportFilterContext().fromProjects.length,0);assert.equal(f.elements.reportProject.value,'Other');
});
test('picker search selects only visible results, Clear removes hidden selections too',()=>{
 const f=fixture();const rows=['বিশ্বাস ১','বিশ্বাস ২','Other'].map(textContent=>({textContent,hidden:false,input:{checked:false},querySelector(){return this.input}}));
 f.c.document.querySelectorAll=()=>rows;
 vm.runInContext(['searchTransferReportProjects','selectTransferReportProjects'].map(fn).join('\n'),f.c);f.c.updateTransferReportProjects=()=>{};
 f.c.searchTransferReportProjects('from','বিশ্বাস');f.c.selectTransferReportProjects('from',true);assert.deepEqual(rows.map(r=>r.input.checked),[true,true,false]);
 f.c.searchTransferReportProjects('from','Other');f.c.selectTransferReportProjects('from',false);assert(rows.every(r=>!r.input.checked));
});
