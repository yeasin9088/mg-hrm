/* MG-HRM PWA App Center v1 — app-only UX, no employee data or credentials. */
(function () {
  'use strict';
  if (window.__mgPwaExperience) return;
  window.__mgPwaExperience = true;

  var state = { registration:null, installPrompt:null, updateReady:false,
    applyRequested:false, lastUpdateCheck:0, panelOpen:false, installed:false };
  var root, trigger, panel, banner, statusLine, versionLine, installButton, updateButton;
  var updateInterval = 6 * 60 * 60 * 1000;
  function standalone() {
    return Boolean((window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
      (window.navigator && window.navigator.standalone === true));
  }
  function supported() { return 'serviceWorker' in navigator && window.isSecureContext !== false; }
  function make(tag, cls, content) {
    var el = document.createElement(tag);
    if (cls) el.className = cls;
    if (content != null) el.textContent = content;
    return el;
  }
  function button(label, action) {
    var el = make('button', 'mg-pwa-action', label);
    el.type = 'button';
    el.addEventListener('click', action);
    return el;
  }
  function showBanner(text, actionLabel, handler) {
    banner.replaceChildren();
    banner.appendChild(make('span', '', text));
    if (actionLabel) banner.appendChild(button(actionLabel, handler));
    banner.hidden = false;
  }
  function updateStatus() {
    var offline = navigator.onLine === false;
    if (state.updateReady && !offline) showBanner('MG-HRM-এর নতুন সংস্করণ প্রস্তুত। কাজ সেভ করে আপডেট করুন।', 'আপডেট', applyUpdate);
    else if (offline) showBanner('ইন্টারনেট সংযোগ নেই — কোনো পরিবর্তন সেভ হয়েছে ধরে নেবেন না।', null, null);
    else banner.hidden = true;
    if (statusLine) statusLine.textContent = offline ? 'সংযোগ: অফলাইন' : 'সংযোগ: অনলাইন (সার্ভারের অবস্থা যাচাই করা হয়নি)';
    if (installButton) installButton.hidden = state.installed || !state.installPrompt;
    if (updateButton) updateButton.hidden = !state.updateReady;
  }
  function togglePanel(next) {
    state.panelOpen = next;
    panel.hidden = !next;
    trigger.setAttribute('aria-expanded', String(next));
    if (next) { updateStatus(); panel.querySelector('button').focus(); }
    else trigger.focus();
  }
  function createUi() {
    root = make('div', 'mg-pwa-root'); root.id = 'mgPwaRoot';
    banner = make('div', 'mg-pwa-banner'); banner.id = 'mgPwaBanner';
    banner.setAttribute('role','status'); banner.setAttribute('aria-live','polite'); banner.hidden = true;
    trigger = make('button', 'mg-pwa-fab', 'অ্যাপ');
    trigger.type = 'button'; trigger.title = 'MG-HRM অ্যাপ সেটিংস';
    trigger.setAttribute('aria-label','MG-HRM অ্যাপ কেন্দ্র');
    trigger.setAttribute('aria-expanded','false'); trigger.setAttribute('aria-controls','mgPwaPanel');
    trigger.addEventListener('click', function () { togglePanel(!state.panelOpen); });
    panel = make('section', 'mg-pwa-panel'); panel.id = 'mgPwaPanel'; panel.hidden = true;
    panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-label','MG-HRM অ্যাপ কেন্দ্র');
    var head = make('div', 'mg-pwa-panel-head');
    var headTexts = make('div', '');
    headTexts.appendChild(make('strong', '', 'MG-HRM · অ্যাপ কেন্দ্র'));
    headTexts.appendChild(make('small', '', 'ইনস্টলেশন, সংযোগ ও আপডেট'));
    var close = button('বন্ধ', function () { togglePanel(false); });
    close.className = 'mg-pwa-close';
    head.appendChild(headTexts); head.appendChild(close);
    panel.appendChild(head);
    var summary = make('div','mg-pwa-summary');
    statusLine = make('div', '', 'সংযোগ যাচাই হচ্ছে…');
    versionLine = make('div', '', 'সংস্করণ: যাচাই হচ্ছে…');
    var notificationLine = make('div', '', 'নোটিফিকেশন: ' +
      (!('Notification' in window) ? 'এই ব্রাউজারে নেই' :
      Notification.permission === 'granted' ? 'অনুমোদিত' : Notification.permission === 'denied' ? 'বন্ধ' : 'অনুমতি দেওয়া হয়নি'));
    summary.appendChild(statusLine); summary.appendChild(versionLine); summary.appendChild(notificationLine);
    summary.appendChild(make('div', '', 'ইনস্টলেশন: ' + (standalone() ? 'ইনস্টল করা অ্যাপ মোড' : 'ব্রাউজার মোড')));
    panel.appendChild(summary);
    var actions = make('div','mg-pwa-actions');
    installButton = button('অ্যাপ ইনস্টল করুন', requestInstall);
    installButton.hidden = true; actions.appendChild(installButton);
    updateButton = button('নতুন সংস্করণ চালু করুন', applyUpdate);
    updateButton.hidden = true; actions.appendChild(updateButton);
    actions.appendChild(button('আপডেট পরীক্ষা', checkUpdates));
    actions.appendChild(button('অ্যাপ রিফ্রেশ', function () { window.location.reload(); }));
    panel.appendChild(actions);
    var help = make('p','mg-pwa-help', 'অফলাইনে HRM ডেটা সেভ বা পরিবর্তন নিশ্চিত করবেন না। ইনস্টল অপশন না দেখালে ব্রাউজারের মেনু থেকে “Install app” বা “Add to Home screen” ব্যবহার করুন।');
    panel.appendChild(help);
    root.appendChild(banner); root.appendChild(trigger); root.appendChild(panel);
    document.body.appendChild(root);
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && state.panelOpen) togglePanel(false);
    });
    document.addEventListener('pointerdown', function(event) {
      if (state.panelOpen && !panel.contains(event.target) && !trigger.contains(event.target)) togglePanel(false);
    });
    updateStatus();
  }
  function onWaiting() {
    if (!state.registration || !state.registration.waiting || !navigator.serviceWorker.controller) return;
    state.updateReady = true;
    updateStatus();
  }
  function watchWorker(registration) {
    if (!registration) return;
    state.registration = registration;
    onWaiting();
    registration.addEventListener('updatefound', function () {
      var worker = registration.installing;
      if (!worker) return;
      worker.addEventListener('statechange', function () {
        if (worker.state === 'installed') onWaiting();
      });
    });
    if (registration.active && registration.active.postMessage) registration.active.postMessage({type:'MG_PWA_GET_VERSION'});
  }
  async function setupWorker() {
    if (!supported()) {
      versionLine.textContent = 'সংস্করণ: এই পরিবেশে PWA সমর্থিত নয়';
      return;
    }
    try {
      var registration = await navigator.serviceWorker.getRegistration();
      if (!registration) registration = await navigator.serviceWorker.register('./sw.js', { scope:'./', updateViaCache:'none' });
      watchWorker(registration);
      navigator.serviceWorker.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'MG_PWA_VERSION' && typeof event.data.version === 'string') {
          versionLine.textContent = 'ক্যাশ সংস্করণ: ' + event.data.version;
        }
      });
      navigator.serviceWorker.addEventListener('controllerchange', function () {
        if (state.applyRequested) window.location.reload();
      });
      checkUpdates(false);
    } catch (error) {
      versionLine.textContent = 'আপডেট যাচাই ব্যর্থ';
      console.warn('[MG-HRM PWA] Registration:',error);
    }
  }
  async function checkUpdates(notify) {
    if (notify == null) notify = true;
    if (!state.registration || navigator.onLine === false) {
      if (notify) showBanner('আপডেট পরীক্ষা করতে ইন্টারনেট সংযোগ প্রয়োজন।');
      return;
    }
    try {
      state.lastUpdateCheck = Date.now();
      await state.registration.update();
      onWaiting();
      if (notify && !state.updateReady) showBanner('আপডেট পরীক্ষা সম্পন্ন। নতুন সংস্করণ প্রস্তুত থাকলে এখানে দেখাবে।');
    } catch (error) {
      if (notify) showBanner('আপডেট পরীক্ষা করা যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।');
      console.warn('[MG-HRM PWA] Update check:',error);
    }
  }
  function applyUpdate() {
    var reg = state.registration;
    if (!reg || !reg.waiting) { state.updateReady = false; updateStatus(); return; }
    if (!window.confirm('খোলা ফর্মে কোনো অসম্পূর্ণ তথ্য থাকলে আগে সেভ করুন। এখন অ্যাপ আপডেট ও রিফ্রেশ করবেন?')) return;
    state.applyRequested = true;
    reg.waiting.postMessage({type:'MG_PWA_SKIP_WAITING'});
  }
  async function requestInstall() {
    if (!state.installPrompt) return;
    var prompt = state.installPrompt;
    state.installPrompt = null;
    try { await prompt.prompt(); if (prompt.userChoice) await prompt.userChoice; }
    catch (error) { console.warn('[MG-HRM PWA] Install prompt:', error); }
    updateStatus();
  }
  function init() {
    state.installed = standalone();
    createUi();
    window.addEventListener('online', function () { updateStatus(); checkUpdates(false); });
    window.addEventListener('offline', updateStatus);
    window.addEventListener('appinstalled', function () { state.installed = true; state.installPrompt = null; updateStatus(); });
    window.addEventListener('beforeinstallprompt', function (event) {
      if (standalone()) return;
      event.preventDefault(); // Show only after a deliberate operator gesture.
      state.installPrompt = event;
      updateStatus();
    });
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'visible' && Date.now() - state.lastUpdateCheck > updateInterval) checkUpdates(false);
    });
    setupWorker();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once:true });
  else init();
})();
