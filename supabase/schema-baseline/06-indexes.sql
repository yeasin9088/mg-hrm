-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

CREATE INDEX activity_created_idx ON public.activity_log USING btree (created_at DESC);
-- "public"."activity_log_pkey" is created by constraint "activity_log_pkey" on "public"."activity_log".
CREATE INDEX app_settings_deleted_idx ON public.app_settings USING btree (deleted_at);
-- "public"."app_settings_pkey" is created by constraint "app_settings_pkey" on "public"."app_settings".
-- "public"."career_change_id_key" is created by constraint "career_change_id_key" on "public"."career".
CREATE INDEX career_date_idx ON public.career USING btree (effective_date);
CREATE INDEX career_deleted_idx ON public.career USING btree (deleted_at);
-- "public"."career_pkey" is created by constraint "career_pkey" on "public"."career".
CREATE INDEX demand_deleted_idx ON public.demand USING btree (deleted_at);
-- "public"."demand_pkey" is created by constraint "demand_pkey" on "public"."demand".
-- "public"."demand_project_name_key" is created by constraint "demand_project_name_key" on "public"."demand".
-- "public"."designations_pkey" is created by constraint "designations_pkey" on "public"."designations".
CREATE UNIQUE INDEX disciplinary_action_id_key ON public.disciplinary USING btree (action_id);
CREATE INDEX disciplinary_deleted_idx ON public.disciplinary USING btree (deleted_at);
CREATE INDEX disciplinary_emp_idx ON public.disciplinary USING btree (employee_id);
-- "public"."disciplinary_pkey" is created by constraint "disciplinary_pkey" on "public"."disciplinary".
-- "public"."districts_pkey" is created by constraint "districts_pkey" on "public"."districts".
-- "public"."divisions_pkey" is created by constraint "divisions_pkey" on "public"."divisions".
CREATE INDEX employee_join_date_history_employee_idx ON public.employee_join_date_history USING btree (employee_id, changed_at DESC);
-- "public"."employee_join_date_history_pkey" is created by constraint "employee_join_date_history_pkey" on "public"."employee_join_date_history".
CREATE INDEX employee_reactivations_employee_idx ON public.employee_reactivations USING btree (employee_sys_id, reactivated_at DESC);
-- "public"."employee_reactivations_pkey" is created by constraint "employee_reactivations_pkey" on "public"."employee_reactivations".
CREATE INDEX employees_deleted_idx ON public.employees USING btree (deleted_at);
CREATE INDEX employees_desig_idx ON public.employees USING btree (designation);
CREATE INDEX employees_empid_idx ON public.employees USING btree (employee_id);
-- "public"."employees_pkey" is created by constraint "employees_pkey" on "public"."employees".
CREATE INDEX employees_project_idx ON public.employees USING btree (project_name);
CREATE INDEX employees_status_idx ON public.employees USING btree (status);
CREATE INDEX exits_date_idx ON public.exits USING btree (exit_date);
CREATE INDEX exits_deleted_idx ON public.exits USING btree (deleted_at);
CREATE INDEX exits_employee_sys_id_idx ON public.exits USING btree (employee_sys_id);
CREATE UNIQUE INDEX exits_one_open_per_employee_uidx ON public.exits USING btree (employee_sys_id) WHERE ((deleted_at IS NULL) AND (employee_sys_id IS NOT NULL) AND (status = ANY (ARRAY['Draft'::text, 'Clearance Pending'::text])));
-- "public"."exits_pkey" is created by constraint "exits_pkey" on "public"."exits".
CREATE INDEX exits_related_transfer_idx ON public.exits USING btree (related_transfer_id) WHERE (related_transfer_id IS NOT NULL);
CREATE INDEX exits_status_idx ON public.exits USING btree (status) WHERE (deleted_at IS NULL);
CREATE INDEX leaves_deleted_idx ON public.leaves USING btree (deleted_at);
-- "public"."leaves_leave_id_key" is created by constraint "leaves_leave_id_key" on "public"."leaves".
-- "public"."leaves_pkey" is created by constraint "leaves_pkey" on "public"."leaves".
CREATE INDEX leaves_status_idx ON public.leaves USING btree (status);
CREATE INDEX att_meeting_idx ON public.meeting_attendance USING btree (meeting_id);
CREATE INDEX meeting_attendance_deleted_idx ON public.meeting_attendance USING btree (deleted_at);
-- "public"."meeting_attendance_pkey" is created by constraint "meeting_attendance_pkey" on "public"."meeting_attendance".
-- "public"."unique_attendance" is created by constraint "unique_attendance" on "public"."meeting_attendance".
CREATE INDEX meetings_deleted_idx ON public.meetings USING btree (deleted_at);
-- "public"."meetings_meeting_id_key" is created by constraint "meetings_meeting_id_key" on "public"."meetings".
-- "public"."meetings_pkey" is created by constraint "meetings_pkey" on "public"."meetings".
CREATE UNIQUE INDEX notification_deliveries_attempt_uidx ON public.notification_deliveries USING btree (notification_id, channel, COALESCE(subscription_id, (0)::bigint), attempt_number);
CREATE INDEX notification_deliveries_failure_idx ON public.notification_deliveries USING btree (failed_at DESC, error_code) WHERE (delivery_status = 'Failed'::text);
CREATE INDEX notification_deliveries_notification_idx ON public.notification_deliveries USING btree (notification_id, created_at DESC);
CREATE INDEX notification_deliveries_pending_idx ON public.notification_deliveries USING btree (delivery_status, created_at) WHERE (delivery_status = ANY (ARRAY['Pending'::text, 'Processing'::text, 'Failed'::text]));
-- "public"."notification_deliveries_pkey" is created by constraint "notification_deliveries_pkey" on "public"."notification_deliveries".
CREATE INDEX notification_deliveries_subscription_idx ON public.notification_deliveries USING btree (subscription_id, created_at DESC) WHERE (subscription_id IS NOT NULL);
CREATE INDEX notification_escalation_rules_lookup_idx ON public.notification_escalation_rules USING btree (category, event_type, source_priority) WHERE (is_enabled = true);
-- "public"."notification_escalation_rules_pkey" is created by constraint "notification_escalation_rules_pkey" on "public"."notification_escalation_rules".
CREATE UNIQUE INDEX notification_escalation_rules_rule_key_uidx ON public.notification_escalation_rules USING btree (rule_key);
CREATE INDEX notification_escalation_rules_target_role_idx ON public.notification_escalation_rules USING btree (escalation_target_role) WHERE ((escalation_target_role IS NOT NULL) AND (is_enabled = true));
CREATE INDEX notification_escalation_rules_target_user_idx ON public.notification_escalation_rules USING btree (escalation_target_user_id) WHERE ((escalation_target_user_id IS NOT NULL) AND (is_enabled = true));
CREATE INDEX notification_events_employee_idx ON public.notification_events USING btree (employee_sys_id) WHERE (employee_sys_id IS NOT NULL);
CREATE INDEX notification_events_entity_idx ON public.notification_events USING btree (entity_type, entity_id);
CREATE UNIQUE INDEX notification_events_event_key_uidx ON public.notification_events USING btree (event_key);
-- "public"."notification_events_pkey" is created by constraint "notification_events_pkey" on "public"."notification_events".
CREATE INDEX notification_events_processing_idx ON public.notification_events USING btree (processing_status, occurred_at);
CREATE INDEX notification_events_project_idx ON public.notification_events USING btree (project_id) WHERE (project_id IS NOT NULL);
CREATE INDEX notification_jobs_due_idx ON public.notification_jobs USING btree (run_at, id) WHERE (job_status = ANY (ARRAY['Pending'::text, 'Failed'::text]));
CREATE INDEX notification_jobs_event_idx ON public.notification_jobs USING btree (event_id, created_at DESC) WHERE (event_id IS NOT NULL);
CREATE INDEX notification_jobs_failure_idx ON public.notification_jobs USING btree (job_status, failed_at DESC) WHERE (job_status = ANY (ARRAY['Failed'::text, 'DeadLetter'::text]));
CREATE INDEX notification_jobs_notification_idx ON public.notification_jobs USING btree (notification_id, created_at DESC) WHERE (notification_id IS NOT NULL);
CREATE UNIQUE INDEX notification_jobs_open_dedupe_uidx ON public.notification_jobs USING btree (job_type, COALESCE(notification_id, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(event_id, (0)::bigint)) WHERE (job_status = ANY (ARRAY['Pending'::text, 'Processing'::text, 'Failed'::text]));
-- "public"."notification_jobs_pkey" is created by constraint "notification_jobs_pkey" on "public"."notification_jobs".
CREATE INDEX notification_jobs_processing_lock_idx ON public.notification_jobs USING btree (locked_at, id) WHERE (job_status = 'Processing'::text);
-- "public"."notification_preferences_pkey" is created by constraint "notification_preferences_pkey" on "public"."notification_preferences".
CREATE UNIQUE INDEX notification_preferences_user_category_uidx ON public.notification_preferences USING btree (user_id, category);
CREATE INDEX notification_preferences_user_idx ON public.notification_preferences USING btree (user_id);
CREATE INDEX notifications_employee_idx ON public.notifications USING btree (employee_sys_id) WHERE (employee_sys_id IS NOT NULL);
CREATE INDEX notifications_entity_idx ON public.notifications USING btree (entity_type, entity_id) WHERE ((entity_type IS NOT NULL) AND (entity_id IS NOT NULL));
CREATE INDEX notifications_event_idx ON public.notifications USING btree (event_id) WHERE (event_id IS NOT NULL);
CREATE INDEX notifications_parent_idx ON public.notifications USING btree (parent_notification_id) WHERE (parent_notification_id IS NOT NULL);
-- "public"."notifications_pkey" is created by constraint "notifications_pkey" on "public"."notifications".
CREATE INDEX notifications_project_idx ON public.notifications USING btree (project_id) WHERE (project_id IS NOT NULL);
CREATE UNIQUE INDEX notifications_recipient_dedupe_open_uidx ON public.notifications USING btree (recipient_user_id, dedupe_key) WHERE (status = ANY (ARRAY['Scheduled'::text, 'Ready'::text, 'Delivered'::text, 'Read'::text, 'Actioned'::text, 'Snoozed'::text, 'Failed'::text]));
CREATE INDEX notifications_recipient_inbox_idx ON public.notifications USING btree (recipient_user_id, created_at DESC);
CREATE INDEX notifications_recipient_unread_idx ON public.notifications USING btree (recipient_user_id, created_at DESC) WHERE ((read_at IS NULL) AND (status <> ALL (ARRAY['Completed'::text, 'Dismissed'::text, 'Expired'::text, 'Cancelled'::text])));
CREATE INDEX notifications_schedule_idx ON public.notifications USING btree (status, scheduled_for) WHERE (status = ANY (ARRAY['Scheduled'::text, 'Ready'::text, 'Snoozed'::text, 'Failed'::text]));
-- "public"."profiles_pkey" is created by constraint "profiles_pkey" on "public"."profiles".
-- "public"."project_meeting_scope_history_pkey" is created by constraint "project_meeting_scope_history_pkey" on "public"."project_meeting_scope_history".
CREATE INDEX project_meeting_scope_history_project_idx ON public.project_meeting_scope_history USING btree (project_record_id, changed_at DESC);
CREATE INDEX projects_deleted_idx ON public.projects USING btree (deleted_at);
CREATE INDEX projects_meeting_attendance_enabled_idx ON public.projects USING btree (meeting_attendance_enabled);
-- "public"."projects_pkey" is created by constraint "projects_pkey" on "public"."projects".
-- "public"."projects_project_name_key" is created by constraint "projects_project_name_key" on "public"."projects".
CREATE INDEX push_subscriptions_active_user_idx ON public.push_subscriptions USING btree (user_id, last_seen_at DESC) WHERE ((is_active = true) AND (permission_state = 'granted'::text) AND (revoked_at IS NULL));
CREATE UNIQUE INDEX push_subscriptions_endpoint_hash_uidx ON public.push_subscriptions USING btree (endpoint_hash);
CREATE INDEX push_subscriptions_health_idx ON public.push_subscriptions USING btree (is_active, permission_state, failure_count, last_failure_at);
-- "public"."push_subscriptions_pkey" is created by constraint "push_subscriptions_pkey" on "public"."push_subscriptions".
CREATE INDEX recruitment_archive_at_idx ON public.recruitment_archive USING btree (decided_at DESC);
CREATE INDEX recruitment_archive_deleted_idx ON public.recruitment_archive USING btree (deleted_at);
-- "public"."recruitment_archive_pkey" is created by constraint "recruitment_archive_pkey" on "public"."recruitment_archive".
-- "public"."thanas_pkey" is created by constraint "thanas_pkey" on "public"."thanas".
CREATE INDEX idx_todos_created_at ON public.todos USING btree (created_at DESC);
CREATE INDEX idx_todos_important ON public.todos USING btree (is_important) WHERE (is_important = true);
CREATE INDEX idx_todos_next_reminder ON public.todos USING btree (next_reminder_at) WHERE ((reminder_enabled = true) AND (next_reminder_at IS NOT NULL));
CREATE INDEX idx_todos_remind_on ON public.todos USING btree (remind_on) WHERE (remind_on IS NOT NULL);
CREATE INDEX todos_assigned_next_reminder_idx ON public.todos USING btree (assigned_to_user_id, next_reminder_at) WHERE ((deleted_at IS NULL) AND (reminder_enabled = true) AND (next_reminder_at IS NOT NULL));
CREATE INDEX todos_assigned_user_idx ON public.todos USING btree (assigned_to_user_id) WHERE (deleted_at IS NULL);
CREATE INDEX todos_deleted_idx ON public.todos USING btree (deleted_at);
CREATE INDEX todos_owner_user_idx ON public.todos USING btree (owner_user_id);
-- "public"."todos_pkey" is created by constraint "todos_pkey" on "public"."todos".
CREATE INDEX transfers_action_queue_idx ON public.transfers USING btree (status, effective_date) WHERE (deleted_at IS NULL);
CREATE INDEX transfers_date_idx ON public.transfers USING btree (transfer_date);
CREATE INDEX transfers_deleted_idx ON public.transfers USING btree (deleted_at);
CREATE INDEX transfers_employee_sys_id_idx ON public.transfers USING btree (employee_sys_id);
CREATE INDEX transfers_open_employee_idx ON public.transfers USING btree (employee_sys_id, status) WHERE ((deleted_at IS NULL) AND (employee_sys_id IS NOT NULL) AND (status = ANY (ARRAY['Draft'::text, 'Scheduled'::text, 'Joining Pending'::text, 'Not Joined'::text])));
-- "public"."transfers_pkey" is created by constraint "transfers_pkey" on "public"."transfers".
CREATE INDEX uniform_deleted_idx ON public.uniform USING btree (deleted_at);
CREATE INDEX uniform_emp_idx ON public.uniform USING btree (employee_id);
-- "public"."uniform_issue_id_key" is created by constraint "uniform_issue_id_key" on "public"."uniform".
-- "public"."uniform_pkey" is created by constraint "uniform_pkey" on "public"."uniform".
CREATE INDEX uniform_source_allocation_idx ON public.uniform USING btree (uniform_order_allocation_id);
CREATE INDEX uniform_source_order_idx ON public.uniform USING btree (uniform_order_id);
CREATE INDEX uniform_deliveries_order_date_idx ON public.uniform_deliveries USING btree (order_id, delivery_date);
-- "public"."uniform_deliveries_order_id_delivery_sequence_key" is created by constraint "uniform_deliveries_order_id_delivery_sequence_key" on "public"."uniform_deliveries".
-- "public"."uniform_deliveries_pkey" is created by constraint "uniform_deliveries_pkey" on "public"."uniform_deliveries".
-- "public"."uniform_delivery_bills_delivery_id_key" is created by constraint "uniform_delivery_bills_delivery_id_key" on "public"."uniform_delivery_bills".
CREATE UNIQUE INDEX uniform_delivery_bills_order_document_uidx ON public.uniform_delivery_bills USING btree (order_id, lower(btrim(document_number)));
CREATE INDEX uniform_delivery_bills_payment_idx ON public.uniform_delivery_bills USING btree (order_id, head_office_confirmed, paid);
-- "public"."uniform_delivery_bills_pkey" is created by constraint "uniform_delivery_bills_pkey" on "public"."uniform_delivery_bills".
CREATE INDEX uniform_delivery_issues_delivery_idx ON public.uniform_delivery_issues USING btree (delivery_id);
CREATE INDEX uniform_delivery_issues_order_status_idx ON public.uniform_delivery_issues USING btree (order_id, resolution_status);
-- "public"."uniform_delivery_issues_pkey" is created by constraint "uniform_delivery_issues_pkey" on "public"."uniform_delivery_issues".
CREATE INDEX uniform_delivery_items_allocation_idx ON public.uniform_delivery_items USING btree (order_employee_id);
CREATE INDEX uniform_delivery_items_delivery_idx ON public.uniform_delivery_items USING btree (delivery_id);
-- "public"."uniform_delivery_items_pkey" is created by constraint "uniform_delivery_items_pkey" on "public"."uniform_delivery_items".
CREATE INDEX uniform_items_active_category_idx ON public.uniform_items USING btree (is_active, category, item_name);
CREATE UNIQUE INDEX uniform_items_name_normalized_uidx ON public.uniform_items USING btree (lower(btrim(item_name)));
-- "public"."uniform_items_pkey" is created by constraint "uniform_items_pkey" on "public"."uniform_items".
CREATE INDEX uniform_allocations_employee_idx ON public.uniform_order_allocations USING btree (employee_sys_id);
CREATE INDEX uniform_allocations_issue_status_idx ON public.uniform_order_allocations USING btree (issue_status);
CREATE INDEX uniform_allocations_item_idx ON public.uniform_order_allocations USING btree (order_item_id);
CREATE INDEX uniform_allocations_order_idx ON public.uniform_order_allocations USING btree (order_id);
-- "public"."uniform_order_allocations_order_id_order_item_id_employee_s_key" is created by constraint "uniform_order_allocations_order_id_order_item_id_employee_s_key" on "public"."uniform_order_allocations".
-- "public"."uniform_order_allocations_pkey" is created by constraint "uniform_order_allocations_pkey" on "public"."uniform_order_allocations".
CREATE INDEX uniform_order_employee_items_allocation_idx ON public.uniform_order_employee_items USING btree (order_employee_id);
-- "public"."uniform_order_employee_items_pkey" is created by constraint "uniform_order_employee_items_pkey" on "public"."uniform_order_employee_items".
CREATE UNIQUE INDEX uniform_order_employee_items_unique_idx ON public.uniform_order_employee_items USING btree (order_employee_id, item_id, COALESCE(lower(btrim(size_text)), ''::text));
CREATE UNIQUE INDEX uniform_order_employees_active_order_employee_uidx ON public.uniform_order_employees USING btree (order_id, employee_id) WHERE (is_active = true);
CREATE INDEX uniform_order_employees_employee_idx ON public.uniform_order_employees USING btree (employee_id, is_active);
CREATE INDEX uniform_order_employees_order_idx ON public.uniform_order_employees USING btree (order_id, is_active);
-- "public"."uniform_order_employees_pkey" is created by constraint "uniform_order_employees_pkey" on "public"."uniform_order_employees".
-- "public"."uniform_order_items_order_id_item_name_key" is created by constraint "uniform_order_items_order_id_item_name_key" on "public"."uniform_order_items".
CREATE INDEX uniform_order_items_order_idx ON public.uniform_order_items USING btree (order_id);
-- "public"."uniform_order_items_pkey" is created by constraint "uniform_order_items_pkey" on "public"."uniform_order_items".
CREATE INDEX uniform_order_postponements_order_status_idx ON public.uniform_order_postponements USING btree (order_id, status);
-- "public"."uniform_order_postponements_pkey" is created by constraint "uniform_order_postponements_pkey" on "public"."uniform_order_postponements".
CREATE INDEX uniform_orders_demand_date_idx ON public.uniform_orders USING btree (demand_date);
-- "public"."uniform_orders_order_no_key" is created by constraint "uniform_orders_order_no_key" on "public"."uniform_orders".
CREATE INDEX uniform_orders_payment_idx ON public.uniform_orders USING btree (payment_status);
-- "public"."uniform_orders_pkey" is created by constraint "uniform_orders_pkey" on "public"."uniform_orders".
CREATE INDEX uniform_orders_project_idx ON public.uniform_orders USING btree (project_name);
CREATE INDEX uniform_orders_requisition_idx ON public.uniform_orders USING btree (requisition_no);
CREATE INDEX uniform_orders_status_idx ON public.uniform_orders USING btree (status);
CREATE INDEX uniform_orders_work_order_idx ON public.uniform_orders USING btree (work_order_no);
CREATE UNIQUE INDEX uniform_requirement_reports_current_type_uidx ON public.uniform_requirement_reports USING btree (order_id, report_type) WHERE (is_current = true);
CREATE UNIQUE INDEX uniform_requirement_reports_main_revision_uidx ON public.uniform_requirement_reports USING btree (order_id, revision_number) WHERE (report_type = 'Main'::text);
-- "public"."uniform_requirement_reports_pkey" is created by constraint "uniform_requirement_reports_pkey" on "public"."uniform_requirement_reports".
CREATE UNIQUE INDEX uniform_requirement_reports_supplementary_uidx ON public.uniform_requirement_reports USING btree (order_id, supplementary_number) WHERE (report_type = 'Supplementary'::text);
CREATE INDEX uniform_suppliers_active_idx ON public.uniform_suppliers USING btree (is_active, supplier_name);
CREATE UNIQUE INDEX uniform_suppliers_name_normalized_uidx ON public.uniform_suppliers USING btree (lower(btrim(supplier_name)));
-- "public"."uniform_suppliers_pkey" is created by constraint "uniform_suppliers_pkey" on "public"."uniform_suppliers".
CREATE INDEX uniform_supply_orders_created_idx ON public.uniform_supply_orders USING btree (created_at DESC);
-- "public"."uniform_supply_orders_order_number_key" is created by constraint "uniform_supply_orders_order_number_key" on "public"."uniform_supply_orders".
-- "public"."uniform_supply_orders_pkey" is created by constraint "uniform_supply_orders_pkey" on "public"."uniform_supply_orders".
CREATE INDEX uniform_supply_orders_project_status_idx ON public.uniform_supply_orders USING btree (project_id, status);
CREATE INDEX uniform_supply_orders_supplier_status_idx ON public.uniform_supply_orders USING btree (supplier_id, status);
