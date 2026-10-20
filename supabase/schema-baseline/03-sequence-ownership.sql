-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

ALTER SEQUENCE "public"."career_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."demand_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."disciplinary_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."employee_join_date_history_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."employee_reactivations_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."employees_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."exits_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."leaves_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."meeting_attendance_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."meetings_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notification_deliveries_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notification_escalation_rules_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notification_events_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notification_jobs_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notification_preferences_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."project_meeting_scope_history_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."projects_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."push_subscriptions_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."todos_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."transfers_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_deliveries_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_delivery_bills_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_delivery_issues_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_delivery_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_order_allocations_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_order_employee_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_order_employees_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_order_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_order_postponements_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_orders_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_requirement_reports_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_suppliers_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."uniform_supply_orders_id_seq" OWNER TO "postgres";
