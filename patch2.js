const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

let replacement = "      v = rec[k];\n" +
  "      if (typeof v === 'string' && v.trim() === '') v = null;\n" +
  "      if (v && typeof v === 'string' && (col === 'salary' || col === 'new_salary' || col === 'previous_salary' || col === 'increment_amount')) {\n" +
  "        v = v.replace(/,/g, '');\n" +
  "        if (isNaN(Number(v))) v = 0;\n" +
  "      }\n" +
  "      out[col] = v;\n";

html = html.replace(/v = rec\[k\];\n      if \(typeof v === 'string' && v.trim\(\) === ''\) v = null;\n      out\[col\] = v;/s, replacement);
fs.writeFileSync('index.html', html);
console.log('patched salary numeric formatting');
