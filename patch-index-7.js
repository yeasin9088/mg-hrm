const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The issue is in `function saveVillages(){ try{ // localStorage.setItem('mghrm_villages', JSON.stringify(window.__villagesMem||{})); }catch(e){} }`
// The `//` comments out everything until the end of the line, including the `}catch(e){}`.
// We must replace this!

html = html.replace(/function saveVillages\(\)\{ try\{ \/\/ localStorage\.setItem\('mghrm_villages', JSON\.stringify\(window\.__villagesMem\|\|\{\}\)\); \}catch\(e\)\{\} \}/g, "function saveVillages(){ /* villages setItem disabled */ }");

fs.writeFileSync('index.html', html);
console.log('Fixed comment syntax error in saveVillages');
