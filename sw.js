/* =====================================================================
   MG Security HRM — Service Worker
   Role: Cache application assets offline
   ===================================================================== */
const CACHE = 'mghrm-v14';  /* v3.5: bumped v9→v10 (Transfer action buttons + Meeting overhaul + Employee history bug fix + Toast top-right + To-Do reorder + Import module + Wipe DB + Serial columns) */
const SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png', './bd-geo.json', './config.js', './app-core.js'];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL).catch(() => {})));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Supabase / auth / CDN → bypass cache, always use network
  if (url.hostname.includes('supabase') ||
      url.hostname.includes('jsdelivr') ||
      url.hostname.includes('cloudflareinsights')) {
    return; // Handled directly by browser
  }
  if (e.request.method !== 'GET') return;

  // App shell files → network-first, fallback to cache
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match('./index.html')))
  );
});
