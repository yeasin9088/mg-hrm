const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.split('DATA.employees.filter(e => String(e.id) !== String(delId) && String(e.EmployeeID) !== String(delId) && String(e.RecordID) !== String(delId));').join('DATA.employees.filter(e => String(e.id) !== String(delId) && String(e.EmployeeID) !== String(delId));');

code = code.split('DATA.employees.some(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)) || (norm.RecordID && String(e.RecordID) === String(norm.RecordID)));').join('DATA.employees.some(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)));');

code = code.split('DATA.employees.findIndex(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)) || (norm.RecordID && String(e.RecordID) === String(norm.RecordID)));').join('DATA.employees.findIndex(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)));');

code = code.split('DATA.exits.filter(x=>String(x.id)===String(recordId) || String(x.EmployeeID)===String(recordId) || String(x.RecordID)===String(recordId))').join('DATA.exits.filter(x=>String(x.employee_sys_id)===String(recordId) || String(x.EmployeeID)===String(recordId))');

fs.writeFileSync('index.html', code);
