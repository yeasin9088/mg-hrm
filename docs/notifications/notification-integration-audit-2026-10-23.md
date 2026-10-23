# Notification integration audit — 23 October 2026

## Scope and evidence

Read-only production catalog queries were compared with current `main` at
`a98b857e7a03e1e922218382fc1f5c60c0201a3d` and Rulebook v1.1. This is an
integration checkpoint, **not** evidence of 385 implemented rules or 69 passing
acceptance tests. The companion traceability matrix has one row for each rule.

Production snapshot: 122 To-Dos, 8 historical SWA ledger records, 2 active
push subscriptions, 0 pending/processing/failed notification jobs and 0
pending/failed notification events. Four active notification-related cron jobs
were found, including the transfer producer, server processor, maintenance,
and Web Push sender. Counts may change after this inspection.

## Existing path and owners

| Stage | Current component | Observed boundary / gap |
| --- | --- | --- |
| Business source | `todos`, transfer, leave, uniform, disciplinary and other module tables | Source statuses are module-specific; SWA ledger is historical/supporting and must not supersede source truth. |
| Producer | `notification_schedule_todos`, `notification_claim_todo_reminder`, `mghrm_sync_due_transfer_notifications`, module triggers/RPCs | To-Do server and foreground claim share a lock and gate; all other producers still require individual policy mapping. |
| Source resolver | `notification_source_state`, `notification_check_*` | Core, leave and selected uniform types supported; unsupported source types require explicit verification and repair visibility. |
| Candidate and gate | `notification_events`, `todo_followup_allowed`, `governance_evaluate_todo` | Governance evaluator is preview-only; production control `enabled=false`. It has no cross-module decision contract. |
| Dedupe and queue | `notification_events.event_key`, `notifications`, `notification_jobs` | To-Do identity includes old reminder slot. A V1 read-aware repeat trigger remains active. Material source version and policy reason are absent from the common key. |
| Processing | `notification_cron_tick`, event processor, `notification_run_recurrence`, `notification_prepare_deliveries` | Recurrence still has V1 semantics; office backlog aggregation and decision audit are absent. |
| Push dispatch | `notification_claim_web_push_jobs`, `notification_get_web_push_dispatch`, `notification_web_push_preview`, Edge Function worker | Dispatch rechecks To-Do actionability and preferences. It does not prove all source types remain actionable or that a changed business deadline invalidates a queued job. Preview may include To-Do note when user enabled content preview; privacy policy must be reviewed. |
| Display and action | `sw.js`, `notification-center.js`, `notification-ui.js`, `notification-settings.js` | Service Worker tags per notification ID and routes click into app. Device clear, app read and business ACK remain different interactions. |

## Verified incompatibilities and release blockers

1. The active `notification_private.prevent_unseen_repeat` trigger suppresses
   repeats on unread roots and waits for a read timestamp. Flipping the V2 To-Do
   gate alone cannot deliver bounded unread urgent re-alerts (AT-010).
2. The preview evaluator's `important` class combines `is_important` and text
   priority. It does not implement verified P0/P1/P2/P3 impact tiers, nor a
   deadline exception to its fixed important cooldown. Its office-hours check
   also conflates notification eligibility with office execution availability.
3. The preview's event count uses generated `TodoReminderDue` events as the
   alert history, not confirmed per-device push attempts or grouped delivery.
   It therefore cannot prove the proposed caps or low-noise digest behavior.
4. `notification_get_web_push_dispatch` rechecks some source and preference
   facts, but its explicit source predicate is To-Do-specific. There is no
   unified source-version check, expiration policy or reasoned suppression
   across every producer immediately before Push.
5. Existing Web Push preview can insert a To-Do note into a device payload.
   Whether that is acceptable on a locked screen requires an explicit setting
   and privacy acceptance test; salary and disciplinary data must remain generic.
6. No validated 09:05/17:15 digest, morning burst cap, owner-approved P1/P0
   exception, holiday calendar, salary cutoff, or cross-module obligation map
   exists. Do not infer business deadlines from `todos.remind_on`.

## Security and current deployment

The database advisor reports RLS disabled on
`notification_private.governance_control`. Direct production privilege checks
showed `anon` and `authenticated` have **no table SELECT/UPDATE grant**, and
`anon` has no schema USAGE. Thus the advisor deserves review, but its generic
claim that these two roles currently can modify every row is not supported by
the observed grants. No security setting was changed. Private function EXECUTE
was also unavailable to `authenticated`; the public preview RPC is operator
gated. Future migrations should enable defense-in-depth RLS after staging
checks for trusted processor access.

The four cron schedules are live and the V2 flag is false. No production SQL,
data, policy flag, Auth setting, Edge Function or deployment was modified here.
Supabase branch inventory exposed only a `main` entry reporting
`MIGRATIONS_FAILED`; no validated isolated hosted staging database was found.
An attempt to create a fresh development branch returned
`PaymentRequiredException`: branching requires the Pro plan or higher.
The in-process PostgreSQL fixtures do not substitute for a hosted end-to-end
dispatch and Android device smoke test.

The existing To-Do manager-status control previously showed a success toast
after `mgTdPush` returned false, and the write helper treated an offline `null`
or zero returned rows as success. The local UI patch requires a returned row
and restores the previous status on failure. A synthetic test covers both
branches. Concurrent device updates still need a server-side version check and
an auditable decision event before AT-061 can pass.

The existing To-Do status control also changed local `status`/`solved_at`
before any database confirmation. A follow-up local patch awaits a returned
server row before changing either field, rejects a second tap while a write is
pending, and leaves the item open on a failed/offline write. This does not yet
solve conflicting writes from two different devices.

An additive **unapplied** migration
`20261023120000_salary_todo_push_privacy.sql` keeps Salary Note text out of
lock-screen previews even if content preview is enabled. Its isolated PGlite
test covers salary, ordinary To-Do, and global preview opt-out. This is a
privacy correction in the existing notification path, not V2 activation.

An additional **unapplied** migration
`20261023130000_governance_todo_repeat_gate.sql` makes the existing repeat
trigger consult the V2 To-Do policy only while the feature flag is enabled.
The isolated synthetic test verifies V1 unread suppression, V2 policy-approved
unread repeat, V2 suppression and terminal-root suppression. The flag stays off;
the complete production recurrence, deadline and dispatch path is not yet proven.

## Activation gate and next implementation slices

Keep `notification_private.governance_control.enabled=false` until a synthetic
staging run demonstrates the entire producer → recurrence → delivery path with
AT-003, AT-009–018, AT-026, AT-029–040 and AT-047–069, followed by an
Android/desktop pilot. First replace the V1 repeat trigger with a single
source-aware, deadline-aware decision contract behind a reversible gate; then
build source adapters and a durable decision audit; then add configurable
aggregation/digests and dispatch revalidation. Preserve the 8 historical SWA
records and all original notification/To-Do rows.

Pending owner policies include Push hours (distinct from confirmed execution
hours), digest timing, recurrence/caps, ACK lease, emergency process, salary
cutoff, holidays and sensitive preview defaults. No proposed value is approved
merely by appearing in the Rulebook or existing preview table.
