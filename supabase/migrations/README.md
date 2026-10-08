# Database Migrations

Every file here is a schema change that was run, in filename order, against
the `Gruhinifood` Supabase project's Postgres database via the SQL Editor.
Filenames are `<timestamp>_<description>.sql`, so sorting alphabetically
gives the exact order they were (and must be) applied in.

**All 11 are already applied to production.** This directory exists as a
readable, ordered history of the schema — not as a queue of pending work.

| # | File | What it does |
|---|---|---|
| 1 | `20260626123500_initial_schema.sql` | Core tables (`products`, `customers`, `orders`), RLS policies, `product-images` storage bucket. |
| 2 | `20260626123501_shop_owners.sql` | `shop_owners` table, `shop_owner_id` FK on products/orders, SHA-256-era `authenticate_shop_owner()`/`change_shop_owner_password()` (later replaced by #4). |
| 3 | `20260701163100_payments_and_business_settings.sql` | Payment columns on `orders`, 6-state order status lifecycle, `business_settings` table, `payment-screenshots`/`business-assets` buckets. |
| 4 | `20260702132100_security_hardening_bcrypt_auth.sql` | `admins` table + bcrypt RPCs (`authenticate_admin`, `create_admin`, `change_admin_password`); replaces shop-owner auth RPCs with bcrypt; locks down `password_hash` and `business_settings` access. |
| 5 | `20260710115900_razorpay_order_id.sql` | Adds `orders.razorpay_order_id`. |
| 6 | `20260803135500_account_deletion_policy.sql` | Adds the `DELETE` RLS policy the in-app "Delete Account" feature needs. |
| 7 | `20260821151700_customer_password_auth.sql` | Adds bcrypt password auth for customers. **Superseded** by #8, then #11 — see "Superseded migrations" below. |
| 8 | `20260910120400_customer_otp_auth.sql` | Switches customer login to Firebase Phone Auth (OTP). **Superseded** by #11. |
| 9 | `20260915113600_delivery_fee_and_pincodes.sql` | Adds delivery fee / free-delivery threshold / serviceable-pincode columns to `business_settings`. |
| 10 | `20260915115600_product_reviews.sql` | Adds the `reviews` table and `product_rating_summary` view. |
| 11 | `20260915122700_customer_google_auth.sql` | Switches customer login to Firebase Google Sign-In. **Current** customer auth method. |

## Superseded migrations (#7, #8)

Customer login has changed twice since #7: password → OTP (#8) → Google
Sign-In (#11, current). Each migration's header says so and leaves the
previous one's columns/functions in place rather than dropping them — they
are harmless once unused, and dropping live objects from a migration file
that runs later is a much easier way to lose data or break a rollback than
it is to save a little schema clutter. If you want to actually remove the
dead `customers.password_hash` column and the `login_or_create_customer`/
`reset_customer_password` functions from #7, do that as a **new**,
deliberate migration after confirming nothing still calls them — don't
edit #7 itself.

## Adding a new migration

1. Create a new file here named `<YYYYMMDDHHMMSS>_<short_description>.sql`,
   timestamped later than every existing file.
2. Write it idempotently (`create table if not exists`, `add column if not
   exists`, `drop policy if exists` + `create policy`, `create or replace
   function`) so it's safe to re-run if something fails partway through.
3. Run it in the Supabase dashboard SQL Editor against production, the same
   way every file above was applied.
4. If the app depends on the change, update the relevant `lib/` doc
   comments to cite the new filename (see how existing files are cited
   throughout `lib/state/` and `lib/models/`).

This project does not use `supabase db push` / `supabase migration up` to
apply these — they've always been run by hand through the SQL Editor, and
the local Supabase CLI's migration-history table has never been synced to
match. **Don't run `supabase db push` or `supabase migration repair`
against this project without first checking `supabase migration list`** —
since the CLI's remote history doesn't know about any of these 11 files, it
may try to re-apply them (most are idempotent so that's often harmless, but
verify first rather than assume) or report a divergent history.
