export type RevenueCatEvent = Record<string, unknown> & {
  id?: string;
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: unknown;
  transferred_from?: unknown;
  transferred_to?: unknown;
  entitlement_id?: string;
  entitlement_ids?: unknown;
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
};

export type RevenueCatEventIdentity = {
  id: string;
  type: string;
  timestampMs: number;
};

export type RevenueCatPlanUpdate =
  | {
    action: "update";
    plan: "free" | "plus" | "pro" | "coach";
    expiresAtMs: number | null;
  }
  | { action: "skip"; reason: string };

const PLAN_ORDER = ["coach", "pro", "plus"] as const;
const ACTIVE_LIFECYCLE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "SUBSCRIPTION_EXTENDED",
  "NON_RENEWING_PURCHASE",
  "PURCHASE_REDEEMED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);
const ACCESS_UNTIL_EXPIRY_EVENTS = new Set([
  "CANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
]);
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function verifyRevenueCatAuthorization(
  authorization: string | null,
  secret: string,
): boolean {
  if (!secret) return false;
  return constantTimeEqual(authorization ?? "", `Bearer ${secret}`);
}

export async function verifyRevenueCatSignature(args: {
  rawBody: string;
  signatureHeader: string | null;
  secret: string;
  nowMs?: number;
  toleranceSeconds?: number;
}): Promise<boolean> {
  if (!args.secret || !args.signatureHeader) return false;
  const parts = new Map<string, string>();
  for (const rawPart of args.signatureHeader.split(",")) {
    const separator = rawPart.indexOf("=");
    if (separator <= 0) return false;
    parts.set(
      rawPart.slice(0, separator).trim(),
      rawPart.slice(separator + 1).trim(),
    );
  }
  const timestamp = parts.get("t") ?? "";
  const supplied = (parts.get("v1") ?? "").toLowerCase();
  if (!/^\d{10,13}$/.test(timestamp) || !/^[0-9a-f]{64}$/.test(supplied)) {
    return false;
  }
  const timestampSeconds = Number(timestamp);
  if (!Number.isSafeInteger(timestampSeconds)) return false;
  const nowSeconds = Math.floor((args.nowMs ?? Date.now()) / 1000);
  if (
    Math.abs(nowSeconds - timestampSeconds) >
      (args.toleranceSeconds ?? 300)
  ) {
    return false;
  }

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(args.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${args.rawBody}`),
  );
  const computed = [...new Uint8Array(signature)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  return constantTimeEqual(computed, supplied);
}

export function parseRevenueCatEnvelope(
  rawBody: string,
): { event: RevenueCatEvent } | null {
  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== "object") return null;
    const event = (parsed as Record<string, unknown>).event;
    if (!event || typeof event !== "object" || Array.isArray(event)) {
      return null;
    }
    return { event: event as RevenueCatEvent };
  } catch (_) {
    return null;
  }
}

export function revenueCatUserCandidates(event: RevenueCatEvent): string[] {
  const rawCandidates: unknown[] = [
    event.app_user_id,
    event.original_app_user_id,
    ...(Array.isArray(event.aliases) ? event.aliases : []),
    ...(Array.isArray(event.transferred_to) ? event.transferred_to : []),
  ];
  const unique = new Set<string>();
  for (const candidate of rawCandidates) {
    if (typeof candidate !== "string") continue;
    const value = candidate.trim().toLowerCase();
    if (UUID_PATTERN.test(value)) unique.add(value);
  }
  return [...unique];
}

export function revenueCatEventIdentity(
  event: RevenueCatEvent,
): RevenueCatEventIdentity | null {
  const id = typeof event.id === "string" ? event.id.trim() : "";
  const type = typeof event.type === "string"
    ? event.type.trim().toUpperCase()
    : "";
  const timestampMs = Number(event.event_timestamp_ms);
  if (
    id.length < 1 || id.length > 128 || type.length < 1 || type.length > 64 ||
    !Number.isSafeInteger(timestampMs) || timestampMs <= 0
  ) return null;
  return { id, type, timestampMs };
}

export function revenueCatTransferCandidates(event: RevenueCatEvent): {
  from: string[];
  to: string[];
} {
  return {
    from: uuidList(event.transferred_from),
    to: uuidList(event.transferred_to),
  };
}

export function resolveRevenueCatPlanUpdate(
  event: RevenueCatEvent,
  nowMs = Date.now(),
): RevenueCatPlanUpdate {
  const type = typeof event.type === "string"
    ? event.type.trim().toUpperCase()
    : "";
  if (!type) return { action: "skip", reason: "missing_event_type" };

  const entitlementIds = new Set<string>();
  if (typeof event.entitlement_id === "string") {
    entitlementIds.add(event.entitlement_id.trim().toLowerCase());
  }
  if (Array.isArray(event.entitlement_ids)) {
    for (const item of event.entitlement_ids) {
      if (typeof item === "string") {
        entitlementIds.add(item.trim().toLowerCase());
      }
    }
  }
  const expiration = Number(event.expiration_at_ms);
  const expiresAtMs = Number.isFinite(expiration) && expiration > 0
    ? Math.trunc(expiration)
    : null;

  // EXPIRATION must not require entitlement ids (payload often omits them).
  if (type === "EXPIRATION") {
    return { action: "update", plan: "free", expiresAtMs };
  }

  const activePlan = PLAN_ORDER.find((plan) => entitlementIds.has(plan));
  if (!activePlan) {
    return { action: "skip", reason: "no_rallymate_plan_entitlement" };
  }
  if (ACTIVE_LIFECYCLE_EVENTS.has(type)) {
    return {
      action: "update",
      plan: expiresAtMs !== null && expiresAtMs > nowMs ? activePlan : "free",
      expiresAtMs,
    };
  }
  if (ACCESS_UNTIL_EXPIRY_EVENTS.has(type)) {
    return {
      action: "update",
      plan: expiresAtMs !== null && expiresAtMs > nowMs ? activePlan : "free",
      expiresAtMs,
    };
  }
  return { action: "skip", reason: "non_subscription_event" };
}

function uuidList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const unique = new Set<string>();
  for (const candidate of value) {
    if (typeof candidate !== "string") continue;
    const normalized = candidate.trim().toLowerCase();
    if (UUID_PATTERN.test(normalized)) unique.add(normalized);
  }
  return [...unique];
}

function constantTimeEqual(left: string, right: string): boolean {
  const maxLength = Math.max(left.length, right.length);
  let mismatch = left.length ^ right.length;
  for (let index = 0; index < maxLength; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}
