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

create table if not exists public.app_settings (
  id text primary key,
  quick_pin text not null default left(replace(gen_random_uuid()::text, '-', ''), 10),
  updated_at timestamptz not null default now()
);

insert into public.app_settings (id, quick_pin)
values ('main', left(replace(gen_random_uuid()::text, '-', ''), 10))
on conflict (id) do nothing;

create table if not exists public.purchase_inbox (
  id uuid primary key default gen_random_uuid(),
  purchase_date date not null default current_date,
  month_key text not null,
  target_id text not null,
  description text not null,
  amount numeric not null check (amount > 0),
  receipt_text text not null default '',
  source text not null default 'quick' check (source in ('quick', 'receipt_ai', 'voice_ai', 'manual')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id)
);

create table if not exists public.category_rules (
  id uuid primary key default gen_random_uuid(),
  pattern text not null unique,
  target_id text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.budget_state_history (
  id uuid primary key default gen_random_uuid(),
  budget_id text not null,
  data jsonb not null,
  saved_by uuid references auth.users(id),
  saved_at timestamptz not null default now()
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
alter table public.app_settings enable row level security;
alter table public.purchase_inbox enable row level security;
alter table public.category_rules enable row level security;
alter table public.budget_state_history enable row level security;

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

drop policy if exists "app_settings_read_admin" on public.app_settings;
create policy "app_settings_read_admin"
on public.app_settings
for select
to authenticated
using (public.is_app_admin());

drop policy if exists "app_settings_update_admin" on public.app_settings;
create policy "app_settings_update_admin"
on public.app_settings
for update
to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

drop policy if exists "purchase_inbox_read_allowed" on public.purchase_inbox;
create policy "purchase_inbox_read_allowed"
on public.purchase_inbox
for select
to authenticated
using (public.is_budget_user());

drop policy if exists "purchase_inbox_update_allowed" on public.purchase_inbox;
create policy "purchase_inbox_update_allowed"
on public.purchase_inbox
for update
to authenticated
using (public.is_budget_user())
with check (public.is_budget_user());

drop policy if exists "category_rules_read_allowed" on public.category_rules;
create policy "category_rules_read_allowed"
on public.category_rules
for select
to authenticated
using (public.is_budget_user());

drop policy if exists "category_rules_admin_write" on public.category_rules;
create policy "category_rules_admin_write"
on public.category_rules
for all
to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

drop policy if exists "budget_state_history_read_allowed" on public.budget_state_history;
create policy "budget_state_history_read_allowed"
on public.budget_state_history
for select
to authenticated
using (public.is_budget_user());

drop policy if exists "budget_state_history_admin_write" on public.budget_state_history;
create policy "budget_state_history_admin_write"
on public.budget_state_history
for all
to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

create or replace function public.quick_pin_ok(p_pin text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_settings
    where id = 'main'
      and quick_pin = p_pin
  )
$$;

create or replace function public.quick_budget_categories(p_pin text)
returns table(id text, name text, kind text)
language sql
stable
security definer
set search_path = public
as $$
  with state as (
    select data
    from public.budget_state
    where id = 'main'
      and public.quick_pin_ok(p_pin)
  ),
  rows as (
    select item, 'fixedCosts'::text as kind
    from state, jsonb_array_elements(coalesce(data #> '{budgetTemplate,fixedCosts}', '[]'::jsonb)) item
    union all
    select item, 'variableCosts'::text as kind
    from state, jsonb_array_elements(coalesce(data #> '{budgetTemplate,variableCosts}', '[]'::jsonb)) item
  )
  select item ->> 'id' as id, item ->> 'name' as name, kind
  from rows
  where coalesce(item ->> 'id', '') <> ''
    and coalesce(item ->> 'name', '') <> ''
  order by kind, name
$$;

create or replace function public.quick_category_rules(p_pin text)
returns table(pattern text, target_id text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.quick_pin_ok(p_pin) then
    raise exception 'Fel PIN-kod';
  end if;

  return query
  select r.pattern, r.target_id
  from public.category_rules r
  order by r.created_at desc;
end;
$$;

create or replace function public.quick_add_purchase(
  p_pin text,
  p_month_key text,
  p_target_id text,
  p_purchase_date date,
  p_description text,
  p_amount numeric,
  p_receipt_text text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  purchase_id uuid := gen_random_uuid();
  current_data jsonb;
  target_exists boolean;
begin
  if not public.quick_pin_ok(p_pin) then
    raise exception 'Fel PIN-kod';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Belopp saknas';
  end if;

  select data into current_data
  from public.budget_state
  where id = 'main'
  for update;

  if current_data is null then
    raise exception 'Budgeten saknas';
  end if;

  if current_data #> array['months', p_month_key] is null then
    raise exception 'Budgetmånaden saknas';
  end if;

  select exists (
    select 1
    from (
      select jsonb_array_elements(coalesce(current_data #> '{budgetTemplate,fixedCosts}', '[]'::jsonb)) item
      union all
      select jsonb_array_elements(coalesce(current_data #> '{budgetTemplate,variableCosts}', '[]'::jsonb)) item
    ) categories
    where item ->> 'id' = p_target_id
  ) into target_exists;

  if not target_exists then
    raise exception 'Kategorin finns inte';
  end if;

  insert into public.purchase_inbox (
    id, purchase_date, month_key, target_id, description, amount, receipt_text, source
  )
  values (
    purchase_id,
    coalesce(p_purchase_date, current_date),
    p_month_key,
    p_target_id,
    left(coalesce(p_description, 'Snabbköp'), 120),
    p_amount,
    left(coalesce(p_receipt_text, ''), 4000),
    'quick'
  );

  return purchase_id;
end;
$$;

create or replace function public.approve_purchase_inbox(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item public.purchase_inbox%rowtype;
  purchase jsonb;
  purchase_path text[];
  current_purchases jsonb;
  current_data jsonb;
begin
  if not public.is_budget_user() then
    raise exception 'Saknar behörighet';
  end if;

  select * into item
  from public.purchase_inbox
  where id = p_id and status = 'pending'
  for update;

  if item.id is null then
    raise exception 'Köpet finns inte eller är redan hanterat';
  end if;

  select data into current_data
  from public.budget_state
  where id = 'main'
  for update;

  insert into public.budget_state_history (budget_id, data, saved_by)
  values ('main', current_data, auth.uid());

  purchase := jsonb_build_object(
    'id', item.id::text,
    'date', item.purchase_date::text,
    'description', item.description,
    'amount', item.amount,
    'targetId', item.target_id,
    'userId', auth.uid(),
    'userName', 'Godkänt snabbköp',
    'userEmail', public.current_auth_email(),
    'receiptText', item.receipt_text
  );

  purchase_path := array['months', item.month_key, 'purchases'];
  current_purchases := coalesce(current_data #> purchase_path, '[]'::jsonb);

  update public.budget_state
  set data = jsonb_set(current_data, purchase_path, current_purchases || jsonb_build_array(purchase), true),
      updated_by = auth.uid(),
      updated_at = now()
  where id = 'main';

  update public.purchase_inbox
  set status = 'approved',
      decided_at = now(),
      decided_by = auth.uid()
  where id = p_id;
end;
$$;

create or replace function public.reject_purchase_inbox(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_budget_user() then
    raise exception 'Saknar behörighet';
  end if;

  update public.purchase_inbox
  set status = 'rejected',
      decided_at = now(),
      decided_by = auth.uid()
  where id = p_id and status = 'pending';
end;
$$;

create or replace function public.save_budget_state(p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_data jsonb;
  latest_snapshot timestamptz;
begin
  if not public.is_budget_user() then
    raise exception 'Saknar behörighet';
  end if;

  select data into current_data
  from public.budget_state
  where id = 'main'
  for update;

  if current_data is null then
    insert into public.budget_state (id, data, updated_by, updated_at)
    values ('main', p_data, auth.uid(), now())
    on conflict (id) do update
      set data = excluded.data,
          updated_by = auth.uid(),
          updated_at = now();
    return;
  end if;

  if current_data is distinct from p_data then
    select max(saved_at) into latest_snapshot
    from public.budget_state_history
    where budget_id = 'main';

    if latest_snapshot is null or latest_snapshot < now() - interval '2 minutes' then
      insert into public.budget_state_history (budget_id, data, saved_by)
      values ('main', current_data, auth.uid());
    end if;
  end if;

  update public.budget_state
  set data = p_data,
      updated_by = auth.uid(),
      updated_at = now()
  where id = 'main';
end;
$$;

create or replace function public.restore_budget_history(p_history_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_data jsonb;
  restore_data jsonb;
begin
  if not public.is_budget_user() then
    raise exception 'Saknar behörighet';
  end if;

  select data into restore_data
  from public.budget_state_history
  where id = p_history_id and budget_id = 'main';

  if restore_data is null then
    raise exception 'Historikversionen finns inte';
  end if;

  select data into current_data
  from public.budget_state
  where id = 'main'
  for update;

  if current_data is not null then
    insert into public.budget_state_history (budget_id, data, saved_by)
    values ('main', current_data, auth.uid());
  end if;

  update public.budget_state
  set data = restore_data,
      updated_by = auth.uid(),
      updated_at = now()
  where id = 'main';
end;
$$;

grant execute on function public.quick_budget_categories(text) to anon, authenticated;
grant execute on function public.quick_category_rules(text) to anon, authenticated;
grant execute on function public.quick_add_purchase(text, text, text, date, text, numeric, text) to anon, authenticated;
grant execute on function public.approve_purchase_inbox(uuid) to authenticated;
grant execute on function public.reject_purchase_inbox(uuid) to authenticated;
grant execute on function public.save_budget_state(jsonb) to authenticated;
grant execute on function public.restore_budget_history(uuid) to authenticated;
