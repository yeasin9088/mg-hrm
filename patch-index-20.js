const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

html = html.replace("setInterval(()=>checkPendingToast(true), 180000); /* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */})();\n</script>", "setInterval(()=>checkPendingToast(true), 180000); /* প্রতি ৩ মিনিটে রিমাইন্ডার পপআপ */\n</script>");

fs.writeFileSync('index.html', html);
console.log('Removed stray IIFE closing properly 3');
