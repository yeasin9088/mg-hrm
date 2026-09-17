/* =====================================================================
   MG SECURITY HRM — Supabase Data Layer (Real-Time Server-Side)
   ===================================================================== */
(function (global) {
  'use strict';
  'use strict';

  /* ---------- 1. Table & Column Mapping -------------------------------- */
  var TABLE_MAP = {
    employees: { table: 'employees', pk: 'record_id', allowed: ['id', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'father_name', 'mother_name', 'dob', 'phone', 'nid', 'education', 'religion', 'height', 'weight', 'marital_status', 'spouse_name', 'spouse_phone', 'ec_name', 'ec_relation', 'ec_phone', 'division', 'district', 'thana', 'address', 'address_bn', 'division_id', 'district_id', 'upazila_id', 'union_id', 'village', 'street', 'designation', 'project_name', 'join_date', 'duty_hour', 'salary', 'status', 'exit_date', 'exit_reason', 'remarks', 'photo_url', 'created_at', 'updated_at', 'system_id'], map: {
      'SystemID':'system_id','RecordID':'record_id','EmployeeID':'employee_id','FullName':'full_name',
      'FullNameBangla':'full_name_bn','DOB':'dob','PhoneNumber':'phone','Education':'education',
      'Religion':'religion','Height':'height','Weight':'weight','Division':'division',
      'District':'district','Thana':'thana','Designation':'designation','ProjectName':'project_name',
      'JoinDate':'join_date','DutyHour':'duty_hour','Salary':'salary','Status':'status',
      'ExitDate':'exit_date','PhotoURL':'photo_url' } },

    projects: { table: 'projects', pk: 'id', allowed: ['id', 'project_name', 'project_name_bn', 'address', 'address_bn', 'main_gate_phone', 'admin_name', 'admin_phone', 'admin_whatsapp', 'division', 'district', 'thana', 'division_id', 'district_id', 'upazila_id', 'union_id', 'village', 'street', 'start_date', 'status', 'created_at'], map: {
      'Project ID':'id','ProjectName':'project_name','ProjectNameBangla':'project_name_bn',
      'Main Gate Phone Num':'main_gate_phone','Admin Phone Num':'admin_phone',
      'Admin WhatsApp Num':'admin_whatsapp' } },

    demand: { table: 'demand', pk: 'id', allowed: ['id', 'project_name', 'demand_incharge', 'demand_supervisor', 'demand_assst_sup', 'demand_guard', 'demand_lady_guard', 'demand_total', 'created_at'], map: {
      'ID':'id','ProjectName':'project_name',
      'DemandSecurityIncharge':'demand_incharge','DemandSecuritySupervisor':'demand_supervisor',
      'DemandAsstSecuritySupervisor':'demand_assst_sup','DemandSecurityGuard':'demand_guard',
      'DemandLadyGuard':'demand_lady_guard','DemandTotal':'demand_total' } },

    disciplinary: { table: 'disciplinary', pk: 'action_id', allowed: ['id', 'action_id', 'ref_no', 'ref_no_bn', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'designation', 'designation_bn', 'project_name', 'project_name_bn', 'action_type', 'issue_date', 'incident_date', 'description', 'created_at', 'system_id', 'employee_id_bn', 'issue_date_bn', 'description_bn'], map: {
      'SystemID':'system_id','ActionID':'action_id','RefNo':'ref_no','RefNoBangla':'ref_no_bn','RecordID':'record_id',
      'EmployeeID':'employee_id','EmployeeIDBangla':'employee_id_bn','FullName':'full_name',
      'FullNameBangla':'full_name_bn','Designation':'designation','DesignationBangla':'designation_bn',
      'ProjectName':'project_name','ProjectNameBangla':'project_name_bn','ActionType':'action_type',
      'IssueDate':'issue_date','IssueDateBangla':'issue_date_bn','IncidentDate':'incident_date',
      'Description':'description','DescriptionBangla':'description_bn' } },

    exits: { table: 'exits', pk: 'exit_id', allowed: ['id', 'exit_id', 'record_id', 'full_name', 'designation', 'current_project', 'join_date', 'exit_reason', 'exit_date', 'issue_date', 'created_at', 'system_id'], map: {
      'SystemID':'system_id','ExitID':'exit_id','RecordID':'record_id','FullName':'full_name','Designation':'designation',
      'CurrentProject':'current_project','JoinDate':'join_date','ExitReason':'exit_reason',
      'ExitDate':'exit_date','IssueDate':'issue_date' } },

    transfers: { table: 'transfers', pk: 'transfer_id', allowed: ['id', 'transfer_id', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'designation', 'designation_bn', 'current_project', 'current_project_bn', 'new_project', 'new_project_bn', 'transfer_date', 'issues_date', 'is_proceed', 'created_at', 'system_id', 'employee_id_bn', 'transfer_date_bn', 'issues_date_bn'], map: {
      'SystemID':'system_id','TransferID':'transfer_id','RecordID':'record_id','EmployeeID':'employee_id',
      'EmployeeIDBangla':'employee_id_bn','FullName':'full_name','FullNameBangla':'full_name_bn',
      'Designation':'designation','DesignationBangla':'designation_bn',
      'CurrentProject':'current_project','CurrentProjectBangla':'current_project_bn',
      'NewProject':'new_project','NewProjectBangla':'new_project_bn',
      'TransferDate':'transfer_date','TransferDateBangla':'transfer_date_bn',
      'Issues Date':'issues_date','Issues DateBangla':'issues_date_bn','IsProceed':'is_proceed' } },

    career: { table: 'career', pk: 'change_id', allowed: ['id', 'change_id', 'record_id', 'employee_id', 'full_name', 'project_name', 'change_type', 'effective_date', 'current_designation', 'new_designation', 'previous_salary', 'increment_amount', 'new_salary', 'created_at', 'system_id'], map: {
      'SystemID':'system_id','ChangeID':'change_id','RecordID':'record_id','EmployeeID':'employee_id','FullName':'full_name',
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
    leaves:  { table: 'leaves',  pk: 'leave_id', allowed: ['id', 'leave_id', 'record_id', 'employee_id', 'name', 'type', 'start', 'end', 'days', 'reason', 'status', 'created_at'], map: {} },
    meetings:{ table: 'meetings',pk: 'meeting_id', allowed: ['id', 'meeting_id', 'date_iso', 'title', 'location', 'start_time', 'end_time', 'notes', 'status', 'created_at'], map: {} },

    /* v3.4: Activity log & recruitment archive - now synced to server
       (Column names aligned with supabase_setup.sql) */
    activityLog:        { table: 'activity_log',        pk: 'id', allowed: ['id', 'user_id', 'user_email', 'action', 'table_name', 'record_ref', 'detail', 'created_at'], map: {
      'LogID':'id','UserID':'user_id','UserEmail':'user_email',
      'Action':'action','TableName':'table_name','RecordRef':'record_ref','Detail':'detail',
      'CreatedAt':'created_at' } },
    recruitmentArchive: { table: 'recruitment_archive', pk: 'archive_id', allowed: ['archive_id', 'candidate_name', 'designation', 'project_name', 'result', 'employee_id', 'decided_at', 'notes', 'created_at', 'updated_at'], map: {
      'ArchiveID':'archive_id','CandidateName':'candidate_name','Designation':'designation',
      'ProjectName':'project_name','Result':'result','EmployeeID':'employee_id',
      'DecidedAt':'decided_at','Notes':'notes' } }
  };

  /* ---------- 2. Name Transformation -------------------------------------- */
  function camelToSnake(s) {
    return String(s)
      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
      .replace(/[\s\-]+/g, '_')
      .replace(/_+/g, '_')
      .toLowerCase().replace(/^_|_$/g, '');
  }
    function toDb(key, rec) {
    var m = TABLE_MAP[key], out = {}, k, col, v;
    var allowed = m.allowed || [];
    for (k in rec) {
      if (!Object.prototype.hasOwnProperty.call(rec, k)) continue;
      if (k.charAt(0) === '_') continue;
      col = (m.map && m.map[k]) || camelToSnake(k);
      if (allowed.length && allowed.indexOf(col) === -1) continue;
            v = rec[k];
      if (typeof v === 'string' && v.trim() === '') v = null;
      if (v && typeof v === 'string' && (col === 'salary' || col === 'new_salary' || col === 'previous_salary' || col === 'increment_amount')) {
        v = v.replace(/,/g, '');
        if (isNaN(Number(v))) v = 0;
      }
      out[col] = v;

    }
    delete out.created_at; delete out.updated_at;
    if (out.id === undefined || out.id === null) delete out.id;  // identity column
    return out;
  }
  function fromDb(key, row) {

  var sb = null, cfg = {}, user = null, ready = false;

  function connect(config) {
    cfg = config || {};
    if (!cfg.url || !cfg.anonKey) {
      return Promise.reject(new Error('Supabase URL or anon key missing'));
    }
    if (!global.supabase || !global.supabase.createClient) {
      return Promise.reject(new Error('supabase-js not loaded — check internet connection'));
    }
    sb = global.supabase.createClient(cfg.url, cfg.anonKey, {
      auth: { persistSession: true, autoRefreshToken: true, storageKey: 'mghrm_auth' }
    });
    ready = true;
    return Promise.resolve(true);
  }

  function isReady() { return ready; }

  /* ---------- Auth ---------- */
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

  /* ---------- Read All ---------- */
  function loadAll() {
    var keys = Object.keys(TABLE_MAP);
    return Promise.all(keys.map(function (k) {
      return sb.from(TABLE_MAP[k].table).select('*')
        .then(function (r) {
          if (r.error) { console.warn('[Supabase] load ' + k, r.error.message); return [k, []]; }
          return [k, (r.data || []).map(function (row) { return fromDb(k, row); })];
        });
    })).then(function (pairs) {
      var out = {};
      pairs.forEach(function (p) { out[p[0]] = p[1]; });
      return out;
    });
  }

  /* ---------- Real-Time WebSockets ---------- */
  function subscribeRealtime() {
    console.log('[Supabase] Initializing Real-Time WebSockets...');
    sb.channel('custom-all-channel')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public' },
        function(payload) {
          console.log('⚡ [Real-Time] Remote change received:', payload);
          handleRealtimeEvent(payload);
        }
      )
      .subscribe(function(status) {
        if (status === 'SUBSCRIBED') {
          console.log('✅ [Real-Time] Connected to Supabase WebSockets');
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          console.error('❌ [Real-Time] Disconnected or Error:', status);
        }
      });
  }

  function handleRealtimeEvent(payload) {
    var table = payload.table;
    var eventType = payload.eventType; // 'INSERT', 'UPDATE', 'DELETE'
    
    var bucket = null, pk = null;
    for (var k in TABLE_MAP) {
      if (TABLE_MAP[k].table === table) {
        bucket = k;
        pk = TABLE_MAP[k].pk;
        break;
      }
    }
    
    if (!bucket || !global.DATA[bucket]) return;
    var dataArr = global.DATA[bucket];
    
    if (eventType === 'DELETE') {
        var deletedId = payload.old.id;
        var idx = dataArr.findIndex(function(x) { return String(x.id) === String(deletedId); });
        if (idx !== -1) dataArr.splice(idx, 1);
    } else {
        var jsRecord = fromDb(bucket, payload.new);
        // Find existing record by frontend primary key mapping
        var localPkField = null;
        for (var c in TABLE_MAP[bucket].map || {}) {
            if (TABLE_MAP[bucket].map[c] === pk) { localPkField = c; break; }
        }
        var pkValue = jsRecord[localPkField] || jsRecord[pk];
        
        var idx = dataArr.findIndex(function(x) { return String(x[localPkField] || x[pk]) === String(pkValue); });
        
        if (eventType === 'INSERT') {
            if (idx === -1) dataArr.unshift(jsRecord);
        } else if (eventType === 'UPDATE') {
            if (idx !== -1) dataArr[idx] = Object.assign(dataArr[idx], jsRecord);
        }
    }

    if (typeof global.refreshAll === 'function') global.refreshAll();
  }

  
  /* ---------- Auto-Sync Proxy for Legacy UI ---------- */
  var _isRealtimeEvent = false;

  function bindDirectCrudProxy(data, bucket) {
    var originalPush = data.push;
    var originalUnshift = data.unshift;
    var originalSplice = data.splice;

    data.push = function() {
      var args = Array.prototype.slice.call(arguments);
      var res = originalPush.apply(this, args);
      if (!_isRealtimeEvent) {
        args.forEach(function(item) { insert(bucket, item); });
      }
      return res;
    };

    data.unshift = function() {
      var args = Array.prototype.slice.call(arguments);
      var res = originalUnshift.apply(this, args);
      if (!_isRealtimeEvent) {
        args.forEach(function(item) { insert(bucket, item); });
      }
      return res;
    };

    data.splice = function() {
      var args = Array.prototype.slice.call(arguments);
      var start = args[0];
      var deleteCount = args[1];
      
      // If items are being added/updated via splice
      var itemsToAdd = args.slice(2);
      
      // Capture what is being removed before actually splicing
      var removedItems = [];
      if (deleteCount > 0) {
        for(var i = 0; i < deleteCount; i++) {
          if (this[start + i]) removedItems.push(this[start + i]);
        }
      }

      var res = originalSplice.apply(this, args);

      if (!_isRealtimeEvent) {
        // Handle deletions
        removedItems.forEach(function(item) {
           var pkName = TABLE_MAP[bucket].pk;
           // Find the front-end mapped key
           var localPkField = null;
           for (var c in TABLE_MAP[bucket].map || {}) {
               if (TABLE_MAP[bucket].map[c] === pkName) { localPkField = c; break; }
           }
           var pkValue = item[localPkField] || item[pkName] || item.id;
           if (pkValue) remove(bucket, pkName, pkValue);
        });
        
        // Handle insertions via splice
        itemsToAdd.forEach(function(item) { insert(bucket, item); });
      }
      return res;
    };
  }

  // Inject bindings when data is loaded
  var originalLoadAll = loadAll;
  loadAll = function() {
    return originalLoadAll().then(function(out) {
      for (var bucket in out) {
        bindDirectCrudProxy(out[bucket], bucket);
      }
      return out;
    });
  };

  // Wrap the realtime handler to prevent infinite loops
  var originalHandleRealtime = handleRealtimeEvent;
  handleRealtimeEvent = function(payload) {
    _isRealtimeEvent = true;
    originalHandleRealtime(payload);
    _isRealtimeEvent = false;
  };

  /* ---------- Direct Server CRUD ---------- */
  function insert(bucket, jsObject) {
    var table = TABLE_MAP[bucket].table;
    var dbRecord = toDb(bucket, jsObject);
    return sb.from(table).insert([dbRecord]).select().then(function(r) {
        if (r.error) {
            console.error('[Supabase Insert Error] ' + table + ':', r.error.message);
            if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
            throw r.error;
        }
        return r.data;
    });
  }

  function update(bucket, primaryKeyName, primaryKeyValue, jsObject) {
    var table = TABLE_MAP[bucket].table;
    var dbRecord = toDb(bucket, jsObject);
    var dbPkColumn = TABLE_MAP[bucket].map[primaryKeyName] || primaryKeyName;

    return sb.from(table).update(dbRecord).eq(dbPkColumn, primaryKeyValue).select().then(function(r) {
        if (r.error) {
            console.error('[Supabase Update Error] ' + table + ':', r.error.message);
            if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
            throw r.error;
        }
        return r.data;
    });
  }

  function remove(bucket, primaryKeyName, primaryKeyValue) {
    var table = TABLE_MAP[bucket].table;
    var dbPkColumn = TABLE_MAP[bucket].map[primaryKeyName] || primaryKeyName;

    return sb.from(table).delete().eq(dbPkColumn, primaryKeyValue).then(function(r) {
        if (r.error) {
            console.error('[Supabase Delete Error] ' + table + ':', r.error.message);
            if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
            throw r.error;
        }
        return true;
    });
  }

  /* Admin Helpers */
  function raw() { return sb; }
  function sqlView(table) { return sb.from(table).select('*'); }

  global.MGHRM = {
    connect: connect, isReady: isReady,
    signIn: signIn, signUp: signUp, signOut: signOut,
    getSession: getSession, onChange: onChange, currentUser: currentUser, myProfile: myProfile,
    loadAll: loadAll, subscribeRealtime: subscribeRealtime,
    insert: insert, update: update, remove: remove,
    TABLE_MAP: TABLE_MAP, toDb: toDb, fromDb: fromDb,
    _client: raw, _view: sqlView,
    version: '2.0.0' // Upgraded to Real-Time
  };

})(window);

  /* ---------- Memory-based Auto-Sync (Replaces LocalStorage sync) ---------- */
  var memoryHashes = {};
  var pushTimer = null;
  var pushing = false;

  function hashOf(obj) {
    var s = typeof obj === 'string' ? obj : JSON.stringify(obj);
    var h = 5381, i = s.length;
    while (i) h = ((h * 33) ^ s.charCodeAt(--i)) >>> 0;
    return h;
  }

  function pushAll() {
    if (pushTimer) clearTimeout(pushTimer);
    pushTimer = setTimeout(doPush, 1000);
  }

  function doPush() {
    if (!ready || pushing) return Promise.resolve();
    var src = global.DATA || {};
    var jobs = [], names = [];

    Object.keys(TABLE_MAP).forEach(function(k) {
      var arr = src[k];
      if (!Array.isArray(arr) || !arr.length) return;
      var h = hashOf(arr);
      if (memoryHashes[k] === h) return; // Unchanged
      
      memoryHashes[k] = h;
      names.push(k);
      
      // Batch Upsert
      var m = TABLE_MAP[k];
      var clean = arr.map(function(r) { return toDb(k, r); });
      var p = sb.from(m.table).upsert(clean, { onConflict: m.pk }).then(function(r) {
        if (r.error) throw r.error;
      });
      jobs.push(p);
    });

    if (!jobs.length) return Promise.resolve();
    pushing = true;
    return Promise.all(jobs).then(function() {
      console.log('⚡ [Auto-Sync] Server synced:', names.join(', '));
    }).catch(function(e) {
      console.error('❌ [Auto-Sync Error]:', e.message || e);
      if (global.toast) global.toast('Sync failed: ' + (e.message || e), 'error');
    }).finally(function() {
      pushing = false;
    });
  }

  global.MGHRM.pushAll = pushAll;
