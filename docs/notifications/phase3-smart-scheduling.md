# MG-HRM Notification V2 — Phase 3 Smart Scheduler and Digest

**Owner-approved timing:** `Asia/Dhaka`; routine Push eligibility 09:00–18:00;
Morning Digest 09:05, Wrap-up Digest 17:15.
**Status:** Implemented and tested in isolated PostgreSQL, *not connected to live Push*.
**Production migration:** explicitly DEFERRED until the consolidated release gate.
**V2 activation:** `notification_private.governance_control.enabled=false`.

## What exists
- `notification_private.digest_plan(recipient,day,kind,at)` — stable,
  privacy-safe, READ-ONLY source-derived digest. Reads actual open To-Do
  records with owner/assigned recipient validation; never uses inbox Read as
  business completion. Unknown official holidays are clearly flagged.
- `notification_private.digest_latest_due(at)` — resolves the most
  recent due slot across Bangladesh-local 09:05/17:15 and midnight.
- `public.notification_digest_prepare_slot(recipient,day,kind,at)` —
  service-only durable batch creation; one batch per recipient/day/slot.
  A replay serializes through a unique key, adds newly eligible work, marks
  completed/reassigned records *inactive* without deleting their history.
- `public.notification_digest_reconcile(recipient,at)` — service-only
  missed-tick catchup. Builds only the latest due slot, never replays every
  missed push slot; actionable backlog persists from authoritative To-Dos.
- `public.notification_digest_preview(day,kind)` — authenticated
  operator-only preview for future integration into the **existing**
  Notification Center. No second inbox or Smart Work UI.
- `notification_private.digest_batches` and `digest_items` — private
  RLS-protected, recipient-scoped, auditable scheduling snapshots. Contain
  source IDs and material state fingerprints, **no note or salary text**.
  They are not new business-task records, delivery receipts or provider jobs.

## Digest grouping semantics
- `OVERDUE`: **verified** actual deadline <= instant of evaluation.
- `DUE_TODAY`: verified deadline falls on local digest date (morning).
- `BEFORE_NEXT_OPEN_RISK`: verified event before the next 09:00
  clock candidate during wrap-up. This is *not* an official workday claim.
- `BRIEF_MANAGER`: existing To-Do category `permission` without
  separately verified previously informed state.
- `WAITING_FOLLOWUP`: `permission` with known `asked` /
  `informed` / `waiting` status; must not re-label as uninformed.
- `ACT_TODAY`: other actionable To-Do source rows.
- `captured_overnight`: captured since previous local 18:00 and
  before the 09:05 morning digest. Read/clear doesn't change inclusion.

**Known limitation:** category labels are conservative mappings for
existing To-Dos, not a complete Manager/Salary/Leave/Recruitment adapter.
Only verified deadlines linked to the current exact source material version
are used. `todos.date` or `remind_on` cannot manufacture a due timestamp.

## Scheduling, recovery and deduplication invariants
- Slot identities: `(recipient_user_id,local_day,digest_kind)`; unique DB
  constraint, UPSERT in one transaction, stable `batch_id` on retry.
- Local office clock is **separate** from event deadline and Manager
  communication time. UTC timestamps are retained; rendering uses
  `AT TIME ZONE 'Asia/Dhaka'`.
- If cron is late, reconcile once against current work truth in the
  most recent due slot; no 20-push storm or backfill of dozens of old
  Push requests. Very old explicit slot replays (>48 hours) are rejected.
- At 08:59 the previous 17:15 remains the latest due slot; at 09:05 a
  new morning slot is due.
- Failing to deliver a digest cannot erase To-Dos; the next slot is
  built from live actionable source state, independently of prior batch.
- Snapshot of a completed/reassigned item is marked `is_current=false`
  on replay; source work remains the sole authority. **A dispatcher added
  later must revalidate source/version/permissions/preferences immediately
  before Push; never treat a stored snapshot as send authorization.**
- P0/P1 emergency exceptions, verified working-day calendar, official
  holidays, payroll cutoff and statutory SLAs are **not invented**.

## Integration boundary / what Phase 3 does NOT do
- Does NOT create `notification_events`, `notification_jobs` or
  `notification_deliveries`, trigger the Web Push Edge Function, alter
  Service Worker, register a cron or change existing Notification Center.
- Does NOT promise the 09:05/17:15 group is already delivered via Push.
  These durable slot constructors are an internal preparation stage.
- Phase 4 must choose a single digest delivery path, implement provider
  acceptance/retry/health state, trigger the builder from existing server
  scheduler, enforce all caps atomically and revalidate before final send.
- Phase 5 must run Android/Windows and full Rulebook acceptance.
- Rulebook BR-125–134, BR-366–385 and AT-054–060, AT-068–069 are **partially
  covered** by synthetic source/timing tests; none is represented as fully
  end-to-end accepted by these fixtures.

## Tests
`.github/workflows/notification-core-phase3.yml` replays Phase 1, Phase 2
and Phase 3 in **disposable PostgreSQL 16**, using
`scripts/notification-phase3-ci-fixtures.sql` and
`scripts/notification-phase3-ci-assertions.sql`.
Test: 20 overnight work items become one slot, exact local schedule and
midnight rollover, Read is independent, completed/reassigned source removal,
source reopen, manager-informed semantics, 08:00 verified joining deadline
at 17:15 wrap-up, real overdue at next 09:05, missed-cron catchup,
replay idempotency, privacy and access control.

## Ordered release
See [release-manifest-v2.md](./release-manifest-v2.md).
This migration is additive and must follow the existing, already-applied
`notification_core_decision_contract` and `notification_core_policy_phase2`.
**Do not apply it or enable any scheduled sender as a shortcut to full V2.**
