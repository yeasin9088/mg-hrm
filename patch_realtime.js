const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const realtimeCode = `
  /* ---------- REAL-TIME SUPABASE ARCHITECTURE ---------- */
  function subscribeRealtime() {
    console.log('[Supabase] Initializing Real-Time WebSockets...');
    
    // Listen to all public tables
    const channel = sb.channel('custom-all-channel')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public' },
        (payload) => {
          console.log('[Real-Time] Change received:', payload);
          handleRealtimeEvent(payload);
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('✅ [Real-Time] Connected to Supabase WebSockets');
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          console.error('❌ [Real-Time] Disconnected or Error:', status);
        }
      });
  }

  function handleRealtimeEvent(payload) {
    const table = payload.table;
    const eventType = payload.eventType; // INSERT, UPDATE, DELETE
    const newRow = payload.new;
    const oldRow = payload.old;

    // Find the corresponding local table bucket
    let bucket = null;
    let pk = null;
    for (let k in TABLE_MAP) {
      if (TABLE_MAP[k].table === table) {
        bucket = k;
        pk = TABLE_MAP[k].pk;
        break;
      }
    }
    
    if (!bucket || !window.DATA[bucket]) return;

    const dataArr = window.DATA[bucket];
    const jsRecord = eventType === 'DELETE' ? {} : fromDb(bucket, newRow);

    if (eventType === 'INSERT') {
      // Avoid duplicate if we inserted it locally first
      if (!dataArr.find(x => String(x[pk]) === String(jsRecord[pk]))) {
        dataArr.unshift(jsRecord);
      }
    } else if (eventType === 'UPDATE') {
      const idx = dataArr.findIndex(x => String(x[pk]) === String(jsRecord[pk]));
      if (idx !== -1) {
        dataArr[idx] = Object.assign(dataArr[idx], jsRecord);
      } else {
        dataArr.unshift(jsRecord);
      }
    } else if (eventType === 'DELETE') {
      // Supabase DELETE payload usually only contains the identity/PK
      const deletedPkValue = oldRow.id; // Or resolve the exact mapped PK
      // For precision, we refresh all on delete or do a hard map, 
      // but for now we remove by assuming the local 'id' maps to Supabase 'id'
      const mappedOld = fromDb(bucket, oldRow);
      const idx = dataArr.findIndex(x => String(x[pk]) === String(mappedOld[pk]) || String(x.id) === String(oldRow.id));
      if (idx !== -1) dataArr.splice(idx, 1);
    }

    // Instantly reflect changes in UI
    if (typeof refreshAll === 'function') refreshAll();
  }
`;

// Inject Realtime setup into connect() or startApp()
html = html.replace('function startApp(){', realtimeCode + '\n  function startApp(){\n    subscribeRealtime();');

fs.writeFileSync('index.html', html);
console.log('Realtime Subscriptions added');
