-- Run this once in the Supabase SQL editor (Project > SQL Editor > New query).
-- Sets up tables + storage for products, customers, and orders.
--
-- NOTE: the app keeps its current hardcoded admin login and local customer
-- profile (no Supabase Auth session), so policies below grant the `anon`
-- role full read/write access. This is intentionally open for now.

create table if not exists products (
  id text primary key,
  name text not null,
  category text not null,
  price numeric not null,
  unit text not null,
  image_path text not null default '',
  description text not null default '',
  in_stock boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists customers (
  id text primary key,
  name text not null,
  phone text not null,
  address text not null default '',
  joined_date timestamptz not null default now()
);

create table if not exists orders (
  id text primary key,
  customer_name text not null,
  customer_phone text not null,
  items jsonb not null,
  total numeric not null,
  placed_at timestamptz not null default now(),
  status text not null default 'pending'
);

alter table products enable row level security;
alter table customers enable row level security;
alter table orders enable row level security;

-- products genuinely needs every command via anon (shop owners manage their
-- own catalog through the same shared key, with no real per-owner identity
-- to scope a narrower policy to - see lib/state/products_provider.dart).
drop policy if exists "anon full access" on products;
create policy "anon full access" on products for all to anon using (true) with check (true);

-- customers: the app only ever selects (admin list) and inserts (first-time
-- signup) - see lib/state/customers_provider.dart and
-- lib/state/auth_provider.dart. It never updates or deletes a customer row,
-- so those commands aren't granted.
drop policy if exists "anon full access" on customers;
drop policy if exists "anon can read customers" on customers;
drop policy if exists "anon can insert customers" on customers;
create policy "anon can read customers" on customers for select to anon using (true);
create policy "anon can insert customers" on customers for insert to anon with check (true);

-- orders: select/insert (checkout) and update (status changes) are used -
-- see lib/state/orders_provider.dart - but orders are never deleted.
drop policy if exists "anon full access" on orders;
drop policy if exists "anon can read orders" on orders;
drop policy if exists "anon can insert orders" on orders;
drop policy if exists "anon can update orders" on orders;
create policy "anon can read orders" on orders for select to anon using (true);
create policy "anon can insert orders" on orders for insert to anon with check (true);
create policy "anon can update orders" on orders for update to anon using (true) with check (true);

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- Split by command rather than one "for all" policy: the bucket's `public`
-- flag already serves reads via the direct object URL without going
-- through these policies, so granting anon SELECT here would only let it
-- *list*/enumerate every file in the bucket, which the app never needs.
-- No delete policy either - ProductsProvider.deleteProduct only removes the
-- `products` row, never the underlying Storage object.
drop policy if exists "anon full access to product-images" on storage.objects;
drop policy if exists "anon can upload product images" on storage.objects;
drop policy if exists "anon can update product images" on storage.objects;
create policy "anon can upload product images" on storage.objects
for insert to anon
with check (bucket_id = 'product-images');
create policy "anon can update product images" on storage.objects
for update to anon
using (bucket_id = 'product-images')
with check (bucket_id = 'product-images');
