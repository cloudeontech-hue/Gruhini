-- Adds delivery fee + serviceable-pincode configuration to the shared
-- business_settings row - see lib/state/business_settings_provider.dart
-- and lib/utils/delivery_fee.dart.
--
-- Previously the delivery fee shown at checkout (cart_screen.dart,
-- order_summary_screen.dart) was hardcoded to the literal text "Free" and
-- never actually added to what Razorpay charged - there was no
-- configuration for it at all. This migration adds real, admin-editable
-- values; the app defaults to delivery_fee = 0 until an admin sets one, so
-- existing checkouts keep behaving exactly as before until this is
-- deliberately configured.
--
-- serviceable_pincodes empty ('{}', the default) means "deliver
-- everywhere" - the same as today's behavior, where nothing checks the
-- delivery address at all. Populating it switches on the serviceability
-- check in DeliveryAddressScreen.
--
-- Run this once in the Supabase SQL editor, after
-- 20260701163100_payments_and_business_settings.sql and 20260702132100_security_hardening_bcrypt_auth.sql.
-- Idempotent - safe to re-run.

alter table business_settings
  add column if not exists delivery_fee numeric not null default 0,
  add column if not exists free_delivery_above numeric,
  add column if not exists serviceable_pincodes text[] not null default '{}';
