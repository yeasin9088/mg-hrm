const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');
const html=fs.readFileSync('index.html','utf8');
function fixture(insert){
 const messages=[],storage=new Map(),calls=[];let translations=0;
 const c={console:{error(){}},Set,Date,Math,DATA:{todos:[]},renderTodo(){},updateTodoBadge(){},toastSafe:(m,k)=>messages.push({m,k}),todayISO:()=> '2026-10-25',setTimeout(){},
 localStorage:{setItem:(k,v)=>storage.set(k,v),getItem:k=>storage.get(k),removeItem:k=>storage.delete(k)},
 appData:{currentUser:()=>null,insert:async(b,t)=>{calls.push({...t});return insert(t,calls.length);}},mgAITranslate:async()=>{translations++;return 'বাংলা নোট';},MG_RM_TYPES:{'30min':{interval:30}}};c.window=c;
 vm.createContext(c);vm.runInContext(html.slice(html.indexOf('  var MG_TD_LOADING = [];'),html.indexOf('\n  tdLoadRestore();',html.indexOf('  var MG_TD_LOADING = [];'))),c);
 function queue(extra={}){const item={id:'q1',raw:'original',cat:'permission',phase:'busy',...extra};c.MG_TD_LOADING.push(item);return item;}
 return {c,messages,calls,storage,queue,get translations(){return translations;}};
}
test('all inline scripts remain syntactically valid',()=>{for(const m of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)){if(m[1].trim())new vm.Script(m[1]);}});
test('translated new note inserts once, keeps reminder and uses returned server row',async()=>{
 const f=fixture(async t=>[{...t,next_reminder_at:'2026-10-25T09:00:00Z'}]);await f.c.tdProcessItem(f.queue({reminder:'30min'}));
 assert.equal(f.calls.length,1);assert.equal(f.calls[0].reminder_interval,30);assert.equal(f.c.DATA.todos[0].next_reminder_at,'2026-10-25T09:00:00Z');assert.equal(f.c.MG_TD_LOADING.length,0);assert.equal(f.messages.at(-1).k,'success');
});
test('null or empty confirmation preserves draft and never claims success; retry keeps ID and translation',async()=>{
 for(const response of [null,[]]){const f=fixture(async(t,n)=>n===1?response:[t]);const item=f.queue();await f.c.tdProcessItem(item);
 assert.equal(item.phase,'save-error');assert.equal(f.c.DATA.todos.length,0);assert.equal(f.messages.some(x=>x.k==='success'),false);assert.equal(JSON.parse(f.storage.get('mghrm_td_queue'))[0].raw,'original');
 await f.c.mtRetryLoading(item.id);assert.equal(f.calls[0].id,f.calls[1].id);assert.equal(f.translations,1);assert.equal(f.c.DATA.todos.length,1);}
});
test('Bengali direct save bypasses translation; original fallback also inserts',async()=>{
 const f=fixture(async t=>[t]);await f.c.tdProcessItem(f.queue({translated:'বাংলা'}));assert.equal(f.translations,0);
 const g=fixture(async t=>[t]);const item=g.queue();await g.c.mtSaveLoadingRaw(item.id);assert.equal(g.calls[0].note,'original');assert.equal(g.translations,0);
});
test('concurrent Retry taps issue only one insert and discard cannot remove an in-flight draft',async()=>{
 let release;const f=fixture(t=>new Promise(r=>release=()=>r([t])));const item=f.queue({translated:'বাংলা'});
 const pending=f.c.tdProcessItem(item);await f.c.tdProcessItem(item);f.c.mtDiscardLoading(item.id);assert.equal(f.calls.length,1);assert.equal(f.c.MG_TD_LOADING.length,1);release();await pending;
});
test('duplicate key after lost response recovers matching row without overwrite',async()=>{
 const f=fixture(async()=>{throw {code:'23505'};});const item=f.queue({translated:'বাংলা'});
 f.c.sb={from:()=>({select:()=>({eq:async()=>({data:[{...item.task}]})})})};await f.c.tdProcessItem(item);assert.equal(f.c.DATA.todos.length,1);assert.equal(f.c.MG_TD_LOADING.length,0);
});
test('duplicate key with different note is never treated as saved',async()=>{
 const f=fixture(async()=>{throw {code:'23505'};});const item=f.queue({translated:'বাংলা'});
 f.c.sb={from:()=>({select:()=>({eq:async()=>({data:[{...item.task,note_bn:'different'}]})})})};await f.c.tdProcessItem(item);assert.equal(f.c.DATA.todos.length,0);assert.equal(item.phase,'save-error');
});
