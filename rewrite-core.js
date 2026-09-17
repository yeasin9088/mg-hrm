const fs = require('fs');
const tableMapText = fs.readFileSync('table_map.txt', 'utf8');

// We take everything from TABLE_MAP until the end of fromDb
const tableMapAndHelpers = tableMapText.substring(tableMapText.indexOf('var TABLE_MAP'));

const coreCode = `/* =====================================================================
   MG SECURITY HRM — Supabase Data Layer (Real-Time Server-Side)
   ===================================================================== */
(function (global) {
  'use strict';

  ${tableMapAndHelpers}

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
\`;

fs.writeFileSync('app-core.js', coreCode);
console.log('app-core.js rewritten');

