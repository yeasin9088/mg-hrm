const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.replace(/DATA\.employees\.find\([^)]*x\.RecordID[^)]*\)/g, (match) => {
  if (match.includes('.EmployeeID') && match.match(/\(\w+\.EmployeeID/)) {
    const objVarMatch = match.match(/\((\w+)\.EmployeeID/);
    if (objVarMatch) {
      return `findEmpByAction(${objVarMatch[1]})`;
    }
  }
  const varMatch = match.match(/String\((rid|recordId|empKey|editKey|delId)\)/);
  if (varMatch) {
    return `findEmp(${varMatch[1]})`;
  }
  return match;
});

code = code.replace(/\(DATA\.employees \|\| \[\]\)\.find\([^)]*x\.RecordID[^)]*\)/g, (match) => {
  const varMatch = match.match(/String\((rid|recordId)\)/);
  if (varMatch) {
    return `findEmp(${varMatch[1]})`;
  }
  return match;
});

code = code.replace(/DATA\.employees\.some\([^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.some(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)))');

code = code.replace(/DATA\.employees\.findIndex\([^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.findIndex(e => (norm.id != null && String(e.id) === String(norm.id)) || (norm.EmployeeID && String(e.EmployeeID) === String(norm.EmployeeID)))');

code = code.replace(/DATA\.employees\.filter\([^)]*e\.RecordID[^)]*\)/g, 'DATA.employees.filter(e => String(e.id) !== String(delId) && String(e.EmployeeID) !== String(delId))');

code = code.replace(/DATA\.exits\.filter\([^)]*x\.RecordID[^)]*\)/g, 'DATA.exits.filter(x=>String(x.employee_sys_id)===String(recordId) || String(x.EmployeeID)===String(recordId))');

fs.writeFileSync('index.html', code);
