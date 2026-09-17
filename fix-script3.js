const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      const lines = code.split('\n');
      console.log(lines[6560]);
      console.log(lines[6561]);
      console.log(lines[6562]);
      console.log(lines[6563]);
      console.log(lines[6564]);
      console.log(lines[6565]);
      console.log(lines[6566]);
      console.log(lines[6567]);
      console.log(lines[6568]);
      console.log(lines[6569]);
  }
}
