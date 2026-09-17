const fs = require('fs');
const acorn = require('acorn');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      let lines = code.split('\n');
      console.log("Lines total:", lines.length);
      for(let i = lines.length - 20; i < lines.length; i++) {
          console.log(i + ": " + lines[i]);
      }
  }
}
