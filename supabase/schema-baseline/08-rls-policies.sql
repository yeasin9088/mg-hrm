-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

ALTER TABLE "public"."activity_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."activity_log" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."app_settings" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."career" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."career" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."demand" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."demand" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."designations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."designations" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."disciplinary" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."disciplinary" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."districts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."districts" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."divisions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."divisions" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."employee_join_date_history" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."employee_join_date_history" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."employee_reactivations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."employee_reactivations" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."employees" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."employees" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."exits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."exits" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."leaves" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."leaves" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."meeting_attendance" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."meeting_attendance" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."meetings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."meetings" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_deliveries" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_deliveries" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_escalation_rules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_escalation_rules" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_events" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_events" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_jobs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_jobs" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_legacy_states" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_legacy_states" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_preferences" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notifications" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."project_meeting_scope_history" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."project_meeting_scope_history" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."projects" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."push_subscriptions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."push_subscriptions" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."recruitment_archive" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."recruitment_archive" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."thanas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."thanas" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."todos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."todos" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."todos_backup_20260928" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."todos_backup_20260928" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."transfers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."transfers" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_deliveries" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_deliveries" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_bills" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_bills" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_issues" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_issues" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_delivery_items" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_items" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_allocations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_allocations" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_employee_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_employee_items" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_employees" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_employees" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_items" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_postponements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_order_postponements" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_orders" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_requirement_reports" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_requirement_reports" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_suppliers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_suppliers" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_supply_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."uniform_supply_orders" NO FORCE ROW LEVEL SECURITY;

CREATE POLICY "activity_insert" ON "public"."activity_log" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "activity_select" ON "public"."activity_log" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "app_settings_delete" ON "public"."app_settings" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "app_settings_insert" ON "public"."app_settings" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "app_settings_select" ON "public"."app_settings" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "app_settings_update" ON "public"."app_settings" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "career_delete" ON "public"."career" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "career_insert" ON "public"."career" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "career_select" ON "public"."career" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "career_update" ON "public"."career" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "demand_delete" ON "public"."demand" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "demand_insert" ON "public"."demand" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "demand_select" ON "public"."demand" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "demand_update" ON "public"."demand" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "designations_delete" ON "public"."designations" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "designations_insert" ON "public"."designations" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "designations_select" ON "public"."designations" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "designations_update" ON "public"."designations" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "disciplinary_delete" ON "public"."disciplinary" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "disciplinary_insert" ON "public"."disciplinary" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "disciplinary_select" ON "public"."disciplinary" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "disciplinary_update" ON "public"."disciplinary" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "districts_delete" ON "public"."districts" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "districts_insert" ON "public"."districts" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "districts_select" ON "public"."districts" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "districts_update" ON "public"."districts" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "divisions_delete" ON "public"."divisions" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "divisions_insert" ON "public"."divisions" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "divisions_select" ON "public"."divisions" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "divisions_update" ON "public"."divisions" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "employee_join_date_history_read" ON "public"."employee_join_date_history" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "employee_reactivations_delete" ON "public"."employee_reactivations" AS PERMISSIVE FOR DELETE TO "authenticated" USING (false);

CREATE POLICY "employee_reactivations_insert" ON "public"."employee_reactivations" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text, 'owner'::text])));

CREATE POLICY "employee_reactivations_select" ON "public"."employee_reactivations" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "employee_reactivations_update" ON "public"."employee_reactivations" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])));

CREATE POLICY "employees_delete" ON "public"."employees" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "employees_insert" ON "public"."employees" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "employees_select" ON "public"."employees" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "employees_update" ON "public"."employees" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "exits_delete" ON "public"."exits" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "exits_insert" ON "public"."exits" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "exits_select" ON "public"."exits" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "exits_update" ON "public"."exits" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "leaves_delete" ON "public"."leaves" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "leaves_insert" ON "public"."leaves" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "leaves_select" ON "public"."leaves" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "leaves_update" ON "public"."leaves" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "meeting_attendance_delete" ON "public"."meeting_attendance" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "meeting_attendance_insert" ON "public"."meeting_attendance" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "meeting_attendance_select" ON "public"."meeting_attendance" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "meeting_attendance_update" ON "public"."meeting_attendance" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "meetings_delete" ON "public"."meetings" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "meetings_insert" ON "public"."meetings" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "meetings_select" ON "public"."meetings" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "meetings_update" ON "public"."meetings" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "notification_deliveries_select_own" ON "public"."notification_deliveries" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM notifications n
  WHERE ((n.id = notification_deliveries.notification_id) AND (n.recipient_user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "notification_escalation_rules_admin_delete" ON "public"."notification_escalation_rules" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])));

CREATE POLICY "notification_escalation_rules_admin_insert" ON "public"."notification_escalation_rules" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])) AND ((created_by_user_id IS NULL) OR (created_by_user_id = ( SELECT auth.uid() AS uid))) AND ((updated_by_user_id IS NULL) OR (updated_by_user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "notification_escalation_rules_admin_select" ON "public"."notification_escalation_rules" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])));

CREATE POLICY "notification_escalation_rules_admin_update" ON "public"."notification_escalation_rules" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))) WITH CHECK (((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])) AND ((updated_by_user_id IS NULL) OR (updated_by_user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "notification_legacy_states_owner" ON "public"."notification_legacy_states" AS PERMISSIVE FOR ALL TO "authenticated" USING (((user_id = auth.uid()) AND (my_role() <> 'none'::text))) WITH CHECK (((user_id = auth.uid()) AND (my_role() <> 'none'::text)));

CREATE POLICY "notification_preferences_delete_own_override" ON "public"."notification_preferences" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) AND (category <> '*'::text) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true))))));

CREATE POLICY "notification_preferences_insert_own" ON "public"."notification_preferences" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true))))));

CREATE POLICY "notification_preferences_select_own" ON "public"."notification_preferences" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "notification_preferences_update_own" ON "public"."notification_preferences" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true)))))) WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true))))));

CREATE POLICY "notifications_select_own" ON "public"."notifications" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((recipient_user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "profiles_admin_all" ON "public"."profiles" AS PERMISSIVE FOR ALL TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])));

CREATE POLICY "profiles_select" ON "public"."profiles" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((id = auth.uid()) OR (( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY "profiles_update_self" ON "public"."profiles" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((id = auth.uid())) WITH CHECK (((id = auth.uid()) AND (role = ( SELECT p.role
   FROM profiles p
  WHERE (p.id = auth.uid())))));

CREATE POLICY "project_meeting_scope_history_select_authenticated" ON "public"."project_meeting_scope_history" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "projects_delete" ON "public"."projects" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "projects_insert" ON "public"."projects" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "projects_select" ON "public"."projects" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "projects_update" ON "public"."projects" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "push_subscriptions_insert_own" ON "public"."push_subscriptions" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true))))));

CREATE POLICY "push_subscriptions_select_own" ON "public"."push_subscriptions" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "push_subscriptions_update_own" ON "public"."push_subscriptions" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true)))))) WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.is_active = true))))));

CREATE POLICY "recruitment_archive_delete" ON "public"."recruitment_archive" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "recruitment_archive_insert" ON "public"."recruitment_archive" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "recruitment_archive_select" ON "public"."recruitment_archive" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "recruitment_archive_update" ON "public"."recruitment_archive" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "thanas_delete" ON "public"."thanas" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "thanas_insert" ON "public"."thanas" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "thanas_select" ON "public"."thanas" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "thanas_update" ON "public"."thanas" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "todos_delete" ON "public"."todos" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "todos_insert" ON "public"."todos" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "todos_select" ON "public"."todos" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "todos_update" ON "public"."todos" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "transfers_delete" ON "public"."transfers" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "transfers_insert" ON "public"."transfers" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "transfers_select" ON "public"."transfers" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "transfers_update" ON "public"."transfers" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "uniform_delete" ON "public"."uniform" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT my_role() AS my_role) = 'admin'::text));

CREATE POLICY "uniform_insert" ON "public"."uniform" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "uniform_select" ON "public"."uniform" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT my_role() AS my_role) <> 'none'::text));

CREATE POLICY "uniform_update" ON "public"."uniform" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text]))) WITH CHECK ((( SELECT my_role() AS my_role) = ANY (ARRAY['admin'::text, 'editor'::text])));

CREATE POLICY "uniform_deliveries_delete" ON "public"."uniform_deliveries" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_deliveries_insert" ON "public"."uniform_deliveries" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_deliveries_select" ON "public"."uniform_deliveries" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_deliveries_update" ON "public"."uniform_deliveries" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_delivery_bills_delete" ON "public"."uniform_delivery_bills" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_delivery_bills_insert" ON "public"."uniform_delivery_bills" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_delivery_bills_select" ON "public"."uniform_delivery_bills" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_delivery_bills_update" ON "public"."uniform_delivery_bills" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_delivery_issues_delete" ON "public"."uniform_delivery_issues" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_delivery_issues_insert" ON "public"."uniform_delivery_issues" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_delivery_issues_select" ON "public"."uniform_delivery_issues" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_delivery_issues_update" ON "public"."uniform_delivery_issues" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_delivery_items_delete" ON "public"."uniform_delivery_items" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_delivery_items_insert" ON "public"."uniform_delivery_items" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_delivery_items_select" ON "public"."uniform_delivery_items" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_delivery_items_update" ON "public"."uniform_delivery_items" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_items_delete" ON "public"."uniform_items" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_items_insert" ON "public"."uniform_items" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_items_select" ON "public"."uniform_items" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_items_update" ON "public"."uniform_items" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_order_employee_items_delete" ON "public"."uniform_order_employee_items" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_order_employee_items_insert" ON "public"."uniform_order_employee_items" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_order_employee_items_select" ON "public"."uniform_order_employee_items" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_order_employee_items_update" ON "public"."uniform_order_employee_items" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_order_employees_delete" ON "public"."uniform_order_employees" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_order_employees_insert" ON "public"."uniform_order_employees" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_order_employees_select" ON "public"."uniform_order_employees" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_order_employees_update" ON "public"."uniform_order_employees" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_order_postponements_delete" ON "public"."uniform_order_postponements" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_order_postponements_insert" ON "public"."uniform_order_postponements" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_order_postponements_select" ON "public"."uniform_order_postponements" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_order_postponements_update" ON "public"."uniform_order_postponements" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_requirement_reports_delete" ON "public"."uniform_requirement_reports" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_requirement_reports_insert" ON "public"."uniform_requirement_reports" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_requirement_reports_select" ON "public"."uniform_requirement_reports" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_requirement_reports_update" ON "public"."uniform_requirement_reports" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_suppliers_delete" ON "public"."uniform_suppliers" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_suppliers_insert" ON "public"."uniform_suppliers" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_suppliers_select" ON "public"."uniform_suppliers" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_suppliers_update" ON "public"."uniform_suppliers" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "uniform_supply_orders_delete" ON "public"."uniform_supply_orders" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((my_role() = ANY (ARRAY['owner'::text, 'admin'::text])));

CREATE POLICY "uniform_supply_orders_insert" ON "public"."uniform_supply_orders" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "uniform_supply_orders_select" ON "public"."uniform_supply_orders" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "uniform_supply_orders_update" ON "public"."uniform_supply_orders" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);
