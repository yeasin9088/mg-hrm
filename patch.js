const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const tableAllowed = {
  employees: "'id', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'father_name', 'mother_name', 'dob', 'phone', 'nid', 'education', 'religion', 'height', 'weight', 'marital_status', 'spouse_name', 'spouse_phone', 'ec_name', 'ec_relation', 'ec_phone', 'division', 'district', 'thana', 'address', 'address_bn', 'division_id', 'district_id', 'upazila_id', 'union_id', 'village', 'street', 'designation', 'project_name', 'join_date', 'duty_hour', 'salary', 'status', 'exit_date', 'exit_reason', 'remarks', 'photo_url', 'created_at', 'updated_at', 'system_id'",
  projects: "'id', 'project_name', 'project_name_bn', 'address', 'address_bn', 'main_gate_phone', 'admin_name', 'admin_phone', 'admin_whatsapp', 'division', 'district', 'thana', 'division_id', 'district_id', 'upazila_id', 'union_id', 'village', 'street', 'start_date', 'status', 'created_at'",
  demand: "'id', 'project_name', 'demand_incharge', 'demand_supervisor', 'demand_assst_sup', 'demand_guard', 'demand_lady_guard', 'demand_total', 'created_at'",
  disciplinary: "'id', 'action_id', 'ref_no', 'ref_no_bn', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'designation', 'designation_bn', 'project_name', 'project_name_bn', 'action_type', 'issue_date', 'incident_date', 'description', 'created_at', 'system_id', 'employee_id_bn', 'issue_date_bn', 'description_bn'",
  exits: "'id', 'exit_id', 'record_id', 'full_name', 'designation', 'current_project', 'join_date', 'exit_reason', 'exit_date', 'issue_date', 'created_at', 'system_id'",
  transfers: "'id', 'transfer_id', 'record_id', 'employee_id', 'full_name', 'full_name_bn', 'designation', 'designation_bn', 'current_project', 'current_project_bn', 'new_project', 'new_project_bn', 'transfer_date', 'issues_date', 'is_proceed', 'created_at', 'system_id', 'employee_id_bn', 'transfer_date_bn', 'issues_date_bn'",
  career: "'id', 'change_id', 'record_id', 'employee_id', 'full_name', 'project_name', 'change_type', 'effective_date', 'current_designation', 'new_designation', 'previous_salary', 'increment_amount', 'new_salary', 'created_at', 'system_id'",
  recruitmentArchive: "'archive_id', 'candidate_name', 'designation', 'project_name', 'result', 'employee_id', 'decided_at', 'notes', 'created_at', 'updated_at'",
  activityLog: "'id', 'user_id', 'user_email', 'action', 'table_name', 'record_ref', 'detail', 'created_at'"
};

let replacement = "  function toDb(key, rec) {\n    var m = TABLE_MAP[key], out = {}, k, col, v;\n" +
  "    var allowed = m.allowed || [];\n" +
  "    for (k in rec) {\n      if (!Object.prototype.hasOwnProperty.call(rec, k)) continue;\n" +
  "      if (k.charAt(0) === '_') continue;\n" +
  "      col = (m.map && m.map[k]) || camelToSnake(k);\n" +
  "      if (allowed.length && allowed.indexOf(col) === -1) continue;\n" +
  "      v = rec[k];\n" +
  "      if (typeof v === 'string' && v.trim() === '') v = null;\n" +
  "      out[col] = v;\n" +
  "    }";

html = html.replace(/function toDb\(key, rec\).*?out\[col\] = v;\n    }/s, replacement);

for (const [key, cols] of Object.entries(tableAllowed)) {
  let rx = new RegExp(key + ":\\s*\\{\\s*table:\\s*'[^']+',\\s*pk:\\s*'[^']+',", "g");
  html = html.replace(rx, match => match + " allowed: [" + cols + "],");
}

fs.writeFileSync('index.html', html);
console.log('patched toDb and allowed cols');
