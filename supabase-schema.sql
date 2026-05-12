create table if not exists public.budget_state (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  role text not null default 'user' check (role in ('admin', 'user')),
  user_id uuid references auth.users(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create or replace function public.current_auth_email()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create or replace function public.is_budget_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_users
    where user_id = auth.uid()
       or lower(email) = public.current_auth_email()
  )
$$;

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_users
    where role = 'admin'
      and (user_id = auth.uid() or lower(email) = public.current_auth_email())
  )
$$;

create or replace function public.is_first_app_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (select 1 from public.app_users)
$$;

alter table public.budget_state enable row level security;
alter table public.app_users enable row level security;

drop policy if exists "app_users_read_allowed" on public.app_users;
create policy "app_users_read_allowed"
on public.app_users
for select
to authenticated
using (
  public.is_app_admin()
  or user_id = auth.uid()
  or lower(email) = public.current_auth_email()
);

drop policy if exists "app_users_insert_admin_or_first" on public.app_users;
create policy "app_users_insert_admin_or_first"
on public.app_users
for insert
to authenticated
with check (
  public.is_app_admin()
  or public.is_first_app_user()
);

drop policy if exists "app_users_update_admin_or_claim" on public.app_users;
create policy "app_users_update_admin_or_claim"
on public.app_users
for update
to authenticated
using (
  public.is_app_admin()
  or lower(email) = public.current_auth_email()
)
with check (
  public.is_app_admin()
  or lower(email) = public.current_auth_email()
);

drop policy if exists "budget_state_read_authenticated" on public.budget_state;
drop policy if exists "budget_state_read_allowed" on public.budget_state;
create policy "budget_state_read_allowed"
on public.budget_state
for select
to authenticated
using (public.is_budget_user());

drop policy if exists "budget_state_insert_authenticated" on public.budget_state;
drop policy if exists "budget_state_insert_allowed" on public.budget_state;
create policy "budget_state_insert_allowed"
on public.budget_state
for insert
to authenticated
with check (id = 'main' and public.is_budget_user());

drop policy if exists "budget_state_update_authenticated" on public.budget_state;
drop policy if exists "budget_state_update_allowed" on public.budget_state;
create policy "budget_state_update_allowed"
on public.budget_state
for update
to authenticated
using (id = 'main' and public.is_budget_user())
with check (id = 'main' and public.is_budget_user());
       or lower(email) = public.current_auth_email()
  )
$$;

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_users
    where role = 'admin'
      and (user_id = auth.uid() or lower(email) = public.current_auth_email())
  )
$$;

alter table public.budget_state enable row level security;
alter table public.app_users enable row level security;

drop policy if exists "app_users_read_allowed" on public.app_users;
create policy "app_users_read_allowed"
on public.app_users
for select
to authenticated
using (
  public.is_app_admin()
  or user_id = auth.uid()
  or lower(email) = public.current_auth_email()
);

drop policy if exists "app_users_insert_admin_or_first" on public.app_users;
create policy "app_users_insert_admin_or_first"
on public.app_users
for insert
to authenticated
with check (
  public.is_app_admin()
  or not exists (select 1 from public.app_users)
);

drop policy if exists "app_users_update_admin_or_claim" on public.app_users;
create policy "app_users_update_admin_or_claim"
on public.app_users
for update
to authenticated
using (
  public.is_app_admin()
  or lower(email) = public.current_auth_email()
)
with check (
  public.is_app_admin()
  or lower(email) = public.current_auth_email()
);

drop policy if exists "budget_state_read_authenticated" on public.budget_state;
drop policy if exists "budget_state_read_allowed" on public.budget_state;
create policy "budget_state_read_allowed"
on public.budget_state
for select
to authenticated
using (public.is_budget_user());

drop policy if exists "budget_state_insert_authenticated" on public.budget_state;
drop policy if exists "budget_state_insert_allowed" on public.budget_state;
create policy "budget_state_insert_allowed"
on public.budget_state
for insert
to authenticated
with check (id = 'main' and public.is_budget_user());

drop policy if exists "budget_state_update_authenticated" on public.budget_state;
drop policy if exists "budget_state_update_allowed" on public.budget_state;
create policy "budget_state_update_allowed"
on public.budget_state
for update
to authenticated
using (id = 'main' and public.is_budget_user())
with check (id = 'main' and public.is_budget_user());
