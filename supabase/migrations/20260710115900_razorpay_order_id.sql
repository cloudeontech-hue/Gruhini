-- Run this once in the Supabase SQL editor, after 20260701163100_payments_and_business_settings.sql
-- and 20260702132100_security_hardening_bcrypt_auth.sql.
-- Adds a single column to store the Razorpay Order id created by the
-- create-razorpay-order Edge Function, alongside the existing transaction_id
-- column (which holds the Razorpay Payment id for Razorpay-paid orders, and
-- the customer-entered UTR/reference for the manual UPI flow used on
-- web/desktop). See scripts/MIGRATION_RAZORPAY.md for the full rollout.

alter table orders add column if not exists razorpay_order_id text;
