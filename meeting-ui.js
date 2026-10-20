/* Meeting board presentation only. Persistence and RPC contracts live elsewhere. */
(function (global) {
  'use strict';
  const filters = ['all', 'pending', 'present', 'absent'];
  const views = new Map();
  let current = null;
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
  function validation(projects, day, historicalEdit) {
    const missing = historicalEdit ? [] : summarize(projects, day).missing;
    return {allowed: missing.length === 0, missing};
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
    byId('mtDraftHelp').textContent = historicalEdit
      ? 'Update changes when ready. Existing historical blanks can remain blank.'
      : 'Changes are not submitted yet. Mark every required project, then submit.';
    const submit = byId('mtSubmitDayBtn');
    if (submit && !historicalEdit) {
      submit.disabled = counts.pending > 0 || !!global.mtAttendanceSaving;
      submit.title = counts.pending ? 'Mark all pending projects before submitting' : 'Submit complete attendance';
    }
    const review = byId('mtReviewPending');
    review.hidden = counts.pending === 0;
    review.textContent = 'Review pending (' + counts.pending + ')';
    let shown = 0;
    board.querySelectorAll('.mt-tile').forEach(tile => {
      const project = tile.dataset.proj;
      const state = status(day, project);
      tile.classList.toggle('present', state === 'present');
      tile.classList.toggle('absent', state === 'absent');
      tile.querySelector('.mt-state').textContent = state[0].toUpperCase() + state.slice(1);
      tile.querySelectorAll('[data-status]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.status === state)));
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
    byId('mtPendingPanel').hidden = !view.review || counts.pending === 0;
    if (view.review) counts.missing.forEach(project => {
      const button = document.createElement('button');
      button.type = 'button';
      // Use textContent, never interpolate project names into handlers/HTML.
      button.textContent = project;
      button.onclick = () => reach(project);
      missing.append(button);
    });
    if (focusedTile?.hidden) {
      const next = [...board.querySelectorAll('.mt-tile')].find(tile => !tile.hidden);
      const target = next?.querySelector('[data-status="' + (focusedStatus === 'absent' ? 'absent' : 'present') + '"]')
        || byId('mtSearch');
      target.focus({preventScroll: true});
    }
  }
  function reach(project) {
    if (!current) return;
    current.view.review = false;
    current.view.query = '';
    current.view.filter = 'pending';
    byId('mtSearch').value = '';
    refresh();
    const tile = [...current.board.querySelectorAll('.mt-tile')].find(el => el.dataset.proj === project);
    if (tile) {
      tile.scrollIntoView({block: 'center', behavior: 'instant'});
      tile.querySelector('[data-status="present"]').focus({preventScroll: true});
    }
  }
  function reviewPending() {
    if (!current) return;
    current.view.review = true;
    current.view.filter = 'pending';
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
  function toggleDetails(button) {
    const tile = button.closest('.mt-tile');
    const open = tile.classList.toggle('expanded');
    button.setAttribute('aria-expanded', String(open));
    tile.querySelector('.mt-tile-body').hidden = !open;
  }
  global.MeetingAttendanceUI = {status, summarize, matches, validation, mount, refresh, setFilter, search, reviewPending, reset, toggleDetails};
})(typeof window !== 'undefined' ? window : globalThis);
