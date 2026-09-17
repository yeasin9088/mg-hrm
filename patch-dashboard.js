const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const newRenderDashboard = `
let _dashboardDebounceTimeout = null;
let _dashboardLastData = null;

async function renderDashboard(){
  const container = document.getElementById('page-dashboard');
  
  if (window.MGHRM && window.MGHRM.isReady()) {
    try {
      const sb = window.MGHRM._client();
      const [
        { count: activeCount },
        { count: inactiveCount },
        { count: projCount }
      ] = await Promise.all([
        sb.from('employees').select('id', { count: 'exact', head: true }).eq('status', 'Active'),
        sb.from('employees').select('id', { count: 'exact', head: true }).eq('status', 'Inactive'),
        sb.from('projects').select('id', { count: 'exact', head: true })
      ]);
      
      const totalEmps = activeCount + inactiveCount;
      const projSetSize = projCount;

      _dashboardLastData = { activeCount, inactiveCount, projSetSize, totalEmps };
    } catch (err) {
      console.error('Supabase aggregation error:', err);
    }
  }

  const emps = DATA.employees;
  const active = emps.filter(e=>e.Status==='Active');
  const inactive = emps.filter(e=>e.Status==='Inactive');
  const projSet = new Set(active.map(e=>e.ProjectName));
  const parade = computeParade();
  const totalDemand = parade.reduce((s,p)=>s+p.demandTotal,0);
  const totalActual = parade.reduce((s,p)=>s+p.actualTotal,0);
  const shortage = Math.max(0,totalDemand-totalActual);
  const shortagePct = totalDemand>0 ? (shortage*100/totalDemand).toFixed(1) : 0;
  const recentJoins = active.filter(e=>daysAgo(e.JoinDate)<=30);
  const recentTransfers = DATA.transfers.filter(t=>daysAgo(t.TransferDate)<=30);
  const recentDisc = DATA.disciplinary.filter(a=>daysAgo(a.IssueDate)<=30);
  const recentExits = DATA.exits.filter(x=>daysAgo(x.ExitDate)<=30);
  
  // Use aggregated data if available, else fallback to local array counts
  const dData = _dashboardLastData || {
      activeCount: active.length,
      inactiveCount: inactive.length,
      projSetSize: projSet.size,
      totalEmps: emps.length
  };

  const desigCount = {};
  active.forEach(e=>desigCount[e.Designation]=(desigCount[e.Designation]||0)+1);
  const desigRows = Object.entries(desigCount).sort((a,b)=>b[1]-a[1]);

  container.innerHTML = \`
    <div class="kpi-grid">
      \${kpi('Active Employees', num(dData.activeCount), 'g', ico('users'), \`\${num(dData.totalEmps)} total\`,'','employees')}
      \${kpi('Inactive Employees', num(dData.inactiveCount), 'r', ico('x'), \`\${num((dData.inactiveCount*100/(dData.totalEmps||1)).toFixed(1))}% of total\`,'','employees')}
      \${kpi('Active Projects', num(dData.projSetSize), 'p', ico('home'), \`\${num(dData.projSetSize)} total\`,'','projects')}
      \${kpi('New Joins (30d)', num(recentJoins.length), 'b', ico('trend'), \`+\${num((recentJoins.length*100/(dData.activeCount||1)).toFixed(1))}%\`, 'up','recruitment')}
      \${kpi('Exits (30d)', num(recentExits.length), 'r', ico('x'), 'Turnover rate','','exit')}
      \${kpi('Manpower Shortage', num(shortage), 'y', ico('warn'), \`\${num(shortagePct)}% shortage\`, 'down','parade')}
      \${kpi('Transfers (30d)', num(recentTransfers.length), 'b', ico('refresh'), '','','transfer')}
      \${kpi('Disciplinary (30d)', num(recentDisc.length), 'r', ico('warn'), '','','disciplinary')}
    </div>
  \` + container.innerHTML.substring(container.innerHTML.indexOf('<div class="grid-2">'));
  
  // The rest of the dashboard needs to be re-rendered cleanly. Wait, this partial replacement is unsafe.
  // I will just replace the kpi-grid part manually in the file.
}
`;

// It's safer to just do a strict replace on the renderDashboard function.
// Let's match from `function renderDashboard(){` up to `    </div>` for the KPI grid.

const oldFuncStart = /function renderDashboard\(\)\{[\s\S]*?<div class="kpi-grid">[\s\S]*?<\/div>/;

const newStart = `let _dashboardLastData = null;
async function renderDashboard(){
  const container = document.getElementById('page-dashboard');
  
  if (window.MGHRM && window.MGHRM.isReady()) {
    try {
      const sb = window.MGHRM._client();
      const [
        { count: activeCount },
        { count: inactiveCount },
        { count: projCount }
      ] = await Promise.all([
        sb.from('employees').select('id', { count: 'exact', head: true }).eq('status', 'Active'),
        sb.from('employees').select('id', { count: 'exact', head: true }).eq('status', 'Inactive'),
        sb.from('projects').select('id', { count: 'exact', head: true })
      ]);
      
      const totalEmps = activeCount + inactiveCount;
      _dashboardLastData = { activeCount, inactiveCount, projCount, totalEmps };
    } catch (err) {
      console.error('Supabase aggregation error:', err);
    }
  }

  const emps = DATA.employees;
  const active = emps.filter(e=>e.Status==='Active');
  const inactive = emps.filter(e=>e.Status==='Inactive');
  const projSet = new Set(active.map(e=>e.ProjectName));
  const parade = computeParade();
  const totalDemand = parade.reduce((s,p)=>s+p.demandTotal,0);
  const totalActual = parade.reduce((s,p)=>s+p.actualTotal,0);
  const shortage = Math.max(0,totalDemand-totalActual);
  const shortagePct = totalDemand>0 ? (shortage*100/totalDemand).toFixed(1) : 0;
  const recentJoins = active.filter(e=>daysAgo(e.JoinDate)<=30);
  const recentTransfers = DATA.transfers.filter(t=>daysAgo(t.TransferDate)<=30);
  const recentDisc = DATA.disciplinary.filter(a=>daysAgo(a.IssueDate)<=30);
  const recentExits = DATA.exits.filter(x=>daysAgo(x.ExitDate)<=30);
  
  const dData = _dashboardLastData || {
      activeCount: active.length,
      inactiveCount: inactive.length,
      projCount: DATA.projects.length,
      totalEmps: emps.length
  };

  const desigCount = {};
  active.forEach(e=>desigCount[e.Designation]=(desigCount[e.Designation]||0)+1);
  const desigRows = Object.entries(desigCount).sort((a,b)=>b[1]-a[1]);

  const alerts = computeAlerts();
  
  container.innerHTML = \`
    <div class="kpi-grid">
      \${kpi('Active Employees', num(dData.activeCount), 'g', ico('users'), \`\${num(dData.totalEmps)} total\`,'','employees')}
      \${kpi('Inactive Employees', num(dData.inactiveCount), 'r', ico('x'), \`\${num((dData.inactiveCount*100/(dData.totalEmps||1)).toFixed(1))}% of total\`,'','employees')}
      \${kpi('Total Projects', num(dData.projCount), 'p', ico('home'), \`\${num(dData.projCount)} total\`,'','projects')}
      \${kpi('New Joins (30d)', num(recentJoins.length), 'b', ico('trend'), \`+\${num((recentJoins.length*100/(dData.activeCount||1)).toFixed(1))}%\`, 'up','recruitment')}
      \${kpi('Exits (30d)', num(recentExits.length), 'r', ico('x'), 'Turnover rate','','exit')}
      \${kpi('Manpower Shortage', num(shortage), 'y', ico('warn'), \`\${num(shortagePct)}% shortage\`, 'down','parade')}
      \${kpi('Transfers (30d)', num(recentTransfers.length), 'b', ico('refresh'), '','','transfer')}
      \${kpi('Disciplinary (30d)', num(recentDisc.length), 'r', ico('warn'), '','','disciplinary')}
    </div>`;

html = html.replace(oldFuncStart, newStart);
fs.writeFileSync('index.html', html);
console.log('Replaced renderDashboard implementation');
