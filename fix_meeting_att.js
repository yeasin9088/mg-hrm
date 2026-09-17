const fs = require('fs');
let code = fs.readFileSync('app-core.js', 'utf8');

const t = 'meetingAttendance';
const regex = new RegExp(`(${t}:\\s*\\{[\\s\\S]*?allowed:\\s*\\[)([^\\]]+)(\\][\\s\\S]*?map:\\s*\\{)`, 'm');
code = code.replace(regex, (match, prefix, allowedStr, suffix) => {
  if (!allowedStr.includes("'employee_sys_id'")) {
    allowedStr = `'employee_sys_id', ` + allowedStr;
  }
  return prefix + allowedStr + suffix;
});

const mapRegex = new RegExp(`(${t}:\\s*\\{[\\s\\S]*?map:\\s*\\{)`, 'm');
code = code.replace(mapRegex, (match, prefix) => {
  if (!match.includes("'employee_sys_id':")) {
    return prefix + ` 'RecordID': 'employee_sys_id', 'employee_sys_id': 'employee_sys_id',`;
  }
  return match;
});

fs.writeFileSync('app-core.js', code);
