alter table public.admin_users add column if not exists can_manage_access boolean not null default false;

update public.admin_users set can_manage_access = true where role = 'owner';
