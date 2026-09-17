const fs = require('fs');
let code = fs.readFileSync('index.html', 'utf8');

code = code.replace(/rows\.map\(/g, 'rows.slice(0, 100).map(');
code = code.replace(/DATA\.exits\.slice\(\)\.sort\(\(a,b\)=>\+b\.ExitID-\+a\.ExitID\)\.map\(/g, 'DATA.exits.slice().sort((a,b)=>+b.ExitID-+a.ExitID).slice(0, 100).map(');
code = code.replace(/DATA\.career\.slice\(\)\.sort\(\(a,b\)=>\+b\.ChangeID-\+a\.ChangeID\)\.map\(/g, 'DATA.career.slice().sort((a,b)=>+b.ChangeID-+a.ChangeID).slice(0, 100).map(');
code = code.replace(/DATA\.leaves\.slice\(\)\.sort\(\(a,b\)=>\+b\.LeaveID-\+a\.LeaveID\)\.map\(/g, 'DATA.leaves.slice().sort((a,b)=>+b.LeaveID-+a.LeaveID).slice(0, 100).map(');
code = code.replace(/DATA\.uniform\.slice\(\)\.sort\(\(a,b\)=>\+b\.IssueID-\+a\.IssueID\)\.map\(/g, 'DATA.uniform.slice().sort((a,b)=>+b.IssueID-+a.IssueID).slice(0, 100).map(');
code = code.replace(/DATA\.disciplinary\.slice\(\)\.sort\(\(a,b\)=>\+b\.ActionID-\+a\.ActionID\)\.map\(/g, 'DATA.disciplinary.slice().sort((a,b)=>+b.ActionID-+a.ActionID).slice(0, 100).map(');

fs.writeFileSync('index.html', code);
