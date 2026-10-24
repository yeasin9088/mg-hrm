-- An explicit test already has its one target; keep the general Ready fan-out out.
BEGIN;
DO $$ DECLARE body text; BEGIN
 SELECT pg_get_functiondef('public.notification_test_device_push(bigint)'::regprocedure) INTO body;
 body:=replace(body,'''device_test'',p_subscription_id::text,''Ready''','''device_test'',p_subscription_id::text,''Delivered''');
 EXECUTE body;
END $$;
COMMIT;
