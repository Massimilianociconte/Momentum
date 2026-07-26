import { assertEquals } from "jsr:@std/assert@1";
import {
  parseRevenueCatEnvelope,
  resolveRevenueCatPlanUpdate,
  revenueCatEventIdentity,
  revenueCatTransferCandidates,
  revenueCatUserCandidates,
  verifyRevenueCatAuthorization,
  verifyRevenueCatSignature,
} from "./revenuecat_webhook.ts";

Deno.test("paywall UI events never downgrade an active plan", () => {
  assertEquals(
    resolveRevenueCatPlanUpdate({
      type: "PAYWALL_IMPRESSION",
      app_user_id: "9ba40dd9-bebb-43b7-bac8-810654411234",
    }),
    { action: "skip", reason: "no_rallymate_plan_entitlement" },
  );
});

Deno.test("cancellation keeps access until expiration and expiration revokes", () => {
  const now = 1_800_000_000_000;
  const event = {
    type: "CANCELLATION",
    entitlement_ids: ["pro"],
    expiration_at_ms: now + 60_000,
  };
  assertEquals(resolveRevenueCatPlanUpdate(event, now), {
    action: "update",
    plan: "pro",
    expiresAtMs: now + 60_000,
  });
  assertEquals(
    resolveRevenueCatPlanUpdate({ ...event, type: "EXPIRATION" }, now),
    {
      action: "update",
      plan: "free",
      expiresAtMs: now + 60_000,
    },
  );
});

Deno.test("highest RallyMate entitlement wins", () => {
  const now = 1_800_000_000_000;
  assertEquals(
    resolveRevenueCatPlanUpdate({
      type: "RENEWAL",
      entitlement_ids: ["plus", "coach", "pro"],
      expiration_at_ms: now + 60_000,
    }, now),
    { action: "update", plan: "coach", expiresAtMs: now + 60_000 },
  );
});

Deno.test("active lifecycle events fail closed without a future expiry", () => {
  const now = 1_800_000_000_000;
  assertEquals(
    resolveRevenueCatPlanUpdate({
      type: "RENEWAL",
      entitlement_ids: ["pro"],
    }, now),
    { action: "update", plan: "free", expiresAtMs: null },
  );
  assertEquals(
    resolveRevenueCatPlanUpdate({
      type: "INITIAL_PURCHASE",
      entitlement_ids: ["pro"],
      expiration_at_ms: now - 1,
    }, now),
    { action: "update", plan: "free", expiresAtMs: now - 1 },
  );
});

Deno.test("user resolution considers original ID, aliases and transfer target", () => {
  assertEquals(
    revenueCatUserCandidates({
      app_user_id: "$RCAnonymousID:ignored",
      original_app_user_id: "not-a-uuid",
      aliases: [
        "9ba40dd9-bebb-43b7-bac8-810654411234",
        "$RCAnonymousID:also-ignored",
      ],
      transferred_to: ["64f45cad-da97-48e5-88e7-8ba6c39e4321"],
    }),
    [
      "9ba40dd9-bebb-43b7-bac8-810654411234",
      "64f45cad-da97-48e5-88e7-8ba6c39e4321",
    ],
  );
});

Deno.test("official TRANSFER fields resolve source and destination UUIDs", () => {
  assertEquals(
    revenueCatTransferCandidates({
      type: "TRANSFER",
      transferred_from: ["9BA40DD9-BEBB-43B7-BAC8-810654411234"],
      transferred_to: ["64f45cad-da97-48e5-88e7-8ba6c39e4321"],
    }),
    {
      from: ["9ba40dd9-bebb-43b7-bac8-810654411234"],
      to: ["64f45cad-da97-48e5-88e7-8ba6c39e4321"],
    },
  );
});

Deno.test("event identity requires RevenueCat id and timestamp", () => {
  assertEquals(
    revenueCatEventIdentity({
      id: "event-1",
      type: "renewal",
      event_timestamp_ms: 1_800_000_000_000,
    }),
    { id: "event-1", type: "RENEWAL", timestampMs: 1_800_000_000_000 },
  );
  assertEquals(revenueCatEventIdentity({ type: "RENEWAL" }), null);
});

Deno.test("authorization comparison is exact", () => {
  assertEquals(
    verifyRevenueCatAuthorization("Bearer correct", "correct"),
    true,
  );
  assertEquals(verifyRevenueCatAuthorization("Bearer wrong", "correct"), false);
  assertEquals(verifyRevenueCatAuthorization(null, "correct"), false);
});

Deno.test("HMAC validates raw body and rejects mutation or replay", async () => {
  const rawBody = JSON.stringify({ event: { type: "RENEWAL" } });
  const secret = "local-test-secret";
  const timestamp = 1_800_000_000;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );
  const signature = [...new Uint8Array(bytes)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  const header = `t=${timestamp},v1=${signature}`;
  const nowMs = timestamp * 1000;

  assertEquals(
    await verifyRevenueCatSignature({
      rawBody,
      signatureHeader: header,
      secret,
      nowMs,
    }),
    true,
  );
  assertEquals(
    await verifyRevenueCatSignature({
      rawBody: `${rawBody} `,
      signatureHeader: header,
      secret,
      nowMs,
    }),
    false,
  );
  assertEquals(
    await verifyRevenueCatSignature({
      rawBody,
      signatureHeader: header,
      secret,
      nowMs: nowMs + 301_000,
    }),
    false,
  );
});

Deno.test("invalid envelopes are rejected", () => {
  assertEquals(parseRevenueCatEnvelope("{}"), null);
  assertEquals(parseRevenueCatEnvelope("not json"), null);
});
