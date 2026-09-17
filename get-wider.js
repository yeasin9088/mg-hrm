const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const scripts = [];
const scriptRegex = /<script>([\s\S]*?)<\/script>/g;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  scripts.push(match[1]);
}

const lines = scripts[2].split('\n');
let code = lines.slice(4155-20, 4165+10).join('\n');
try {
  require('acorn').parse(code, { ecmaVersion: 'latest' });
  console.log("No error in snippet");
} catch(e) {
  console.log(e.message);
}
