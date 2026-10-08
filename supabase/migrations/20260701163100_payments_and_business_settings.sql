-- Run this once in the Supabase SQL editor, after 20260626123500_initial_schema.sql
-- and 20260626123501_shop_owners.sql.
-- Adds UPI-only prepaid checkout: payment fields on orders, a richer order
-- status lifecycle, and a single-row business_settings table for the UPI
-- ID/QR/business info (previously hardcoded in the app).

alter table orders add column if not exists delivery_address text not null default '';
alter table orders add column if not exists payment_method text not null default 'upi';
alter table orders add column if not exists payment_status text not null default 'pending';
alter table orders add column if not exists payment_screenshot_url text;
alter table orders add column if not exists transaction_id text;
alter table orders add column if not exists payment_verified boolean not null default false;
alter table orders add column if not exists verified_at timestamptz;
alter table orders add column if not exists verified_by text;

-- NOTE: these literal status strings are deliberately camelCase, not
-- snake_case - the Flutter app reads/writes `status` via OrderStatus.name
-- (see lib/models/order.dart), and Dart's bare enum `.name` for
-- `OrderStatus.paymentVerification`/`outForDelivery` is the camelCase
-- identifier itself, not a snake_case version of it.
alter table orders alter column status set default 'paymentVerification';

-- Best-effort remap of any existing rows from the old 4-status lifecycle
-- (pending/packed/delivered/cancelled) onto the new 6-status one. Orders
-- already delivered/cancelled stay as-is.
update orders set status = 'paymentVerification' where status = 'pending';
update orders set status = 'preparing' where status = 'packed';

create table if not exists business_settings (
  id text primary key default 'default',
  business_name text not null default 'Gruhini Foods',
  support_phone text not null default '',
  upi_id text not null default '',
  upi_qr_url text not null default '',
  updated_at timestamptz not null default now()
);

alter table business_settings enable row level security;

-- Single shared row: the app only ever selects and updates it (see
-- lib/state/business_settings_provider.dart) - never inserts/deletes, since
-- the one row is seeded right here.
drop policy if exists "anon can read business_settings" on business_settings;
drop policy if exists "anon can update business_settings" on business_settings;
create policy "anon can read business_settings" on business_settings for select to anon using (true);
create policy "anon can update business_settings" on business_settings for update to anon using (true) with check (true);

-- Placeholder contact/UPI values only - replace via Admin > Settings (head
-- admin) before accepting real payments. Never seed real business details
-- (UPI VPA, support phone) directly in a migration script.
insert into business_settings (id, business_name, support_phone, upi_id, upi_qr_url)
values ('default', 'Gruhini Foods', '+91 00000 00000', 'replace-me@upi', '')
on conflict (id) do nothing;

-- Same public-bucket + insert/update-only anon policy pattern as
-- product-images in 20260626123500_initial_schema.sql - no anon SELECT/listing
-- policy needed, the bucket's `public` flag already serves direct URLs.
insert into storage.buckets (id, name, public)
values ('payment-screenshots', 'payment-screenshots', true)
on conflict (id) do nothing;

drop policy if exists "anon can upload payment screenshots" on storage.objects;
drop policy if exists "anon can update payment screenshots" on storage.objects;
create policy "anon can upload payment screenshots" on storage.objects
for insert to anon
with check (bucket_id = 'payment-screenshots');
create policy "anon can update payment screenshots" on storage.objects
for update to anon
using (bucket_id = 'payment-screenshots')
with check (bucket_id = 'payment-screenshots');

insert into storage.buckets (id, name, public)
values ('business-assets', 'business-assets', true)
on conflict (id) do nothing;

drop policy if exists "anon can upload business assets" on storage.objects;
drop policy if exists "anon can update business assets" on storage.objects;
create policy "anon can upload business assets" on storage.objects
for insert to anon
with check (bucket_id = 'business-assets');
create policy "anon can update business assets" on storage.objects
for update to anon
using (bucket_id = 'business-assets')
with check (bucket_id = 'business-assets');
