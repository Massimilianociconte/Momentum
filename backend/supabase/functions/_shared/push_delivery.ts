export type PushTransport = "APNS" | "FCM";

export interface PushJobPayload {
  notificationId: string;
  kind: string;
  title: string;
  body: string;
  deepLink?: string | null;
  payload?: Record<string, unknown> | null;
  dedupeKey: string;
  priority: "NORMAL" | "HIGH";
  expiresAt: string;
}

export interface FcmServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface ApnsCredentials {
  teamId: string;
  keyId: string;
  privateKey: string;
  topic: string;
}

export type ProviderDeliveryStatus = "SENT" | "RETRY" | "INVALID" | "FAILED";
export type PushJobOutcome =
  | "SENT"
  | "PARTIAL"
  | "RETRY"
  | "FAILED"
  | "SUPPRESSED";

export interface ProviderDeliveryResult {
  status: ProviderDeliveryStatus;
  messageId?: string;
  errorCode?: string;
}

const encoder = new TextEncoder();

export function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}

export function normalizedPrivateKey(value: string): string {
  return value.trim().replaceAll("\\n", "\n");
}

export function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export async function createFcmAssertion(
  account: FcmServiceAccount,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  if (!account.client_email || !account.private_key) {
    throw new Error("fcm_credentials_missing");
  }
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      encoder.encode(signingInput),
    ),
  );
  return `${signingInput}.${base64Url(signature)}`;
}

export async function createApnsProviderToken(
  credentials: ApnsCredentials,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  if (!credentials.teamId || !credentials.keyId || !credentials.privateKey) {
    throw new Error("apns_credentials_missing");
  }
  const header = base64Url(JSON.stringify({
    alg: "ES256",
    kid: credentials.keyId,
  }));
  const claims = base64Url(JSON.stringify({
    iss: credentials.teamId,
    iat: nowSeconds,
  }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(credentials.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      encoder.encode(signingInput),
    ),
  );
  // WebCrypto returns the JOSE-compatible raw R || S signature for ECDSA.
  if (signature.length !== 64) throw new Error("apns_signature_invalid");
  return `${signingInput}.${base64Url(signature)}`;
}

export function fcmMessage(
  token: string,
  job: PushJobPayload,
): Record<string, unknown> {
  const ttlSeconds = ttl(job.expiresAt);
  return {
    message: {
      token,
      data: {
        notification_id: job.notificationId,
        kind: job.kind,
        title: job.title,
        body: job.body,
        deep_link: job.deepLink ?? "",
        payload: JSON.stringify(job.payload ?? {}),
      },
      android: {
        priority: job.priority === "HIGH" ? "HIGH" : "NORMAL",
        ttl: `${ttlSeconds}s`,
        collapse_key: collapseId(job.dedupeKey),
      },
    },
  };
}

export function apnsMessage(job: PushJobPayload): Record<string, unknown> {
  return {
    aps: {
      alert: { title: job.title, body: job.body },
      sound: "default",
      category: job.kind,
      "thread-id": threadId(job.kind),
    },
    notification_id: job.notificationId,
    kind: job.kind,
    deep_link: job.deepLink ?? "",
    payload: job.payload ?? {},
  };
}

export function collapseId(value: string): string {
  // APNs permits at most 64 bytes. Dedupe keys are ASCII by construction.
  return value.length <= 64 ? value : value.slice(0, 64);
}

export function retryDelaySeconds(attempt: number): number {
  const bounded = Math.max(1, Math.min(attempt, 8));
  return Math.min(15 * 60, 15 * 2 ** (bounded - 1));
}

export function classifyPushJobOutcome({
  priorSent = 0,
  priorFailed = 0,
  priorInvalid = 0,
  results,
  attemptCount,
  expiresAt,
  nowMs = Date.now(),
}: {
  priorSent?: number;
  priorFailed?: number;
  priorInvalid?: number;
  results: ProviderDeliveryResult[];
  attemptCount: number;
  expiresAt: string;
  nowMs?: number;
}): PushJobOutcome {
  const retryable =
    results.filter((result) => result.status === "RETRY").length;
  if (
    retryable > 0 && attemptCount < 8 &&
    Date.parse(expiresAt) > nowMs
  ) {
    return "RETRY";
  }

  const sent = priorSent +
    results.filter((result) => result.status === "SENT").length;
  const failed = priorFailed + retryable +
    results.filter((result) => result.status === "FAILED").length;
  const invalid = priorInvalid +
    results.filter((result) => result.status === "INVALID").length;
  if (sent > 0) return failed > 0 ? "PARTIAL" : "SENT";
  if (failed > 0) return "FAILED";
  return invalid > 0 ? "SUPPRESSED" : "FAILED";
}

export function isInvalidApnsToken(status: number, reason: string): boolean {
  return status === 410 || [
    "BadDeviceToken",
    "DeviceTokenNotForTopic",
    "MissingDeviceToken",
    "Unregistered",
  ].includes(reason);
}

export function isRetryableProviderStatus(status: number): boolean {
  return status === 408 || status === 409 || status === 425 || status === 429 ||
    status >= 500;
}

export function isInvalidFcmToken(
  httpStatus: number,
  providerStatus: string,
  errorCode: string,
): boolean {
  return errorCode === "UNREGISTERED" || errorCode === "SENDER_ID_MISMATCH" ||
    (httpStatus === 404 && providerStatus === "NOT_FOUND");
}

function pemBytes(raw: string): ArrayBuffer {
  const normalized = normalizedPrivateKey(raw);
  const body = normalized.replace(/-----BEGIN [^-]+-----/gu, "")
    .replace(/-----END [^-]+-----/gu, "")
    .replace(/\s/gu, "");
  if (!body) throw new Error("private_key_invalid");
  const decoded = atob(body);
  const buffer = new ArrayBuffer(decoded.length);
  const bytes = new Uint8Array(buffer);
  for (let index = 0; index < decoded.length; index++) {
    bytes[index] = decoded.charCodeAt(index);
  }
  return buffer;
}

function ttl(expiresAt: string): number {
  const expires = Date.parse(expiresAt);
  if (!Number.isFinite(expires)) return 3600;
  return Math.max(
    60,
    Math.min(7 * 24 * 3600, Math.floor((expires - Date.now()) / 1000)),
  );
}

function threadId(kind: string): string {
  if (
    kind.startsWith("FRIEND") || kind.startsWith("MATCH") ||
    kind.startsWith("TEAM")
  ) {
    return "social";
  }
  if (kind.startsWith("DUO")) return "duo";
  if (kind.startsWith("COACH")) return "coach";
  return "rallymate";
}
