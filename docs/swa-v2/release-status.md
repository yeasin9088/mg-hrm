# MG-HRM Smart Work Assistant V2 — foundation release status

## Safe scope

This release creates an additive, server-authoritative work ledger, independent audit events, explicit action RPCs with optimistic concurrency, a manager briefing session, a read-independent attention board and a narrow legacy To-Do adapter. The existing four To-Do tabs and V1 notification service remain intact.

Time handling explicitly distinguishes the true business deadline from manager communication (24 hours) and ordinary 09:00–18:00 Dhaka office execution. Weekly-off and holiday rules are **not** inferred.

## Rollout boundaries

- `swa_preferences.push_v2_enabled` defaults to **false**. This release does **not** switch off V1, claim to have replaced Web Push, send digest push, or suppress existing legacy reminders.
- New attention events are in-app-only. Existing `notifications`, `notification_jobs`, Web Push subscriptions and scheduling cron are not modified.
- The source adapter mirrors active `todos` via trigger into `swa_work_items`. It does **not** update `todos`, employees, transfers, leaves, salaries or disciplinary records.
- Source `terminal` is stored as a signal. Required follow-up steps are not auto-completed. Previously resolved To-Dos are not backfilled into the active list.
- New manual Quick Capture items reside in SWA and do not automatically appear as records inside the original four To-Do tabs. Work item category references these tabs for clarity.
- Import/adapters for Transfer, Leave, Recruitment, Uniform, Disciplinary and salary-specific source resolver remain backlog pending verified semantic mapping. A user can manually capture such follow-ups without triggering underlying business workflows.

## Verification gates

1. GitHub Action `swa-v2.yml` runs JS syntax and the synthetic three-clock test suite, then validates the production migration against a disposable PostgreSQL 16 database.
2. The SQL gate tests operator-only RLS, duplicate capture key, manager informed versus approved, decision not equal execution, completion blocking, audit events, conflict version and reopen.
3. Production must be compared with migration history, RLS and object inventory. Do not run migration if actual schema drift or operation conflicts appear.
4. After migration, monitor RPC error logs and work item counts, authenticate and inspect Android/desktop UIs, check manager night workflow, then verify GitHub Pages deploy status.
5. The synthetic suite does not replace an isolated restoration drill, 14–30-day low-noise pilot, actual push delivery tests or real-device accessibility verification.

## Rollback / containment

- For an SWA UI regression, revert the Pages commit to stop serving `swa-ui.js` and `swa-ui.css`; previous To-Do/notification workflows persist.
- `swa_preferences.push_v2_enabled=false` is the default and must remain false until the separate V2 notification engine is implemented and tested. Do not disable V1 cron on account of this migration.
- No existing business tables or rows need deletion for rollback. Retain `swa_work_items` and `swa_work_events` data for incident review. To stop new sync activity temporarily, disable only `swa_todo_sync` on `public.todos` via supervised change.
- This is **not** an all-rulebook-complete release; consult `requirements-traceability.md` for exact gaps.

## Required follow-up before calling SWA V2 complete

Implement persistent offline queue, robust source-state adapters for each verified module, separate requestor/admin step checklist, true digest scheduler, feature-flagged notification V2 dispatch with bounded rate controls, retry/dedupe/health diagnostics, editable preferences, production rollback rehearsal and real Android/Desktop walkthrough. Never claim complete until all 69 acceptance tests have evidence.
