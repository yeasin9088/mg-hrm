import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
// Explicit browser assets only. Never copy the repository recursively.
export const publicAssets = Object.freeze([
  'index.html', 'app-core.js', 'exit-model.js', 'exit-service.js', 'exit-ui.js', 'exit-reports.js', 'exit-ui.css', 'disciplinary-model.js', 'meeting-attendance.js', 'meeting-ui.js', 'meeting-ui.css', 'notification-model.js', 'notification-center.js', 'notification-presence.js', 'notification-ui.js', 'notification-ui.css', 'notification-settings.js', 'notification-engine-ui.js', 'notification-workflow-ui.js', 'notification-workflow-ui.css', 'config.js', 'sw.js',
  'manifest.json', 'icon-192.png', 'icon-512.png', 'app-logo-192.webp', 'notification-badge-96.png', 'notification-small-m-96.png', 'bd-geo.json'
]);

export function buildPages(destination = path.join(root, '_site')) {
  const output = path.resolve(destination);
  // Refuse existing output, including stale SQL/docs. No files are deleted.
  if (fs.existsSync(output)) throw new Error('Output already exists; use a new directory: ' + output);
  for (const asset of publicAssets) {
    const stat = fs.lstatSync(path.join(root, asset));
    if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('Expected regular public asset: ' + asset);
  }
  fs.mkdirSync(output);
  for (const asset of publicAssets) {
    fs.copyFileSync(path.join(root, asset), path.join(output, asset), fs.constants.COPYFILE_EXCL);
  }
  return output;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 2) throw new Error('Usage: node scripts/build-pages.mjs');
  buildPages();
  console.log('Packaged ' + publicAssets.length + ' public assets into _site/ (SQL, docs and tests excluded).');
}
