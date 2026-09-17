const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      const lines = code.split('\n');
      console.log(lines[0].substring(0, 50));
      console.log(lines[lines.length - 1]);
      console.log(lines[lines.length - 2]);
  }
}
