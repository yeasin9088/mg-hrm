const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');
const scripts = [];
const scriptRegex = /<script>([\s\S]*?)<\/script>/g;
let match;
while ((match = scriptRegex.exec(html)) !== null) { scripts.push(match[1]); }
const s2 = scripts[2].split('\n');
console.log(s2[4163]);
