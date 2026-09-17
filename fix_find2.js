const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

// The most common pattern
code = code.replace(/DATA\.employees\.find\(x\s*=>\s*String\(x\.id\)\s*===\s*String\(([^)]+)\)\s*\|\|\s*String\(x\.EmployeeID\)\s*===\s*String\(\1\)\s*\|\|\s*String\(x\.RecordID\)\s*===\s*String\(\1\)\)/g, 'findEmp($1)');

code = code.replace(/DATA\.employees\.find\(x\s*=>\s*\(\w+\.EmployeeID\s*&&\s*String\(x\.EmployeeID\)\s*===\s*String\((\w+)\.EmployeeID\)\)\s*\|\|\s*\(\1\.id\s*&&\s*String\(x\.id\)\s*===\s*String\(\1\.id\)\)\s*\|\|\s*\(x\.RecordID\s*&&\s*String\(x\.RecordID\)\s*===\s*String\(\1\.RecordID\)\)\)/g, 'findEmpByAction($1)');

code = code.replace(/DATA\.employees\.find\(emp\s*=>\s*\(\w+\.EmployeeID\s*&&\s*String\(emp\.EmployeeID\)\s*===\s*String\((\w+)\.EmployeeID\)\)\s*\|\|\s*\(\1\.id\s*&&\s*String\(emp\.id\)\s*===\s*String\(\1\.id\)\)\s*\|\|\s*\(x\.RecordID\s*&&\s*String\(emp\.RecordID\)\s*===\s*String\(\1\.RecordID\)\)\)/g, 'findEmpByAction($1)');

code = code.replace(/DATA\.employees\.find\(e\s*=>\s*\(\w+\.EmployeeID\s*&&\s*String\(e\.EmployeeID\)\s*===\s*String\((\w+)\.EmployeeID\)\)\s*\|\|\s*\(\1\.id\s*&&\s*String\(e\.id\)\s*===\s*String\(\1\.id\)\)\s*\|\|\s*\(\1\.RecordID\s*&&\s*String\(e\.RecordID\)\s*===\s*String\(\1\.RecordID\)\)\)/g, 'findEmpByAction($1)');


// Other variants:
code = code.replace(/DATA\.employees\.find\(x\s*=>\s*\(\w+\.EmployeeID\s*&&\s*String\(x\.EmployeeID\)\s*===\s*String\((\w+)\.EmployeeID\)\)\s*\|\|\s*\(\1\.id\s*&&\s*String\(x\.id\)\s*===\s*String\(\1\.id\)\)\s*\|\|\s*\(\1\.RecordID\s*&&\s*String\(x\.RecordID\)\s*===\s*String\(\1\.RecordID\)\)\)/g, 'findEmpByAction($1)');

// Also replace `|| e.RecordID` in JSX templates:
code = code.replace(/\|\|\s*e\.RecordID/g, '');
code = code.replace(/\|\|\s*s\.emp\.RecordID/g, '');
code = code.replace(/\|\|\s*emp\.RecordID/g, '');


fs.writeFileSync('index.html', code);
