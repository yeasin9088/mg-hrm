const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The issue was I removed `})();` but earlier the script started with:
// `const DATA = {"employees": [], ...`
// Wait, when looking at line 10, it started with `(function() { try { var nativeFetch = ... }})()`.
// This is a DIFFERENT script block!

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
let newHtml = html;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      console.log(code.substring(0, 100));
  }
}
