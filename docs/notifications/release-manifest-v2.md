# MG-HRM Intelligent Notification V2 — Ordered Release Manifest

**Owner's instruction (23 Oct 2026):** Save each core phase, migrations, tests,
audit and deployment/rollback documentation together so the FINAL integration
migration is a deliberate ordered operation. No new standalone Smart Work UI.

## Authoritative baseline, confirm live before final rollout
Repo: `yeasin9088/mg-hrm` / main.
Supabase: `enkggoozsvvkgbjeghbf`.
Production: https://yeasinh.me/mg-hrm/

| Phase | Migration | Baseline status | Feature enabled? |
|---|---|---|---|
| 1 — Decision contract | `supabase/migrations/20261023180000_notification_core_decision_contract.sql` | Already applied to production as `20261023052759 notification_core_decision_contract` | Read-only preview |
| 2 — Priority, risk, quotas | `supabase/migrations/20261023190000_notification_core_policy_phase2.sql` | Already applied to production as `20261023054338 notification_core_policy_phase2` | Read-only preview |
| 3 — Digest scheduling | `supabase/migrations/20261023200000_notification_digest_scheduler_phase3.sql` | **APPLIED** production `20261023071238`; feature inactive | NO live cron or Push |
| 4 — Gated digest event/push integration (partial) | `20261023210000_notification_digest_event_bridge_phase4.sql` → `20261023213000_notification_processor_bridge_phase4.sql` → `20261023214500_notification_digest_event_guard_phase4.sql` | **APPLIED** production `20261023071309` → `20261023071348` → `20261023071403` | Both switches OFF |
| 5 — Backend settings API + acceptance evidence | `20261023220000_notification_operator_settings_api_phase5.sql` → `20261023221000_notification_digest_settings_enforcement_phase5.sql` | **APPLIED** production `20261023071437` → `20261023071450`; no V2 activation | OFF |
| 6 — FINAL UI/UX + migration + go-live | Existing responsive Settings Center + `20261023230000_notification_configurable_digest_window_phase6.sql` | UI PR #26 merged; phase6 clock migration applied `20261023073032`; real-device activation **BLOCKED** | OFF |

**Important:** GitHub migration filename and the Supabase applied migration
version may have different prefixes. Check the live migration table by
**logical migration name** and SQL compatibility. Do not apply Phase 1/2 twice
or infer from timestamps alone.

## Phase inventory: code/test/doc kept together

### Phase 1
- Migration: `20261023180000_notification_core_decision_contract.sql`
- Fixtures/assertions: `scripts/notification-core-ci-fixtures.sql`,
  `scripts/notification-core-ci-assertions.sql`
- Workflow: `.github/workflows/notification-core-phase1.yml`
- Docs: `docs/notifications/core-decision-engine-phase1.md`

### Phase 2
- Migration: `20261023190000_notification_core_policy_phase2.sql`
- Fixtures/assertions: `scripts/notification-core-phase2-fixtures.sql`,
  `scripts/notification-core-phase2-assertions.sql`
- Workflow: `.github/workflows/notification-core-phase2.yml`
- Docs: `docs/notifications/core-policy-phase2.md`

### Phase 3
- Migration: `20261023200000_notification_digest_scheduler_phase3.sql`
- Fixtures/assertions: `scripts/notification-phase3-ci-fixtures.sql`,
  `scripts/notification-phase3-ci-assertions.sql`
- Workflow: `.github/workflows/notification-core-phase3.yml`
- Docs: `docs/notifications/phase3-smart-scheduling.md`
- Preflight SQL: `scripts/notification-phase3-release-preflight.sql`
- Postflight SQL: `scripts/notification-phase3-release-postflight.sql`
- Containment: `supabase/rollout/notification-phase3-containment.sql`

### Phase 4 (gated existing-pipeline bridge, NOT live)
- SQL: `supabase/migrations/20261023210000_notification_digest_event_bridge_phase4.sql`
- SQL: `supabase/migrations/20261023213000_notification_processor_bridge_phase4.sql`
- SQL: `supabase/migrations/20261023214500_notification_digest_event_guard_phase4.sql`
- Synthetic DB: `scripts/notification-phase4-ci-fixtures.sql`
  and `scripts/notification-phase4-ci-assertions.sql`
- Device privacy: `tests/notification-phase4-push.test.mjs`
- Workflow: `.github/workflows/notification-core-phase4.yml`
- Docs: `docs/notifications/phase4-pipeline-bridge.md`
- Preflight: `scripts/notification-phase4-release-preflight.sql`
- Postflight: `scripts/notification-phase4-release-postflight.sql`
- Containment (break glass only): `supabase/rollout/notification-phase4-containment.sql`
- Separate default-off switch: `notification_private.digest_bridge_control.enabled=false`
- **Not full Phase4 completion:** all-module adapters, atomic Push reservations,
  supplier/provider delivery E2E and final policy acceptance are still missing.
- Phase3 and Phase4 SQL were applied in approved order to production on 23 Oct 2026;
  **do not replay them**. Both feature switches remain OFF.

### Phase 5 — Existing Settings API and per-slot enforcement (installed; V2 not active)
- Migration 1: `supabase/migrations/20261023220000_notification_operator_settings_api_phase5.sql`
- Migration 2: `supabase/migrations/20261023221000_notification_digest_settings_enforcement_phase5.sql`
- Synthetic isolated tests: `scripts/notification-settings-phase5-assertions.sql`,
  `scripts/notification-digest-switch-phase5-assertions.sql`
- CI: `.github/workflows/notification-settings-phase5.yml`
- Operator policy read/save: `public.notification_operator_policy_read()` and
  `public.notification_operator_policy_save(expected_revision,changes)`.
- Whitelist, operator-only, DB-based read-after-write, optimistic CAS revision.
  The API CANNOT enable P0, P1 interrupts or the Governance feature flags.
- Morning/afternoon settings are enforced in the staged digest event publisher
  and the final dispatch source gate. Still no live UI controls before Phase 6.
- Phase 5 rulebook acceptance matrix: `phase5-acceptance-evidence.md`.
- **No claims of real Android/desktop/provider Push or all 69 AT accepted**.
- Both Phase5 SQL files were applied; do not replay them.

### Phase 6 — FINAL operator Settings Center and release (IN PROGRESS; V2 NOT LIVE)
- Phase6 UI/UX merged in PR #26, commit `72504323c0754d84f805ee58c861b6516190ab5f`.
- Phase6 responsive Chromium testing + release gate in PR #27, merge
  commit `882da5f6b39788091b4f9337003ac8073eda9fec`.
- Dynamic clock guard applied to production:
  `20261023073032 notification_configurable_digest_window_phase6`.
- Production readiness report: `docs/notifications/phase6-release-evidence-2026-10-23.md`.
- Machine-readiness probe: `node scripts/notification-phase6-release-gate.mjs --assert-ready`.
- Mandatory design and acceptance contract:
  `docs/notifications/phase6-final-settings-center-ux-contract.md`.
- Upgrade the EXISTING Notification Settings panel, never create a second UI.
- All real engine controls must be responsive, accessible and backed by
  operator-authorized APIs with data-confirmed save/reload/conflict behavior.
- Fix misleading legacy "Urgent always bypass" UI wording/default relative to
  unapproved P0/P1 policy; do not accidentally activate night interruption.
- Final ordered migration Phase3→Phase4A→4B→4C→Phase5A→5B only after
  required acceptance checks. Keep both gates OFF during migration.
- Then verify exact delivery/rate quotas, protected source truth, actual browser
  and Android Push, all 69 individual AT results, rollback and operator sign-off.
- **There is no Phase 7**. If criteria remain unverified, report NOT READY
  within Phase 6 rather than invent another phase or falsely claiming Live.

## Live implementation status confirmed 23 October 2026
- **Already applied** in production: Phase3, Phase4 A/B/C, Phase5 A/B and Phase6
  configurable digest push window. Database migration names/versions listed
  above. Never replay a migration solely because its filename differs from
  applied timestamp.
- Existing V1 Notifications are the **only live sender**; Governance V2 and
  digest bridge are `false`. Both source records and Push history preserved.
- Private operator Settings RPC is installed; effective engine flags are OFF.
- Browser UI merged; latest Pages deployment must be separately checked.
- 69 ATs end-to-end **not accepted**; atomic concurrent Push cap and all HRM
  authoritative source adapters are not proven.
- No release gate may change both flags until remaining evidence truly passes;
  no Phase 7 is planned. Everything outstanding remains Phase6 work.

## Full release gates (DO NOT SKIP)
1. Read full Rulebook v1.1 and Project Context; re-audit latest `main`,
   migration history, live schema and source statuses.
2. Capture safe pre-change metrics and function definitions (never credentials).
3. Dedicated disposable PostgreSQL CI must apply Phase 1 → 2 → 3 in order
   and pass the corresponding isolated tests. No synthetic tests on real HRM.
4. Confirm current `notification_private.governance_control.enabled=false`.
5. Verify 122/8/2 previous **historical** baselines against ACTUAL pre-rollout
   counts; equality between before and after is the safety criterion, not a
   hardcoded count that may naturally change.
6. Final phase integration must persist and deduplicate actual digest
   notification jobs, enforce real provider-success-based quotas atomically,
   avoid concurrent-worker bursts, suppress stale sources, preserve
   genuine deadlines, deliver a single grouped Push (where appropriate),
   and record worker retries/failures and the exact cause.
7. Verify source adapters beyond To-Do, Manager/SWAs, authorization, private
   data minimization, user settings, cancellation and missed ticks.
8. No new Push cron without final integration and acceptance tests.
9. Explicit real Android + Windows verification, service-worker click routing,
   notification inbox, and adequate recovery/rollback test are required.
10. Review all 385 BR and 69 AT individually; do not equate synthetic tests
    with full acceptance. Only then consider enabling the governance flag.

## Before final migration
Run `scripts/notification-phase3-release-preflight.sql` using a
read-only production session. Verify `ready_for_phase3=true`, reconcile
migration history and deploy approval. If Phase 3 is already installed,
**do not replay**, inspect schema/migration drift first.

Apply Phase 3 with official Supabase migration capability only **after**
code review, staging compatibility and approved release window. Then run
`scripts/notification-phase3-release-postflight.sql`; expect
`phase3_installed=true`, `governance_enabled=false` and zero new
Push jobs from Phase 3. Retain its results with the PR/release evidence.

**Do not wire digest sender, activate V2, or declare user-facing grouped
Push live merely because these PostgreSQL functions exist.**

## Safe containment and rollback
- The Phase 3 file only creates new tables/functions. It neither replaces the
  Phase 1/2 evaluator nor changes the V1 delivery logic.
- `supabase/rollout/notification-phase3-containment.sql` removes service
  execute permissions for digest preparation/reconciliation, preserving all
  generated batches, source records and audit rows.
- To roll back a later live dispatch hookup, disable the Phase 4 digest
  feature and disconnect cron in a separately reviewed change. Do not
  destroy historical batches or real notification rows.
- No automatic `DROP TABLE`, `TRUNCATE`, delete of To-Dos or SWA ledger,
  or resetting Push subscriptions is allowed.

## Owner-approved pilot choices / unavailable policies
- Asia/Dhaka, execution hours 09:00–18:00.
- Routine Push pilot hours 09:00–18:00.
- Digest clocks 09:05 and 17:15.
- P3 cap 1/24h; P2 cap 2/24h.
- P1 urgent and P0 emergencies unapproved; no automatic overnight escalation.
- Holidays, weekly office days, verified public-calendar dates, payroll
  cutoffs and statutory SLAs unapproved. Keep as reviewable policy inputs;
  no invented "working day" determination.

## Historical non-destructive baselines at Phase 3 start
Main commit: `436c4446ba857d77006282852dcb8a163fb8196d`.
Live: 122 To-Dos, 117 notifications, 8 SWA ledger rows,
2 active Push subscriptions, 0 Phase 1/2 audit rows;
Governance V2 `false`, Phase 2 policy `notification-core-v2-phase2-1`.
These are dated observations, not validation of future production.

## Phase 6 dispatch integrity continuation

`20261023081545_notification_phase6_dispatch_integrity.sql` was installed as
production version `20261023083720` after existing Phase1–6 dependencies.
Do not replay it. PR #29 adds atomic reservations, explicit source leases and
existing-panel diagnostics. See `phase6-dispatch-integrity-2026-10-23.md`.
All 69 end-to-end scenarios and final activation are still not accepted.
