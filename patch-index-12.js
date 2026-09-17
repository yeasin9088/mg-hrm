const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      let lines = code.split('\n');
      console.log("Analyzing missing }");
      
      let patchedCode = code.replace(/function/g, 'f').replace(/catch\(/g, 'f(');
      let openBraceCount = (code.match(/\{/g) || []).length;
      let closeBraceCount = (code.match(/\}/g) || []).length;
      console.log("{ count:", openBraceCount, "} count:", closeBraceCount);
  }
}
