-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE PUBLICATION "supabase_realtime" WITH (publish = 'insert, update, delete, truncate', publish_via_partition_root = false);
ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."employees";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."notifications";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."projects";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."todos";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_deliveries";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_delivery_bills";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_delivery_issues";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_delivery_items";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_items";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_order_employee_items";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_order_employees";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_order_postponements";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_requirement_reports";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_suppliers";
ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."uniform_supply_orders";

-- Managed Realtime message partitions/publication are inventoried in catalog.json,
-- not recreated. The application publication currently has all columns/no filters.
