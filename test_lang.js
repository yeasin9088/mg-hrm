const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// Example: LANG==='bn'?'বন্ধ':'Close'
let matches = html.match(/LANG\s*===\s*'bn'\s*\?\s*(`[^`]*`|'[^']*'|"[^"]*")\s*:\s*(`[^`]*`|'[^']*'|"[^"]*")/g);
console.log(matches ? matches.slice(0, 10).join('\n') : 'no matches');
