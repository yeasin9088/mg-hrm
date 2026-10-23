# Notification governance release gate — 23 October 2026

## Decision: release verified fixes; do not activate V2

The owner authorized implementation and a safe production release and selected
the pilot Push window (09:00–18:00 Asia/Dhaka), digest times (09:05/17:15),
and rolling per-item caps (routine 1, important 2 in 24 hours). The selections
are recorded in `owner-policy-decisions-2026-10-23.md`.

The authorized release must still satisfy the Rulebook's technical gates. A
complete V2 notification engine has **not** been implemented or verified.
Production remains on V1 with `notification_private.governance_control.enabled=false`.

## Evidence collected

- Current `main` inspected at `a98b857e7a03e1e922218382fc1f5c60c0201a3d`.
- Complete inventory: 385 BR IDs and 69 AT IDs indexed exactly once.
- 166 repository tests run locally: 165 passed, 1 skipped, 0 failed. These are
  existing regression tests plus focused synthetic SQL/UI checks, **not** 69
  passing Rulebook acceptance tests.
- Isolated PGlite tests compiled the unapplied Salary Note privacy migration
  and V2 To-Do repeat-trigger migration; verified V1 rollback behavior,
  V2 read-independent gated repeat, source-root terminal suppression, generic
  Salary Note preview, ordinary preview and opt-out.
- To-Do status/manager UI writes now require a confirmed server row before
  reporting success. Failure and concurrent same-device tap tests passed.
- Production read-only inspection: 122 To-Dos; 8 SWA historical rows preserved;
  2 active Push subscriptions; four active notification-related cron jobs;
  zero open notification jobs/events at the inspection time.

## Failing / unproven gates

1. All 69 Rulebook ATs still lack complete isolated setup, actual result and
   evidence; the matrix marks them Blocked. Existing tests cover narrower paths.
2. Cross-module source obligation mapping, P1 deadline handling, manager
   informed/approved/communicated/executed separation, status audit and
   multi-device optimistic conflict protection remain incomplete.
3. Approved digest times are recorded but no server-authoritative grouped
   digest/backlog reconciling pipeline exists. An overnight burst is not ruled out.
4. Final dispatch cannot yet revalidate every module's source version and
   business deadline. The V2 repeat gate covers only To-Do reminders.
5. Hosted staging is unavailable: the only existing branch reports
   `MIGRATIONS_FAILED`; creation of a fresh Supabase development branch returned
   `PaymentRequiredException` (Pro plan required). Local synthetic PostgreSQL
   checks do not replace a hosted end-to-end and Android/desktop smoke test.
6. GitHub API upload is available; hosted CI and merge results must be verified
   on the exact uploaded commit. Full V2 remains incomplete regardless of CI success.

## Non-destructive recovery path

Keep the control flag false. The prepared migrations are additive and should
be applied only after a complete staged compatibility run. If a later pilot
fails, first set `enabled=false` in a controlled migration and verify V1
producer, cron, inbox and Push continue; preserve events, notifications,
subscriptions, ledger rows and their history. Do not reset reminders or alter
employee transfers as a rollback shortcut.

## Production change during follow-up execution

The owner explicitly authorized migrations, push and merge. Applied
`salary_todo_push_privacy` successfully on production. Read-back verified the
source salary guard is present and anon/authenticated cannot execute the RPC.
The governance control remains disabled. This privacy correction is independently
compatible with V1 and does not activate the incomplete engine. The repeat-gate
migration remains unapplied. Repository regression rerun: 166 tests, 165 pass,
1 skip, 0 fail. GitHub blob SHA checks matched local index and traceability files.

This report is an honest partial release record, not a claim that all requested
rules, 69 acceptance scenarios, or device delivery paths are implemented.
