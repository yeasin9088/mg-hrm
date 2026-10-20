-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- Faithful CURRENT grants, including broad legacy grants. No remediation.
-- SET ROLE preserves recorded grantors; managed role membership is a prerequisite.

-- Original ACL: {pg_database_owner=UC/pg_database_owner,=U/pg_database_owner,postgres=U/pg_database_owner,anon=U/pg_database_owner,authenticated=U/pg_database_owner,service_role=U/pg_database_owner}
SET ROLE "pg_database_owner";
REVOKE ALL PRIVILEGES ON SCHEMA "public" FROM PUBLIC, "anon", "authenticated", "pg_database_owner", "postgres", "service_role";
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE, CREATE ON SCHEMA "public" TO "pg_database_owner";
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE ON SCHEMA "public" TO PUBLIC;
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE ON SCHEMA "public" TO "postgres";
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE ON SCHEMA "public" TO "anon";
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
RESET ROLE;
SET ROLE "pg_database_owner";
GRANT USAGE ON SCHEMA "public" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."activity_log" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."activity_log" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."activity_log" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."activity_log" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."activity_log" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."app_settings" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."app_settings" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."app_settings" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."app_settings" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."app_settings" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."career" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."career" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."career" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."career" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."career" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."demand" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."demand" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."demand" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."demand" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."demand" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."designations" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."designations" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."designations" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."designations" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."designations" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."disciplinary" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."disciplinary" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."disciplinary" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."disciplinary" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."disciplinary" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."districts" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."districts" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."districts" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."districts" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."districts" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."divisions" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."divisions" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."divisions" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."divisions" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."divisions" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."employee_join_date_history" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_join_date_history" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_join_date_history" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_join_date_history" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_join_date_history" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."employee_reactivations" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_reactivations" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_reactivations" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_reactivations" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employee_reactivations" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."employees" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employees" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employees" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employees" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."employees" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."exits" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."exits" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."exits" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."exits" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."exits" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."leaves" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."leaves" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."leaves" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."leaves" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."leaves" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."meeting_attendance" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meeting_attendance" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meeting_attendance" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meeting_attendance" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meeting_attendance" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."meetings" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meetings" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meetings" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meetings" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."meetings" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notification_deliveries" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_deliveries" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_deliveries" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT ON TABLE "public"."notification_deliveries" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=arwd/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notification_escalation_rules" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_escalation_rules" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_escalation_rules" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE ON TABLE "public"."notification_escalation_rules" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notification_events" FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_events" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_events" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notification_jobs" FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_jobs" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_jobs" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=arwd/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notification_preferences" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_preferences" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notification_preferences" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE ON TABLE "public"."notification_preferences" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."notifications" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notifications" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."notifications" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT ON TABLE "public"."notifications" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."profiles" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."profiles" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."profiles" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."profiles" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."project_meeting_scope_history" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."project_meeting_scope_history" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."project_meeting_scope_history" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."project_meeting_scope_history" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."project_meeting_scope_history" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."projects" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."projects" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."projects" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."projects" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."projects" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=aw/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."push_subscriptions" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."push_subscriptions" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."push_subscriptions" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, UPDATE ON TABLE "public"."push_subscriptions" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."recruitment_archive" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."recruitment_archive" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."recruitment_archive" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."recruitment_archive" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."recruitment_archive" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."thanas" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."thanas" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."thanas" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."thanas" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."thanas" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."todos" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."todos_backup_20260928" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos_backup_20260928" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos_backup_20260928" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos_backup_20260928" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."todos_backup_20260928" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."transfers" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."transfers" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."transfers" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."transfers" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."transfers" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_deliveries" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_deliveries" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_deliveries" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_deliveries" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_deliveries" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_delivery_bills" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_bills" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_bills" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_bills" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_bills" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_delivery_issues" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_issues" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_issues" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_issues" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_issues" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_delivery_items" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_items" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_items" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_items" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_delivery_items" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_items" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_items" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_items" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_items" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_items" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_order_allocations" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_allocations" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_allocations" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_allocations" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_allocations" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_order_employee_items" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employee_items" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employee_items" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employee_items" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employee_items" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_order_employees" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employees" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employees" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employees" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_employees" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_order_items" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_items" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_items" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_items" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_items" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_order_postponements" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_postponements" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_postponements" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_postponements" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_order_postponements" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_orders" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_orders" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_orders" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_orders" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_orders" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_requirement_reports" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_requirement_reports" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_requirement_reports" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_requirement_reports" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_requirement_reports" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_suppliers" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_suppliers" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_suppliers" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_suppliers" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_suppliers" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON TABLE "public"."uniform_supply_orders" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_supply_orders" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_supply_orders" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_supply_orders" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE "public"."uniform_supply_orders" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."career_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."career_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."career_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."career_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."career_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."demand_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."demand_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."demand_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."demand_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."demand_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."disciplinary_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."disciplinary_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."disciplinary_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."disciplinary_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."disciplinary_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."employee_join_date_history_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_join_date_history_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_join_date_history_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_join_date_history_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_join_date_history_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."employee_reactivations_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_reactivations_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_reactivations_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_reactivations_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employee_reactivations_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."employees_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employees_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employees_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employees_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."employees_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."exits_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."exits_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."exits_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."exits_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."exits_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."leaves_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."leaves_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."leaves_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."leaves_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."leaves_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."meeting_attendance_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meeting_attendance_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meeting_attendance_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meeting_attendance_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meeting_attendance_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."meetings_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meetings_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meetings_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meetings_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."meetings_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."notification_deliveries_id_seq" FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_deliveries_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_deliveries_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres,authenticated=rU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."notification_escalation_rules_id_seq" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_escalation_rules_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_escalation_rules_id_seq" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, USAGE ON SEQUENCE "public"."notification_escalation_rules_id_seq" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."notification_events_id_seq" FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_events_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_events_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."notification_jobs_id_seq" FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_jobs_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_jobs_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres,authenticated=rU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."notification_preferences_id_seq" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_preferences_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."notification_preferences_id_seq" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, USAGE ON SEQUENCE "public"."notification_preferences_id_seq" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."project_meeting_scope_history_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."project_meeting_scope_history_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."project_meeting_scope_history_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."project_meeting_scope_history_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."project_meeting_scope_history_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."projects_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."projects_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."projects_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."projects_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."projects_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,service_role=rwU/postgres,authenticated=rU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."push_subscriptions_id_seq" FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."push_subscriptions_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."push_subscriptions_id_seq" TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, USAGE ON SEQUENCE "public"."push_subscriptions_id_seq" TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."todos_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."todos_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."todos_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."todos_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."todos_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."transfers_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."transfers_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."transfers_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."transfers_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."transfers_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_deliveries_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_deliveries_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_deliveries_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_deliveries_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_deliveries_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_delivery_bills_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_bills_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_bills_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_bills_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_bills_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_delivery_issues_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_issues_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_issues_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_issues_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_issues_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_delivery_items_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_items_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_items_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_items_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_delivery_items_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_items_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_items_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_items_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_items_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_items_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_order_allocations_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_allocations_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_allocations_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_allocations_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_allocations_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_order_employee_items_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employee_items_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employee_items_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employee_items_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employee_items_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_order_employees_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employees_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employees_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employees_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_employees_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_order_items_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_items_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_items_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_items_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_items_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_order_postponements_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_postponements_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_postponements_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_postponements_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_order_postponements_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_orders_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_orders_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_orders_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_orders_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_orders_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_requirement_reports_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_requirement_reports_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_requirement_reports_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_requirement_reports_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_requirement_reports_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_suppliers_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_suppliers_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_suppliers_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_suppliers_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_suppliers_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON SEQUENCE "public"."uniform_supply_orders_id_seq" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_supply_orders_id_seq" TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_supply_orders_id_seq" TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_supply_orders_id_seq" TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."uniform_supply_orders_id_seq" TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.assign_uniform_order_number() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.assign_uniform_order_number() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.assign_uniform_order_number() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.assign_uniform_order_number() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.assign_uniform_order_number() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.assign_uniform_order_number() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.cancel_exit(bigint,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_exit(bigint,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_exit(bigint,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_exit(bigint,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_exit(bigint,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.cancel_transfer(bigint,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_transfer(bigint,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_transfer(bigint,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_transfer(bigint,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.cancel_transfer(bigint,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.commit_exit(jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_exit(jsonb) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_exit(jsonb) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_exit(jsonb) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_exit(jsonb) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.commit_transfer(jsonb,boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_transfer(jsonb,boolean) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_transfer(jsonb,boolean) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_transfer(jsonb,boolean) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.commit_transfer(jsonb,boolean) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.complete_exit(bigint,date,text,text,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.complete_exit(bigint,date,text,text,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.complete_exit(bigint,date,text,text,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.complete_exit(bigint,date,text,text,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.complete_exit(bigint,date,text,text,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.confirm_transfer_joining(bigint,date,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.confirm_transfer_joining(bigint,date,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.confirm_transfer_joining(bigint,date,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.confirm_transfer_joining(bigint,date,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.confirm_transfer_joining(bigint,date,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.create_exit_draft(jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_exit_draft(jsonb) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_exit_draft(jsonb) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_exit_draft(jsonb) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_exit_draft(jsonb) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.create_transfer_order(jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_transfer_order(jsonb) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_transfer_order(jsonb) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_transfer_order(jsonb) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.create_transfer_order(jsonb) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.get_transfer_action_queue() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.get_transfer_action_queue() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.get_transfer_action_queue() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.get_transfer_action_queue() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.get_transfer_action_queue() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.guard_profile_fields() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.guard_profile_fields() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.guard_profile_fields() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.guard_profile_fields() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.guard_profile_fields() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.guard_profile_fields() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.handle_new_user() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.log_employee_join_date_change() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_employee_join_date_change() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_employee_join_date_change() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_employee_join_date_change() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_employee_join_date_change() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_employee_join_date_change() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.log_project_meeting_scope_change() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_project_meeting_scope_change() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_project_meeting_scope_change() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_project_meeting_scope_change() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.log_project_meeting_scope_change() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.mark_transfer_not_joined(bigint,text,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mark_transfer_not_joined(bigint,text,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mark_transfer_not_joined(bigint,text,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mark_transfer_not_joined(bigint,text,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mark_transfer_not_joined(bigint,text,text) TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.mghrm_is_employee_inactive(text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_is_employee_inactive(text) TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_is_employee_inactive(text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_is_employee_inactive(text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_is_employee_inactive(text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_is_employee_inactive(text) TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.mghrm_normalize_employee_status() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_normalize_employee_status() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_normalize_employee_status() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_normalize_employee_status() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_normalize_employee_status() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_normalize_employee_status() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_resolve_transfers_for_inactive_employee() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.mghrm_touch_updated_at() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_touch_updated_at() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_touch_updated_at() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_touch_updated_at() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_touch_updated_at() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.mghrm_touch_updated_at() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.my_role() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.my_role() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.my_role() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.my_role() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.my_role() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.my_role() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.next_uniform_order_number(date) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.next_uniform_order_number(date) TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.next_uniform_order_number(date) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.next_uniform_order_number(date) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.next_uniform_order_number(date) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.next_uniform_order_number(date) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_apply_lifecycle() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_apply_lifecycle() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_apply_lifecycle() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_check_core_source(text,bigint) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_core_source(text,bigint) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_core_source(text,bigint) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_check_leave_source(bigint) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_leave_source(bigint) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_leave_source(bigint) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_check_uniform_source(text,bigint) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_uniform_source(text,bigint) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_check_uniform_source(text,bigint) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_claim_jobs(text,integer) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_claim_jobs(text,integer) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_claim_jobs(text,integer) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_claim_web_push_jobs(text,integer) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_claim_web_push_jobs(text,integer) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_claim_web_push_jobs(text,integer) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_complete_if_resolved(uuid) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_complete_if_resolved(uuid) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_complete_if_resolved(uuid) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_complete_if_resolved(uuid) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_complete_job(bigint,text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_complete_job(bigint,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_complete_job(bigint,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_cron_tick() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_cron_tick() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_cron_tick() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_dismiss(uuid) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_dismiss(uuid) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_dismiss(uuid) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_dismiss(uuid) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_effective_preference(uuid,text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_effective_preference(uuid,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_effective_preference(uuid,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_enqueue_pending_events(integer) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_enqueue_pending_events(integer) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_enqueue_pending_events(integer) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_event_apply_lifecycle() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_event_apply_lifecycle() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_event_apply_lifecycle() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_fail_job(bigint,text,text,interval) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_fail_job(bigint,text,text,interval) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_fail_job(bigint,text,text,interval) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_finalize_web_push_job(bigint,text,interval) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_finalize_web_push_job(bigint,text,interval) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_finalize_web_push_job(bigint,text,interval) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_get_web_push_dispatch(bigint,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_job_apply_lifecycle() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_job_apply_lifecycle() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_job_apply_lifecycle() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_mark_all_read() FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_all_read() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_all_read() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_all_read() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_mark_read(uuid) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_read(uuid) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_read(uuid) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_mark_read(uuid) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_next_allowed_at(uuid,text,text,timestamp with time zone) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_next_allowed_at(uuid,text,text,timestamp with time zone) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_next_allowed_at(uuid,text,text,timestamp with time zone) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_open(uuid) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_open(uuid) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_open(uuid) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_open(uuid) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_operations_health() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_operations_health() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_operations_health() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_operations_maintenance() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_operations_maintenance() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_operations_maintenance() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_prepare_deliveries(integer) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_prepare_deliveries(integer) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_prepare_deliveries(integer) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_priority_rank(text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_priority_rank(text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_priority_rank(text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_process_event_job(bigint,text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_process_event_job(bigint,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_process_event_job(bigint,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_record_web_push_result(bigint,text,bigint,boolean,text,text,text,text,jsonb,boolean) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_recover_stale_jobs(interval) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_recover_stale_jobs(interval) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_recover_stale_jobs(interval) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_run_event_processor(text,integer,interval) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_event_processor(text,integer,interval) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_event_processor(text,integer,interval) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_run_recurrence(integer) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_recurrence(integer) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_recurrence(integer) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_run_server_processor(text,integer,interval) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_server_processor(text,integer,interval) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_run_server_processor(text,integer,interval) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_snooze(uuid,timestamp with time zone) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_snooze(uuid,timestamp with time zone) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_snooze(uuid,timestamp with time zone) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_snooze(uuid,timestamp with time zone) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_source_state(text,text) FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_source_state(text,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_source_state(text,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.notification_touch_updated_at() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_touch_updated_at() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.notification_touch_updated_at() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.prevent_duplicate_active_uniform_employee() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.prevent_duplicate_active_uniform_employee() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.prevent_duplicate_active_uniform_employee() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.prevent_duplicate_active_uniform_employee() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.prevent_duplicate_active_uniform_employee() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.prevent_duplicate_active_uniform_employee() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.protect_terminal_uniform_delivery_items() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_delivery_items() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_delivery_items() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_delivery_items() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_delivery_items() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_delivery_items() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.protect_terminal_uniform_employee_items() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_employee_items() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_employee_items() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_employee_items() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_employee_items() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_employee_items() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.protect_terminal_uniform_order_children() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_order_children() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_order_children() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_order_children() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_order_children() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_terminal_uniform_order_children() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.protect_uniform_order_integrity() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_uniform_order_integrity() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_uniform_order_integrity() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_uniform_order_integrity() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_uniform_order_integrity() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.protect_uniform_order_integrity() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.push_subscription_apply_lifecycle() FROM PUBLIC, "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_apply_lifecycle() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_apply_lifecycle() TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.push_subscription_list_devices() FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_list_devices() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_list_devices() TO "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_list_devices() TO "authenticated";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_register(text,text,text,text,text,text,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.push_subscription_revoke(bigint) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_revoke(bigint) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_revoke(bigint) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_revoke(bigint) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.push_subscription_update_device(bigint,text,text,text,boolean) FROM PUBLIC, "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_update_device(bigint,text,text,text,boolean) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_update_device(bigint,text,text,text,boolean) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.push_subscription_update_device(bigint,text,text,text,boolean) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.reactivate_employee(bigint,date,text,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reactivate_employee(bigint,date,text,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reactivate_employee(bigint,date,text,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reactivate_employee(bigint,date,text,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reactivate_employee(bigint,date,text,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.reschedule_transfer(bigint,date,text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reschedule_transfer(bigint,date,text) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reschedule_transfer(bigint,date,text) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reschedule_transfer(bigint,date,text) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.reschedule_transfer(bigint,date,text) TO "service_role";
RESET ROLE;

-- Original ACL: {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.save_uniform_delivery(bigint,text,date,text,text,numeric,text,jsonb,jsonb) TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.set_updated_at() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.uniform_order_accounting(bigint) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.uniform_order_accounting(bigint) TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.uniform_order_accounting(bigint) TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.uniform_order_accounting(bigint) TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.uniform_order_accounting(bigint) TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.uniform_order_accounting(bigint) TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.validate_uniform_delivery_bill() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_delivery_bill() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_delivery_bill() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_delivery_bill() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_delivery_bill() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_delivery_bill() TO "service_role";
RESET ROLE;

-- Original ACL: {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
SET ROLE "postgres";
REVOKE ALL PRIVILEGES ON FUNCTION public.validate_uniform_order_status_change() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_order_status_change() TO PUBLIC;
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_order_status_change() TO "postgres";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_order_status_change() TO "anon";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_order_status_change() TO "authenticated";
RESET ROLE;
SET ROLE "postgres";
GRANT EXECUTE ON FUNCTION public.validate_uniform_order_status_change() TO "service_role";
RESET ROLE;
