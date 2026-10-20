-- CURRENT DEPLOYED SCHEMA REFERENCE — not a migration or tested restore script.
-- Source: read-only PostgreSQL 17.6 catalogs, 2026-10-20 (Asia/Dhaka).
SET standard_conforming_strings = on;
SET search_path = pg_catalog, public;

-- REFERENCE ONLY: installed extension names/versions/schemas. Managed bootstrap
-- and server packages are prerequisites, not reproduced by this application baseline.
-- Installed owner: supabase_admin; relocatable=false
CREATE EXTENSION "pg_cron" WITH SCHEMA "pg_catalog" VERSION '1.6.4';

-- Installed owner: supabase_admin; relocatable=false
CREATE EXTENSION "pg_net" WITH SCHEMA "extensions" VERSION '0.20.4';

-- Installed owner: postgres; relocatable=true
CREATE EXTENSION "pg_stat_statements" WITH SCHEMA "extensions" VERSION '1.11';

-- Installed owner: postgres; relocatable=true
CREATE EXTENSION "pgcrypto" WITH SCHEMA "extensions" VERSION '1.3';

-- Installed owner: supabase_admin; relocatable=false
CREATE EXTENSION "plpgsql" WITH SCHEMA "pg_catalog" VERSION '1.0';

-- Installed owner: supabase_admin; relocatable=false
CREATE EXTENSION "supabase_vault" WITH SCHEMA "vault" VERSION '0.3.1';

-- Installed owner: postgres; relocatable=true
CREATE EXTENSION "uuid-ossp" WITH SCHEMA "extensions" VERSION '1.1';
