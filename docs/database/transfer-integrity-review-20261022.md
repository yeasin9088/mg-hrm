# MG-HRM Transfer Integrity Review — 22 October 2026 (Asia/Dhaka)

## Safety invariants
- A scheduled effective date unlocks **review actions**, not an employee assignment change.
- Only explicit, verified `confirm_transfer_joining` changes `employees.project_name`.
- `Not Joined`, cancellation, rescheduling, page refresh, Realtime events, and Cron must not perform a joining.
- Transfer due actions use the Bangladesh local calendar date, including midnight boundary.
- App remains operated by one explicitly authenticated user on multiple devices.

## Production read-only reconciliation, 2026-10-22
- Active/non-archived transfer orders: 166; completed: 159.
- One due scheduled order effective 2026-10-08.
- Three future scheduled orders effective 2026-11-01.
- No unresolved-transfer duplicates, no open-order source/current employee project mismatch, no future `Joining Pending` state.
- Existing legacy completed history includes **153** records lacking both `actual_joining_date` and `completed_at`. These dates cannot be reliably invented. Existing reports deliberately do not treat `transfer_date` as proven actual joining.
- One historical completed order (ID 134) does not equal the employee's present project; the employee is now Inactive and this 2026-10-22 inspection alone cannot establish an incorrect historical order. No historical personnel data were changed.

## Changes delivered
1. Single validated client due-date predicate shared by Transfer list, detail popup, Joined and Not Joined confirmation workflows; inactive employee guard.
2. Dashboard includes only due orders in Joining confirmations, but discloses future scheduled order count and next effective date separately. Persistent statuses are not changed by a clock tick.
3. Transfer queue detail prioritizes authoritative stored status rather than derived client queue status.
4. Removed local-browser-timezone dependency in the Not Joined submit guard; all rules use `Asia/Dhaka`.
5. Reschedule navigation returns to the selected order rather than forcing a Not Joined flow.
6. Cron-triggered, idempotent `TransferJoiningConfirmationRequired` events for due scheduled orders, every minute; uses the existing notification processor, per-user preferences and Web Push sender.
7. Due notification is deliberately omitted for the previously dismissed legacy bootstrap event, preserving user intent unless a new reschedule changes its milestone.
8. New notification generator requires exactly one active Auth-backed profile and cannot be executed by `anon` or `authenticated`; event content includes no employee names/projects.
9. Web Push preview for the new action shows only a transfer order number and actionable verification prompt when recipient permits content previews; otherwise retains generic privacy-safe body.
10. Added explicit NULL effective-date safeguard to the server-side Not Joined RPC, complementing the existing table check.
11. Added regression tests for boundary dates, single-event idempotency, no assignment mutation, dashboard visibility, and privacy-safe Web Push formatting.

## Checks and release caveats
- Production synthetic due-date SQL was run in a transaction and rolled back: zero events before due, one on due, zero duplicates on rerun, employee assignment unchanged.
- The production event scheduler runs at 1-minute cadence. Its first version had a PostgreSQL UUID aggregate issue (`min(uuid)`); a corrective migration was applied. Subsequent Cron runs were observed succeeding.
- GitHub Node test suite and Pages deployment were validated during rollout. Later commits should be checked against CI runs before treating their tests as final.
- The actual 2026-11-01 notification and phone-specific delivery cannot be observed ahead of time. Device permission, foreground presence, notification preferences, quiet hours and push transport affect delivery. Event generation and rendering have been tested separately.
- Do not backfill unknown actual joining dates from scheduled effective dates.
- Avoid claiming that historical `Completed` records' actual joining dates are known without authoritative evidence.

## Rollback
- `docs/database/transfer-due-notifications-rollback.sql` unschedules the new Cron producer and drops its function without mutating employee records.
- Prior versions of `index.html`, Web Push worker, and tests are recoverable through GitHub commit history.
- Database RPC missing-date safeguard is a narrow function change: restore the prior function definition from the preserved schema baseline if rollback is necessary after verifying deployed signatures.
