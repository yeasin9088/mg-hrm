# Phase 6 integrated workflow continuation — 23 October 2026

## Implemented scope

The four existing To-Do tabs now own the work interface: next action, responsible
party, review, real deadline, event and promised response time. Existing manager
controls use the same audited workflow. Manager discussion, decision,
party-specific communication, actual execution, verification and completion are
independent records. Required custom substeps also block parent completion. A decision never performs an HR operation or sends messages.

The server uses source-row and workflow-row locks, optimistic versions, idempotent
request IDs and private request receipts. Quick capture creates an ordinary
To-Do exactly once. IndexedDB stores identity-scoped unsent intents until server
acknowledgement. Conflicts and rejected requests remain visible for review.
A local queue is explicitly not a server save. A blocked or missing next action
remains visible; review and overdue clocks do not depend on notification Read.

Transfer, leave, exit, recruitment archive and three uniform sources receive
stable source-linked To-Do follow-ups. Authoritative closure stops source work
while unfinished communication remains open. Rescheduling invalidates queued
versions; a genuinely reopened source can reopen its automatically closed task.
Meeting and disciplinary records remain informational notifications unless the
operator explicitly links a real work obligation. An archive adapter does not
invent a recruitment intake backend. The notification engine never changes an
employee's project, approves leave, calculates payroll or executes disciplinary
action.

Salary plans can record project date ranges and detect uncovered or overlapping
days in a specified month. A promised next-cycle response remains attached to the
same task. No official payroll cutoff, working calendar or pay calculation is
inferred. Changed requirements require an operator reason in the audit.

Morning/wrap-up batches include all supported source-linked work through its
canonical To-Do identity. Important verified time risks can surface between
slots; transactionally enforced P2/P3 caps and generic lock-screen text apply.
Historical direct-source sends and linked To-Dos share per-source quota.
P0/P1 emergencies and after-hours overrides remain disabled.

## Verification

- Ten workflow integration tests cover independent handoffs, stale revisions,
  retry receipts, rejected approvals, true deadlines, salary allocation,
  source reschedule/closure, 15-item manager sessions, bounded attention events
  and data-preserving containment.
- Full local suite: 187 total, 186 passed, one existing skip, zero failures.
- Real PostgreSQL 16, two connections: concurrent manager writes reject the
  stale edit; simultaneous duplicate capture creates one task.
- Actual Chromium at 320/360/390/768/1024/1440px: server saves, IndexedDB network
  failure/recovery, conflict review and touch targets. The responses are
  synthetic; this does not prove physical Android/Windows Push display.
- CI evidence: PR https://github.com/yeasin9088/mg-hrm/pull/30 . Run
  https://github.com/yeasin9088/mg-hrm/actions/runs/39955767368 passed the full
  workflow suite, real PostgreSQL concurrency and six viewport checks.
  Later refinements require their own final-head run before merge.

## Rollout and recovery

Migration: `20261023122146_notification_workflow_completion.sql`, after the
installed dispatch integrity and recruitment-selection fixes. It adds workflow
metadata without resetting original To-Do statuses, schedules or HR data.
It does not activate the V2 gates. Production installation and deployment
will be appended after verification.

Containment: `supabase/rollout/notification-workflow-containment.sql` disables
both V2 gates, restores captured production dispatcher/cron/work functions,
disables new source triggers and revokes new mutation APIs. All source/task,
workflow/audit, notification, subscription and queued-intent data are retained.
Revert the Pages assets for a UI regression. Containment is tested on synthetic
data; do not execute it as a production experiment.

## Current acceptance boundary

This is a substantial implementation continuation. Physical-device display,
Service Worker click/offline/permission walkthrough, complete 69-scenario live
acceptance and a 14–30-day usefulness pilot are not observed by these tests.
The final release checkpoint must retain honest unverified fields. Passing
component/Chromium tests must not be relabelled as physical-device acceptance.

## Usage

Open **To-Do & Follow-up → Work steps** for any task. Save its action plan,
record the actual conversation/decision and each required recipient separately,
then record real execution and verification. Complete becomes available only
when the required steps and original module permit it. **Brief manager now**
is available after hours and summarizes each session independently. **Quick
capture** stores one ordinary task; **Pending saves** shows unsynced/conflicted
changes. **Needs attention** filters the current existing tab.

## Production installation

Applied `20261023130557 notification_workflow_completion`. All 122 original
To-Dos, 117 notifications and two active registrations remain unchanged.
There are eight canonically open To-Dos, all linked to the eight existing
workflow rows. No source mirror was created while V2 gates were disabled.

A live discrepancy was found in the earlier snapshot adapter: its incomplete
terminal-state list counted 45 open tasks instead of the authoritative eight.
Forward migration `notification_source_truth_alignment` now calls the exact
canonical `todo_actionable` helper, including terminal manager-status spellings.
The added test checks every terminal spelling in both status fields. This
corrects earlier diagnostic counts without changing any source status.

Alignment applied as `20261023130913 notification_source_truth_alignment`.
Live read-back now agrees: canonical eight, snapshot eight, all eight visible
through the operator role and linked to the existing work ledger. Scheduler,
sender and maintenance remain healthy with zero failed/dead-letter jobs.
