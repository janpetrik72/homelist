-- HomeList: vlastní umístění zásob pro každou domácnost
create table if not exists public.household_locations (
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 40),
  created_at timestamptz not null default now(),
  primary key (household_id, name)
);

alter table public.household_locations enable row level security;
drop policy if exists "Members can read locations" on public.household_locations;
create policy "Members can read locations" on public.household_locations
for select to authenticated using (public.is_household_member(household_id));
drop policy if exists "Members can add locations" on public.household_locations;
create policy "Members can add locations" on public.household_locations
for insert to authenticated with check (public.is_household_member(household_id));
drop policy if exists "Members can delete locations" on public.household_locations;
create policy "Members can delete locations" on public.household_locations
for delete to authenticated using (public.is_household_member(household_id));

-- Převedení tří dosavadních umístění na české názvy.
insert into public.household_locations(household_id, name)
select h.id, v.name
from public.households h
cross join (values ('Lednice'), ('Mrazák'), ('Spíž')) as v(name)
on conflict do nothing;

alter table public.inventory_items drop constraint if exists inventory_items_location_check;
update public.inventory_items set location = case location
  when 'fridge' then 'Lednice'
  when 'freezer' then 'Mrazák'
  when 'pantry' then 'Spíž'
  else location end;

alter table public.inventory_items
  add constraint inventory_items_household_location_fk
  foreign key (household_id, location)
  references public.household_locations(household_id, name)
  on update cascade on delete restrict;

create or replace function public.create_household(household_name text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_household_id uuid;
begin
  if auth.uid() is null then raise exception 'Musíš být přihlášený.'; end if;
  if char_length(trim(household_name)) < 1 or char_length(trim(household_name)) > 80 then
    raise exception 'Název domácnosti musí mít 1 až 80 znaků.';
  end if;
  insert into public.households(name, created_by)
  values (trim(household_name), auth.uid()) returning id into new_household_id;
  insert into public.household_members(household_id, user_id, role)
  values (new_household_id, auth.uid(), 'owner');
  insert into public.household_locations(household_id, name)
  values (new_household_id, 'Lednice'), (new_household_id, 'Mrazák'), (new_household_id, 'Spíž');
  return new_household_id;
end;
$$;
grant execute on function public.create_household(text) to authenticated;
