-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TABLE "public"."notifications" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "event_id" bigint,
  "recipient_user_id" uuid NOT NULL,
  "category" text NOT NULL,
  "severity" text DEFAULT 'Info'::text NOT NULL,
  "priority" text DEFAULT 'Normal'::text NOT NULL,
  "title" text NOT NULL,
  "message" text NOT NULL,
  "entity_type" text,
  "entity_id" text,
  "employee_sys_id" bigint,
  "project_id" bigint,
  "action_label" text,
  "action_route" text,
  "action_params" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "status" text DEFAULT 'Scheduled'::text NOT NULL,
  "scheduled_for" timestamp with time zone DEFAULT now() NOT NULL,
  "expires_at" timestamp with time zone,
  "first_delivered_at" timestamp with time zone,
  "last_delivered_at" timestamp with time zone,
  "read_at" timestamp with time zone,
  "opened_at" timestamp with time zone,
  "actioned_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "dismissed_at" timestamp with time zone,
  "snoozed_until" timestamp with time zone,
  "dedupe_key" text NOT NULL,
  "repeat_count" integer DEFAULT 0 NOT NULL,
  "escalation_level" integer DEFAULT 0 NOT NULL,
  "parent_notification_id" uuid,
  "escalation_rule_id" bigint,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
) USING "heap";
ALTER TABLE "public"."notifications" OWNER TO "postgres";
COMMENT ON TABLE "public"."notifications" IS 'Authoritative per-user Notification Inbox records and actionable reminder lifecycle.';
COMMENT ON COLUMN "public"."notifications"."recipient_user_id" IS 'Authenticated profile that owns this notification and its read/action state.';
COMMENT ON COLUMN "public"."notifications"."action_params" IS 'Structured deep-link and action context. Sensitive secrets must not be stored here.';
COMMENT ON COLUMN "public"."notifications"."status" IS 'Scheduled, Ready, Delivered, Read, Actioned, Snoozed, Completed, Dismissed, Expired, Cancelled or Failed.';
COMMENT ON COLUMN "public"."notifications"."dedupe_key" IS 'Stable per-workflow key used with recipient ownership to prevent duplicate open notifications.';
COMMENT ON COLUMN "public"."notifications"."parent_notification_id" IS 'Original notification when this row is an escalation or controlled follow-up.';
