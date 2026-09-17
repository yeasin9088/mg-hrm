const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      let lines = code.split('\n');
      
      let testCode = lines.slice(0, 3948).join('\n');
      try {
          acorn.parse(testCode, {ecmaVersion: 2020});
      } catch(e) {
          console.log(e);
      }
  }
}
