# Meeting attendance incident: local repair

Read-only production investigation confirmed that the original 122 preflight
flags are NULL attendance dates linked to three valid active parent meetings,
not orphaned records or contradictory saved dates. All parent dates and identities
were verified through aggregate queries without retrieving personal/status values.
The application/RPC now supports this legacy format without changing stored dates
or attendance values; the updated preflight's six counts are all zero.
The approved migration committed on production on 2026-10-21 after verified
backup recovery, isolated PostgreSQL integration tests and an owner-confirmed
writer pause. Historical content digests are unchanged and the baseline reflects
deployed metadata. Security-staging is untouched. See the deployment status for
matching application release and signed-in smoke-test progress.

## Evidence

- The previous submit handler hard-deleted all attendance for a date before
  inserting replacements. These were separate requests; failure could leave
  records missing. Its duplicate fallback also performed partial row writes.
- The previous update handler logged update failures, ignored insert failures,
  and still announced success.
- History loaders used unpaginated `select('*')`. A synthetic 1000-row response
  containing 999 earlier rows and one row from a 40-person meeting reproduces
  the one-present display. Complete pagination reconstructs all 40. The actual
  production row limit and cause of the reported historical incident remain
  unverified.
- Generic autosync could upsert stale attendance cache after explicit writes.
- Unmarked status was saved as Absent; soft-deleted rows were included by some
  loaders; summary order was taken from other dates.

The existing workflow records one attendance row per **project**, with an
employee representative. The fix preserves that relationship.

## Delivered behavior

Explicit saves use one RPC with a complete row set and versioned edit snapshot.
The client verifies returned rows, rejects incomplete drafts, preserves blanks,
blocks double submissions, and retains the same request token for uncertain
network retries. Generic autosync excludes meetings and attendance. History uses
ordered keyset pagination; partial reads never replace the cached history.
Per-date edit drafts survive background refresh. Historical projects remain
visible, and unmarked records are not counted as Absent.

Follow-up creation remains separate from attendance. A follow-up/cache failure
after attendance commits is reported as such, without suggesting resubmission.
Meeting remarks preserve the source notes for manual follow-up reconciliation.

## Required review before database-backed testing

The final safety decision, approval steps and rollback requirements are in
`meeting-attendance-deployment.md`. Production activation remains blocked.

`meeting-attendance-review.sql` proposes a SECURITY INVOKER transaction, optimistic
version checks, retry token, active date/project uniqueness, and replacing the
employee-based attendance uniqueness constraint. It never deletes attendance.
Existing duplicate dates/projects block the SQL transaction; they must be reviewed
without automatic cleanup. Existing soft-deleted rows are never restored implicitly.

**The RPC is required. Until approved and installed in an authorized test
environment, saves fail closed with the draft retained.** SQL runtime, live RLS,
and multi-session database locking have not been tested. Tests use a synthetic
RPC contract and static SQL checks. Old clients/direct REST writes can bypass the
new protocol and must be retired before rollout. The proposed table locks briefly
serialize writes across meeting dates.

## Local validation

Run `node --test tests/*.test.cjs` (57 tests), individual `node --check` commands
for runtime JavaScript, and `git diff --check`. The suite also compiles inline HTML
scripts and checks Pages packaging. No historical recovery is claimed.
The three review SQL files and RPC PL/pgSQL passed pglast 7.21's PostgreSQL
17.7 parser without executing SQL; runtime/RLS integration is still unverified.
