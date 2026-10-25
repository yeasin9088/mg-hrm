# Simple read-aware reminders — 24 October 2026

This owner-approved policy supersedes the former daily caps, work acknowledgement leases, workflow steps and scheduled digests for To-Do reminders.

- The previous enabled governance/digest branch bypassed `notification_schedule_todos`; the legacy producer is now active with the new simple read gate.
- A source has one outstanding unread reminder. Display, push acceptance and closing a popup do not acknowledge it.
- Read, opening the notification, or Remind next time establishes the next interval from the persisted acknowledgement. Custom date schedules and notification hours remain effective.
- Complete closes the actual To-Do and disables its reminder. Approved/rejected outcomes are preserved; a pending item uses generic `solved`, without inventing an approval.
- Normal To-Do status changes no longer require the removed Work steps workflow.
- Office hours support daytime, overnight and 24-hour windows in Asia/Dhaka. Settings use a revision check and one atomic database save. Changing the hours also rebases acknowledged reminders; switching to 24 hours does not leave an old next-morning clamp in place.
- Device actions use a random 256-bit, notification-scoped, expiring capability. Only its hash is stored. The Edge endpoint checks that capability through a service-only RPC; it accepts no caller-supplied source/user ID. Actions recheck ownership and active-profile status.
- Device action slots follow `Notification.maxActions`. With two slots, Complete and Remind next time are shown; tapping the notification opens it and marks it read. In-app reminders expose all three actions.
- A failed background action opens the authenticated application with the original action intent. No failed action is presented as saved.

Deployed migrations: `20261024111642_simple_read_aware_reminders.sql` and `20261024113123_rebase_reminders_after_hours_change.sql`.
Edge functions: `web-push-sender` v9 and `notification-device-action` v1.

Validation includes isolated PostgreSQL scheduling/action/authorization tests, browser checks at six widths, action-limit and cold-start tests, and a rollback-only verification of read and background completion against the live schema. Existing source records were not completed by these verification checks. Provider acceptance is checked independently of physical device display.

## Device delivery repair — 24 October 2026

The Android registrations were revoked after their FCM endpoints expired; only two Windows Edge registrations remained active. Provider acceptance on Windows did not establish that the phone could receive a push.

Granted browsers now reconcile their subscription on sign-in, app resume and reconnect. Provider-expired endpoints are replaced, including when local device storage was lost. Explicit manual revocations are respected during automatic repair. A newly registered device receives each existing unread actionable To-Do occurrence once, without acknowledging it or creating another reminder. Note previews include all To-Do categories when enabled. Background task actions remain unchanged.

Settings include **Test device push**, which queues a fixed, non-sensitive test for the current registered device. This explicit diagnostic works outside reminder hours and in the foreground, with ownership checks and a one-minute rate limit. Queued/provider-accepted status does not claim that the OS displayed it. Browser/OS permission still requires the device owner's interaction when blocked.

Migrations: `20261024120948_repair_device_push_registration.sql` and `20261024121149_isolate_manual_device_push_test.sql`; sender v10; service worker v56. Validation covers expired endpoint renewal, permission and manual-revocation behavior, one-time unread backfill, preview content and capabilities, per-device test authorization, office-hour bypass for diagnostics, and six responsive browser widths.

## Authoritative timing and automatic Seen — 25 October 2026

The reported 18:20/18:22 times came from client-computed reminder edits outside the configured 09:00–18:00 window. The scheduler correctly stopped outside that window, but those writes were not clamped and the cards did not refresh server scheduling state.

A server-owned natural due time now preserves the interval separately from the effective delivery time. Database guards normalize edits and reject stale browser clock writes. Settings immediately reconcile every owned actionable reminder, including first reminders without read history; equal endpoints mean 24 hours, overnight and limited windows work, and master Off pauses without losing the natural clock. Re-enabling releases due work once. The visible global settings are authoritative over obsolete category and quiet-hour overrides. Pending delivery is deferred while disabled instead of discarded.

Opening the notification page or bell panel automatically persists Seen for the inbox. Refresh acknowledges newly arrived items without resetting already-seen intervals. Remaining on an actually visible inbox also acknowledges newly rendered notifications; background polling elsewhere does not. Cadence edits preserve an outstanding unseen occurrence. Existing Complete and background device actions remain supported.

To-Do cards refresh server times after saves, inbox refreshes and device actions. Labels distinguish the next scheduled time, waiting for Seen, queued/due reminders and notifications Off. Reminder saves merge the returned database row rather than keeping an optimistic client-computed time.

Applied migration: `20261024201313_authoritative_reminder_timing.sql`. Service worker v58. Validation includes a scheduling matrix for windows, Off/On, first occurrence, repeat suppression, Seen idempotence, cadence changes and deferred delivery; six viewport browser coverage for panel visit/refresh, actions and settings; live transaction-rollback checks; and the repository regression suite. Routine scheduling uses the existing one-minute cron. Provider acceptance still does not establish physical OS display.

## 2026-10-25 — Background notification branding

The operator confirmed scheduled reminders and tray actions arrive, but Android sometimes substitutes its default bell and site initial for the logo and badge. Test and scheduled pushes share the same service-worker renderer; image URL fetching was still an external dependency despite CacheStorage precaching. Exact approved PNG bytes are now embedded in service worker v59 as data URLs, so native notification image loading needs no network/cache lookup. Payloads cannot override these assets. Existing image caching and safe update behavior remain compatible.

Validation: offline/no-cache push-handler tests assert both test and scheduled paths retain exact source bytes and action buttons; Chromium offline image decoding validates 192px logo and 96px badge; CI covers these regressions. Physical Samsung tray appearance after the v59 update remains a device verification, not a claimed automated result. No database or reminder timing change.

## 2026-10-25 — Confirm new To-Do inserts before success

Direct Bengali, translated and Save original creation now share a confirmed INSERT path instead of calling the existing-row UPDATE helper. Drafts remain in the existing local queue until the server returns the matching row. Failed saves retain original text, translation, reminder choice and stable insert ID for Retry. Concurrent retries are blocked; a duplicate-key response is recovered only by reading a matching original note, without overwriting existing data. Successful cards use server-returned scheduling fields. Update failures no longer incorrectly diagnose every server failure as an internet outage. Service worker v60 refreshes the app shell.

Regression cases cover null/empty confirmations, retry identity, cached translation, original text, category/reminder preservation, concurrent taps, matching/conflicting duplicate keys and inline script syntax. Existing note content is not modified by this release. Previously lost drafts cannot be reconstructed from missing server rows; the operator retained the affected text.
