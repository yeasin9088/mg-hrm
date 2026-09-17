const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      
      console.log("Trying with loose parser or checking lines...");
      // Let's strip the last few lines and see if it parses
      let lines = code.split('\n');
      lines.pop(); // remove empty line or })();
      lines.pop(); 
      lines.pop();
      try {
        let tree = acorn.parse(lines.join('\n'), {ecmaVersion: 2020});
        console.log("Parsed after removing last lines!");
      } catch (e) {
          console.log(e);
      }
  }
}
