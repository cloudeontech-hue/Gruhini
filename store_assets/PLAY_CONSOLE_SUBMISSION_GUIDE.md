# Play Console Submission Guide — Gruhini Foods

Complete, self-contained reference for taking Gruhini Foods from zero to a
published Play Store listing. Every value below is copy-paste ready and
pulled directly from the actual app code/schema/build — not guessed.
Written so it can be followed end-to-end without any other context.

**Current state as of writing:** app created in Play Console, Internal
testing track working with a verified real payment, Store listing filled
in, most of "App content" filled in. What's explicitly still open is
called out in section 9.

---

## 1. What this app is

Gruhini Foods — a Flutter app (Android/iOS/Web/Windows) connecting
customers with home kitchens selling snacks, sweets, and pickles. Three
roles: Customer, Shop Owner, Admin. Backend is Supabase (Postgres). Real
payments via Razorpay (UPI/card/net banking) — no cash on delivery.

- **Package name (permanent, already set):** `com.gruhinifoods.gruhini_foods`
- **Current version:** `1.0.0+3` (versionName `1.0.0`, versionCode `3`)
- **Signed release bundle:** `build/app/outputs/bundle/release/app-release.aab`
  — signed with the real upload keystore, verified via `apksigner`.
- **Live compliance site:** `https://cloudeontech-hue.github.io/gruhini-foods-site/`
  (hosted on the `gh-pages` branch of this same repo — Terms, Privacy,
  Shipping, Refunds, Account Deletion, Contact pages)

## 2. Building a new release (only if code has changed)

If you need a fresh build (e.g. after a code fix):

```bash
cd "Gruhini Foods"
# bump the build number in pubspec.yaml, e.g. 1.0.0+3 -> 1.0.0+4
flutter build appbundle --release
```

Play Console rejects re-uploading a version code that's ever been used
before (even from a discarded draft release) — always bump the `+N` build
number before rebuilding if a previous upload attempt failed partway.

Verify before uploading:
```bash
unzip -p build/app/outputs/bundle/release/app-release.aab base/assets/flutter_assets/.env | grep RAZORPAY_KEY_ID
# should print: RAZORPAY_KEY_ID=rzp_live_TK25Sf1ZqZ9jjo
```

## 3. Account creation

Play Console → **Create app**:
- App name: `Gruhini Foods`
- Package name: `com.gruhinifoods.gruhini_foods` (permanent, cannot change later)
- Default language: English (India) – en-IN (or leave en-US, not critical)
- App or game: **App**
- Free or paid: **Free**
- Accept both declarations (Developer Program Policies, US export laws)

## 4. Internal testing (do this before Production)

Testing → Internal testing → **Testers** tab → create an email list, add
your own Gmail. Then **Releases** tab → Create new release → upload the
`.aab` → release notes wrapped in language tags:
```
<en-US>
Initial release of Gruhini Foods.
</en-US>
```
Publish. Open the generated opt-in URL on your phone (signed into the
same Gmail), install, and do one real payment end-to-end (see section 8
below for the Razorpay gotcha already hit and fixed once).

## 5. Razorpay configuration (already done, reference only)

- Live Key ID (client-side, baked into `.env`, bundled in the app):
  `rzp_live_TK25Sf1ZqZ9jjo`
- Live Key Secret: stored **only** server-side as a Supabase Edge Function
  secret (`RAZORPAY_KEY_SECRET`), never in the repo or client. Set via:
  ```
  supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=...
  ```
- **Gotcha already hit once:** if the Razorpay dashboard key is ever
  regenerated, both `.env`'s `RAZORPAY_KEY_ID` and the Supabase secrets
  must be updated to match, and the app rebuilt — a stale key causes every
  real payment to fail with "Authentication failed," which looks like an
  account problem but isn't.
- **Play Store commission:** none applies. This app sells physical goods
  (food), which Google Play's Payments Policy exempts from requiring Play
  Billing — same category as Zomato/Swiggy/Amazon/Uber. The only Google
  fee is the one-time $25 Play Console registration.

## 6. Store listing (Store presence → Main store listing)

**App name**
```
Gruhini Foods
```

**Short description**
```
Homemade snacks, sweets & pickles from local kitchens, delivered to you.
```

**Full description**
```
Gruhini Foods brings homemade snacks, sweets, and pickles from local home
kitchens straight to your door - made fresh, the traditional way, by the
cooks in your own neighborhood.

WHY GRUHINI FOODS
- Fresh, homemade snacks, sweets & pickles - not mass-produced
- Support local home kitchens and small food businesses
- Simple, secure checkout with UPI, cards, and net banking
- Track your order from kitchen to doorstep
- Reorder your favorites in one tap

HOW IT WORKS
1. Browse snacks, sweets, and pickles from local home kitchens
2. Add your favorites to cart and check out securely
3. Track your order in real time
4. Get freshly made food delivered to your door

SECURE, PREPAID ORDERS
All orders are paid online via UPI, card, or net banking through Razorpay,
a trusted, secure payment gateway - no cash on delivery, no hassle.

FOR HOME COOKS & SMALL FOOD BUSINESSES
Gruhini Foods also gives local home kitchens a simple way to list their
products, manage orders, and reach customers nearby - all from the same app.

Download Gruhini Foods and taste the difference of homemade.
```

**Assets:**
- App icon (512×512): `store_assets/play_store_icon_512.png`
- Feature graphic (1024×500): `store_assets/play_store_feature_graphic.png`
- Phone screenshots (4, 412×915): `store_assets/screenshots/00_welcome.png`,
  `01_home.png`, `02_product_details.png`, `03_cart.png`
- 7-inch tablet screenshots (2, 800×1280): `store_assets/screenshots_tablet/7in_01_welcome.png`, `7in_02_home.png`
- 10-inch tablet screenshots (2, 1200×1920): `store_assets/screenshots_tablet/10in_01_home.png`, `10in_02_product_details.png`
- Video: none/optional, skip
- **AI asset declaration:** "Don't label assets" — none of these are
  generative-AI content; screenshots are real captures of the running
  app, icon/feature graphic are composited from the real logo via code.

**Category:** Food & Drink
**Contact email:** `cloudeontech@gmail.com`
**Contact phone:** `+91 8125125100`
**Website:** `https://cloudeontech-hue.github.io/gruhini-foods-site/`
**Privacy Policy URL:** `https://cloudeontech-hue.github.io/gruhini-foods-site/privacy.html`

## 7. App content declarations

### Privacy policy
```
https://cloudeontech-hue.github.io/gruhini-foods-site/privacy.html
```

### Sign in details (formerly "App access")
Answer **Yes** (app has restricted sign-in + payments). Add three entries:

**Entry 1 — Customer account**
- Username: `+91 9999912345`
- Password: `Test@1234`
- Other info: "No verification (OTP/email) is required. On first login,
  entering any name, phone number, and password instantly creates a new
  customer account — the credentials above will work, or a reviewer can
  create their own with any values."
- "Full access to all features" checkbox: **unchecked** (doesn't reach
  Shop Owner/Admin panels)

**Entry 2 — Shop Owner account**
- Username: `gruhini`
- Password: `shop123`
(real seeded account from the DB migration; no "other info" needed)
- "Full access" checkbox: **unchecked**

**Entry 3 — Admin account**
- Username: `playreview`
- Password: (created via `select create_admin('playreview', '<password>');`
  in the Supabase SQL editor — if this hasn't been run yet, run it first;
  the password isn't repeated here since it was generated live and only
  shown once in chat, not persisted to this file for security)
- Other info: "Tap 'I am Admin' from the role selection screen and sign in
  with the credentials above."
- "Full access" checkbox: **unchecked**

### Ads
```
No
```

### Content rating
- Category: **All Other App Types**
- Email: `cloudeontech@gmail.com`
- Questionnaire answers — all **No** except:
  - "Does the app feature or promote content not part of the initial
    download?" → **Yes** (product listings, like the Amazon Shopping
    example Google gives) → triggers Violence/Sexuality/Language/
    Controlled Substance follow-ups → all **No**
- Expected result: Everyone / All ages / 3+ across every region

### Target audience and content
- Target age group: **18 and over only**
- "Restrict users determined to be minors": **leave both boxes unchecked**

### Data safety
Answer **Yes** (collects/shares required data types). Skip both
"Additional badges" (Independent security review, UPI Payments verified —
neither applies/needed).

- Encrypted in transit: **Yes**
- Account creation methods: **Username and password** only (phone number
  counts as "username" per Google's own definition)
- Delete account URL: `https://cloudeontech-hue.github.io/gruhini-foods-site/account-deletion.html`
- "Way to delete partial data without deleting account?": **No**

**Data types — select exactly:**
- Location → **Precise location** only (not Approximate separately)
- Personal info → **Name, Phone number, Address**
- Financial info → **Purchase history, User payment info**
- Everything else (Health, Messages, Photos/videos, Audio, Files, Calendar,
  Contacts, App activity, Web browsing, App info/performance, Device IDs):
  **none selected**

**Per-item usage answers (this is the part most likely to be gotten wrong
— verified correct via the Preview step after two rounds of corrections):**

| Data type | Collected | Shared | Ephemeral | Required/Optional | Collection purpose | Sharing purpose |
|---|---|---|---|---|---|---|
| Name | ✅ | ✅ (Razorpay) | No | Required | App functionality, Account management | App functionality |
| Phone number | ✅ | ✅ (Razorpay) | No | Required | App functionality, Account management | App functionality |
| Address | ✅ | ❌ | No | Required | App functionality | — |
| Purchase history | ✅ | ❌ | No | Required | App functionality | — |
| User payment info | ✅ | ✅ (Razorpay) | No | Required | App functionality | App functionality |
| Precise location | ✅ | ✅ (Google Geocoding API) | **Yes** | **Optional** (user can type address manually) | App functionality | App functionality |

Why Name/Phone are shared but Address isn't: Razorpay Checkout is
initialized with `customerName` and `customerPhone` as prefill fields
(see `lib/screens/checkout/payment_method_screen.dart` →
`_payWithRazorpay()`), but never the address. Why Precise location is
ephemeral: raw GPS coordinates are sent to Google's Geocoding API only to
resolve an address string; the coordinates themselves aren't stored, only
the resulting text address is.

**Note:** the address autofill backend was switched from OpenStreetMap's
Nominatim to Google's Geocoding API after this guide was first written —
if you already saved the Data safety form with "Nominatim/OpenStreetMap"
as the sharing recipient, go back and update that field to say Google.
The live Privacy Policy was updated to match (see `gh-pages` branch,
`privacy.html` section 4 "Location Data").

Use the **Preview** step (step 5 of the Data safety flow) to sanity-check
before saving — it lists exactly what will be shown publicly, and it's
easy to mischeck a box on the first pass.

### Government apps
```
No
```

### Financial features
```
My app doesn't provide any financial features
```
(This app accepts payment for physical goods via a processor — it isn't
itself a financial product like a wallet, lender, or exchange.)

### Health apps
```
My app does not have any health features
```

## 8. Store settings

- Category: **Food & Drink**
- Contact details: same email/phone/website as section 6

## 9. What's still open (verify before final submit)

- [ ] Confirm the Admin account (`create_admin` SQL) was actually run —
      if not, run it and fill in the Sign in details entry 3 with the
      real password generated
- [ ] Countries/regions for the Production track — not yet selected;
      pick target markets (India, at minimum)
- [ ] One real end-to-end payment test on Internal testing — confirm this
      was actually completed and the order appeared correctly, not just
      that the Razorpay checkout screen opened
- [ ] Pricing & distribution: confirm "No ads," "No in-app products"
- [ ] Once every App content item shows complete on the Dashboard,
      Production (or Closed/Open testing) will unblock — create a release
      there with the same `.aab`, review the "Preview and confirm" screen
      for zero errors, then **Send for review**

## 10. After submitting

Google's first-time review is typically same-day to a few days. If
rejected, the rejection reason will reference a specific policy — re-read
the relevant section above (most rejections for apps like this trace back
to Data safety mismatches or an unreachable Privacy Policy URL) before
making changes.
