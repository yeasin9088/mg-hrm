/* Meeting persistence is deliberately separate from generic cache autosync.
   The reviewed RPC is required: never fall back to destructive REST writes. */
(function (global) {
  'use strict';
  const clone = x => JSON.parse(JSON.stringify(x));
  const fields = ['project_name', 'status', 'remarks', 'employee_id', 'full_name', 'designation', 'sort_order'];
  const busy = new Set();
  const pending = new Map();
  function date(iso) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(iso) ||
        new Date(iso + 'T00:00:00Z').toISOString().slice(0, 10) !== iso) throw Error('Invalid meeting date');
    return iso;
  }
  async function readAll(client, table, iso, meetingId) {
    const rows = [];
    // Continue until an empty page, including when the server caps pages below 500.
    for (;;) {
      let query = client.from(table).select('*').is('deleted_at', null).order('id');
      if (iso) query = query.eq('meeting_date', date(iso));
      if (meetingId != null) query = query.eq('meeting_id', meetingId);
      // Keyset pagination avoids skipping rows when earlier records are soft-deleted.
      if (rows.length) query = query.gt('id', rows[rows.length - 1].id);
      const result = await query.range(0, 499);
      if (result.error) throw result.error;
      if (!Array.isArray(result.data)) throw Error('Incomplete meeting response');
      if (!result.data.length) return rows;
      if (rows.length && BigInt(result.data[0].id) <= BigInt(rows[rows.length - 1].id)) {
        throw Error('Meeting pagination did not advance');
      }
      rows.push(...result.data);
    }
  }
  function validate(iso, meetings, rows) {
    date(iso);
    if (meetings.length > 1) throw Error('Multiple meetings on this date require review; no data changed');
    const meeting = meetings[0] || null;
    if (meeting && (!meeting.meeting_id || meeting.meeting_date !== iso || meeting.deleted_at)) {
      throw Error('Invalid meeting/date identity; no data changed');
    }
    const projects = new Set();
    rows.forEach(row => {
      if (!meeting || row.meeting_id !== meeting.meeting_id || (row.meeting_date !== null && row.meeting_date !== iso) ||
          !row.project_name || projects.has(row.project_name) || row.deleted_at) {
        throw Error('Ambiguous meeting/project/date identity; no data changed');
      }
      projects.add(row.project_name);
    });
    return { meeting, rows };
  }
  function dateForRow(row, meetings) {
    if (row.meeting_date != null) return row.meeting_date;
    const parents = (meetings || []).filter(m => !m.deleted_at && m.meeting_id === row.meeting_id);
    return parents.length === 1 ? parents[0].meeting_date : '';
  }
  async function readDay(client, iso) {
    // Legacy rows may have a NULL denormalized date. The exact parent ID is the
    // authoritative relationship; never invent a parent or rewrite stored dates.
    const meetings = await readAll(client, 'meetings', iso);
    const snapshot = validate(iso, meetings, []);
    const [byDate, byMeeting] = await Promise.all([
      readAll(client, 'meeting_attendance', iso),
      snapshot.meeting ? readAll(client, 'meeting_attendance', null, snapshot.meeting.meeting_id) : []
    ]);
    const rows = [...new Map(byDate.concat(byMeeting).map(row => [String(row.id), row])).values()];
    // Explicit contradictory dates still fail; transaction rechecks every version.
    return validate(iso, meetings, rows);
  }
  function status(day, project) {
    if (day.present?.[project] && day.absent?.[project]) throw Error('Conflicting attendance status');
    return day.present?.[project] ? 'Present' : day.absent?.[project] ? 'Absent' : null;
  }
  function rowFor(day, project, employees) {
    let rep = day.representatives?.[project] || {};
    if (typeof rep !== 'object') {
      rep = (employees || []).find(e => String(e.id) === String(rep) || String(e.EmployeeID) === String(rep)) || {};
    }
    const st = status(day, project);
    const order = (day.presentOrder || []).indexOf(project);
    const notes = day.notes?.[project] || [];
    return {
      project_name: project, status: st,
      remarks: Array.isArray(notes) ? notes.join(' | ') : String(notes).trim(),
      employee_id: String(rep.employee_id || rep.EmployeeID || rep.id || '') || null,
      full_name: rep.FullName || rep.fullName || rep.name || null,
      designation: rep.Designation || rep.designation || null,
      sort_order: st === 'Present' && order >= 0 ? order : 999
    };
  }
  function plan(day, original, snapshot, projects, employees) {
    if (!original && snapshot.rows.length) throw Error('Existing attendance requires an edit snapshot');
    if (original) {
      for (const key of ['present', 'absent', 'representatives', 'notes']) {
        if (!day[key] || typeof day[key] !== 'object' || Array.isArray(day[key])) {
          throw Error('Incomplete attendance draft; reload before editing');
        }
      }
      for (const project of new Set([...Object.keys(original.present || {}), ...Object.keys(original.absent || {})])) {
        if (status(original, project) && !status(day, project) && !day.attendanceBlanks?.[project]) {
          throw Error('Missing saved attendance status; an explicit blank is required');
        }
      }
      for (const key of ['representatives', 'notes']) {
        for (const project of Object.keys(original[key] || {})) {
          if (!Object.prototype.hasOwnProperty.call(day[key], project)) {
            throw Error('Incomplete attendance ' + key + '; reload before editing');
          }
        }
      }
    }
    const result = new Map(snapshot.rows.map(row => [row.project_name, Object.fromEntries(fields.map(k => [k, row[k] ?? null]))]));
    const keys = new Set([...projects, ...result.keys(), ...Object.keys(day.present || {}),
      ...Object.keys(day.absent || {}), ...Object.keys(day.representatives || {}), ...Object.keys(day.notes || {})]);
    for (const project of keys) {
      const current = rowFor(day, project, employees);
      if (!original) result.set(project, current);
      else {
        const before = rowFor(original, project, employees);
        const changed = fields.filter(k => k !== 'project_name' && current[k] !== before[k]);
        if (changed.length) {
          const row = result.get(project) || before;
          changed.forEach(k => { row[k] = current[k]; });
          result.set(project, row);
        }
      }
    }
    return [...result.values()];
  }
  function matches(actual, desired) {
    return actual.length === desired.length && desired.every(want => {
      const found = actual.find(row => row.project_name === want.project_name);
      return found && fields.every(k => (found[k] ?? null) === (want[k] ?? null));
    });
  }
  function validatePayload(rows, metadata) {
    if (!Array.isArray(rows) || !metadata ||
        !['agenda', 'started_at', 'ended_at'].every(k => Object.prototype.hasOwnProperty.call(metadata, k))) {
      throw Error('Incomplete attendance payload');
    }
    for (const row of rows) {
      if (!row || !fields.every(k => Object.prototype.hasOwnProperty.call(row, k)) ||
          Object.keys(row).some(k => !fields.includes(k)) ||
          typeof row.project_name !== 'string' || !row.project_name.trim() ||
          ![null, '', 'Present', 'Absent'].includes(row.status) ||
          ['remarks', 'employee_id', 'full_name', 'designation'].some(k => row[k] !== null && typeof row[k] !== 'string') ||
          (row.sort_order !== null && (!Number.isInteger(row.sort_order) || row.sort_order < -2147483648 || row.sort_order > 2147483647))) {
        throw Error('Incomplete or invalid attendance row');
      }
    }
    if (new Set(rows.map(r => r.project_name)).size !== rows.length) throw Error('Duplicate attendance project');
    if (metadata.agenda !== null && typeof metadata.agenda !== 'string') throw Error('Invalid meeting agenda');
    for (const k of ['started_at', 'ended_at']) {
      if (metadata[k] !== null && (typeof metadata[k] !== 'string' || !Number.isFinite(Date.parse(metadata[k])))) {
        throw Error('Invalid meeting time');
      }
    }
  }
  function metadataMatches(meeting, metadata) {
    return meeting.agenda === metadata.agenda &&
      ['started_at', 'ended_at'].every(k => metadata[k] === null
        ? meeting[k] === null
        : Date.parse(meeting[k]) === Date.parse(metadata[k]));
  }
  async function save(client, iso, snapshot, rows, metadata) {
    date(iso);
    validatePayload(rows, metadata);
    if (busy.has(iso)) throw Error('Meeting save already in progress');
    busy.add(iso);
    try {
      const signature = JSON.stringify({snapshot, rows, metadata});
      let request = pending.get(iso);
      if (request && request.signature !== signature) {
        throw Error('Previous save outcome is uncertain. Retry the unchanged draft or reload before editing');
      }
      if (!request) {
        request = {signature, args: {
          p_date: iso, p_expected: clone(snapshot), p_rows: clone(rows), p_metadata: clone(metadata),
          p_request_id: global.crypto.randomUUID()
        }};
        pending.set(iso, request);
      }
      const result = await client.rpc('mghrm_save_meeting_attendance', request.args);
      if (result.error) {
        // An explicit PostgreSQL error rolls back the transaction. Transport failures
        // retain the request token so a committed but lost response can be retried.
        if (/^(22|23|40|42|P0)/.test(result.error.code || '') || result.error.code === 'PGRST202') pending.delete(iso);
        throw Error('Attendance save not confirmed: ' + result.error.message);
      }
      const saved = result.data;
      if (!saved || !saved.meeting || !Array.isArray(saved.rows)) throw Error('Save response incomplete; retry unchanged draft');
      validate(iso, [saved.meeting], saved.rows);
      if (!matches(saved.rows, rows)) throw Error('Persisted attendance verification failed; reload required');
      if (saved.meeting.id == null || !saved.meeting.submitted_at ||
          saved.meeting.attendance_request_id !== request.args.p_request_id || !metadataMatches(saved.meeting, metadata)) {
        throw Error('Persisted meeting verification failed; retry unchanged draft or reload');
      }
      pending.delete(iso);
      return saved;
    } finally {
      busy.delete(iso);
    }
  }
  global.MeetingAttendanceStore = {readAll, readDay, dateForRow, validate, plan, matches, save, status, busy};
})(typeof window !== 'undefined' ? window : globalThis);
