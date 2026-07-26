// Server-only APNs/FCM dispatcher for Padelandia's idempotent push outbox.
// Deploy with --no-verify-jwt and protect every invocation with
// X-Padelandia-Push-Secret. A Supabase scheduled function or Database Webhook
// may call this endpoint; mobile clients never receive the dispatcher secret.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type ApnsCredentials,
  apnsMessage,
  classifyPushJobOutcome,
  collapseId,
  constantTimeEqual,
  createApnsProviderToken,
  createFcmAssertion,
  fcmMessage,
  type FcmServiceAccount,
  isInvalidApnsToken,
  isInvalidFcmToken,
  isRetryableProviderStatus,
  type ProviderDeliveryResult,
  type PushJobPayload,
  retryDelaySeconds,
} from "../_shared/push_delivery.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const dispatchSecret = Deno.env.get("PUSH_DISPATCH_SECRET")?.trim() ?? "";

interface PushJobRow {
  notification_id: string;
  recipient_user_id: string;
  kind: string;
  title: string;
  body: string;
  deep_link: string | null;
  payload: Record<string, unknown> | null;
  dedupe_key: string;
  priority: "NORMAL" | "HIGH";
  attempt_count: number;
  expires_at: string;
}

interface PushDeviceRow {
  device_id: string;
  user_id: string;
  platform: "IOS" | "ANDROID" | "WATCHOS";
  transport: "APNS" | "FCM";
  environment: "SANDBOX" | "PRODUCTION";
  token: string;
}

type DeliveryResult = ProviderDeliveryResult;

let fcmAccessCache: { token: string; expiresAtMs: number } | null = null;
let apnsTokenCache: { token: string; expiresAtMs: number } | null = null;

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const provided = request.headers.get("x-rallymate-push-secret")?.trim() ?? "";
  if (!dispatchSecret || !constantTimeEqual(dispatchSecret, provided)) {
    return json({ error: "unauthorized" }, 401);
  }

  const body = await boundedJson(request, 2048);
  if (body === null) return json({ error: "invalid_payload" }, 400);
  const requested = typeof body.limit === "number"
    ? Math.trunc(body.limit)
    : 25;
  const limit = Math.max(1, Math.min(requested, 50));

  const { data, error } = await admin.rpc("claim_push_notifications", {
    p_limit: limit,
  });
  if (error) {
    console.error("push claim failed", error.message);
    return json({ error: "queue_unavailable" }, 503);
  }
  const jobs = (data as PushJobRow[] | null) ?? [];
  if (jobs.length === 0) return json({ ok: true, claimed: 0, sent: 0 });

  const recipientIds = [...new Set(jobs.map((job) => job.recipient_user_id))];
  const notificationIds = jobs.map((job) => job.notification_id);
  const [devicesResponse, deliveredResponse] = await Promise.all([
    admin.from("push_devices")
      .select("device_id,user_id,platform,transport,environment,token")
      .in("user_id", recipientIds)
      .eq("enabled", true),
    admin.from("push_deliveries")
      .select("notification_id,device_id,status")
      .in("notification_id", notificationIds)
      .in("status", ["SENT", "FAILED", "INVALID"]),
  ]);
  if (devicesResponse.error || deliveredResponse.error) {
    await releaseJobs(jobs, "registry_unavailable");
    return json({ error: "registry_unavailable" }, 503);
  }

  const devicesByUser = new Map<string, PushDeviceRow[]>();
  for (const device of (devicesResponse.data as PushDeviceRow[] | null) ?? []) {
    const list = devicesByUser.get(device.user_id) ?? [];
    list.push(device);
    devicesByUser.set(device.user_id, list);
  }
  const terminalDeliveries = new Map<string, "SENT" | "FAILED" | "INVALID">();
  for (
    const row of (deliveredResponse.data as
      | Array<{
        notification_id: string;
        device_id: string;
        status: "SENT" | "FAILED" | "INVALID";
      }>
      | null) ?? []
  ) {
    const key = `${row.notification_id}:${row.device_id}`;
    const previous = terminalDeliveries.get(key);
    if (previous == null || row.status === "SENT") {
      terminalDeliveries.set(key, row.status);
    }
  }

  let sent = 0;
  let retried = 0;
  let failed = 0;
  let suppressed = 0;
  for (const job of jobs) {
    const outcome = await dispatchJob(
      job,
      devicesByUser.get(job.recipient_user_id) ?? [],
      terminalDeliveries,
    );
    if (outcome === "SENT" || outcome === "PARTIAL") sent += 1;
    else if (outcome === "RETRY") retried += 1;
    else if (outcome === "SUPPRESSED") suppressed += 1;
    else failed += 1;
  }
  return json({
    ok: true,
    claimed: jobs.length,
    sent,
    retried,
    failed,
    suppressed,
  });
});

async function dispatchJob(
  row: PushJobRow,
  devices: PushDeviceRow[],
  terminalDeliveries: Map<string, "SENT" | "FAILED" | "INVALID">,
): Promise<"SENT" | "PARTIAL" | "RETRY" | "FAILED" | "SUPPRESSED"> {
  const prior = devices.map((device) =>
    terminalDeliveries.get(`${row.notification_id}:${device.device_id}`)
  );
  const priorSent = prior.filter((status) => status === "SENT").length;
  const priorFailed = prior.filter((status) => status === "FAILED").length;
  const priorInvalid = prior.filter((status) => status === "INVALID").length;
  const pending = devices.filter((device) =>
    !terminalDeliveries.has(`${row.notification_id}:${device.device_id}`)
  );
  if (devices.length === 0) {
    await finishJob(row.notification_id, "SUPPRESSED", "no_active_devices");
    return "SUPPRESSED";
  }
  if (pending.length === 0) {
    const outcome = classifyPushJobOutcome({
      priorSent,
      priorFailed,
      priorInvalid,
      results: [],
      attemptCount: row.attempt_count,
      expiresAt: row.expires_at,
    });
    if (outcome === "RETRY") {
      await retryJob(row, []);
      return outcome;
    }
    await finishJob(row.notification_id, outcome, null);
    return outcome;
  }

  const payload: PushJobPayload = {
    notificationId: row.notification_id,
    kind: row.kind,
    title: row.title,
    body: row.body,
    deepLink: row.deep_link,
    payload: row.payload,
    dedupeKey: row.dedupe_key,
    priority: row.priority,
    expiresAt: row.expires_at,
  };
  const results = await Promise.all(
    pending.map(async (device) => {
      let result: DeliveryResult;
      try {
        result = device.transport === "APNS"
          ? await sendApns(device, payload)
          : await sendFcm(device, payload);
      } catch (error) {
        const code = error instanceof Error ? error.message : "provider_error";
        result = { status: "RETRY", errorCode: code.slice(0, 160) };
      }
      await recordDelivery(row, device, result);
      if (result.status === "INVALID") {
        await invalidateDevice(device, result.errorCode);
      }
      return result;
    }),
  );

  const outcome = classifyPushJobOutcome({
    priorSent,
    priorFailed,
    priorInvalid,
    results,
    attemptCount: row.attempt_count,
    expiresAt: row.expires_at,
  });
  if (outcome === "RETRY") {
    await retryJob(row, results);
    return "RETRY";
  }
  await finishJob(row.notification_id, outcome, summarizeErrors(results));
  return outcome;
}

async function sendFcm(
  device: PushDeviceRow,
  job: PushJobPayload,
): Promise<DeliveryResult> {
  const account = fcmAccount();
  if (!account) return { status: "RETRY", errorCode: "fcm_not_configured" };
  const accessToken = await fcmAccessToken(account);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${
      encodeURIComponent(account.project_id)
    }/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(fcmMessage(device.token, job)),
    },
  );
  const body = await response.json().catch(() => ({})) as Record<
    string,
    unknown
  >;
  if (response.ok) {
    return { status: "SENT", messageId: String(body.name ?? "") };
  }
  const error = (body.error as Record<string, unknown> | undefined) ?? {};
  const providerStatus = String(error.status ?? "");
  const details = Array.isArray(error.details) ? error.details : [];
  const errorCode = String(
    (details.find((item) =>
      item && typeof item === "object" && "errorCode" in item
    ) as Record<string, unknown> | undefined)?.errorCode ?? providerStatus ??
      response.status,
  );
  if (isInvalidFcmToken(response.status, providerStatus, errorCode)) {
    return { status: "INVALID", errorCode };
  }
  const retry = isRetryableProviderStatus(response.status) || [
    "UNAVAILABLE",
    "INTERNAL",
    "RESOURCE_EXHAUSTED",
  ].includes(providerStatus);
  return {
    status: retry ? "RETRY" : "FAILED",
    errorCode: errorCode.slice(0, 160),
  };
}

async function sendApns(
  device: PushDeviceRow,
  job: PushJobPayload,
): Promise<DeliveryResult> {
  const credentials = apnsCredentials();
  if (!credentials) {
    return { status: "RETRY", errorCode: "apns_not_configured" };
  }
  const providerToken = await apnsProviderToken(credentials);
  const host = device.environment === "SANDBOX"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const expiration = Math.max(
    Math.floor(Date.now() / 1000),
    Math.floor(Date.parse(job.expiresAt) / 1000),
  );
  const response = await fetch(`${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${providerToken}`,
      "content-type": "application/json",
      "apns-topic": credentials.topic,
      "apns-push-type": "alert",
      "apns-priority": job.priority === "HIGH" ? "10" : "5",
      "apns-expiration": String(expiration),
      "apns-collapse-id": collapseId(job.dedupeKey),
    },
    body: JSON.stringify(apnsMessage(job)),
  });
  if (response.ok) {
    return {
      status: "SENT",
      messageId: response.headers.get("apns-id") ?? undefined,
    };
  }
  const body = await response.json().catch(() => ({})) as Record<
    string,
    unknown
  >;
  const reason = String(body.reason ?? response.status);
  if (isInvalidApnsToken(response.status, reason)) {
    return { status: "INVALID", errorCode: reason };
  }
  return {
    status: isRetryableProviderStatus(response.status) ? "RETRY" : "FAILED",
    errorCode: reason.slice(0, 160),
  };
}

async function recordDelivery(
  job: PushJobRow,
  device: PushDeviceRow,
  result: DeliveryResult,
): Promise<void> {
  const { error } = await admin.from("push_deliveries").upsert({
    notification_id: job.notification_id,
    device_id: device.device_id,
    attempt: job.attempt_count,
    status: result.status,
    provider_message_id: result.messageId ?? null,
    error_code: result.errorCode ?? null,
  }, { onConflict: "notification_id,device_id,attempt" });
  if (error) console.error("push delivery audit failed", error.message);
}

async function invalidateDevice(
  device: PushDeviceRow,
  reason?: string,
): Promise<void> {
  const { error } = await admin.from("push_devices").update({
    enabled: false,
    invalidated_at: new Date().toISOString(),
    invalidation_reason: (reason ?? "provider_invalid_token").slice(0, 160),
    updated_at: new Date().toISOString(),
  }).eq("device_id", device.device_id);
  if (error) console.error("push token invalidation failed", error.message);
}

async function retryJob(
  row: PushJobRow,
  results: DeliveryResult[],
): Promise<void> {
  const delay = retryDelaySeconds(row.attempt_count);
  const { error } = await admin.from("push_outbox").update({
    status: "RETRY",
    next_attempt_at: new Date(Date.now() + delay * 1000).toISOString(),
    last_error: summarizeErrors(results),
    updated_at: new Date().toISOString(),
  }).eq("notification_id", row.notification_id).eq("status", "PROCESSING");
  if (error) console.error("push retry update failed", error.message);
}

async function finishJob(
  notificationId: string,
  status: "SENT" | "PARTIAL" | "FAILED" | "SUPPRESSED",
  errorCode: string | null,
): Promise<void> {
  const { error } = await admin.from("push_outbox").update({
    status,
    sent_at: status === "SENT" || status === "PARTIAL"
      ? new Date().toISOString()
      : null,
    last_error: errorCode,
    updated_at: new Date().toISOString(),
  }).eq("notification_id", notificationId).eq("status", "PROCESSING");
  if (error) console.error("push completion update failed", error.message);
}

async function releaseJobs(jobs: PushJobRow[], reason: string): Promise<void> {
  const delay = new Date(Date.now() + 60_000).toISOString();
  const { error } = await admin.from("push_outbox").update({
    status: "RETRY",
    next_attempt_at: delay,
    last_error: reason,
    updated_at: new Date().toISOString(),
  }).in("notification_id", jobs.map((job) => job.notification_id))
    .eq("status", "PROCESSING");
  if (error) console.error("push lease release failed", error.message);
}

function summarizeErrors(results: DeliveryResult[]): string | null {
  const values = [
    ...new Set(results.map((result) => result.errorCode).filter(Boolean)),
  ];
  return values.length === 0 ? null : values.join(",").slice(0, 500);
}

function fcmAccount(): FcmServiceAccount | null {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")?.trim();
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as Partial<FcmServiceAccount>;
    if (!value.project_id || !value.client_email || !value.private_key) {
      return null;
    }
    return value as FcmServiceAccount;
  } catch {
    return null;
  }
}

function apnsCredentials(): ApnsCredentials | null {
  const value: ApnsCredentials = {
    teamId: Deno.env.get("APNS_TEAM_ID")?.trim() ?? "",
    keyId: Deno.env.get("APNS_KEY_ID")?.trim() ?? "",
    privateKey: Deno.env.get("APNS_PRIVATE_KEY")?.trim() ?? "",
    topic: Deno.env.get("APNS_BUNDLE_ID")?.trim() ?? "",
  };
  return Object.values(value).every(Boolean) ? value : null;
}

async function fcmAccessToken(account: FcmServiceAccount): Promise<string> {
  if (fcmAccessCache && fcmAccessCache.expiresAtMs > Date.now() + 60_000) {
    return fcmAccessCache.token;
  }
  const assertion = await createFcmAssertion(account);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json().catch(() => ({})) as Record<
    string,
    unknown
  >;
  const token = String(body.access_token ?? "");
  if (!response.ok || !token) throw new Error("fcm_auth_failed");
  const expiresIn = Math.max(60, Number(body.expires_in ?? 3600));
  fcmAccessCache = { token, expiresAtMs: Date.now() + expiresIn * 1000 };
  return token;
}

async function apnsProviderToken(
  credentials: ApnsCredentials,
): Promise<string> {
  if (apnsTokenCache && apnsTokenCache.expiresAtMs > Date.now() + 60_000) {
    return apnsTokenCache.token;
  }
  const token = await createApnsProviderToken(credentials);
  // Apple accepts a provider token for at most one hour; refresh at 50 min.
  apnsTokenCache = { token, expiresAtMs: Date.now() + 50 * 60_000 };
  return token;
}

async function boundedJson(
  request: Request,
  maxBytes: number,
): Promise<Record<string, unknown> | null> {
  const declared = Number(request.headers.get("content-length") ?? 0);
  if (declared > maxBytes) return null;
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > maxBytes) return null;
  if (!raw) return {};
  try {
    const value = JSON.parse(raw);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value
      : null;
  } catch {
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}
