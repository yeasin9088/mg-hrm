const fs = require('fs');
const acorn = require('acorn');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      
      // Binary search over strings of characters this time
      let low = 0; let high = code.length;
      let lastGood = 0;
      
      while (low <= high) {
          let mid = Math.floor((low + high) / 2);
          let testCode = code.substring(0, mid);
          try {
              acorn.parse(testCode, {ecmaVersion: 2020});
              lastGood = mid;
              low = mid + 1;
          } catch(e) {
              if (e.message.includes('Unexpected token')) {
                 lastGood = mid;
                 low = mid + 1;
              } else {
                 high = mid - 1;
              }
          }
      }
      console.log("Good until:", lastGood);
      console.log("Character after:", code[lastGood]);
      console.log("Surrounding code:");
      console.log(code.substring(lastGood - 20, lastGood + 20));
  }
}
