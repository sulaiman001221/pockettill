create table public.admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create policy admin_users_select_own
  on public.admin_users
  for select
  using (id = auth.uid());
