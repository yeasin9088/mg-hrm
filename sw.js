/* =====================================================================
   MG Security HRM — Service Worker
   Role: Offline application cache + safe notification display/click flow
   ===================================================================== */
const CACHE = 'mghrm-v29';
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
  // Supabase / auth / CDN -> bypass cache, always use network
  if (url.hostname.includes('supabase') ||
      url.hostname.includes('jsdelivr') ||
      url.hostname.includes('cloudflareinsights')) {
    return;
  }
  if (e.request.method !== 'GET') return;
  const isCoreAsset = url.pathname.endsWith('/index.html') ||
    url.pathname.endsWith('/app-core.js') ||
    url.pathname.endsWith('/config.js') ||
    e.request.mode === 'navigate';
  const networkRequest = isCoreAsset
    ? new Request(e.request, { cache: 'reload' })
    : e.request;
  e.respondWith(
    fetch(networkRequest)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match('./index.html')))
  );
});

function safePushPayload(event) {
  if (!event.data) return {};
  try {
    const parsed = event.data.json();
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (err) {
    try { return { body: event.data.text() }; } catch (ignore) { return {}; }
  }
}

function safeRoute(value) {
  const route = String(value || '').replace(/^#?\/?/, '').split('?')[0];
  const allowed = ['dashboard', 'notifications', 'todo', 'transfer', 'employees', 'recruitment', 'disciplinary', 'leave', 'uniform', 'meetings', 'reports'];
  return allowed.includes(route) ? route : 'notifications';
}

self.addEventListener('push', (event) => {
  const payload = safePushPayload(event);
  const notificationId = String(payload.notification_id || payload.id || '');
  const title = String(payload.title || 'MG Security HRM');
  const body = String(payload.body || payload.message || 'You have a new notification.');
  const route = safeRoute(payload.action_route || payload.route);
  const priority = String(payload.priority || 'Normal');
  const options = {
    body,
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: String(payload.tag || notificationId || 'mghrm-notification'),
    renotify: false,
    requireInteraction: priority === 'Urgent' || payload.require_interaction === true,
    data: {
      notificationId,
      route,
      actionParams: payload.action_params && typeof payload.action_params === 'object' ? payload.action_params : {},
      entityType: String(payload.entity_type || ''),
      entityId: payload.entity_id == null ? null : String(payload.entity_id)
    }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const route = safeRoute(data.route);
  const targetUrl = new URL('./index.html?notification_route=' + encodeURIComponent(route), self.registration.scope).href;
  const message = {
    type: 'MG_NOTIFICATION_CLICK',
    notificationId: data.notificationId || '',
    route,
    actionParams: data.actionParams || {},
    entityType: data.entityType || '',
    entityId: data.entityId == null ? null : data.entityId
  };

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.indexOf(self.registration.scope) === 0) {
          client.postMessage(message);
          return 'focus' in client ? client.focus() : client;
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
      return undefined;
    })
  );
});
