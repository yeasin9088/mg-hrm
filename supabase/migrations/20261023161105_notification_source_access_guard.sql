-- Single approved operator boundary for source roles and legacy uniform policies.
-- Adds no user, changes no source row and preserves service-only worker ACLs.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT p.role FROM public.profiles p WHERE p.id=auth.uid()
   AND p.is_active=true AND public.swa_is_operator()),'none');
$$;
DO $$DECLARE tab text; BEGIN
 FOREACH tab IN ARRAY ARRAY['uniform_supply_orders','uniform_delivery_issues','uniform_delivery_bills'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',tab);
  EXECUTE format('CREATE POLICY notification_operator_boundary ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((SELECT public.swa_is_operator())) WITH CHECK ((SELECT public.swa_is_operator()))',tab);
 END LOOP;
END $$;
COMMIT;
