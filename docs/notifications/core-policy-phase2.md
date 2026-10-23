# MG-HRM Notification Core — Phase 2 Policy Intelligence

**Scope:** Phase 2 policy evaluator and SQL evidence. **V2 remains OFF**, and
the production notification sender, queue, Service Worker, digest publisher and
existing Notification Center are unchanged.

## Rulebook foundation
The work is guided by BR-003, BR-099–102, BR-115–128, BR-132,
BR-357–368 and the relevant AT-009–018, AT-052–059.
This is a limited component-level implementation, NOT 385 BR or 69 AT closure.

## Implemented in canonical evaluator
- Four priority tiers in the stable decision schema. P3 routine and P2
  important follow-up are mapped from verified source flags. No "critical"
  text automatically makes P0; a real P0 process remains unapproved.
- P1 risk can be inferred only from separately *verified* actual business
  deadline facts explicitly linked to the current source-material version,
  recipient and evidence reference; `todos.remind_on` is not a real business
  deadline. Verified overdue, next-office-open conflict and an optional
  explicit warning horizon can justify P1. Missing/stale evidence cannot.
- Unapproved P1 interrupt policy is disabled by default. Candidate decisions
  show `NEEDS_VERIFICATION` with the risk details, not fabricated escalation.
- True user-facing Push count per source/recipient in rolling 24h uses
  successful `Sent` or `Delivered` WebPush delivery receipts, counted as
  DISTINCT notification occurrences so multiple devices do not amplify counts.
- Approved item caps are P3=1/24h and P2=2/24h. Cap exhaustion returns
  `DEFER`, machine reason and next eligible timestamp.
- Configurable positive P2/P3 cooldown, per-user and per-category Push cap
  fields exist but are NULL (not approved) by default. P1 cap, urgency warning
  horizon, P0 exception and holiday calendar are unapproved/inactive.
- Real business deadline and proposed morning digest time are separate clocks;
  quiet hours do not rewrite an actual event deadline.
- Read/Mark All Read does not regenerate quota. Explicit ACK and Snooze are
  separate from task completion. ACK and Snooze leases read from existing
  safely linked supporting work ledger; fixed a previous `greatest(...NULL)`
  bug. A lease crossing a verified deadline records a conflict flag and never
  changes deadline.
- Cross-module source state remains fail-closed until true recipient/source
  version adapters are integrated (later phase). No new Smart Work UI.

## New private evidence and config
- `notification_private.core_policy_limits`: row-level-security-enabled,
  restricted policy settings, version `notification-core-v2-phase2-1`.
- `notification_private.core_verified_deadlines`: restricted, source-version
  matching evidence of a verified real deadline. Not exposed to app Data API,
  no permissions for ordinary roles or direct service table operations.
  No production deadline facts are inserted by this migration.
- Existing decision audit table gets `decision_details` JSONB; service-only
  audit RPC recomputes policy decision and writes reasoned metadata. Previous
  rows are preserved, including idempotency keys.

## Limitations and activation gates
1. `core_evaluate` is still preview-only, not called by existing scheduler
   or actual Web Push dispatch. Thus caps are **modelled, tested, not live
   enforced on production sends**.
2. Concurrent send reservations / atomic claim-and-quota enforcement require
   an authoritative dispatcher integration (Phase 4). Queries over accepted
   receipts alone cannot prevent two simultaneous workers from exceeding caps.
3. No P0 policy, P1 after-hours opt-in, official holidays, payroll cutoffs or
   staff SLA is invented.
4. No 09:05/17:15 grouped digest delivery is built (Phase 3).
5. All 69 Rulebook acceptance tests, real-device Push and full module status
   adapter checks remain separate release gates.

## Tests
Disposable PostgreSQL 16 CI compiles actual Phase 1 then Phase 2 migrations
and executes SQL assertions for:
- P3/P2 real successful-send rolling caps; fanout counted once; expiry and
  next allowed timestamp; optional cooldown/user/category cap.
- Verified 08:00 event, 17:30 preclose P1 risk, disabled default escalation,
  explicit synthetic P1 opt-in, out-of-hours non-emergency behavior.
- Live source version changed invalidates stale deadline facts.
- Read preserves history; ACK/Snooze crossing real deadline produces a conflict.
- Sensitive source note is not returned; RLS and function ACLs are restrictive.
- Phase 1 contract compatibility and audit reason JSON persistence.

## Rollout and rollback
This migration only creates new private evidence tables, adds a nullable-
default JSONB audit detail column and replaces the dormant evaluator/recorder.
It does **not** set `notification_private.governance_control.enabled=true`,
touch employees or To-Do statuses, or alter existing V1 cron and Web Push.
Capture baseline and post-apply counts; verify RPC definitions and flag.
Rollback should first revoke any new access (none enabled by default) and
restore the Phase 1 function bodies from the recorded Phase 1 migration;
retain audit/evidence rows. Never truncate any notification or HRM history.
