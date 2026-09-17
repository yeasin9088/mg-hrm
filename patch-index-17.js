const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

html = html.replace("/* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */})();", "/* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */");

fs.writeFileSync('index.html', html);
console.log('Removed stray IIFE closing properly 2');
