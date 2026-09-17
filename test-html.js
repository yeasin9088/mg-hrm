const { JSDOM } = require('jsdom');
const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

const dom = new JSDOM(html);
const scripts = dom.window.document.querySelectorAll('script');
scripts.forEach((script, i) => {
    if (script.textContent.length > 1000) {
        console.log(`Script ${i}: Length ${script.textContent.length}`);
        const acorn = require('acorn');
        try {
            acorn.parse(script.textContent, {ecmaVersion: 2020});
            console.log(`Script ${i} is valid.`);
        } catch (e) {
            console.log(`Script ${i} syntax error:`, e.message);
        }
    }
});
