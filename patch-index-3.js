const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

html = html.replace("function hookPersist(){ /* legacy persist hook removed */ }", 
"function hookPersist(){\n  var orig = window.persist;\n  if (typeof orig !== 'function' || orig.__sbHooked) return;\n  var wrapped = function () {\n    try { orig.apply(this, arguments); } catch (e) {}\n    try { MGHRM.pushAll(); } catch (e) {}\n  };\n  wrapped.__sbHooked = true;\n  window.persist = wrapped;\n}");

fs.writeFileSync('index.html', html);
console.log('hookPersist restored');
