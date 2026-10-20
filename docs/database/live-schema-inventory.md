# Production live schema inventory

Audit date: 2026-10-20 (Asia/Dhaka)
Project: `enkggoozsvvkgbjeghbf`
Source: read-only Supabase MCP catalog queries (`pg_catalog` and `information_schema`)

This is an inspection artifact, not executable SQL. No application rows or Auth records were queried.

## Scope and totals

- `public` tables: 45; all report RLS enabled.
- Indexes: 173; sequences: 35.
- Public functions: 72; `SECURITY DEFINER`: 41.
- RLS policies: 140.
- User triggers: 53.
- Public views, materialized views, enums/domains/ranges: none found.
- Realtime publication members: 15.
- Migration records: `20260916135500 init`, `20260916140800 fix_schema`.

## Relational object matrix

Counts are catalog verified. `C/PK/FK/UQ/CK/I/TR` means columns, primary keys, foreign keys, unique constraints, check constraints, indexes and user triggers.

| Table | C/PK/FK/UQ/CK/I/TR |
|---|---|
| activity_log | 8/1/0/0/0/2/0 |
| app_settings | 5/1/0/0/0/2/1 |
| career | 18/1/1/1/0/4/1 |
| demand | 11/1/0/1/0/3/1 |
| designations | 3/1/0/0/0/1/0 |
| disciplinary | 22/1/1/0/0/4/1 |
| districts | 3/1/0/0/0/1/0 |
| divisions | 2/1/0/0/0/1/0 |
| employee_join_date_history | 6/1/1/0/0/2/0 |
| employee_reactivations | 12/1/2/0/0/2/0 |
| employees | 62/1/0/0/1/6/4 |
| exits | 24/1/2/0/1/7/1 |
| leaves | 19/1/1/1/0/4/1 |
| meeting_attendance | 14/1/0/1/0/4/1 |
| meetings | 15/1/0/1/0/3/1 |
| notification_deliveries | 16/1/2/0/8/6/0 |
| notification_escalation_rules | 18/1/3/0/12/5/1 |
| notification_events | 15/1/3/0/6/6/2 |
| notification_jobs | 17/1/2/0/11/7/2 |
| notification_preferences | 18/1/1/0/6/3/1 |
| notifications | 33/1/6/0/15/10/2 |
| profiles | 8/1/1/0/0/1/1 |
| project_meeting_scope_history | 6/1/0/0/0/2/0 |
| projects | 26/1/0/1/0/4/2 |
| push_subscriptions | 19/1/1/0/8/4/2 |
| recruitment_archive | 13/1/0/0/0/3/1 |
| thanas | 3/1/0/0/0/1/0 |
| todos | 28/1/2/0/0/9/1 |
| todos_backup_20260928 | 21/0/0/0/0/0/0 |
| transfers | 38/1/1/0/2/6/1 |
| uniform | 25/1/5/1/0/6/1 |
| uniform_deliveries | 9/1/1/1/3/3/2 |
| uniform_delivery_bills | 14/1/2/1/5/4/3 |
| uniform_delivery_issues | 16/1/4/0/5/3/2 |
| uniform_delivery_items | 11/1/3/0/3/3/1 |
| uniform_items | 9/1/0/0/3/3/1 |
| uniform_order_allocations | 17/1/3/1/2/6/1 |
| uniform_order_employee_items | 11/1/2/0/4/3/2 |
| uniform_order_employees | 19/1/5/0/2/4/3 |
| uniform_order_items | 9/1/1/1/3/3/1 |
| uniform_order_postponements | 9/1/1/0/3/2/1 |
| uniform_orders | 33/1/0/1/3/8/1 |
| uniform_requirement_reports | 12/1/3/0/3/4/1 |
| uniform_suppliers | 8/1/0/0/1/3/1 |
| uniform_supply_orders | 24/1/2/1/9/5/4 |

## Important verified definitions

- `employees` contains identity `id`, personal/contact fields, `salary numeric`, lifecycle timestamps, soft-delete fields and 62 columns total. It has no FK to `projects`; project association is textual through `project_name`.
- `career` stores `previous_salary`, `increment_amount` and `new_salary` and references `employees(id)` with `ON DELETE RESTRICT`.
- Core employee workflow tables (`disciplinary`, `exits`, `transfers`, `leaves`, `uniform`) reference `employees(id)`; current FKs use restrictive deletion where inspected.
- Notification tables have extensive FK/check/index coverage. `notifications` has six FKs, 15 checks and ten indexes.
- The newer uniform workflow has strong checks and terminal-state triggers. The older `uniform_orders`, `uniform_order_items`, and `uniform_order_allocations` coexist with the newer `uniform_supply_orders` family.
- `todos_backup_20260928` is the only public table without a primary key or index.

## Functions and RPCs

Application RPC dependencies are present:

- `commit_transfer(jsonb, boolean)` — invoker, authenticated and anon EXECUTE grant.
- `save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb)` — invoker, authenticated and anon EXECUTE grant.
- `push_subscription_list_devices()` — definer, authenticated only; checks `auth.uid()` and active profile and returns only that user's devices.

Workflow RPCs also include transfer, exit, reactivation and notification lifecycle operations. Forty-one functions are definer functions; notification server functions generally deny `anon` and `authenticated`, while user notification actions are granted to `authenticated`.

## Triggers

Verified trigger families include updated-at triggers, employee status normalization, transfer cancellation on employee inactivity, join-date audit history, project meeting-scope history, profile-field protection, notification lifecycle enforcement, push-subscription lifecycle enforcement, and uniform integrity/terminal-state validation.

## Realtime

`supabase_realtime` includes: `employees`, `projects`, `todos`, `notifications`, and eleven newer uniform tables (`uniform_supply_orders`, suppliers/items, employee requirements, reports, deliveries, delivery items/bills/issues, and postponements). Meeting and transfer tables are not members in the catalog result.

## Limitations

Catalog definitions were inspected, but application data and Auth rows were deliberately excluded. Effective behavior under distinct JWT claims was not tested. Identity sequences exist in `pg_class` (35); `information_schema.sequences` did not expose rows to this inspection role.
