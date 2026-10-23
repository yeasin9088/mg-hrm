# Phase 6 — Rulebook acceptance audit and Supabase Preview repair

Evidence captured: 2026-10-23T14:24:56.976Z (UTC). User-facing office calculations use Asia/Dhaka.

All 69 Rulebook IDs were inspected against the attached v1.1 catalogue. **52 have a synthetic scenario pass, 15 remain partial, and 2 are blocked on external observation/time.** The runner executes 67 automated scopes successfully and skips physical-device UX and the elapsed pilot. Passing only an automated scope does not promote a partial AT to complete acceptance. V2 remains disabled; this is not a production acceptance certificate.

## Changes and verified runtime state

- Recovered the 30 existing applied migration identities from `supabase_migrations.schema_migrations`, restored the missing init/fix-schema/paused-sender originals, and renamed 26 repository files to the actual applied versions. No old SQL was rerun and no remote history was fabricated or deleted. One trailing blank line was normalized; both hashes are recorded in the manifest.
- Root error from GitHub check `120437282909`: `Remote migration versions not found in local migrations directory.` GitHub Pages build/deploy on that same commit succeeded. This is a migration-history integration failure, not evidence of a failed website deploy.
- New tested migration `20261023142411_notification_acceptance_gaps.sql` is applied: a tomorrow-before-opening deadline is now classified as Before Office Risk at 17:30; duplicate candidates remain separate and are returned only through an operator-guarded RPC.
- Existing To-Do rows and work details now visibly label After-hours captured and Needs next action. Similar requests expose review-only duplicate suggestions. No automatic merging, HR execution or gate activation. Service Worker shell is `mghrm-v45`.
- Production readback: 122 To-Dos, 8 workflow items and 8 canonical open sources. Operator read works, non-operator denial is enforced, anonymous read and authenticated access to the private foundation are denied. Both V2 gates remain false.
- Current operations health is true, with zero failed/dead-letter/stale/overdue jobs. Existing V1 cron is active. The security advisor group counts are unchanged before/after this migration; unrelated pre-existing findings were not presented as fixed.
- Supabase unified-log endpoint returned a fetch error; the GitHub check output, migration history and direct cron/health readbacks provided independent evidence.
- An isolated full fixture export was loaded into a second PGlite database and data plus RPC ACLs compared. This is a synthetic restore drill, not a production managed-backup claim.
- `notification-acceptance-gaps-rollback.sql` restores the previous read API/risk classifier without deleting tasks, notifications or audit. Tested; not executed in production.

## Evidence and verification boundaries

- `node scripts/run-rulebook-acceptance.mjs`: 69 IDs, 67 automated scopes passed, 0 failed, 2 deliberately not run. The committed JSON records the tested source fingerprint.
- `node --test --test-concurrency=1 tests/*.test.cjs tests/*.test.mjs`: full regression is run locally and in the new GitHub workflow; the checkpoint records final counts after completion.
- `scripts/test-notification-workflow-concurrency.mjs`: real PostgreSQL concurrent manager decisions, idempotent capture, competing schedulers and simultaneous digest slots.
- `tests/notification-workflow-browser.mjs`: real Chromium at 320/360/390/768/1024/1440, synthetic RPC transport, visible capture/action/duplicate labels, IndexedDB reload, uncertain save retry, and visible conflict. These are not physical Android/Windows or real Push-provider observations.
- `tests/migration-history.test.mjs`: every captured applied version has matching recorded SQL content, no duplicate versions, no untracked historical replay, and all executable migration paths exist.
- Formal release gate remains `NOT_READY`. The 15 partial rows below include implementation and integration gaps; the two external rows cannot be completed by inventing observations.

## Published verification

Code commit: [`c555d7618145ac874a13d98cbb9c9b5ee15f9bd2`](https://github.com/yeasin9088/mg-hrm/commit/c555d7618145ac874a13d98cbb9c9b5ee15f9bd2).

- Supabase Preview check `120469722786` succeeded. The migration version mismatch is resolved. All 31 applied versions are represented in the repository.
- [Rulebook 69 Acceptance Audit](https://github.com/yeasin9088/mg-hrm/actions/runs/39969876730) succeeded, including full regression, individual AT export, real PostgreSQL concurrency and Chromium six-viewport/offline/conflict checks.
- Full local and CI regression: **259 total, 256 passed, 0 failed, 3 skipped** (two explicit external ATs plus one pre-existing skip). The dedicated 69-AT runner: **67 automated scopes passed, 0 failed, 2 not run**.
- [Pages deployment](https://github.com/yeasin9088/mg-hrm/actions/runs/39969876656) succeeded. Live `notification-workflow-ui.js` and `sw.js` were fetched and compared byte-for-byte with the released files; both matched.
- All six GitHub checks on the code commit succeeded. No real-device/pilot or full acceptance claims were inferred from these successful checks.

## Deployment reliability follow-up

A later documentation-only deploy exposed an intermittent apt/ImageMagick download stall. The publishing job now uses committed approved PNGs and an offline Node validator for their source hashes and dimensions. Both committed PNGs were compared byte-for-byte with the already deployed approved icons and matched exactly. Four Pages packaging tests pass, including rejection of modified branding. No icon conversion/download is needed during publishing.

## Individual results

| AT | Controlled acceptance status | Observed result / remaining work |
|---|---|---|
| AT-001 | PASS_SYNTHETIC | Capture UUID retries return exactly one durable To-Do; browser IndexedDB reload/retry is tested separately in Chromium. |
| AT-002 | PASS_SYNTHETIC | A task without an action plan stays in the source queue and reports Needs Next Action; matching UI label is tested in Chromium. |
| AT-003 | PASS_SYNTHETIC | Read/All Read leaves stage, deadline, promise, priority and decision unchanged. |
| AT-004 | PASS_SYNTHETIC | Informed leaves manager decision pending and party communication open. |
| AT-005 | PASS_SYNTHETIC | Approval does not record execution or completion. |
| AT-006 | PASS_SYNTHETIC | Rejection retains communication and cannot authorize execution. |
| AT-007 | PASS_SYNTHETIC | Outstanding steps reject completion and source remains active. |
| AT-008 | PASS_SYNTHETIC | Explicit reopen retains audit and opens a new work cycle. |
| AT-009 | PARTIAL | Stable event keys and grouping tested; one visual thread across policy reasons and repeated days is not fully proven. |
| AT-010 | PARTIAL | Deadline attention and quota bounds tested; the full urgent policy re-alert transition matrix remains unverified. |
| AT-011 | PASS_SYNTHETIC | Read does not prevent the actual deadline trigger or create a tick storm. |
| AT-012 | PASS_SYNTHETIC | ACK suppresses delivery during its lease and eligibility returns after expiry. |
| AT-013 | PARTIAL | Cross-deadline snooze is rejected safely; an explicit policy exception workflow is not implemented/approved. |
| AT-014 | PARTIAL | Routine quiet-hour deferral tested; no approved emergency exception opt-in exists. |
| AT-015 | PASS_SYNTHETIC | Moving a true deadline changes the source fingerprint and digest time; existing last-mile tests cover stale-source suppression. |
| AT-016 | PASS_SYNTHETIC | A resolved source is suppressed after a reservation was made. |
| AT-017 | PASS_SYNTHETIC | An exhausted Push cap leaves the source active and digest-visible. |
| AT-018 | PARTIAL | Overlapping deadlines create one attention event per source version/reason/day; a persistent visual thread combining all reasons is not fully implemented. |
| AT-019 | PASS_SYNTHETIC | Reconciliation/attention never mutates current employee project or confirms joining. |
| AT-020 | PARTIAL | Reschedule/not-joined follow-up tested, plus existing transfer regression suite; full explicit joining server/audit acceptance remains unverified. |
| AT-021 | PASS_SYNTHETIC | Tomorrow leave remains in Brief Manager with independent communication. |
| AT-022 | PASS_SYNTHETIC | Source approval retains pending project/requestor communication. |
| AT-023 | PASS_SYNTHETIC | Missing project allocation days block verification/completion without payroll changes. |
| AT-024 | PASS_SYNTHETIC | Next-month promise survives month rollover and remains actionable. |
| AT-025 | PASS_SYNTHETIC | Rejected/withdrawn/hired/cancelled candidates suppress obsolete work; selected is not hired. |
| AT-026 | PASS_SYNTHETIC | Unsupported resolver fails closed; a missing formerly linked source exposes repair work. |
| AT-027 | PASS_SYNTHETIC | Two requests from one employee retain independent source IDs. |
| AT-028 | PARTIAL | Sender fan-out to four synthetic endpoints tested; physical devices and provider receipts are not observed. |
| AT-029 | PASS_SYNTHETIC | Digest replay is unique; real PostgreSQL concurrent scheduler and slot preparation are tested separately. |
| AT-030 | PARTIAL | Mock 503 records failures and bounded retry delays; complete database-to-provider retry/dead-letter lifecycle remains unverified. |
| AT-031 | PASS_SYNTHETIC | Push-disabled preference suppresses dispatch while source and morning queue stay accurate; existing denied-permission UI tests cover no re-subscription. |
| AT-032 | PARTIAL | Operator/anonymous authorization tested; several module links open a list/reference rather than the exact record, and real Service Worker clicks remain unobserved. |
| AT-033 | PASS_SYNTHETIC | Actual sender payload and digest omit salary/disciplinary content. |
| AT-034 | PASS_SYNTHETIC | Stale revisions reject writes; Chromium exercises IndexedDB reload, retry and visible conflict. |
| AT-035 | PASS_SYNTHETIC | UTC instants round-trip while Dhaka dates cross midnight correctly. |
| AT-036 | PASS_SYNTHETIC | Expired occurrences return no eligible deliveries. |
| AT-037 | PASS_SYNTHETIC | Dismissed notification leaves source active and unacknowledged. |
| AT-038 | PARTIAL | New RPC ownership, private ACLs and anonymous denial tested; a complete service-role/RLS authorization matrix across all source modules remains unverified. |
| AT-039 | PARTIAL | Synthetic cron stale/failure health and latest-slot catch-up tested; actual live V2 cron failure/recovery is unobserved. |
| AT-040 | PARTIAL | Dead-letter record retains its actionable source and diagnostic resolver; complete failure-to-health-warning integration remains unverified. |
| AT-041 | PASS_SYNTHETIC | Canonical historical terminal statuses survive source synchronization. |
| AT-042 | PASS_SYNTHETIC | Flag containment and the existing rollback regression retain tasks, notifications and audit. |
| AT-043 | BLOCKED | Physical Android/Windows action timing and accessibility observations are required; synthetic six-viewport Chromium checks are separate evidence. |
| AT-044 | BLOCKED | An observed 14–30 day pilot and measured duplicate/missed/overdue/usefulness results require elapsed time. |
| AT-045 | PASS_SYNTHETIC | Full isolated PGlite fixture is exported, loaded into a second database and compared, including RPC ACLs; no production restore or managed backup claim. |
| AT-046 | PASS_SYNTHETIC | Reconciliation neither changes HR source rows nor executes work. |
| AT-047 | PASS_SYNTHETIC | 18:01 capture is durable and classified after-hours; office attention is deferred and Chromium checks the visible label. |
| AT-048 | PASS_SYNTHETIC | Night briefing/manual informed records are accepted without approval. |
| AT-049 | PASS_SYNTHETIC | A manually recorded 21:00 approval leaves execution and communication open, with audit. |
| AT-050 | PASS_SYNTHETIC | 15 separate notes produce 10 recorded decisions and 5 pending decisions. |
| AT-051 | PASS_SYNTHETIC | Night salary capture survives into morning queue without sensitive Push content. |
| AT-052 | PASS_SYNTHETIC | 08:00 actual deadline remains Before Office Risk at night. |
| AT-053 | PASS_SYNTHETIC | Tomorrow 08:00 joining is Before Office Risk at 17:30 and never auto-confirms joining. |
| AT-054 | PASS_SYNTHETIC | 17:59 attention is eligible once; 18:00 is deferred without losing the source. |
| AT-055 | PASS_SYNTHETIC | 08:59 is not due; overnight tasks are one durable 09:05 batch. |
| AT-056 | PASS_SYNTHETIC | 00:30 All Read does not change morning eligibility or work state. |
| AT-057 | PASS_SYNTHETIC | After-hours informed removes only that completed step; decision/handoff remain. |
| AT-058 | PASS_SYNTHETIC | A before-opening deadline keeps its real instant and conflict. |
| AT-059 | PARTIAL | Unknown calendar remains explicitly unconfigured; a configurable calendar proposal workflow has not been provided. |
| AT-060 | PASS_SYNTHETIC | Exactly 09:00/18:00, UTC instants and Dhaka midnight are verified. |
| AT-061 | PASS_SYNTHETIC | Stale concurrent decisions reject overwrite; real PostgreSQL lock test and browser conflict are separate evidence. |
| AT-062 | PASS_SYNTHETIC | Browser suite verifies durable IndexedDB, honest unconfirmed status, reload and reconnect retry. |
| AT-063 | PARTIAL | After-hours Push remains disabled and no business execution is automatic; approved opt-in awareness-only emergency path is absent. |
| AT-064 | PASS_SYNTHETIC | Cross-deadline snooze cannot hide a true overdue source. |
| AT-065 | PASS_SYNTHETIC | Actual 21:00 occurrence, capture time and later recorded time remain distinct. |
| AT-066 | PASS_SYNTHETIC | 06:00 true overdue remains separate from next office availability. |
| AT-067 | PASS_SYNTHETIC | Different projects/requests remain independent; same-text same-project matches are review-only suggestions, never automatic merges. |
| AT-068 | PARTIAL | Denied Push/failed jobs retain actionable morning tasks; full failure-to-visible-health-warning integration remains unverified. |
| AT-069 | PASS_SYNTHETIC | 17:15 digest retains before-opening risk and pending communication even after Read. |

Exact original acceptance wording and machine-readable scopes are retained in [the catalogue](rulebook-acceptance-catalogue.json); actual automated outcomes and source fingerprint are in [the results snapshot](phase6-acceptance-results-2026-10-23.json).
