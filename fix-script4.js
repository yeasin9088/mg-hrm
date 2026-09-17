const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      const acorn = require('acorn');
      try {
        acorn.parse(code, {ecmaVersion: 2020});
      } catch (e) {
         console.log(e);
         // Find unmatched brackets
         let openCount = 0;
         for(let i=0; i<code.length; i++) {
             if(code[i] === '{') openCount++;
             if(code[i] === '}') openCount--;
         }
         console.log("Unmatched { count:", openCount);
         
         let parenCount = 0;
         for(let i=0; i<code.length; i++) {
             if(code[i] === '(') parenCount++;
             if(code[i] === ')') parenCount--;
         }
         console.log("Unmatched ( count:", parenCount);
      }
  }
}
