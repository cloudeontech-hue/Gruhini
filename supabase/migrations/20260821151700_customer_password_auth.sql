-- Adds real server-side authentication for Customer accounts.
--
-- Previously, a customer's "account" only ever existed as
-- SharedPreferences on one device (see lib/state/auth_provider.dart's old
-- loginAsCustomer): logging out cleared those prefs, so logging back in -
-- even with the exact same phone number - had nothing left to compare
-- against and silently started a brand-new local identity, leaving the
-- customer's real saved address behind in Supabase, unreachable. The
-- `customers` table itself was just a write-mostly mirror for the admin
-- panel, with no password column at all.
--
-- This migration brings customer accounts in line with how admins and
-- shop owners already work (20260702132100_security_hardening_bcrypt_auth.sql):
-- passwords stored as bcrypt hashes, verified server-side via a
-- SECURITY DEFINER function, so logging in on any device (or after a
-- logout that wipes local state) reconnects to the same real account and
-- restores the saved name/address.
--
-- Run this once in the Supabase SQL editor, after
-- 20260626123500_initial_schema.sql and 20260702132100_security_hardening_bcrypt_auth.sql.
-- Idempotent - safe to re-run.

alter table customers add column if not exists password_hash text;

-- ── login_or_create_customer ─────────────────────────────────────────────
-- Single entry point matching the app's single-form signup/login UX (see
-- lib/screens/auth/login_screen.dart - there's no separate "sign up"
-- screen). Handles three cases:
--
-- 1. Phone not on file at all -> creates a new customer row, bcrypt-hashes
--    the password server-side.
-- 2. Phone on file but password_hash is null -> a pre-migration row
--    created before this fix existed (no password was ever stored for
--    it). Claims the account: sets password_hash to whatever password is
--    given now, exactly like the old device-local trust model did. Not
--    fully secure (anyone who knows the phone number and gets to it
--    before the real owner could claim it first) but it's the same trust
--    level the app has always had for customers, and there is no OTP/SMS
--    verification infrastructure to lean on instead - see the "Known
--    limitation" note below.
-- 3. Phone on file with a password_hash already set -> normal login,
--    verifies the bcrypt hash. Returns zero rows if the password is
--    wrong (mirrors authenticate_admin/authenticate_shop_owner's
--    zero-or-one-row convention - the Dart caller checks for an empty
--    result rather than getting a distinct error).
--
-- Returns the customer's *real* name/address from the server on success,
-- not just whatever was typed into the form this time - that's what
-- actually fixes the "logout then login re-asks for everything" bug.
create or replace function login_or_create_customer(
  p_name     text,
  p_phone    text,
  p_password text
)
returns table (id text, name text, phone text, address text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing record;
begin
  select c.id, c.name, c.phone, c.address, c.password_hash
    into existing
    from public.customers c
    where c.id = p_phone;

  if existing.id is null then
    insert into public.customers (id, name, phone, address, password_hash)
    values (
      p_phone,
      p_name,
      p_phone,
      '',
      extensions.crypt(p_password, extensions.gen_salt('bf', 12))
    );
    return query select p_phone, p_name, p_phone, ''::text;
    return;
  end if;

  if existing.password_hash is null then
    -- id must be qualified here (public.customers.id, not bare id) -
    -- this function's RETURNS TABLE(id text, ...) makes `id` ambiguous
    -- otherwise: PL/pgSQL can't tell if it means the output column or
    -- the customers table's column of the same name (error 42702).
    update public.customers
    set    password_hash = extensions.crypt(p_password, extensions.gen_salt('bf', 12))
    where  public.customers.id = p_phone;
    return query select existing.id, existing.name, existing.phone, existing.address;
    return;
  end if;

  if extensions.crypt(p_password, existing.password_hash) = existing.password_hash then
    return query select existing.id, existing.name, existing.phone, existing.address;
  end if;
  -- Wrong password: fall through and return zero rows.
end;
$$;

revoke execute on function login_or_create_customer(text, text, text) from public;
grant  execute on function login_or_create_customer(text, text, text) to   anon;

-- ── reset_customer_password ──────────────────────────────────────────────
-- Known limitation, same trust level as the pre-migration local-only
-- design: resets a customer's password given only their phone number, no
-- OTP/SMS/email verification of ownership. Anyone who knows a customer's
-- phone number could reset their password and see their saved name/
-- address (no payment data - Razorpay handles that separately and isn't
-- touched by this). This is an accepted, pre-existing risk carried
-- forward, not introduced by this migration - see
-- 20260702132100_security_hardening_bcrypt_auth.sql's "Known accepted risks" section
-- for the same reasoning applied elsewhere. Add real OTP verification
-- (e.g. via an SMS provider) before this app handles anything more
-- sensitive than a food order.
create or replace function reset_customer_password(
  p_phone       text,
  p_new_password text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.customers
  set    password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf', 12))
  where  id = p_phone
  returning true;
$$;

revoke execute on function reset_customer_password(text, text) from public;
grant  execute on function reset_customer_password(text, text) to   anon;

-- ── Tighten RLS: customers password_hash column ──────────────────────────
-- Same pattern as shop_owners in 20260702132100_security_hardening_bcrypt_auth.sql - anon can
-- still SELECT customer rows (admin panel needs this), just not the
-- password_hash column via the REST API.
revoke select (password_hash) on customers from anon;

-- ── Remove the raw anon INSERT policy on customers ───────────────────────
-- Customer creation now goes through login_or_create_customer() above,
-- which bcrypt-hashes the password. The old "anon can insert customers"
-- policy (from 20260626123500_initial_schema.sql, `with check true`) let the client
-- (or anyone calling the REST API directly) insert a customer row with no
-- password_hash at all - exactly the gap that caused this migration.
-- Same reasoning as removing shop_owners' equivalent policy once
-- create_shop_owner() took over in 20260702132100_security_hardening_bcrypt_auth.sql.
drop policy if exists "anon can insert customers" on customers;

-- ── Allow customers to update their own name/address ─────────────────────
-- Previously there was no anon UPDATE policy on customers at all
-- (20260626123500_initial_schema.sql's comment: "It never updates or deletes a customer
-- row"), so AuthProvider.updateCustomerAddress() only ever wrote to local
-- SharedPreferences - never to Supabase. That meant an address edit
-- looked saved on the device that made it, but a fresh login_or_create_
-- customer() call (a different device, or this device after local
-- storage is cleared) would still return the old address from signup
-- time. Column-level grant, not a blanket UPDATE - password_hash stays
-- unreachable except through the RPCs above.
drop policy if exists "anon can update customers" on customers;
create policy "anon can update customers"
  on customers for update to anon
  using (true)
  with check (true);
revoke update on customers from anon;
grant  update (name, address) on customers to anon;
