-- SELECT ONLY. Catalog extraction recipes; no application/Auth rows or sequence values.
-- This is a documentation snapshot workflow, not an audit or migration.
-- Results require secret review before local storage. Run only with an authorized read-only connection.

SELECT jsonb_build_object(
'schemas',(SELECT jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner),'acl',nspacl::text,'comment',obj_description(oid,'pg_namespace')) ORDER BY nspname) FROM pg_namespace WHERE nspname='public'),
'tables',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name) FROM (
 SELECT c.oid AS catalog_oid,n.nspname AS schema,c.relname AS name,c.relkind,c.relpersistence,pg_get_userbyid(c.relowner) AS owner,c.relacl::text AS acl,c.relrowsecurity,c.relforcerowsecurity,c.relreplident,c.reloptions,am.amname AS access_method,ts.spcname AS tablespace,c.relispartition,pg_get_partkeydef(c.oid) AS partition_key,obj_description(c.oid,'pg_class') AS comment
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_am am ON am.oid=c.relam LEFT JOIN pg_tablespace ts ON ts.oid=c.reltablespace
 WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','f'))s),
'columns',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.table_name,s.ordinal) FROM (
 SELECT c.relname AS table_name,a.attnum AS ordinal,a.attname AS name,format_type(a.atttypid,a.atttypmod) AS type,tn.nspname AS type_schema,t.typname AS type_name,a.attnotnull AS not_null,a.attidentity AS identity,a.attgenerated AS generated,pg_get_expr(ad.adbin,ad.adrelid) AS default_expression,
 CASE WHEN a.attcollation<>t.typcollation THEN quote_ident(cn.nspname)||'.'||quote_ident(co.collname) END AS collation,
 a.attstorage AS storage,t.typstorage AS type_storage,a.attcompression AS compression,a.attstattarget AS statistics_target,a.attoptions AS options,a.attacl::text AS acl,col_description(c.oid,a.attnum) AS comment
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_type t ON t.oid=a.atttypid JOIN pg_namespace tn ON tn.oid=t.typnamespace
 LEFT JOIN pg_attrdef ad ON ad.adrelid=a.attrelid AND ad.adnum=a.attnum LEFT JOIN pg_collation co ON co.oid=a.attcollation LEFT JOIN pg_namespace cn ON cn.oid=co.collnamespace
 WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','f') AND a.attnum>0 AND NOT a.attisdropped)s),
'constraints',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.table_name,s.name) FROM (
 SELECT c.conname AS name,cl.relname AS table_name,c.contype,c.condeferrable,c.condeferred,c.convalidated,c.connoinherit,c.conislocal,c.coninhcount,pg_get_constraintdef(c.oid,true) AS definition,
 CASE WHEN c.confrelid<>0 THEN c.confrelid::regclass::text END AS referenced_table,c.conkey,c.confkey,CASE WHEN c.conindid<>0 THEN c.conindid::regclass::text END AS backing_index,obj_description(c.oid,'pg_constraint') AS comment
 FROM pg_constraint c JOIN pg_class cl ON cl.oid=c.conrelid JOIN pg_namespace n ON n.oid=cl.relnamespace WHERE n.nspname='public')s),
'indexes',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.table_name,s.name) FROM (
 SELECT cl.relname AS table_name,ix.relname AS name,pg_get_indexdef(i.indexrelid) AS definition,i.indisprimary,i.indisunique,i.indisvalid,i.indisready,i.indisclustered,i.indisreplident,ix.reloptions,ts.spcname AS tablespace,co.conname AS constraint_name,obj_description(ix.oid,'pg_class') AS comment
 FROM pg_index i JOIN pg_class cl ON cl.oid=i.indrelid JOIN pg_namespace n ON n.oid=cl.relnamespace JOIN pg_class ix ON ix.oid=i.indexrelid LEFT JOIN pg_tablespace ts ON ts.oid=ix.reltablespace LEFT JOIN pg_constraint co ON co.conindid=i.indexrelid AND co.contype IN ('p','u','x') WHERE n.nspname='public')s),
'sequences',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name) FROM (
 SELECT c.relname AS name,pg_get_userbyid(c.relowner) AS owner,c.relacl::text AS acl,format_type(s.seqtypid,NULL) AS type,s.seqstart::text AS seqstart,s.seqincrement::text AS seqincrement,s.seqmin::text AS seqmin,s.seqmax::text AS seqmax,s.seqcache::text AS seqcache,s.seqcycle,cl.relname AS owned_table,a.attname AS owned_column,d.deptype AS ownership_dependency,obj_description(c.oid,'pg_class') AS comment
 FROM pg_sequence s JOIN pg_class c ON c.oid=s.seqrelid JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_depend d ON d.classid='pg_class'::regclass AND d.objid=c.oid AND d.refclassid='pg_class'::regclass AND d.deptype IN ('a','i') LEFT JOIN pg_class cl ON cl.oid=d.refobjid LEFT JOIN pg_attribute a ON a.attrelid=cl.oid AND a.attnum=d.refobjsubid WHERE n.nspname='public')s),
'types',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.name),'[]'::jsonb) FROM (
 SELECT t.typname AS name,t.typtype,pg_get_userbyid(t.typowner) AS owner,format_type(t.typbasetype,t.typtypmod) AS base_type,t.typnotnull,t.typdefault,t.typacl::text AS acl, obj_description(t.oid,'pg_type') AS comment FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace LEFT JOIN pg_class c ON c.oid=t.typrelid WHERE n.nspname='public' AND t.typtype IN ('e','d','r','m') )s),
'extensions',(SELECT jsonb_agg(jsonb_build_object('name',e.extname,'version',e.extversion,'schema',n.nspname,'owner',pg_get_userbyid(e.extowner),'relocatable',e.extrelocatable) ORDER BY e.extname) FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace),
'publications',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name) FROM (SELECT p.pubname AS name,pg_get_userbyid(p.pubowner) AS owner,p.puballtables,p.pubinsert,p.pubupdate,p.pubdelete,p.pubtruncate,p.pubviaroot,(SELECT coalesce(jsonb_agg(jsonb_build_object('schema',pt.schemaname,'table',pt.tablename,'columns',pt.attnames,'row_filter',pt.rowfilter) ORDER BY pt.schemaname,pt.tablename),'[]'::jsonb) FROM pg_publication_tables pt WHERE pt.pubname=p.pubname) AS tables FROM pg_publication p)s),
'inheritance',(SELECT coalesce(jsonb_agg(jsonb_build_object('child',i.inhrelid::regclass::text,'parent',i.inhparent::regclass::text)),'[]'::jsonb) FROM pg_inherits i JOIN pg_class c ON c.oid=i.inhrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public')
) AS metadata;

SELECT jsonb_build_object(
'routines',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.identity) FROM (
 SELECT p.oid::regprocedure::text AS identity,pg_get_userbyid(p.proowner) AS owner,l.lanname AS language,p.prokind,p.prosecdef,p.provolatile,p.proparallel,p.proisstrict,p.proleakproof,p.proconfig,p.proacl::text AS proacl,pg_get_function_identity_arguments(p.oid) AS identity_arguments,pg_get_function_arguments(p.oid) AS arguments,pg_get_function_result(p.oid) AS result,md5(pg_get_functiondef(p.oid)) AS definition_md5,obj_description(p.oid,'pg_proc') AS comment
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang WHERE n.nspname='public' AND p.prokind IN ('f','p'))s),
'policies',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.tablename,s.policyname) FROM (SELECT schemaname,tablename,policyname,permissive,roles::text,cmd,qual,with_check FROM pg_policies WHERE schemaname='public')s),
'triggers',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.relation,s.name) FROM (
 SELECT n.nspname AS schema,c.relname AS relation,t.tgname AS name,t.tgfoid::regprocedure::text AS function,t.tgenabled,pg_get_triggerdef(t.oid,true) AS definition,obj_description(t.oid,'pg_trigger') AS comment
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND (n.nspname='public' OR (n.nspname='auth' AND t.tgfoid IN (SELECT p.oid FROM pg_proc p JOIN pg_namespace pn ON pn.oid=p.pronamespace WHERE pn.nspname='public'))))s),
'default_privileges',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.owner,s.schema,s.object_type) FROM (
 SELECT pg_get_userbyid(defaclrole) AS owner,n.nspname AS schema,defaclobjtype AS object_type,defaclacl::text AS acl FROM pg_default_acl a LEFT JOIN pg_namespace n ON n.oid=a.defaclnamespace WHERE n.nspname='public' OR a.defaclnamespace=0)s),
'external_schemas',(SELECT jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner),'acl',nspacl::text) ORDER BY nspname) FROM pg_namespace WHERE nspname IN ('auth','cron','net','extensions','storage','realtime')),
'roles',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name) FROM (
 SELECT rolname AS name,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolreplication,rolbypassrls FROM pg_roles WHERE rolname IN ('postgres','pg_database_owner','anon','authenticated','authenticator','service_role','supabase_auth_admin'))s),
'role_memberships',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.role,s.member) FROM (
 SELECT pg_get_userbyid(roleid) AS role,pg_get_userbyid(member) AS member,pg_get_userbyid(grantor) AS grantor,admin_option,inherit_option,set_option FROM pg_auth_members WHERE roleid IN (SELECT oid FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator')) OR member IN (SELECT oid FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator')))s)
) AS metadata;

WITH scoped AS (
 SELECT 'pg_proc'::regclass AS classid,p.oid AS objid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 UNION ALL SELECT 'pg_class'::regclass,c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
 UNION ALL SELECT 'pg_constraint'::regclass,co.oid FROM pg_constraint co JOIN pg_namespace n ON n.oid=co.connamespace WHERE n.nspname='public'
 UNION ALL SELECT 'pg_attrdef'::regclass,a.oid FROM pg_attrdef a JOIN pg_class c ON c.oid=a.adrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
 UNION ALL SELECT 'pg_trigger'::regclass,t.oid FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND n.nspname='public'
 UNION ALL SELECT 'pg_policy'::regclass,p.oid FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
)
SELECT DISTINCT pg_describe_object(d.classid,d.objid,d.objsubid) AS object,pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS dependency,d.deptype FROM pg_depend d JOIN scoped s ON s.classid=d.classid AND s.objid=d.objid ORDER BY 1,2,3;

SELECT 'function' AS kind,p.oid::regprocedure::text AS identity,pg_get_userbyid(p.proowner) AS owner,pg_get_functiondef(p.oid) AS definition,p.proacl::text AS acl FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE (n.nspname='auth' AND p.proname IN ('uid','role')) UNION ALL SELECT 'table',c.oid::regclass::text,pg_get_userbyid(c.relowner),NULL,c.relacl::text FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname='auth' AND c.relname='users') OR (n.nspname='cron' AND c.relname IN ('job','job_run_details')) ORDER BY 1,2;

SELECT n.nspname AS schema,c.relname AS table_name,a.attname AS column_name,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE a.attnum>0 AND NOT a.attisdropped AND ((n.nspname='auth' AND c.relname='users' AND a.attname='id') OR (n.nspname='cron' AND c.relname IN ('job','job_run_details'))) ORDER BY n.nspname,c.relname,a.attnum;

SELECT t.typname AS name,t.typtype,c.relkind FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace LEFT JOIN pg_class c ON c.oid=t.typrelid WHERE n.nspname='public' AND ((t.typtype='c' AND c.relkind='c') OR (t.typtype='b' AND t.typelem=0)) ORDER BY t.typname;

SELECT p.pubname AS publication,n.nspname AS schema,c.relname AS table_name,pr.prattrs::text AS explicit_attribute_numbers,pg_get_expr(pr.prqual,pr.prrelid) AS row_filter FROM pg_publication_rel pr JOIN pg_publication p ON p.oid=pr.prpubid JOIN pg_class c ON c.oid=pr.prrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' ORDER BY p.pubname,c.relname;

-- Fetch body text only for new or changed hashes, after identifying the exact routines.
-- Current 72 cached bodies were reused after ALL current hashes matched.
SELECT p.oid::regprocedure::text AS identity, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind IN ('f','p')
ORDER BY identity;
