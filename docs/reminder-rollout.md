# Server reminders — implementation and gated rollout

Status: source implementation; NOT deployed. Production producer mode has NOT been changed.

## Verified starting state (2026-10-21 UTC)

- Main parent: 3dc3f1d0456aea39d18c5ac1ffce022f2b53b00f.
- Connected project: enkggoozsvvkgbjeghbf. Deployed sender version 5 exists,
  verify_jwt=false, authenticates its own x-web-push-sender-token header.
- Existing notification-server-processor and notification-web-push-sender Cron
  jobs are active every minute. Each recorded 1,440 successful SQL invocations
  over the inspected day. This establishes scheduling, not HTTP success.
- The recent hour of pg_net responses contained 60 HTTP 401 responses. Do not
  infer provider acceptance from Cron success. Sender-specific authenticated
  health and successful processing still need verification.
- Sender Cron has the custom token header but does not use Vault. No relevant
  push/project URL Vault secret names were found. Values were NOT retrieved.
- Affected deployed RPC definition hashes match the checked-in catalog reference:
  claim_todo_reminder, check_core_source, cron_tick, claim_web_push_jobs,
  get_web_push_dispatch, prepare_deliveries, record_web_push_result,
  finalize_web_push_job, run_server_processor and snooze (notification_ prefix).
- Aggregate-only check found zero enabled schedules lacking an assigned/owner
  recipient and zero with an inactive recipient at inspection time.
- Browser mgReminderTick is the existing TodoReminderDue event producer.
  Existing Cron processes events; it does not compute due To-Do schedules.

## Targeted 401 investigation and remaining access gate (2026-10-21)

Cause VERIFIED, not a token-mismatch assumption: the named sender Cron targets
`/functions/v1/web-push-config` on the correct project, rather than
`/functions/v1/web-push-sender`. Its JSON headers contain a nonempty custom sender
token and no Authorization header. During 22:00–22:30 Asia/Dhaka, 30 matching
function-edge log entries showed the config path, HTTP 401 and platform error
`UNAUTHORIZED_NO_AUTH_HEADER`. The config function v6 has verify_jwt=true;
the sender v5 has verify_jwt=false and expects x-web-push-sender-token.
No credentials, endpoint capabilities or request header values were retrieved.

An unauthenticated, non-sending GET to the actual sender returned HTTP 405,
consistent with its POST-only deployed handler. This is route reachability, NOT
authentication or VAPID validation. Sender v5 has no read-only health endpoint;
POSTing to v5 with `?health=1` would still run delivery work. Do NOT do that.
The reviewed new handler's authenticated health path is tested without claims.

Actual Edge token presence/equality and VAPID validity remain UNVERIFIED.
Required-token absence would produce 500 in the v5 handler, but these 401s occur
at the different function's platform gateway, before any sender execution. No
conclusion about sender-secret rotation can be drawn from these responses.

Connected tools expose SQL, function deployment and empty development branching,
but no physical-backup creation/export/clone or Edge secret list/set operation.
CLI backup list and secret list were both actively attempted and returned
`AccessTokenRequiredError`. Environment credentials were not configured.
Supabase Dashboard fallback reached sign-in; secure browser authentication was
declined, so no retry or credential entry followed. No existing isolated database
branch was available (only production main). Plugin discovery found the existing
Supabase connector, with no additional suitable backup/secret operation.

The smallest next access step is authenticated Supabase Dashboard management
through its secure sign-in, not a token/password pasted in chat. An authorized
operator can then inspect Database → Backups and Edge Functions → Secrets.
Any paid isolated restore must be cost-approved first. A production clone must
be prevented from sending to copied subscriptions: secure network isolation and
suppression of copied Cron/pg_net/Vault before any outbound execution are
mandatory. Do not create a live clone and rely on disabling its jobs afterwards.
No full encrypted backup, integrity/restore proof, hosted integration or real
multi-session concurrency has been completed, and production rollout is blocked.

The pending Cron script now updates exactly one existing job and leaves it
INACTIVE in the same transaction. It never creates a second scheduler or flushes
old work. After the new sender's protected health returns 200/configured=true,
review old event/job/delivery work explicitly, preserving inbox/history and
cancelling only separately approved stale/duplicate push attempts. The new
`reminder-activate.sql` refuses unresolved backlog or a misconfigured/unpaused
sender; it locks queue tables, enables the producer and resumes the same job in
one bounded transaction. It does not sweep or delete any historical records.

## Architecture

Reuse the existing one-minute processor Cron. Its transaction first calls
notification_schedule_todos, then the existing event/recurrence/delivery pipeline.
The scheduler uses database time, a shared producer advisory transaction lock,
row locks, SKIP LOCKED, and the existing unique event_key. Recipient is the saved
assigned_to_user_id, falling back to owner_user_id, requiring an active profile.
Unassigned/orphaned notes are never broadcast or attributed to the last browser
user. They need an authorized owner assignment before receiving reminders.

A missed interval emits at most one occurrence and jumps to the first future
slot. Pending event/delivery work and future quiet-hour/snoozed inbox entries
coalesce later cycles. Historical records remain. No new escalation rules are
installed. Existing configured bounded non-ToDo recurrence remains intact.

Legacy `today` retains its daily recurrence; UI now labels it Daily (legacy).
`once` is a genuine one-shot option. Custom dates keep their per-date intervals,
with saved timezone (legacy default Asia/Dhaka); new picker saves the browser's
IANA timezone. Invalid/past dates do not produce fabricated occurrences.
Stored future next_reminder_at is respected, including rescheduling/snoozing.
Ordinary note cache autosync excludes schedule fields, and a consumed one-shot
cannot be re-enabled by an older cached client without a new explicit due time.
Disabling, reassignment, schedule edits and genuine terminal source states cancel
outstanding related work atomically, without deleting history. Existing one-shot
completion disables the schedule, while its queued occurrence remains deliverable.

Quiet hours: explicitly scheduled To-Do reminders obey the existing ToDo category
and global preferences, priority threshold and timezone. They do not bypass quiet
hours or modify other categories. Users can change the ToDo category's quiet-hour
setting in existing Notification settings. The picker explains this policy.
Intervals have minute-level scheduling accuracy, not second-level guarantees.

## Presence and delivery

A private RLS-enabled table binds user + signed Auth session + per-document tab
UUID; device UUID is only metadata. Heartbeats contain visibility, focus and
recent-input flags; server time is authoritative. Auth session ownership, profile
activity and session not_after are checked. No caller user ID or timestamp is
accepted. Another account cannot create effective presence for this recipient.
Client claims about physical focus cannot be cryptographically proven; clients
can only affect their own authenticated account's notification experience.

Heartbeats run every 25s, expire after 75s, and require activity within 2 minutes.
Blur/hidden/pagehide/disconnect immediately report inactive when possible;
otherwise TTL expires. Old rows are pruned after one day. Multi-tab/device
coordination uses server rows; localStorage only remembers a device label UUID.
Unknown/offline/missing capabilities conservatively permit push.

Dispatch rechecks live presence, account subscriptions, source status and current
enabled channel preferences immediately before each send. A valid foreground
session suppresses pushes across that user's subscriptions; inbox remains.
When in-app delivery is explicitly disabled, push remains eligible rather than
silently losing both channels. Presence changes concurrent with a provider
request can still race the final network send; already accepted push cannot be
recalled. Authentication changes stop the old presence tracker.

The deployed sender contracts are reused by a versioned source Edge worker.
It keeps VAPID/service credentials in server environment secrets. Production
VAPID configuration has NOT been proven valid. Fanout is per authorized device;
201/202 means provider acceptance, never proof of device display. 404/410 revoke
subscriptions; other failures use bounded exponential backoff and jitter with
existing maximum attempts, stale-lock recovery and dead-letter diagnostics.
A 45s worker budget and 8s request timeout bound batches; remaining devices retry.
Sent attempts are not resent on ordinary retries. Lost acknowledgements or a
crash after provider acceptance can still cause at-least-once retransmission;
notification tags provide device-side occurrence deduplication. Recurring events
produce distinct notification UUIDs. Snooze preserves previous attempts and
queues a later attempt; a claimed job is deferred without consuming send retries.
Payload is generic, contains only an opaque notification ID and priority. Click
opens the authenticated inbox record and existing workflow route. No note text,
employee data, subscription endpoints or provider response headers are logged.

## Local validation

Run `npm ci`, `node --test tests/*.test.cjs`, `npm run test:reminder-db`, `npm run lint`.
The DB test uses PostgreSQL WASM (PGlite 0.5.11), synthetic tables/fixtures and the
actual notification SQL functions, lifecycle triggers, constraints and indexes.
Auth helpers/sessions are isolated test fixtures, NOT a full Supabase Auth clone.
The migration is replayed to prove idempotency and rollback behavior. The
two-phase rollout SQL is exercised against synthetic Cron/net/Vault interface
stubs; this is not a hosted extension integration test. Tests cover event →
inbox → per-device queue, one-shot/recurrence, source resolution, reschedule,
quiet hours, snooze, source edit cancellation, private grants and account isolation.
Queued invocations are serialized by WASM: a real multi-connection race stress
and managed-platform integration test remain REQUIRED before rollout.
The worker transport tests use mocked providers; there are no real device sends.
Browser visual/OS notification verification is unavailable in this environment.
Deno check is performed against pinned dependencies in an isolated npm directory;
this does not prove hosted Edge execution.

Verified local results: Node 124 passed / 0 failed / 1 browser test skipped;
20 PostgreSQL acceptance groups passed; npm lint, JavaScript/inline-script syntax,
diff checks and isolated Deno sender type-check passed. Real multi-session
concurrency, hosted extensions and physical-device receipt remain unverified.

## Blocking production gates and ordered rollout

No production migration, function deployment, Cron change or producer cutover has
been executed. No production data was exported. This session cannot demonstrate
a fresh encrypted production backup and isolated restored copy through its exposed
connected tools. An existing schema baseline is NOT a backup or restore proof.
Do not merge this PR or deploy until these gates are demonstrated:

1. Create a fresh encrypted production backup via an authorized secure backup
   facility. Keep ciphertext and encryption keys separately; never place either
   in Git/chat. Record backup timestamp, integrity digest and recovery scope.
2. Restore it into an isolated authorized environment, restrict access, compare
   row counts and integrity, prove required Auth/role/RLS contracts, then run
   migration, replay, transaction rollback, real concurrent claims and security
   acceptance tests. Use synthetic recipients/subscriptions and a fake transport
   until explicitly testing dedicated real devices; never send from restored
   production subscriptions. Supabase Auth/session and Cron/pg_net integration
   must be tested on an isolated hosted stack or equivalent real environment.
3. Deploy the reviewed sender with gateway JWT verification disabled because it
   requires its own strong custom token. Securely provision identical token in
   Edge WEB_PUSH_SENDER_TOKEN and Vault mg_notification_sender_token. Retain the
   working VAPID public/private pair and subject and existing subscription keys.
   Credential handling must occur through an approved secret facility, not chat.
4. Apply the core versioned migration with server_authoritative still FALSE.
   Existing producer stays fenced only after explicit activation. Inspect grants,
   ownership and RLS against the reviewed signatures and original catalog ACLs.
5. Validate the pending `supabase/rollout/reminder-cron.sql` on the isolated stack
   (real pg_cron/pg_net/Vault; WASM cannot validate those extensions). Apply it only
   after those checks. It changes exactly one existing named sender Cron and
   leaves it INACTIVE. The invoker refuses absent/short Vault token configuration.
6. Invoke the protected sender `?health=1` through the authorized server path.
   It checks configuration and read-only capability; no jobs are claimed. Observe
   HTTP 200 and configured=true. A queued pg_net request ID is not success.
7. Explicitly review and resolve the pre-cutover event/job/delivery backlog;
   never blindly replay it or remove history. Publish verified frontend assets.
   Use `supabase/rollout/reminder-activate.sql`, which refuses unresolved work
   and atomically enables producer mode and resumes the paused sender. Cached/old clients are blocked by the legacy RPC even before refresh.
   Do not disable all reminders or rewrite saved dates during cutover.
8. Run end-to-end synthetic 30-minute and one-shot acceptance while the app is
   closed, active, minimized and stale across dedicated subscribed devices.
   Record each event ID, queue job ID, provider HTTP status and independently
   observed OS notification separately. Confirm correct account and click route.
9. Observe several cycles: Cron cadence + HTTP status, dead letters/retries,
   oldest pending job and per-channel status counts. Existing operations health
   RPC supports queue diagnostics. Never read raw endpoints or provider bodies
   into ordinary logs/reports. Alert on 401/403, repeated 5xx and backlog age.

Rollback producer mode with notification_set_server_reminders(false), under the
same transaction lock; preserve schema, next times and history. Disable/repair a
failing sender schedule through authorized operations; do not delete audit rows.
The permission/presence migration is additive; do not run a destructive down
migration or restore production over newer records as an automatic rollback.

Browser/OS constraints: user permission, secure origin, supported Push API and
service worker are required. Android battery restrictions, browser force-stop,
network loss and push-provider TTL can delay/drop display. iOS may require a
Home Screen installation. Background timers are never relied on for scheduling.
