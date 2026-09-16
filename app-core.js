/* =====================================================================
   MG SECURITY HRM — Supabase Data Layer  (v1.0)
   এই ফাইলটি অ্যাপের ডেটা পড়া/লেখার পুরো কাজ করে।
   ===================================================================== */
(function (global) {
  'use strict';

  /* ---------- ১. টেবিল ও কলাম ম্যাপিং -------------------------------- */
  var TABLE_MAP = {
    employees: { table: 'employees', pk: 'record_id', map: {
      'RecordID':'record_id','EmployeeID':'employee_id','FullName':'full_name',
      'FullNameBangla':'full_name_bn','FullNameBn':'full_name_bn',
      'FatherName':'father_name','MotherName':'mother_name',
      'DOB':'dob','PhoneNumber':'phone','Education':'education',
      'Religion':'religion','Height':'height','Weight':'weight',
      'Division':'division','District':'district','Thana':'thana',
      'DivisionID':'division_id','DistrictID':'district_id','UpazilaID':'upazila_id','UnionID':'union_id',
      'Village':'village','Street':'street','Address':'address','AddressBangla':'address_bn',
      'NID':'nid','NID/BirthCertificate':'nid',
      'MaritalStatus':'marital_status','SpouseName':'spouse_name','SpousePhoneNum':'spouse_phone',
      'ECName':'ec_name','ECRelation':'ec_relation','ECPhoneNumber':'ec_phone',
      'Designation':'designation','ProjectName':'project_name',
      'JoinDate':'join_date','DutyHour':'duty_hour','Salary':'salary','Status':'status',
      'ExitDate':'exit_date','ExitReason':'exit_reason','PhotoURL':'photo_url','Remarks':'remarks' } },

    projects: { table: 'projects', pk: 'id', map: {
      'Project ID':'id','ProjectName':'project_name','ProjectNameBangla':'project_name_bn',
      'Address':'address','AddressBangla':'address_bn',
      'Main Gate Phone Num':'main_gate_phone','MainGatePhone':'main_gate_phone',
      'Admin Name':'admin_name','AdminName':'admin_name',
      'Admin Phone Num':'admin_phone','AdminPhone':'admin_phone',
      'Admin WhatsApp Num':'admin_whatsapp','AdminWhatsApp':'admin_whatsapp',
      'Division':'division','District':'district','Thana':'thana',
      'DivisionID':'division_id','DistrictID':'district_id','UpazilaID':'upazila_id','UnionID':'union_id',
      'Village':'village','Street':'street',
      'StartDate':'start_date','Status':'status' } },

    demand: { table: 'demand', pk: 'id', map: {
      'ID':'id','ProjectName':'project_name',
      'DemandSecurityIncharge':'demand_incharge','DemandSecuritySupervisor':'demand_supervisor',
      'DemandAsstSecuritySupervisor':'demand_assst_sup','DemandSecurityGuard':'demand_guard',
      'DemandLadyGuard':'demand_lady_guard','DemandTotal':'demand_total' } },

    disciplinary: { table: 'disciplinary', pk: 'action_id', map: {
      'ActionID':'action_id','RefNo':'ref_no','RefNoBangla':'ref_no_bn','RecordID':'record_id',
      'EmployeeID':'employee_id','EmployeeIDBangla':'employee_id_bn','FullName':'full_name',
      'FullNameBangla':'full_name_bn','Designation':'designation','DesignationBangla':'designation_bn',
      'ProjectName':'project_name','ProjectNameBangla':'project_name_bn','ActionType':'action_type',
      'IssueDate':'issue_date','IssueDateBangla':'issue_date_bn','IncidentDate':'incident_date',
      'Description':'description','DescriptionBangla':'description_bn' } },

    exits: { table: 'exits', pk: 'exit_id', map: {
      'ExitID':'exit_id','RecordID':'record_id','FullName':'full_name','Designation':'designation',
      'CurrentProject':'current_project','JoinDate':'join_date','ExitReason':'exit_reason',
      'ExitDate':'exit_date','IssueDate':'issue_date' } },

    transfers: { table: 'transfers', pk: 'transfer_id', map: {
      'TransferID':'transfer_id','RecordID':'record_id','EmployeeID':'employee_id',
      'EmployeeIDBangla':'employee_id_bn','FullName':'full_name','FullNameBangla':'full_name_bn',
      'Designation':'designation','DesignationBangla':'designation_bn',
      'CurrentProject':'current_project','CurrentProjectBangla':'current_project_bn',
      'NewProject':'new_project','NewProjectBangla':'new_project_bn',
      'TransferDate':'transfer_date','TransferDateBangla':'transfer_date_bn',
      'Issues Date':'issues_date','Issues DateBangla':'issues_date_bn','IsProceed':'is_proceed' } },

    career: { table: 'career', pk: 'change_id', map: {
      'ChangeID':'change_id','RecordID':'record_id','EmployeeID':'employee_id','FullName':'full_name',
      'ProjectName':'project_name','ChangeType':'change_type','EffectiveDate':'effective_date',
      'CurrentDesignation':'current_designation','NewDesignation':'new_designation',
      'PreviousSalary':'previous_salary','IncrementAmount':'increment_amount','NewSalary':'new_salary' } },

    divisions: { table: 'divisions', pk: 'division_id', map: {
      'Division ID':'division_id','Division Name':'division_name' } },

    districts: { table: 'districts', pk: 'district_id', map: {
      'Districts ID':'district_id','Division ID':'division_id','Districts Name':'district_name' } },

    thana: { table: 'thanas', pk: 'thana_id', map: {
      'Thana ID':'thana_id','Districts ID':'district_id','Thana Name':'thana_name' } },

    desigBangla: { table: 'designations', pk: 'desig_id', map: {
      'ID':'desig_id','Designation':'designation','DesignationBangla':'designation_bn' } },

    uniform: { table: 'uniform', pk: 'issue_id', map: {} },
    leaves:  { table: 'leaves',  pk: 'leave_id', map: {} },
    meetings:{ table: 'meetings',pk: 'meeting_id', map: {} }
  };

  /* ---------- ২. নাম রূপান্তর -------------------------------------- */
  function camelToSnake(s) {
    return String(s)
      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
      .replace(/[\s\-]+/g, '_')
      .replace(/_+/g, '_')
      .toLowerCase().replace(/^_|_$/g, '');
  }
  function toDb(key, rec) {
    var m = TABLE_MAP[key], out = {}, k, col, v;
    for (k in rec) {
      if (!Object.prototype.hasOwnProperty.call(rec, k)) continue;
      if (k.charAt(0) === '_') continue;                       // _i ইত্যাদি internal
      col = (m.map && m.map[k]) || camelToSnake(k);
      v = rec[k];
      if (typeof v === 'string' && v.trim() === '') v = null;
      out[col] = v;
    }
    delete out.created_at; delete out.updated_at;
    if (out.id === undefined || out.id === null) delete out.id;  // identity কলাম
    return out;
  }
  function fromDb(key, row) {
    var m = TABLE_MAP[key], rev = {}, c, out = {};
    for (c in (m.map || {})) rev[m.map[c]] = c;
    for (c in row) {
      if (c === 'created_at' || c === 'updated_at') continue;
      if (row[c] === null) continue;                            // খালি ফিল্ড বাদ
      out[rev[c] || c] = row[c];
    }
    return out;
  }

  /* ---------- ৩. অবস্থা ------------------------------------------- */
  var sb = null, cfg = {}, user = null, ready = false;
  var QUEUE_KEY = 'mghrm_offline_queue';
  var HASH_KEY  = 'mghrm_table_hashes';
  var memory = {};                                            // offline fallback

  function loadJSON(k, d) { try { return JSON.parse(localStorage.getItem(k)) || d; } catch (e) { return d; } }
  function saveJSON(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }

  /* ---------- ৪. সংযোগ ------------------------------------------- */
  function connect(config) {
    cfg = config || {};
    if (!cfg.url || !cfg.anonKey) {
      return Promise.reject(new Error('Supabase URL অথবা anon key দেওয়া হয়নি'));
    }
    if (!global.supabase || !global.supabase.createClient) {
      return Promise.reject(new Error('supabase-js লোড হয়নি — ইন্টারনেট সংযোগ দেখুন'));
    }
    sb = global.supabase.createClient(cfg.url, cfg.anonKey, {
      auth: { persistSession: true, autoRefreshToken: true, storageKey: 'mghrm_auth' }
    });
    ready = true;
    return Promise.resolve(true);
  }
  function isReady() { return ready; }

  /* ---------- ৫. লগইন / লগআউট ------------------------------------ */
  function signIn(email, password) {
    return sb.auth.signInWithPassword({ email: email, password: password })
      .then(function (r) { if (r.error) throw r.error; user = r.data.user; return user; });
  }
  function signUp(email, password, fullName) {
    return sb.auth.signUp({ email: email, password: password,
      options: { data: { full_name: fullName || email } } })
      .then(function (r) { if (r.error) throw r.error; return r.data; });
  }
  function signOut() {
    return sb.auth.signOut().then(function () { user = null; });
  }
  function getSession() {
    return sb.auth.getSession().then(function (r) {
      user = r.data && r.data.session ? r.data.session.user : null;
      return r.data ? r.data.session : null;
    });
  }
  function onChange(cb) { sb.auth.onAuthStateChange(function (ev, s) { cb(ev, s); }); }
  function currentUser() { return user; }
  function myProfile() {
    if (!user) return Promise.resolve(null);
    return sb.from('profiles').select('*').eq('id', user.id).maybeSingle()
      .then(function (r) { return r.data; });
  }

  /* ---------- ৬. সব ডেটা পড়া -------------------------------------- */
  function loadAll() {
    var keys = Object.keys(TABLE_MAP);
    return Promise.all(keys.map(function (k) {
      return sb.from(TABLE_MAP[k].table).select('*')
        .then(function (r) {
          if (r.error) { console.warn('[Supabase] load ' + k, r.error.message); return [k, null]; }
          return [k, (r.data || []).map(function (row) { return fromDb(k, row); })];
        });
    })).then(function (pairs) {
      var out = {}, nulls = [];
      pairs.forEach(function (p) { if (p[1] === null) nulls.push(p[0]); else out[p[0]] = p[1]; });
      if (nulls.length) console.warn('[Supabase] এই টেবিলগুলো পড়া যায়নি:', nulls.join(', '));
      return out;
    });
  }

  /* ---------- ৭. লেখা (upsert) -------------------------------------- */
  function upsert(key, rows) {
    if (!rows || !rows.length) return Promise.resolve(0);
    var m = TABLE_MAP[key];
    var clean = rows.map(function (r) { return toDb(key, r); });
    var chunk = 500, parts = [];
    for (var i = 0; i < clean.length; i += chunk) parts.push(clean.slice(i, i + chunk));
    return parts.reduce(function (chain, part) {
      return chain.then(function (n) {
        return sb.from(m.table).upsert(part, { onConflict: m.pk }).then(function (r) {
          if (r.error) throw r.error;
          return n + part.length;
        });
      });
    }, Promise.resolve(0));
  }

  function remove(key, pkValue) {
    var m = TABLE_MAP[key];
    return sb.from(m.table).delete().eq(m.pk, pkValue).then(function (r) {
      if (r.error) throw r.error; return true;
    });
  }

  function hashOf(obj) {
    var s = typeof obj === 'string' ? obj : JSON.stringify(obj);
    var h = 5381, i = s.length;
    while (i) h = ((h * 33) ^ s.charCodeAt(--i)) >>> 0;
    return h;
  }

  /* ---------- ৮. সব ডেটা লেখা (শুধু যেগুলো বদলেছে) ------------------ */
  var pushTimer = null, pushing = false;
  function pushAll(silentSource) {
    if (pushTimer) clearTimeout(pushTimer);
    pushTimer = setTimeout(function () { doPush(silentSource); }, 1500);
  }

  function doPush(silentSource) {
    if (!ready || pushing) return Promise.resolve();
    var src = silentSource || global.DATA || {};
    var hashes = loadJSON(HASH_KEY, {});
    var jobs = [], names = [];
    Object.keys(TABLE_MAP).forEach(function (k) {
      var arr = src[k];
      if (!Array.isArray(arr) || !arr.length) return;
      var h = hashOf(arr);
      if (hashes[k] === h) return;                    // অপরিবর্তিত
      hashes[k] = h;
      names.push(k);
      jobs.push(upsert(k, arr));
    });
    if (!jobs.length) return Promise.resolve();
    pushing = true;
    return Promise.all(jobs).then(function () {
      saveJSON(HASH_KEY, hashes);
      console.log('[Supabase] সংরক্ষিত:', names.join(', '));
    }).catch(function (e) {
      // ব্যর্থ হলে হ্যাশ ফেরত দিই, যাতে পরে আবার চেষ্টা হয়
      var cur = loadJSON(HASH_KEY, {});
      names.forEach(function (n) { delete cur[n]; });
      saveJSON(HASH_KEY, cur);
      console.error('[Supabase] সংরক্ষণ ব্যর্থ:', e.message || e);
      if (global.toast) global.toast('ডেটা সার্ভারে যায়নি — ইন্টারনেট দেখুন', 'error');
    }).then(function () { pushing = false; });
  }

  /* ---------- ৯. রেফারেন্স টেবিল সিড -------------------------------- */
  function seedReferenceTables(src) {
    var jobs = [];
    ['divisions', 'districts', 'thana', 'desigBangla'].forEach(function (k) {
      if (Array.isArray(src[k]) && src[k].length) jobs.push(upsert(k, src[k]));
    });
    return Promise.all(jobs);
  }

  /* ---------- ১০. বিদ্যমান ডেটা একবার আপলোড ------------------------ */
  function bulkUpload(src, onProgress) {
    var keys = Object.keys(TABLE_MAP).filter(function (k) {
      return Array.isArray(src[k]) && src[k].length;
    });
    var done = 0;
    return keys.reduce(function (chain, k) {
      return chain.then(function () {
        return upsert(k, src[k]).then(function (n) {
          done++;
          if (onProgress) onProgress(done, keys.length, k, n);
        });
      });
    }, Promise.resolve()).then(function () { return done; });
  }

  /* ---------- ১১. অ্যাডমিন হেল্পার ---------------------------------- */
  function raw() { return sb; }
  function sqlView(table) {
    return sb.from(table).select('*');
  }

  global.MGHRM = {
    connect: connect, isReady: isReady,
    signIn: signIn, signUp: signUp, signOut: signOut,
    getSession: getSession, onChange: onChange, currentUser: currentUser, myProfile: myProfile,
    loadAll: loadAll, upsert: upsert, remove: remove,
    pushAll: pushAll, doPush: doPush,
    bulkUpload: bulkUpload, seedReferenceTables: seedReferenceTables,
    TABLE_MAP: TABLE_MAP, toDb: toDb, fromDb: fromDb,
    _client: raw, _view: sqlView,
    version: '1.0.0'
  };
})(window);
