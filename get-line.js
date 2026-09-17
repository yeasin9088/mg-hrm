const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const scripts = [];
const scriptRegex = /<script>([\s\S]*?)<\/script>/g;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  scripts.push(match[1]);
}

const lines = scripts[2].split('\n');
console.log(lines[4161]);
console.log(lines[4162]);
console.log(lines[4163]);
console.log(lines[4164]);
