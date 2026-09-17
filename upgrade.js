const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// 1. Remove localStorage writes from persist()
html = html.replace(/try\{\s*localStorage\.setItem\(LS_KEY,\s*snapshotState\(\)\);\s*\}catch\(e\)\{\}/g, "/* LocalStorage purged for Direct Server Architecture */");

// 2. Remove localStorage from autobackup and other syncs
html = html.replace(/localStorage\.setItem\('mghrm_villages'/g, "// localStorage.setItem('mghrm_villages'");
html = html.replace(/localStorage\.setItem\(key,\s*JSON\.stringify\(payload\)\);/g, "/* Autobackup disabled in favor of Real-Time Supabase */");

fs.writeFileSync('index.html', html);
console.log('LocalStorage Purged');
