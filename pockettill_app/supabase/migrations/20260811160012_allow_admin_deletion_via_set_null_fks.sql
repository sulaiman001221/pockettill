alter table public.audit_log drop constraint audit_log_admin_id_fkey;
alter table public.audit_log add constraint audit_log_admin_id_fkey foreign key (admin_id) references public.admin_users(id) on delete set null;

alter table public.admin_users drop constraint admin_users_invited_by_fkey;
alter table public.admin_users add constraint admin_users_invited_by_fkey foreign key (invited_by) references public.admin_users(id) on delete set null;
