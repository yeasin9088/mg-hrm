-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

ALTER TABLE ONLY "public"."career" ADD CONSTRAINT "career_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."disciplinary" ADD CONSTRAINT "disciplinary_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."employee_join_date_history" ADD CONSTRAINT "employee_join_date_history_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."employee_reactivations" ADD CONSTRAINT "employee_reactivations_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."employee_reactivations" ADD CONSTRAINT "employee_reactivations_previous_exit_id_fkey" FOREIGN KEY (previous_exit_id) REFERENCES exits(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."exits" ADD CONSTRAINT "exits_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."exits" ADD CONSTRAINT "exits_related_transfer_id_fkey" FOREIGN KEY (related_transfer_id) REFERENCES transfers(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."leaves" ADD CONSTRAINT "leaves_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_notification_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_subscription_fkey" FOREIGN KEY (subscription_id) REFERENCES push_subscriptions(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_created_by_fkey" FOREIGN KEY (created_by_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_target_user_fkey" FOREIGN KEY (escalation_target_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_updated_by_fkey" FOREIGN KEY (updated_by_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_actor_fkey" FOREIGN KEY (actor_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_employee_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_project_fkey" FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_event_fkey" FOREIGN KEY (event_id) REFERENCES notification_events(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_notification_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_user_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_employee_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_escalation_rule_fkey" FOREIGN KEY (escalation_rule_id) REFERENCES notification_escalation_rules(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_event_fkey" FOREIGN KEY (event_id) REFERENCES notification_events(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_parent_fkey" FOREIGN KEY (parent_notification_id) REFERENCES notifications(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_project_fkey" FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_recipient_fkey" FOREIGN KEY (recipient_user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."profiles" ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_user_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."todos" ADD CONSTRAINT "todos_assigned_to_user_id_fkey" FOREIGN KEY (assigned_to_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."todos" ADD CONSTRAINT "todos_owner_user_id_fkey" FOREIGN KEY (owner_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."transfers" ADD CONSTRAINT "transfers_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_replacement_for_id_fkey" FOREIGN KEY (replacement_for_id) REFERENCES uniform(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_uniform_order_allocation_id_fkey" FOREIGN KEY (uniform_order_allocation_id) REFERENCES uniform_order_allocations(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_uniform_order_id_fkey" FOREIGN KEY (uniform_order_id) REFERENCES uniform_orders(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_uniform_order_item_id_fkey" FOREIGN KEY (uniform_order_item_id) REFERENCES uniform_order_items(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_delivery_id_fkey" FOREIGN KEY (delivery_id) REFERENCES uniform_deliveries(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_delivery_id_fkey" FOREIGN KEY (delivery_id) REFERENCES uniform_deliveries(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_item_id_fkey" FOREIGN KEY (item_id) REFERENCES uniform_items(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_order_employee_id_fkey" FOREIGN KEY (order_employee_id) REFERENCES uniform_order_employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_delivery_id_fkey" FOREIGN KEY (delivery_id) REFERENCES uniform_deliveries(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_item_id_fkey" FOREIGN KEY (item_id) REFERENCES uniform_items(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_order_employee_id_fkey" FOREIGN KEY (order_employee_id) REFERENCES uniform_order_employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_employee_sys_id_fkey" FOREIGN KEY (employee_sys_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_orders(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_order_item_id_fkey" FOREIGN KEY (order_item_id) REFERENCES uniform_order_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_item_id_fkey" FOREIGN KEY (item_id) REFERENCES uniform_items(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_order_employee_id_fkey" FOREIGN KEY (order_employee_id) REFERENCES uniform_order_employees(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_delivery_project_id_fkey" FOREIGN KEY (delivery_project_id) REFERENCES projects(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_original_project_id_fkey" FOREIGN KEY (original_project_id) REFERENCES projects(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_replaced_allocation_id_fkey" FOREIGN KEY (replaced_allocation_id) REFERENCES uniform_order_employees(id) ON DELETE SET NULL;

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_orders(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_order_postponements" ADD CONSTRAINT "uniform_order_postponements_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_order_id_fkey" FOREIGN KEY (order_id) REFERENCES uniform_supply_orders(id) ON DELETE CASCADE;

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_supersedes_report_id_fkey" FOREIGN KEY (supersedes_report_id) REFERENCES uniform_requirement_reports(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_supplier_id_fkey" FOREIGN KEY (supplier_id) REFERENCES uniform_suppliers(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_project_id_fkey" FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_supplier_id_fkey" FOREIGN KEY (supplier_id) REFERENCES uniform_suppliers(id) ON DELETE RESTRICT;
