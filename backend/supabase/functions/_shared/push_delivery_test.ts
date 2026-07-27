import {
  apnsMessage,
  classifyPushJobOutcome,
  collapseId,
  constantTimeEqual,
  createApnsProviderToken,
  createFcmAssertion,
  fcmMessage,
  isInvalidApnsToken,
  isInvalidFcmToken,
  isRetryableProviderStatus,
  type PushJobPayload,
  retryDelaySeconds,
} from "./push_delivery.ts";

const job: PushJobPayload = {
  notificationId: "11111111-1111-4111-8111-111111111111",
  kind: "FRIEND_REQUEST",
  title: "Nuova richiesta Momentum",
  body: "Apri Momentum per rispondere.",
  deepLink: "rallymate://friends",
  payload: { requestId: "22222222-2222-4222-8222-222222222222" },
  dedupeKey: "friend_request:22222222-2222-4222-8222-222222222222:created",
  priority: "HIGH",
  expiresAt: new Date(Date.now() + 3600_000).toISOString(),
};

Deno.test("constant-time secret comparison rejects any mismatch", () => {
  assert(constantTimeEqual("server-secret", "server-secret"));
  assert(!constantTimeEqual("server-secret", "server-secreu"));
  assert(!constantTimeEqual("short", "longer"));
});

Deno.test("FCM payload is data-only and deep-links without exposing credentials", () => {
  const envelope = fcmMessage("device-token", job) as {
    message: Record<string, unknown>;
  };
  assert(envelope.message.notification === undefined);
  const data = envelope.message.data as Record<string, string>;
  assertEquals(data.deep_link, "rallymate://friends");
  assertEquals(data.kind, "FRIEND_REQUEST");
  assert(!JSON.stringify(envelope).includes("service_account"));
});

Deno.test("APNs payload uses a visible alert and a bounded collapse id", () => {
  const envelope = apnsMessage(job) as Record<string, unknown>;
  const aps = envelope.aps as Record<string, unknown>;
  assertEquals((aps.alert as Record<string, string>).title, job.title);
  assertEquals(envelope.deep_link, job.deepLink);
  assert(collapseId("x".repeat(100)).length === 64);
});

Deno.test("provider failures distinguish invalid tokens from retryable outages", () => {
  assert(isInvalidApnsToken(410, "Unregistered"));
  assert(isInvalidApnsToken(400, "BadDeviceToken"));
  assert(!isInvalidApnsToken(500, "InternalServerError"));
  assert(isInvalidFcmToken(404, "NOT_FOUND", "UNREGISTERED"));
  assert(!isInvalidFcmToken(503, "UNAVAILABLE", ""));
  assert(isRetryableProviderStatus(429));
  assert(isRetryableProviderStatus(503));
  assert(!isRetryableProviderStatus(400));
});

Deno.test("retry backoff is bounded", () => {
  assertEquals(retryDelaySeconds(1), 15);
  assertEquals(retryDelaySeconds(4), 120);
  assertEquals(retryDelaySeconds(8), 900);
  assertEquals(retryDelaySeconds(100), 900);
});

Deno.test("job outcome retries only transient devices and preserves terminal results", () => {
  const expiresAt = new Date(1_800_000_000_000 + 60_000).toISOString();
  assertEquals(
    classifyPushJobOutcome({
      priorSent: 1,
      priorFailed: 1,
      results: [{ status: "RETRY", errorCode: "UNAVAILABLE" }],
      attemptCount: 2,
      expiresAt,
      nowMs: 1_800_000_000_000,
    }),
    "RETRY",
  );
  assertEquals(
    classifyPushJobOutcome({
      priorSent: 1,
      priorFailed: 1,
      results: [],
      attemptCount: 3,
      expiresAt,
      nowMs: 1_800_000_000_000,
    }),
    "PARTIAL",
  );
});

Deno.test("invalid-only deliveries are suppressed instead of reported as provider failures", () => {
  assertEquals(
    classifyPushJobOutcome({
      results: [{ status: "INVALID", errorCode: "Unregistered" }],
      attemptCount: 1,
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
    }),
    "SUPPRESSED",
  );
});

Deno.test("FCM assertion is a signed RS256 JWT", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const privateKey = await pem(pair.privateKey, "PRIVATE KEY");
  const assertion = await createFcmAssertion({
    project_id: "rallymate-test",
    client_email: "push@test.invalid",
    private_key: privateKey,
  }, 1_800_000_000);
  const segments = assertion.split(".");
  assertEquals(segments.length, 3);
  assertEquals(JSON.parse(decodeSegment(segments[0])).alg, "RS256");
  assertEquals(JSON.parse(decodeSegment(segments[1])).exp, 1_800_003_600);
});

Deno.test("APNs provider token uses ES256 and a raw 64-byte signature", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const privateKey = await pem(pair.privateKey, "PRIVATE KEY");
  const token = await createApnsProviderToken({
    teamId: "TEAM123456",
    keyId: "KEY1234567",
    privateKey,
    topic: "com.rallymate.rallymate",
  }, 1_800_000_000);
  const segments = token.split(".");
  assertEquals(segments.length, 3);
  assertEquals(JSON.parse(decodeSegment(segments[0])).alg, "ES256");
  assertEquals(decodeBytes(segments[2]).length, 64);
});

async function pem(key: CryptoKey, label: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", key));
  const body =
    btoa(String.fromCharCode(...bytes)).match(/.{1,64}/gu)?.join("\n") ?? "";
  return `-----BEGIN ${label}-----\n${body}\n-----END ${label}-----\n`;
}

function decodeSegment(value: string): string {
  return new TextDecoder().decode(decodeBytes(value));
}

function decodeBytes(value: string): Uint8Array {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function assert(
  condition: unknown,
  message = "assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
