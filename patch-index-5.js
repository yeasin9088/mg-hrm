const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The issue is in try{// localStorage.setItem('mghrm_villages', JSON.stringify(payload.villages));}catch(e){}
// The comment syntax inside a single-line try/catch block can break the catch clause if not formatted right, 
// because // comments out everything until the end of the line!
// Ah, `try{// localStorage.setItem...}catch(e){}` -> `try{// localStorage.setItem...` makes the catch disappear!

html = html.replace(/try\{\/\/\s*localStorage\.setItem\('mghrm_villages', JSON\.stringify\(payload\.villages\)\);\}catch\(e\)\{\}/g, "/* villages setItem disabled */");
html = html.replace(/try\{\/\/\s*localStorage\.setItem\('mghrm_villages', JSON\.stringify\(window\.__villagesMem\|\|\{\}\)\);\}catch\(e\)\{\}/g, "/* villages setItem disabled */");

fs.writeFileSync('index.html', html);
console.log('Fixed comment syntax error');
