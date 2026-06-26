-- ============================================================
-- PisoWise fix: remove duplicate seed rows + stop them recurring
-- Run this ONCE in the Supabase SQL Editor (it's safe to re-run).
-- ============================================================

-- 1) Delete duplicate CATEGORIES, keeping one of each (user_id, kind, name).
delete from categories c
using (
  select user_id, kind, name, min(ctid) as keep
  from categories
  group by user_id, kind, name
) d
where c.user_id = d.user_id
  and c.kind    = d.kind
  and c.name    = d.name
  and c.ctid   <> d.keep;

-- 2) Delete duplicate WALLETS, keeping one of each (user_id, name).
delete from wallets w
using (
  select user_id, name, min(ctid) as keep
  from wallets
  group by user_id, name
) d
where w.user_id = d.user_id
  and w.name    = d.name
  and w.ctid   <> d.keep;

-- 3) Add the unique rules so duplicates can never happen again.
--    (Wrapped so re-running this file doesn't error if they already exist.)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'categories_user_kind_name_key') then
    alter table categories add constraint categories_user_kind_name_key unique (user_id, kind, name);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'wallets_user_name_key') then
    alter table wallets add constraint wallets_user_name_key unique (user_id, name);
  end if;
end $$;
