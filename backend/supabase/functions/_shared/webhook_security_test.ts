import { assertEquals } from "jsr:@std/assert@1";
import {
  isFreshUnixTimestamp,
  verifyHmacSha256Base64,
} from "./webhook_security.ts";

Deno.test("WHOOP HMAC validation covers timestamp plus exact raw body", async () => {
  const secret = "test-secret";
  const timestamp = "1783944000";
  const body = '{"trace_id":"abc-12345"}';
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(timestamp + body),
    ),
  );
  const signature = btoa(String.fromCharCode(...digest));
  assertEquals(
    await verifyHmacSha256Base64(secret, timestamp + body, signature),
    true,
  );
  assertEquals(
    await verifyHmacSha256Base64(secret, timestamp + `${body} `, signature),
    false,
  );
});

Deno.test("webhook timestamp rejects replay outside the five-minute window", () => {
  const now = Date.UTC(2026, 6, 13, 12, 0, 0);
  assertEquals(isFreshUnixTimestamp(String(now), 300, now), true);
  assertEquals(isFreshUnixTimestamp(String(now - 301_000), 300, now), false);
  assertEquals(isFreshUnixTimestamp(String(now / 1000), 300, now), false);
  assertEquals(isFreshUnixTimestamp("not-a-date", 300, now), false);
});
