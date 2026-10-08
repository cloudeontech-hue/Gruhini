-- Switches Customer login from Firebase Phone Auth (OTP) to Firebase
-- Google Sign-In - see lib/screens/auth/login_screen.dart and
-- lib/state/auth_provider.dart. Google proves who the customer is; this
-- app's `customers` table is still keyed by phone number everywhere
-- (orders, delivery, the admin panel), so a customer still provides a
-- phone number once, the first time they sign in with a given Google
-- account - link_google_customer() below then remembers that pairing so
-- every later sign-in with the same Google account skips straight past
-- the phone step.
--
-- The password_hash/OTP-era columns and functions from
-- 20260821151700_customer_password_auth.sql / 20260910120400_customer_otp_auth.sql
-- are left in place rather than dropped - harmless once unused. Admin and
-- Shop Owner logins are untouched by this migration.
--
-- Run this once in the Supabase SQL editor, after
-- 20260910120400_customer_otp_auth.sql. Idempotent - safe to re-run.

alter table customers add column if not exists google_uid text unique;

-- ── link_google_customer ─────────────────────────────────────────────────
-- Called right after Firebase confirms a Google sign-in. Three cases:
--
-- 1. This google_uid is already linked to a customer -> return that row
--    as-is (p_phone/p_name are ignored - the caller only has them on the
--    very first sign-in's "what's your phone number" step, not on every
--    later sign-in).
-- 2. Not linked yet, but a customer row with this phone number already
--    exists (e.g. they used the app before this migration, back when
--    login was OTP-based) -> link this Google account to that existing
--    row rather than creating a duplicate, so their existing order
--    history/address stays attached.
-- 3. Neither exists -> create a new customer row with this phone, name,
--    and google_uid all at once.
create or replace function link_google_customer(
  p_google_uid text,
  p_phone      text,
  p_name       text
)
returns table (id text, name text, phone text, address text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing record;
begin
  select c.id, c.name, c.phone, c.address
    into existing
    from public.customers c
    where c.google_uid = p_google_uid;

  if existing.id is not null then
    return query select existing.id, existing.name, existing.phone, existing.address;
    return;
  end if;

  select c.id, c.name, c.phone, c.address
    into existing
    from public.customers c
    where c.id = p_phone;

  if existing.id is not null then
    update public.customers
    set    google_uid = p_google_uid
    where  public.customers.id = p_phone;
    return query select existing.id, existing.name, existing.phone, existing.address;
    return;
  end if;

  insert into public.customers (id, name, phone, address, google_uid)
  values (p_phone, p_name, p_phone, '', p_google_uid);
  return query select p_phone, p_name, p_phone, ''::text;
end;
$$;

revoke execute on function link_google_customer(text, text, text) from public;
grant  execute on function link_google_customer(text, text, text) to   anon;

-- ── get_customer_by_google_uid ───────────────────────────────────────────
-- Used on every sign-in *after* the first, to check whether this Google
-- account already has a linked phone number before deciding whether to
-- show the "what's your phone number" step at all.
create or replace function get_customer_by_google_uid(p_google_uid text)
returns table (id text, name text, phone text, address text)
language sql
security definer
set search_path = ''
as $$
  select id, name, phone, address
  from public.customers
  where google_uid = p_google_uid;
$$;

revoke execute on function get_customer_by_google_uid(text) from public;
grant  execute on function get_customer_by_google_uid(text) to   anon;
