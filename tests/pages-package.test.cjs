const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const root = path.resolve(__dirname, '..');
const builder = () => import(pathToFileURL(path.join(root, 'scripts/build-pages.mjs')).href);

test('Pages package contains only unchanged runtime assets and preserves relative references', async () => {
  const {buildPages, publicAssets} = await builder();
  // Leave temporary artifacts intact: this preparation must not delete files.
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'mghrm-pages-'));
  const output = buildPages(path.join(temporary, 'site'));
  assert.deepEqual(fs.readdirSync(output).sort(), [...publicAssets].sort());
  for (const name of publicAssets) {
    assert.deepEqual(fs.readFileSync(path.join(output, name)), fs.readFileSync(path.join(root, name)));
    assert(!/\.(sql|md|cjs|mjs)$/.test(name));
  }
  const checkReference = reference => {
    const name = reference.split(/[?#]/)[0].replace(/^\.\//, '') || 'index.html';
    assert(publicAssets.includes(name), 'Unpackaged local browser reference: ' + reference);
  };
  const html = fs.readFileSync(path.join(output, 'index.html'), 'utf8');
  // Template strings and dynamic user-provided images are not static references.
  for (const match of html.matchAll(/(?:src|href)\s*=\s*["'](\.\/[^"']+)["']/g)) checkReference(match[1]);
  const sw = fs.readFileSync(path.join(output, 'sw.js'), 'utf8');
  const shell = sw.match(/const SHELL = (\[[^;]+\]);/);
  assert(shell, 'Service worker shell not found');
  for (const match of shell[1].matchAll(/'([^']+)'/g)) checkReference(match[1]);
  const manifest = JSON.parse(fs.readFileSync(path.join(output, 'manifest.json'), 'utf8'));
  [manifest.start_url, manifest.scope, ...manifest.icons.map(x => x.src), ...manifest.shortcuts.map(x => x.url)].forEach(checkReference);
  for (const match of html.matchAll(/fetch\(['"](\.\/[^'"]+)['"]/g)) checkReference(match[1]);
});

test('Pages builder refuses stale output without modifying or deleting existing files', async () => {
  const {buildPages} = await builder();
  const output = fs.mkdtempSync(path.join(os.tmpdir(), 'mghrm-pages-stale-'));
  const marker = path.join(output, 'private.sql');
  fs.writeFileSync(marker, '-- synthetic marker');
  assert.throws(() => buildPages(output), /Output already exists/);
  assert.equal(fs.readFileSync(marker, 'utf8'), '-- synthetic marker');
  assert.deepEqual(fs.readdirSync(output), ['private.sql']);
});

test('Pages workflow uploads the allowlisted package rather than the repository', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/pages.yml'), 'utf8');
  assert.match(workflow, /run: node scripts\/build-pages\.mjs/);
  assert.match(workflow, /uses: actions\/upload-pages-artifact@v4\s+with:\s+path: _site\s/);
  assert(!/path:\s*\.(?:\/)?\s*$/m.test(workflow));
});
