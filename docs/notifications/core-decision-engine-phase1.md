# MG-HRM Notification Core Decision Engine — Phase 1
**Status:** architectural decision contract, preview and evidence only. Not the full Notification Governance V2 engine.

## Existing architecture is preserved
The existing Notification Center, all four To-Do tabs, Web Push sender, SW,
queue and cron remain authoritative and **unchanged**. No new Smart Work UI,
notification producer or duplicate inbox has been introduced.

## Decision contract
`notification_private.core_evaluate(notification_id, evaluated_at)` is a
read-only, server-authoritative decision evaluator returning:
`decision`, `reason_code`, `reason_codes`, `priority_tier`,
`source_version`, `next_eligible_at`, `entity_type`, `entity_id`,
`recipient_user_id`, `policy_version`, `evaluated_at`,
`enforcement='preview_only'`.

Canonical valid decisions:
`SEND_NOW`, `DEFER`, `DIGEST`, `IN_APP_ONLY`,
`SUPPRESS_DUPLICATE`, `SUPPRESS_RESOLVED`,
`SUPPRESS_ACKNOWLEDGED`, `SUPPRESS_SNOOZED`,
`BLOCKED_BY_PREFERENCE`, `NEEDS_VERIFICATION`, `EXPIRED`.

**SEND_NOW is a decision recommendation, not proof of a network send.**
**DIGEST is a decision recommendation, not a scheduled/delivered digest.**
The engine currently evaluates existing notification IDs, not raw incoming
business events. Candidate event intake adapters are Phase 4, with policy
depthening in Phases 2–3.

## Intentional fail-closed source architecture
- To-Do has a verified authoritative record, assigned/owner recipient
  check, deleted/solved check, and a material source fingerprint from
  `updated_at`, status, manager_status, recipient and terminal timestamps.
- It uses `swa_work_items` only for an actual explicit acknowledgement or
  snooze lease matching the same source ID and recipient. That table remains
  historical/supporting and never replaces the authoritative To-Do.
- Terminal states of known other sources can be suppressed by the existing
  `notification_source_state`. A supported but unresolved transfer/leave
  is **NEEDS_VERIFICATION** until ownership and version adapters are
  independently verified. Unsupported source types also do not become
  approved candidates.
- Notification Read/Mark All Read does not change business eligibility;
  delivered/dismissed *same notification occurrence* can be suppressed to
  prevent duplicate display without declaring the source completed.
- Phase 1 maps ordinary/important to preliminary P3/P2. It does not infer
  legitimate P1 or P0 emergencies from a text priority label.
- The approved routine Push window is 09:00–18:00 Asia/Dhaka; out-of-hours
  candidates suggest a next 09:05 digest without inventing office holidays.
  This policy is **preview only**, not a change to current production V1.

## Diagnostic interfaces and durable audit
- `public.notification_core_preview(uuid)`: authenticated operator-only
  preview, only for his own notification, with no note, salary, message,
  endpoint, or encryption keys returned.
- `public.notification_core_record_decision(uuid,text,timestamptz)`:
  service-only, database-derived audit recording; no client may fabricate
  a decision value. Supports candidate, queue, dispatch, reconcile phases.
- `notification_private.core_decision_audit`: private, RLS-enabled,
  immutable-in-use (service cannot UPDATE/DELETE) evidence table with unique
  decision fingerprint from notification/source-version/slot/phase/reason.
  Repeated equivalent evaluations are idempotent. Audit records are NOT
  delivery receipts or business workflow completion.
- Privileged functions have fixed `search_path`; no anon execute rights.
  Internal tables are denied to anon, authenticated and direct service_role
  access. Only the specific service RPC writes audit decisions.

## Phase 1 test matrix (synthetic PostgreSQL 16)
Assertions include source truth; owner change; terminal/expiry; unread vs read;
explicit ACK vs snooze; future schedule; push/master preference; in-app-only;
09:05 Asia/Dhaka after-hours suggestion; duplicate displayed occurrence;
supported terminal vs unsupported source; private grants; unauthorized
operator; audit idempotency; privacy. GitHub Actions runs these entirely
outside production.

## Excluded until upcoming phases
1. Phase 2: Full P0/P1/P2/P3 verified impact and deadline decisions,
   business ACK semantics, rolling per-user and per-item caps, source-version
   updates and priority overrides.
2. Phase 3: Real 09:05/17:15 grouped digest, catch-up and burst control.
3. Phase 4: Connect existing event producers, enqueue, final push dispatch
   and remaining HRM source adapters to the new contract under one policy flag.
4. Phase 5: Real Android/Windows Push, end-to-end concurrency/rollback and
   69 individual Rulebook AT tests.

## Rollout and rollback
This migration creates only new private functions/audit table and an operator
preview RPC. It does NOT change any live flag, job or user record.
Before/after must verify To-Do/inbox counts, active push subscriptions, cron
status, grants and `notification_private.governance_control.enabled=false`.
If unexpectedly incompatible, revoke preview and record execute rights,
restore no existing functions (none were replaced), and retain the private
audit history for later investigation. Dropping private audit history is NOT
part of safe rollback. No planned production Push activity is introduced.

The Rulebook is a review draft: completed Phase 1 is not the 385 BR and 69 AT
acceptance certification.
