const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const tableAllowed = {
  leaves: "'id', 'leave_id', 'record_id', 'employee_id', 'name', 'type', 'start', 'end', 'days', 'reason', 'status', 'created_at'",
  meetings: "'id', 'meeting_id', 'date_iso', 'title', 'location', 'start_time', 'end_time', 'notes', 'status', 'created_at'",
  meeting_attendance: "'id', 'meeting_id', 'project_name', 'project_id', 'is_present', 'remarks', 'created_at'"
};

for (const [key, cols] of Object.entries(tableAllowed)) {
  let rx = new RegExp(key + ":\\s*\\{\\s*table:\\s*'[^']+',\\s*pk:\\s*'[^']+',", "g");
  html = html.replace(rx, match => match + " allowed: [" + cols + "],");
}

fs.writeFileSync('index.html', html);
console.log('patched leaves and meetings allowed cols');
