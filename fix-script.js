const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      console.log("Analyzing script starting at", match.index);
      
      const code = match[1];
      
      const acorn = require('acorn');
      try {
        acorn.parse(code, {ecmaVersion: 2020});
      } catch (e) {
         console.log(e);
      }
  }
}
