-- Additional Phase 2 test-only history. Run after Phase 1 synthetic fixtures.
CREATE TABLE public.notification_deliveries(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 notification_id uuid NOT NULL,channel text,delivery_status text,
 sent_at timestamptz,delivered_at timestamptz,attempted_at timestamptz
);
