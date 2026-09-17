const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      console.log("Replacing all functions trying to find parsing issue...");
      let patchedCode = code.replace(/function/g, 'f');
      
      let lines = code.split('\n');
      console.log("Total lines:", lines.length);
      
      // Binary search to find where it breaks
      let low = 0; let high = lines.length;
      let lastGood = 0;
      
      while (low <= high) {
          let mid = Math.floor((low + high) / 2);
          let testCode = lines.slice(0, mid).join('\n');
          try {
              acorn.parse(testCode, {ecmaVersion: 2020});
              lastGood = mid;
              low = mid + 1;
          } catch(e) {
              if (e.message.includes('Unexpected token')) {
                 // it means the code is valid up to here but maybe incomplete 
                 // actually missing } is expected at the end of a partial parse
                 lastGood = mid;
                 low = mid + 1;
              } else {
                 high = mid - 1;
              }
          }
      }
      console.log("Issue likely at line", lastGood);
  }
}
