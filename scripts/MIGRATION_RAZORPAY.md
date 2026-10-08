# Razorpay Checkout Migration

Run these steps once after deploying the new Flutter app version. Requires
the [Supabase CLI](https://supabase.com/docs/guides/cli) and a
[Razorpay](https://razorpay.com) account (test mode is fine to start).

## 1. Run the SQL migration

In the Supabase dashboard → **SQL Editor**, paste and run
`supabase/migrations/20260710115900_razorpay_order_id.sql`. It adds one column
(`orders.razorpay_order_id`) — additive only, safe to re-run.

## 2. Link the Supabase CLI to your project

```
supabase login
supabase link --project-ref your-project-ref
```

`your-project-ref` is the id in your project's Supabase dashboard URL
(`https://supabase.com/dashboard/project/<project-ref>`).

## 3. Set the Edge Function secrets

Both Edge Functions call Razorpay's REST API directly with Basic Auth, so
**both** the key id and key secret are needed server-side — even though the
key id is also safe to put in the app's `.env` (step 5):

```
supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
supabase secrets set RAZORPAY_KEY_SECRET=your-key-secret
```

Get these from the Razorpay Dashboard → **Settings → API Keys**. Never
commit `RAZORPAY_KEY_SECRET` anywhere, including this repo's `.env` — it
must only exist as a Supabase secret.

## 4. Deploy the Edge Functions

```
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
```

## 5. Add the key ID to the app's `.env`

```
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
```

(Same value as step 3's `RAZORPAY_KEY_ID` secret — this one is safe
client-side since it only identifies your account, it can't authorize a
charge on its own.)

## 6. Update dependencies and rebuild

```
flutter pub get
```

(`pubspec.yaml` already switched from `easy_upi_payment` to
`razorpay_flutter`, and added `razorpay_web` for the Web/Windows paths below
— this just re-resolves the lockfile.)

### Android

No manual Gradle changes needed — `razorpay_flutter` merges its own Android
manifest/Gradle config. If you ever enable `minifyEnabled true` for a release
build, add a proguard keep rule so the SDK's reflection-based bits survive:

```
-keep class com.razorpay.** {*;}
-keepattributes JavascriptInterface
-dontwarn com.razorpay.**
```

### iOS

Run `pod install` (from `ios/`) after `flutter pub get` if building for iOS.

### Web

Also uses [`razorpay_web`](https://pub.dev/packages/razorpay_web) (same
community package as Windows below), but its **web** implementation is
unrelated to the Windows WebView path — it dynamically injects Razorpay's
own `checkout.js` `<script>` tag into the page and opens the standard
browser popup, exactly as Razorpay's own web docs describe. No
`web/index.html` changes are needed; the package registers itself as a
normal Flutter web plugin (declared in its own `pubspec.yaml`), the same
mechanism any other web-capable package uses.

No extra setup beyond what's already required: `RAZORPAY_KEY_ID` in `.env`
(step 5) and the two Edge Functions deployed (steps 3–4) — both already
shared with the mobile/Windows paths, nothing web-specific to configure.

If Razorpay can't initialize on web (key missing, or `checkout.js` fails to
load — e.g. blocked by an ad-blocker or offline), the app automatically
falls back to the QR-code flow instead of leaving the customer stuck; see
"Fallback behavior" in the PR/report this migration doc accompanies.
`flutter_inappwebview`'s startup console messages (a transitive dependency,
used only by the Windows path) are harmless noise on web — unrelated to
this checkout.js integration.

### Windows

**Read this before relying on it.** The Windows checkout path uses
[`razorpay_web`](https://pub.dev/packages/razorpay_web), a **community
package that is not affiliated with, endorsed by, or officially supported by
Razorpay** — it embeds `checkout.js` in a WebView2-backed dialog via
`flutter_inappwebview`, since `razorpay_flutter` (the official SDK) has no
Windows support at all. This is meaningfully less proven than the
mobile/Android+iOS path. It was implemented and Dart-analyzed/tested from a
Linux machine with no Windows toolchain available, so **none of it has been
built, run, or exercised on an actual Windows machine** — treat the test
checklist below as required, not optional, before trusting this in
production.

Build requirements on the Windows machine itself:
- Visual Studio 2019 or later, with the "Desktop development with C++"
  workload, and the Windows 11 SDK (10.0.22000.194+)
- The [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)
  (pre-installed on most Windows 10 1809+/11 machines; if missing, the
  checkout dialog will fail to render — no special handling for that case is
  implemented here)

The `windows/` platform folder is already committed to this repo (generated
via `flutter create --platforms=windows .`), so no scaffolding step is
needed — just `flutter build windows` or `flutter run -d windows` from a
Windows machine with the above installed.

## 7. Test-mode end-to-end checklist

On an Android or iOS device/emulator:

1. Add an item to cart → checkout → **Payment Method** screen now shows a
   single **Pay Now** button (no QR/screenshot step).
2. Complete a payment using a
   [Razorpay test card/UPI](https://razorpay.com/docs/payments/payments/test-card-upi-details/)
   (e.g. card `4111 1111 1111 1111`, any future expiry, any CVV).
3. Confirm you land on **Order Placed** with a green "Verified" payment
   status chip (not the orange "Payment Verification" one).
4. In the shop owner or head admin app, open the new order — it should show
   **Accept Order** directly (no Verify/Reject Payment buttons), since
   payment was already cryptographically verified.
5. In the Supabase `orders` table, confirm the new row has
   `payment_method = 'razorpay'`, `payment_status = 'verified'`,
   `payment_verified = true`, `verified_by = 'razorpay'`, and
   `razorpay_order_id` populated.
6. On a **web** build (`flutter run -d chrome`), repeat steps 1–5 — the
   Payment Method screen should show the same single **Pay Now** button,
   opening Razorpay's own popup directly in the browser tab rather than a
   native or dialog-hosted one. Also specifically test the fallback: with
   `RAZORPAY_KEY_ID` temporarily removed from `.env` (or an ad-blocker
   enabled), confirm tapping **Pay Now** shows the "Online payment is
   unavailable..." message and lands you on the QR flow automatically,
   rather than hanging or erroring with no way forward.
7. On **Windows** (`flutter run -d windows`), repeat steps 1–5 — the Payment
   Method screen should show the same single **Pay Now** button, opening a
   dialog-hosted checkout instead of a native full-screen one. Pay close
   attention here specifically: confirm the dialog actually renders (a blank
   or perpetually-loading dialog usually means the WebView2 Runtime isn't
   installed), that closing the dialog without paying is treated as a
   cancellation (not an error, not a false success), and that a completed
   payment reaches Supabase the same way step 5 checks for mobile.

## What changed

| Area | Before | After |
|---|---|---|
| Mobile (Android/iOS) checkout | QR code or `easy_upi_payment` app-chooser, then customer-entered transaction ID + optional screenshot | Razorpay Checkout (cards/UPI/wallets/netbanking), signature-verified server-side, via the official `razorpay_flutter` SDK |
| Web checkout | QR code + manual verification | Same signature-verified flow, via `checkout.js` opened directly in the browser (community `razorpay_web` package) — auto-falls back to QR only if Razorpay can't initialize |
| Windows checkout | QR code + manual verification | Same signature-verified flow as web, via the same community `razorpay_web` package embedding `checkout.js` in a WebView2 dialog (unofficial — see the Windows section above) |
| Payment verification (mobile/web/Windows) | Manual — shop owner/admin clicks "Verify Payment" after eyeballing the screenshot | Automatic — `verify-razorpay-payment` Edge Function checks Razorpay's HMAC signature before the order is even saved |
| Linux/macOS checkout | QR code + manual verification | Unchanged — out of scope, no Razorpay integration wired up for these |
| `orders` table | — | New `razorpay_order_id` column |
| Secrets | None | `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET` as Supabase Edge Function secrets |

## Rollback

All schema changes here are additive (`add column if not exists`), so
reverting to a previous app version needs no database rollback — the old
version simply won't populate `razorpay_order_id`.
