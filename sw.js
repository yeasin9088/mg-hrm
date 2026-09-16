/* =====================================================================
   MG Security HRM — Service Worker
   কাজ: অ্যাপের ফাইলগুলো ফোনে/কম্পিউটারে জমা রাখা (offline-এ খোলার জন্য)
   ===================================================================== */
const CACHE = 'mghrm-v10';  /* v3.5: bumped v9→v10 (Transfer action buttons + Meeting overhaul + Employee history bug fix + Toast top-right + To-Do reorder + Import module + Wipe DB + Serial columns) */
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

  // Supabase / auth / CDN → কখনো ক্যাশ করব না, সবসময় নেটওয়ার্ক
  if (url.hostname.includes('supabase') ||
      url.hostname.includes('jsdelivr') ||
      url.hostname.includes('cloudflareinsights')) {
    return; // ব্রাউজার নিজে হ্যান্ডল করবে
  }
  if (e.request.method !== 'GET') return;

  // অ্যাপের নিজের ফাইল → network-first, না পেলে cache
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
