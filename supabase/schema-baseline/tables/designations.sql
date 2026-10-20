-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."designations" (
  "desig_id" integer NOT NULL,
  "designation" text NOT NULL,
  "designation_bn" text
) USING "heap";
ALTER TABLE "public"."designations" OWNER TO "postgres";
