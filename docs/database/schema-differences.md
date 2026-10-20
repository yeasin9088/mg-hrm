# Live schema versus repository

The live database is authoritative. Repository SQL is a historical, repeated `CREATE/ALTER/DROP` script and must not be executed as a schema snapshot.

## Table differences

Repository SQL defines 21 of the 45 live tables. The following 24 live tables have no `CREATE TABLE` definition in the inspected SQL files:

`todos`, `todos_backup_20260928`, `uniform_orders`, `uniform_order_items`, `uniform_order_allocations`, `uniform_suppliers`, `uniform_items`, `uniform_supply_orders`, `uniform_order_employees`, `uniform_order_employee_items`, `uniform_order_postponements`, `uniform_requirement_reports`, `uniform_deliveries`, `uniform_delivery_items`, `uniform_delivery_bills`, `uniform_delivery_issues`, `employee_reactivations`, `notification_events`, `notification_preferences`, `push_subscriptions`, `notification_escalation_rules`, `notifications`, `notification_deliveries`, `notification_jobs`.

No literal table used by `app-core.js` or `index.html` was absent from live metadata. Dynamic table variables were not statically resolvable.

## Confirmed column incompatibilities

| Object | Repository/application expectation | Live result | Impact |
|---|---|---|---|
| disciplinary | `description_bn` in setup SQL and `TABLE_MAP` | absent | Writes containing it can fail; Bangla description is dropped by compatibility fallback or unavailable. |
| meeting_attendance | `employee_sys_id` in setup SQL and `TABLE_MAP` | absent | Payloads containing it fail; no FK to employee master. |
| exits | setup SQL declares `exit_id` | absent | Historical SQL does not describe production. Application maps legacy ID to `id`. |
| employees | setup SQL adds `blood_group`, `division_id`, `district_id`, `upazila_id`, `union_id`, `spouse_name_bn`, `ec_name_bn`, `address`, `address_bn`, `thana` | absent | Re-running setup is unsafe and could create unused columns. |
| project_meeting_scope_history | repository trigger inserts `project_id`, `previous_state`, `new_state` | live columns are `project_record_id`, `previous_enabled`, `new_enabled` | Repository function/table definition is incompatible with production naming. |

Live-only evolution also includes extensive transfer/exit lifecycle fields, notification fields, uniform workflow state, soft-delete columns, checks and indexes that are missing from the repository snapshot.

## Constraints and integrity drift

- Repository SQL commonly specifies `ON DELETE CASCADE` for employee workflow FKs; inspected live FKs such as `career_employee_sys_id_fkey` and `disciplinary_employee_sys_id_fkey` use `ON DELETE RESTRICT`.
- Live `meeting_attendance` has no employee FK despite the repository declaration.
- Live `projects` and `employees` use textual project association; there is no FK from employees to projects. Renames and spelling drift remain possible.
- Geography reference tables have identifiers but no live FKs linking districts to divisions or thanas to districts.
- `todos_backup_20260928` lacks a primary key and all indexes.
- Production contains 173 indexes and extensive partial/unique workflow indexes not represented by the repository SQL.

## Trigger and policy drift

Production has 53 user triggers. Most updated-at, status lifecycle, notification and uniform integrity triggers have no repository definition. The setup SQL contains only a small subset, including join-date and meeting-scope history triggers.

Production has 140 RLS policies. Repository SQL does not represent the notification and modern uniform policy families, and its generic policy model does not capture the current live split between service-only notification tables and authenticated user-owned notification tables.

## RPC reconciliation

All three literal application RPC dependencies exist in production:

- `commit_transfer(jsonb, boolean)` referenced by `index.html`.
- `save_uniform_delivery(...)` referenced by `app-core.js`.
- `push_subscription_list_devices()` referenced by `app-core.js`.

Their definitions are absent from the inspected repository SQL, so a clean environment built from the repository cannot supply these application dependencies.

## Migration history

Only `20260916135500 init` and `20260916140800 fix_schema` are registered. The repository hotfix and meeting-scope files are not represented as named migrations, and the large notification/uniform evolution cannot be reconstructed from repository SQL plus registered history. Manual SQL execution may explain the gap but cannot be proven from metadata.

## Source references

- Base definitions: `supabase_setup.sql` (tables start near lines 19, 179 and 298).
- Employee hotfix: `employee_address_join_date_hotfix.sql`.
- Meeting scope migration: `project_meeting_attendance_scope_migration.sql`.
- Application mapping: `app-core.js` (`TABLE_MAP` starts near line 9; RPC calls near lines 1563 and 2302).
- Transfer RPC call: `index.html` near line 11154.

## Limitations

Repeated and conditional DDL means the final state implied by running historical files is not deterministic against an unknown starting schema. This report compares explicit declarations and application expectations to verified production metadata; it does not certify the SQL files as replayable.
