const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');
const regex = /<input type="file" id="logoInput" accept="imagefunction/g;
let match = regex.exec(html);
if (match) {
    console.log("Found at: " + match.index);
}
