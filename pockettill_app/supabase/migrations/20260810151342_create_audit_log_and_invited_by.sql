alter table public.admin_users add column if not exists invited_by uuid references public.admin_users(id);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.admin_users(id),
  action text not null,
  target text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_log enable row level security;
