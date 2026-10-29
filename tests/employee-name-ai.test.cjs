const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('index.html', 'utf8');
const code = html.slice(html.indexOf('// Employee-name transliteration only;'), html.indexOf('async function translateField('));
function setup({source='Md. Rahman Khan', target='', rows=[['রহমান','খান'],['রাহমান','খান']], confirm=true, response, fetchError}={}){
  class Node {
    constructor(id='',value=''){this.id=id;this.value=value;this.innerHTML='✦';this.listeners={};this.children=[];this.disabled=false;this.style={};}
    addEventListener(type,fn){(this.listeners[type] ||= new Set()).add(fn);}
    removeEventListener(type,fn){this.listeners[type]?.delete(fn);}
    dispatchEvent(event){for(const fn of [...(this.listeners[event.type]||[])])fn(event);}
    appendChild(node){this.children.push(node);node.parent=this;if(node.value && !this.value)this.value=node.value;}
    setAttribute(k,v){this[k]=v;}
    closest(){return field;}
    remove(){this.parent.children=this.parent.children.filter(n=>n!==this);}
  }
  const field=new Node(), src=new Node('src',source), dst=new Node('dst',target), btn=new Node('btn');
  const nodes={src,dst}, calls=[], messages=[], timers=new Map();let timerId=0, confirms=0;
  const ctx=vm.createContext({document:{getElementById:id=>nodes[id],createElement:()=>new Node()},
    Event:class {constructor(type){this.type=type;}},AbortController,
    setTimeout(fn){timers.set(++timerId,fn);return timerId;},clearTimeout(id){timers.delete(id);},
    window:{__mgAiCfg:{key:'synthetic-test-key'},confirm(){confirms++;return confirm;}},
    toast:(...args)=>messages.push(args),
    fetch:async(url,opts)=>{calls.push({url,opts,body:JSON.parse(opts.body)});if(fetchError)throw Error('offline');return response ? response(opts) : {ok:true,json:async()=>({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(rows)}]}}]})};}
  });
  vm.runInContext(code,ctx);
  return {ctx,src,dst,btn,field,nodes,calls,messages,timers,get confirms(){return confirms;},run:(type='employee name')=>ctx.translateEmployeeFieldAI('src','dst',type,btn)};
}
const plain=x=>JSON.parse(JSON.stringify(x));
test('leading abbreviations handle case, periods and spacing without swallowing full names',()=>{
  const h=setup();
  for(const spelling of ['Md.','MD','M.D.','m . d .','m d','md']){
    const plan=h.ctx.employeeNameAIPlan(spelling+' Rahman Khan');
    assert.equal(plan.prefix,'মোঃ');assert.deepEqual(plain(plan.parts),['Rahman','Khan']);
  }
  for(const spelling of ['Mst.','MST','M.S.T.','m . s . t .','m s t'])assert.equal(h.ctx.employeeNameAIPlan(spelling+' Begum').prefix,'মোছাঃ');
  for(const spelling of ['Muhammad','Mdali','Mstara'])assert.equal(h.ctx.employeeNameAIPlan(spelling+' Khan').prefix,'');
});
test('full Muhammad preserved; punctuation, parts and order retained; duplicates collapsed',()=>{
  const h=setup(),plan=h.ctx.employeeNameAIPlan("M.D. Muhammad Ali-Khan (Jr.)");
  const names=h.ctx.employeeNameAIVariants(JSON.stringify([['মোঃ','আলী','খান','জুনিয়র'],['মুহাম্মদ','আলী','খান','জুনিয়র']]),plan,true);
  assert.deepEqual(plain(names),['মোঃ মুহাম্মদ আলী-খান (জুনিয়র.)'.normalize('NFC')]);
  assert.equal(h.ctx.employeeNameAIPlan('Ali MD').prefix,'');
  assert.deepEqual(plain(h.ctx.employeeNameAIVariants('[["আলী"]]', h.ctx.employeeNameAIPlan('MD., Ali'), true)), ['মোঃ, আলী']);
});
test('one compact request, bounded tokens, employee dropdown selects spelling and permits editing',async()=>{
  const h=setup();await h.run();assert.equal(h.calls.length,1);assert.equal(h.dst.value,'মোঃ রহমান খান');
  const cfg=h.calls[0].body.generationConfig;assert.equal(cfg.maxOutputTokens,256);assert.equal(cfg.temperature,.15);
  const prompt=h.calls[0].body.contents[0].parts[0].text;assert(prompt.length<500);assert(!prompt.includes('Md.'));
  const select=h.field.children[0];assert.equal(select.children.length,2);assert.equal(select['aria-label'],'Choose Bengali name spelling');
  select.value='মোঃ রাহমান খান';select.dispatchEvent({type:'change'});assert.equal(h.dst.value,select.value);
  h.dst.value='নিজের বানান';h.dst.dispatchEvent({type:'input'});assert.equal(h.field.children.length,0);assert.equal(h.dst.value,'নিজের বানান');
});
test('single or duplicate variants produce no dropdown; parents only one best result',async()=>{
  for(const type of ['employee name','father name','mother name']){
    const h=setup({rows:type==='employee name'?[['রহমান','খান'],['রহমান','খান']]:[['রহমান','খান']]});
    await h.run(type);assert.equal(h.field.children.length,0);assert.equal(h.dst.value,'মোঃ রহমান খান');
    assert.equal(h.calls.length,1);assert.equal(h.calls[0].body.generationConfig.maxOutputTokens,type==='employee name'?256:96);
  }
  const h=setup();await h.run('father name');assert.equal(h.dst.value,'');assert.equal(h.messages.length,1);
});
test('existing Bengali requires explicit replacement approval and declined request makes no API call',async()=>{
  const no=setup({target:'নিজের নাম',confirm:false});await no.run();assert.equal(no.dst.value,'নিজের নাম');assert.equal(no.calls.length,0);assert.equal(no.confirms,1);
  const yes=setup({target:'নিজের নাম'});await yes.run();assert.equal(yes.confirms,1);assert.equal(yes.dst.value,'মোঃ রহমান খান');
});
test('malformed, empty, non-Bengali, added/dropped parts, prose, and excess variants fail safely',async()=>{
  const outputs=['{bad','',JSON.stringify([]),JSON.stringify([['Rahman','Khan']]),JSON.stringify([['রহমান']]),JSON.stringify([['রহমান','খান','আলী']]),JSON.stringify([['রহমান খান','খান']]),JSON.stringify([['রহমান','<b>খান</b>']]),JSON.stringify(Array(5).fill(['রহমান','খান'])),'Here is '+JSON.stringify([['রহমান','খান']])];
  for(const output of outputs){
    const h=setup({response:()=>({ok:true,json:async()=>({candidates:[{content:{parts:[{text:output}]}}]})})});
    await h.run();assert.equal(h.dst.value,'');assert.equal(h.field.children.length,0);assert.equal(h.messages.length,1);assert.equal(h.btn.disabled,false);assert.equal(h.btn.innerHTML,'✦');assert.equal(h.calls.length,1);
  }
});
test('fenced JSON accepted, normalization deduplicates and Bengali source parts stay intact',()=>{
  const h=setup(),plan=h.ctx.employeeNameAIPlan('Muhammad আলী');
  assert.deepEqual(plain(h.ctx.employeeNameAIVariants('```json\n[["মুহম্মদ","আলি"]]\n```',plan,true)),['মুহাম্মদ আলী']);
});
test('network, HTTP, blocked and truncated responses do not replace existing names or retry',async()=>{
  for(const opts of [{fetchError:true},{response:()=>({ok:false})},{response:()=>({ok:true,json:async()=>({})})},{response:()=>({ok:true,json:async()=>({candidates:[{finishReason:'MAX_TOKENS',content:{parts:[{text:'[["রহমান","খান"]]'}]}}]})})}]){
    const h=setup({...opts,target:'সংরক্ষিত নাম'});await h.run();assert.equal(h.dst.value,'সংরক্ষিত নাম');assert.equal(h.calls.length,1);assert.equal(h.messages.length,1);assert.equal(h.btn.disabled,false);
  }
});
function deferred(){let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};}
const reply=()=>({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'[["রহমান","খান"]]'}]}}]})});
test('edits (including edit then undo), replaced modal nodes, and newer requests invalidate late responses',async()=>{
  for(const change of [h=>{h.dst.value='ম্যানুয়াল';h.dst.dispatchEvent({type:'input'});},h=>{h.src.dispatchEvent({type:'input'});},h=>{h.nodes.dst={value:'অন্য ব্যক্তি'};},h=>{h.src.value='New Person';}]){
    const gate=deferred(),h=setup({response:()=>gate.promise});const run=h.run();change(h);gate.resolve(reply());await run;
    assert.notEqual(h.dst.value,'মোঃ রহমান খান');assert.equal(h.field.children.length,0);assert.equal(h.messages.length,0);
  }
  const gates=[deferred(),deferred()];let i=0;
  const h=setup({response:()=>gates[i++].promise}),first=h.run(),second=h.run();
  gates[1].resolve(reply());await second;gates[0].resolve(reply());await first;
  assert.equal(h.dst.value,'মোঃ রহমান খান');assert.equal(h.btn.disabled,false);assert.equal(h.btn.innerHTML,'✦');assert.equal(h.calls[0].opts.signal.aborted,true);
});
test('timeout restores button and late successful response cannot write',async()=>{
  const gate=deferred(),h=setup({response:()=>gate.promise});const run=h.run();for(const fn of h.timers.values())fn();gate.resolve(reply());await run;
  assert.equal(h.dst.value,'');assert.equal(h.btn.disabled,false);assert.match(h.messages[0][0],/timed out/);
});
test('stale dropdown removed on source edit; programmatic target change cannot be overwritten',async()=>{
  const h=setup();await h.run();const select=h.field.children[0];h.dst.value='ম্যানুয়াল';select.dispatchEvent({type:'change'});assert.equal(h.dst.value,'ম্যানুয়াল');assert.equal(h.field.children.length,0);
  const other=setup();await other.run();other.src.dispatchEvent({type:'input'});assert.equal(other.field.children.length,0);
});
test('prefix only deterministic; missing API config and unsupported inputs cause no calls',async()=>{
  const h=setup({source:'M.S.T.'});await h.run();assert.equal(h.dst.value,'মোছাঃ');assert.equal(h.calls.length,0);
  for(const source of ['', '123', 'Ali / Khan']){const h=setup({source});await h.run();assert.equal(h.calls.length,0);assert.equal(h.dst.value,'');}
  const missing=setup();missing.ctx.window.__mgAiCfg.key='';await missing.run();assert.equal(missing.calls.length,0);
});
