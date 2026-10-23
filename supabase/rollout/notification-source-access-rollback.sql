-- Restore the preceding role lookup and remove only the added restrictive policies.
BEGIN;
CREATE OR REPLACE FUNCTION public.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select p.role from public.profiles p
      where p.id = auth.uid() and p.is_active = true),
    'none'
  );
$function$;
DROP POLICY notification_operator_boundary ON public.uniform_supply_orders;
DROP POLICY notification_operator_boundary ON public.uniform_delivery_issues;
DROP POLICY notification_operator_boundary ON public.uniform_delivery_bills;
COMMIT;
