const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      
      console.log("Original parsing...");
      try {
        let tree = acorn.parse(code, {ecmaVersion: 2020});
      } catch (e) {
          console.log(e);
      }
      
      console.log("\nTrying with an extra } at the end...");
      try {
        let tree = acorn.parse(code + "}", {ecmaVersion: 2020});
        console.log("Successfully parsed with extra }!");
      } catch (e) {
          console.log(e);
      }
  }
}
