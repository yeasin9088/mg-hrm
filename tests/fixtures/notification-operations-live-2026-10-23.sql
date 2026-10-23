-- Six production function definitions captured read-only on 2026-10-23.
-- Test fixtures only; never applied to production.
CREATE OR REPLACE FUNCTION public.notification_claim_jobs(p_worker_id text, p_batch_size integer DEFAULT 20)
 RETURNS SETOF notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  if length(btrim(p_worker_id)) > 200 then
    raise exception 'Worker ID cannot exceed 200 characters';
  end if;

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 100 then
    raise exception 'Batch size must be between 1 and 100';
  end if;

  return query
  with claimable as (
    select j.id
    from public.notification_jobs j
    where j.job_status in ('Pending', 'Failed')
      and j.run_at <= clock_timestamp()
      and j.attempt_count < j.maximum_attempts
    order by j.run_at, j.id
    limit p_batch_size
    for update skip locked
  )
  update public.notification_jobs j
  set
    job_status = 'Processing',
    attempt_count = j.attempt_count + 1,
    locked_at = clock_timestamp(),
    locked_by = btrim(p_worker_id),
    started_at = clock_timestamp(),
    completed_at = null,
    failed_at = null,
    last_error = null
  from claimable c
  where j.id = c.id
  returning j.*;
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_claim_web_push_jobs(p_worker_id text, p_batch_size integer DEFAULT 10)
 RETURNS SETOF notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if length(btrim(p_worker_id)) > 200 then
    raise exception
      'Worker ID cannot exceed 200 characters';
  end if;

  if p_batch_size is null
     or p_batch_size < 1
     or p_batch_size > 25 then
    raise exception
      'Batch size must be between 1 and 25';
  end if;

  return query
  with claimable as (
    select job_row.id
    from public.notification_jobs job_row
    where job_row.job_type =
      'DeliverWebPush'
      and job_row.job_status in (
        'Pending',
        'Failed'
      )
      and job_row.run_at <=
        clock_timestamp()
      and job_row.attempt_count <
        job_row.maximum_attempts
    order by
      job_row.run_at,
      job_row.id
    limit p_batch_size
    for update skip locked
  )
  update public.notification_jobs job_row
  set
    job_status = 'Processing',
    attempt_count =
      job_row.attempt_count + 1,
    locked_at = clock_timestamp(),
    locked_by = btrim(p_worker_id),
    started_at = clock_timestamp(),
    completed_at = null,
    failed_at = null,
    last_error = null
  from claimable claim_row
  where job_row.id = claim_row.id
  returning job_row.*;
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_complete_job(p_job_id bigint, p_worker_id text)
 RETURNS notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  update public.notification_jobs
  set
    job_status = 'Completed',
    completed_at = clock_timestamp(),
    failed_at = null,
    last_error = null,
    locked_at = null,
    locked_by = null
  where id = p_job_id
    and job_status = 'Processing'
    and locked_by = btrim(p_worker_id)
  returning *
  into v_job;

  if v_job.id is null then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  return v_job;
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_fail_job(p_job_id bigint, p_worker_id text, p_error text, p_retry_after interval DEFAULT '00:05:00'::interval)
 RETURNS notification_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs;
begin
  if p_job_id is null then
    raise exception 'Job ID is required';
  end if;

  if nullif(btrim(coalesce(p_worker_id, '')), '') is null then
    raise exception 'Worker ID is required';
  end if;

  if nullif(btrim(coalesce(p_error, '')), '') is null then
    raise exception 'Failure diagnostics are required';
  end if;

  if p_retry_after is null
     or p_retry_after < interval '1 minute'
     or p_retry_after > interval '24 hours' then
    raise exception
      'Retry interval must be between 1 minute and 24 hours';
  end if;

  update public.notification_jobs
  set
    job_status = case
      when attempt_count >= maximum_attempts
        then 'DeadLetter'
      else 'Failed'
    end,
    run_at = case
      when attempt_count >= maximum_attempts
        then run_at
      else clock_timestamp() + p_retry_after
    end,
    failed_at = clock_timestamp(),
    completed_at = null,
    last_error = left(btrim(p_error), 4000),
    locked_at = null,
    locked_by = null
  where id = p_job_id
    and job_status = 'Processing'
    and locked_by = btrim(p_worker_id)
  returning *
  into v_job;

  if v_job.id is null then
    raise exception
      'Job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  return v_job;
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_finalize_web_push_job(p_job_id bigint, p_worker_id text, p_retry_after interval DEFAULT '00:05:00'::interval)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_job public.notification_jobs%rowtype;
  v_pending integer := 0;
  v_failed integer := 0;
  v_sent integer := 0;
  v_result public.notification_jobs%rowtype;
begin
  if p_job_id is null then
    raise exception
      'Job ID is required';
  end if;

  if nullif(
    btrim(coalesce(p_worker_id, '')),
    ''
  ) is null then
    raise exception
      'Worker ID is required';
  end if;

  if p_retry_after is null
     or p_retry_after <
        interval '1 minute'
     or p_retry_after >
        interval '24 hours' then
    raise exception
      'Retry interval must be between 1 minute and 24 hours';
  end if;

  select job_row.*
  into v_job
  from public.notification_jobs job_row
  where job_row.id = p_job_id
    and job_row.job_type =
      'DeliverWebPush'
    and job_row.job_status =
      'Processing'
    and job_row.locked_by =
      btrim(p_worker_id);

  if not found then
    raise exception
      'Web Push job % is not Processing or is not owned by worker %',
      p_job_id,
      btrim(p_worker_id);
  end if;

  select
    count(*) filter (
      where delivery_status in (
        'Pending',
        'Processing'
      )
    ),
    count(*) filter (
      where delivery_status =
        'Failed'
    ),
    count(*) filter (
      where delivery_status in (
        'Sent',
        'Delivered'
      )
    )
  into
    v_pending,
    v_failed,
    v_sent
  from public.notification_deliveries
  where notification_id =
        v_job.notification_id
    and channel = 'WebPush';

  if v_pending > 0 then
    raise exception
      'Web Push job % still has % unfinished deliveries',
      p_job_id,
      v_pending;
  end if;

  if v_failed > 0 then
    v_result :=
      public.notification_fail_job(
        p_job_id,
        p_worker_id,
        format(
          '%s Web Push delivery attempt(s) failed; %s accepted',
          v_failed,
          v_sent
        ),
        p_retry_after
      );
  else
    v_result :=
      public.notification_complete_job(
        p_job_id,
        p_worker_id
      );
  end if;

  return jsonb_build_object(
    'job_id',
      v_result.id,
    'job_status',
      v_result.job_status,
    'attempt_count',
      v_result.attempt_count,
    'maximum_attempts',
      v_result.maximum_attempts,
    'sent_deliveries',
      v_sent,
    'failed_deliveries',
      v_failed,
    'pending_deliveries',
      v_pending,
    'run_at',
      v_result.run_at
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.notification_operations_health()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'cron'
AS $function$
declare
  v_overdue_jobs bigint := 0;
  v_failed_jobs bigint := 0;
  v_deadletter_jobs bigint := 0;
  v_stale_jobs bigint := 0;

  v_unfinished_push bigint := 0;
  v_failed_push bigint := 0;
  v_successful_push bigint := 0;

  v_active_subscriptions bigint := 0;
  v_subscription_failures bigint := 0;
  v_unhealthy_subscriptions bigint := 0;
  v_inactive_subscriptions bigint := 0;

  v_processor_active boolean := false;
  v_sender_active boolean := false;
  v_maintenance_active boolean := false;

  v_processor_last_status text;
  v_sender_last_status text;
  v_maintenance_last_status text;

  v_healthy boolean := false;
begin
  select
    count(*) filter (
      where job_status = 'Pending'
        and run_at <= clock_timestamp()
    ),
    count(*) filter (
      where job_status = 'Failed'
    ),
    count(*) filter (
      where job_status = 'DeadLetter'
    ),
    count(*) filter (
      where job_status = 'Processing'
        and locked_at <
          clock_timestamp() - interval '15 minutes'
    )
  into
    v_overdue_jobs,
    v_failed_jobs,
    v_deadletter_jobs,
    v_stale_jobs
  from public.notification_jobs;


  select
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status in (
          'Pending',
          'Processing'
        )
    ),
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status = 'Failed'
    ),
    count(*) filter (
      where channel = 'WebPush'
        and delivery_status in (
          'Sent',
          'Delivered'
        )
    )
  into
    v_unfinished_push,
    v_failed_push,
    v_successful_push
  from public.notification_deliveries;


  select
    count(*) filter (
      where is_active = true
        and permission_state = 'granted'
        and revoked_at is null
    ),
    count(*) filter (
      where failure_count > 0
    ),
    count(*) filter (
      where failure_count >= 5
    ),
    count(*) filter (
      where is_active = false
         or revoked_at is not null
         or permission_state in (
           'denied',
           'revoked',
           'unsupported'
         )
    )
  into
    v_active_subscriptions,
    v_subscription_failures,
    v_unhealthy_subscriptions,
    v_inactive_subscriptions
  from public.push_subscriptions;


  select exists (
    select 1
    from cron.job
    where jobname = 'notification-server-processor'
      and active = true
  )
  into v_processor_active;

  select exists (
    select 1
    from cron.job
    where jobname = 'notification-web-push-sender'
      and active = true
  )
  into v_sender_active;

  select exists (
    select 1
    from cron.job
    where jobname = 'notification-operations-maintenance'
      and active = true
  )
  into v_maintenance_active;


  select run_row.status
  into v_processor_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-server-processor'
  order by run_row.start_time desc
  limit 1;


  select run_row.status
  into v_sender_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-web-push-sender'
  order by run_row.start_time desc
  limit 1;


  select run_row.status
  into v_maintenance_last_status
  from cron.job job_row
  join cron.job_run_details run_row
    on run_row.jobid = job_row.jobid
  where job_row.jobname = 'notification-operations-maintenance'
  order by run_row.start_time desc
  limit 1;


  /*
   * A newly-created maintenance Cron may not have executed yet.
   * A NULL first-run status is therefore accepted.
   * Any recorded non-success status makes health red.
   */
  v_healthy :=
    v_overdue_jobs = 0
    and v_failed_jobs = 0
    and v_deadletter_jobs = 0
    and v_stale_jobs = 0
    and v_unfinished_push = 0
    and v_failed_push = 0
    and v_unhealthy_subscriptions = 0
    and v_processor_active
    and v_sender_active
    and v_maintenance_active
    and v_processor_last_status = 'succeeded'
    and v_sender_last_status = 'succeeded'
    and (
      v_maintenance_last_status is null
      or v_maintenance_last_status = 'succeeded'
    );


  return jsonb_build_object(
    'healthy',
      v_healthy,

    'jobs',
      jsonb_build_object(
        'overdue_pending',
          v_overdue_jobs,
        'failed',
          v_failed_jobs,
        'deadletter',
          v_deadletter_jobs,
        'stale_processing',
          v_stale_jobs
      ),

    'web_push_deliveries',
      jsonb_build_object(
        'unfinished',
          v_unfinished_push,
        'failed',
          v_failed_push,
        'successful',
          v_successful_push
      ),

    'subscriptions',
      jsonb_build_object(
        'active',
          v_active_subscriptions,
        'with_failures',
          v_subscription_failures,
        'unhealthy',
          v_unhealthy_subscriptions,
        'inactive',
          v_inactive_subscriptions
      ),

    'cron',
      jsonb_build_object(
        'notification-server-processor',
          jsonb_build_object(
            'active',
              v_processor_active,
            'last_status',
              v_processor_last_status
          ),

        'notification-web-push-sender',
          jsonb_build_object(
            'active',
              v_sender_active,
            'last_status',
              v_sender_last_status
          ),

        'notification-operations-maintenance',
          jsonb_build_object(
            'active',
              v_maintenance_active,
            'last_status',
              v_maintenance_last_status,
            'first_run_pending',
              v_maintenance_last_status is null
          )
      ),

    'checked_at',
      clock_timestamp()
  );
end
$function$;
