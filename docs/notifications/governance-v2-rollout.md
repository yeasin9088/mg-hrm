# Notification Governance V2 — integration checkpoint (23 October 2026)

## Corrected product direction

The user clarified that MG-HRM requires **existing notifications** to follow the attached
Rulebook v1.1; a new standalone Smart Work screen was not requested.
The index, offline shell and GitHub Pages asset manifest therefore no longer load the
standalone SWA UI. The legacy To-Do, Follow-Up, Notifications, settings, delivery
subscriptions and existing manager interactions remain untouched.
The additive SWA database ledger/audit and its 8 mirrored records are **preserved**;
dropping those tables would destroy historical metadata and is not required.

## Rulebook-backed changes now represented in code

- BR-003/BR-032/BR-115–119/BR-371: **preview-only** To-Do decision uses source
  actionability and elapsed alert time; it never treats Read, Mark All Read, Dismiss,
  or phone tray clearing as task completion or re-alert permission.
- BR-031/BR-100: terminal To-Do is not eligible.
- BR-120/BR-122: explicit snooze from notification inbox and acknowledged lease
  from a mirrored source work item can delay a candidate, without completing source.
- BR-125/BR-126/BR-366/BR-368: optional **proposed** Dhaka 09:00–18:00
  notification delivery window; after-hours candidate is deferred and reasoned.
  This is *not* an official workday/holiday calendar and does not move an actual deadline.
- BR-095/BR-116–118/BR-132: **proposed** 24-hour and 4-hour cooldown defaults,
  rolling 24h maximum 1 routine / 2 important alerts per To-Do thread.
- BR-124/BR-300: authorized `notification_governance_preview(todo_id)` reports
  machine-readable policy reason, next eligible time, source risk, and what V1
  would do. This is diagnostic, not a delivery guarantee.
- Distinguishes genuine `swa_work_items.deadline_at` / `promised_at` timestamps
  from legacy `todos.remind_on`, which is a *reminder request*, not a legal or
  organizational business deadline.
- Push payloads remain generic for privacy; no business automation writes
  employee, transfer, leave, payroll, discipline, or external messaging records.

## Activation and parity

Production gate: `notification_private.governance_control.enabled=false`.
The prior `notification_private.todo_followup_allowed` algorithm has been preserved
verbatim as `todo_followup_v1_allowed`, and remains the sole live algorithm
while the feature is disabled. SQL migration does not alter existing
`notifications`, `notification_events`, `notification_jobs`, existing
To-Do reminder data, device subscriptions, current cron, or Push sender.

**Do not enable this flag yet.** The existing
`notification_private.prevent_unseen_repeat` guard, Web Push source-at-dispatch
checks, and all other event producers must also be migrated under a controlled
feature flag. The preview logic alone would not achieve complete V2 recurrence.
The CI checks run in an isolated synthetic PostgreSQL 16 instance.

## Still missing — cannot claim Rulebook complete

- Aggregated 09:05 morning and 17:15 wrap-up digests (proposed defaults),
  pending overnight reconciliation, multi-item grouped Web Push and global burst cap.
- Durable cross-module source resolvers, explicit business deadlines, manager
  approved vs informed/communicated/executed mapping for existing To-Do records.
- Source material-event version keys, stale queued event cancellation and
  final pre-push transactional revalidation across all producers.
- Audit of all suppression/defer decisions, dead-letter and health reporting,
  improved per-user notification settings, opt-in emergency exception.
- Offline and multi-device edge cases, 14–30 day pilot and 69 acceptance tests.
- User decision on proposed reminder intervals/digests and official holiday calendar.

## Safe rollback

Revert deployed UI commit if a presentation issue appears; backend ledger stays
preserved. With governance flag off, SQL migration is a non-active extension to V1.
Before any future activation: test trigger parity and push-inbox pairing in staging,
define reversible policy switch, measure notification counts and capture a rollback
point. Do not delete user notifications or reinitialize subscriptions.
