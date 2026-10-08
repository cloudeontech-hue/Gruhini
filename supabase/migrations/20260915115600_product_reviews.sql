-- Product ratings & reviews. Customers rate individual items from a
-- delivered order (see lib/screens/order_tracking_screen.dart's "Rate
-- your order" action); ratings show up as a star average + count on
-- product cards and the product details screen.
--
-- Trust model matches the rest of this app (no real per-customer auth
-- session to scope RLS to - see 20260702132100_security_hardening_bcrypt_auth.sql's "Known
-- accepted risks" section for the same reasoning applied elsewhere):
-- anon can insert a review for any order/product pair, but never update
-- or delete one, and a unique constraint stops the same order+product
-- being reviewed twice by resubmission.
--
-- Run this once in the Supabase SQL editor. Idempotent - safe to re-run.

create table if not exists reviews (
  id             uuid primary key default gen_random_uuid(),
  product_id     text not null references products(id) on delete cascade,
  order_id       text not null references orders(id) on delete cascade,
  customer_phone text not null,
  customer_name  text not null,
  rating         smallint not null check (rating between 1 and 5),
  comment        text not null default '',
  created_at     timestamptz not null default now(),
  unique (order_id, product_id)
);

alter table reviews enable row level security;

-- Public read - ratings need to be visible to every customer browsing
-- the catalog, not just the reviewer.
drop policy if exists "anon can read reviews" on reviews;
create policy "anon can read reviews" on reviews for select to anon using (true);

-- Insert-only: no anon UPDATE/DELETE policy exists, so a submitted review
-- can't be edited or removed via the REST API (matches the "no real
-- customer auth session" trust level already accepted elsewhere in this
-- app - see the note above).
drop policy if exists "anon can insert reviews" on reviews;
create policy "anon can insert reviews" on reviews for insert to anon with check (true);

create index if not exists reviews_product_id_idx on reviews (product_id);

-- Cheap per-product aggregate (average rating + count) instead of every
-- client computing it from the full reviews list - a view keeps this a
-- single indexed query rather than pulling every review row just to show
-- a star badge on the product grid.
create or replace view product_rating_summary as
select
  product_id,
  round(avg(rating)::numeric, 1) as average_rating,
  count(*) as review_count
from reviews
group by product_id;

grant select on product_rating_summary to anon;
