-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- public.next_uniform_order_number(date) | SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.next_uniform_order_number(p_order_date date DEFAULT CURRENT_DATE)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_prefix text;
  v_next integer;
begin
  v_prefix := to_char(p_order_date, 'DDMMYY');
  perform pg_advisory_xact_lock(hashtext('uniform_order_number_' || v_prefix));

  select coalesce(max(right(order_number, 3)::integer), 0) + 1
    into v_next
  from public.uniform_supply_orders
  where left(order_number, 6) = v_prefix;

  if v_next > 999 then
    raise exception 'Daily uniform order limit exceeded for %', p_order_date;
  end if;

  return v_prefix || lpad(v_next::text, 3, '0');
end;
$function$;
ALTER FUNCTION public.next_uniform_order_number(date) OWNER TO "postgres";

-- public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.save_uniform_delivery(p_order_id bigint, p_delivery_type text, p_delivery_date date, p_document_type text, p_document_number text, p_bill_amount numeric, p_remarks text DEFAULT NULL::text, p_items jsonb DEFAULT '[]'::jsonb, p_issues jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_order public.uniform_supply_orders%rowtype;
  v_delivery_id bigint;
  v_sequence integer;
  v_item jsonb;
  v_issue jsonb;
  v_allocation public.uniform_order_employees%rowtype;
  v_expected integer;
  v_previously_delivered integer;
  v_deliver_now integer;
  v_outstanding integer;
  v_total_remaining bigint;
  v_issue_count integer := 0;
  v_item_count integer := 0;
  v_new_status text;
begin
  if p_delivery_type not in ('Partial','Remaining','Full','Supplementary') then
    raise exception 'Invalid delivery type.';
  end if;
  if p_delivery_date is null then raise exception 'Delivery date is required.'; end if;
  if p_document_type not in ('Bill','Challan','Bill/Challan') then
    raise exception 'Invalid Bill/Challan document type.';
  end if;
  if btrim(coalesce(p_document_number,'')) = '' then
    raise exception 'Bill/Challan number is required.';
  end if;
  if coalesce(p_bill_amount,0) <= 0 then raise exception 'Bill amount must be greater than zero.'; end if;
  if jsonb_typeof(coalesce(p_items,'[]'::jsonb)) <> 'array' then raise exception 'Delivery items must be a JSON array.'; end if;
  if jsonb_array_length(coalesce(p_items,'[]'::jsonb)) = 0 then raise exception 'At least one delivered item is required.'; end if;
  if jsonb_typeof(coalesce(p_issues,'[]'::jsonb)) <> 'array' then raise exception 'Delivery issues must be a JSON array.'; end if;

  select * into v_order from public.uniform_supply_orders where id=p_order_id for update;
  if not found then raise exception 'Uniform order does not exist.'; end if;
  if v_order.status in ('Completed','Cancelled') then raise exception 'This order is read-only.'; end if;
  if v_order.status not in ('Ready for Delivery','Partially Delivered') then
    raise exception 'Order must be Ready for Delivery or Partially Delivered.';
  end if;

  select coalesce(max(delivery_sequence),0)+1 into v_sequence
  from public.uniform_deliveries where order_id=p_order_id;

  -- Validate every line against the authoritative requirement and prior deliveries.
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_deliver_now := coalesce((v_item->>'delivered_quantity')::integer,0);
    if v_deliver_now <= 0 then raise exception 'Delivered quantities must be positive integers.'; end if;

    select * into v_allocation
    from public.uniform_order_employees
    where id=(v_item->>'order_employee_id')::bigint
      and order_id=p_order_id and is_active=true;
    if not found then raise exception 'A delivery line references an invalid employee allocation.'; end if;

    if lower(v_item->>'item_name_snapshot')='shirt' then
      v_expected := v_allocation.set_quantity;
    elsif lower(v_item->>'item_name_snapshot')='pant' then
      v_expected := v_allocation.set_quantity;
    else
      select quantity into v_expected
      from public.uniform_order_employee_items
      where order_employee_id=v_allocation.id
        and item_id=(v_item->>'item_id')::bigint
        and coalesce(lower(btrim(size_text)),'')=coalesce(lower(btrim(v_item->>'size_text')),'')
      limit 1;
      if v_expected is null then raise exception 'A delivery line is not part of the employee requirement.'; end if;
    end if;

    select coalesce(sum(di.delivered_quantity),0) into v_previously_delivered
    from public.uniform_delivery_items di
    join public.uniform_deliveries d on d.id=di.delivery_id
    where d.order_id=p_order_id and d.status<>'Cancelled'
      and di.order_employee_id=v_allocation.id
      and lower(di.item_name_snapshot)=lower(v_item->>'item_name_snapshot')
      and coalesce(lower(btrim(di.size_text)),'')=coalesce(lower(btrim(v_item->>'size_text')),'');

    v_outstanding := greatest(v_expected-v_previously_delivered,0);
    if v_deliver_now > v_outstanding then
      raise exception 'Delivered quantity for % exceeds the outstanding quantity of %.', v_item->>'item_name_snapshot', v_outstanding;
    end if;
    v_item_count := v_item_count+1;
  end loop;

  insert into public.uniform_deliveries(order_id,delivery_sequence,delivery_type,delivery_date,status,remarks)
  values(p_order_id,v_sequence,p_delivery_type,p_delivery_date,
    case when jsonb_array_length(coalesce(p_issues,'[]'::jsonb))>0 then 'Received with Issues' else 'Received' end,
    nullif(btrim(coalesce(p_remarks,'')),'')
  ) returning id into v_delivery_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    insert into public.uniform_delivery_items(
      delivery_id,order_employee_id,item_id,item_name_snapshot,unit_snapshot,size_text,
      expected_quantity,delivered_quantity,remarks
    ) values(
      v_delivery_id,(v_item->>'order_employee_id')::bigint,
      nullif(v_item->>'item_id','')::bigint,v_item->>'item_name_snapshot',
      v_item->>'unit_snapshot',nullif(btrim(coalesce(v_item->>'size_text','')),''),
      (v_item->>'expected_quantity')::integer,(v_item->>'delivered_quantity')::integer,
      nullif(btrim(coalesce(v_item->>'remarks','')),'')
    );
  end loop;

  insert into public.uniform_delivery_bills(
    delivery_id,order_id,document_type,document_number,bill_amount,submission_date,remarks
  ) values(
    v_delivery_id,p_order_id,p_document_type,btrim(p_document_number),p_bill_amount,
    p_delivery_date,nullif(btrim(coalesce(p_remarks,'')),'')
  );

  for v_issue in select value from jsonb_array_elements(coalesce(p_issues,'[]'::jsonb)) loop
    if v_issue->>'issue_type' not in (
      'Short Quantity','Missing Item','Wrong Size','Damaged Item',
      'Modification Required','Returned','Replacement Pending','Other'
    ) then raise exception 'Invalid delivery issue type.'; end if;
    if btrim(coalesce(v_issue->>'remarks',''))='' then raise exception 'Issue remarks are required.'; end if;

    insert into public.uniform_delivery_issues(
      order_id,delivery_id,order_employee_id,item_id,issue_type,
      expected_quantity,received_quantity,affected_quantity,remarks,resolution_status
    ) values(
      p_order_id,v_delivery_id,nullif(v_issue->>'order_employee_id','')::bigint,
      nullif(v_issue->>'item_id','')::bigint,v_issue->>'issue_type',
      nullif(v_issue->>'expected_quantity','')::integer,
      nullif(v_issue->>'received_quantity','')::integer,
      nullif(v_issue->>'affected_quantity','')::integer,
      btrim(v_issue->>'remarks'),'Open'
    );
    v_issue_count := v_issue_count+1;
  end loop;

  -- Calculate the authoritative balance after this delivery.
  with required as (
    select e.id allocation_id,'Shirt' item_name,'' size_text,e.set_quantity qty
    from public.uniform_order_employees e where e.order_id=p_order_id and e.is_active and e.set_quantity>0
    union all
    select e.id,'Pant','',e.set_quantity
    from public.uniform_order_employees e where e.order_id=p_order_id and e.is_active and e.set_quantity>0
    union all
    select e.id,i.item_name_snapshot,coalesce(i.size_text,''),i.quantity
    from public.uniform_order_employees e
    join public.uniform_order_employee_items i on i.order_employee_id=e.id
    where e.order_id=p_order_id and e.is_active and i.quantity>0
  ), delivered as (
    select di.order_employee_id allocation_id,di.item_name_snapshot item_name,
      coalesce(di.size_text,'') size_text,sum(di.delivered_quantity) qty
    from public.uniform_delivery_items di
    join public.uniform_deliveries d on d.id=di.delivery_id
    where d.order_id=p_order_id and d.status<>'Cancelled'
    group by di.order_employee_id,di.item_name_snapshot,coalesce(di.size_text,'')
  )
  select coalesce(sum(greatest(r.qty-coalesce(d.qty,0),0)),0) into v_total_remaining
  from required r left join delivered d
    on d.allocation_id=r.allocation_id and lower(d.item_name)=lower(r.item_name)
    and lower(d.size_text)=lower(r.size_text);

  if p_delivery_type='Full' and v_total_remaining>0 then
    raise exception 'Full delivery cannot be saved because % item unit(s) remain outstanding.',v_total_remaining;
  end if;
  if p_delivery_type='Partial' and v_total_remaining=0 then
    raise exception 'Partial delivery is not valid because no quantity remains outstanding.';
  end if;

  v_new_status := case when v_total_remaining=0 then 'Delivered' else 'Partially Delivered' end;
  update public.uniform_supply_orders
  set status=v_new_status,
      final_delivery_at=case when v_total_remaining=0 then p_delivery_date else null end
  where id=p_order_id;

  return jsonb_build_object(
    'delivery_id',v_delivery_id,'delivery_sequence',v_sequence,
    'status',v_new_status,'remaining_quantity',v_total_remaining,
    'item_lines',v_item_count,'issues_created',v_issue_count
  );
end;
$function$;
ALTER FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) OWNER TO "postgres";

-- public.uniform_order_accounting(bigint) | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.uniform_order_accounting(p_order_id bigint)
 RETURNS TABLE(approved_sets integer, assigned_sets bigint, postponed_sets bigint, unaccounted_sets bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select
    coalesce(o.approved_sets, 0)::integer,
    coalesce((
      select sum(e.set_quantity)
      from public.uniform_order_employees e
      where e.order_id = o.id and e.is_active = true
    ), 0)::bigint,
    coalesce((
      select sum(p.set_quantity)
      from public.uniform_order_postponements p
      where p.order_id = o.id and p.status in ('Open','Partially Activated')
    ), 0)::bigint,
    (
      coalesce(o.approved_sets, 0)
      - coalesce((
          select sum(e.set_quantity)
          from public.uniform_order_employees e
          where e.order_id = o.id and e.is_active = true
        ), 0)
      - coalesce((
          select sum(p.set_quantity)
          from public.uniform_order_postponements p
          where p.order_id = o.id and p.status in ('Open','Partially Activated')
        ), 0)
    )::bigint
  from public.uniform_supply_orders o
  where o.id = p_order_id;
$function$;
ALTER FUNCTION public.uniform_order_accounting(bigint) OWNER TO "postgres";
