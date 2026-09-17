const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// Replace LANG==='bn' ? 'bangla' : 'english' with just 'english'
// Regex handles string literals
let newHtml = html.replace(/LANG\s*===\s*'bn'\s*\?\s*(`[^`]*`|'[^']*'|"[^"]*")\s*:\s*(`[^`]*`|'[^']*'|"[^"]*")/g, '$2');
newHtml = newHtml.replace(/LANG\s*===\s*'bn'\s*\?\s*([^:]+)\s*:\s*([^,;)\n]+)/g, (match, m1, m2) => {
    // some might not be string literals, e.g. variables. We can try to replace them if safe
    return m2.trim();
});

// Remove Bengali comments
newHtml = newHtml.replace(/\/\*[\s\S]*?\*\//g, (match) => {
    if (/[\u0980-\u09FF]/.test(match)) {
        return '';
    }
    return match;
});
newHtml = newHtml.replace(/\/\/.*$/gm, (match) => {
    if (/[\u0980-\u09FF]/.test(match)) {
        return '';
    }
    return match;
});

// Force LANG = 'en'
newHtml = newHtml.replace(/let LANG = .*/, "const LANG = 'en';");

fs.writeFileSync('index.html', newHtml);
console.log('Stripped bn');
