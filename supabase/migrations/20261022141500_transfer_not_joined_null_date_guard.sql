-- Missing-date fail-closed safeguard: prevents Not Joined on corrupt legacy orders.
-- The joining-confirmation RPC already has the same check.
-- This is a targeted SECURITY INVOKER replacement; assignments are never touched.
DO $preflight$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p
    WHERE p.oid='public.mark_transfer_not_joined(bigint,text,text)'::regprocedure
      AND NOT p.prosecdef
      AND 'TimeZone=Asia/Dhaka'=ANY(p.proconfig)
      AND position('if v_transfer.effective_date > current_date' in lower(pg_get_functiondef(p.oid)))>0
      AND position('if v_transfer.effective_date is null' in lower(pg_get_functiondef(p.oid)))=0)
  THEN RAISE EXCEPTION 'mark_transfer_not_joined body or security setting drifted'; END IF;
END $preflight$;

CREATE OR REPLACE FUNCTION public.mark_transfer_not_joined(p_transfer_id bigint, p_reason text, p_remarks text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'Asia/Dhaka'
AS $function$
declare
  v_transfer public.transfers%rowtype;
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception using errcode = '23514', message = 'Not-joined reason is required';
  end if;

  select * into v_transfer
    from public.transfers
   where id = p_transfer_id
     and deleted_at is null
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Transfer not found';
  end if;

  if v_transfer.status not in ('Scheduled', 'Joining Pending') then
    raise exception using errcode = '23514',
      message = format('Transfer cannot be marked Not Joined from status %s', v_transfer.status);
  end if;

  if v_transfer.effective_date is null then
    raise exception using errcode = '23514', message = 'Transfer effective date is missing';
  end if;
  if v_transfer.effective_date > current_date then
    raise exception using errcode = '23514', message = 'Transfer is not yet due';
  end if;

  update public.transfers
     set status = 'Not Joined',
         not_joined_at = now(),
         not_joined_by = auth.uid(),
         not_joined_reason = btrim(p_reason),
         not_joined_remarks = nullif(btrim(coalesce(p_remarks, '')), ''),
         updated_at = now()
   where id = v_transfer.id
   returning * into v_transfer;

  insert into public.activity_log (user_id, action, table_name, record_ref, detail)
  values (
    auth.uid(), 'not_joined', 'transfers', v_transfer.id::text,
    format('Employee system ID %s did not join destination project: %s',
      v_transfer.employee_sys_id, p_reason)
  );

  return to_jsonb(v_transfer);
end;
$function$;
