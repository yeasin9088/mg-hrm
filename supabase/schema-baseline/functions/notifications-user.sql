-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- public.notification_complete_if_resolved(uuid) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_complete_if_resolved(p_notification_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
  v_entity_id bigint;
  v_check jsonb;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  select n.*
  into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  if v_notification.status = 'Completed' then
    return jsonb_build_object(
      'notification', to_jsonb(v_notification),
      'changed', false
    );
  end if;

  if v_notification.status in (
    'Dismissed',
    'Expired',
    'Cancelled'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Terminal notification cannot be completed';
  end if;

  if coalesce(v_notification.entity_id, '') !~ '^[0-9]+$' then
    raise exception using
      errcode = '23514',
      message = 'Valid source entity ID is required';
  end if;

  v_entity_id := v_notification.entity_id::bigint;

  if lower(v_notification.entity_type) in (
    'todo',
    'transfer',
    'exit'
  ) then
    v_check := public.notification_check_core_source(
      v_notification.entity_type,
      v_entity_id
    );

  elsif lower(v_notification.entity_type) = 'leave' then
    v_check := public.notification_check_leave_source(
      v_entity_id
    );

  elsif lower(v_notification.entity_type) in (
    'uniform_supply_order',
    'uniform_delivery_issue',
    'uniform_delivery_bill'
  ) then
    v_check := public.notification_check_uniform_source(
      v_notification.entity_type,
      v_entity_id
    );

  else
    raise exception using
      errcode = '23514',
      message = 'Unsupported notification source type';
  end if;

  if coalesce(
    (v_check ->> 'resolved')::boolean,
    false
  ) is not true then
    raise exception using
      errcode = '23514',
      message = concat(
        'Source workflow is not resolved. Current state: ',
        coalesce(v_check ->> 'state', '[unknown]')
      );
  end if;

  update public.notifications n
  set
    status = 'Completed',
    completed_at = coalesce(n.completed_at, now()),
    read_at = coalesce(n.read_at, now()),
    actioned_at = coalesce(n.actioned_at, now()),
    snoozed_until = null
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  returning n.*
  into v_notification;

  return jsonb_build_object(
    'notification', to_jsonb(v_notification),
    'source_check', v_check,
    'changed', true
  );
end;
$function$;
ALTER FUNCTION public.notification_complete_if_resolved(uuid) OWNER TO "postgres";

-- public.notification_dismiss(uuid) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_dismiss(p_notification_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'Notification ID is required';
  end if;

  select n.*
    into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  -- Already terminal: return safely without changing the row.
  if v_notification.status in (
    'Completed',
    'Dismissed',
    'Expired',
    'Cancelled'
  ) then
    return jsonb_build_object(
      'notification',
      to_jsonb(v_notification),
      'changed',
      false
    );
  end if;

  update public.notifications n
     set status = 'Dismissed',
         dismissed_at = coalesce(
           n.dismissed_at,
           now()
         ),
         read_at = coalesce(
           n.read_at,
           now()
         ),
         snoozed_until = null
   where n.id = p_notification_id
     and n.recipient_user_id = v_user_id
   returning n.*
      into v_notification;

  return jsonb_build_object(
    'notification',
    to_jsonb(v_notification),
    'changed',
    true
  );
end;
$function$;
ALTER FUNCTION public.notification_dismiss(uuid) OWNER TO "postgres";

-- public.notification_mark_all_read() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_mark_all_read()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_updated_count integer := 0;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  update public.notifications n
     set read_at = coalesce(n.read_at, now()),

         status = case
           when n.status in (
             'Scheduled',
             'Ready',
             'Delivered',
             'Failed'
           )
             then 'Read'

           else n.status
         end

   where n.recipient_user_id = v_user_id
     and n.read_at is null
     and n.status not in (
       'Completed',
       'Dismissed',
       'Expired',
       'Cancelled'
     );

  get diagnostics
    v_updated_count = row_count;

  return jsonb_build_object(
    'updated_count',
    v_updated_count
  );
end;
$function$;
ALTER FUNCTION public.notification_mark_all_read() OWNER TO "postgres";

-- public.notification_mark_read(uuid) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_mark_read(p_notification_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'Notification ID is required';
  end if;

  select n.*
    into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  update public.notifications n
     set read_at = coalesce(n.read_at, now()),

         status = case
           when n.status in (
             'Scheduled',
             'Ready',
             'Delivered',
             'Failed'
           )
             then 'Read'

           else n.status
         end

   where n.id = p_notification_id
     and n.recipient_user_id = v_user_id

   returning n.*
   into v_notification;

  return jsonb_build_object(
    'notification',
    to_jsonb(v_notification)
  );
end;
$function$;
ALTER FUNCTION public.notification_mark_read(uuid) OWNER TO "postgres";

-- public.notification_open(uuid) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_open(p_notification_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'Notification ID is required';
  end if;

  select n.*
    into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  if v_notification.status in (
    'Completed',
    'Dismissed',
    'Expired',
    'Cancelled'
  ) then
    return jsonb_build_object(
      'notification',
      to_jsonb(v_notification),
      'changed',
      false
    );
  end if;

  update public.notifications n
     set status = 'Actioned',
         read_at = coalesce(n.read_at, now()),
         opened_at = coalesce(n.opened_at, now()),
         actioned_at = coalesce(n.actioned_at, now()),
         snoozed_until = null
   where n.id = p_notification_id
     and n.recipient_user_id = v_user_id
   returning n.*
      into v_notification;

  return jsonb_build_object(
    'notification',
    to_jsonb(v_notification),
    'changed',
    true
  );
end;
$function$;
ALTER FUNCTION public.notification_open(uuid) OWNER TO "postgres";

-- public.notification_snooze(uuid,timestamp with time zone) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.notification_snooze(p_notification_id uuid, p_snoozed_until timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_notification public.notifications%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'Notification ID is required';
  end if;

  if p_snoozed_until is null then
    raise exception using
      errcode = '22023',
      message = 'Snooze time is required';
  end if;

  if p_snoozed_until <= now() then
    raise exception using
      errcode = '23514',
      message = 'Snooze time must be in the future';
  end if;

  select n.*
    into v_notification
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Notification not found';
  end if;

  if v_notification.status in (
    'Completed',
    'Dismissed',
    'Expired',
    'Cancelled'
  ) then
    raise exception using
      errcode = '23514',
      message = format(
        'Notification cannot be snoozed from status %s',
        v_notification.status
      );
  end if;

  update public.notifications n
     set status = 'Snoozed',
         snoozed_until = p_snoozed_until,
         scheduled_for = p_snoozed_until
   where n.id = p_notification_id
     and n.recipient_user_id = v_user_id
   returning n.*
      into v_notification;

  return jsonb_build_object(
    'notification',
    to_jsonb(v_notification),
    'changed',
    true
  );
end;
$function$;
ALTER FUNCTION public.notification_snooze(uuid,timestamp with time zone) OWNER TO "postgres";

-- public.push_subscription_list_devices() | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.push_subscription_list_devices()
 RETURNS TABLE(subscription_id bigint, device_label text, browser_name text, platform_name text, permission_state text, is_active boolean, last_seen_at timestamp with time zone, last_success_at timestamp with time zone, last_failure_at timestamp with time zone, failure_count integer, revoked_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authenticated session required';
  end if;

  if not exists (
    select 1
    from public.profiles profile_row
    where profile_row.id = v_user_id
      and profile_row.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active profile required';
  end if;

  return query
  select
    subscription_row.id,
    subscription_row.device_label,
    subscription_row.browser_name,
    subscription_row.platform_name,
    subscription_row.permission_state,
    subscription_row.is_active,
    subscription_row.last_seen_at,
    subscription_row.last_success_at,
    subscription_row.last_failure_at,
    subscription_row.failure_count,
    subscription_row.revoked_at,
    subscription_row.created_at,
    subscription_row.updated_at
  from public.push_subscriptions subscription_row
  where subscription_row.user_id = v_user_id
  order by
    subscription_row.is_active desc,
    subscription_row.last_seen_at desc,
    subscription_row.id desc;
end
$function$;
ALTER FUNCTION public.push_subscription_list_devices() OWNER TO "postgres";

-- public.push_subscription_register(text,text,text,text,text,text,text) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.push_subscription_register(p_endpoint text, p_p256dh_key text, p_auth_key text, p_device_label text DEFAULT NULL::text, p_browser_name text DEFAULT NULL::text, p_platform_name text DEFAULT NULL::text, p_user_agent text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_endpoint text;
  v_endpoint_hash text;
  v_existing public.push_subscriptions%rowtype;
  v_subscription public.push_subscriptions%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  v_endpoint := btrim(coalesce(p_endpoint, ''));

  if v_endpoint = '' then
    raise exception using
      errcode = '22023',
      message = 'Push endpoint is required';
  end if;

  if btrim(coalesce(p_p256dh_key, '')) = '' then
    raise exception using
      errcode = '22023',
      message = 'Push p256dh key is required';
  end if;

  if btrim(coalesce(p_auth_key, '')) = '' then
    raise exception using
      errcode = '22023',
      message = 'Push auth key is required';
  end if;

  if v_endpoint !~ '^https://' then
    raise exception using
      errcode = '23514',
      message = 'Push endpoint must use HTTPS';
  end if;

  v_endpoint_hash := md5(v_endpoint);

  select s.*
  into v_existing
  from public.push_subscriptions s
  where s.endpoint_hash = v_endpoint_hash
  for update;

  if found and v_existing.user_id <> v_user_id then
    raise exception using
      errcode = '23505',
      message = 'This push subscription belongs to another user';
  end if;

  if found then
    update public.push_subscriptions s
    set
      endpoint = v_endpoint,
      p256dh_key = btrim(p_p256dh_key),
      auth_key = btrim(p_auth_key),
      device_label = nullif(btrim(coalesce(p_device_label, '')), ''),
      browser_name = nullif(btrim(coalesce(p_browser_name, '')), ''),
      platform_name = nullif(btrim(coalesce(p_platform_name, '')), ''),
      user_agent = nullif(btrim(coalesce(p_user_agent, '')), ''),
      permission_state = 'granted',
      is_active = true,
      revoked_at = null,
      last_seen_at = now()
    where s.id = v_existing.id
      and s.user_id = v_user_id
    returning s.*
    into v_subscription;

  else
    insert into public.push_subscriptions (
      user_id,
      endpoint,
      endpoint_hash,
      p256dh_key,
      auth_key,
      device_label,
      browser_name,
      platform_name,
      user_agent,
      permission_state,
      is_active,
      last_seen_at
    )
    values (
      v_user_id,
      v_endpoint,
      v_endpoint_hash,
      btrim(p_p256dh_key),
      btrim(p_auth_key),
      nullif(btrim(coalesce(p_device_label, '')), ''),
      nullif(btrim(coalesce(p_browser_name, '')), ''),
      nullif(btrim(coalesce(p_platform_name, '')), ''),
      nullif(btrim(coalesce(p_user_agent, '')), ''),
      'granted',
      true,
      now()
    )
    returning *
    into v_subscription;
  end if;

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'device_label', v_subscription.device_label,
    'browser_name', v_subscription.browser_name,
    'platform_name', v_subscription.platform_name,
    'is_active', v_subscription.is_active,
    'permission_state', v_subscription.permission_state,
    'last_seen_at', v_subscription.last_seen_at
  );
end;
$function$;
ALTER FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) OWNER TO "postgres";

-- public.push_subscription_revoke(bigint) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.push_subscription_revoke(p_subscription_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_subscription public.push_subscriptions%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_subscription_id is null then
    raise exception using
      errcode = '22023',
      message = 'Subscription ID is required';
  end if;

  select s.*
  into v_subscription
  from public.push_subscriptions s
  where s.id = p_subscription_id
    and s.user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Device subscription not found';
  end if;

  if v_subscription.is_active = false
     and v_subscription.permission_state = 'revoked' then
    return jsonb_build_object(
      'subscription_id', v_subscription.id,
      'is_active', v_subscription.is_active,
      'permission_state', v_subscription.permission_state,
      'revoked_at', v_subscription.revoked_at,
      'changed', false
    );
  end if;

  update public.push_subscriptions s
  set
    is_active = false,
    permission_state = 'revoked',
    revoked_at = coalesce(s.revoked_at, now())
  where s.id = p_subscription_id
    and s.user_id = v_user_id
  returning s.*
  into v_subscription;

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'device_label', v_subscription.device_label,
    'is_active', v_subscription.is_active,
    'permission_state', v_subscription.permission_state,
    'revoked_at', v_subscription.revoked_at,
    'changed', true
  );
end;
$function$;
ALTER FUNCTION public.push_subscription_revoke(bigint) OWNER TO "postgres";

-- public.push_subscription_update_device(bigint,text,text,text,boolean) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.push_subscription_update_device(p_subscription_id bigint, p_device_label text DEFAULT NULL::text, p_browser_name text DEFAULT NULL::text, p_platform_name text DEFAULT NULL::text, p_touch_last_seen boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_subscription public.push_subscriptions%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.is_active = true
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active user profile is required';
  end if;

  if p_subscription_id is null then
    raise exception using
      errcode = '22023',
      message = 'Subscription ID is required';
  end if;

  select s.*
  into v_subscription
  from public.push_subscriptions s
  where s.id = p_subscription_id
    and s.user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Device subscription not found';
  end if;

  update public.push_subscriptions s
  set
    device_label = case
      when p_device_label is null
        then s.device_label
      else nullif(btrim(p_device_label), '')
    end,

    browser_name = case
      when p_browser_name is null
        then s.browser_name
      else nullif(btrim(p_browser_name), '')
    end,

    platform_name = case
      when p_platform_name is null
        then s.platform_name
      else nullif(btrim(p_platform_name), '')
    end,

    last_seen_at = case
      when coalesce(p_touch_last_seen, true)
        then now()
      else s.last_seen_at
    end

  where s.id = p_subscription_id
    and s.user_id = v_user_id

  returning s.*
  into v_subscription;

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'device_label', v_subscription.device_label,
    'browser_name', v_subscription.browser_name,
    'platform_name', v_subscription.platform_name,
    'permission_state', v_subscription.permission_state,
    'is_active', v_subscription.is_active,
    'last_seen_at', v_subscription.last_seen_at
  );
end;
$function$;
ALTER FUNCTION public.push_subscription_update_device(bigint,text,text,text,boolean) OWNER TO "postgres";
