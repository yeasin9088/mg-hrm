# Local validation — 2026-10-20, Asia/Dhaka

- Read-only MCP catalog access confirmed transaction_read_only=on on PostgreSQL 17.6.
- Existing audit summaries were reused; missing structural DDL was extracted.
  All 72 cached original function bodies matched current catalog definition MD5s;
  unchanged bodies were not fetched again. Auth helper source was read as metadata.
- Reviewed SQL/defaults/comments and metadata before saving: no real Auth IDs,
  application rows, emails, JWTs, API keys or bearer credentials included. The
  all-zero UUID in notification_jobs_open_dedupe_uidx is a fixed SQL sentinel.
- Local generation and Node syntax checks passed without extra tooling.
- validate.mjs passed: 45 tables/729 columns; 238 constraints (62 FK targets);
  173 indexes (57 constraint-owned + 116 standalone); 35 identity sequences with
  exact decimal-string bigint bounds; 72 original function digests; 54 trigger
  definitions; 140 policy expressions; 15 publication member column lists.
- Generated SQL checksums and lexical quote/comment/dollar/parenthesis balance
  passed. Capture queries contain only SELECT catalog reads.
- Reference checks cover declared FK/trigger/policy/public function-source symbols.
  PostgreSQL 17 generated-column exclusion from publication lists was checked
  against pg_publication_rel: no explicit public column subsets or row filters.
- Regenerating all 64 SQL files and manifest produced zero differences.
- Completion fingerprints matched all 51 preexisting repository files: application,
  historical SQL, docs/database and security-staging remain unchanged. main is
  retained; no commit, push or deployment.

No PostgreSQL executable/parser, Docker or restore environment was found locally.
No SQL was run, no runtime routines/jobs were called, and no database/configuration
writes occurred. Lexical validation does not parse PL/pgSQL bodies or certify
type/name resolution, effective authorization, concurrency or restorability.
The baseline is ready as a development/debugging reference, not as an installer.
