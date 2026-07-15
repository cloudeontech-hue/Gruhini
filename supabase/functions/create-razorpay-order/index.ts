// Creates a Razorpay Order server-side so the RAZORPAY_KEY_SECRET never has
// to leave Supabase. Called by lib/services/razorpay_service.dart before
// opening the Razorpay Checkout UI.
//
// Deploy: supabase functions deploy create-razorpay-order
// Secrets required: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
// (see scripts/MIGRATION_RAZORPAY.md for the full rollout).

const RAZORPAY_ORDERS_URL = "https://api.razorpay.com/v1/orders";

// Required for any browser (web) caller: the Flutter app on web calls this
// function via a cross-origin fetch (the page is served from the app's own
// origin, not Supabase's), so the browser sends a CORS preflight OPTIONS
// request first. Without these headers on *every* response - including the
// OPTIONS preflight itself - the browser blocks the request client-side
// before it ever reaches this function, with no server-side trace of it.
// Native mobile callers (Android/iOS) never do this preflight, which is why
// this was invisible there.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) {
    return jsonResponse(
      { error: "Razorpay is not configured on the server." },
      500,
    );
  }

  let body: { amount?: unknown; receipt?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount <= 0) {
    return jsonResponse({ error: "amount must be a positive number." }, 400);
  }
  const receipt =
    typeof body.receipt === "string" && body.receipt.length > 0
      ? body.receipt
      : `rcpt_${Date.now()}`;

  // Razorpay's Orders API takes the smallest currency unit (paise for INR),
  // not rupees.
  const amountPaise = Math.round(amount * 100);

  const basicAuth = btoa(`${keyId}:${keySecret}`);
  const razorpayRes = await fetch(RAZORPAY_ORDERS_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${basicAuth}`,
    },
    body: JSON.stringify({
      amount: amountPaise,
      currency: "INR",
      receipt,
    }),
  });

  const razorpayData = await razorpayRes.json();
  if (!razorpayRes.ok) {
    return jsonResponse(
      { error: razorpayData?.error?.description ?? "Could not create Razorpay order." },
      502,
    );
  }

  return jsonResponse({
    orderId: razorpayData.id,
    amount: razorpayData.amount,
    currency: razorpayData.currency,
  });
});
