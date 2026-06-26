-- ============================================================
-- PisoWise database schema (PostgreSQL / Supabase)
-- ============================================================
-- Paste this whole file into the Supabase SQL Editor and click "Run".
-- It creates 4 tables and the security rules that keep each user's
-- data private. Read the comments — they explain what each part does.
--
-- KEY IDEA: every row carries a `user_id`. Supabase fills it in from
-- the logged-in user, and the "row level security" (RLS) policies at
-- the bottom make it physically impossible to read or change a row
-- that isn't yours — even if someone edits the app's JavaScript.
-- ============================================================


-- ------------------------------------------------------------
-- WALLETS  (your accounts / assets: Cash, GCash, BPI ...)
-- ------------------------------------------------------------
create table wallets (
  id         uuid primary key default gen_random_uuid(),   -- unique row id
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  icon       text not null default '👛',
  color      text not null default '#1f8a4c',
  balance    numeric not null default 0,                    -- starting balance
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- CATEGORIES  (kind tells expense vs income apart)
-- ------------------------------------------------------------
create table categories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('expense', 'income')),
  name       text not null,
  icon       text not null,
  color      text not null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- TRANSACTIONS  (expense, income, or transfer)
-- ------------------------------------------------------------
-- We keep category/wallet as text names (not foreign keys) so this
-- matches the app you already built with the least rewriting. A more
-- "normalized" design would link by id — a good future refactor.
create table transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  type        text not null check (type in ('expense', 'income', 'transfer')),
  description text,
  amount      numeric not null check (amount > 0),
  category    text,           -- for expense / income
  wallet      text,           -- for expense / income
  from_wallet text,           -- for transfer
  to_wallet   text,           -- for transfer
  occurred_at timestamptz not null default now(),  -- when it happened
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- BUDGETS  (one monthly limit per expense category)
-- ------------------------------------------------------------
create table budgets (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references auth.users (id) on delete cascade,
  category text not null,
  amount   numeric not null check (amount > 0),
  unique (user_id, category)   -- can't budget the same category twice
);


-- ============================================================
-- ROW LEVEL SECURITY  (the actual "secured" part)
-- ============================================================
-- 1) Turn RLS on for each table. Once on, NObody can read/write
--    anything until a policy explicitly allows it.
alter table wallets      enable row level security;
alter table categories   enable row level security;
alter table transactions enable row level security;
alter table budgets      enable row level security;

-- 2) Allow each logged-in user to do anything ONLY on their own rows.
--    auth.uid() is the id of the currently logged-in user.
--    USING   = which rows you may read/update/delete.
--    WITH CHECK = which rows you may insert/update to.
create policy "own wallets" on wallets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own categories" on categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own transactions" on transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own budgets" on budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ============================================================
-- SPEED  (indexes so "give me MY rows" stays fast as data grows)
-- ============================================================
create index on wallets      (user_id);
create index on categories   (user_id);
create index on transactions (user_id, occurred_at desc);
create index on budgets      (user_id);
