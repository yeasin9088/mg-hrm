# Notification database reference

This guide describes captured definitions, not live job execution or a new design.
Read the SQL bodies for exact predicates, return shapes, errors and transaction
behavior. No notification rows, subscription endpoints or encryption values were read.

## Pipeline and source files

| Stage | Captured objects | Definition location |
|---|---|---|
| Business event input | notification_events; event_key idempotency and lifecycle | tables/notification_events.sql; constraints/indexes; trigger helpers |
| Server queue | notification_jobs; claims, stale-lock recovery, retry/finalization | tables/notification_jobs.sql; functions/notifications-service.sql |
| Event processing | notification_run_event_processor → enqueue/claim/process event jobs | functions/notifications-service.sql |
| Recipient inbox | notifications; dedupe, ownership, state/timestamps/actions | tables/notifications.sql; functions/notifications-user.sql |
| Recurrence/escalation | notification_run_recurrence; notification_escalation_rules; source checks | tables/notification_escalation_rules.sql; service functions |
| Delivery preparation | notification_prepare_deliveries; notification_deliveries | tables/notification_deliveries.sql; service functions |
| Web Push dispatch | claim_web_push_jobs/get_web_push_dispatch/record_web_push_result/finalize_web_push_job (all notification_ prefixed) | service functions; push_subscriptions table |
| User preferences | notification_preferences; effective_preference/next_allowed_at | tables/notification_preferences.sql; service functions |
| Device management | push_subscription_register/list_devices/revoke/update_device | functions/notifications-user.sql |
| Health/maintenance | notification_operations_health/maintenance; cron_tick | functions/notifications-service.sql |

The original notification_cron_tick() invokes notification_run_server_processor(),
whose body explicitly sequences event processing, recurrence, then delivery
preparation. A Web Push sender must separately claim/dispatch/finalize work;
its external HTTP/Edge implementation and actual cron command/configuration are
not reconstructed from PostgreSQL catalogs.

The SQL reference does not assume that every HR edit automatically inserts an
event. Captured source triggers and RPC bodies show their actual behavior;
event-producer application/worker code requires separate inspection if relevant.

## Relationships and authorization

All notification FKs, checks, partial/unique indexes and trigger lifecycle rules
are in 04/05/06/07 SQL files. Use catalog.json for FK column mappings and full
dependency edges. Preserve the deployed differences between service-only
notification_events/jobs and owned inbox/preferences/device operations.

09-privileges.sql records actual EXECUTE/table grants; 08-rls-policies.sql records
actual ownership/role predicates. Function SECURITY DEFINER/INVOKER modes,
search paths and active-profile/subject checks are preserved as deployed;
they must be read individually rather than inferred from a shared function name.
No staged operator guard has been added to this baseline.

push_subscription_list_devices returns a declared safe metadata shape. Subscription
schema includes endpoint/p256dh_key/auth_key column definitions, never their values.
Lifecycle triggers are grouped in functions/triggers-and-helpers.sql and attached
in 07-triggers.sql. Source-resolution helpers inspect existing To-Do, transfer,
exit, leave and modern Uniform state according to their captured bodies.

## Realtime and Uniform

notifications is an application Realtime publication member. All 15 public members
are recorded in 11-publications.sql; transfers/meetings are not added speculatively.

Modern Uniform DDL includes allocations/replacements, stored generated shirt/pant
quantities, reports, deliveries, bills/issues and terminal-state validators. In
PostgreSQL 17, the implicit publication columns omit stored generated columns:
uniform_order_employees.shirt_quantity/pant_quantity remain table columns, while
the verified publication binding has no explicit column subset or row filter.
Legacy uniform_orders/order_items/order_allocations are retained as deployed.

## Available evidence and gaps

Database definitions are sufficient to inspect contracts and trace database-side
notification logic now. Data-dependent failures, running cron schedules, deployed
sender source, provider responses and browser behavior are not established by this
baseline. No debugging, remediation, job invocation or feature change was performed.
