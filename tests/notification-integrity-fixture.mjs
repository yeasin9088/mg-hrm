import fs from 'node:fs';
const read=p=>fs.readFileSync(p,'utf8');
const migration='supabase/migrations/20261023081545_notification_phase6_dispatch_integrity.sql';
export async function setup(db){
 for(const file of [
 'scripts/notification-core-ci-fixtures.sql',
 'supabase/migrations/20261023180000_notification_core_decision_contract.sql',
 'scripts/notification-core-phase2-fixtures.sql',
 'supabase/migrations/20261023190000_notification_core_policy_phase2.sql',
 'scripts/notification-phase3-ci-fixtures.sql',
 'supabase/migrations/20261023200000_notification_digest_scheduler_phase3.sql',
 'scripts/notification-phase4-ci-fixtures.sql',
 'supabase/migrations/20261023210000_notification_digest_event_bridge_phase4.sql',
 'supabase/migrations/20261023213000_notification_processor_bridge_phase4.sql',
 'supabase/migrations/20261023214500_notification_digest_event_guard_phase4.sql',
 'supabase/migrations/20261023220000_notification_operator_settings_api_phase5.sql',
 'supabase/migrations/20261023221000_notification_digest_settings_enforcement_phase5.sql',
 'supabase/migrations/20261023230000_notification_configurable_digest_window_phase6.sql']) await db.exec(read(file));
 await db.exec(`
 ALTER TABLE public.notification_deliveries ADD COLUMN failed_at timestamptz,ADD COLUMN error_code text,
 ADD COLUMN error_message text,ADD COLUMN provider_message_id text;
 ALTER TABLE public.push_subscriptions ADD COLUMN failure_count integer DEFAULT 0,ADD COLUMN last_failure_at timestamptz,
 ADD COLUMN last_success_at timestamptz;
 CREATE FUNCTION public.notification_operations_health() RETURNS jsonb LANGUAGE sql AS $$SELECT '{"fixture":true}'::jsonb$$;
 CREATE TABLE public.transfers(id bigint,status text,deleted_at timestamptz,effective_date date,joining_confirmed_at timestamptz,
  not_joined_at timestamptz,cancelled_at timestamptz,completed_at timestamptz);
 CREATE TABLE public.leaves(id bigint,status text,deleted_at timestamptz);
 CREATE TABLE public.exits(id bigint,status text,deleted_at timestamptz);
 CREATE TABLE public.disciplinary(id bigint,action_type text,deleted_at timestamptz);
 CREATE TABLE public.meetings(id bigint,deleted_at timestamptz);
 CREATE TABLE public.uniform_supply_orders(id bigint,status text);
 CREATE TABLE public.uniform_delivery_issues(id bigint,resolution_status text);
 CREATE TABLE public.uniform_delivery_bills(id bigint,paid boolean);
 CREATE TABLE public.recruitment_archive(archive_id text,result text,deleted_at timestamptz);
 INSERT INTO public.transfers VALUES(1,'Joining Pending',null,current_date,null,null,null,null);
 INSERT INTO public.leaves VALUES(1,'Pending',null);
 INSERT INTO public.exits VALUES(1,'Draft',null);
 INSERT INTO public.disciplinary VALUES(1,'Show Cause Notice',null);
 INSERT INTO public.meetings VALUES(1,null);
 INSERT INTO public.uniform_supply_orders VALUES(1,'Open');
 INSERT INTO public.uniform_delivery_issues VALUES(1,'Open');
 INSERT INTO public.uniform_delivery_bills VALUES(1,false);
 INSERT INTO public.recruitment_archive VALUES('candidate-1','pending',null);
 `);
 await db.exec(read(migration));
}
