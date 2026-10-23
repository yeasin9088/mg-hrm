# MG-HRM — Phase 6 FINAL Notification Settings Center: Binding Product Acceptance Contract

**Status:** Owner requirement confirmed 23 October 2026. **Target:** Phase 6 final go-live.
**Scope:** Enhance the EXISTING Notification Settings Center / Notification Center.
**Non-negotiable:** Do not create another Smart Work UI, parallel notification inbox,
or duplicate To-Do section. Phase 6 is the **FINAL phase**; no Phase 7.

## Goal
A modern, responsive, trustworthy and accessible Notification Settings Center
where the sole authorized MG-HRM operator can **control and verify the behavior
of the full Intelligent Notification System** from Android, mobile browsers,
desktop and installed PWA. Every enabled control must be backed by a real
server-authoritative policy; never fake a toggle whose only effect is localStorage.

## Baseline audit of existing front end
Existing source: `notification-settings.js`, `notification-center.js`,
`notification-ui.js`, `notification-ui.css` and `notification-model.js`.
Present controls: Master notifications, In-App, Browser Push, preview privacy,
toasts, minimum priority, quiet hours start/end, snooze preset, toast frequency
and devices/permission. These already provide a usable starting point.

**Confirmed gaps:** no operator-friendly access to the actual governance
state/version or planned engine rules; missing Morning/Wrap-up Digest toggles,
per-item P2/P3 rolling caps, verified P1 policy, user/category caps,
ACK lease duration, current worker/cron/Push health, readable suppression
reason, safe next-run times, preview decision, or final activation banner.

**Critical baseline contradiction to reconcile in Phase 6:**
Current `notification-settings.js` states "Urgent notifications always bypass
quiet hours" and writes `urgent_bypass_enabled:true`. This legacy setting
is **NOT approval for unverified P0/P1 overnight interrupts**. The eventual
UI and backend must clearly distinguish legacy "Urgent" labels from the new
verified P1/P0 risk model; safety-critical exception configuration remains
disabled unless the owner explicitly approves a real emergency procedure.

## Final information architecture (ONE existing panel)
1. **Overview / Health**
   - Engine status: V1 Live, V2 Staged, V2 Live, Degraded or Paused;
     display authoritative DB flags, last successful scheduler tick, queue
     status, last accepted Push, connected devices and recent delivery error.
   - Current `policy_version`, Asia/Dhaka time and next digest slot.
   - Clear banner if a server capability is not yet installed/approved.
   - No secrets, source notes, salaries or employee names in diagnostics.
2. **Delivery Channels**
   - Account Master, In-App, foreground toast, per-device Browser Push,
     privacy-safe previews, permission/registered device lifecycle.
   - Notification display and Push controls remain distinct. An off Push
     switch must not delete outstanding source work.
3. **Smart Scheduling and Digests**
   - Morning digest on/off and editable 09:05; afternoon digest on/off
     and editable 17:15; visible office execution 09:00–18:00.
   - Quiet hours distinct from office-execution availability and manager
     communication time. Never modify real business deadlines.
   - Grouping/overnight backlog status; safe next-run preview.
   - Weekends, holidays, payroll cutoff and statutory SLA options visibly
     **Unconfigured** until officially approved, not guessed.
4. **Priority / Rate Policy**
   - P3 routine: default 1 successful Push occurrence per 24h;
     P2 important: default 2 per 24h; show actual current values.
   - Editable per-item cooldown, per-user and per-category caps only with
     server validation and explicit enabled/disabled state.
   - P1 real-deadline risk status, P0 real safety/security emergency policy:
     **Disabled/Needs Verified Procedure** unless approved; ordinary
     "Urgent" textual labels must not bypass operator protection.
   - Show quota counts and next eligible time when grounded in audit.
5. **Acknowledgement / Snooze / Read**
   - Independent controls and explanations for Read, Open, Work ACK, Snooze
     and source completion. Work ACK lease policy and snooze presets.
   - If a snooze crosses a verified deadline show the conflict without
     extending the deadline. Editing a notification cannot complete a To-Do.
6. **Diagnostics and Safe Test**
   - Reasoned sample decision, last revalidation result and suppression
     reason; source and privileged details protected.
   - Preview policy effects BEFORE Save where possible.
   - Trigger only a benign, explicitly requested device test Push with
     strict safe payload and server authorization. NO HR record mutations.
   - An operator-facing alert if a digest failed, with source work preserved.

## Responsiveness and interaction behavior
- Mobile first, support widths at least 320 / 360 / 390 / 768 / 1024 /
  1440px, portrait and landscape. No horizontal viewport overflow.
- Use the existing panel trigger; mobile may become a full-height sheet,
  desktop a bounded modal/panel. Preserve accessibility and scroll location.
- Controls have descriptive labels, server-derived values, `role=switch`
  only when appropriate, keyboard/focus support, visible focus ring, escape
  closing, focus restoration, logical reading order and `aria-live` errors.
- At least 44×44px touch targets, readable type, reduced-motion support,
  high contrast and safe viewport inset padding.
- Progress states: Loading → Draft changed → Saving → Confirmed server state,
  with Disabled/Failed/Conflict as distinct cases. Never claim Saved before
  a matching server row/version has been read back.
- Concurrent edits from Android and PC require expected policy revision /
  optimistic conflict detection. On conflict, explain changes and offer
  Reload/Review, NOT a silent last-write-wins overwrite.
- Apply/Save, Cancel and Reset to Approved Defaults; reset needs clear
  confirmation and must not reset To-Dos, notifications or subscriptions.
- Disabled/ineligible options explain WHY and HOW they become available.
  Save buttons only activate when actual values change, and every field
  has server-side type/range validation.
- Frontend reads current persisted database state at open and updates
  after Save; localStorage is optional cache only, never authority.

## Phase 4–5 backend commitments BEFORE Phase 6
- One authenticated operator-scoped versioned policy read/write RPC;
  verify least privilege, version conflicts, schedule range validation and
  accurate read-after-write outcomes in isolated PostgreSQL tests.
- No blanket `service_role` grant on policy tables to browser clients.
- Preserve existing per-device permission/Push subscription controls.
- Include all global/recipient switches in the policy decision and last-mile
  dispatch, including late changes while a job is queued.
- Expose bounded diagnostics from private audit without leaking other users,
  employee notes, encryption keys or service secrets.
- Cover each control with backend behavior tests so the later UI is not
  decorative.
- Add explicit feature availability indicators; don't present staged
  features as already controlling the live V1 sender.

## Mandatory Phase 6 UX acceptance (UX-01–UX-22)
| ID | Acceptance criterion |
|---|---|
| UX-01 | Existing Notification Settings trigger opens exactly one settings surface |
| UX-02 | 320px Android: no horizontal overflow or clipped Save/Cancel |
| UX-03 | Desktop 1440px: accessible bounded panel with scrolling |
| UX-04 | Screen reader/keyboard focus enters, moves and returns correctly |
| UX-05 | Backend read reveals correct current policy version and actual flags |
| UX-06 | Master/Push/In-App changes persist independently |
| UX-07 | Digest times 09:05 / 17:15 display Asia/Dhaka correctly |
| UX-08 | Morning Digest toggle persists and controls real server scheduling |
| UX-09 | Wrap-up Digest toggle persists and controls real server scheduling |
| UX-10 | P3/P2 current caps shown; changes validated and enforced at dispatcher |
| UX-11 | Snooze/ACK lease changes affect real decisions, not task status |
| UX-12 | Quiet hours and office execution are separately explained |
| UX-13 | P0/P1 exception controls remain inactive without approved policy |
| UX-14 | Actual selected category/device exceptions are visible and durable |
| UX-15 | Pending backend save never shows Saved |
| UX-16 | Network/offline failure restores draft and shows real error |
| UX-17 | Concurrent mobile/desktop policy edit surfaces revision conflict |
| UX-18 | Reset affects settings only, not HRM business data |
| UX-19 | Decision preview supplies verifiable machine reason |
| UX-20 | No secret, salary note or disciplinary description on lock screen |
| UX-21 | Accessibility, reduced motion and 44px touch targets confirmed |
| UX-22 | Full V2 Live banner appears ONLY after real verified activation |

## Explicit final stage sequencing
Phase 4: Finish source integration, policy enforcement, atomic delivery safety
and operator-scoped settings API; code and migration recorded, not V2 enabled.
Phase 5: Full synthetic/failure/concurrency tests, Rulebook 69-AT evidence,
compatibility, rollback and device E2E findings; no fabricated Pass results.
Phase 6 (FINAL): Final schema migration, settings UI/UX, real backend wiring,
controlled enablement, production deployment, Android/desktop smoke test,
operator sign-off and release closeout. No additional phase.

The application is NOT "Ready to Use" merely because this UX contract exists.
Each UX criterion needs actual test evidence at final activation.
