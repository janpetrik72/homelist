-- HomeList: základní databázové schéma pro rodinné zásoby
-- Spusť celý soubor v Supabase -> SQL Editor -> New query.

create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  quantity text not null default '',
  location text not null check (location in ('fridge', 'freezer', 'pantry')),
  is_low boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  quantity text not null default '',
  is_done boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists inventory_household_idx on public.inventory_items(household_id);
create index if not exists shopping_household_idx on public.shopping_items(household_id);

-- Bezpečná pomocná funkce pro ověření členství v domácnosti.
create or replace function public.is_household_member(target_household uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household
      and hm.user_id = auth.uid()
  );
$$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.inventory_items enable row level security;
alter table public.shopping_items enable row level security;

drop policy if exists "Members can read their households" on public.households;
create policy "Members can read their households"
on public.households for select
to authenticated
using (public.is_household_member(id) or created_by = auth.uid());

drop policy if exists "Signed-in users can create a household" on public.households;
create policy "Signed-in users can create a household"
on public.households for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "Members can read household membership" on public.household_members;
create policy "Members can read household membership"
on public.household_members for select
to authenticated
using (public.is_household_member(household_id) or user_id = auth.uid());

drop policy if exists "Household creator can add the first member" on public.household_members;
create policy "Household creator can add the first member"
on public.household_members for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.households h
    where h.id = household_id and h.created_by = auth.uid()
  )
);

drop policy if exists "Members can read inventory" on public.inventory_items;
create policy "Members can read inventory"
on public.inventory_items for select
to authenticated
using (public.is_household_member(household_id));

drop policy if exists "Members can add inventory" on public.inventory_items;
create policy "Members can add inventory"
on public.inventory_items for insert
to authenticated
with check (public.is_household_member(household_id) and created_by = auth.uid());

drop policy if exists "Members can update inventory" on public.inventory_items;
create policy "Members can update inventory"
on public.inventory_items for update
to authenticated
using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

drop policy if exists "Members can delete inventory" on public.inventory_items;
create policy "Members can delete inventory"
on public.inventory_items for delete
to authenticated
using (public.is_household_member(household_id));

drop policy if exists "Members can read shopping list" on public.shopping_items;
create policy "Members can read shopping list"
on public.shopping_items for select
to authenticated
using (public.is_household_member(household_id));

drop policy if exists "Members can add shopping items" on public.shopping_items;
create policy "Members can add shopping items"
on public.shopping_items for insert
to authenticated
with check (public.is_household_member(household_id) and created_by = auth.uid());

drop policy if exists "Members can update shopping items" on public.shopping_items;
create policy "Members can update shopping items"
on public.shopping_items for update
to authenticated
using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

drop policy if exists "Members can delete shopping items" on public.shopping_items;
create policy "Members can delete shopping items"
on public.shopping_items for delete
to authenticated
using (public.is_household_member(household_id));

-- updated_at se aktualizuje při změně položky.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists inventory_items_updated_at on public.inventory_items;
create trigger inventory_items_updated_at
before update on public.inventory_items
for each row execute function public.set_updated_at();
