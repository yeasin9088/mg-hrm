const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The issue must be somewhere else. Let's find exactly line 6571 in the script block.
// We have the exact line in index.html, it's 6571 + the offset of the script tag.
const scriptOffset = 234533;
const textBeforeScript = html.substring(0, scriptOffset);
const lineOffset = textBeforeScript.split('\n').length;
console.log("Script starts at line", lineOffset);
console.log("Error is at script line 6571, which is absolute line", lineOffset + 6571 - 1);
