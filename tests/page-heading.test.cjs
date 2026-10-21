const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('index.html','utf8');
const start = html.indexOf('function syncSectionHeading(){');
const source = html.slice(start,html.indexOf("document.addEventListener('DOMContentLoaded'",start));
function fixture(heading, title='Dashboard', subtitle='Workforce overview') {
  const page = {fallback:null, controls:{},
    querySelector(){return this.fallback},
    querySelectorAll(){return [...(this.fallback ? [this.fallback.children[0]] : []),...(heading ? [heading] : [])]},
    prepend(node){this.fallback=node;node.remove=()=>{this.fallback=null}}};
  const titles={pageTitle:{textContent:title},pageSub:{textContent:subtitle}};
  const c=vm.createContext({currentPage:'dashboard',document:{
    getElementById:id=>id==='page-dashboard'?page:titles[id],
    createElement:tag=>({tagName:tag.toUpperCase(),textContent:'',children:[],setAttribute(){},
      append(...nodes){this.children.push(...nodes);nodes.forEach(n=>{n.closest=()=>this})}})
  }});
  vm.runInContext(source,c);
  return {page,c,titles,setHeading(next){heading=next}};
}
const heading = (tag,text,hidden=false)=>{
  const classes=new Set();
  const host={classList:{add:name=>classes.add(name)},classes};
  return {tagName:tag,textContent:text,parentElement:host,
    closest:selector=>hidden?{}:selector==='header,.card-header'?host:null};
};
test('native Dashboard, Notification and Recruitment headings own the page; content subheadings remain intact',()=>{
  for(const [title,own] of [['Dashboard','Dashboard'],['Notifications','Notifications'],['Recruitment Pipeline','Recruitment']]) {
    const f=fixture(heading('H2',own),title);f.c.syncSectionHeading();
    assert.equal(f.page.fallback,null);assert.equal(f.page.querySelectorAll()[0].textContent,own);
  }
  const employees=fixture(heading('H3','Employees'),'Employees');employees.c.syncSectionHeading();assert.equal(employees.page.fallback,null);
  const form=fixture(heading('H3','New Transfer Order'),'Transfer Orders','Explicit joining confirmation');
  const controls=form.page.controls;form.c.syncSectionHeading();
  assert.equal(form.page.fallback.children[0].textContent,'Transfer Orders');
  assert.equal(form.page.fallback.children[1].textContent,'Explicit joining confirmation');
  assert.equal(form.page.controls,controls);assert.equal(form.page.querySelectorAll()[1].textContent,'New Transfer Order');
});
test('shared fallback is idempotent, updates context and disappears after an asynchronous native render',()=>{
  const f=fixture(null);f.c.syncSectionHeading();const initial=f.page.fallback;
  f.c.syncSectionHeading();assert.equal(f.page.fallback,initial);
  f.titles.pageSub.textContent='Updated context';f.c.syncSectionHeading();assert.equal(initial.children[1].textContent,'Updated context');
  f.setHeading(heading('H2','Dashboard'));f.c.syncSectionHeading();assert.equal(f.page.fallback,null);
  f.setHeading(null);f.c.syncSectionHeading();assert.equal(f.page.fallback.children[0].textContent,'Dashboard');
  assert.match(html,/<div class="topbar-left" hidden>/);
  assert.match(html,/observer\.observe\(page,\{childList:true,subtree:true\}\)/);
});

test('heading hosts reserve utility space without moving or hiding native actions',()=>{
  const own=heading('H2','Notifications');
  const f=fixture(own,'Notifications');const controls=f.page.controls;
  f.c.syncSectionHeading();
  assert(own.parentElement.classes.has('section-heading-host'));
  assert.equal(f.page.controls,controls);assert.equal(f.page.fallback,null);
  const empty=fixture(null);empty.c.syncSectionHeading();
  assert.equal(empty.page.fallback.className,'section-page-heading section-heading-host');
  // Utility and navigation markup must remain outside the hidden metadata source.
  const metadata=html.slice(html.indexOf('<div class="topbar-left"'),html.indexOf('<div class="topbar-right"'));
  assert(!/id="(?:notifBell|fullscreenToggleBtn|mobileNotifToggle)"/.test(metadata));
  assert.match(html,/\.main > \.topbar\{position:absolute;/);
  assert.match(html,/padding-inline-end:104px/);
  assert.match(html,/\.main > \.topbar\{position:static;margin:0;padding:0!important;min-height:0/);
});
