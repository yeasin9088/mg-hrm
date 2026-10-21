-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

ALTER TABLE ONLY "public"."activity_log" ADD CONSTRAINT "activity_log_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."app_settings" ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY (setting_key);

ALTER TABLE ONLY "public"."career" ADD CONSTRAINT "career_change_id_key" UNIQUE (change_id);

ALTER TABLE ONLY "public"."career" ADD CONSTRAINT "career_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."demand" ADD CONSTRAINT "demand_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."demand" ADD CONSTRAINT "demand_project_name_key" UNIQUE (project_name);

ALTER TABLE ONLY "public"."designations" ADD CONSTRAINT "designations_pkey" PRIMARY KEY (desig_id);

ALTER TABLE ONLY "public"."disciplinary" ADD CONSTRAINT "disciplinary_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."districts" ADD CONSTRAINT "districts_pkey" PRIMARY KEY (district_id);

ALTER TABLE ONLY "public"."divisions" ADD CONSTRAINT "divisions_pkey" PRIMARY KEY (division_id);

ALTER TABLE ONLY "public"."employee_join_date_history" ADD CONSTRAINT "employee_join_date_history_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."employee_reactivations" ADD CONSTRAINT "employee_reactivations_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."employees" ADD CONSTRAINT "employees_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."employees" ADD CONSTRAINT "employees_status_check" CHECK (status = ANY (ARRAY['Active'::text, 'Inactive'::text]));

ALTER TABLE ONLY "public"."exits" ADD CONSTRAINT "exits_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."exits" ADD CONSTRAINT "exits_status_check" CHECK (status = ANY (ARRAY['Draft'::text, 'Clearance Pending'::text, 'Completed'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."leaves" ADD CONSTRAINT "leaves_leave_id_key" UNIQUE (leave_id);

ALTER TABLE ONLY "public"."leaves" ADD CONSTRAINT "leaves_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."meeting_attendance" ADD CONSTRAINT "meeting_attendance_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."meetings" ADD CONSTRAINT "meetings_meeting_id_key" UNIQUE (meeting_id);

ALTER TABLE ONLY "public"."meetings" ADD CONSTRAINT "meetings_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_attempt_check" CHECK (attempt_number >= 1);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_channel_check" CHECK (channel = ANY (ARRAY['InApp'::text, 'Toast'::text, 'WebPush'::text, 'System'::text]));

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_delivered_time_check" CHECK (delivery_status <> 'Delivered'::text OR delivered_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_failed_time_check" CHECK (delivery_status <> 'Failed'::text OR failed_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_metadata_check" CHECK (jsonb_typeof(response_metadata) = 'object'::text);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_push_target_check" CHECK (channel <> 'WebPush'::text OR subscription_id IS NOT NULL);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_sent_time_check" CHECK ((delivery_status <> ALL (ARRAY['Sent'::text, 'Delivered'::text])) OR sent_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_deliveries" ADD CONSTRAINT "notification_deliveries_status_check" CHECK (delivery_status = ANY (ARRAY['Pending'::text, 'Processing'::text, 'Sent'::text, 'Delivered'::text, 'Failed'::text, 'Skipped'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_after_check" CHECK (escalation_after_minutes > 0);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_category_not_blank" CHECK (btrim(category) <> ''::text);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_event_type_not_blank" CHECK (event_type IS NULL OR btrim(event_type) <> ''::text);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_first_repeat_check" CHECK (first_repeat_after_minutes IS NULL OR first_repeat_after_minutes > 0);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_maximum_repeat_check" CHECK (maximum_repeat_count IS NULL OR maximum_repeat_count >= 0);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_priority_check" CHECK (source_priority = ANY (ARRAY['Low'::text, 'Normal'::text, 'High'::text, 'Urgent'::text]));

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_repeat_interval_check" CHECK (repeat_every_minutes IS NULL OR repeat_every_minutes > 0);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_rule_key_not_blank" CHECK (btrim(rule_key) <> ''::text);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_rule_name_not_blank" CHECK (btrim(rule_name) <> ''::text);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_rules_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_target_required_check" CHECK (escalation_target_role IS NOT NULL OR escalation_target_user_id IS NOT NULL);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_target_role_not_blank" CHECK (escalation_target_role IS NULL OR btrim(escalation_target_role) <> ''::text);

ALTER TABLE ONLY "public"."notification_escalation_rules" ADD CONSTRAINT "notification_escalation_timing_order_check" CHECK (first_repeat_after_minutes IS NULL OR first_repeat_after_minutes <= escalation_after_minutes);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_entity_id_not_blank" CHECK (btrim(entity_id) <> ''::text);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_entity_type_not_blank" CHECK (btrim(entity_type) <> ''::text);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_key_not_blank" CHECK (btrim(event_key) <> ''::text);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_payload_object_check" CHECK (jsonb_typeof(event_payload) = 'object'::text);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_processing_status_check" CHECK (processing_status = ANY (ARRAY['Pending'::text, 'Processing'::text, 'Processed'::text, 'Ignored'::text, 'Failed'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."notification_events" ADD CONSTRAINT "notification_events_type_not_blank" CHECK (btrim(event_type) <> ''::text);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_attempt_count_check" CHECK (attempt_count >= 0);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_attempt_limit_check" CHECK (attempt_count <= maximum_attempts OR job_status = 'DeadLetter'::text);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_cancelled_lock_check" CHECK (job_status <> 'Cancelled'::text OR locked_at IS NULL);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_completed_time_check" CHECK (job_status <> 'Completed'::text OR completed_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_failed_time_check" CHECK ((job_status <> ALL (ARRAY['Failed'::text, 'DeadLetter'::text])) OR failed_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_maximum_attempts_check" CHECK (maximum_attempts >= 1 AND maximum_attempts <= 25);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_payload_object_check" CHECK (jsonb_typeof(job_payload) = 'object'::text);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_processing_lock_check" CHECK (job_status <> 'Processing'::text OR locked_at IS NOT NULL AND NULLIF(btrim(COALESCE(locked_by, ''::text)), ''::text) IS NOT NULL AND started_at IS NOT NULL);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_reference_check" CHECK (notification_id IS NOT NULL OR event_id IS NOT NULL);

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_status_check" CHECK (job_status = ANY (ARRAY['Pending'::text, 'Processing'::text, 'Completed'::text, 'Failed'::text, 'Cancelled'::text, 'DeadLetter'::text]));

ALTER TABLE ONLY "public"."notification_jobs" ADD CONSTRAINT "notification_jobs_type_not_blank" CHECK (btrim(job_type) <> ''::text);

ALTER TABLE ONLY "public"."notification_legacy_states" ADD CONSTRAINT "notification_legacy_states_check" CHECK (status = 'Snoozed'::text AND snoozed_until IS NOT NULL OR status <> 'Snoozed'::text AND snoozed_until IS NULL);

ALTER TABLE ONLY "public"."notification_legacy_states" ADD CONSTRAINT "notification_legacy_states_event_key_check" CHECK (length(event_key) >= 1 AND length(event_key) <= 1024);

ALTER TABLE ONLY "public"."notification_legacy_states" ADD CONSTRAINT "notification_legacy_states_pkey" PRIMARY KEY (user_id, event_key);

ALTER TABLE ONLY "public"."notification_legacy_states" ADD CONSTRAINT "notification_legacy_states_status_check" CHECK (status = ANY (ARRAY['Read'::text, 'Dismissed'::text, 'Snoozed'::text]));

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_category_not_blank" CHECK (btrim(category) <> ''::text);

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_priority_check" CHECK (minimum_priority = ANY (ARRAY['Low'::text, 'Normal'::text, 'High'::text, 'Urgent'::text]));

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_snooze_check" CHECK (default_snooze_minutes >= 1 AND default_snooze_minutes <= 10080);

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_timezone_not_blank" CHECK (btrim(timezone) <> ''::text);

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_toast_gap_check" CHECK (toast_gap_seconds >= 0 AND toast_gap_seconds <= 3600);

ALTER TABLE ONLY "public"."notification_preferences" ADD CONSTRAINT "notification_preferences_toast_max_check" CHECK (toast_max_visible >= 1 AND toast_max_visible <= 10);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_action_params_object_check" CHECK (jsonb_typeof(action_params) = 'object'::text);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_category_not_blank" CHECK (btrim(category) <> ''::text);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_completed_check" CHECK (status <> 'Completed'::text OR completed_at IS NOT NULL);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_dedupe_key_not_blank" CHECK (btrim(dedupe_key) <> ''::text);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_dismissed_check" CHECK (status <> 'Dismissed'::text OR dismissed_at IS NOT NULL);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_escalation_level_check" CHECK (escalation_level >= 0);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_expiry_check" CHECK (expires_at IS NULL OR expires_at > created_at);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_message_not_blank" CHECK (btrim(message) <> ''::text);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_parent_not_self_check" CHECK (parent_notification_id IS NULL OR parent_notification_id <> id);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_priority_check" CHECK (priority = ANY (ARRAY['Low'::text, 'Normal'::text, 'High'::text, 'Urgent'::text]));

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_repeat_count_check" CHECK (repeat_count >= 0);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_severity_check" CHECK (severity = ANY (ARRAY['Info'::text, 'Success'::text, 'Warning'::text, 'Critical'::text]));

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_snooze_check" CHECK (status <> 'Snoozed'::text OR snoozed_until IS NOT NULL);

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_status_check" CHECK (status = ANY (ARRAY['Scheduled'::text, 'Ready'::text, 'Delivered'::text, 'Read'::text, 'Actioned'::text, 'Snoozed'::text, 'Completed'::text, 'Dismissed'::text, 'Expired'::text, 'Cancelled'::text, 'Failed'::text]));

ALTER TABLE ONLY "public"."notifications" ADD CONSTRAINT "notifications_title_not_blank" CHECK (btrim(title) <> ''::text);

ALTER TABLE ONLY "public"."profiles" ADD CONSTRAINT "profiles_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."project_meeting_scope_history" ADD CONSTRAINT "project_meeting_scope_history_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."projects" ADD CONSTRAINT "projects_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."projects" ADD CONSTRAINT "projects_project_name_key" UNIQUE (project_name);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_auth_key_not_blank" CHECK (btrim(auth_key) <> ''::text);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_endpoint_hash_not_blank" CHECK (btrim(endpoint_hash) <> ''::text);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_endpoint_not_blank" CHECK (btrim(endpoint) <> ''::text);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_failure_count_check" CHECK (failure_count >= 0);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_failure_time_check" CHECK (last_failure_at IS NULL OR failure_count > 0);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_p256dh_not_blank" CHECK (btrim(p256dh_key) <> ''::text);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_permission_state_check" CHECK (permission_state = ANY (ARRAY['default'::text, 'granted'::text, 'denied'::text, 'revoked'::text, 'unsupported'::text]));

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."push_subscriptions" ADD CONSTRAINT "push_subscriptions_revocation_check" CHECK (revoked_at IS NULL OR is_active = false);

ALTER TABLE ONLY "public"."recruitment_archive" ADD CONSTRAINT "recruitment_archive_pkey" PRIMARY KEY (archive_id);

ALTER TABLE ONLY "public"."thanas" ADD CONSTRAINT "thanas_pkey" PRIMARY KEY (thana_id);

ALTER TABLE ONLY "public"."todos" ADD CONSTRAINT "todos_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."transfers" ADD CONSTRAINT "transfers_effective_date_required_check" CHECK ((status <> ALL (ARRAY['Scheduled'::text, 'Joining Pending'::text, 'Not Joined'::text])) OR effective_date IS NOT NULL);

ALTER TABLE ONLY "public"."transfers" ADD CONSTRAINT "transfers_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."transfers" ADD CONSTRAINT "transfers_status_check" CHECK (status = ANY (ARRAY['Draft'::text, 'Scheduled'::text, 'Joining Pending'::text, 'Completed'::text, 'Cancelled'::text, 'Not Joined'::text]));

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_issue_id_key" UNIQUE (issue_id);

ALTER TABLE ONLY "public"."uniform" ADD CONSTRAINT "uniform_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_order_id_delivery_sequence_key" UNIQUE (order_id, delivery_sequence);

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_sequence_chk" CHECK (delivery_sequence > 0);

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_status_chk" CHECK (status = ANY (ARRAY['Received'::text, 'Received with Issues'::text, 'Verified'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."uniform_deliveries" ADD CONSTRAINT "uniform_deliveries_type_chk" CHECK (delivery_type = ANY (ARRAY['Partial'::text, 'Remaining'::text, 'Full'::text, 'Supplementary'::text]));

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_amount_chk" CHECK (bill_amount > 0::numeric);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_confirmation_chk" CHECK (NOT head_office_confirmed OR confirmation_date IS NOT NULL);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_delivery_id_key" UNIQUE (delivery_id);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_number_chk" CHECK (btrim(document_number) <> ''::text);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_paid_chk" CHECK (NOT paid OR paid_date IS NOT NULL AND head_office_confirmed = true);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_delivery_bills" ADD CONSTRAINT "uniform_delivery_bills_type_chk" CHECK (document_type = ANY (ARRAY['Bill'::text, 'Challan'::text, 'Bill/Challan'::text]));

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_qty_chk" CHECK ((expected_quantity IS NULL OR expected_quantity >= 0) AND (received_quantity IS NULL OR received_quantity >= 0) AND (affected_quantity IS NULL OR affected_quantity > 0));

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_remarks_chk" CHECK (btrim(remarks) <> ''::text);

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_resolution_chk" CHECK ((resolution_status <> ALL (ARRAY['Resolved'::text, 'Cancelled'::text])) OR resolved_at IS NOT NULL);

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_status_chk" CHECK (resolution_status = ANY (ARRAY['Open'::text, 'In Progress'::text, 'Resolved'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."uniform_delivery_issues" ADD CONSTRAINT "uniform_delivery_issues_type_chk" CHECK (issue_type = ANY (ARRAY['Short Quantity'::text, 'Missing Item'::text, 'Wrong Size'::text, 'Damaged Item'::text, 'Modification Required'::text, 'Returned'::text, 'Replacement Pending'::text, 'Other'::text]));

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_delivered_chk" CHECK (delivered_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_expected_chk" CHECK (expected_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_delivery_items" ADD CONSTRAINT "uniform_delivery_items_unit_chk" CHECK (unit_snapshot = ANY (ARRAY['Piece'::text, 'Pair'::text]));

ALTER TABLE ONLY "public"."uniform_items" ADD CONSTRAINT "uniform_items_category_chk" CHECK (category = ANY (ARRAY['Uniform'::text, 'Footwear'::text, 'Accessory'::text, 'Safety Gear'::text, 'Winter Wear'::text, 'Other'::text]));

ALTER TABLE ONLY "public"."uniform_items" ADD CONSTRAINT "uniform_items_name_not_blank" CHECK (btrim(item_name) <> ''::text);

ALTER TABLE ONLY "public"."uniform_items" ADD CONSTRAINT "uniform_items_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_items" ADD CONSTRAINT "uniform_items_unit_chk" CHECK (unit = ANY (ARRAY['Piece'::text, 'Pair'::text]));

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_issued_quantity_check" CHECK (issued_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_order_id_order_item_id_employee_s_key" UNIQUE (order_id, order_item_id, employee_sys_id);

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_order_allocations" ADD CONSTRAINT "uniform_order_allocations_quantity_check" CHECK (quantity > 0);

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_category_chk" CHECK (category_snapshot = ANY (ARRAY['Uniform'::text, 'Footwear'::text, 'Accessory'::text, 'Safety Gear'::text, 'Winter Wear'::text, 'Other'::text]));

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_footwear_size_chk" CHECK (category_snapshot <> 'Footwear'::text OR btrim(COALESCE(size_text, ''::text)) <> ''::text);

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_qty_chk" CHECK (quantity > 0);

ALTER TABLE ONLY "public"."uniform_order_employee_items" ADD CONSTRAINT "uniform_order_employee_items_unit_chk" CHECK (unit_snapshot = ANY (ARRAY['Piece'::text, 'Pair'::text]));

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_nameplate_chk" CHECK (NOT nameplate_required OR btrim(COALESCE(nameplate_text, ''::text)) <> ''::text);

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_order_employees" ADD CONSTRAINT "uniform_order_employees_set_qty_chk" CHECK (set_quantity >= 0 AND set_quantity <= 2);

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_approved_quantity_check" CHECK (approved_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_delivered_quantity_check" CHECK (delivered_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_order_id_item_name_key" UNIQUE (order_id, item_name);

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_order_items" ADD CONSTRAINT "uniform_order_items_requested_quantity_check" CHECK (requested_quantity >= 0);

ALTER TABLE ONLY "public"."uniform_order_postponements" ADD CONSTRAINT "uniform_order_postponements_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_order_postponements" ADD CONSTRAINT "uniform_order_postponements_qty_chk" CHECK (set_quantity > 0);

ALTER TABLE ONLY "public"."uniform_order_postponements" ADD CONSTRAINT "uniform_order_postponements_reason_chk" CHECK (btrim(reason) <> ''::text);

ALTER TABLE ONLY "public"."uniform_order_postponements" ADD CONSTRAINT "uniform_order_postponements_status_chk" CHECK (status = ANY (ARRAY['Open'::text, 'Partially Activated'::text, 'Resolved'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."uniform_orders" ADD CONSTRAINT "uniform_orders_approved_sets_check" CHECK (approved_sets >= 0);

ALTER TABLE ONLY "public"."uniform_orders" ADD CONSTRAINT "uniform_orders_delivered_sets_check" CHECK (delivered_sets >= 0);

ALTER TABLE ONLY "public"."uniform_orders" ADD CONSTRAINT "uniform_orders_order_no_key" UNIQUE (order_no);

ALTER TABLE ONLY "public"."uniform_orders" ADD CONSTRAINT "uniform_orders_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_orders" ADD CONSTRAINT "uniform_orders_requested_sets_check" CHECK (requested_sets >= 0);

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_number_chk" CHECK (report_type = 'Main'::text AND revision_number IS NOT NULL AND revision_number > 0 AND supplementary_number IS NULL OR report_type = 'Supplementary'::text AND supplementary_number IS NOT NULL AND supplementary_number > 0);

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_snapshot_chk" CHECK (jsonb_typeof(report_snapshot) = 'object'::text);

ALTER TABLE ONLY "public"."uniform_requirement_reports" ADD CONSTRAINT "uniform_requirement_reports_type_chk" CHECK (report_type = ANY (ARRAY['Main'::text, 'Supplementary'::text]));

ALTER TABLE ONLY "public"."uniform_suppliers" ADD CONSTRAINT "uniform_suppliers_name_not_blank" CHECK (btrim(supplier_name) <> ''::text);

ALTER TABLE ONLY "public"."uniform_suppliers" ADD CONSTRAINT "uniform_suppliers_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_approval_data_chk" CHECK ((status <> ALL (ARRAY['Requisition Approved'::text, 'Measurement Completed'::text, 'Items Finalized'::text, 'Requirements Submitted'::text, 'Assigned to Supplier'::text, 'In Production'::text, 'Ready for Delivery'::text, 'Partially Delivered'::text, 'Delivered'::text, 'Completed'::text])) OR approved_sets IS NOT NULL AND requisition_approved_at IS NOT NULL);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_approved_sets_chk" CHECK (approved_sets IS NULL OR approved_sets > 0);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_cancel_reason_chk" CHECK (status <> 'Cancelled'::text OR btrim(COALESCE(cancellation_reason, ''::text)) <> ''::text);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_measurement_data_chk" CHECK ((status <> ALL (ARRAY['Measurement Completed'::text, 'Items Finalized'::text, 'Requirements Submitted'::text, 'Assigned to Supplier'::text, 'In Production'::text, 'Ready for Delivery'::text, 'Partially Delivered'::text, 'Delivered'::text, 'Completed'::text])) OR measurement_completed_at IS NOT NULL);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_number_format_chk" CHECK (order_number ~ '^[0-9]{9}$'::text);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_order_number_key" UNIQUE (order_number);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_pkey" PRIMARY KEY (id);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_requested_sets_chk" CHECK (requested_sets > 0);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_status_chk" CHECK (status = ANY (ARRAY['Draft'::text, 'Confirmed'::text, 'Requisition Submitted'::text, 'Requisition Approved'::text, 'Measurement Completed'::text, 'Items Finalized'::text, 'Requirements Submitted'::text, 'Assigned to Supplier'::text, 'In Production'::text, 'Ready for Delivery'::text, 'Partially Delivered'::text, 'Delivered'::text, 'Completed'::text, 'Cancelled'::text]));

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_supplier_data_chk" CHECK ((status <> ALL (ARRAY['Assigned to Supplier'::text, 'In Production'::text, 'Ready for Delivery'::text, 'Partially Delivered'::text, 'Delivered'::text, 'Completed'::text])) OR supplier_id IS NOT NULL AND supplier_assigned_at IS NOT NULL);

ALTER TABLE ONLY "public"."uniform_supply_orders" ADD CONSTRAINT "uniform_supply_orders_terminal_timestamp_chk" CHECK ((status <> 'Completed'::text OR completed_at IS NOT NULL) AND (status <> 'Cancelled'::text OR cancelled_at IS NOT NULL));
