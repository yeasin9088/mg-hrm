-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."recruitment_archive" (
  "archive_id" text NOT NULL,
  "candidate_name" text,
  "designation" text,
  "project_name" text,
  "result" text,
  "employee_id" text,
  "decided_at" timestamp with time zone DEFAULT now() NOT NULL,
  "notes" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "system_id" text,
  "deleted_at" timestamp with time zone,
  "deleted_by" uuid
) USING "heap";
ALTER TABLE "public"."recruitment_archive" OWNER TO "postgres";
