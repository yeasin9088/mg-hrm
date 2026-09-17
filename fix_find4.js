const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.replace(/DATA\.employees\.filter\(e\s*=>[^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.filter(e => String(e.id) !== String(delId) && String(e.EmployeeID) !== String(delId))');

code = code.replace(/DATA\.employees\.some\(e\s*=>[^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.some(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)))');

code = code.replace(/DATA\.employees\.findIndex\(e\s*=>[^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.findIndex(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)))');

code = code.replace(/DATA\.exits\.filter\(x=>[^)]*x\.RecordID[^)]*\)/g, 'DATA.exits.filter(x=>String(x.employee_sys_id)===String(recordId) || String(x.EmployeeID)===String(recordId))');

code = code.replace(/\(DATA\.employees \|\| \[\]\)\.find\(x\s*=>\s*String\(x\.id\)\s*===\s*String\(rid\)\s*\|\|\s*String\(x\.EmployeeID\)\s*===\s*String\(rid\)\s*\|\|\s*String\(x\.RecordID\)\s*===\s*String\(rid\)\)/g, 'findEmp(rid)');

code = code.replace(/DATA\.employees\.find\(e\s*=>\s*\(l\.empId\s*&&\s*String\(e\.EmployeeID\)\s*===\s*String\(l\.empId\)\)\s*\|\|\s*\(l\.empId\s*&&\s*String\(e\.id\)\s*===\s*String\(l\.empId\)\)\s*\|\|\s*\(l\.RecordID\s*&&\s*String\(e\.RecordID\)\s*===\s*String\(l\.RecordID\)\)\)/g, 'findEmpByAction(l)');

code = code.replace(/String\(x\.id\)\s*===\s*String\(rid\)\s*\|\|\s*String\(x\.EmployeeID\)\s*===\s*String\(rid\)\s*\|\|\s*String\(x\.RecordID\)\s*===\s*String\(rid\)/g, 'String(x.id) === String(rid) || String(x.EmployeeID) === String(rid)');

// Remove RecordID in search checks
code = code.replace(/String\(e\.RecordID\s*\|\|\s*''\)\.toLowerCase\(\)\.includes\(q\)\s*\|\|/g, '');
code = code.replace(/String\(e\.RecordID\s*\|\|\s*''\)\.trim\(\)\.toLowerCase\(\)\s*===\s*q\.toLowerCase\(\)/g, 'false');

// Remove RecordID from empDisplayId resolution
code = code.replace(/\|\|\s*existing\.RecordID/g, '');
code = code.replace(/\|\|\s*exact\.RecordID/g, '');

// Fix 'RecordID: row.id' in offline backup parse (line 2426)
code = code.replace(/RecordID:\s*row\.id,/g, '');
code = code.replace(/query\.eq\('id',\s*e\.RecordID\)/g, "query.eq('id', e.id)");

fs.writeFileSync('index.html', code);
