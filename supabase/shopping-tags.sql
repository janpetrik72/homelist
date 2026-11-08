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
