const fs = require('fs');
const acorn = require('acorn');

const html = fs.readFileSync('index.html', 'utf8');

const regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = regex.exec(html)) !== null) {
  if (match.index === 234533) {
      const code = match[1];
      
      try {
        let tree = acorn.parse(code, {ecmaVersion: 2020, onToken: () => {}, onComment: () => {}});
      } catch (e) {
          // get the token right before the error
          const tokens = Array.from(acorn.tokenizer(code, {ecmaVersion: 2020}));
          let lastTokens = [];
          for (let i = 0; i < tokens.length; i++) {
              if (tokens[i].start >= e.pos - 50 && tokens[i].start <= e.pos) {
                  lastTokens.push(tokens[i]);
              }
          }
          console.log(lastTokens);
      }
  }
}
