const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// Replace hookPersist which used to call pushAll
html = html.replace(/function hookPersist\(\)\{[\s\S]*?window\.persist = wrapped;\n  \}/, "function hookPersist(){ /* legacy persist hook removed */ }");

// Replace G.pushAll references
html = html.replace(/try \{ G\.pushAll\(window\.DATA\); \} catch \(e\) \{\}/g, "");
html = html.replace(/G\.pushAll\(window\.DATA\);/g, "");

// Modify startApp to initiate realtime instead of the old seed checks
// Actually, let's just make sure startApp calls G.subscribeRealtime()
html = html.replace(/hookPersist\(\);\s*refreshAll\(\);/g, "hookPersist(); refreshAll();\n      if(typeof G.subscribeRealtime === 'function') G.subscribeRealtime();");

// To support direct CRUD without rewriting 50 different event listeners in index.html,
// we proxy the window.persist to do nothing, and the array mutations are already intercepted in realtime?
// Wait, I did NOT proxy array mutations. I just provided MGHRM.insert(). 
// If I don't proxy array mutations, all the old UI code like `DATA.employees.push` will ONLY change local memory and NEVER hit the server!
// I MUST proxy or monkey-patch the DATA arrays so that legacy UI code actually fires network requests.
// Let's add an auto-sync monkey patch right after loadAll completes!
