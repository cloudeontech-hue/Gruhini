-- Switches Customer login from password-based to Firebase Phone Auth
-- (OTP) - see lib/screens/auth/login_screen.dart and
-- lib/state/auth_provider.dart. Firebase verifies phone ownership via a
-- real SMS code before the app ever calls Supabase, so there is no
-- password left to check server-side - get_or_create_customer() below
-- just fetches or creates the customer row keyed by phone, the same way
-- login_or_create_customer() did, minus all the password_hash handling.
--
-- The password_hash column and login_or_create_customer/
-- reset_customer_password functions from
-- 20260821151700_customer_password_auth.sql are left in place rather than
-- dropped - harmless once unused, and dropping them isn't necessary for
-- this change to work. Admin and Shop Owner logins are untouched by this
-- migration; they still use their own bcrypt password RPCs.
--
-- Run this once in the Supabase SQL editor, after
-- 20260821151700_customer_password_auth.sql. Idempotent - safe to re-run.

create or replace function get_or_create_customer(
  p_phone text,
  p_name  text
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
    where c.id = p_phone;

  if existing.id is null then
    insert into public.customers (id, name, phone, address)
    values (p_phone, p_name, p_phone, '');
    return query select p_phone, p_name, p_phone, ''::text;
    return;
  end if;

  return query select existing.id, existing.name, existing.phone, existing.address;
end;
$$;

revoke execute on function get_or_create_customer(text, text) from public;
grant  execute on function get_or_create_customer(text, text) to   anon;
