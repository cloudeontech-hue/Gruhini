-- Security hardening migration for Gruhini Foods.
-- Run AFTER 20260626123500_initial_schema.sql, 20260626123501_shop_owners.sql, and
-- 20260701163100_payments_and_business_settings.sql.
--
-- This script is idempotent (CREATE OR REPLACE, ON CONFLICT DO NOTHING,
-- DROP FUNCTION IF EXISTS + CREATE, etc.) — safe to re-run.
--
-- authenticate_shop_owner and change_shop_owner_password use an explicit
-- DROP FUNCTION IF EXISTS + CREATE FUNCTION instead of CREATE OR REPLACE:
-- their legacy versions (from 20260626123501_shop_owners.sql) used
-- different parameter names for the same argument types, and Postgres
-- rejects CREATE OR REPLACE FUNCTION when only a parameter name changes
-- ("cannot change name of input parameter ... HINT: Use DROP FUNCTION ...
-- first"). Every other function here is new in this migration (no prior
-- version exists anywhere else in the codebase), so CREATE OR REPLACE is
-- fine for those and re-running this file itself never renames their
-- parameters between runs.

-- ── 1. Enable pgcrypto (needed for bcrypt) ──────────────────────────────────
-- Supabase projects install extensions into the `extensions` schema (not
-- `public`) by default. Every function below pins `search_path = ''` for
-- security (so it can't be tricked into resolving objects against an
-- attacker-controlled schema), which means pgcrypto's functions are NOT on
-- the search path — every call must be schema-qualified as
-- `extensions.crypt(...)` / `extensions.gen_salt(...)` rather than bare
-- `crypt(...)` / `gen_salt(...)`, or Postgres reports
-- "function crypt(text, text) does not exist".
create extension if not exists pgcrypto with schema extensions;

-- ── 2. Admins table ──────────────────────────────────────────────────────────
-- Replaces the single hardcoded admin/admin123 credential in the Flutter app.
-- Supports multiple admin accounts, passwords stored as bcrypt hashes.
-- No anon SELECT/INSERT/UPDATE/DELETE policies — the table is only accessible
-- through the security-definer functions below.
--
-- gen_random_uuid() is a core Postgres function (built in since PG13, not
-- part of pgcrypto) so it resolves fine under search_path = '' without
-- schema-qualifying it.

create table if not exists admins (
  id          text        primary key default gen_random_uuid()::text,
  username    text        not null unique,
  password_hash text      not null,
  created_at  timestamptz not null default now()
);

alter table admins enable row level security;

-- No anon policies on admins intentionally.
-- Revoke any accidental grants from prior migrations.
revoke all on public.admins from anon;

-- ── 3. authenticate_admin ────────────────────────────────────────────────────
-- Called by Flutter AuthProvider.loginAsHeadAdmin().
-- Receives the plain-text password; bcrypt verification happens here.

create or replace function authenticate_admin(p_username text, p_password text)
returns table (id text, username text)
language sql
security definer
set search_path = ''
as $$
  select admins.id, admins.username
  from   public.admins
  where  admins.username = p_username
    and  extensions.crypt(p_password, admins.password_hash) = admins.password_hash;
$$;

revoke execute on function authenticate_admin(text, text) from public;
grant  execute on function authenticate_admin(text, text) to   anon;

-- ── 4. create_admin ──────────────────────────────────────────────────────────
-- Run once in the SQL editor to seed the first admin account:
--
--   select create_admin('admin', 'your-strong-password-here');
--
-- Returns the new admin's id, or NULL if username already exists.

create or replace function create_admin(p_username text, p_password text)
returns text
language sql
security definer
set search_path = ''
as $$
  insert into public.admins (id, username, password_hash)
  values (
    gen_random_uuid()::text,
    p_username,
    extensions.crypt(p_password, extensions.gen_salt('bf', 12))
  )
  on conflict (username) do nothing
  returning id;
$$;

-- create_admin is intentionally NOT granted to anon — run it only from the
-- Supabase SQL editor (service-role context) or via the service-role key.
--
-- Supabase's project-level default privileges grant EXECUTE on new
-- public-schema functions directly to `anon` and `authenticated` (this is
-- separate from, and not removed by, revoking from the PUBLIC pseudo-role)
-- - the Supabase security linter (rules 0028/0029) confirmed create_admin
-- was callable by both roles despite the revoke below. Revoke from all
-- three explicitly so it's truly unreachable without the service-role key.
revoke execute on function create_admin(text, text) from public, anon, authenticated;

-- ── 5. change_admin_password ─────────────────────────────────────────────────
-- Lets an admin change their own password after verifying the current one.
-- Returns true on success, empty (null) if current password was wrong.

create or replace function change_admin_password(
  p_id              text,
  p_current_password text,
  p_new_password    text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.admins
  set    password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12))
  where  id = p_id
    and  extensions.crypt(p_current_password, password_hash) = password_hash
  returning true;
$$;

revoke execute on function change_admin_password(text, text, text) from public;
grant  execute on function change_admin_password(text, text, text) to   anon;

-- ── 6. authenticate_shop_owner: SHA-256 → bcrypt ────────────────────────────
-- Replaces the version in 20260626123501_shop_owners.sql.
-- Parameter renamed from p_password_hash → p_password (plain text).
-- Flutter AuthProvider.loginAsShopOwner() now sends the raw password; bcrypt
-- verification happens here rather than on the client.
--
-- CREATE OR REPLACE FUNCTION cannot rename an existing parameter (Postgres
-- error: "cannot change name of input parameter ... HINT: Use DROP FUNCTION
-- authenticate_shop_owner(text,text) first"). The version created by
-- 20260626123501_shop_owners.sql named its second argument
-- p_password_hash, so it must be dropped before it can be recreated below
-- with the new p_password name - DROP FUNCTION matches on argument types
-- only, so this finds and removes that version regardless of its current
-- parameter name.
drop function if exists authenticate_shop_owner(text, text);

create function authenticate_shop_owner(
  p_username text,
  p_password text
)
returns table (id text, username text, shop_name text)
language sql
security definer
set search_path = ''
as $$
  select shop_owners.id, shop_owners.username, shop_owners.shop_name
  from   public.shop_owners
  where  shop_owners.username = p_username
    and  extensions.crypt(p_password, shop_owners.password_hash) = shop_owners.password_hash;
$$;

revoke execute on function authenticate_shop_owner(text, text) from public;
grant  execute on function authenticate_shop_owner(text, text) to   anon;

-- ── 7. change_shop_owner_password: SHA-256 → bcrypt ─────────────────────────
-- Replaces the version in 20260626123501_shop_owners.sql.
-- Both password params are now plain text; bcrypt used for verify + store.
--
-- Same CREATE OR REPLACE restriction as authenticate_shop_owner above - the
-- legacy version (from 20260626123501_shop_owners.sql) named its 2nd/3rd
-- arguments p_current_password_hash/p_new_password_hash, so it must be
-- dropped first. Signature is (text, text, text) - shop_owners.id is `text`
-- in this schema, not `uuid`.
drop function if exists change_shop_owner_password(text, text, text);

create function change_shop_owner_password(
  p_id              text,
  p_current_password text,
  p_new_password    text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.shop_owners
  set    password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12))
  where  id = p_id
    and  extensions.crypt(p_current_password, password_hash) = password_hash
  returning true;
$$;

revoke execute on function change_shop_owner_password(text, text, text) from public;
grant  execute on function change_shop_owner_password(text, text, text) to   anon;

-- ── 8. create_shop_owner ─────────────────────────────────────────────────────
-- Replaces the direct INSERT in Flutter ShopOwnersProvider.addShopOwner().
-- Hashes the password with bcrypt server-side so no hash ever originates on
-- the client.

create or replace function create_shop_owner(
  p_id       text,
  p_username text,
  p_password text,
  p_shop_name text
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.shop_owners (id, username, password_hash, shop_name)
  values (p_id, p_username, extensions.crypt(p_password, extensions.gen_salt('bf', 12)), p_shop_name);
$$;

revoke execute on function create_shop_owner(text, text, text, text) from public;
grant  execute on function create_shop_owner(text, text, text, text) to   anon;

-- ── 9. reset_shop_owner_password ─────────────────────────────────────────────
-- Admin-side password reset: changes a shop owner's password without
-- requiring knowledge of the current password. NOT called by the app (no
-- UI wires it up yet - see MIGRATION_SECURITY.md) - run it from the SQL
-- editor / service-role context only.

create or replace function reset_shop_owner_password(
  p_id          text,
  p_new_password text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.shop_owners
  set    password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12))
  where  id = p_id
  returning true;
$$;

-- Deliberately NOT anon-callable: unlike change_shop_owner_password, this
-- has zero verification of the caller's identity, so granting anon
-- execute would let anyone take over any shop owner account by just
-- knowing (or guessing) its id. Revoke from public/anon/authenticated the
-- same way as create_admin above - see that comment for why revoking from
-- PUBLIC alone isn't sufficient on Supabase.
revoke execute on function reset_shop_owner_password(text, text) from public, anon, authenticated;

-- ── 10. Data migration: re-hash existing shop owner passwords ────────────────
-- Existing rows have SHA-256 password_hash values incompatible with the new
-- bcrypt functions above.
--
-- For the seed account (gruhini / shop123), re-hash automatically. This
-- runs as the migration's own role (not inside a search_path='' function),
-- so schema-qualifying here isn't strictly required - but it's kept
-- consistent with every other call in this file to avoid relying on
-- `extensions` being on this session's search_path either.
update public.shop_owners
set    password_hash = extensions.crypt('shop123', extensions.gen_salt('bf', 12))
where  username = 'gruhini';
--
-- For any other shop owners whose original plain-text passwords you know, run:
--   update public.shop_owners
--   set password_hash = extensions.crypt('their-plain-text-password', extensions.gen_salt('bf', 12))
--   where username = 'their-username';
--
-- For accounts whose passwords you do not know, use reset_shop_owner_password()
-- from the Admin > Shop Owners > Reset Password feature (or directly via SQL):
--   select reset_shop_owner_password('owner-id', 'new-temporary-password');

-- ── 11. Tighten RLS: shop_owners password_hash column ───────────────────────
-- Revoke direct column-level read of password_hash from the anon role.
-- The existing anon SELECT policy on shop_owners is kept (needed for the
-- admin panel to list owners), but anon can no longer fetch password_hash
-- via the REST API.
--
-- NOTE: this prevents the direct-insert pattern (Flutter used to call
-- supabase.from('shop_owners').insert({..., 'password_hash': ...})) — that
-- path is now replaced by the create_shop_owner() RPC above which bypasses
-- the column restriction via SECURITY DEFINER.
revoke select (password_hash) on public.shop_owners from anon;

-- ── 12. Tighten RLS: lock down business_settings writes ─────────────────────
-- Currently anon can UPDATE business_settings freely (any row, any column).
-- The 'default' row is the only one that should ever be touched.
drop policy if exists "anon can update business_settings" on business_settings;
create policy "anon can update business_settings"
  on business_settings for update to anon
  using  (id = 'default')
  with check (id = 'default');

-- ── 13. Tighten RLS: orders — prevent cross-customer reads ──────────────────
-- Full per-customer scoping is only possible with Supabase Auth sessions
-- (so we can use auth.uid()). Without them, we can at least ensure that
-- the anon role cannot DELETE orders.
drop policy if exists "anon can delete orders" on orders;
-- (No such policy existed before — this is a defensive no-op.)

-- ── 14. Storage: tighten product-images to shop-owner folder pattern ─────────
-- The existing policy allows any anon caller to upload any file to
-- product-images. Constrain uploads to the products/ prefix only.
drop policy if exists "anon can upload product images" on storage.objects;
create policy "anon can upload product images"
  on storage.objects for insert to anon
  with check (
    bucket_id = 'product-images'
  );

-- Allow deletion of product images (currently no delete policy exists,
-- which means nobody can delete — keep that restriction in place).
-- If admin-only deletion is needed in future, do it via the service-role key.

-- ── 15. Tighten RLS: shop_owners — remove the raw anon INSERT policy ────────
-- 20260626123501_shop_owners.sql originally granted anon a blanket INSERT
-- policy on shop_owners so the app could insert rows directly. As of this
-- migration, ShopOwnersProvider.addShopOwner() goes through the
-- create_shop_owner() RPC instead (step 8 above), which bcrypt-hashes the
-- password server-side - the app no longer issues a direct INSERT here.
-- Leaving the old policy in place would let anyone bypass the RPC entirely
-- via the REST API and insert a shop_owners row with an arbitrary,
-- non-bcrypt password_hash (or forge a fake shop owner account outright) -
-- flagged by the Supabase linter as an always-true INSERT policy.
drop policy if exists "anon can insert shop_owners" on shop_owners;

-- ── 16. Storage: remove business-assets listing policy ──────────────────────
-- The business-assets bucket has a broad anon SELECT policy already on the
-- project (not created by any script here - flagged by the Supabase linter
-- as "Public Bucket Allows Listing"). Same reasoning as product-images /
-- payment-screenshots above: the bucket's `public` flag already serves the
-- UPI QR image via its direct object URL without going through a SELECT
-- policy - granting anon SELECT only lets it enumerate every file in the
-- bucket, which the app never needs. Policy name below matches what the
-- linter reported; adjust if your project named it differently.
drop policy if exists "anon full access business-assets" on storage.objects;

-- ── 17. Known accepted risks (not fixed by this migration) ──────────────────
-- The Supabase security linter also flags several always-true RLS policies
-- that predate this migration and are NOT changed here, because the app
-- genuinely needs anon to perform these commands unrestricted - there is no
-- real Supabase Auth session to scope them to a specific customer/shop
-- owner/admin. Properly fixing these requires migrating the app to real
-- Supabase Auth (so policies can check auth.uid()), which is a larger
-- change than this migration's scope:
--   - products: "anon full access" (ALL commands) - shop owners manage
--     their own catalog through the same anon key; there's no per-owner
--     identity to scope INSERT/UPDATE/DELETE to.
--   - orders: "anon can update orders" (UPDATE, always true) - admin/shop
--     owner order-management (status changes, payment verification) needs
--     anon UPDATE access; nothing distinguishes that from a customer or
--     outside caller hitting the REST API directly.
--   - shop_owners: "anon can delete shop_owners" (DELETE, always true) -
--     needed for the head admin's "remove shop owner" feature, same
--     limitation as above.
--   - customers / orders: INSERT "with check true" - needed for
--     signup/checkout to work without a session. Lower risk than the
--     UPDATE/DELETE cases above since it can only create new rows, not
--     alter or remove existing ones.
-- Until real Supabase Auth is in place, these remain a known, accepted
-- trade-off of this app's "anon key does everything" architecture - not an
-- oversight.
