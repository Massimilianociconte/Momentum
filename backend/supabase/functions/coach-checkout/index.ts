// Edge function: registrazione acquisto pacchetto coach (PRD I3/I5).
//
//   POST /coach-checkout  { packageId, store, storeTxId }
//   → { purchaseId, commissionCents, coachNetCents }
//
// Flusso: il client compra via IAP (App Store / Play Billing, come da
// policy store per contenuti digitali). Dopo la conferma dello store il
// client chiama questa function, che:
//   1. valida il pacchetto e l'anti-replay su store_tx_id;
//   2. calcola la commissione piattaforma dal commission_rate;
//   3. registra l'acquisto e crea l'assignment (sblocco funzioni in-app).
//
// NOTA produzione: qui va aggiunta la verifica server-side della ricevuta
// (App Store Server API / Play Developer API o webhook RevenueCat) prima
// di registrare l'acquisto. Il punto d'integrazione è `verifyReceipt`.

import { createClient } from "npm:@supabase/supabase-js@2";
import { hasActiveEntitlement } from "../_shared/entitlement.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const jwt = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!jwt) return json({ error: "unauthorized" }, 401);
  const { data: userData } = await supabase.auth.getUser(jwt);
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const packageId = body?.packageId?.toString().trim();
  const store = ["APP_STORE", "PLAY_STORE"].includes(body?.store)
    ? body.store
    : null;
  const storeTxId = body?.storeTxId?.toString().trim().slice(0, 256);
  if (!packageId || !store || !storeTxId) {
    return json({ error: "bad_request" }, 400);
  }

  const { data: pkg } = await supabase
    .from("coach_packages")
    .select("package_id, coach_id, type, price_cents, status")
    .eq("package_id", packageId)
    .maybeSingle();
  if (!pkg || pkg.status !== "ACTIVE") {
    return json({ error: "package_not_found" }, 404);
  }
  let coachEntitled: boolean;
  try {
    coachEntitled = await hasActiveEntitlement(
      supabase,
      pkg.coach_id,
      ["coach"],
    );
  } catch (error) {
    console.error(
      "coach-checkout entitlement lookup",
      error instanceof Error ? error.message : "unknown",
    );
    return json({ error: "temporarily_unavailable" }, 503);
  }
  if (!coachEntitled) return json({ error: "package_not_found" }, 404);
  if (pkg.coach_id === user.id) {
    return json({ error: "cannot_buy_own_package" }, 400);
  }

  const verified = verifyReceipt(store, storeTxId);
  if (!verified) return json({ error: "receipt_invalid" }, 402);

  // Commissione piattaforma (PRD I3). Es: 49,00€ * 15% = 7,35€.
  // Il rate è derivato dal tipo, mai letto dalla riga scritta dal coach
  // (in DB un trigger forza comunque lo stesso valore).
  const commission = Math.round(pkg.price_cents * commissionRateFor(pkg.type));
  const coachNet = pkg.price_cents - commission;

  const { data: purchase, error } = await supabase
    .from("coach_purchases")
    .insert({
      package_id: pkg.package_id,
      coach_id: pkg.coach_id,
      player_id: user.id,
      price_cents: pkg.price_cents,
      commission_cents: commission,
      coach_net_cents: coachNet,
      store,
      store_tx_id: storeTxId,
    })
    .select("purchase_id")
    .single();

  if (error) {
    // unique(store, store_tx_id) → replay della stessa ricevuta.
    return json({ error: "duplicate_or_failed" }, 409);
  }

  // Sblocca subito le funzioni in-app: scheda assegnata, tracking, report.
  await supabase.from("coach_assignments").insert({
    purchase_id: purchase.purchase_id,
    coach_id: pkg.coach_id,
    player_id: user.id,
  });

  return json({
    purchaseId: purchase.purchase_id,
    commissionCents: commission,
    coachNetCents: coachNet,
  });
});

// PRD I3: 15% digitale, 10% live. Tenere allineata a
// private.coach_commission_rate (migrazione 20260715150000) e a
// CoachService.commissionFor nell'app.
function commissionRateFor(type: string): number {
  return type === "LIVE_1TO1" || type === "GROUP_LESSON" ? 0.10 : 0.15;
}

function verifyReceipt(
  _store: string,
  _storeTxId: string,
): boolean {
  // Intentionally fail closed until App Store Server API, Google Play
  // Developer API, or a verified RevenueCat webhook is wired end-to-end.
  return false;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
