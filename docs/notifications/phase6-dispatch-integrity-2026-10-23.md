# Phase 6 dispatch integrity continuation — 23 October 2026

This continuation fixes concrete implementation gaps in the existing notification
system. It is not a certificate that the complete Rulebook or final V2 release
is accepted. There is no Phase 7. No new Smart Work section or parallel inbox.

## Implemented

- Private, recipient-serialized quota reservations spanning independent worker
  jobs and multi-device delivery. Provider acceptance consumes one occurrence
  across devices; all definitive device failures release the reservation.
  An unrecorded/uncertain provider outcome remains conservatively charged for
  24 hours. Retrying network sends cannot prove exactly-once provider receipt;
  existing stable notification IDs remain essential to device grouping.
- Digest membership freezes at first dispatch. A later device cannot receive
  newly added work in the same occurrence. Source changes/resolution suppress
  obsolete members immediately before delivery. Per-item, user/category and
  cooldown limits are checked with current settings under the recipient lock.
- Explicit private source snapshots for To-Do, due joining transfer, exit,
  leave approval, uniform supply/issue/bill, disciplinary record, meeting record
  and recruitment archive. Snapshots are fingerprints, not copies of HR data.
  The archive adapter is not an invented intake/recruitment workflow.
- Source-level Work ACK, Snooze and Resume with operator checks, server time,
  revision conflicts, immutable action audit and verified-deadline protection.
  Explicit source leases defer the V1 dispatcher as well as staged V2. Read,
  Dismiss and source completion remain separate.
- Existing Settings now includes authenticated scheduler/Push health. Existing
  notification details offer explicit source leases, suppression reasons and
  digest-to-To-Do links. The Pages asset allowlist and Service Worker cache
  include the new UI module. No external messages or HR changes are performed.
- Version fingerprints are captured for newly created source notifications.
  Old historical rows are retained; unknown source types fail closed in V2.
- Existing V1 mode is retained when the V2 gates are disabled. Non-To-Do source
  producers continue through the existing event processor.

## Verification and rollout

Local Node/PGlite regression and UI VM checks are recorded in the PR. The
`Notification Phase 6 Dispatch Integrity` workflow additionally uses PostgreSQL
16 and two independent concurrent transactions. Chromium checks use synthetic
RPC responses at 320/360/390/768/1024/1440px and cannot prove physical Android
or Windows Push behavior. A local browser download failed; use CI evidence.

Migration: `20261023081545_notification_phase6_dispatch_integrity.sql`.
It must run AFTER the already installed Phase 1–6 logical migrations, regardless
of filename prefixes. Do not replay old migrations or reset the database.
The migration does not turn either V2 flag on. Production application and
postflight details will be recorded after CI and deployment verification.

Containment: disable both V2 gates. The exact prior dispatcher/result definitions
and planner/evaluator restoration are in
`supabase/rollout/notification-phase6-integrity-rollback.sql`. This retains all
HR/source/history/subscription and new audit rows. Rolling back source leases
also revokes their mutation RPC, so the deployed UI cannot falsely save an
unenforced lease. Never execute rollback merely as a production test.

## User guide

Open existing Notification Settings for current server policy and health. The
engine status distinguishes V1 live from V2 staged. A staged policy control does
not alter live V1 scheduling. For a backend notification, open **Reminder
details** to inspect its source and last suppression reason. **Acknowledge work**
pauses source reminders for the selected time; **Snooze source** also pauses
reminders; **Resume reminders** clears the source lease. None of these controls
approves, completes, transfers or modifies an HR record. A verified deadline
cannot be moved by a reminder lease. Conflicting edits require reopening details.

## Remaining final-release blockers

- Full Rulebook workflow/obligation semantics (next action, promised response,
  manager decision/communication/execution handoff) are not made complete merely
  by adding source snapshot adapters. Several authoritative module producers
  and date/version transitions still require complete integration evidence.
- Grouped mixed-module delivery, verified P1 treatment and all 69 complete
  acceptance scenarios remain unaccepted. Emergency/holiday/payroll policies
  must not be invented. Longitudinal pilot evidence cannot be produced instantly.
- Real authenticated Android/Windows provider Push, click/offline/permissions,
  production cron recovery and full final UX acceptance remain unverified.
- Keep final release gate NOT_READY and both V2 flags OFF. Do not change a false
  acceptance field to true merely to satisfy a deployment request.

## Verified installation checkpoint

- PR #29: https://github.com/yeasin9088/mg-hrm/pull/29
- All nine workflows on implementation commit `fadeb5d08356de346458d0bbd45be9245f7fc939` passed.
- Actual PostgreSQL concurrent-session quota assertion passed:
  https://github.com/yeasin9088/mg-hrm/actions/runs/39925630462
- Chromium settings + source lease controls passed at all six widths:
  https://github.com/yeasin9088/mg-hrm/actions/runs/39925630072
- Local full suite: 177 tests, 176 pass, one pre-existing skipped; subsequent
  synthetic rollback verification passed without deleting source or audit rows.
- Production migration applied as `20261023083720 notification_phase6_dispatch_integrity`.
- Live read-back verified new functions, quota hooks and RLS. Anonymous users
  cannot call diagnostics or source mutation; authenticated clients cannot
  access private quota tables or reserve quota directly.
- Preserved counts: 122 To-Dos, 117 notifications, 8 historical SWA records,
  2 active registrations. No production test leases/reservations were created.
- Live source snapshots classified 45 current and 77 resolved/ineligible To-Dos.
- Both V2 gates remain false. Full final release is still NOT_READY for the
  remaining blockers above; deployment of these improvements is not activation.
