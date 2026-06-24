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

drop policy if exists "anon full access" on products;
drop policy if exists "anon full access" on customers;
drop policy if exists "anon full access" on orders;
create policy "anon full access" on products for all to anon using (true) with check (true);
create policy "anon full access" on customers for all to anon using (true) with check (true);
create policy "anon full access" on orders for all to anon using (true) with check (true);

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

drop policy if exists "anon full access to product-images" on storage.objects;
create policy "anon full access to product-images" on storage.objects for all to anon
using (bucket_id = 'product-images') with check (bucket_id = 'product-images');
