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

In the Supabase dashboard: **Project → SQL Editor → New query**. Run every
file in [`supabase/migrations/`](supabase/migrations/) **in filename
order** (each is timestamp-prefixed, so sorting alphabetically gives the
correct order) — each is idempotent (`if not exists` / `on conflict do
nothing` / `drop policy if exists`), so re-running is safe. See
[`supabase/migrations/README.md`](supabase/migrations/README.md) for what
each one does and the full list.

All RLS policies grant the `anon` role narrowly-scoped access (only the
specific commands the app actually issues — see the comments in each SQL
file) since the app has no real Supabase Auth session; identity is
SharedPreferences-based for shop owners, Firebase-backed for customers, and
database-backed (bcrypt via the `admins` table) for the head admin.

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
3. Run the migrations above. This also creates the storage buckets the app
   needs (`product-images`, `payment-screenshots`, `business-assets`) — no
   manual bucket setup required.

## Adding the Business UPI QR

The QR shown to customers at checkout is **not** bundled in the app — it's
stored in Supabase and configured at runtime:

1. Log in as head admin (see [Default credentials](#default-credentials-development-only)).
2. Go to **Settings**.
3. Upload the UPI QR image and set the real UPI ID and support phone
   number. These are stored in the `business_settings` table (see
   `supabase/migrations/20260701163100_payments_and_business_settings.sql`), which the migration seeds with
   a placeholder UPI ID — **must be replaced** before accepting real orders.

## Running the App

```
flutter run -d chrome        # web
flutter run                  # connected device/emulator
flutter build web            # production web build, output in build/web
```

## Default Credentials (development only)

There is no hardcoded head-admin fallback in the app — `authenticate_admin()`
(added by `20260702132100_security_hardening_bcrypt_auth.sql`) is the only
way to log in as head admin, so at least one row must exist in the `admins`
table before anyone can. Seed the first admin account from the SQL editor
after running the migrations:

```sql
select create_admin('your-admin-username', 'your-strong-password');
```

| Role | Username | Password | Where it's defined |
|---|---|---|---|
| Shop Owner (sample) | `gruhini` | `shop123` | Created by `scripts/seed_supabase.dart`, stored hashed in the `shop_owners` table |

**Do not ship the sample shop owner credential to production** — delete it
or change its password via the Shop Owner Profile screen once logged in.
