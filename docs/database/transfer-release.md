# Transfer date and Realtime release

Deployed on 2026-10-21 (Asia/Dhaka) to the authorized Supabase PostgreSQL 17.6
database with `transfer-date-realtime-forward.sql`. The file ran once as a single
transaction after its production preflight passed. The rollback is retained in
`transfer-date-realtime-rollback.sql` and was tested on an isolated restore.

## Recovery and validation

- Fresh backup ID: `transfer-20261021T091832Z`. A scoped custom-format dump of
  `employees`, `transfers`, and `activity_log` stores schema and data as Windows
  DPAPI CurrentUser encrypted files outside the repository. Both encrypted and
  decrypted SHA-256 values passed round-trip checks. Recovery evidence and the
  encrypted files remain in the protected local release-backups directory.
- The backup was decrypted in memory and restored into a separate loopback-only
  PostgreSQL 18.6 database. Restored full-row digests matched production immediately
  before migration: 600 employees, 202 transfers, and 175 activity-log rows.
- On an isolated clone, the forward change, synthetic Transfer database cases,
  rollback, and full-row history preservation passed. PostgreSQL 18 renders
  function definitions differently from PostgreSQL 17, so only the expected
  preflight definition hashes were adapted for this local test. The production
  script and its PostgreSQL 17 hashes were unchanged.
- After production commit, all five RPCs have `TimeZone=Asia/Dhaka`; their bodies,
  `SECURITY INVOKER` setting and ACLs are unchanged. `transfers` is the sole new
  member of `supabase_realtime`, with default replica identity and no column
  filter. Employee/transfer/activity-log row digests, employee project assignments,
  table RLS policies and privileges match the pre-migration snapshot.

The local database test does not simulate signed JWT authentication or delivery
of a live Realtime event to a browser. It verifies database metadata and
transaction behavior for this scoped release.
