const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The `try` was added in `v3.4 অটো-ব্যাকআপ`. Let's look closely at it.
// try { (function(){ ... })(); } catch(e){ ... }
// That's totally valid. But maybe an earlier function has a missing brace?
// The acorn error was 6571:0 inside the script (i.e. at the very end). This means unexpected EOF or unbalanced braces.

// Let's count all { and } in the script!
const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
let match;
while ((match = scriptRegex.exec(html)) !== null) {
  if (match.index === 234533) {
      let code = match[1];
      let openBraceCount = (code.match(/\{/g) || []).length;
      let closeBraceCount = (code.match(/\}/g) || []).length;
      console.log("Script 5 { count:", openBraceCount);
      console.log("Script 5 } count:", closeBraceCount);
  }
}
