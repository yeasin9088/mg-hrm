/* =====================================================================
   MG Security HRM — Service Worker
   Role: Offline application cache + safe notification display/click flow
   ===================================================================== */
const CACHE = 'mghrm-v35';
const SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png', './bd-geo.json', './config.js', './app-core.js', './meeting-attendance.js', './meeting-ui.js', './meeting-ui.css', './notification-model.js', './notification-center.js', './notification-presence.js', './notification-ui.js', './notification-ui.css', './notification-settings.js'];

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
    url.pathname.endsWith('/meeting-attendance.js') ||
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
  let route = String(value || '').replace(/^#?\/?/, '').split('?')[0];
  if (route === 'meetings') route = 'meeting';
  const allowed = ['dashboard', 'notifications', 'todo', 'transfer', 'employees', 'recruitment', 'disciplinary', 'leave', 'uniform', 'meeting', 'reports'];
  return allowed.includes(route) ? route : 'notifications';
}

self.addEventListener('push', (event) => {
  const payload = safePushPayload(event);
  const notificationId = String(payload.notification_id || payload.id || '');
  const title = 'MG-HRM';
  const body = 'You have a new notification. Open MG-HRM to review it.';
  const route = safeRoute(payload.action_route || payload.route);
  const priority = String(payload.priority || 'Normal');
  const options = {
    body,
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: 'mghrm-' + (notificationId || 'notification'),
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
  const targetUrl = new URL('./index.html?notification_route=' + encodeURIComponent(route) + '&notification_id=' + encodeURIComponent(data.notificationId || '') + '&notification_entity=' + encodeURIComponent(data.entityId || ''), self.registration.scope).href;
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

self.addEventListener('pushsubscriptionchange', event => {
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(clients => {
    clients.forEach(client => client.postMessage({type:'MG_PUSH_SUBSCRIPTION_CHANGED'}));
  }));
});
