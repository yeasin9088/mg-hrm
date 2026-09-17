const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

html = html.replace(/localStorage\.setItem\(LS_KEY,\s*snapshotState\(\)\);/g, "/* localStorage disabled */");
html = html.replace(/localStorage\.setItem\(OD_FLAG,'1'\);/g, "/* localStorage disabled */");

fs.writeFileSync('index.html', html);
console.log('Final localStorage purged');
