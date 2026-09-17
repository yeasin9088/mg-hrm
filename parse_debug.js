const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      const acorn = require('acorn');
      try {
        const tokens = Array.from(acorn.tokenizer(code, {ecmaVersion: 2020}));
        console.log("Tokens parsed successfully!");
      } catch (e) {
         console.log(e);
      }
  }
}
