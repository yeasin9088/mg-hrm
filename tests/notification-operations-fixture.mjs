import fs from 'node:fs';
import {setup as workflow} from './notification-workflow-fixture.mjs';
export async function setup(db){
 await workflow(db);
 await db.exec(`ALTER TABLE public.notification_jobs ADD COLUMN started_at timestamptz,ADD COLUMN completed_at timestamptz,ADD COLUMN failed_at timestamptz,ADD COLUMN last_error text;
 CREATE SCHEMA cron;
 CREATE TABLE cron.job(jobid bigint,jobname text,active boolean);
 CREATE TABLE cron.job_run_details(jobid bigint,start_time timestamptz,end_time timestamptz,status text);
 INSERT INTO cron.job VALUES(1,'notification-server-processor',true),(2,'notification-web-push-sender',true),(3,'notification-operations-maintenance',true);
 INSERT INTO cron.job_run_details SELECT jobid,now(),now(),'succeeded' FROM cron.job;
 INSERT INTO public.push_subscriptions(id,user_id,is_active,permission_state,endpoint,p256dh_key,auth_key)
 SELECT n,'11111111-1111-4111-8111-111111111111',true,'granted','https://synthetic.invalid/'||n,'synthetic','synthetic' FROM generate_series(1,4)n;`);
 await db.exec(fs.readFileSync('tests/fixtures/notification-operations-live-2026-10-23.sql','utf8'));
 // ACLs read back from production alongside the function capture.
 for(const signature of ['notification_claim_jobs(text,integer)','notification_claim_web_push_jobs(text,integer)','notification_complete_job(bigint,text)','notification_fail_job(bigint,text,text,interval)','notification_finalize_web_push_job(bigint,text,interval)','notification_operations_health()','notification_get_web_push_dispatch(bigint,text)','notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean)'])await db.exec(`REVOKE ALL ON FUNCTION public.${signature} FROM PUBLIC,anon,authenticated,service_role; GRANT EXECUTE ON FUNCTION public.${signature} TO service_role;`);
}
