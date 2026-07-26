export async function verifyHmacSha256Base64(
  secret: string,
  message: string,
  receivedSignature: string,
) {
  if (!secret || !/^[A-Za-z0-9+/]{43}=$/.test(receivedSignature)) {
    return false;
  }
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
      new TextEncoder().encode(message),
    ),
  );
  const expected = btoa(String.fromCharCode(...digest));
  return constantTimeEqual(expected, receivedSignature);
}

export function isFreshUnixTimestamp(
  value: string,
  maxAgeSeconds = 300,
  nowMs = Date.now(),
) {
  // WHOOP documents this header as milliseconds since Unix epoch.
  if (!/^\d{13}$/.test(value)) return false;
  const numeric = Number(value);
  return Number.isFinite(numeric) &&
    Math.abs(nowMs - numeric) <= maxAgeSeconds * 1000;
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}
