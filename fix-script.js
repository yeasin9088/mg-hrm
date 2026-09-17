const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const lines = html.split('\n');

// For script 2 at line 1304 (which is relative to script 2 start). We need global line numbers.
// Let's do string replacement on the exact text.
const badStr1 = "`<span class=\"pill success\">✓ ${'+r.empId:'Onboarded — ID: '+r.empId}</span>`";
const goodStr1 = "`<span class=\"pill success\">✓ Onboarded — ID: ${r.empId}</span>`";
if (html.includes(badStr1)) {
    html = html.replace(badStr1, goodStr1);
    console.log("Fixed str1");
} else {
    console.log("str1 not found");
}

const badStr2 = "msg('setupMsg','URL-টি ঠিক মনে হচ্ছে না। এমন হওয়া উচিত:<br><code>https:\n         url.replace(/[<>&]/g,'') + '</code>','err');";
const goodStr2 = "msg('setupMsg','URL-টি ঠিক মনে হচ্ছে না। এমন হওয়া উচিত:<br><code>https://' + \n         url.replace(/[<>&]/g,'') + '</code>','err');";
if (html.includes(badStr2)) {
    html = html.replace(badStr2, goodStr2);
    console.log("Fixed str2");
} else {
    console.log("str2 not found");
}

fs.writeFileSync('index.html', html);
