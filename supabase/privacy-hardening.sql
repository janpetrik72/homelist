-- HomeList: zpřísnění soukromí a jednorázové pozvánky
-- Spusť jednou v Supabase SQL Editoru. Opakované spuštění je bezpečné.
-- Předpokládá, že existují tabulky včetně household_locations a household_invites.

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.inventory_items enable row level security;
alter table public.shopping_items enable row level security;
alter table public.household_locations enable row level security;
alter table public.household_invites enable row level security;

revoke all on table public.households from public, anon, authenticated;
revoke all on table public.household_members from public, anon, authenticated;
revoke all on table public.inventory_items from public, anon, authenticated;
revoke all on table public.shopping_items from public, anon, authenticated;
revoke all on table public.household_locations from public, anon, authenticated;
revoke all on table public.household_invites from public, anon, authenticated;

grant select on table public.households to authenticated;
grant select on table public.household_members to authenticated;
grant select, insert, update, delete on table public.inventory_items to authenticated;
grant select, insert, update, delete on table public.shopping_items to authenticated;
grant select, insert, delete on table public.household_locations to authenticated;

revoke all on function public.is_household_member(uuid) from public, anon, authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
revoke all on function public.create_household(text) from public, anon, authenticated;
grant execute on function public.create_household(text) to authenticated;
revoke all on function public.create_household_invite(uuid) from public, anon, authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;
revoke all on function public.join_household_with_code(text) from public, anon, authenticated;
grant execute on function public.join_household_with_code(text) to authenticated;

alter table public.household_invites
  add column if not exists used_at timestamptz,
  add column if not exists used_by uuid references auth.users(id) on delete set null;

create or replace function public.create_household_invite(target_household uuid)
returns text language plpgsql security definer set search_path = public, extensions
as $$
declare new_code text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.household_members
    where household_id = target_household and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'Pozvánku může vytvořit pouze správce domácnosti.';
  end if;
  new_code := upper(encode(extensions.gen_random_bytes(16), 'hex'));
  insert into public.household_invites(household_id, code, created_by)
  values (target_household, new_code, auth.uid());
  return new_code;
end;
$$;
revoke all on function public.create_household_invite(uuid) from public, anon, authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;

create or replace function public.join_household_with_code(invite_code_input text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare target_household uuid; target_invite uuid;
begin
  if auth.uid() is null then raise exception 'Nejdřív se přihlas.'; end if;
  select id, household_id into target_invite, target_household
  from public.household_invites
  where code = upper(trim(invite_code_input))
    and expires_at > now() and used_at is null
  order by created_at desc
  limit 1
  for update;
  if target_household is null then
    raise exception 'Pozvánkový kód není platný, už byl použit nebo vypršel.';
  end if;
  insert into public.household_members(household_id, user_id, role)
  values (target_household, auth.uid(), 'member')
  on conflict (household_id, user_id) do nothing;
  update public.household_invites
  set used_at = now(), used_by = auth.uid()
  where id = target_invite;
  return target_household;
end;
$$;
revoke all on function public.join_household_with_code(text) from public, anon, authenticated;
grant execute on function public.join_household_with_code(text) to authenticated;
