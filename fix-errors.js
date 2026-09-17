const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const scripts = [];
const scriptRegex = /<script>([\s\S]*?)<\/script>/g;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  scripts.push({
    start: match.index,
    content: match[1],
    length: match[0].length
  });
}

const acorn = require('acorn');
scripts.forEach((s, i) => {
  try {
    acorn.parse(s.content, { ecmaVersion: 'latest' });
  } catch (err) {
    console.log(`Error in script ${i} at line ${err.loc.line}, col ${err.loc.column}`);
    const lines = s.content.split('\n');
    console.log('Context:');
    for (let j = Math.max(0, err.loc.line - 3); j < Math.min(lines.length, err.loc.line + 3); j++) {
      console.log(`${j + 1}: ${lines[j]}`);
    }
  }
});
