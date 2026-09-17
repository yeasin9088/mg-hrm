const fs = require('fs');
let js = fs.readFileSync('app-core.js', 'utf8');

const monkeyPatchCode = `
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
`;

js = js.replace('/* ---------- Direct Server CRUD ---------- */', monkeyPatchCode + '\n  /* ---------- Direct Server CRUD ---------- */');

fs.writeFileSync('app-core.js', js);
console.log('App-core proxied');
