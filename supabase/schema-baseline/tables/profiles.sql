-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."profiles" (
  "id" uuid NOT NULL,
  "email" text,
  "full_name" text,
  "role" text DEFAULT 'viewer'::text NOT NULL,
  "project_scope" text,
  "is_active" boolean DEFAULT true NOT NULL,
  "last_login" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
) USING "heap";
ALTER TABLE "public"."profiles" OWNER TO "postgres";
