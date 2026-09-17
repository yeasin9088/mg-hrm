/* =====================================================================
   MG SECURITY HRM — Supabase Data Layer (Real-Time Server-Side)
   Universal Root Identifier: id (Supabase Auto-Incrementing Primary Key)
   ===================================================================== */
(function (global) {
  'use strict';

  /* ---------- 1. Table & Column Mapping -------------------------------- */
  var TABLE_MAP = {
    employees: {
      table: 'employees',
      pk: 'id',
      allowed: [
        'id', 'record_id', 'employee_id', 'full_name', 'full_name_bn',
        'father_name', 'mother_name', 'dob', 'phone', 'nid', 'education', 'religion',
        'height', 'weight', 'marital_status', 'spouse_name', 'spouse_phone',
        'ec_name', 'ec_relation', 'ec_phone', 'division', 'district', 'thana',
        'address', 'address_bn', 'division_id', 'district_id', 'upazila_id',
        'union_id', 'village', 'street', 'designation', 'project_name',
        'join_date', 'duty_hour', 'salary', 'status', 'exit_date', 'exit_reason',
        'remarks', 'photo_url', 'created_at', 'updated_at'
      ],
      map: {
        'id': 'id',
        'record_id': 'record_id',
        'RecordID': 'record_id',
        'EmployeeID': 'employee_id',
        'FullName': 'full_name',
        'FullNameBn': 'full_name_bn',
        'FullNameBangla': 'full_name_bn',
        'FatherName': 'father_name',
        'MotherName': 'mother_name',
        'DOB': 'dob',
        'PhoneNumber': 'phone',
        'NID': 'nid',
        'Education': 'education',
        'Religion': 'religion',
        'Height': 'height',
        'Weight': 'weight',
        'MaritalStatus': 'marital_status',
        'SpouseName': 'spouse_name',
        'SpousePhone': 'spouse_phone',
        'EmergencyName': 'ec_name',
        'EmergencyRelation': 'ec_relation',
        'EmergencyPhone': 'ec_phone',
        'Division': 'division',
        'District': 'district',
        'Thana': 'thana',
        'Address': 'address',
        'AddressBangla': 'address_bn',
        'Designation': 'designation',
        'ProjectName': 'project_name',
        'JoinDate': 'join_date',
        'DutyHour': 'duty_hour',
        'Salary': 'salary',
        'Status': 'status',
        'ExitDate': 'exit_date',
        'ExitReason': 'exit_reason',
        'Remarks': 'remarks',
        'PhotoURL': 'photo_url'
      }
    },

    projects: {
      table: 'projects',
      pk: 'id',
      allowed: [
        'id', 'project_name', 'project_name_bn', 'address', 'address_bn',
        'main_gate_phone', 'admin_name', 'admin_phone', 'admin_whatsapp',
        'division', 'district', 'thana', 'division_id', 'district_id',
        'upazila_id', 'union_id', 'village', 'street', 'start_date',
        'status', 'is_active', 'created_at', 'updated_at'
      ],
      map: {
        'Project ID': 'id',
        'ProjectName': 'project_name',
        'ProjectNameBangla': 'project_name_bn',
        'Address': 'address',
        'AddressBangla': 'address_bn',
        'Main Gate Phone Num': 'main_gate_phone',
        'Admin Name': 'admin_name',
        'Admin Phone Num': 'admin_phone',
        'Admin WhatsApp Num': 'admin_whatsapp',
        'Division': 'division',
        'District': 'district',
        'Thana': 'thana',
        'StartDate': 'start_date',
        'Status': 'status'
      }
    },

    demand: {
      table: 'demand',
      pk: 'id',
      allowed: [
        'id', 'project_name', 'demand_incharge', 'demand_supervisor',
        'demand_assst_sup', 'demand_guard', 'demand_lady_guard',
        'demand_total', 'updated_at'
      ],
      map: {
        'ID': 'id',
        'ProjectName': 'project_name',
        'DemandSecurityIncharge': 'demand_incharge',
        'DemandSecuritySupervisor': 'demand_supervisor',
        'DemandAsstSecuritySupervisor': 'demand_assst_sup',
        'DemandSecurityGuard': 'demand_guard',
        'DemandLadyGuard': 'demand_lady_guard',
        'DemandTotal': 'demand_total'
      }
    },

    disciplinary: {
      table: 'disciplinary',
      pk: 'action_id',
      allowed: [
        'id', 'action_id', 'ref_no', 'ref_no_bn',
        'employee_id', 'employee_id_bn', 'full_name', 'full_name_bn',
        'designation', 'designation_bn', 'project_name', 'project_name_bn',
        'action_type', 'issue_date', 'issue_date_bn', 'incident_date',
        'description', 'description_bn', 'created_at'
      ],
      map: {
        'ActionID': 'action_id',
        'RefNo': 'ref_no',
        'RefNoBangla': 'ref_no_bn',
        'EmployeeID': 'employee_id',
        'EmployeeIDBangla': 'employee_id_bn',
        'FullName': 'full_name',
        'FullNameBangla': 'full_name_bn',
        'Designation': 'designation',
        'DesignationBangla': 'designation_bn',
        'ProjectName': 'project_name',
        'ProjectNameBangla': 'project_name_bn',
        'ActionType': 'action_type',
        'IssueDate': 'issue_date',
        'IssueDateBangla': 'issue_date_bn',
        'IncidentDate': 'incident_date',
        'Description': 'description',
        'DescriptionBangla': 'description_bn'
      }
    },

    exits: {
      table: 'exits',
      pk: 'exit_id',
      allowed: [
        'id', 'exit_id', 'employee_id',
        'full_name', 'designation', 'current_project', 'join_date',
        'exit_reason', 'exit_date', 'issue_date', 'created_at'
      ],
      map: {
        'ExitID': 'exit_id',
        'EmployeeID': 'employee_id',
        'FullName': 'full_name',
        'Designation': 'designation',
        'CurrentProject': 'current_project',
        'JoinDate': 'join_date',
        'ExitReason': 'exit_reason',
        'ExitDate': 'exit_date',
        'IssueDate': 'issue_date'
      }
    },

    transfers: {
      table: 'transfers',
      pk: 'transfer_id',
      allowed: [
        'id', 'transfer_id', 'employee_id',
        'employee_id_bn', 'full_name', 'full_name_bn', 'designation',
        'designation_bn', 'current_project', 'current_project_bn',
        'new_project', 'new_project_bn', 'transfer_date', 'transfer_date_bn',
        'issues_date', 'issues_date_bn', 'is_proceed', 'status', 'notes', 'created_at'
      ],
      map: {
        'TransferID': 'transfer_id',
        'EmployeeID': 'employee_id',
        'EmployeeIDBangla': 'employee_id_bn',
        'FullName': 'full_name',
        'FullNameBangla': 'full_name_bn',
        'Designation': 'designation',
        'DesignationBangla': 'designation_bn',
        'CurrentProject': 'current_project',
        'CurrentProjectBangla': 'current_project_bn',
        'NewProject': 'new_project',
        'NewProjectBangla': 'new_project_bn',
        'TransferDate': 'transfer_date',
        'TransferDateBangla': 'transfer_date_bn',
        'Issues Date': 'issues_date',
        'Issues DateBangla': 'issues_date_bn',
        'IsProceed': 'is_proceed',
        'Status': 'status',
        'Notes': 'notes'
      }
    },

    career: {
      table: 'career',
      pk: 'change_id',
      allowed: [
        'id', 'change_id', 'employee_id',
        'full_name', 'project_name', 'change_type', 'effective_date',
        'current_designation', 'new_designation', 'previous_salary',
        'increment_amount', 'new_salary', 'notes', 'created_at'
      ],
      map: {
        'ChangeID': 'change_id',
        'EmployeeID': 'employee_id',
        'FullName': 'full_name',
        'ProjectName': 'project_name',
        'ChangeType': 'change_type',
        'EffectiveDate': 'effective_date',
        'CurrentDesignation': 'current_designation',
        'NewDesignation': 'new_designation',
        'PreviousSalary': 'previous_salary',
        'IncrementAmount': 'increment_amount',
        'NewSalary': 'new_salary',
        'Notes': 'notes'
      }
    },

    leaves: {
      table: 'leaves',
      pk: 'leave_id',
      allowed: [
        'id', 'leave_id', 'employee_id',
        'full_name', 'designation', 'project_name', 'leave_type',
        'from_date', 'to_date', 'days_count', 'reason', 'status',
        'applied_on', 'approved_by', 'created_at'
      ],
      map: {
        'LeaveID': 'leave_id',
        'id': 'leave_id',
        'EmployeeID': 'employee_id',
        'empId': 'employee_id',
        'FullName': 'full_name',
        'name': 'full_name',
        'Designation': 'designation',
        'ProjectName': 'project_name',
        'LeaveType': 'leave_type',
        'type': 'leave_type',
        'StartDate': 'from_date',
        'start': 'from_date',
        'EndDate': 'to_date',
        'end': 'to_date',
        'Days': 'days_count',
        'days': 'days_count',
        'Reason': 'reason',
        'Status': 'status',
        'AppliedOn': 'applied_on',
        'ApprovedBy': 'approved_by'
      }
    },

    uniform: {
      table: 'uniform',
      pk: 'issue_id',
      allowed: [
        'id', 'issue_id', 'employee_id',
        'full_name', 'designation', 'project_name', 'item_name',
        'size_text', 'quantity', 'issue_date', 'return_date',
        'condition_text', 'status', 'remarks', 'created_at'
      ],
      map: {
        'IssueID': 'issue_id',
        'EmployeeID': 'employee_id',
        'FullName': 'full_name',
        'Designation': 'designation',
        'ProjectName': 'project_name',
        'ItemName': 'item_name',
        'Size': 'size_text',
        'Quantity': 'quantity',
        'IssueDate': 'issue_date',
        'ReturnDate': 'return_date',
        'Condition': 'condition_text',
        'Status': 'status',
        'Remarks': 'remarks'
      }
    },

    meetings: {
      table: 'meetings',
      pk: 'meeting_id',
      allowed: [
        'id', 'meeting_id', 'meeting_date', 'title', 'venue', 'agenda',
        'created_by', 'created_at'
      ],
      map: {
        'MeetingID': 'meeting_id',
        'MeetingDate': 'meeting_date',
        'Title': 'title',
        'Venue': 'venue',
        'Agenda': 'agenda',
        'CreatedBy': 'created_by'
      }
    },

    meetingAttendance: {
      table: 'meeting_attendance',
      pk: 'id',
      allowed: [
        'id', 'meeting_id', 'employee_id', 'full_name',
        'designation', 'project_name', 'status', 'remarks'
      ],
      map: {
        'MeetingID': 'meeting_id',
        'EmployeeID': 'employee_id',
        'FullName': 'full_name',
        'Designation': 'designation',
        'ProjectName': 'project_name',
        'Status': 'status',
        'Remarks': 'remarks'
      }
    },

    divisions: {
      table: 'divisions',
      pk: 'division_id',
      map: {
        'Division ID': 'division_id',
        'Division Name': 'division_name'
      }
    },

    districts: {
      table: 'districts',
      pk: 'district_id',
      map: {
        'Districts ID': 'district_id',
        'Division ID': 'division_id',
        'Districts Name': 'district_name'
      }
    },

    thana: {
      table: 'thanas',
      pk: 'thana_id',
      map: {
        'Thana ID': 'thana_id',
        'Districts ID': 'district_id',
        'Thana Name': 'thana_name'
      }
    },

    desigBangla: {
      table: 'designations',
      pk: 'desig_id',
      map: {
        'ID': 'desig_id',
        'Designation': 'designation',
        'DesignationBangla': 'designation_bn'
      }
    },

    activityLog: {
      table: 'activity_log',
      pk: 'id',
      allowed: [
        'id', 'user_id', 'user_email', 'action', 'table_name',
        'record_ref', 'detail', 'created_at'
      ],
      map: {
        'LogID': 'id',
        'UserID': 'user_id',
        'UserEmail': 'user_email',
        'Action': 'action',
        'TableName': 'table_name',
        'RecordRef': 'record_ref',
        'Detail': 'detail',
        'CreatedAt': 'created_at'
      }
    },

    recruitmentArchive: {
      table: 'recruitment_archive',
      pk: 'archive_id',
      allowed: [
        'archive_id', 'candidate_name', 'designation', 'project_name',
        'result', 'employee_id', 'decided_at', 'notes', 'created_at', 'updated_at'
      ],
      map: {
        'ArchiveID': 'archive_id',
        'CandidateName': 'candidate_name',
        'Designation': 'designation',
        'ProjectName': 'project_name',
        'Result': 'result',
        'EmployeeID': 'employee_id',
        'DecidedAt': 'decided_at',
        'Notes': 'notes'
      }
    }
  };

  /* ---------- 2. Name Transformation -------------------------------------- */
  function camelToSnake(s) {
    return String(s)
      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
      .replace(/[\s\-]+/g, '_')
      .replace(/_+/g, '_')
      .toLowerCase()
      .replace(/^_|_$/g, '');
  }

  function toDb(key, rec) {
    var m = TABLE_MAP[key];
    if (!m) return rec;
    var out = {}, k, col, v;
    var allowed = m.allowed || [];

    for (k in rec) {
      if (!Object.prototype.hasOwnProperty.call(rec, k)) continue;
      if (k.charAt(0) === '_') continue;
      col = (m.map && m.map[k]) || camelToSnake(k);
      if (allowed.length && allowed.indexOf(col) === -1) continue;
      v = rec[k];
      if (typeof v === 'string' && v.trim() === '') v = null;
      if (
        v &&
        typeof v === 'string' &&
        (col === 'salary' ||
          col === 'new_salary' ||
          col === 'previous_salary' ||
          col === 'increment_amount')
      ) {
        v = v.replace(/,/g, '');
        if (isNaN(Number(v))) v = 0;
      }
      out[col] = v;
    }
    delete out.created_at;
    delete out.updated_at;
    if (out.id === undefined || out.id === null) delete out.id;
    return out;
  }

  function fromDb(key, row) {
    if (!row) return row;
    var m = TABLE_MAP[key] || {};
    var map = m.map || {};
    var reverseMap = {};
    for (var k in map) {
      if (Object.prototype.hasOwnProperty.call(map, k)) {
        reverseMap[map[k]] = k;
      }
    }
    var out = {};
    for (var col in row) {
      if (!Object.prototype.hasOwnProperty.call(row, col)) continue;
      var jsKey = reverseMap[col] || col;
      out[jsKey] = row[col];
      // Keep direct column name as well
      out[col] = row[col];
    }
    // Explicit root identifier enforcement
    if (row.id != null) out.id = row.id;
    if (row.employee_id && !out.EmployeeID) out.EmployeeID = row.employee_id;
    if (row.full_name && !out.FullName) out.FullName = row.full_name;
    return out;
  }

  /* ---------- 3. Supabase Client & Lifecycle ----------------------------- */
  var sb = null,
    cfg = {},
    user = null,
    ready = false;

  // Ensure window.sb is always defined as a global getter/setter
  try {
    Object.defineProperty(global, 'sb', {
      get: function () {
        return sb;
      },
      set: function (v) {
        sb = v;
      },
      configurable: true,
      enumerable: true
    });
  } catch (e) {
    global.sb = sb;
  }

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
    global.sb = sb;
    global.supabaseClient = sb;
    if (global.MGHRM) {
      global.MGHRM.client = sb;
      global.MGHRM.sb = sb;
    }
    return Promise.resolve(true);
  }

  function isReady() {
    return ready && !!sb;
  }

  /* ---------- Auth ---------- */
  function signIn(email, password) {
    if (!sb) {
      var c = global.MGHRM_CONFIG;
      if (c && c.url && c.anonKey && String(c.url).indexOf('PASTE_') !== 0) {
        return connect(c).then(function () {
          return signIn(email, password);
        });
      }
      return Promise.reject(new Error('Database not connected. Please setup connection first.'));
    }
    return sb.auth.signInWithPassword({ email: email, password: password }).then(function (r) {
      if (r.error) throw r.error;
      user = r.data.user;
      return user;
    });
  }

  function signUp(email, password, fullName) {
    if (!sb) {
      var c = global.MGHRM_CONFIG;
      if (c && c.url && c.anonKey && String(c.url).indexOf('PASTE_') !== 0) {
        return connect(c).then(function () {
          return signUp(email, password, fullName);
        });
      }
      return Promise.reject(new Error('Database not connected. Please setup connection first.'));
    }
    return sb.auth
      .signUp({
        email: email,
        password: password,
        options: { data: { full_name: fullName || email } }
      })
      .then(function (r) {
        if (r.error) throw r.error;
        return r.data;
      });
  }

  function signOut() {
    if (!sb) {
      user = null;
      return Promise.resolve();
    }
    return sb.auth.signOut().then(function () {
      user = null;
    });
  }

  function getSession() {
    if (!sb) {
      var c = global.MGHRM_CONFIG;
      if (c && c.url && c.anonKey && String(c.url).indexOf('PASTE_') !== 0) {
        return connect(c).then(function () {
          return getSession();
        });
      }
      return Promise.resolve(null);
    }
    return sb.auth.getSession().then(function (r) {
      user = r.data && r.data.session ? r.data.session.user : null;
      return r.data ? r.data.session : null;
    });
  }

  function onChange(cb) {
    if (!sb) {
      var c = global.MGHRM_CONFIG;
      if (c && c.url && c.anonKey && String(c.url).indexOf('PASTE_') !== 0) {
        connect(c).then(function () {
          onChange(cb);
        });
      }
      return;
    }
    sb.auth.onAuthStateChange(function (ev, s) {
      cb(ev, s);
    });
  }

  function currentUser() {
    return user;
  }

  function myProfile() {
    var client = sb || global.sb;
    if (!user || !client) return Promise.resolve(null);
    return client
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle()
      .then(function (r) {
        return r.data;
      });
  }

  /* ---------- Read All ---------- */
  function loadAll() {
    var client = sb || global.sb;
    if (!client) {
      console.warn('[Supabase] loadAll: Supabase client not initialized');
      var emptyOut = {};
      Object.keys(TABLE_MAP).forEach(function (k) {
        emptyOut[k] = [];
      });
      return Promise.resolve(emptyOut);
    }
    var keys = Object.keys(TABLE_MAP);
    return Promise.all(
      keys.map(function (k) {
        return client
          .from(TABLE_MAP[k].table)
          .select('*')
          .then(function (r) {
            if (r.error) {
              console.warn('[Supabase] load ' + k, r.error.message);
              return [k, []];
            }
            return [
              k,
              (r.data || []).map(function (row) {
                var rec = fromDb(k, row);
                if (k === 'projects' && typeof global.normProject === 'function') {
                  rec = global.normProject(rec);
                }
                return rec;
              })
            ];
          });
      })
    ).then(function (pairs) {
      var out = {};
      pairs.forEach(function (p) {
        out[p[0]] = p[1];
      });
      return out;
    });
  }

  /* ---------- Real-Time WebSockets ---------- */
  function subscribeRealtime() {
    console.log('[Supabase] Initializing Real-Time WebSockets...');
    var client = (typeof _client === 'function' ? _client() : null) || sb || global.sb;
    if (!client) {
      console.warn('[Real-Time] Supabase client not initialized yet');
      return null;
    }

    // Explicit channel for projects table real-time events
    try {
      client.channel('projects-realtime')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'projects' }, function (payload) {
          console.log('⚡ [Real-Time] Projects table changed:', payload);
          if (typeof global.handleProjectRealtimeUpdate === 'function') {
            global.handleProjectRealtimeUpdate(payload);
          } else {
            handleRealtimeEvent(payload);
          }
        })
        .subscribe();
    } catch (e) {
      console.warn('[Real-Time] projects-realtime subscription error:', e);
    }

    // Explicit channel for employees table real-time events
    try {
      client.channel('employees-realtime')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'employees' }, function (payload) {
          console.log('⚡ [Real-Time] Employees table changed:', payload);
          if (typeof global.handleEmployeeRealtimeUpdate === 'function') {
            global.handleEmployeeRealtimeUpdate(payload);
          } else {
            handleRealtimeEvent(payload);
          }
        })
        .subscribe();
    } catch (e) {
      console.warn('[Real-Time] employees-realtime subscription error:', e);
    }

    return client.channel('custom-all-channel')
      .on('postgres_changes', { event: '*', schema: 'public' }, function (payload) {
        console.log('⚡ [Real-Time] Remote change received:', payload);
        handleRealtimeEvent(payload);
      })
      .subscribe(function (status) {
        if (status === 'SUBSCRIBED') {
          console.log('✅ [Real-Time] Connected to Supabase WebSockets');
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          console.error('❌ [Real-Time] Disconnected or Error:', status);
        }
      });
  }

  function handleRealtimeEvent(payload) {
    if (payload && payload.table === 'projects' && typeof global.handleProjectRealtimeUpdate === 'function') {
      global.handleProjectRealtimeUpdate(payload);
      return;
    }
    if (payload && payload.table === 'employees' && typeof global.handleEmployeeRealtimeUpdate === 'function') {
      global.handleEmployeeRealtimeUpdate(payload);
      return;
    }

    var table = payload.table;
    var eventType = payload.eventType; // 'INSERT', 'UPDATE', 'DELETE'

    var bucket = null,
      pk = null;
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
      var idx = dataArr.findIndex(function (x) {
        return String(x.id) === String(deletedId);
      });
      if (idx !== -1) dataArr.splice(idx, 1);
    } else {
      var jsRecord = fromDb(bucket, payload.new);
      var localPkField = null;
      for (var c in TABLE_MAP[bucket].map || {}) {
        if (TABLE_MAP[bucket].map[c] === pk) {
          localPkField = c;
          break;
        }
      }
      var pkValue = jsRecord[localPkField] || jsRecord[pk];

      var idx = dataArr.findIndex(function (x) {
        return String(x[localPkField] || x[pk]) === String(pkValue);
      });

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

    data.push = function () {
      var args = Array.prototype.slice.call(arguments);
      var res = originalPush.apply(this, args);
      if (!_isRealtimeEvent) {
        args.forEach(function (item) {
          insert(bucket, item);
        });
      }
      return res;
    };

    data.unshift = function () {
      var args = Array.prototype.slice.call(arguments);
      var res = originalUnshift.apply(this, args);
      if (!_isRealtimeEvent) {
        args.forEach(function (item) {
          insert(bucket, item);
        });
      }
      return res;
    };

    data.splice = function () {
      var args = Array.prototype.slice.call(arguments);
      var start = args[0];
      var deleteCount = args[1];
      var itemsToAdd = args.slice(2);
      var removedItems = [];

      if (deleteCount > 0) {
        for (var i = 0; i < deleteCount; i++) {
          if (this[start + i]) removedItems.push(this[start + i]);
        }
      }

      var res = originalSplice.apply(this, args);

      if (!_isRealtimeEvent) {
        removedItems.forEach(function (item) {
          var pkName = TABLE_MAP[bucket].pk;
          var localPkField = null;
          for (var c in TABLE_MAP[bucket].map || {}) {
            if (TABLE_MAP[bucket].map[c] === pkName) {
              localPkField = c;
              break;
            }
          }
          var pkValue = item[localPkField] || item[pkName] || item.id;
          if (pkValue) remove(bucket, pkName, pkValue);
        });

        itemsToAdd.forEach(function (item) {
          insert(bucket, item);
        });
      }
      return res;
    };
  }

  var originalLoadAll = loadAll;
  loadAll = function () {
    return originalLoadAll().then(function (out) {
      for (var bucket in out) {
        bindDirectCrudProxy(out[bucket], bucket);
      }
      return out;
    });
  };

  var originalHandleRealtime = handleRealtimeEvent;
  handleRealtimeEvent = function (payload) {
    _isRealtimeEvent = true;
    originalHandleRealtime(payload);
    _isRealtimeEvent = false;
  };

  /* ---------- Direct Server CRUD ---------- */
  function insert(bucket, jsObject) {
    if (!ready || !sb) return Promise.resolve(null);
    var table = TABLE_MAP[bucket].table;
    var dbRecord = toDb(bucket, jsObject);
    return sb
      .from(table)
      .insert([dbRecord])
      .select()
      .then(function (r) {
        if (r.error) {
          console.error('[Supabase Insert Error] ' + table + ':', r.error.message);
          if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
          throw r.error;
        }
        return r.data;
      });
  }

  function update(bucket, primaryKeyName, primaryKeyValue, jsObject) {
    if (!ready || !sb) return Promise.resolve(null);
    if (arguments.length === 3) {
      jsObject = primaryKeyValue;
      primaryKeyValue = primaryKeyName;
      primaryKeyName = (TABLE_MAP[bucket] && TABLE_MAP[bucket].pk) || 'id';
    }
    var table = TABLE_MAP[bucket].table;
    var dbRecord = toDb(bucket, jsObject);
    var dbPkColumn = (TABLE_MAP[bucket].map && TABLE_MAP[bucket].map[primaryKeyName]) || primaryKeyName;

    return sb
      .from(table)
      .update(dbRecord)
      .eq(dbPkColumn, primaryKeyValue)
      .select()
      .then(function (r) {
        if (r.error) {
          console.error('[Supabase Update Error] ' + table + ':', r.error.message);
          if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
          throw r.error;
        }
        return r.data;
      });
  }

  function remove(bucket, primaryKeyName, primaryKeyValue) {
    if (!ready || !sb) return Promise.resolve(null);
    if (arguments.length === 2) {
      primaryKeyValue = primaryKeyName;
      primaryKeyName = (TABLE_MAP[bucket] && TABLE_MAP[bucket].pk) || 'id';
    }
    var table = TABLE_MAP[bucket].table;
    var dbPkColumn = (TABLE_MAP[bucket].map && TABLE_MAP[bucket].map[primaryKeyName]) || primaryKeyName;

    return sb
      .from(table)
      .delete()
      .eq(dbPkColumn, primaryKeyValue)
      .then(function (r) {
        if (r.error) {
          console.error('[Supabase Delete Error] ' + table + ':', r.error.message);
          if (global.toast) global.toast('Server Error: ' + r.error.message, 'error');
          throw r.error;
        }
        return true;
      });
  }

  /* ---------- Real-Time Auto-Fetch by Primary Key ID or EmployeeID ---------- */
  function fetchEmployeeById(id) {
    if (!id) return Promise.resolve(null);
    var idStr = String(id).trim();

    // 1. Check local cache first
    if (global.DATA && Array.isArray(global.DATA.employees)) {
      var foundLocal = global.DATA.employees.find(function (e) {
        return (
          String(e.id || '').trim() === idStr ||
          String(e.EmployeeID || '').trim() === idStr ||
          String(e.RecordID || '').trim() === idStr
        );
      });
      if (foundLocal) return Promise.resolve(foundLocal);
    }

    // 2. Query Supabase server directly in real-time
    if (!ready || !sb) return Promise.resolve(null);

    var query = /^\d+$/.test(idStr)
      ? sb.from('employees').select('*').or('id.eq.' + idStr + ',employee_id.eq.' + idStr).limit(1)
      : sb.from('employees').select('*').eq('employee_id', idStr).limit(1);

    return query
      .then(function (r) {
        if (r.error || !r.data || !r.data.length) return null;
        var empObj = fromDb('employees', r.data[0]);

        // Cache into local memory if missing
        if (global.DATA && Array.isArray(global.DATA.employees)) {
          var exists = global.DATA.employees.some(function (e) {
            return String(e.id) === String(empObj.id);
          });
          if (!exists) {
            global.DATA.employees.push(empObj);
          }
        }
        return empObj;
      })
      .catch(function (err) {
        console.warn('[Auto-Fetch Employee]', err);
        return null;
      });
  }
  var fetchEmployeeByRecordId = fetchEmployeeById;

  /* ---------- Direct Batch Uploader (For Smart CSV Importer) ---------- */
  function batchUpsert(tableName, rows, onProgress, batchSize) {
    if (!ready || !sb) {
      return Promise.reject(new Error('Supabase client is not connected.'));
    }
    if (!Array.isArray(rows) || !rows.length) {
      return Promise.resolve({ success: true, count: 0 });
    }

    batchSize = batchSize || 50;
    var bucket = null;
    for (var k in TABLE_MAP) {
      if (TABLE_MAP[k].table === tableName || k === tableName) {
        bucket = k;
        tableName = TABLE_MAP[k].table;
        break;
      }
    }

    var pkCol = (bucket && TABLE_MAP[bucket].pk) || 'id';
    var total = rows.length;
    var processed = 0;
    var batches = [];

    for (var i = 0; i < total; i += batchSize) {
      batches.push(rows.slice(i, i + batchSize));
    }

    function runBatch(idx) {
      if (idx >= batches.length) {
        return Promise.resolve({ success: true, count: total });
      }

      var currentBatch = batches[idx].map(function (item) {
        return bucket ? toDb(bucket, item) : item;
      });

      return sb
        .from(tableName)
        .upsert(currentBatch, { onConflict: pkCol })
        .then(function (res) {
          if (res.error) throw res.error;
          processed += currentBatch.length;
          if (typeof onProgress === 'function') {
            var cur = Math.min(processed, total);
            var pct = total > 0 ? Math.round((cur / total) * 100) : 100;
            onProgress({
              processed: cur,
              total: total,
              batch: idx + 1,
              totalBatches: batches.length,
              percent: pct
            }, cur, total, idx + 1, batches.length);
          }
          return runBatch(idx + 1);
        });
    }

    return runBatch(0);
  }

  /* Admin Helpers */
  function raw() {
    return sb || global.sb;
  }
  ['from', 'channel', 'auth', 'storage', 'rpc', 'functions'].forEach(function (m) {
    try {
      Object.defineProperty(raw, m, {
        get: function () {
          var client = sb || global.sb;
          return client && typeof client[m] === 'function' ? client[m].bind(client) : (client ? client[m] : undefined);
        },
        configurable: true,
        enumerable: true
      });
    } catch (e) {}
  });

  function sqlView(table) {
    var client = sb || global.sb;
    return client ? client.from(table).select('*') : null;
  }

  /* ---------- Memory-based Auto-Sync ---------- */
  var memoryHashes = {};
  var pushTimer = null;
  var pushing = false;

  function hashOf(obj) {
    var s = typeof obj === 'string' ? obj : JSON.stringify(obj);
    var h = 5381,
      i = s.length;
    while (i) h = ((h * 33) ^ s.charCodeAt(--i)) >>> 0;
    return h;
  }

  function pushAll() {
    if (pushTimer) clearTimeout(pushTimer);
    pushTimer = setTimeout(doPush, 1000);
  }

  function doPush() {
    if (!ready || pushing || !sb) return Promise.resolve();
    var src = global.DATA || {};
    var jobs = [],
      names = [];

    Object.keys(TABLE_MAP).forEach(function (k) {
      var arr = src[k];
      if (!Array.isArray(arr) || !arr.length) return;
      var h = hashOf(arr);
      if (memoryHashes[k] === h) return;

      memoryHashes[k] = h;
      names.push(k);

      var m = TABLE_MAP[k];
      var clean = arr.map(function (r) {
        return toDb(k, r);
      });
      var p = sb
        .from(m.table)
        .upsert(clean, { onConflict: m.pk })
        .then(function (r) {
          if (r.error) throw r.error;
        });
      jobs.push(p);
    });

    if (!jobs.length) return Promise.resolve();
    pushing = true;
    return Promise.all(jobs)
      .then(function () {
        console.log('⚡ [Auto-Sync] Server synced:', names.join(', '));
      })
      .catch(function (e) {
        console.error('❌ [Auto-Sync Error]:', e.message || e);
        if (global.toast) global.toast('Sync failed: ' + (e.message || e), 'error');
      })
      .finally(function () {
        pushing = false;
      });
  }

  global.MGHRM = {
    connect: connect,
    isReady: isReady,
    signIn: signIn,
    signUp: signUp,
    signOut: signOut,
    getSession: getSession,
    onChange: onChange,
    currentUser: currentUser,
    myProfile: myProfile,
    loadAll: loadAll,
    subscribeRealtime: subscribeRealtime,
    handleRealtimeEvent: handleRealtimeEvent,
    insert: insert,
    update: update,
    remove: remove,
    fetchEmployeeById: fetchEmployeeById,
    fetchEmployeeByRecordId: fetchEmployeeByRecordId,
    batchUpsert: batchUpsert,
    pushAll: pushAll,
    TABLE_MAP: TABLE_MAP,
    toDb: toDb,
    fromDb: fromDb,
    _client: raw,
    _view: sqlView,
    client: sb,
    sb: sb,
    version: '2.1.1'
  };

  // Immediate eager auto-initialization if config is present
  try {
    var c = global.MGHRM_CONFIG;
    if (c && c.url && c.anonKey && String(c.url).indexOf('PASTE_') !== 0 && String(c.anonKey).indexOf('PASTE_') !== 0) {
      connect(c).catch(function () {});
    } else {
      var saved = JSON.parse(localStorage.getItem('mghrm_cfg') || 'null');
      if (saved && saved.url && saved.anonKey) {
        connect(saved).catch(function () {});
      }
    }
  } catch (e) {}
})(window);
