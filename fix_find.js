const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

// First, inject helper functions at the top of the JS section
const helpers = `
function findEmpByAction(t) {
  if (!t) return null;
  const sysId = t.employee_sys_id || t.id; // t.id might be the action id, so be careful. Actually t.employee_sys_id is safer.
  return DATA.employees.find(x => 
    (t.employee_sys_id && String(x.id) === String(t.employee_sys_id)) ||
    (t.EmployeeID && String(x.EmployeeID) === String(t.EmployeeID)) ||
    (t.RecordID && String(x.id) === String(t.RecordID)) // Legacy fallback if UI still has RecordID cached
  );
}
function findEmp(rid) {
  if (!rid) return null;
  return DATA.employees.find(x => String(x.id) === String(rid) || String(x.EmployeeID) === String(rid));
}
`;

if (!code.includes('function findEmpByAction')) {
  code = code.replace(/<script>/, "<script>\n" + helpers);
}

// Now replace all the inline finds:
// Pattern 1: e.id == rid || e.EmployeeID == rid || e.RecordID == rid
code = code.replace(/DATA\.employees\.find\([^)]*x\.RecordID\s*===[^)]*\)/g, (match) => {
  // We need to determine if it's finding by a string `rid` / `recordId` / `empKey` or by an object `t`, `d`, `l`, `c`, `x`
  if (match.includes('.EmployeeID') && match.match(/\(\w+\.EmployeeID/)) {
    // Looks like it's matching an object, e.g. (t.EmployeeID ...)
    const objVarMatch = match.match(/\((\w+)\.EmployeeID/);
    if (objVarMatch) {
      return `findEmpByAction(${objVarMatch[1]})`;
    }
  }
  // Otherwise it's finding by a string variable
  const varMatch = match.match(/String\((rid|recordId|empKey|editKey)\)/);
  if (varMatch) {
    return `findEmp(${varMatch[1]})`;
  }
  
  // generic fallback
  return match;
});

fs.writeFileSync('index.html', code);
