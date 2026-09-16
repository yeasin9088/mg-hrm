-- Fix columns missing for index.html compatibility:

alter table public.employees add column if not exists system_id text;

alter table public.transfers add column if not exists system_id text;
alter table public.transfers add column if not exists employee_id_bn text;
alter table public.transfers add column if not exists transfer_date_bn text;
alter table public.transfers add column if not exists issues_date_bn text;

alter table public.exits add column if not exists system_id text;

alter table public.disciplinary add column if not exists system_id text;
alter table public.disciplinary add column if not exists employee_id_bn text;
alter table public.disciplinary add column if not exists issue_date_bn text;
alter table public.disciplinary add column if not exists description_bn text;

alter table public.career add column if not exists system_id text;

-- Fix identity columns mapped to UUID/String IDs in JS
alter table public.recruitment_archive alter column archive_id drop identity if exists;
alter table public.recruitment_archive alter column archive_id type text using archive_id::text;

alter table public.activity_log alter column id drop identity if exists;
alter table public.activity_log alter column id type text using id::text;
