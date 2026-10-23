# MG-HRM Notification Governance V2 — Phase 4 Integration Slice

**Status:** gated pipeline integration code, isolated tests required; NOT active.
**Feature gates:** `notification_private.governance_control.enabled=false`,
`notification_private.digest_bridge_control.enabled=false` (new).
**Product boundary:** Existing Notification Center, existing event/job processor,
existing Web Push Edge Function and Service Worker only. NO Smart Work UI.

## Existing actual queue, no parallel sender
1. A server-only `notification_private.digest_publish_slot(user,at)`
   uses the Phase3 `notification_digest_reconcile` to gather REAL actionable
   To-Dos, respecting owner, deleted/resolved and verified deadline semantics.
2. A stable event key `mghrm:work-digest:RECIPIENT:LOCALDATE:KIND` creates ONE
   event in `public.notification_events` for the whole group, not one event
   per source. Real event row uses `OperatorWorkDigest`, `System` category
   and the original `notifications` deep link. It includes no names, salary
   notes or disciplinary details.
3. Existing `notification_run_event_processor` creates the notification and
   existing `notification_prepare_deliveries` uses its normal Inbox/Push
   queue; no second sender or new external service is installed.
4. `notification_private.digest_dispatch_allowed(batch,recipient,time)`
   recalculates the Phase3 digest source truth *at actual dispatch*, rejects
   terminal, reassigned or absent source work, and checks operator and the
   approved 09:05–18:00 routine push window. A guarded extension to
   `notification_get_web_push_dispatch` skips stale delivery records with
   reason `digest_source_or_window_invalid`. The worker calls this RPC again
   before each push send.
6. A third guarded migration additionally protects the **Inbox**: a queued
   `OperatorWorkDigest` event is marked Ignored if feature switches were
   disabled or if its current source has vanished **before** the original
   event processor creates a notification. Other V1 event types remain
   untouched. Disabling the bridge also prevents any *previously queued*
   digest Web Push from being sent.
5. The existing Web Push JS worker sends a privacy-safe generic
   `MG-HRM · Work Digest` payload and opens the existing Notification Center;
   source content never enters its lock-screen payload.

## V1/V2 isolated switch
`notification_cron_tick` checks **both** existing governance enabled and
new bridge enabled. When both are ON, it *would* publish grouped digests and
run the existing event processor and delivery preparer, deliberately skipping
legacy To-Do interval scheduling and the V1 unread recurrence during that path.
When either is OFF, its original V1 behavior is unchanged.

**Do NOT flip either production flag.** This is code-level integration only.
Existing To-Do source-specific realtime alerts and verified P1 escalation
would require additional authoritative per-source decision gating and retry
tests; calendar and end-to-end caps are not fully proven.

## Explicit incomplete gates
- Phase3 is not applied to production. Phase4 depends on it.
- The existing `notification_prepare_deliveries` may still promote other
  queued V1 sources when the gated path runs. End-to-end producer,
  server queue and subscription-level concurrency/delivery quota admission
  require more integration coverage.
- The 1/24h P3 and 2/24h P2 policy currently observes previous accepted
  Push history but **does not atomically reserve slots across concurrent
  provider workers**. Do not activate pending this work.
- No user-specific source adapters have been proven for every HRM module.
  Do not claim complete rulebook BR-001..385 or AT-001..069 coverage.
- 09:05 and 17:15 digest slots are approved; **actual workday/holiday
  calendar is not**. The current planner reports `calendar_verified=false`.
- Android device, Windows browser, offline, retry/dead-letter, provider
  receipt, actual Notification Center view and explicit operator activation
  are Phase5 release criteria.
- P0 emergencies unapproved; P1 urgency exception unapproved; no night
  interrupt is invented.

## Ordered installation at final approved release
1. Inspect current production migration history, backups, auth, RLS, cron,
   pending jobs, source records and selected settings.
2. Phase1 `20261023052759_notification_core_decision_contract.sql` and
   Phase2 `20261023054338_notification_core_policy_phase2.sql` are already
   applied; do not replay them. Confirm their logical migration names.
3. Apply uninstalled Phase3 `20261023071238_notification_digest_scheduler_phase3.sql`
   (and verify source-mode tests, protected preview and grants).
4. Apply Phase4 in file order:
   - `20261023071309_notification_digest_event_bridge_phase4.sql`
   - `20261023071348_notification_processor_bridge_phase4.sql`
   - `20261023071403_notification_digest_event_guard_phase4.sql`
5. Verify V1 clone and the updated Dispatch function, keep **both flags
   FALSE** until a separate owner-authorized final activation.
6. Re-run pre/post row counts, subscriptions, cron and per-device smoke tests.
   No schema deployment is authorization to start grouped Push.

## Safe rollback / containment
- Flag OFF is immediate V1 routing only. The legacy branch stays in
  `notification_cron_tick` and the extra dispatch validation only runs
  when *both* flags are true.
- In emergencies, disable `digest_bridge_control.enabled` without
  deleting jobs, notifications, subscriptions or historical work snapshots.
  Then recheck one V1 scheduler tick in controlled non-production tests.
- Detailed rollback and migration state: `release-manifest-v2.md`.
