const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const oldFunc = /function renderDashboard\(\)\{[\s\S]*?document\.getElementById\('page-dashboard'\)\.innerHTML = `[\s\S]*?<\/div>\s*`;\n\}/;
const match = html.match(oldFunc);
if (match) {
    console.log("Found renderDashboard");
} else {
    console.log("Not found!");
}
