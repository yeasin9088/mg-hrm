const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      
      try {
        let tree = acorn.parse(code + ";", {ecmaVersion: 2020});
      } catch (e) {
          console.log(e);
      }
  }
}
