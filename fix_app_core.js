const fs = require('fs');
let code = fs.readFileSync('app-core.js', 'utf8');

const regexAllowed = /allowed:\s*\[([\s\S]*?)\]/g;
code = code.replace(regexAllowed, (match, inner) => {
  if (inner.includes("'id',") && !inner.includes("'employee_sys_id'")) {
    return `allowed: [ 'employee_sys_id', ${inner} ]`;
  }
  return match;
});

const regexMap = /map:\s*\{([\s\S]*?)\}/g;
code = code.replace(regexMap, (match, inner) => {
  if (!inner.includes("'employee_sys_id':")) {
    return `map: { 'RecordID': 'employee_sys_id', 'employee_sys_id': 'employee_sys_id', ${inner} }`;
  }
  return match;
});

fs.writeFileSync('app-core.js', code);
