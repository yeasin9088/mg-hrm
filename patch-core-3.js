const fs = require('fs');
let js = fs.readFileSync('app-core.js', 'utf8');

const pushAllCode = `
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
`;

js += pushAllCode;
fs.writeFileSync('app-core.js', js);
console.log('pushAll restored in memory');
