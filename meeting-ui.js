/* Meeting board presentation only. Persistence and RPC contracts live elsewhere. */
(function (global) {
  'use strict';
  const filters = ['all', 'pending', 'present', 'absent'];
  const views = new Map();
  let current = null;
  let pendingRepresentative = null;
  const repId = rep => String(rep && typeof rep === 'object' ? (rep.employee_id || rep.EmployeeID || rep.id || '') : (rep || '')).trim();
  const repName = rep => String(rep && typeof rep === 'object' ? (rep.full_name || rep.fullName || rep.FullName || rep.name || '') : '').trim();
  const hasRepresentative = (day, project) => !!(repId(day.representatives?.[project]) && repName(day.representatives?.[project]));
  function status(day, project) {
    return day.present?.[project] ? 'present' : day.absent?.[project] ? 'absent' : 'pending';
  }
  function summarize(projects, day) {
    const unique = [...new Set(projects)];
    const result = {total: unique.length, present: 0, absent: 0, pending: 0, missing: []};
    unique.forEach(project => {
      const value = status(day, project);
      result[value]++;
      if (value === 'pending') result.missing.push(project);
    });
    result.completed = result.present + result.absent;
    result.percent = result.total ? Math.round(result.completed * 100 / result.total) : 0;
    return result;
  }
  function matches(name, state, filter, query) {
    return (filter === 'all' || state === filter) && name.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase());
  }
  function validation(projects, day, historicalEdit, original) {
    const missing = historicalEdit ? [] : summarize(projects, day).missing;
    const missingRepresentatives = [...new Set(projects)].filter(project => {
      if (!day.present?.[project] || hasRepresentative(day, project)) return false;
      // Grandfather an unchanged historical Present row; never rewrite old data.
      return !(historicalEdit && original?.present?.[project] && !hasRepresentative(original, project));
    });
    return {allowed: !missing.length && !missingRepresentatives.length, missing, missingRepresentatives};
  }
  const byId = id => document.getElementById(id);
  function setFilter(value) {
    if (!current) return;
    current.view.filter = filters.includes(value) ? value : 'all';
    refresh();
  }
  function search(value) {
    if (!current) return;
    current.view.query = value;
    refresh();
  }
  function mount(iso, day, projects, historicalEdit) {
    const board = byId('mtTiles');
    current = null;
    pendingRepresentative = null;
    if (!board) return;
    if (!views.has(iso)) views.set(iso, {filter: 'all', query: '', review: false});
    current = {iso, day, projects, historicalEdit, view: views.get(iso), board};
    byId('mtSearch').value = current.view.query;
    refresh();
  }
  function refresh() {
    if (!current || !current.board.isConnected) return;
    const {day, projects, view, historicalEdit, board} = current;
    const counts = summarize(projects, day);
    const original = global.mtAttendanceEdits?.[current.iso]?.original || null;
    const check = validation(projects, day, historicalEdit, original);
    const focusedTile = document.activeElement?.closest?.('.mt-tile');
    const focusedStatus = document.activeElement?.dataset?.status;
    const badge = byId('mtAttendanceCounterBadge');
    if (badge) badge.textContent = 'Present: ' + counts.present + ' / ' + counts.total;
    ['total', 'present', 'absent', 'pending'].forEach(key => {
      byId('mtCount-' + key).textContent = counts[key];
    });
    byId('mtProgress').value = counts.percent;
    byId('mtProgress').setAttribute('aria-valuetext', counts.completed + ' of ' + counts.total + ' projects marked');
    byId('mtProgressLabel').textContent = counts.completed + ' of ' + counts.total + ' marked · ' + counts.percent + '%';
    byId('mtDraftLabel').textContent = historicalEdit ? 'Editing saved attendance' : 'Draft · not submitted';
    byId('mtDraftHelp').textContent = check.missingRepresentatives.length
      ? check.missingRepresentatives.length + ' Present project(s) need a representative before saving.'
      : historicalEdit ? 'Update changes when ready. Historical records remain intact.'
      : 'Changes are not submitted yet. Mark every required project, then submit.';
    const submit = byId('mtSubmitDayBtn');
    if (submit && !historicalEdit) {
      submit.disabled = !check.allowed || !!global.mtAttendanceSaving;
      submit.title = check.missingRepresentatives.length ? 'Choose a representative for every Present project' : counts.pending ? 'Mark all pending projects before submitting' : 'Submit complete attendance';
    }
    const review = byId('mtReviewPending');
    review.hidden = counts.pending === 0 && check.missingRepresentatives.length === 0;
    review.textContent = 'Review required (' + (counts.pending + check.missingRepresentatives.length) + ')';
    let shown = 0;
    board.querySelectorAll('.mt-tile').forEach(tile => {
      const project = tile.dataset.proj;
      const state = status(day, project);
      tile.classList.toggle('present', state === 'present');
      tile.classList.toggle('absent', state === 'absent');
      tile.querySelector('.mt-state').textContent = state[0].toUpperCase() + state.slice(1);
      tile.querySelectorAll('[data-status]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.status === state)));
      const savedRep = day.representatives?.[project];
      const repText = tile.querySelector('.mt-rep-summary');
      if (repText) {
        repText.textContent = repName(savedRep) || (hasRepresentative(day, project) ? 'Representative selected' : '');
        repText.hidden = !repText.textContent;
      }
      tile.classList.toggle('mt-needs-rep', state === 'present' && !hasRepresentative(day, project));
      const select = tile.querySelector('.mt-rep-select');
      if (select && savedRep && select.value === '') {
        const existingOption = [...select.options].find(option => option.value.split('|')[0] === repId(savedRep));
        if (existingOption) select.value = existingOption.value;
      }
      tile.hidden = !matches(tile.querySelector('h5').textContent, state, view.filter, view.query);
      if (!tile.hidden) shown++;
    });
    board.querySelectorAll('.mt-group').forEach(group => {
      group.hidden = ![...group.querySelectorAll('.mt-tile')].some(tile => !tile.hidden);
    });
    document.querySelectorAll('#mtFilterChips [data-f]').forEach(button => {
      const selected = button.dataset.f === view.filter;
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    byId('mtBarCount').textContent = shown + ' of ' + counts.total + ' projects shown';
    byId('mtEmptyFilter').hidden = shown !== 0;
    const missing = byId('mtPendingList');
    missing.replaceChildren();
    byId('mtPendingPanel').hidden = !view.review || (counts.pending === 0 && check.missingRepresentatives.length === 0);
    if (view.review) [...new Set([...counts.missing, ...check.missingRepresentatives])].forEach(project => {
      const button = document.createElement('button');
      button.type = 'button';
      // Use textContent, never interpolate project names into handlers/HTML.
      button.textContent = project;
      button.onclick = () => reach(project, check.missingRepresentatives.includes(project));
      missing.append(button);
    });
    // Patch the visible month's count without re-rendering the board/note drafts.
    const cell = document.querySelector('.mt-calendar-card .mt-day[data-meeting-day="' + current.iso + '"]');
    if (cell && !cell.classList.contains('off') && !cell.classList.contains('future')) {
      cell.classList.toggle('held', counts.present > 0);
      cell.classList.toggle('missed', counts.present === 0);
      const label = cell.querySelector('.mt-day-count');
      if (label) label.textContent = counts.present ? counts.present + ' ✓' : '✗';
      cell.title = current.iso + ' — ' + counts.present + ' present';
    }
    if (focusedTile?.hidden) {
      const next = [...board.querySelectorAll('.mt-tile')].find(tile => !tile.hidden);
      const target = next?.querySelector('[data-status="' + (focusedStatus === 'absent' ? 'absent' : 'present') + '"]')
        || byId('mtSearch');
      target.focus({preventScroll: true});
    }
  }
  function reach(project, needsRepresentative = false) {
    if (!current) return;
    current.view.review = false;
    current.view.query = '';
    current.view.filter = needsRepresentative ? 'all' : 'pending';
    byId('mtSearch').value = '';
    refresh();
    const tile = [...current.board.querySelectorAll('.mt-tile')].find(el => el.dataset.proj === project);
    if (tile) {
      tile.scrollIntoView({block: 'center', behavior: 'instant'});
      if (needsRepresentative) requestRepresentative(current.iso, project);
      else tile.querySelector('[data-status="present"]').focus({preventScroll: true});
    }
  }
  function reviewPending() {
    if (!current) return;
    current.view.review = true;
    const check = validation(current.projects, current.day, current.historicalEdit,
      global.mtAttendanceEdits?.[current.iso]?.original);
    current.view.filter = check.missingRepresentatives.length ? 'all' : 'pending';
    current.view.query = '';
    byId('mtSearch').value = '';
    refresh();
    byId('mtPendingPanel').focus();
    byId('mtPendingPanel').scrollIntoView({block: 'center', behavior: 'instant'});
  }
  function reset() {
    if (!current) return;
    current.view.review = false;
    current.view.query = '';
    byId('mtSearch').value = '';
    setFilter('all');
  }
  function closeTile(tile) {
    if (!tile) return;
    tile.classList.remove('expanded');
    const control = tile.querySelector('.mt-details-toggle');
    if (control) control.setAttribute('aria-expanded', 'false');
    const body = tile.querySelector('.mt-tile-body');
    if (body) body.hidden = true;
    const hint = tile.querySelector('.mt-rep-hint');
    if (hint) hint.hidden = true;
  }
  function openTile(tile, selectRepresentative = false) {
    if (!tile || !current) return;
    current.board.querySelectorAll('.mt-tile.expanded').forEach(other => {
      if (other !== tile) closeTile(other);
    });
    tile.classList.add('expanded');
    const button = tile.querySelector('.mt-details-toggle');
    if (button) button.setAttribute('aria-expanded', 'true');
    const body = tile.querySelector('.mt-tile-body');
    if (body) body.hidden = false;
    const select = tile.querySelector('.mt-rep-select');
    if (selectRepresentative && select) {
      select.focus({preventScroll: true});
      if (typeof select.showPicker === 'function') {
        try {select.showPicker();} catch (_) { /* Manual selection remains available. */ }
      }
    }
  }
  function requestRepresentative(iso, project) {
    if (!current || current.iso !== iso) return false;
    const tile = [...current.board.querySelectorAll('.mt-tile')].find(row => row.dataset.proj === project);
    if (!tile) return false;
    pendingRepresentative = {iso, project};
    openTile(tile, true);
    const hint = tile.querySelector('.mt-rep-hint');
    if (hint) {
      hint.textContent = tile.querySelector('.mt-rep-select')?.options?.length > 1
        ? 'Choose a representative to confirm Present automatically.'
        : 'No eligible representative available; Present cannot be confirmed.';
      hint.hidden = false;
    }
    return true;
  }
  function representativeSaved(iso, project) {
    if (!current || current.iso !== iso) return;
    refresh();
    if (pendingRepresentative?.iso !== iso || pendingRepresentative.project !== project ||
        !hasRepresentative(current.day, project)) return;
    pendingRepresentative = null;
    if (typeof global.mtSetStatus === 'function') global.mtSetStatus(iso, project, 'present');
    const tile = [...current.board.querySelectorAll('.mt-tile')].find(row => row.dataset.proj === project);
    closeTile(tile);
  }
  function toggleDetails(button) {
    const tile = button.closest('.mt-tile');
    if (!tile || !current) return;
    if (tile.classList.contains('expanded')) {
      closeTile(tile);
      if (pendingRepresentative?.project === tile.dataset.proj) pendingRepresentative = null;
    } else {
      pendingRepresentative = null;
      openTile(tile, !hasRepresentative(current.day, tile.dataset.proj));
    }
  }
  // Capture immediately before DOM replacement, not when the tab is hidden.
  // This also preserves manual scrolling performed after returning to the app.
  function captureViewport(iso) {
    const page = byId('page-meeting');
    if (!current || current.iso !== iso || !current.board.isConnected || !page || page.getClientRects().length === 0) return null;
    const scrollers = [];
    for (let node = page; node; node = node.parentElement) {
      if (node.scrollHeight > node.clientHeight) scrollers.push({node, top:node.scrollTop, left:node.scrollLeft});
    }
    const tiles = [...current.board.querySelectorAll('.mt-tile')];
    const anchor = tiles.find(tile => !tile.hidden && tile.getBoundingClientRect().bottom > 0 && tile.getBoundingClientRect().top < global.innerHeight);
    return {iso, scrollers, x:global.scrollX, y:global.scrollY,
      project:anchor?.dataset.proj, top:anchor?.getBoundingClientRect().top,
      expanded:tiles.filter(tile=>tile.classList.contains('expanded')).map(tile=>tile.dataset.proj)};
  }
  function restoreViewport(snapshot) {
    if (!snapshot || !current || current.iso !== snapshot.iso) return;
    const tiles = [...current.board.querySelectorAll('.mt-tile')];
    tiles.filter(tile=>snapshot.expanded.includes(tile.dataset.proj)).forEach(tile=>{
      tile.classList.add('expanded');
      const body=tile.querySelector('.mt-tile-body'); if(body) body.hidden=false;
      tile.querySelector('.mt-details-toggle')?.setAttribute('aria-expanded','true');
    });
    snapshot.scrollers.forEach(({node,top,left})=>node.scrollTo({top,left,behavior:'instant'}));
    global.scrollTo({top:snapshot.y,left:snapshot.x,behavior:'instant'});
    const anchor=tiles.find(tile=>tile.dataset.proj===snapshot.project && !tile.hidden);
    if (!anchor) return;
    const delta=anchor.getBoundingClientRect().top-snapshot.top;
    // Prefer the nearest actual scrolling container; otherwise scroll the window.
    const inner=snapshot.scrollers.find(({node})=>node!==document.scrollingElement && node!==document.body);
    if(inner) inner.node.scrollTop+=delta;
    else global.scrollTo({top:global.scrollY+delta,left:snapshot.x,behavior:'instant'});
  }
  global.MeetingAttendanceUI = {captureViewport, restoreViewport, status, summarize, matches, validation, hasRepresentative, mount, refresh, setFilter, search, reviewPending, reset, requestRepresentative, representativeSaved, toggleDetails};
})(typeof window !== 'undefined' ? window : globalThis);
