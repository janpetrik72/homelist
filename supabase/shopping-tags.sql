-- HomeList: štítky pro položky nákupního seznamu
-- Spusť jednou v Supabase -> SQL Editor -> New query.

alter table public.shopping_items
  add column if not exists tags text[] not null default '{}';

create index if not exists shopping_items_tags_gin_idx
  on public.shopping_items using gin (tags);


-- Štítky také u položek domácích zásob, aby se přenesly na nákupní seznam.
alter table public.inventory_items
  add column if not exists tags text[] not null default '{}';

create index if not exists inventory_items_tags_gin_idx
  on public.inventory_items using gin (tags);


-- Propojení nákupního seznamu s původní položkou v inventáři.
-- Po označení jako nakoupené se položka může vrátit do původního místa.
alter table public.shopping_items
  add column if not exists source_inventory_id uuid
  references public.inventory_items(id) on delete set null;

-- Jedna aktivní nákupní položka může odkazovat na jednu inventární položku.
create unique index if not exists shopping_items_active_inventory_source_idx
  on public.shopping_items(source_inventory_id)
  where source_inventory_id is not null and is_done = false;


-- Kategorie prodejny: null znamená automatické určení podle názvu v aplikaci.
alter table public.inventory_items
  add column if not exists category text;

alter table public.shopping_items
  add column if not exists category text;



-- Pořadí míst v domácnosti (sdílené mezi členy).
alter table public.household_locations
  add column if not exists sort_order integer;

with ranked_locations as (
  select ctid as row_tid, row_number() over (
    partition by household_id order by created_at asc, name asc
  ) - 1 as position
  from public.household_locations
)
update public.household_locations as locations
set sort_order = ranked_locations.position
from ranked_locations
where locations.ctid = ranked_locations.row_tid
  and locations.sort_order is null;

alter table public.household_locations
  alter column sort_order set default 0;
