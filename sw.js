/* =====================================================================
   MG Security HRM — Service Worker
   Role: Offline application cache + safe notification display/click flow
   ===================================================================== */
const CACHE = 'mghrm-v37';
const LOGO_URL = new URL('icon-192.png', self.registration.scope).href;
const SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png', './bd-geo.json', './config.js', './app-core.js', './meeting-attendance.js', './meeting-ui.js', './meeting-ui.css', './notification-model.js', './notification-center.js', './notification-presence.js', './notification-ui.js', './notification-ui.css', './notification-settings.js'];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(async (c) => {
    // Keep the previous worker active if the logo cannot be fetched. A failure
    // in an unrelated shell asset must not leave new pushes without branding.
    await c.add(new Request(LOGO_URL, { cache: 'reload' }));
    await c.addAll(SHELL.filter(asset => asset !== './icon-192.png')).catch(() => {});
  }));
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
  if (url.href === LOGO_URL) {
    e.respondWith(caches.match(LOGO_URL).then((cached) => cached || fetch(e.request)));
    return;
  }
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
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (err) {
    try { return { body: event.data.text() }; } catch (ignore) { return {}; }
  }
}
function pushText(value, max, fallback) {
  if(typeof value!=='string') return fallback;
  const plain=value.replace(/<[^>]*>/g,' ').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e]/g,' ').replace(/\s+/gu,' ').trim();
  if(!plain) return fallback;
  const chars=typeof Intl.Segmenter==='function'
    ? Array.from(new Intl.Segmenter(undefined,{granularity:'grapheme'}).segment(plain),part=>part.segment)
    : Array.from(plain);
  return chars.length>max?chars.slice(0,max-1).join('').trimEnd()+'…':plain;
}

function safeRoute(value) {
  let route = String(value || '').replace(/^#?\/?/, '').split('?')[0];
  if (route === 'meetings') route = 'meeting';
  const allowed = ['dashboard', 'notifications', 'todo', 'transfer', 'employees', 'recruitment', 'disciplinary', 'leave', 'uniform', 'meeting', 'reports'];
  return allowed.includes(route) ? route : 'notifications';
}

self.addEventListener('push', (event) => {
  const payload = safePushPayload(event);
  const notificationId = /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(String(payload.notification_id||payload.id||''))
    ? String(payload.notification_id||payload.id) : '';
  const title = pushText(payload.title, 90, 'MG-HRM');
  const body = pushText(payload.body, 200, 'You have a new notification. Open MG-HRM to review it.');
  const route = safeRoute(payload.action_route || payload.route);
  const priority = String(payload.priority || 'Normal');
  const options = {
    body,
    icon: LOGO_URL,
    badge: LOGO_URL,
    tag: 'mghrm-' + (notificationId || 'notification'),
    renotify: false,
    requireInteraction: priority === 'Urgent' || payload.require_interaction === true,
    data: {
      notificationId,
      route,
      entityType: payload.entity_type === 'todo' ? 'todo' : '',
      entityId: route === 'todo' && payload.entity_type === 'todo' && /^\d{1,18}$/.test(String(payload.entity_id||''))
        ? String(payload.entity_id) : null
    }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const route = safeRoute(data.route);
  const targetUrl = new URL('./index.html?notification_route=' + encodeURIComponent(route) + '&notification_id=' + encodeURIComponent(data.notificationId || '') + (data.entityId ? '&notification_entity=' + encodeURIComponent(data.entityId) : ''), self.registration.scope).href;
  const message = {
    type: 'MG_NOTIFICATION_CLICK',
    notificationId: data.notificationId || '',
    route,
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
