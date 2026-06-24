-- Run this once in the Supabase SQL editor, after scripts/supabase_schema.sql.
-- Adds the multi-vendor model: many shop owners ("sub admins"), each with
-- their own products and orders, overseen by the single head admin (which
-- stays hardcoded in the app — see lib/state/auth_provider.dart).

create table if not exists shop_owners (
  id text primary key,
  username text not null unique,
  password_hash text not null,
  shop_name text not null,
  created_at timestamptz not null default now()
);

alter table products add column if not exists shop_owner_id text references shop_owners(id);
alter table orders add column if not exists shop_owner_id text references shop_owners(id);

alter table shop_owners enable row level security;

-- The anon key is used for everything (no real Supabase Auth session). A
-- column-level revoke on password_hash was tried here but breaks upsert
-- (INSERT ... ON CONFLICT needs table-level SELECT to check for conflicts),
-- so this is the same open "anon full access" pattern as the other tables.
-- The app itself never selects password_hash directly — login goes through
-- the authenticate_shop_owner() function below — but be aware the anon key
-- could still read it directly via the REST API if someone tried.
drop policy if exists "anon full access" on shop_owners;
create policy "anon full access" on shop_owners for all to anon using (true) with check (true);
-- Restores full SELECT in case an earlier version of this script revoked it
-- (column-level grants broke upsert's ON CONFLICT check — see note above).
grant select on shop_owners to anon;

create or replace function authenticate_shop_owner(p_username text, p_password_hash text)
returns table (id text, username text, shop_name text)
language sql
security definer
as $$
  select shop_owners.id, shop_owners.username, shop_owners.shop_name
  from shop_owners
  where shop_owners.username = p_username
    and shop_owners.password_hash = p_password_hash;
$$;

grant execute on function authenticate_shop_owner(text, text) to anon;
