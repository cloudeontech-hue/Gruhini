# Security Hardening Migration

Run these steps once after deploying the new Flutter app version.

## 1. Run the SQL migration

In the Supabase dashboard → **SQL Editor**, paste and run
`scripts/supabase_schema_security.sql` in full.

What it does:
- Enables `pgcrypto` for bcrypt support
- Creates the `admins` table (zero anon access)
- Creates/replaces all auth RPCs with bcrypt-based equivalents
- Re-hashes the `gruhini` shop owner password with bcrypt
- Tightens RLS on `shop_owners` (hides `password_hash` from anon REST) and `business_settings`

## 2. Seed the first admin account

In the SQL editor (service-role context), run:

```sql
select create_admin('admin', 'your-strong-password-here');
```

Choose a strong password — the hardcoded `admin123` no longer works after
this migration. Record the password somewhere safe.

## 3. Re-hash existing shop owner passwords

The `gruhini` seed account is handled automatically by step 1.

For any other shop owners created before this migration:

**Option A** — if you know their plain-text password:
```sql
update public.shop_owners
set password_hash = crypt('their-plain-password', gen_salt('bf', 12))
where username = 'their-username';
```

**Option B** — assign a temporary password via the new admin-reset RPC
(not yet wired to a Head Admin UI screen - run from the SQL editor):
```sql
select reset_shop_owner_password('their-id', 'temp-password');
```

Then ask the shop owner to change their password on first login via the
Profile screen.

## 4. Verify logins

- **Admin login** — use the new credentials set in step 2
- **Shop owner login** — use the same passwords (now verified via bcrypt)
- **Customer login** — unchanged; existing devices will auto-migrate
  their locally-stored password from plain text to SHA-256 on next login

## What changed

| Area | Before | After |
|---|---|---|
| Admin credentials | Hardcoded `admin/admin123` in Dart source | `admins` table, bcrypt via pgcrypto |
| Shop owner auth | SHA-256 client-side → DB equality check | Plain text → bcrypt in security-definer RPC |
| Shop owner creation | Direct INSERT with SHA-256 hash | `create_shop_owner()` RPC, bcrypt server-side |
| Customer passwords | Plain text in SharedPreferences | SHA-256 hash in SharedPreferences |
| `password_hash` column | Readable via anon REST API | Column-level revoke: anon cannot SELECT it |
| `business_settings` UPDATE | Any row | Restricted to `id = 'default'` row only |
