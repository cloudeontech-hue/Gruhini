# Gruhini Foods

A Flutter app for a homemade snacks/sweets/pickles business, with three
roles — customer, shop owner, and head admin — backed by Supabase.

## Stack

- Flutter (Dart), Material 3, Provider for state management
- Supabase (Postgres + Storage) via `supabase_flutter`
- `shared_preferences` for local auth persistence (no real Supabase Auth
  session — see [Default credentials](#default-credentials-development-only))
- `flutter_dotenv` for environment variables
- `crypto` (SHA-256) for client-side password hashing
- `image_picker` / `file_picker` for image uploads (mobile vs web/desktop)
- `flutter_svg` for the logo, `google_fonts` for the type system

## Project Setup

1. Install Flutter (see [flutter.dev/get-started](https://docs.flutter.dev/get-started/install)) and run:
   ```
   flutter pub get
   ```
2. Copy `.env.example` to `.env` and fill in your Supabase project's URL and
   anon key (see [Configuring Supabase](#configuring-supabase) below):
   ```
   cp .env.example .env
   ```
3. Run the SQL migrations against your Supabase project (see next section).
4. `flutter run -d chrome` (or your platform of choice — see
   [Running the App](#running-the-app)).

## Running the SQL Migrations

In the Supabase dashboard: **Project → SQL Editor → New query**. Run these
three files **in order** — each is idempotent (`if not exists` / `on
conflict do nothing` / `drop policy if exists`), so re-running is safe:

1. `scripts/supabase_schema.sql` — core tables (`products`, `customers`,
   `orders`), row-level security policies, and the `product-images` storage
   bucket.
2. `scripts/supabase_schema_shop_owners.sql` — `shop_owners` table, adds a
   `shop_owner_id` foreign key to `products` and `orders`, and the
   `authenticate_shop_owner()` / `change_shop_owner_password()` RPC
   functions used for shop-owner login.
3. `scripts/supabase_schema_payments.sql` — adds the UPI/payment columns to
   `orders` (delivery address, payment status, screenshot URL, transaction
   ID, verification fields), the 6-state order status lifecycle, the
   single-row `business_settings` table, and the `payment-screenshots` /
   `business-assets` storage buckets.

All RLS policies grant the `anon` role narrowly-scoped access (only the
specific commands the app actually issues — see the comments in each SQL
file) since the app has no real Supabase Auth session; identity is
SharedPreferences-based for customers/shop owners and a hardcoded password
for the head admin.

### Seeding sample data (optional)

`scripts/seed_supabase.dart` uploads the bundled product photos and inserts
the demo products/customers/orders, plus a default shop owner
(`gruhini` / `shop123`). Run once after the migrations:

```
dart run scripts/seed_supabase.dart
```

## Configuring Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. **Project Settings → API** — copy the **Project URL** and **anon public**
   key into your `.env` as `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Run the three migrations above. This also creates the storage buckets
   the app needs (`product-images`, `payment-screenshots`,
   `business-assets`) — no manual bucket setup required.

## Adding the Business UPI QR

The QR shown to customers at checkout is **not** bundled in the app — it's
stored in Supabase and configured at runtime:

1. Log in as head admin (see [Default credentials](#default-credentials-development-only)).
2. Go to **Settings**.
3. Upload the UPI QR image and set the real UPI ID and support phone
   number. These are stored in the `business_settings` table (see
   `scripts/supabase_schema_payments.sql`), which the migration seeds with
   a placeholder UPI ID — **must be replaced** before accepting real orders.

## Running the App

```
flutter run -d chrome        # web
flutter run                  # connected device/emulator
flutter build web            # production web build, output in build/web
```

## Default Credentials (development only)

These are placeholder credentials baked into the codebase for local
development. **Do not ship to production without changing them.**

| Role | Username | Password | Where it's defined |
|---|---|---|---|
| Head Admin | `admin` | `admin123` | `lib/state/auth_provider.dart` (hardcoded constant) |
| Shop Owner (sample) | `gruhini` | `shop123` | Created by `scripts/seed_supabase.dart`, stored hashed in the `shop_owners` table |

The head admin password is a hardcoded constant in the app binary, not a
database row — changing it means editing
`lib/state/auth_provider.dart:headAdminPassword` and rebuilding. The shop
owner credential is a normal database row and can be changed via the Shop
Owner Profile screen once logged in.
