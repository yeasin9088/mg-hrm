-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."notification_legacy_states" (
  "user_id" uuid NOT NULL,
  "event_key" text NOT NULL,
  "status" text NOT NULL,
  "read_at" timestamp with time zone,
  "snoozed_until" timestamp with time zone,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
) USING "heap";
ALTER TABLE "public"."notification_legacy_states" OWNER TO "postgres";
COMMENT ON TABLE "public"."notification_legacy_states" IS 'Owned read/dismiss/snooze state for stable legacy business-event identities; no employee/message contents.';
