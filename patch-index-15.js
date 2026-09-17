const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// Wait! Both 5 and 6 have mismatched parenthesis/braces?
// The script starting at 234533 (script 5) ends with:
// setInterval(()=>checkPendingToast(true), 180000); /* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */})();
// Wait, the `})();` is there in script 5! BUT script 5 doesn't have an opening `(function(){`!
// Wait! Let me check the start of script 5 again.
// const DATA = {"employees": ...
// It doesn't have a `(function(){`! It just has `})();` at the end! 
// Oh! I ALREADY removed the `})();` at the end in patch-index-8, BUT it turns out I removed the one that was on a new line!
// Wait, my patch-index-8 didn't match!
// Look at what I replaced: 
// /setInterval\(\(\)=>checkPendingToast\(true\), 180000\); \/\* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ \*\/\n\)\(\);\n<\/script>/g
// It failed to match, so it didn't remove anything!

html = html.replace(/setInterval\(\(\)=>checkPendingToast\(true\), 180000\); \/\* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ \*\/\)\(\);/g, "setInterval(()=>checkPendingToast(true), 180000); /* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */");

fs.writeFileSync('index.html', html);
console.log('Removed stray IIFE closing properly');
