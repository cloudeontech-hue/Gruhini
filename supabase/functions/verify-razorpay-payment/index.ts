// Verifies a completed Razorpay Checkout payment server-side, since
// RAZORPAY_KEY_SECRET must never reach the Flutter client. Called by
// lib/services/razorpay_service.dart right after Razorpay's SDK reports
// EVENT_PAYMENT_SUCCESS.
//
// Deploy: supabase functions deploy verify-razorpay-payment
// Secrets required: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
// (see scripts/MIGRATION_RAZORPAY.md for the full rollout).

const RAZORPAY_ORDERS_URL = "https://api.razorpay.com/v1/orders";

// See the matching comment in create-razorpay-order/index.ts - the browser
// (web) caller sends a CORS preflight OPTIONS request before the real POST;
// without these headers on every response, the browser blocks the request
// before this function even runs, invisibly to the client (no Dart-level
// HTTP status to catch, just a client-side network failure).
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

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Manual constant-time compare — avoids a timing side-channel that `===`
// (which short-circuits on the first differing character) could leak.
function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ verified: false, error: "Method not allowed." }, 405);
  }

  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) {
    return jsonResponse(
      { verified: false, error: "Razorpay is not configured on the server." },
      500,
    );
  }

  let body: {
    razorpay_order_id?: unknown;
    razorpay_payment_id?: unknown;
    razorpay_signature?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ verified: false, error: "Invalid JSON body." }, 400);
  }

  const orderId = body.razorpay_order_id;
  const paymentId = body.razorpay_payment_id;
  const signature = body.razorpay_signature;
  if (
    typeof orderId !== "string" || !orderId ||
    typeof paymentId !== "string" || !paymentId ||
    typeof signature !== "string" || !signature
  ) {
    return jsonResponse(
      {
        verified: false,
        error:
          "razorpay_order_id, razorpay_payment_id and razorpay_signature are required.",
      },
      400,
    );
  }

  const expectedSignature = await hmacSha256Hex(
    keySecret,
    `${orderId}|${paymentId}`,
  );

  if (!constantTimeEquals(expectedSignature, signature)) {
    return jsonResponse({ verified: false, error: "Signature mismatch." }, 400);
  }

  // Signature already proves this is a genuine Razorpay-signed payment. The
  // amount re-fetch below is defense-in-depth (lets the client cross-check
  // what Razorpay actually confirms was paid against its own cart total) —
  // if it fails for any reason, still report verified: true rather than
  // failing a payment that's already cryptographically proven genuine.
  try {
    const basicAuth = btoa(`${keyId}:${keySecret}`);
    const orderRes = await fetch(`${RAZORPAY_ORDERS_URL}/${orderId}`, {
      headers: { Authorization: `Basic ${basicAuth}` },
    });
    if (orderRes.ok) {
      const orderData = await orderRes.json();
      return jsonResponse({
        verified: true,
        amount: orderData.amount,
        currency: orderData.currency,
      });
    }
  } catch {
    // Fall through to the verified-with-no-amount response below.
  }

  return jsonResponse({ verified: true, amount: null, currency: null });
});
