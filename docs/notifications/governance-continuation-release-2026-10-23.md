# Notification Governance V2 — verified continuation release checkpoint
Date: 23 October 2026 (Asia/Dhaka)

## Product boundary
The existing MG-HRM Notification Center, four To-Do/Follow-Up categories,
server processing and Web Push sender are the only intended notification
surfaces. Do not create a standalone Smart Work UI.

Rulebook v1.1 has 385 BR requirements and 69 acceptance scenarios. The indexed
traceability baseline is not an implementation completion report.
**The full Rulebook is not implemented. Governance V2 is OFF.**

## Verified repository/database state
- Prior PR #18 baseline: `68ef12a35d368d9cc41b16456c449693b485b89a`.
- Safety fix PR #19: https://github.com/yeasin9088/mg-hrm/pull/19
- Merged commit: `a4811323c24304891290fd9cd8387683168fd53e`.
- CI `Notification governance V2 compatibility`: pass, run `39901069761`.
- GitHub Pages deploy: success, run `39901179396`.
- Production apply_migration success: `governance_todo_repeat_gate`, unapplied in prior release.
- Production apply_migration success: `push_final_source_guard`.
- SQL read-back confirmed both new function definitions installed.
- 122 original To-Dos, 8 historical SWA ledger rows, 2 active Push subscriptions,
  117 notification rows, 4 notification/transfer cron jobs, 0 open notification
  jobs, 0 pending/failed notification events and 0 open deliveries at inspection.
- Governance feature flag remains `false`, policy version unchanged
  `notification-governance-v2-preview-1`.
- `anon` and ordinary `authenticated` cannot call private source guard or
  Web Push dispatch; `service_role` retains dispatcher execute permission.
- No existing employee, salary, leave, transfer, To-Do status, Notification,
  Push subscription or SWA historical record was modified for these tests.

## Exact behavior shipped
1. `notification_private.prevent_unseen_repeat` can consult V2 only if the
   feature flag is enabled. The flag is OFF, so production retains the V1
   read-aware repeat rule.
2. `notification_private.push_source_ineligible` blocks a stale *To-Do* Web
   Push if the original item was completed, cancelled/deleted, or re-assigned
   away from the notification recipient, even if queued earlier.
3. For supported source resolver types (transfer, exit, leave, selected uniform
   supply/delivery records), the dispatch guard also suppresses terminal or
   missing sources. Unsupported source types preserve their existing V1
   behavior until verified source adapters are implemented.
4. At final dispatch the existing worker calls the same dispatch RPC before
   each network send. The SQL delivery rows become `Skipped` when ineligible
   and include a machine-readable `gate_reason` in response_metadata.
5. The flow preserves privacy controls, device subscription checks, normal
   preference handling and the existing service worker.
6. Synthetic PostgreSQL tests prove owner change after job creation prevents
   the old recipient from receiving that job. They also cover terminal/missing
   known-source outcomes and operator/service grants.

**Boundary:** This is last-mile source and recipient hardening. It does NOT yet
provide full source-version comparisons, all module adapters, global digest,
true P0/P1/P2/P3 scheduling, operator ACK leases, approved Push delivery caps
or full message-level policy audit.

## Confirmed operator pilot settings (approved, NOT live as V2)
- Routine office-work Push eligibility: 09:00–18:00 Asia/Dhaka.
- Morning/afternoon digest: 09:05 / 17:15 Asia/Dhaka.
- P3 rolling per-item Push cap: 1/24h.
- P2 rolling per-item Push cap: 2/24h.
- P1 requires tested real deadline/risk evaluation.
- P0 requires a verified emergency procedure and cannot be invented.
- Weekly/company holidays, payroll cutoff and emergency policy remain unverified.

These are documented in `owner-policy-decisions-2026-10-23.md`; do not claim
current V1 delivery is already honoring the complete future policy.

## Acceptance evidence and real gaps
- Synthetic source guard is narrow support for BR-100 and AT-016 (work completed
  between queue and dispatch); it is NOT complete cross-module AT-016.
- The legacy V1-read-aware regression and V2 trigger parity test ran in PGlite.
- None of the 69 Rulebook ATs should be described as fully production accepted
  on these results alone; no authenticated Android and desktop real Push test
  was executed in this continuation.
- Still required: canonical decisions, complete verified HRM source truth,
  source material-version keys, P1/P0 thresholds, action/ACK semantics,
  09:05/17:15 grouped digest with cron catch-up, cap persisted by actual sends,
  multi-device optimistic editing, replay/recovery, full 69-test matrix,
  security review, and real-device smoke tests.

## Rollback — break-glass, not routine
Two reviewed SQL files are committed for supervised recovery:
1. `supabase/rollout/governance-repeat-gate-rollback.sql` — resets the
   governance flag to false and restores the V1 repeat trigger body.
2. `supabase/rollout/push-final-source-guard-rollback.sql` — restores the
   dispatch RPC body that preceded PR #19.

**Warning:** rolling back the Push guard restores a known ownership gap for
reassigned To-Do reminders. Prefer a corrective hotfix over this rollback if
possible. Never run either SQL against production merely to test it.

Before rollback: capture current function definitions, counts, cron state,
last successful sender tick and migration history; do not copy sensitive rows.
After rollback: recheck grants, UI, subscriptions, job pipeline and alert
health, with flag confirmed OFF. Never TRUNCATE notification tables, erase
history, or remove historical SWA ledger records.

Rollback tests run only against synthetic PostgreSQL and must be confirmed
green in the PR before relying on these scripts.

## Next operational gate
Complete and prove unified source, policy, grouping, and dispatch paths first.
Keep Governance V2 disabled until each required rule, 69 AT outcomes, browser
and device result, and recovery procedure have recorded evidence.
