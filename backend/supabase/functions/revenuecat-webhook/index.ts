// Edge function: webhook RevenueCat → aggiornamento piano su profiles.
//
// Setup (dashboard RevenueCat → Integrations → Webhooks):
//   URL:    https://<project>.functions.supabase.co/revenuecat-webhook
//   Header: Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
//
//   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<valore>
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
//
// Richiede che l'app imposti l'appUserID RevenueCat = user id Supabase:
//   await Purchases.logIn(supabaseUserId)
// (senza login cloud il piano resta comunque attivo in locale via store).

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  parseRevenueCatEnvelope,
  resolveRevenueCatPlanUpdate,
  revenueCatEventIdentity,
  revenueCatTransferCandidates,
  revenueCatUserCandidates,
  verifyRevenueCatAuthorization,
  verifyRevenueCatSignature,
} from "../_shared/revenuecat_webhook.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const HMAC_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_HMAC_SECRET") ?? "";
const MAX_BODY_BYTES = 128 * 1024;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  if (
    !verifyRevenueCatAuthorization(req.headers.get("authorization"), SECRET)
  ) {
    return new Response(null, { status: 401 });
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return json({ error: "payload_too_large" }, 413);
  }
  if (
    HMAC_SECRET &&
    !await verifyRevenueCatSignature({
      rawBody,
      signatureHeader: req.headers.get("x-revenuecat-webhook-signature"),
      secret: HMAC_SECRET,
    })
  ) {
    return json({ error: "invalid_signature" }, 401);
  }
  const envelope = parseRevenueCatEnvelope(rawBody);
  if (!envelope) return json({ error: "invalid_payload" }, 400);
  const event = envelope.event;
  const identity = revenueCatEventIdentity(event);
  if (!identity) return json({ error: "invalid_event_identity" }, 400);

  if (identity.type === "TRANSFER") {
    return processTransfer(event, identity);
  }

  const update = resolveRevenueCatPlanUpdate(event);
  if (update.action === "skip") {
    return json({ skipped: true, reason: update.reason });
  }

  const candidates = revenueCatUserCandidates(event);
  if (candidates.length === 0) {
    // Anonymous RevenueCat purchases remain valid on-device. A later logIn()
    // aliases them to the Supabase UUID and generates another lifecycle event.
    return json({ skipped: true, reason: "anonymous_or_unlinked_customer" });
  }
  const userId = await resolveKnownUser(candidates);
  if (!userId) {
    // Trigger RevenueCat retries rather than silently losing a legitimate plan
    // update during an Auth/profile creation race.
    return json({ error: "profile_not_ready" }, 503);
  }

  const { data: result, error } = await supabase.rpc(
    "apply_revenuecat_plan_event",
    {
      p_event_id: identity.id,
      p_event_type: identity.type,
      p_event_timestamp_ms: identity.timestampMs,
      p_user_id: userId,
      p_plan: update.plan,
      p_expires_at: update.expiresAtMs
        ? new Date(update.expiresAtMs).toISOString()
        : null,
    },
  );
  // Fail with a non-2xx so RevenueCat retries the delivery. A 200 here tells
  // RevenueCat the event is processed and it will never resend, so a silent
  // DB error would permanently drop the user's plan change.
  if (error) {
    console.error("revenuecat plan event failed", userId, error.message);
    return json({ error: "plan_event_failed" }, 500);
  }

  return json({ ok: true, plan: update.plan, result });
});

async function processTransfer(
  event: Record<string, unknown>,
  identity: { id: string; type: string; timestampMs: number },
): Promise<Response> {
  const candidates = revenueCatTransferCandidates(event);
  if (candidates.to.length === 0) {
    return json({ error: "invalid_transfer" }, 400);
  }
  if (candidates.from.length === 0) {
    // Official TRANSFER events may contain only a $RCAnonymousID source and no
    // entitlement/expiry fields. Never acknowledge that as processed: a
    // RevenueCat customer-state API integration is required to reconstruct it.
    return json({ error: "transfer_customer_state_required" }, 503);
  }
  const targetUserId = await resolveKnownUser(candidates.to);
  if (!targetUserId) return json({ error: "transfer_target_not_ready" }, 503);
  const sourceUserIds = await resolveExistingProfiles(candidates.from);
  if (sourceUserIds.length === 0) {
    return json({ error: "transfer_source_not_ready" }, 503);
  }

  const { data: result, error } = await supabase.rpc(
    "apply_revenuecat_transfer_event",
    {
      p_event_id: identity.id,
      p_event_timestamp_ms: identity.timestampMs,
      p_from_user_ids: sourceUserIds,
      p_target_user_id: targetUserId,
    },
  );
  if (error) {
    console.error("revenuecat transfer failed", targetUserId, error.message);
    return json({ error: "transfer_failed" }, 500);
  }
  return json({ ok: true, transfer: true, result });
}

async function resolveKnownUser(candidates: string[]): Promise<string | null> {
  const { data: rows, error } = await supabase
    .from("profiles")
    .select("user_id")
    .in("user_id", candidates);
  if (error) throw error;
  const existing = new Set(
    ((rows ?? []) as { user_id: string }[]).map((row) => row.user_id),
  );
  for (const candidate of candidates) {
    if (existing.has(candidate)) return candidate;
  }

  for (const candidate of candidates) {
    const { data, error: authError } = await supabase.auth.admin.getUserById(
      candidate,
    );
    if (authError || !data.user) continue;
    const name = data.user.email?.split("@")[0]?.slice(0, 80) ?? "";
    const { error: profileError } = await supabase.from("profiles").upsert(
      { user_id: candidate, name },
      { onConflict: "user_id", ignoreDuplicates: true },
    );
    if (profileError) throw profileError;
    return candidate;
  }
  return null;
}

async function resolveExistingProfiles(
  candidates: string[],
): Promise<string[]> {
  const { data: rows, error } = await supabase
    .from("profiles")
    .select("user_id")
    .in("user_id", candidates);
  if (error) throw error;
  const existing = new Set(
    ((rows ?? []) as { user_id: string }[]).map((row) => row.user_id),
  );
  return candidates.filter((candidate) => existing.has(candidate));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
