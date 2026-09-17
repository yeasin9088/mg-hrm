const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      console.log(code.substring(543731 - 100, 543731 + 50));
      console.log("LAST CHARACTER ASCII:", code.charCodeAt(code.length - 1));
      console.log("LENGTH:", code.length);
      console.log("POS:", 543731);
  }
}
