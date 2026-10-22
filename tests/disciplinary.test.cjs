const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const model = require('../disciplinary-model.js');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261022170000_disciplinary_actions_notifications.sql'), 'utf8');

test('exact approved action names, order and printable Bengali titles; historical titles remain readable', () => {
  assert.deepEqual(model.types.map(t => t.en), [
    'Show Cause Notice','Warning Letter','Final Warning Letter',
    'Final Show Cause Notice','Suspension Order','Suspension Revocation Order','Dismissal Order'
  ]);
  assert.deepEqual(model.types.map(t => t.bn), [
    'কারণ দর্শানোর নোটিশ','সতর্কীকরণ পত্র','চূড়ান্ত সতর্কীকরণ পত্র',
    'চূড়ান্ত কারণ দর্শানোর নোটিশ','সাময়িক বরখাস্তের আদেশ',
    'সাময়িক বরখাস্ত প্রত্যাহারের আদেশ','চাকরি হতে বরখাস্তের আদেশ'
  ]);
  assert.equal(model.title('Show-Cause Notice'), 'শোকজ নোটিশ');
  assert.equal(model.title('বরখাস্তের আদেশ'), 'বরখাস্তের আদেশ');
  assert.match(html, /Object\.entries\(DC_TEMPLATES\)\.map/);
  assert.doesNotMatch(html, /<option value="ShowCause"|<option value="Termination">/);
});

test('Bengali plain body prints a modest paragraph per single Enter without injected blank lines or HTML', () => {
  assert.equal(model.plainParagraphs('প্রথম অনুচ্ছেদ\nদ্বিতীয় অনুচ্ছেদ'),
    '<p class="dc-paragraph">প্রথম অনুচ্ছেদ</p><p class="dc-paragraph">দ্বিতীয় অনুচ্ছেদ</p>');
  assert.equal(model.plainParagraphs('পরীক্ষা <script>\r\nশেষ'),
    '<p class="dc-paragraph">পরীক্ষা &lt;script&gt;</p><p class="dc-paragraph">শেষ</p>');
  assert.match(html, /\.dc-print-body \.dc-paragraph/);
  assert.match(html, /class="body-text tight-p dc-print-body"/);
  assert.match(html, /\$\{letterhead\(\)\}/);
  assert.match(html, /class="sig-flow"/);
});

test('new and edit editors and validation preserve three editable fields and avoid duplicate previews', () => {
  assert.equal(model.validate({incident_date:'2026-02-30',issue_date:'2026-03-01',description:'লেখা'}), 'Enter a valid Incident Date.');
  assert.equal(model.validate({incident_date:'2026-03-01',issue_date:'2026-03-02',description:'  '}), 'Enter a Letter Body.');
  assert.equal(model.validate({incident_date:'2026-03-01',issue_date:'2026-03-02',description:'বাংলা'}), '');
  assert.match(html, /id="_dcIncidentEdit" type="date"/);
  assert.match(html, /id="_dcIssueEdit" type="date"/);
  assert.match(html, /id="_dcDescEdit" class="dc-letter-editor"/);
  assert.match(html, /\.eq\('updated_at', dcEditVersion\)/);
  assert.match(html, /\.update\(patch\)/);
  assert.doesNotMatch(html, /Preview Body|Preview Full Bangla Notice|dcTogglePreview/);
  assert.match(html, /\.dc-form-head \{[^}]*background:var\(--card\)/);
  assert.match(html, /@media \(max-width:600px\)/);
});

test('record opens via authorized inbox route and push remains privacy safe', () => {
  const center = fs.readFileSync(path.join(root,'notification-center.js'), 'utf8');
  const push = fs.readFileSync(path.join(root,'supabase/functions/web-push-sender/worker.mjs'),'utf8');
  assert.match(center, /route === 'disciplinary'.*item\.isBackend/);
  assert.match(center, /window\.mgOpenDisciplinaryRecord\(item\.ref\)/);
  assert.match(html, /\.eq\('id',id\)\.is\('deleted_at',null\)\.maybeSingle\(\)/);
  assert.match(push, /disciplinary:\['Disciplinary Update','A confidential disciplinary update is ready for review\.'/);
});

test('deep link checks the current account through RLS before showing a cached disciplinary record', async () => {
  const start=html.indexOf('window.mgOpenDisciplinaryRecord = async function(id){');
  const end=html.indexOf('function openDisciplinaryPopup',start);
  assert.ok(start>0 && end>start);
  const stale={id:17,Description:'stale private text'};
  const data={disciplinary:[stale]};
  let result={data:null,error:null},opened=0,errors=0;
  const query={eq(){return this;},is(){return this;},async maybeSingle(){return result;}};
  const context=vm.createContext({DATA:data,window:{sb:{from(){return {select(){return query;}}}}},
    navigate:()=>{},openDisciplinaryPopup:()=>opened++,renderDisciplinaryTable:()=>{},
    toast:()=>errors++});
  vm.runInContext(html.slice(start,end),context);
  await context.window.mgOpenDisciplinaryRecord(17);
  assert.equal(opened,0);
  assert.equal(errors,1);
  assert.equal(data.disciplinary[0],stale);
  result={data:{id:17,action_type:'Warning Letter',description:'authorized'},error:null};
  await context.window.mgOpenDisciplinaryRecord(17);
  assert.equal(opened,1);
  assert.equal(data.disciplinary.length,1);
  assert.equal(data.disciplinary[0].Description,'authorized');
});

test('edit writes only three columns and a stale device keeps the unsaved draft with an error', async () => {
  const start = html.indexOf('let dcEditSaving = false;');
  const end = html.indexOf('async function deleteDisciplinary',start);
  assert.ok(start > 0 && end > start);
  const row = {id:17,ActionID:17,updated_at:'2026-10-22T09:00:00Z',
    incident_date:'2026-10-01',issue_date:'2026-10-02',description:'আগের লেখা',RefNo:'REF-17'};
  const elements = {
    _dcIncidentEdit:{value:'2026-10-03'},_dcIssueEdit:{value:'2026-10-04'},
    _dcDescEdit:{value:'সংশোধিত\nদ্বিতীয় অনুচ্ছেদ'},
    _dcEditError:{textContent:''},_dcSaveEdit:{disabled:false,textContent:'Save Changes',isConnected:true}
  };
  let captured, response, successCount=0;
  const query = {
    eq(k,v){ (captured.filters ||= []).push([k,v]); return this; },
    is(k,v){ (captured.filters ||= []).push([k,v]); return this; },
    select(k){captured.selection=k;return this;},
    async maybeSingle(){return response;}
  };
  const context = vm.createContext({
    DATA:{disciplinary:[row]},document:{getElementById:id=>elements[id]},
    window:{sb:{from(name){assert.equal(name,'disciplinary');return {
      update(patch){captured={patch};return query;}
    };}}},MGDisciplinary:model,guardEdit:()=>true,
    toast:()=>successCount++,logActivity:()=>{},openDisciplinaryPopup:()=>{},renderDisciplinaryTable:()=>{}
  });
  vm.runInContext(html.slice(start,end),context);
  vm.runInContext("dcEditVersion='2026-10-22T09:00:00Z'",context);
  response={data:null,error:null};
  await vm.runInContext('saveDisciplinaryEdit(17)',context);
  assert.deepEqual(Object.keys(captured.patch).sort(),['description','incident_date','issue_date']);
  assert.deepEqual(captured.filters.map(x=>x[0]),['id','updated_at','deleted_at']);
  assert.equal(captured.filters[1][1],row.updated_at);
  assert.equal(row.description,'আগের লেখা');
  assert.equal(elements._dcDescEdit.value,'সংশোধিত\nদ্বিতীয় অনুচ্ছেদ');
  assert.match(elements._dcEditError.textContent,/changed on another device/);
  assert.equal(successCount,0);
  response={data:{id:17,updated_at:'2026-10-22T10:00:00Z',...captured.patch},error:null};
  await vm.runInContext('saveDisciplinaryEdit(17)',context);
  assert.equal(row.description,'সংশোধিত\nদ্বিতীয় অনুচ্ছেদ');
  assert.equal(row.RefNo,'REF-17');
  assert.equal(successCount,1);
});

test('versioned SQL works on isolated records, protects legacy rows, records audit metadata and deduplicates events', async () => {
  const {PGlite} = await import('@electric-sql/pglite');
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated;
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
        AS $$ SELECT nullif(current_setting('app.test_user',true),'')::uuid $$;
      CREATE FUNCTION public.my_role() RETURNS text LANGUAGE sql STABLE
        AS $$ SELECT current_setting('app.test_role',true) $$;
      CREATE TABLE public.disciplinary (
        id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, action_id text, action_type text,
        employee_sys_id bigint, incident_date text, issue_date text, description text,
        deleted_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE FUNCTION public.test_touch_disciplinary() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN NEW.updated_at := clock_timestamp(); RETURN NEW; END $$;
      CREATE TRIGGER disciplinary_touch_trg BEFORE UPDATE ON public.disciplinary
        FOR EACH ROW EXECUTE FUNCTION public.test_touch_disciplinary();
      CREATE TABLE public.notification_events (
        id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, event_type text, entity_type text,
        entity_id text, employee_sys_id bigint, actor_user_id uuid, event_key text UNIQUE,
        event_payload jsonb, occurred_at timestamptz
      );
      CREATE TABLE public.notifications (
        id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, event_id bigint, status text
      );
      INSERT INTO public.disciplinary (action_id,action_type,description)
        VALUES ('legacy-1','Show-Cause Notice','Existing historical record');
      SELECT set_config('app.test_user','00000000-0000-4000-8000-000000000001',false);
      SELECT set_config('app.test_role','editor',false);
    `);
    await db.exec(migration);
    const existing = await db.query("SELECT action_type FROM public.disciplinary WHERE action_id='legacy-1'");
    assert.equal(existing.rows[0].action_type,'Show-Cause Notice');
    for (const [i,t] of model.types.entries()) {
      await db.query(`INSERT INTO public.disciplinary(action_id,action_type,incident_date,issue_date,description)
        VALUES ($1,$2,'2026-10-01','2026-10-02','পরীক্ষা')`,['new-'+i,t.en]);
    }
    const events = await db.query("SELECT event_key,event_payload FROM public.notification_events ORDER BY id");
    assert.equal(events.rows.length, 7);
    for(const [i,row] of events.rows.entries()){
      assert.equal(row.event_payload.category,'Disciplinary');
      assert.equal(row.event_payload.action_route,'disciplinary');
      assert.equal(row.event_payload.recipient_user_id,'00000000-0000-4000-8000-000000000001');
      assert.ok(!JSON.stringify(row.event_payload).includes('পরীক্ষা'));
      assert.equal(row.event_key,'disciplinary:recorded:v1:'+(i+2));
    }
    await assert.rejects(db.query("INSERT INTO public.disciplinary(action_id,action_type) VALUES ('bad','Termination Order')"), /approved disciplinary action type/);
    await assert.rejects(db.query("INSERT INTO public.disciplinary(action_id,action_type) VALUES ('new-0','Warning Letter')"), /unique|duplicate/i);
    const version = (await db.query("SELECT updated_at FROM public.disciplinary WHERE action_id='new-0'")).rows[0].updated_at;
    const first = await db.query("UPDATE public.disciplinary SET incident_date='2026-10-03',description='সংশোধন' WHERE action_id='new-0' AND updated_at=$1 RETURNING id",[version]);
    assert.equal(first.rows.length,1);
    const stale = await db.query("UPDATE public.disciplinary SET description='stale edit' WHERE action_id='new-0' AND updated_at=$1 RETURNING id",[version]);
    assert.equal(stale.rows.length,0);
    const audit = await db.query('SELECT disciplinary_id,editor_user_id,changed_fields FROM public.disciplinary_edit_audit');
    assert.deepEqual(audit.rows[0].changed_fields,['incident_date','description']);
    assert.equal(audit.rows.length,1);
    await db.query('INSERT INTO public.notifications(event_id,status) VALUES (1,\'Ready\')');
    await db.query("UPDATE public.disciplinary SET deleted_at=now() WHERE action_id='new-0'");
    assert.equal((await db.query('SELECT status FROM public.notifications')).rows[0].status,'Cancelled');
    assert.equal((await db.query('SELECT count(*)::integer n FROM public.notification_events')).rows[0].n,7);
  } finally { await db.close(); }
});
