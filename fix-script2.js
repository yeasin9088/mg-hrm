const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const bad = "msg('setupMsg','URL-টি ঠিক মনে হচ্ছে না। এমন হওয়া উচিত:<br><code>https:\n        url.replace(/[<>&]/g,'') + '</code>','err'); return;";
const good = "msg('setupMsg','URL-টি ঠিক মনে হচ্ছে না। এমন হওয়া উচিত:<br><code>https://' +\n        url.replace(/[<>&]/g,'') + '</code>','err'); return;";

if (html.includes(bad)) {
    html = html.replace(bad, good);
    fs.writeFileSync('index.html', html);
    console.log("Fixed!");
} else {
    console.log("Not found.");
}
