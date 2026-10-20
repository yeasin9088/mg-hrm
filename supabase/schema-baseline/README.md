# MG-HRM current schema baseline

Captured **2026-10-20 (Asia/Dhaka)** from Supabase project
`enkggoozsvvkgbjeghbf`, PostgreSQL **17.6**, using read-only catalogs.
This is the deployed database reference for feature development and debugging.
Meeting Attendance objects were refreshed from deployed catalogs on **2026-10-21**
after the approved atomic migration; other objects retain the original capture date.
It contains current definitions, including existing grants/policies; no proposed
security changes are mixed in. It is **not a migration or a tested restore script**.

## Coverage and entry points

| Area | Verified coverage | Files |
|---|---:|---|
| Application schema | public; no additional custom application schema found | 00-schemas.sql |
| Tables and columns | 45 tables, 730 columns, defaults/nullability/generated expressions | tables/*.sql |
| Identity sequences | 35; exact start/increment/bounds/cache/cycle/ownership | table identity clauses; 02-sequences.sql; 03-sequence-ownership.sql |
| Constraints | 44 PK, 62 FK, 12 unique, 119 check | 04-constraints.sql; 05-foreign-keys.sql |
| Indexes | 174: 56 created by constraints, 118 standalone | 06-indexes.sql |
| Routines | 73 deployed bodies/signatures/options, including 41 definers | functions/*.sql |
| Triggers | 53 public plus Auth-to-profile provisioning trigger | 07-triggers.sql |
| RLS | all 45 tables; 140 complete deployed policies | 08-rls-policies.sql |
| Privileges | public schema/table/sequence/routine ACLs and six public default ACLs | 09-privileges.sql; 10-default-privileges.sql |
| Realtime | 15 application members and publication settings | 11-publications.sql |
| Platform dependencies | seven extensions; Auth helpers/keys, cron interfaces, managed roles/publication inventory | platform/; catalog.json |

No standalone application enum/domain/range/composite/base types or application
views/materialized views were found. Table row types/arrays are implicit.
Comments, owners, trigger enabled state and relevant relation options are retained.
There are no employee rows, Auth accounts, sequence current values or credentials.
The all-zero UUID in a notification dedupe index is a verified fixed sentinel.

Use [manifest.json](manifest.json) to locate tables/functions and verify SQL
checksums. [catalog.json](catalog.json) retains reviewed metadata, relationships,
grantors/grant options, platform contracts and 1,655 declarative dependency edges.
[NOTIFICATIONS.md](NOTIFICATIONS.md) maps the database notification pipeline.

## Dependency order

For understanding or preparing a separately reviewed scratch reconstruction:
platform prerequisites/roles → public schema/types → standalone sequences →
all tables (identity sequences are created inline) → sequence ownership →
PK/unique/check constraints → FKs → standalone indexes → application functions →
triggers → policies → object grants/default privileges → publication membership.

Do not concatenate and run these files on production. Supabase already provides
public, Auth, roles, extensions and publications. Platform SQL is reference-only.
Constraint-backed indexes are represented by their owning constraints rather than
duplicate CREATE INDEX statements. All 35 current sequences are identity-owned.
Functions precede policies because policies use my_role(); the Auth trigger needs
public.handle_new_user() and the managed auth.users table. Functions refer to
application table row types and one another; SQL bodies are retained verbatim,
and an untested alphabetical file order is not a promise of successful replay.

## Historical SQL differences

The old [supabase_setup.sql](../../supabase_setup.sql) represents only 21 of the
45 tables and contains repeated, incompatible DDL. Notification tables/processors,
modern Uniform workflows, employee reactivations and several application RPCs
were missing there. Legacy Uniform tables still coexist with the modern model.

Examples of actual deployed differences: disciplinary.description_bn and
meeting_attendance.employee_sys_id are absent; project-meeting audit uses
project_record_id/previous_enabled/new_enabled; employee project association is
textual rather than a project FK. See the existing
[schema differences](../../docs/database/schema-differences.md) and
[live inventory](../../docs/database/live-schema-inventory.md). Historical SQL and
all security-staging artifacts are preserved; neither is a baseline source of DDL.

## Refresh and future changes

1. Record future changes as separate reviewed, versioned migration scripts.
2. After an authorized change is deployed, refresh affected catalog metadata using
   the SELECT-only recipes in capture/catalog.sql. Reuse unchanged function bodies
   only after matching their current md5(pg_get_functiondef(...)) values.
3. Review defaults/comments/bodies for secrets or personal literals before saving
   catalog.json. Do not export scheduler headers, Auth/application rows or secrets.
4. Run generate.mjs, then validate.mjs; review the SQL/manifest diff with the
   corresponding migration. Remove obsolete generated objects as a reviewed diff.
   Generated SQL is derived from catalog.json; do not silently edit it alone.

Local commands (no database/network access):

    node supabase/schema-baseline/generate.mjs
    node supabase/schema-baseline/validate.mjs

## Limits

No PostgreSQL parser/server/psql was available, and no SQL was executed. Local
checks verify source hashes, coverage, references and lexical balance, not runtime
PL/pgSQL resolution or successful restoration. Catalog reads used multiple
read-only statements rather than one exported pg_dump transaction snapshot.

Platform-owned Auth/Storage/Realtime/Vault/extension schemas are dependencies,
not a complete infrastructure dump. Scheduled cron commands, deployed Edge code,
Auth/provider/PostgREST settings, data and secret values are excluded. Catalog
pg_depend does not resolve every PL/pgSQL body call; source-reference checks are
supplementary. Sequence counters and dropped-column physical slots are not restored.

Codex can now start Notification database debugging from this baseline.
Sender/Edge failures may additionally require deployed source or runtime evidence;
those omissions do not block using the captured database definitions for development.
