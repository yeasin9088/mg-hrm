const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');
const scripts = [];
const scriptRegex = /<script>([\s\S]*?)<\/script>/g;
let match;
while ((match = scriptRegex.exec(html)) !== null) { scripts.push({ start: match.index, content: match[1] }); }
const content = scripts[2].content;

const lines = content.split('\n');
let funcName = 'global';
let counts = {};

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/function\s+([a-zA-Z0-9_]+)/);
  if (m) funcName = m[1];
  let bt = (lines[i].match(/`/g) || []).length;
  if (!counts[funcName]) counts[funcName] = 0;
  counts[funcName] += bt;
}

for (let f in counts) {
  if (counts[f] % 2 !== 0) {
    console.log(f + " has " + counts[f] + " backticks.");
  }
}
