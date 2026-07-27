// WHOOP v2 webhook receiver. The gateway JWT check is disabled because WHOOP
// signs the raw payload itself. Every request is authenticated with HMAC,
// freshness checked and deduplicated by trace_id before background processing.

import { createClient } from "npm:@supabase/supabase-js@2";
import { requiredEnv, sha256 } from "../_shared/provider_security.ts";
import { syncWhoopResource } from "../_shared/direct_health_sync.ts";
import {
  isFreshUnixTimestamp,
  verifyHmacSha256Base64,
} from "../_shared/webhook_security.ts";
import { processPendingWebhook } from "../_shared/webhook_retry.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const MAX_BODY_BYTES = 16 * 1024;
const allowedTypes = new Set([
  "workout.updated",
  "workout.deleted",
  "sleep.updated",
  "sleep.deleted",
  "recovery.updated",
  "recovery.deleted",
]);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_BODY_BYTES) {
    return json({ error: "payload_too_large" }, 413);
  }
  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return json({ error: "payload_too_large" }, 413);
  }
  const signature = req.headers.get("x-whoop-signature")?.trim() ?? "";
  const timestamp = req.headers.get("x-whoop-signature-timestamp")?.trim() ??
    "";
  if (
    !isFreshUnixTimestamp(timestamp) ||
    !await verifyHmacSha256Base64(
      requiredEnv("WHOOP_WEBHOOK_SECRET"),
      timestamp + rawBody,
      signature,
    )
  ) {
    return json({ error: "invalid_signature" }, 401);
  }

  const body = parseBody(rawBody);
  if (!body) return json({ error: "invalid_payload" }, 400);
  const rollout = await admin.from("health_provider_features")
    .select("rollout").eq("provider", "WHOOP_DIRECT").maybeSingle();
  if (rollout.error) return json({ error: "temporarily_unavailable" }, 503);
  if (rollout.data?.rollout === "DISABLED") {
    return json({ accepted: true }, 202);
  }
  const subjectHash = await sha256(body.userId);
  const { data: connection, error: connectionError } = await admin
    .from("wearable_provider_connections")
    .select("user_id,status")
    .eq("provider", "WHOOP_DIRECT")
    .eq("provider_subject_hash", subjectHash)
    .maybeSingle();
  if (connectionError) return json({ error: "temporarily_unavailable" }, 503);
  // A valid but unrecognized/revoked WHOOP account is acknowledged to avoid
  // leaking whether a provider account is linked to Momentum.
  if (!connection || connection.status !== "CONNECTED") {
    return json({ accepted: true }, 202);
  }

  const { data: inserted, error: insertError } = await admin
    .from("health_provider_webhook_events")
    .upsert({
      provider: "WHOOP_DIRECT",
      trace_id: body.traceId,
      provider_subject_hash: subjectHash,
      event_type: body.eventType,
      external_resource_id: body.resourceId,
    }, { onConflict: "provider,trace_id", ignoreDuplicates: true })
    .select("processed_at")
    .maybeSingle();
  if (insertError) return json({ error: "temporarily_unavailable" }, 503);

  let delivery = inserted;
  if (!delivery) {
    const { data: existing, error: existingError } = await admin
      .from("health_provider_webhook_events")
      .select("processed_at")
      .eq("provider", "WHOOP_DIRECT")
      .eq("trace_id", body.traceId)
      .maybeSingle();
    if (existingError || !existing) {
      return json({ error: "temporarily_unavailable" }, 503);
    }
    delivery = existing;
  }

  try {
    await processEvent(
      connection.user_id,
      body.traceId,
      body.eventType,
      body.resourceId,
      delivery.processed_at,
    );
  } catch (error) {
    const code = error instanceof Error ? error.message : "unknown";
    console.error(
      "health-provider-webhook",
      body.eventType,
      code.slice(0, 100),
    );
    return json({ error: "temporarily_unavailable" }, 503);
  }
  return json({ accepted: true }, 202);
});

function processEvent(
  userId: string,
  traceId: string,
  eventType: string,
  resourceId: string,
  processedAt: string | null,
) {
  return processPendingWebhook({
    processedAt,
    process: async () => {
      await syncWhoopResource(admin, userId, eventType, resourceId);
    },
    markProcessed: async () => {
      const { error } = await admin.from("health_provider_webhook_events")
        .update({
          processed_at: new Date().toISOString(),
          last_error_code: null,
        }).eq("provider", "WHOOP_DIRECT").eq("trace_id", traceId);
      if (error) throw error;
    },
    markFailed: async (error) => {
      const code = error instanceof Error ? error.message : "unknown";
      const { error: updateError } = await admin.from(
        "health_provider_webhook_events",
      ).update({
        last_error_code: code.slice(0, 100),
      }).eq("provider", "WHOOP_DIRECT").eq("trace_id", traceId);
      if (updateError) throw updateError;
    },
  });
}

function parseBody(rawBody: string) {
  try {
    const value = JSON.parse(rawBody) as Record<string, unknown>;
    const userId = identifier(value.user_id, 80);
    const resourceId = identifier(value.id, 200);
    const eventType = identifier(value.type, 80);
    const traceId = identifier(value.trace_id, 128);
    if (
      !userId || !resourceId || !allowedTypes.has(eventType) ||
      !/^[a-zA-Z0-9_-]{8,128}$/.test(traceId)
    ) return null;
    return { userId, resourceId, eventType, traceId };
  } catch {
    return null;
  }
}

function identifier(value: unknown, max: number) {
  if (typeof value !== "string" && typeof value !== "number") return "";
  const result = String(value).trim();
  return result.length <= max && /^[a-zA-Z0-9._:-]+$/.test(result)
    ? result
    : "";
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}
