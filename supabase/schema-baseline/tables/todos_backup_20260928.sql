-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."todos_backup_20260928" (
  "id" bigint,
  "project" text,
  "who" text,
  "note" text,
  "date" date,
  "status" text,
  "source" text,
  "sourceDate" date,
  "created_at" timestamp with time zone,
  "deleted_at" timestamp with time zone,
  "deleted_by" uuid,
  "updated_at" timestamp with time zone,
  "is_important" boolean,
  "remind_on" date,
  "category" text,
  "priority" text,
  "manager_status" text,
  "manager_note" text,
  "note_bn" text,
  "solved_at" timestamp with time zone,
  "extra_notes" jsonb
) USING "heap";
ALTER TABLE "public"."todos_backup_20260928" OWNER TO "postgres";
