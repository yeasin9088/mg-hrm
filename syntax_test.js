const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      const lines = code.split('\n');
      console.log(lines[6571 - 3]);
      console.log(lines[6571 - 2]);
      console.log(lines[6571 - 1]);
      console.log(lines[6571]);
      console.log(lines[6571 + 1]);
  }
}
