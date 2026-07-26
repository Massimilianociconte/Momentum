// Google Health API webhook receiver.
// Verifies both the configured Authorization header and Google's rotating Tink
// ECDSA signature before accepting a notification. Notifications are persisted
// idempotently before background synchronization starts.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  fetchAndStoreDailySummary,
  GOOGLE_HEALTH_PROVIDER,
  requiredEnv,
  sha256,
} from "../_shared/google_health.ts";
import { processPendingWebhook } from "../_shared/webhook_retry.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const KEYSET_URL =
  "https://www.gstatic.com/googlehealthapi/webhooks/webhooks_public_keyset.json";
const MAX_BODY_BYTES = 64 * 1024;
let cachedKeyset: { expiresAt: number; value: TinkKeyset } | null = null;

type TinkKeyset = {
  key: Array<{
    keyId: number;
    status: string;
    outputPrefixType: string;
    keyData: { typeUrl: string; value: string };
  }>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  let expectedAuthorization: string;
  try {
    expectedAuthorization = requiredEnv("GOOGLE_HEALTH_WEBHOOK_AUTHORIZATION");
  } catch {
    return new Response(null, { status: 503 });
  }
  if (
    !constantTimeEqual(
      req.headers.get("authorization") ?? "",
      expectedAuthorization,
    )
  ) {
    return new Response(null, { status: 401 });
  }
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_BODY_BYTES) return new Response(null, { status: 413 });
  const raw = await req.text();
  const rawBytes = new TextEncoder().encode(raw);
  if (rawBytes.byteLength > MAX_BODY_BYTES) {
    return new Response(null, { status: 413 });
  }
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return new Response(null, { status: 400 });
  }

  if (body.type === "verification") return new Response(null, { status: 200 });
  const signature = req.headers.get("google-health-api-signature") ?? "";
  if (!signature || !await verifyGoogleSignature(rawBytes, signature)) {
    return new Response(null, { status: 401 });
  }

  const data = object(body.data);
  const healthUserId = string(data?.healthUserId, 128);
  const dataType = string(data?.dataType, 80);
  if (!healthUserId || !dataType) return new Response(null, { status: 400 });
  const { data: connection, error } = await admin
    .from("wearable_provider_connections")
    .select("user_id")
    .eq("provider", GOOGLE_HEALTH_PROVIDER)
    .eq("provider_subject_hash", await sha256(healthUserId))
    .eq("status", "CONNECTED")
    .maybeSingle();
  if (error) {
    console.error("google-health webhook lookup", error.message);
    return new Response(null, { status: 503 });
  }
  // Unknown/revoked users are acknowledged without leaking account existence.
  if (!connection?.user_id) return new Response(null, { status: 204 });

  const localDate = notificationDate(data);
  if (!localDate) return new Response(null, { status: 400 });
  const notificationHash = await sha256(raw);
  const { data: inserted, error: insertError } = await admin
    .from("wearable_health_notifications")
    .upsert({
      user_id: connection.user_id,
      notification_hash: notificationHash,
      data_type: dataType.slice(0, 80),
      local_date: localDate,
    }, { onConflict: "notification_hash", ignoreDuplicates: true })
    .select("notification_id,user_id,local_date,processed_at")
    .maybeSingle();
  if (insertError) {
    console.error("google-health webhook insert", insertError.message);
    return new Response(null, { status: 503 });
  }
  let notification = inserted;
  if (!notification) {
    const { data: existing, error: existingError } = await admin
      .from("wearable_health_notifications")
      .select("notification_id,user_id,local_date,processed_at")
      .eq("notification_hash", notificationHash)
      .maybeSingle();
    if (existingError || !existing) {
      console.error(
        "google-health webhook duplicate lookup",
        existingError?.message ?? "missing_notification",
      );
      return new Response(null, { status: 503 });
    }
    notification = existing;
  }

  try {
    await processNotification(
      notification.user_id,
      notification.notification_id,
      notification.local_date,
      notification.processed_at,
    );
  } catch (error) {
    console.error("google-health webhook sync", safeError(error));
    return new Response(null, { status: 503 });
  }
  return new Response(null, { status: 204 });
});

function processNotification(
  userId: string,
  notificationId: number,
  date: string,
  processedAt: string | null,
) {
  return processPendingWebhook({
    processedAt,
    process: async () => {
      await fetchAndStoreDailySummary(admin, userId, date, "provider-local");
    },
    markProcessed: async () => {
      const { error } = await admin.from("wearable_health_notifications")
        .update({ processed_at: new Date().toISOString() })
        .eq("notification_id", notificationId);
      if (error) throw error;
    },
    markFailed: async () => {
      const { error } = await admin.from("wearable_provider_connections")
        .update({
          last_error_code: "webhook_sync_failed",
          updated_at: new Date().toISOString(),
        }).eq("user_id", userId).eq("provider", GOOGLE_HEALTH_PROVIDER);
      if (error) throw error;
    },
  });
}

async function verifyGoogleSignature(
  payload: Uint8Array,
  encodedSignature: string,
) {
  try {
    const signature = decodeBase64(encodedSignature);
    if (signature.length < 7 || signature[0] !== 1) return false;
    const keyId = new DataView(
      signature.buffer,
      signature.byteOffset,
      signature.byteLength,
    ).getUint32(1, false);
    const keyset = await googleKeyset();
    const entry = keyset.key.find((key) =>
      key.keyId === keyId && key.status === "ENABLED" &&
      key.outputPrefixType === "TINK" &&
      key.keyData.typeUrl.endsWith("EcdsaPublicKey")
    );
    if (!entry) return false;
    const coordinates = parseEcdsaPublicKey(decodeBase64(entry.keyData.value));
    if (!coordinates) return false;
    const key = await crypto.subtle.importKey(
      "jwk",
      {
        kty: "EC",
        crv: "P-256",
        x: encodeBase64Url(coordinates.x),
        y: encodeBase64Url(coordinates.y),
        ext: true,
      },
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
    const rawSignature = derEcdsaToRaw(signature.slice(5), 32);
    const payloadBuffer = Uint8Array.from(payload).buffer;
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      rawSignature,
      payloadBuffer,
    );
  } catch (error) {
    console.error("google-health signature", safeError(error));
    return false;
  }
}

async function googleKeyset() {
  if (cachedKeyset && cachedKeyset.expiresAt > Date.now()) {
    return cachedKeyset.value;
  }
  const response = await fetch(KEYSET_URL, {
    headers: { accept: "application/json" },
  });
  if (!response.ok) throw new Error(`keyset_${response.status}`);
  const value = await response.json() as TinkKeyset;
  if (!Array.isArray(value.key) || value.key.length === 0) {
    throw new Error("empty_keyset");
  }
  cachedKeyset = { expiresAt: Date.now() + 60 * 60 * 1000, value };
  return value;
}

function parseEcdsaPublicKey(bytes: Uint8Array) {
  const fields = protobufLengthFields(bytes);
  const x = normalizeCoordinate(fields.get(3), 32);
  const y = normalizeCoordinate(fields.get(4), 32);
  return x && y ? { x, y } : null;
}

function protobufLengthFields(bytes: Uint8Array) {
  const fields = new Map<number, Uint8Array>();
  let offset = 0;
  while (offset < bytes.length) {
    const tag = readVarint(bytes, offset);
    offset = tag.next;
    const field = tag.value >>> 3;
    const wire = tag.value & 7;
    if (wire === 2) {
      const length = readVarint(bytes, offset);
      offset = length.next;
      const end = offset + length.value;
      if (end > bytes.length) throw new Error("invalid_protobuf_length");
      fields.set(field, bytes.slice(offset, end));
      offset = end;
    } else if (wire === 0) {
      offset = readVarint(bytes, offset).next;
    } else {
      throw new Error("unsupported_protobuf_wire");
    }
  }
  return fields;
}

function readVarint(bytes: Uint8Array, start: number) {
  let value = 0;
  let shift = 0;
  let offset = start;
  while (offset < bytes.length && shift <= 28) {
    const byte = bytes[offset++];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) === 0) return { value: value >>> 0, next: offset };
    shift += 7;
  }
  throw new Error("invalid_varint");
}

function derEcdsaToRaw(der: Uint8Array, size: number) {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("invalid_der_sequence");
  const sequence = derLength(der, offset);
  offset = sequence.next;
  if (offset + sequence.length !== der.length) {
    throw new Error("invalid_der_size");
  }
  const r = derInteger(der, offset);
  offset = r.next;
  const s = derInteger(der, offset);
  const raw = new Uint8Array(size * 2);
  raw.set(padInteger(r.value, size), 0);
  raw.set(padInteger(s.value, size), size);
  return raw;
}

function derInteger(bytes: Uint8Array, offset: number) {
  if (bytes[offset++] !== 0x02) throw new Error("invalid_der_integer");
  const length = derLength(bytes, offset);
  offset = length.next;
  const end = offset + length.length;
  if (end > bytes.length) throw new Error("invalid_der_integer_size");
  return { value: bytes.slice(offset, end), next: end };
}

function derLength(bytes: Uint8Array, offset: number) {
  const first = bytes[offset++];
  if (first < 0x80) return { length: first, next: offset };
  const count = first & 0x7f;
  if (count < 1 || count > 2 || offset + count > bytes.length) {
    throw new Error("invalid_der_length");
  }
  let length = 0;
  for (let i = 0; i < count; i++) length = (length << 8) | bytes[offset++];
  return { length, next: offset };
}

function padInteger(value: Uint8Array, size: number) {
  let normalized = value;
  while (normalized.length > 1 && normalized[0] === 0) {
    normalized = normalized.slice(1);
  }
  if (normalized.length > size) throw new Error("ecdsa_integer_too_large");
  const result = new Uint8Array(size);
  result.set(normalized, size - normalized.length);
  return result;
}

function normalizeCoordinate(value: Uint8Array | undefined, size: number) {
  if (!value) return null;
  let normalized = value;
  while (normalized.length > size && normalized[0] === 0) {
    normalized = normalized.slice(1);
  }
  if (normalized.length !== size) return null;
  return normalized;
}

function notificationDate(data: Record<string, unknown> | null) {
  const intervals = Array.isArray(data?.intervals) ? data.intervals : [];
  const first = object(intervals[0]);
  const civil = object(first?.civilDateTimeInterval);
  const start = object(civil?.startDateTime);
  const date = object(start?.date);
  const year = Number(date?.year);
  const month = Number(date?.month);
  const day = Number(date?.day);
  if (
    !Number.isInteger(year) || !Number.isInteger(month) ||
    !Number.isInteger(day)
  ) return null;
  return `${year.toString().padStart(4, "0")}-${
    month.toString().padStart(2, "0")
  }-${day.toString().padStart(2, "0")}`;
}

function constantTimeEqual(a: string, b: string) {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  const size = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let index = 0; index < size; index++) {
    diff |= (left[index % Math.max(1, left.length)] ?? 0) ^
      (right[index % Math.max(1, right.length)] ?? 0);
  }
  return diff === 0;
}

function object(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function string(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function decodeBase64(value: string) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function encodeBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function safeError(error: unknown) {
  return error instanceof Error ? error.message.slice(0, 300) : "unknown";
}
