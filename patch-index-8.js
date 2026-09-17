const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// I see! The script begins with:
// const DATA = {"employees": ...
// It doesn't have an IIFE wrapper `(function(){` at the start, but it DOES have an `})();` at the end!
// Let's remove the `})();` at the end!

html = html.replace(/setInterval\(\(\)=>checkPendingToast\(true\), 180000\); \/\* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ \*\/\n\)\(\);\n<\/script>/g, "setInterval(()=>checkPendingToast(true), 180000); /* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */\n</script>");

fs.writeFileSync('index.html', html);
console.log('Removed stray IIFE closing');
