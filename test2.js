const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 784889) {
      console.log("Analyzing last script");
      const code = match[1];
      const acorn = require('acorn');
      try {
        acorn.parse(code, {ecmaVersion: 2020});
      } catch (e) {
         console.log(e);
      }
  }
}
