export async function sha256(value: string) {
  const result = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(result)]
    .map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function requiredEnv(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`missing_${name.toLowerCase()}`);
  return value;
}

export function randomToken(size = 32) {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  return encodeBase64(bytes)
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export async function encryptProviderToken(
  value: string,
  userId: string,
  provider: string,
  kind: "access" | "refresh",
) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv,
      additionalData: aad(userId, provider, kind),
    },
    await encryptionKey(),
    new TextEncoder().encode(value),
  );
  return {
    ciphertext: encodeBase64(new Uint8Array(ciphertext)),
    iv: encodeBase64(iv),
  };
}

export async function decryptProviderToken(
  ciphertext: string,
  iv: string,
  userId: string,
  provider: string,
  kind: "access" | "refresh",
) {
  const key = await encryptionKey();
  const cipherBytes = decodeBase64(ciphertext);
  const ivBytes = decodeBase64(iv);
  try {
    return await decryptWithAad(
      cipherBytes,
      ivBytes,
      key,
      aad(userId, provider, kind),
    );
  } catch (error) {
    // Google Health tokens created before the unified provider migration used
    // `${userId}|${kind}` as AAD. Keep one-way compatibility so existing
    // users are not forced to reconnect; every newly written token uses the
    // provider-scoped AAD above.
    if (provider !== "GOOGLE_HEALTH") throw error;
    return decryptWithAad(
      cipherBytes,
      ivBytes,
      key,
      new TextEncoder().encode(`${userId}|${kind}`),
    );
  }
}

async function decryptWithAad(
  ciphertext: Uint8Array<ArrayBuffer>,
  iv: Uint8Array<ArrayBuffer>,
  key: CryptoKey,
  additionalData: Uint8Array<ArrayBuffer>,
) {
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv, additionalData },
    key,
    ciphertext,
  );
  return new TextDecoder().decode(plaintext);
}

function aad(
  userId: string,
  provider: string,
  kind: "access" | "refresh",
) {
  return new TextEncoder().encode(`${userId}|${provider}|${kind}`);
}

async function encryptionKey() {
  const encoded = requiredEnv("WEARABLE_TOKEN_ENCRYPTION_KEY");
  const bytes = decodeBase64(encoded);
  if (bytes.length !== 32) throw new Error("invalid_wearable_encryption_key");
  return await crypto.subtle.importKey("raw", bytes, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

function encodeBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
