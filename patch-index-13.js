const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 784705) {
      console.log("WAIT! The 784705 one has `})();` ! Let me see its code:");
      let code = match[1];
      console.log(code.substring(code.length - 100));
  }
}
