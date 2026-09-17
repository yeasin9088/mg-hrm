const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.replace(/m\.targetCol === 'record_id'/g, "m.targetCol === 'employee_sys_id'");
code = code.replace(/employees\.record_id/g, 'employees.id');

fs.writeFileSync('index.html', code);
