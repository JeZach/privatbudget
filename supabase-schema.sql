create table if not exists public.budget_state (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.budget_state enable row level security;

drop policy if exists "budget_state_read_authenticated" on public.budget_state;
create policy "budget_state_read_authenticated"
on public.budget_state
for select
to authenticated
using (true);

drop policy if exists "budget_state_insert_authenticated" on public.budget_state;
create policy "budget_state_insert_authenticated"
on public.budget_state
for insert
to authenticated
with check (id = 'main');

drop policy if exists "budget_state_update_authenticated" on public.budget_state;
create policy "budget_state_update_authenticated"
on public.budget_state
for update
to authenticated
using (id = 'main')
with check (id = 'main');
