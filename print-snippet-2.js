const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

// extract the scripts
const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  if (match.index === 234533) {
    const code = match[1];
    const lines = code.split('\n');
    const errLine = 6328;
    for (let i = errLine - 25; i <= errLine + 25; i++) {
        if (lines[i]) console.log(i + ": " + lines[i]);
    }
  }
}
