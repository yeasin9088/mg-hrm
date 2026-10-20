# Attendance release status

2026-10-21: the owner reconfirmed all old writers/jobs paused. The encrypted
backup decrypts with the existing recovery key; its isolated restore and local
40-row/retry/atomic rollback/role tests passed. Production PostgreSQL 17.6
preflight returned six zeros and matched both restored table content digests.
The exact reviewed migration committed atomically. Post-migration history is
unchanged; SECURITY INVOKER, authenticated EXECUTE, anonymous denial, RLS and
indexes are verified. PostgREST resolves the RPC and denies anonymous GET access.
The schema baseline now reflects deployed definitions. Matching Pages release
and a signed-in ordinary save/reload smoke test are pending. No synthetic
production attendance was created. Local session-claim tests do not establish
Supabase signed-JWT integration. No temporary privilege freeze was applied; the
owner-confirmed stopped-operator window remains required until matching clients
are verified. Keep backup and containment SQL; never revert to the destructive
old client.

## Archived pre-release safety review (superseded by status above)

**Readiness: FAIL for production activation; ready for isolated validation.**
No production write SQL, migration, backup/restore, Git push or deployment has
been executed. On 2026-10-20 (Asia/Dhaka), read-only MCP catalog checks and the
owner-approved exact aggregate preflight were executed. No individual employee
identity or attendance value was retrieved.

## Contract and safety

- Signature: `public.mghrm_save_meeting_attendance(date,jsonb,jsonb,jsonb,uuid)`.
  The five named JavaScript RPC arguments match SQL exactly. Tables, identities,
  nullable fields, `auth.uid()`, `public.my_role()` and both `updated_at` triggers
  match the baseline. `attendance_request_id uuid` is the only added column.
- SECURITY INVOKER retains existing RLS. Active admin/editor roles are required;
  execution is restricted to authenticated. No new SECURITY DEFINER function or
  elevated grant is introduced. Existing `my_role()` is SECURITY DEFINER with a
  fixed search path; its existing behavior is unchanged. Baseline authenticated
  table/sequence privileges support the writes and explicit table locks.
- Locks serialize validation and writes inside one transaction, including legacy
  REST writes during that transaction. Any SQL exception rolls back all its
  changes. Full row keys/types, row count, values, date/project identity, meeting
  metadata and request token are checked. Missing fields cannot act as clears.
- Exact retry of the last accepted request returns its persisted result without
  writing again. An intervening change may produce a conflict; this is not a
  permanent request ledger. Uncertain transport/PostgREST errors retain the token.
  A page reload discards the in-memory token and must reload server state.
- Existing meeting IDs, creation data and unrelated metadata are retained.
  Soft-deleted rows are never revived. Incomplete row sets are rejected.
  Null/empty-string historical blanks are preserved. Ambiguous legacy records
  require review; neither migration nor client repairs them automatically.
- The single-operator `guardEdit()` remains in place. Its OneDrive/browser lock is
  not a server authorization boundary. SQL version checks protect stale edits;
  they do not establish a global device lease.

## Outstanding production gates (verified 2026-10-20)

- MCP configuration is still `read_only=true`; live role is
  `supabase_read_only_user`, transaction read-only is `on`, and that role bypasses
  RLS for reads. The preflight counts therefore are not filtered by app-user RLS.
- Live PostgreSQL is 17.6. The two tables, types, constraints, enabled timestamp
  triggers, role policies, helper definitions and authenticated sequence access
  match the baseline. Explicit privilege checks confirm authenticated can
  SELECT/INSERT/UPDATE/DELETE/TRUNCATE both tables. No new RPC, request-token column
  or proposed unique indexes exist yet.
- Production read-only classification is now explicitly authorized. The updated
  legacy-compatible preflight returns all six counts as zero:

  | Preflight field | Count |
  | --- | ---: |
  | duplicate_active_date_groups | 0 |
  | duplicate_active_project_groups | 0 |
  | invalid_active_meeting_identity | 0 |
  | unresolved_active_attendance_identity | 0 |
  | unsupported_active_status_rows | 0 |
  | legacy_employee_constraint_conflicts | 0 |

  The original 122 flags were all NULL attendance dates across three exact active
  parent meeting IDs. All 122 parent dates are valid; no missing/deleted parent,
  missing project, duplicate project or cross-meeting date collision was found.
  The fix loads those rows by parent ID, uses the parent's date only for view
  filtering, and preserves stored NULL dates in both edits and retries. Explicit
  contradictory non-NULL dates still fail. No production data backfill or repair
  is necessary for this verified legacy format, and no status values were read.
  Recheck the same preflight under the approved writer freeze before migration.
- `psql` and `pg_dump` clients are installed. Supabase CLI, Docker and `pg_restore`
  were not found on PATH. No staging instance, restoration drill, backup/PITR
  evidence, Management API authorization, owner database connection or protected
  release environment has been verified. Read-only MCP exposes no migration tool.
- `.github/workflows/pages.yml` currently deploys on a push to `main` and does not
  wait for database readiness. No push is permitted before the owner pauses that
  automatic release path or installs a protected manual cutover gate. Existing
  single-operator/client closure is not server-side write prevention.

## Narrow automated release procedure (prepared, not activated)

Use one owner-approved release job, pinned to the reviewed SQL and application
artifact hashes. Keep the MCP read-only. A separate short-lived schema-owner
connection may run the exact file **only after owner approval**; never give the
browser a service-role key. Pass credentials through a protected PostgreSQL service
file/password file with TLS, not command-line URLs or logs. Do not run broad
`supabase db push`: this release is one reviewed SQL file, not all pending changes.
The existing SQL already has BEGIN/COMMIT; do not wrap it in another transaction.

| Order | Automated action and required evidence | Failure behavior |
| --- | --- | --- |
| 1. Build and integration | Reuse all 57 tests and existing Pages allowlist packager. Record SHA-256 of the three SQL files and every packaged asset. On an isolated PostgreSQL 17/Supabase instance, run the exact migration, real JWT/RLS role cases, 40 rows, a forced rollback, lost-response retry, two concurrent sessions and soft-delete cases. Record restore-drill evidence separately. | No production job without these results. Synthetic RPC tests alone do not satisfy integration. |
| 2. Approval and target | Protected manual owner approval references project, SQL/artifact hashes, integration evidence, backup/recovery evidence and maintenance window. Confirm the target against the configured project; use a direct/session database connection, not a transaction pooler. Suspend push-triggered Pages releases and inventory all browser/PWA devices plus privileged writers. | Refuse a changed hash, unknown target or missing approval. Never change `read_only=true`. |
| 3. Enforced maintenance | Owner-approved temporary table-write privilege freeze below; retain SELECT. Pause privileged jobs/SECURITY DEFINER writers separately, because table revokes do not stop them. Capture exact original grants before freezing and verify revoked privileges through catalogs after commit. Retire every old tab/PWA/cache and invalidate its auth sessions; wait out already-issued access tokens if necessary. | Keep writes frozen. A banner, closing one tab, or revoking only the new RPC is insufficient. If all writers cannot be fenced, stop. |
| 4. Backup/recovery and preflight | Verify a completed backup ID/time and retention/recovery window via owner Dashboard/Management API evidence. Obtain a fresh encrypted, access-controlled backup of both complete tables, their owned sequences, definitions, grants and dependencies while writes remain frozen. Personal-data export needs explicit approval. Verify archive readability/checksum and an authorized isolated restore with matching counts/content digests and sequence values; listing an archive alone is not recovery verification. Run the unchanged aggregate preflight and require all six zeros. | The revised preflight is currently all-zero; repeat it during cutover. No archive/restore or row comparison has been authorized or performed in this task. |
| 5. Atomic migration | Run only `meeting-attendance-review.sql` as owner with stop-on-error. File locks both tables before DDL; the five-second lock wait and all DDL are inside its transaction. | Abort on nonzero process exit. If connection drops, inspect catalog metadata to distinguish committed from absent; do not blindly rerun the one-time migration. Keep writes frozen. |
| 6. Database availability | Verify the added UUID column, exact RPC signature/security/ACLs, indexes, removed old constraint and unchanged RLS/triggers through catalogs. The file's NOTIFY is delivered at commit. Poll authenticated PostgREST/OpenAPI for the exact RPC argument names with a bounded timeout. | Stop on metadata mismatch or timeout. Do not call the mutating RPC as an availability probe and do not retry migration to refresh cache. |
| 7. Matching app release | Manually release the exact prebuilt artifact through Pages while database writes remain frozen. Verify served bytes/hashes for HTML, core JS, attendance JS and SW; force a fresh install/load on each inventoried device and confirm the matching bundle and fresh auth session. | Keep maintenance on; a failed or mixed asset release is not a successful cutover. Never automatically roll back to the original delete/reinsert client. |
| 8. Resume and contain | After new-client evidence and separate owner release approval, restore the captured grants exactly. This also allows direct REST writes again because the RPC is SECURITY INVOKER: no unidentified old writer may remain. Verify metadata and client read/error handling. The first ordinary owner-approved attendance save may then be checked with a separately authorized minimal read-only query; do not generate a production write probe. | On failure, reapply the table-write freeze, then use the existing RPC-containment rollback file. Keep data and request tokens. No automatic backup restore or uniqueness restoration. |

The release is a stopped-operator cutover. Database and Pages do not share a
transaction, and mixed versions are unsafe. Automatic steps are gated by owner
and integration evidence; **unattended execution is not currently available**.

### Exact future commands (not executed)

The production job must first run the approved preflight under the frozen-writer
condition. In PowerShell, with the approved PostgreSQL service already selected
by the owner outside the command/log:

```powershell
$preflightCsv = & psql -X -w -q --csv -t -v ON_ERROR_STOP=1 -f docs/database/meeting-attendance-preflight.sql
if ($LASTEXITCODE -ne 0 -or ($preflightCsv -join "`n").Trim() -ne '0,0,0,0,0,0') {
  throw 'Attendance preflight blocked: keep maintenance on; no migration'
}
# Separate approved owner job, after backup/integration/freeze evidence is verified:
& psql -X -w -v ON_ERROR_STOP=1 -f docs/database/meeting-attendance-review.sql
if ($LASTEXITCODE -ne 0) { throw 'Migration not confirmed; inspect catalogs before retry' }
```

The following temporary freeze is **review-only**, requires separate owner
approval, and must be tested in staging. It preserves row data and SELECT. It is
not included in the migration or executed by this task:

```sql
BEGIN;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON TABLE public.meetings, public.meeting_attendance FROM anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
```

Verify effective privileges with `has_table_privilege` rather than assuming a
REVOKE removed inherited/PUBLIC grants. Privileged jobs must still be paused. If
other grants supply writes, stop and request a narrowly reviewed fence; do not
silently revoke unrelated application access. No prefilled GRANT recovery command
is supplied: replay the captured, approved original grant set exactly, after the
new clients are verified. Restoring table grants before that point reopens the
old-client hole. The owner may instead approve a persistent server-side protocol
gate as a separate implementation; it is not part of the existing RPC.

## Owner authorizations still required

1. Read-only diagnosis is authorized and complete. No production data repair is
   required for the 122 verified legacy NULL dates. Any unrelated future data
   mutation remains separately authorized and reviewed.
2. Staging provisioning, migration/integration execution and isolated restore;
   production backup-status access, confidential backup export and recovery drill.
3. Temporary production write credentials, writer freeze/release, client-session
   retirement, the exact migration and any containment/rollback actions.
4. Protected GitHub release approval and eventual commit/push/deployment. This task
   grants none of these writes. Do not enable MCP writes as a shortcut.

## Rollback

- Before migration commit, any error must cause `ROLLBACK`; no partial DDL should
  remain. Abort cutover if SQL or schema-cache exposure fails.
- After commit, pause all clients. Approved containment SQL is in
  `meeting-attendance-rollback-review.sql`: disable RPC execution while retaining
  all rows and schema evidence. Do not simply redeploy the original destructive
  client. Use read-only operation until a corrected compatible bundle is ready.
- Once shared representatives have been saved, the old `(meeting_id,employee_id)`
  uniqueness constraint may be impossible to restore. The optional restoration
  block must first pass the aggregate preflight and remain a separate approval.
  Never delete attendance, restore a stale whole database over newer records,
  or null employee identifiers to force rollback.

## Validation limits and references

Local tests use synthetic RPC responses, not a running PostgreSQL/Supabase server.
All 57 local tests pass (the original 51 plus six legacy-date regressions). The migration, preflight, containment rollback and RPC
PL/pgSQL pass pglast 7.21's PostgreSQL 17.7 syntax parser (baseline server: 17.6).
SQL/PLpgSQL parser checks do not verify catalog binding, runtime permissions,
lock behavior, or PostgREST integration. These remain release blockers.

Official references: [Supabase backup/recovery](https://supabase.com/docs/guides/platform/backups),
[PostgreSQL 17 LOCK](https://www.postgresql.org/docs/17/sql-lock.html),
[PostgREST function cache requirements](https://postgrest.org/en/v12/references/api/functions.html),
[pglast parser API](https://pglast.readthedocs.io/en/latest/parser.html).
