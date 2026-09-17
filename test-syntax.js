const fs = require('fs');
const acorn = require('acorn');
const html = fs.readFileSync('index.html', 'utf8');

// extract the scripts
const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  const code = match[1];
  try {
    acorn.parse(code, { ecmaVersion: 2020 });
    console.log("Script block starting at index", match.index, "parsed OK");
  } catch(e) {
    console.log("Syntax error in script starting at", match.index);
    console.log(e);
  }
}
