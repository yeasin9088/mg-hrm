const fs = require('fs');
const acorn = require('acorn');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      let openBraceCount = (code.match(/\{/g) || []).length;
      let closeBraceCount = (code.match(/\}/g) || []).length;
      console.log("{ count:", openBraceCount, "} count:", closeBraceCount);
      console.log("( count:", (code.match(/\(/g) || []).length, ") count:", (code.match(/\)/g) || []).length);
      console.log("[ count:", (code.match(/\[/g) || []).length, "] count:", (code.match(/\]/g) || []).length);
  }
}
