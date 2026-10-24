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
