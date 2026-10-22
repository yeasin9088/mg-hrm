# MG-HRM — Read-aware notification & follow-up rules (2026-10-22)

## Scope and authority

This is the implementation policy for the existing single-operator, multi-device MG-HRM system. The database is authoritative, not the service worker, browser cache, foreground heartbeat or an Android notification tray. It builds on the deployed `notifications`, `notification_events`, `notification_jobs`, `notification_deliveries`, `notification_escalation_rules` and `public.todos` model. This is not a request to migrate frameworks or create additional user accounts.

## Observed defect

`notification_schedule_todos` creates a fresh unique `TodoReminderDue` event per due interval, and the existing guard covers unprocessed events, future snoozes and pending push jobs but not the **unread** state of an already-delivered previous occurrence. The new event therefore becomes a new Android notification every 30 or 60 minutes even if no notification was acknowledged. The underlying event-key idempotency only blocks the *same occurrence*, not the next one.

## Invariants

1. **Semantic identity**: match recipient user ID + workflow source ID + workflow event type. Do not dedupe on title/body text or globally by employee; two genuinely different workflow events are not duplicates. For To-Do, the pair (`todo.id`, `TodoReminderDue`) is the repeat topic; for rule-driven follow-ups, the original parent notification is the repeat thread.
2. **Acknowledgement is explicit**: only a persisted `notifications.read_at` from a confirmed read/open/dismiss action is a read. Push-provider acceptance, delivery status, tab focus, seeing a badge, reloading Inbox or silently opening the app do **not** count as reads. Notification clicks already use `notification_open`; the existing Mark Read APIs remain authoritative.
3. **Never re-alert an unread topic**: if any open, unread occurrence of the same To-Do topic exists, the server must not create another occurrence. For rule-based repeats, if the parent or a prior repeat is unread, no further repeat may be inserted. Do not mark anything read automatically.
4. **Read is not resolved**: opening/reading does not complete a To-Do, transfer, leave or uniform workflow. If a source remains actionable and a recurrence is configured, it becomes eligible for a fresh notification only after the configured interval measured from the **most recent acknowledgement** (not an ancient original due time). The follow-up itself is unread until acknowledged.
5. **No backlog storms**: advance `next_reminder_at` as before even when suppressing a cycle. A missed due interval never generates a series of catch-up alerts. The unique event key, locked producer, existing job idempotency and per-subscription delivery records remain unchanged.
6. **Lifecycle**: solved, completed, cancelled, deleted or otherwise terminal sources stop eligible reminders. A snoozed open occurrence prevents parallel duplicate alerts; its own scheduled delivery remains authoritative. Dismissal acknowledges the current occurrence, not the underlying task; disabling reminders or resolving the task stops future scheduled occurrences.
7. **Delivery reliability**: keep existing server retries, quiet hours, foreground suppression, device permissions, VAPID secrets and per-device fan-out. An accepted push is NOT proof of human receipt or reading. Do not drop queued jobs merely because the browser was backgrounded.
8. **Respect distinct events**: new transfer reschedules, new decisions, new disciplinary records and materially different business events are not indiscriminately collapsed. Routine informational events (such as a disciplinary record being created) are not automatically put on recurring alerts.
9. **Limited action-required defaults**: daily (1,440-minute) reminders *after acknowledgement* for unresolved **TransferJoiningConfirmationRequired** (up to 30), **LeaveReviewRequired** (up to 14) and **UniformSupplyOrderActionRequired** (up to 14), using existing source resolution and enabled event-specific rules. These are repeat-only rules, not role-based escalations. The database requires an `escalation_after_minutes` value even for repeat-only rules, so a distant, unreachable threshold is stored and no recipient assigned. A repeat never mutates transfer assignments or completes joining confirmation.
10. **No unverified hiring automation**: the current `notification_source_state` has no recruitment/candidate resolver, so automatic follow-ups for hiring cannot safely infer whether the hiring decision is complete. Extend the source resolver and event mapping in a later reviewed change before activating that category. Otherwise a finished or rejected candidate could be repeatedly flagged.
11. **Cross-device consistency**: read actions persisted from the operator's phone, laptop or desktop apply to all of that operator's devices. Do not rely on `localStorage` for suppression or infer whether a particular OS notification was viewed.
12. **Concurrency and safety**: database trigger gating is a final safeguard at the `notifications` insert boundary; it does not rewrite existing rows, delete history, change security permissions or cancel historical push deliveries. The existing source processor remains server-only. If a prerequisite is absent, the migration must fail rather than silently loosen safeguards.

## Decision table

| Prior state for the same topic | Source state | At next scheduled interval | Result |
| --- | --- | --- | --- |
| Never notified | Actionable | Due | First notification |
| Unread, including delivered but never opened | Actionable | Any number of cycles | **No new notification** |
| Unread while app opens without opening/marking the alert | Actionable | Due | **No new notification** |
| Read, interval since acknowledgement not yet elapsed | Actionable | Due | Defer; advance schedule |
| Read, interval elapsed | Actionable | Due | One new, unread follow-up |
| Follow-up unread | Actionable | Due | No third notification |
| Snoozed | Actionable | Before acknowledgement of the snoozed occurrence | No parallel copy |
| Read or unread | Completed, cancelled or deleted | Due | No new reminder |
| Read | Distinct new workflow event | New event | Preserve legitimate new notification |
| Explicitly dismissed | Actionable & reminders remain enabled | Future due after interval | Eligible follow-up |

## Implementation points

- Database migration `supabase/migrations/20261022135600_read_aware_notification_followups.sql`: private `todo_followup_allowed`, amended authoritative and legacy fallback To-Do scheduler eligibility, a private BEFORE INSERT gate for repeat children, repeat-only rule compatibility, bounded workflow defaults, and recurrence candidate prioritization.
- No client-side guessing, clearing Android tray, suppressing all push, per-device read flag or unilateral changes to workflow status.
- Preserve and verify the transfer invariant: a transfer remains pending until the operator explicitly confirms joining/not joining via the existing process.

## Acceptance matrix and operational gates

Use isolated synthetic PostgreSQL/PGlite tests and a rollback-only hosted SQL acceptance before production. Verify unread repeated hours/days -> 1 event; read -> cooldown -> 1 follow-up; next unread -> no third; latest child read -> later follow-up; snoozed -> no parallel push; resolved/removed -> none; two devices same account -> one server event + separate allowed device delivery attempts; simultaneous scheduler invocations -> idempotent; retries -> no new business event; newly changed business event -> not falsely suppressed; priorities/quiet hours/permissions preserved.

**Do not deploy the SQL by merging GitHub Pages.** The SQL requires separate reviewed application to the correct Supabase project, then validation of Cron execution and Android receipt. Deploy staged DB changes with sender/producer carefully controlled, run acceptance and health checks, and make an explicit cutover/rollback decision. No paid Supabase upgrade, destructive data cleanup or production SQL has been authorized as part of this branch.

## Recovery

If a regression is observed, first pause the repeat-policy producers and sender under the existing operational playbook. Disable only the three policy-owned `mg-smart-*` rules; never delete inbox, jobs, alerts or delivery audit. Restore the previous exact scheduler and recurrence function definitions from the pre-migration repository/backup in a reviewed transaction, drop only the policy-owned insert trigger/private helper after reviewing dependencies, and reinstate the former target-required check. Re-run isolated and read-only checks before resuming. Do not run a blind rollback script against production.
