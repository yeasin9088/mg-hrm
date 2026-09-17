const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.replace(/DATA\.employees\.filter\(e => String\(e\.id\) !== String\(delId\) && String\(e\.EmployeeID\) !== String\(delId\) && String\(e\.RecordID\) !== String\(delId\)\);/g, 'DATA.employees.filter(e => String(e.id) !== String(delId) && String(e.EmployeeID) !== String(delId));');
code = code.replace(/DATA\.employees\.some\(e => \(norm\.id != null && String\(e\.id\) === String\(norm\.id\)\) || \(norm\.EmployeeID && String\(e\.EmployeeID\) === String\(norm\.EmployeeID\)\) || \(norm\.RecordID && String\(e\.RecordID\) === String\(norm\.RecordID\)\)\);/g, 'DATA.employees.some(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)));');
code = code.replace(/DATA\.employees\.findIndex\(e => \(norm\.id != null && String\(e\.id\) === String\(norm\.id\)\) || \(norm\.EmployeeID && String\(e\.EmployeeID\) === String\(norm\.EmployeeID\)\) || \(norm\.RecordID && String\(e\.RecordID\) === String\(norm\.RecordID\)\)\);/g, 'DATA.employees.findIndex(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)));');
code = code.replace(/DATA\.exits\.filter\(x=>String\(x\.id\)===String\(recordId\) || String\(x\.EmployeeID\)===String\(recordId\) || String\(x\.RecordID\)===String\(recordId\)\)/g, 'DATA.exits.filter(x=>String(x.employee_sys_id)===String(recordId) || String(x.EmployeeID)===String(recordId))');

fs.writeFileSync('index.html', code);
