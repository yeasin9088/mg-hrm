-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE TRIGGER app_settings_touch_trg BEFORE UPDATE ON app_settings FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."app_settings" ENABLE TRIGGER "app_settings_touch_trg";

CREATE TRIGGER career_touch_trg BEFORE UPDATE ON career FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."career" ENABLE TRIGGER "career_touch_trg";

CREATE TRIGGER demand_touch_trg BEFORE UPDATE ON demand FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."demand" ENABLE TRIGGER "demand_touch_trg";

CREATE TRIGGER disciplinary_touch_trg BEFORE UPDATE ON disciplinary FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."disciplinary" ENABLE TRIGGER "disciplinary_touch_trg";

CREATE TRIGGER employees_normalize_status_trg BEFORE INSERT OR UPDATE OF status ON employees FOR EACH ROW EXECUTE FUNCTION mghrm_normalize_employee_status();
ALTER TABLE "public"."employees" ENABLE TRIGGER "employees_normalize_status_trg";

CREATE TRIGGER employees_resolve_open_transfers_trg AFTER UPDATE OF status ON employees FOR EACH ROW EXECUTE FUNCTION mghrm_resolve_transfers_for_inactive_employee();
ALTER TABLE "public"."employees" ENABLE TRIGGER "employees_resolve_open_transfers_trg";

CREATE TRIGGER employees_touch_trg BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."employees" ENABLE TRIGGER "employees_touch_trg";

CREATE TRIGGER trg_employee_join_date_history AFTER UPDATE OF join_date ON employees FOR EACH ROW WHEN (old.join_date IS DISTINCT FROM new.join_date) EXECUTE FUNCTION log_employee_join_date_change();
ALTER TABLE "public"."employees" ENABLE TRIGGER "trg_employee_join_date_history";

CREATE TRIGGER exits_touch_trg BEFORE UPDATE ON exits FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."exits" ENABLE TRIGGER "exits_touch_trg";

CREATE TRIGGER leaves_touch_trg BEFORE UPDATE ON leaves FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."leaves" ENABLE TRIGGER "leaves_touch_trg";

CREATE TRIGGER meeting_attendance_touch_trg BEFORE UPDATE ON meeting_attendance FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."meeting_attendance" ENABLE TRIGGER "meeting_attendance_touch_trg";

CREATE TRIGGER meetings_touch_trg BEFORE UPDATE ON meetings FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."meetings" ENABLE TRIGGER "meetings_touch_trg";

CREATE TRIGGER notification_escalation_rules_touch_trg BEFORE UPDATE ON notification_escalation_rules FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."notification_escalation_rules" ENABLE TRIGGER "notification_escalation_rules_touch_trg";

CREATE TRIGGER notification_events_lifecycle_trg BEFORE INSERT OR UPDATE ON notification_events FOR EACH ROW EXECUTE FUNCTION notification_event_apply_lifecycle();
ALTER TABLE "public"."notification_events" ENABLE TRIGGER "notification_events_lifecycle_trg";

CREATE TRIGGER notification_events_touch_trg BEFORE UPDATE ON notification_events FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."notification_events" ENABLE TRIGGER "notification_events_touch_trg";

CREATE TRIGGER notification_jobs_lifecycle_trg BEFORE INSERT OR UPDATE ON notification_jobs FOR EACH ROW EXECUTE FUNCTION notification_job_apply_lifecycle();
ALTER TABLE "public"."notification_jobs" ENABLE TRIGGER "notification_jobs_lifecycle_trg";

CREATE TRIGGER notification_jobs_touch_trg BEFORE UPDATE ON notification_jobs FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."notification_jobs" ENABLE TRIGGER "notification_jobs_touch_trg";

CREATE TRIGGER notification_preferences_touch_trg BEFORE UPDATE ON notification_preferences FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."notification_preferences" ENABLE TRIGGER "notification_preferences_touch_trg";

CREATE TRIGGER notifications_lifecycle_trg BEFORE INSERT OR UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION notification_apply_lifecycle();
ALTER TABLE "public"."notifications" ENABLE TRIGGER "notifications_lifecycle_trg";

CREATE TRIGGER notifications_touch_trg BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."notifications" ENABLE TRIGGER "notifications_touch_trg";

CREATE TRIGGER profiles_guard_fields BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION guard_profile_fields();
ALTER TABLE "public"."profiles" ENABLE TRIGGER "profiles_guard_fields";

CREATE TRIGGER projects_touch_trg BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."projects" ENABLE TRIGGER "projects_touch_trg";

CREATE TRIGGER trg_project_meeting_scope_history AFTER UPDATE OF meeting_attendance_enabled ON projects FOR EACH ROW WHEN (old.meeting_attendance_enabled IS DISTINCT FROM new.meeting_attendance_enabled) EXECUTE FUNCTION log_project_meeting_scope_change();
ALTER TABLE "public"."projects" ENABLE TRIGGER "trg_project_meeting_scope_history";

CREATE TRIGGER push_subscriptions_lifecycle_trg BEFORE INSERT OR UPDATE ON push_subscriptions FOR EACH ROW EXECUTE FUNCTION push_subscription_apply_lifecycle();
ALTER TABLE "public"."push_subscriptions" ENABLE TRIGGER "push_subscriptions_lifecycle_trg";

CREATE TRIGGER push_subscriptions_touch_trg BEFORE UPDATE ON push_subscriptions FOR EACH ROW EXECUTE FUNCTION notification_touch_updated_at();
ALTER TABLE "public"."push_subscriptions" ENABLE TRIGGER "push_subscriptions_touch_trg";

CREATE TRIGGER recruitment_archive_touch_trg BEFORE UPDATE ON recruitment_archive FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."recruitment_archive" ENABLE TRIGGER "recruitment_archive_touch_trg";

CREATE TRIGGER todos_touch_trg BEFORE UPDATE ON todos FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."todos" ENABLE TRIGGER "todos_touch_trg";

CREATE TRIGGER transfers_touch_trg BEFORE UPDATE ON transfers FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."transfers" ENABLE TRIGGER "transfers_touch_trg";

CREATE TRIGGER uniform_touch_trg BEFORE UPDATE ON uniform FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."uniform" ENABLE TRIGGER "uniform_touch_trg";

CREATE TRIGGER uniform_deliveries_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_deliveries FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_deliveries" ENABLE TRIGGER "uniform_deliveries_terminal_guard_trg";

CREATE TRIGGER uniform_deliveries_updated_at_trg BEFORE UPDATE ON uniform_deliveries FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_deliveries" ENABLE TRIGGER "uniform_deliveries_updated_at_trg";

CREATE TRIGGER uniform_delivery_bills_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_delivery_bills FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_delivery_bills" ENABLE TRIGGER "uniform_delivery_bills_terminal_guard_trg";

CREATE TRIGGER uniform_delivery_bills_updated_at_trg BEFORE UPDATE ON uniform_delivery_bills FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_delivery_bills" ENABLE TRIGGER "uniform_delivery_bills_updated_at_trg";

CREATE TRIGGER uniform_delivery_bills_validate_trg BEFORE INSERT OR UPDATE ON uniform_delivery_bills FOR EACH ROW EXECUTE FUNCTION validate_uniform_delivery_bill();
ALTER TABLE "public"."uniform_delivery_bills" ENABLE TRIGGER "uniform_delivery_bills_validate_trg";

CREATE TRIGGER uniform_delivery_issues_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_delivery_issues FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_delivery_issues" ENABLE TRIGGER "uniform_delivery_issues_terminal_guard_trg";

CREATE TRIGGER uniform_delivery_issues_updated_at_trg BEFORE UPDATE ON uniform_delivery_issues FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_delivery_issues" ENABLE TRIGGER "uniform_delivery_issues_updated_at_trg";

CREATE TRIGGER uniform_delivery_items_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_delivery_items FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_delivery_items();
ALTER TABLE "public"."uniform_delivery_items" ENABLE TRIGGER "uniform_delivery_items_terminal_guard_trg";

CREATE TRIGGER uniform_items_updated_at_trg BEFORE UPDATE ON uniform_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_items" ENABLE TRIGGER "uniform_items_updated_at_trg";

CREATE TRIGGER uniform_allocations_touch_trg BEFORE UPDATE ON uniform_order_allocations FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."uniform_order_allocations" ENABLE TRIGGER "uniform_allocations_touch_trg";

CREATE TRIGGER uniform_order_employee_items_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_order_employee_items FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_employee_items();
ALTER TABLE "public"."uniform_order_employee_items" ENABLE TRIGGER "uniform_order_employee_items_terminal_guard_trg";

CREATE TRIGGER uniform_order_employee_items_updated_at_trg BEFORE UPDATE ON uniform_order_employee_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_order_employee_items" ENABLE TRIGGER "uniform_order_employee_items_updated_at_trg";

CREATE TRIGGER uniform_order_employees_duplicate_trg BEFORE INSERT OR UPDATE OF employee_id, is_active ON uniform_order_employees FOR EACH ROW EXECUTE FUNCTION prevent_duplicate_active_uniform_employee();
ALTER TABLE "public"."uniform_order_employees" ENABLE TRIGGER "uniform_order_employees_duplicate_trg";

CREATE TRIGGER uniform_order_employees_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_order_employees FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_order_employees" ENABLE TRIGGER "uniform_order_employees_terminal_guard_trg";

CREATE TRIGGER uniform_order_employees_updated_at_trg BEFORE UPDATE ON uniform_order_employees FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_order_employees" ENABLE TRIGGER "uniform_order_employees_updated_at_trg";

CREATE TRIGGER uniform_order_items_touch_trg BEFORE UPDATE ON uniform_order_items FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."uniform_order_items" ENABLE TRIGGER "uniform_order_items_touch_trg";

CREATE TRIGGER uniform_order_postponements_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_order_postponements FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_order_postponements" ENABLE TRIGGER "uniform_order_postponements_terminal_guard_trg";

CREATE TRIGGER uniform_orders_touch_trg BEFORE UPDATE ON uniform_orders FOR EACH ROW EXECUTE FUNCTION mghrm_touch_updated_at();
ALTER TABLE "public"."uniform_orders" ENABLE TRIGGER "uniform_orders_touch_trg";

CREATE TRIGGER uniform_requirement_reports_terminal_guard_trg BEFORE INSERT OR DELETE OR UPDATE ON uniform_requirement_reports FOR EACH ROW EXECUTE FUNCTION protect_terminal_uniform_order_children();
ALTER TABLE "public"."uniform_requirement_reports" ENABLE TRIGGER "uniform_requirement_reports_terminal_guard_trg";

CREATE TRIGGER uniform_suppliers_updated_at_trg BEFORE UPDATE ON uniform_suppliers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_suppliers" ENABLE TRIGGER "uniform_suppliers_updated_at_trg";

CREATE TRIGGER uniform_supply_orders_assign_number_trg BEFORE INSERT ON uniform_supply_orders FOR EACH ROW EXECUTE FUNCTION assign_uniform_order_number();
ALTER TABLE "public"."uniform_supply_orders" ENABLE TRIGGER "uniform_supply_orders_assign_number_trg";

CREATE TRIGGER uniform_supply_orders_integrity_trg BEFORE UPDATE ON uniform_supply_orders FOR EACH ROW EXECUTE FUNCTION protect_uniform_order_integrity();
ALTER TABLE "public"."uniform_supply_orders" ENABLE TRIGGER "uniform_supply_orders_integrity_trg";

CREATE TRIGGER uniform_supply_orders_status_validation_trg BEFORE UPDATE OF status ON uniform_supply_orders FOR EACH ROW EXECUTE FUNCTION validate_uniform_order_status_change();
ALTER TABLE "public"."uniform_supply_orders" ENABLE TRIGGER "uniform_supply_orders_status_validation_trg";

CREATE TRIGGER uniform_supply_orders_updated_at_trg BEFORE UPDATE ON uniform_supply_orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE "public"."uniform_supply_orders" ENABLE TRIGGER "uniform_supply_orders_updated_at_trg";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
ALTER TABLE "auth"."users" ENABLE TRIGGER "on_auth_user_created";
