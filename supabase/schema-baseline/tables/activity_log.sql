-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."activity_log" (
  "id" text DEFAULT (gen_random_uuid())::text NOT NULL,
  "user_id" uuid,
  "user_email" text,
  "action" text,
  "table_name" text,
  "record_ref" text,
  "detail" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
) USING "heap";
ALTER TABLE "public"."activity_log" OWNER TO "postgres";
