/* MG-HRM PWA v54: public app-shell caching, safe update lifecycle, Web Push.
 * Cache Storage must NEVER contain HR employee records, Supabase responses,
 * credentials, authenticated API responses, POST bodies or pending writes.
 */
'use strict';
const CACHE = 'mghrm-v54';
const CACHE_PREFIX = 'mghrm-v';
const LOGO_URL = new URL('icon-192.png?notification-icon=v39', self.registration.scope).href;
const BADGE_URL = new URL('notification-small-m-96.png?notification-badge=v39', self.registration.scope).href;
const BRAND_IMAGES = [LOGO_URL, BADGE_URL];
const SHELL = [
  './', './index.html', './offline.html', './manifest.json',
  './app-logo-192.webp', './icon-192.png', './icon-512.png', './bd-geo.json',
  './config.js', './app-core.js', './disciplinary-model.js',
  './exit-model.js', './exit-service.js', './exit-ui.js', './exit-reports.js', './exit-ui.css',
  './meeting-attendance.js', './meeting-ui.js', './meeting-ui.css',
  './notification-model.js', './notification-center.js', './notification-presence.js',
  './notification-ui.js', './notification-ui.css', './notification-settings.js',
  './notification-simple.js', './todo-compact.css',
  './pwa-experience.js', './pwa-experience.css'
];
const SCOPE = new URL(self.registration.scope);
const SCOPE_PATH = SCOPE.pathname;
// A deliberate allowlist. No generic .json or /api caching.
const STATIC_PATHS = new Set(SHELL.filter(x => x !== './').map(x => new URL(x, self.registration.scope).pathname));

async function cacheVerifiedBrandImage(cache, url) {
  const response = await fetch(new Request(url, { cache: 'reload' }));
  if (!response.ok || !/^image\/png(?:;|$)/i.test(response.headers.get('content-type') || '')) {
    throw Error('Push notification brand image is not a valid PNG');
  }
  await cache.put(url, response);
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Branded push assets are a hard requirement, independently of app shell.
    for (const url of BRAND_IMAGES) await cacheVerifiedBrandImage(cache, url);
    // Optional shell warm-up; a transient failure must not disable Web Push.
    // Fail closed: never cache alternate HTML responses for JS/CSS/icon URLs.
    try { await cache.addAll(SHELL); }
    catch (err) { console.warn('[MG-HRM PWA] Shell pre-cache incomplete:', err); }
    // Deliberately NO automatic skipWaiting on upgrades: open forms remain safe.
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k.startsWith(CACHE_PREFIX) && k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', event => {
  const kind = event.data && event.data.type;
  if (kind === 'MG_PWA_SKIP_WAITING') {
    // Only after the app UI explicitly asks the operator to apply an update.
    event.waitUntil(self.skipWaiting());
  } else if (kind === 'MG_PWA_GET_VERSION' && event.source && event.source.postMessage) {
    event.source.postMessage({ type: 'MG_PWA_VERSION', version: CACHE });
  }
});

function isEligibleStaticRequest(request, url) {
  if (request.method !== 'GET' || url.origin !== SCOPE.origin || !url.pathname.startsWith(SCOPE_PATH)) return false;
  if (request.headers && request.headers.has && (request.headers.has('Authorization') || request.headers.has('authorization'))) return false;
  if (url.search && !BRAND_IMAGES.includes(url.href)) return false; // avoid unknown dynamic query cache keys
  return STATIC_PATHS.has(url.pathname);
}
function expectedAssetType(path) {
  if (/\.js$/i.test(path)) return /(?:javascript|ecmascript)/i;
  if (/\.css$/i.test(path)) return /text\/css/i;
  if (/\.png$/i.test(path)) return /^image\/png(?:;|$)/i;
  if (/\.webp$/i.test(path)) return /^image\/webp(?:;|$)/i;
  if (/\.json$/i.test(path)) return /(?:application|text)\/json/i;
  if (/\.html$/i.test(path)) return /text\/html/i;
  return null;
}
function validCacheResponse(response, url) {
  if (!response || !response.ok || (response.type && !['basic', 'default'].includes(response.type))) return false;
  const expected = expectedAssetType(url.pathname);
  return Boolean(expected && expected.test(response.headers && response.headers.get('content-type') || ''));
}
async function networkFirstStatic(request, url) {
  try {
    const response = await fetch(new Request(request, { cache: 'reload' }));
    if (validCacheResponse(response, url)) {
      // No background writes whose failure can affect the actual response.
      try { const cache = await caches.open(CACHE); await cache.put(url.pathname, response.clone()); } catch (_) {}
    }
    return response;
  } catch (_) {
    const cached = await caches.match(url.pathname);
    return validCacheResponse(cached, url) ? cached : Response.error(); // Never serve cached HTML as JS/CSS/PNG.
  }
}
async function navigationResponse(request) {
  try {
    // Navigation always checks the network, so logout/login is not simulated
    // offline and stale HR data is never presented as a fresh session.
    return await fetch(new Request(request, { cache: 'reload' }));
  } catch (_) {
    const cached = await caches.match(new URL('./offline.html', self.registration.scope).pathname);
    if (cached && validCacheResponse(cached, new URL('./offline.html', self.registration.scope))) return cached;
    return new Response('<!doctype html><title>MG-HRM Offline</title><h1>You are offline</h1><p>Reconnect to open MG-HRM.</p>', {
      status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' }
    });
  }
}
self.addEventListener('fetch', event => {
  const request = event.request;
  if (!request || request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== SCOPE.origin || !url.pathname.startsWith(SCOPE_PATH)) return; // Supabase/CDN bypass.
  if (request.mode === 'navigate') {
    event.respondWith(navigationResponse(request));
    return;
  }
  if (BRAND_IMAGES.includes(url.href)) {
    event.respondWith(caches.match(url.href).then(cached => cached || fetch(request)));
    return;
  }
  if (!isEligibleStaticRequest(request, url)) return; // Dynamic data: browser/network only.
  event.respondWith(networkFirstStatic(request, url));
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
  if (typeof value !== 'string') return fallback;
  const plain = value.replace(/<[^>]*>/g, ' ').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e]/g, ' ').replace(/\s+/gu, ' ').trim();
  if (!plain) return fallback;
  const chars = typeof Intl.Segmenter === 'function'
    ? Array.from(new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(plain), part => part.segment)
    : Array.from(plain);
  return chars.length > max ? chars.slice(0, max - 1).join('').trimEnd() + '…' : plain;
}
function safeRoute(value) {
  let route = String(value || '').replace(/^#?\/?/, '').split('?')[0];
  if (route === 'meetings') route = 'meeting';
  const allowed = ['dashboard', 'notifications', 'todo', 'transfer', 'employees', 'recruitment', 'disciplinary', 'leave', 'uniform', 'meeting', 'reports'];
  return allowed.includes(route) ? route : 'notifications';
}
self.addEventListener('push', (event) => {
  const payload = safePushPayload(event);
  const notificationId = /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(String(payload.notification_id || payload.id || ''))
    ? String(payload.notification_id || payload.id) : '';
  const title = pushText(payload.title, 90, 'MG-HRM');
  const body = pushText(payload.body, 200, 'You have a new notification. Open MG-HRM to review it.');
  const route = safeRoute(payload.action_route || payload.route);
  const priority = String(payload.priority || 'Normal');
  const options = {
    body, icon: LOGO_URL, badge: BADGE_URL,
    tag: 'mghrm-' + (notificationId || 'notification'),
    renotify: false,
    requireInteraction: priority === 'Urgent' || payload.require_interaction === true,
    data: {
      actionToken: /^[0-9a-f]{64}$/.test(payload.action_token || '') ? payload.action_token : null,
      notificationId, route,
      entityType: payload.entity_type === 'todo' ? 'todo' : '',
      entityId: route === 'todo' && payload.entity_type === 'todo' && /^\d{1,18}$/.test(String(payload.entity_id || ''))
        ? String(payload.entity_id) : null
    }
  };
  if (options.data.actionToken && payload.task_actions === true) {
    const limit = typeof Notification !== 'undefined' && Number.isInteger(Notification.maxActions) ? Notification.maxActions : 2;
    const actions = [
      {action:'read',title:'Mark as read'},
      {action:'remind',title:'Remind next time'},
      {action:'complete',title:'Complete'}
    ];
    // With two slots, tapping the notification itself supplies the Read action.
    options.actions = limit >= 3 ? actions : limit === 2 ? [actions[2],actions[1]] : limit === 1 ? [actions[2]] : [];
  }
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const route = safeRoute(data.route);
  const action = ['read','remind','complete'].includes(event.action) ? event.action : '';
  const targetUrl = new URL('./index.html?notification_route=' + encodeURIComponent(route) + '&notification_id=' + encodeURIComponent(data.notificationId || '') + (data.entityId ? '&notification_entity=' + encodeURIComponent(data.entityId) : '') + (action ? '&notification_action='+action : ''), self.registration.scope).href;
  const message = {
    type: 'MG_NOTIFICATION_CLICK', notificationId: data.notificationId || '',
    action,
    route, entityType: data.entityType || '', entityId: data.entityId == null ? null : data.entityId
  };
  event.waitUntil((async () => {
    if (action && /^[0-9a-f]{64}$/.test(data.actionToken || '')) {
      try {
        const response = await fetch('https://enkggoozsvvkgbjeghbf.supabase.co/functions/v1/notification-device-action', {
          method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:data.actionToken,action}),
          ...(typeof AbortSignal !== 'undefined' && AbortSignal.timeout ? {signal:AbortSignal.timeout(12000)} : {})
        });
        if (response.ok && (await response.json()).ok === true) {
          const clients = await self.clients.matchAll({type:'window',includeUncontrolled:true});
          clients.filter(client=>client.url.startsWith(self.registration.scope)).forEach(client=>client.postMessage({type:'MG_NOTIFICATION_ACTION_CONFIRMED',notificationId:data.notificationId,action}));
          return;
        }
      } catch (_) { /* Open the authenticated app to finish an unconfirmed action. */ }
    }
    return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
    for (const client of clientList) {
      if (client.url.indexOf(self.registration.scope) === 0) {
        if (action && 'navigate' in client) return client.navigate(targetUrl).then(()=>client.focus());
        client.postMessage(message);
        return 'focus' in client ? client.focus() : client;
      }
    }
    if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    return undefined;
    });
  })());
});
self.addEventListener('pushsubscriptionchange', event => {
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
    clients.forEach(client => client.postMessage({ type: 'MG_PUSH_SUBSCRIPTION_CHANGED' }));
  }));
});
