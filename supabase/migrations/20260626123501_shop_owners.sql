-- Run this once in the Supabase SQL editor, after 20260626123500_initial_schema.sql.
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
-- so this is the same open anon-access pattern as the other tables, scoped
-- to only the commands ShopOwnersProvider actually issues: select (admin
-- list + login lookup), insert (add shop owner), delete (remove shop
-- owner). It never updates a shop owner row, so that command isn't granted.
-- The app itself never selects password_hash directly — login goes through
-- the authenticate_shop_owner() function below — but be aware the anon key
-- could still read it directly via the REST API if someone tried.
drop policy if exists "anon full access" on shop_owners;
drop policy if exists "anon can read shop_owners" on shop_owners;
drop policy if exists "anon can insert shop_owners" on shop_owners;
drop policy if exists "anon can delete shop_owners" on shop_owners;
create policy "anon can read shop_owners" on shop_owners for select to anon using (true);
create policy "anon can insert shop_owners" on shop_owners for insert to anon with check (true);
create policy "anon can delete shop_owners" on shop_owners for delete to anon using (true);
-- Restores full SELECT in case an earlier version of this script revoked it
-- (column-level grants broke upsert's ON CONFLICT check — see note above).
grant select on shop_owners to anon;

-- search_path is pinned to '' (rather than left to inherit the caller's) so
-- this security-definer function can't be tricked into resolving
-- shop_owners against an attacker-controlled schema; that's why the table
-- reference below is fully qualified as public.shop_owners.
create or replace function authenticate_shop_owner(p_username text, p_password_hash text)
returns table (id text, username text, shop_name text)
language sql
security definer
set search_path = ''
as $$
  select shop_owners.id, shop_owners.username, shop_owners.shop_name
  from public.shop_owners
  where shop_owners.username = p_username
    and shop_owners.password_hash = p_password_hash;
$$;

-- New functions are EXECUTE-granted to PUBLIC by default, which the
-- `authenticated` role inherits from - revoke that first so only `anon`
-- (the only role this app's login flow ever uses) can call it.
revoke execute on function authenticate_shop_owner(text, text) from public;
grant execute on function authenticate_shop_owner(text, text) to anon;

-- Lets a shop owner self-service their password (see
-- lib/state/shop_owners_provider.dart) without granting anon a blanket
-- UPDATE policy on shop_owners - same security-definer + pinned search_path
-- pattern as authenticate_shop_owner above, with the old-password check
-- folded into the same statement to avoid a separate read of password_hash.
create or replace function change_shop_owner_password(
  p_id text,
  p_current_password_hash text,
  p_new_password_hash text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.shop_owners
  set password_hash = p_new_password_hash
  where id = p_id and password_hash = p_current_password_hash
  returning true;
$$;

revoke execute on function change_shop_owner_password(text, text, text) from public;
grant execute on function change_shop_owner_password(text, text, text) to anon;
