-- HomeList: zpřísnění soukromí a jednorázové pozvánky
-- Spusť jednou v Supabase SQL Editoru. Opakované spuštění je bezpečné.

-- 1) Zapni RLS na všech tabulkách, které aplikace používá.
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.inventory_items enable row level security;
alter table public.shopping_items enable row level security;
alter table public.household_locations enable row level security;
alter table public.household_invites enable row level security;

-- 2) Odeber přístup nepřihlášeným a nastav minimální oprávnění přihlášeným.
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
-- household_invites se čtou a mění pouze přes zabezpečené databázové funkce.

-- 3) Pomocná funkce pro RLS nesmí být volatelná nepřihlášenými.
revoke all on function public.is_household_member(uuid) from public, anon, authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;

-- 4) RPC funkce mohou používat pouze přihlášení uživatelé.
revoke all on function public.create_household(text) from public, anon, authenticated;
grant execute on function public.create_household(text) to authenticated;

revoke all on function public.create_household_invite(uuid) from public, anon, authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;
-- Funkce používá pgcrypto; v tomto projektu je rozšíření ve schématu extensions.
alter function public.create_household_invite(uuid)
  set search_path = public, extensions;

revoke all on function public.join_household_with_code(text) from public, anon, authenticated;
grant execute on function public.join_household_with_code(text) to authenticated;

-- 5) Pozvánkový kód lze použít jen jednou, i když ještě nevypršel.
alter table public.household_invites
  add column if not exists used_at timestamptz,
  add column if not exists used_by uuid references auth.users(id) on delete set null;

create or replace function public.join_household_with_code(invite_code_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_household uuid;
  target_invite uuid;
begin
  if auth.uid() is null then
    raise exception 'Nejdřív se přihlas.';
  end if;

  select id, household_id
    into target_invite, target_household
  from public.household_invites
  where code = upper(trim(invite_code_input))
    and expires_at > now()
    and used_at is null
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
