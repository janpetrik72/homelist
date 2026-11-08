-- HomeList: založení domácnosti a pozvánky pro rodinu
-- Spusť v Supabase -> SQL Editor -> New query.

create table if not exists public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days')
);

alter table public.household_invites enable row level security;

create or replace function public.create_household(household_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_household_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Musíš být přihlášený.';
  end if;
  if char_length(trim(household_name)) < 1 or char_length(trim(household_name)) > 80 then
    raise exception 'Název domácnosti musí mít 1 až 80 znaků.';
  end if;

  insert into public.households(name, created_by)
  values (trim(household_name), auth.uid())
  returning id into new_household_id;

  insert into public.household_members(household_id, user_id, role)
  values (new_household_id, auth.uid(), 'owner');

  return new_household_id;
end;
$$;

create or replace function public.create_household_invite(target_household uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare new_code text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.household_members
    where household_id = target_household and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'Pozvánku může vytvořit pouze správce domácnosti.';
  end if;

  new_code := upper(encode(gen_random_bytes(5), 'hex'));
  insert into public.household_invites(household_id, code, created_by)
  values (target_household, new_code, auth.uid());
  return new_code;
end;
$$;

create or replace function public.join_household_with_code(invite_code_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare target_household uuid;
begin
  if auth.uid() is null then
    raise exception 'Nejdřív se přihlas.';
  end if;

  select household_id into target_household
  from public.household_invites
  where code = upper(trim(invite_code_input))
    and expires_at > now()
  order by created_at desc
  limit 1;

  if target_household is null then
    raise exception 'Pozvánkový kód není platný nebo už vypršel.';
  end if;

  insert into public.household_members(household_id, user_id, role)
  values (target_household, auth.uid(), 'member')
  on conflict (household_id, user_id) do nothing;

  return target_household;
end;
$$;

revoke all on function public.create_household(text) from public;
revoke all on function public.create_household_invite(uuid) from public;
revoke all on function public.join_household_with_code(text) from public;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;
grant execute on function public.join_household_with_code(text) to authenticated;
