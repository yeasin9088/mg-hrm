# MG-HRM Notification Governance V2 — Phase 6 Release Evidence Checkpoint

Date: **23 October 2026, Asia/Dhaka**.

## Product promise
The Notification System must remain inside the existing Notification Center and
four To-Do categories. There will be **NO Phase 7**. Outstanding defects,
acceptance work and any final cutover belong to **Phase 6**, not a later phase.

## Actual changes completed this Phase 6 session
- PR #26 merged UI changes in commit `72504323c0754d84f805ee58c861b6516190ab5f`.
- Existing Notification Settings modal now contains a responsive Engine Policy
  section using `notification_operator_policy_read` and revision-aware
  `notification_operator_policy_save`. The user cannot accidentally activate
  an unapproved P0/P1 emergency. New UI states that V2 is staged until the
  two feature gates are enabled and returns a visible error when RPC unavailable.
- Replaced misleading legacy Urgent-overrides text with a V1/V2 distinction.
- Synthetic Node UI tests cover backend missing, editable controls,
  server-confirmed Save, read-back, cross-device revision conflict.
- Existing Inbox CI repaired to install locked PGlite dependencies before tests.
- PR #27 adds a real Chromium responsive viewport check with screenshot
  artifacts and synthetic backend. **Browser emulator is NOT Android Push.**
- Production Phase3/Phase4/Phase5 SQL migrations applied in this order
  (all current real-data tables retained):
  1. `20261023071238 notification_digest_scheduler_phase3`
  2. `20261023071309 notification_digest_event_bridge_phase4`
  3. `20261023071348 notification_processor_bridge_phase4`
  4. `20261023071403 notification_digest_event_guard_phase4`
  5. `20261023071437 notification_operator_settings_api_phase5`
  6. `20261023071450 notification_digest_settings_enforcement_phase5`
- After migration, read-only SQL confirms both `governance_control.enabled`
  and `digest_bridge_control.enabled` are **false**.
- Production read-back: 122 original To-Dos, 117 notifications, 8 historical
  SWA ledger rows, 2 active Push registrations, zero open jobs, zero
  generated digest events and zero new digest batches. 
- Core policy read-back: revision 1; P3 1 successful Push/24h,
  P2 2 successful Push/24h, 09:05 and 17:15 Asia/Dhaka.
  This is *configured but not fully enforced by live V2 sender*.
- `anon` has no policy-save EXECUTE and normal `authenticated`
  has no direct UPDATE on private policy table.

## Safety findings that BLOCK V2 activation
1. **Concurrency cap:** Phase2 decision counts provider receipts but a
   reservation/atomic quota claim spanning independent worker attempts is
   not proved. Simultaneous sends may overshoot.
2. **Source truth:** Complete source-version and ownership integration
   for all authoritative HRM producer modules is unverified.
3. **Full Rulebook acceptance:** The 69 ATs remain individually recorded
   as BLOCKED for end-to-end acceptance in
   `docs/notifications/phase5-acceptance-evidence.md`.
   Component-level synthetic tests cannot be conflated with these.
4. **Real-device Push:** authenticated Android and desktop provider acceptance,
   device click routing, service worker/offline/retry evidence unavailable.
5. **Product UI completeness:** New responsive settings exist but Health,
   real policy diagnostics, full ACK workflow and all UX-01–UX-22 criteria
   need final operator/browser verification. Current defaults can be
   configured but do not authorize activating the unverified pipeline.
6. **Policy clocks:** existing staged Phase4 routines contain fixed time
   checks; all server-saved clock adjustments must be validated through the
   *entire* dispatcher before claiming customization is operative.

## One final operational rule
Do NOT set either flag true or dispatch real V2 Push when the release gate
returns `NOT_READY`. Never reset business data or historical SWA rows.
Run `node scripts/notification-phase6-release-gate.mjs --assert-ready`
during the actual release review; it must exit zero using *independently
updated, verifiable* evidence only. No unverified Pass claims.

## Recovery/containment
`supabase/rollout/notification-phase4-containment.sql` disables both gates
without removing any records; follow read-only database snapshots, inspect
notification event/job backlogs, verify old V1 cron behavior, and use reviewed
fix-forward migrations for database changes. Running a containment script
itself is a governed production operation; it has **not** been executed.

## Release outcome
**Staged functionality successfully installed; V2 production activation
BLOCKED / NOT READY.** The live application still uses V1 notifications.
All remaining work stays inside Phase 6; no Phase 7.
