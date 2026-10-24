const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('index.html', 'utf8');
const begin = source.indexOf('(function(){\n  if (window.__mgTd3) return;');
const firstEnd = source.indexOf('  /* ===== C2. Pending Queue State', begin);
const managerStart = source.indexOf('  window.mtSetManagerStatus = async function', firstEnd);
const managerEnd = source.indexOf("  document.addEventListener('keydown'", managerStart);
assert(begin >= 0 && firstEnd > begin && managerStart > firstEnd && managerEnd > managerStart);
const selected = source.slice(begin, firstEnd) + source.slice(managerStart, managerEnd) + '})();';

test('manager decision remains unchanged when database did not confirm a write', async () => {
  const row = { id: 7, manager_status: 'none', updated_at: '2026-10-20T00:00:00Z' };
  const notices = [];
  const context = vm.createContext({
    Date, console: { error() {} },
    DATA: { todos: [row] },
    document: { getElementById: () => null },
    appData: { update: async () => null },
    toast: (message, level) => notices.push({ message, level }),
    renderTodo() {},
    persist() { throw Error('should not persist an unconfirmed decision'); },
  });
  context.window = context;
  vm.runInContext(selected, context);
  await context.mtSetManagerStatus(7, 'approved');
  assert.equal(row.manager_status, 'none');
  assert.equal(row.updated_at, '2026-10-20T00:00:00Z');
  assert.equal(notices.some(n => n.level === 'success'), false);
  assert.equal(notices.some(n => n.level === 'error'), true);

  context.appData.update = async () => [{ id: 7 }];
  context.persist = async () => {};
  await context.mtSetManagerStatus(7, 'asked');
  assert.equal(row.manager_status, 'asked');
  assert.equal(notices.at(-1).level, 'success');
});
