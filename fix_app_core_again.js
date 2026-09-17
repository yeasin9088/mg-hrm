const fs = require('fs');
let code = fs.readFileSync('app-core.js', 'utf8');

code = code.replace(/'RecordID': 'employee_sys_id', 'employee_sys_id': 'employee_sys_id',/g, "'employee_sys_id': 'employee_sys_id',");

fs.writeFileSync('app-core.js', code);
