// Secure bridge for runtimes that cannot use WatchConnectivity/Wear Data Layer.
//
// Authenticated mobile actions:
//   create_pairing, ingest_mobile, enqueue_command, drain, acknowledge,
//   disconnect
// Device actions (manual auth, deploy with --no-verify-jwt):
//   claim, ingest, commands, acknowledge_command, ping
//
// Required secret:
//   WEARABLE_RATE_LIMIT_SECRET=<random 32+ byte value>

import { createClient } from "npm:@supabase/supabase-js@2";
import { hasActiveEntitlement } from "../_shared/entitlement.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const RATE_SECRET = Deno.env.get("WEARABLE_RATE_LIMIT_SECRET") ?? "";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_EVENTS = 50;
// RESUME_MATCH journals: 250 sanitized events (~180 B each) stay within the
// 48 KiB payload CHECK and the 64 KiB body limit.
const MAX_RESUME_EVENTS = 250;
const PAIRING_TTL_MS = 10 * 60 * 1000;
const DEVICE_TOKEN_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const PROVIDERS = ["FITBIT_OS", "GARMIN_CONNECT_IQ"] as const;
const EVENT_TYPES = new Set([
  "MATCH_STARTED",
  "POINT_TEAM_A",
  "POINT_TEAM_B",
  "UNDO",
  "MATCH_PAUSED",
  "MATCH_RESUMED",
  "MATCH_COMPLETED",
]);
const SOURCE_METHODS = new Set([
  "TAP",
  "VOICE",
  "BLIND_TAP",
  "AUTO",
  "MANUAL_EDIT",
]);

type Provider = typeof PROVIDERS[number];
type Json = Record<string, unknown>;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return cors(new Response(null, { status: 204 }), req);
  }
  if (req.method !== "POST") {
    return respond(req, { error: "method_not_allowed" }, 405);
  }

  const body = await readJson(req);
  if (!body) return respond(req, { error: "invalid_request" }, 400);
  const action = asString(body.action, 40);

  try {
    switch (action) {
      case "create_pairing":
        return await createPairing(req, body);
      case "ingest_mobile":
        return await ingestMobile(req, body);
      case "enqueue_command":
        return await enqueueCommand(req, body);
      case "drain":
        return await drainEvents(req);
      case "acknowledge":
        return await acknowledgeEvents(req, body);
      case "disconnect":
        return await disconnect(req, body);
      case "claim":
        return await claim(req, body);
      case "ingest":
        return await ingest(req, body);
      case "commands":
        return await deviceCommands(req);
      case "acknowledge_command":
        return await acknowledgeCommand(req, body);
      case "ping":
        return await devicePing(req);
      default:
        return respond(req, { error: "unknown_action" }, 400);
    }
  } catch (error) {
    console.error("wearable-gateway", action, safeError(error));
    return respond(req, { error: "temporarily_unavailable" }, 503);
  }
});

async function createPairing(req: Request, body: Json) {
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  if (!await hasWearableCloudAccess(user.id)) {
    return respond(req, { error: "plan_required", requiredPlan: "plus" }, 403);
  }
  const provider = parseProvider(body.provider);
  if (!provider) return respond(req, { error: "invalid_provider" }, 400);

  const code = randomCode(8);
  const expiresAt = new Date(Date.now() + PAIRING_TTL_MS).toISOString();
  const { error } = await admin.from("wearable_pairing_challenges").insert({
    user_id: user.id,
    provider,
    code_hash: await sha256(code),
    expires_at: expiresAt,
  });
  if (error) throw error;

  const { error: connectionError } = await admin
    .from("wearable_provider_connections")
    .upsert({
      user_id: user.id,
      provider,
      status: "PENDING",
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,provider" });
  if (connectionError) throw connectionError;

  return respond(req, {
    provider,
    code,
    displayCode: `${code.slice(0, 4)}-${code.slice(4)}`,
    expiresAt,
  });
}

async function claim(req: Request, body: Json) {
  if (!RATE_SECRET) {
    return respond(req, { error: "server_not_configured" }, 503);
  }
  const actorHash = await requestActorHash(req, "claim");
  const rate = await beginRateEvent(actorHash, "CLAIM", 20, 10 * 60 * 1000);
  if (!rate.allowed) return respond(req, { error: "rate_limited" }, 429);

  const provider = parseProvider(body.provider);
  const code = asString(body.code, 16).replace(/[^A-Z0-9]/gi, "").toUpperCase();
  const displayName = asString(body.displayName, 80);
  const capabilities = stringList(body.capabilities, 16, 40);
  if (!provider || code.length !== 8) {
    return respond(req, { error: "invalid_pairing" }, 400);
  }

  const token = randomToken(32);
  const expiresAt = new Date(Date.now() + DEVICE_TOKEN_TTL_MS).toISOString();
  const { data, error } = await admin.rpc("claim_wearable_pairing", {
    p_code_hash: await sha256(code),
    p_provider: provider,
    p_token_hash: await sha256(token),
    p_display_name: displayName,
    p_capabilities: capabilities,
    p_expires_at: expiresAt,
  });
  if (error || !data) {
    return respond(req, { error: "invalid_pairing" }, 400);
  }
  await markRateSuccess(rate.eventId);
  return respond(req, { provider, token, expiresAt });
}

async function ingest(req: Request, body: Json) {
  if (!RATE_SECRET) {
    return respond(req, { error: "server_not_configured" }, 503);
  }
  const credential = wearableCredential(req);
  if (!credential) return respond(req, { error: "unauthorized" }, 401);
  const tokenHash = await sha256(credential);
  const { data: token, error } = await admin
    .from("wearable_device_tokens")
    .select("token_id,user_id,provider,expires_at,revoked_at")
    .eq("token_hash", tokenHash)
    .maybeSingle();
  if (error) throw error;
  if (
    !token || token.revoked_at || Date.parse(token.expires_at) <= Date.now()
  ) {
    return respond(req, { error: "unauthorized" }, 401);
  }
  if (!await hasWearableCloudAccess(token.user_id)) {
    return respond(req, { error: "plan_required", requiredPlan: "plus" }, 403);
  }

  const actorHash = await requestActorHash(
    req,
    `ingest:${tokenHash.slice(0, 16)}`,
  );
  const rate = await beginRateEvent(actorHash, "INGEST", 120, 60 * 1000);
  if (!rate.allowed) return respond(req, { error: "rate_limited" }, 429);

  const input = Array.isArray(body.events)
    ? body.events.slice(0, MAX_EVENTS)
    : [];
  if (input.length === 0) return respond(req, { error: "empty_events" }, 400);
  const rows = input
    .map((value) => sanitizeEvent(value, token.user_id, token.provider))
    .filter((value): value is Json => value !== null);
  if (rows.length !== input.length) {
    return respond(req, { error: "invalid_event" }, 400);
  }

  const { error: insertError } = await admin
    .from("wearable_ingest_events")
    .upsert(rows, {
      onConflict: "user_id,provider,external_event_id",
      ignoreDuplicates: true,
    });
  if (insertError) throw insertError;
  await admin.from("wearable_device_tokens").update({
    last_seen_at: new Date().toISOString(),
  }).eq("token_id", token.token_id);
  await markRateSuccess(rate.eventId);
  return respond(req, { accepted: rows.length });
}

async function ingestMobile(req: Request, body: Json) {
  if (!RATE_SECRET) {
    return respond(req, { error: "server_not_configured" }, 503);
  }
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  if (!await hasWearableCloudAccess(user.id)) {
    return respond(req, { error: "plan_required", requiredPlan: "plus" }, 403);
  }
  const provider = parseProvider(body.provider);
  if (!provider) return respond(req, { error: "invalid_provider" }, 400);
  const actorHash = await requestActorHash(req, `mobile:${user.id}`);
  const rate = await beginRateEvent(actorHash, "INGEST", 120, 60 * 1000);
  if (!rate.allowed) return respond(req, { error: "rate_limited" }, 429);

  const input = Array.isArray(body.events)
    ? body.events.slice(0, MAX_EVENTS)
    : [];
  if (input.length === 0) return respond(req, { error: "empty_events" }, 400);
  const rows = input
    .map((value) => sanitizeEvent(value, user.id, provider))
    .filter((value): value is Json => value !== null);
  if (rows.length !== input.length) {
    return respond(req, { error: "invalid_event" }, 400);
  }
  const { error } = await admin.from("wearable_ingest_events").upsert(rows, {
    onConflict: "user_id,provider,external_event_id",
    ignoreDuplicates: true,
  });
  if (error) throw error;
  const now = new Date().toISOString();
  await admin.from("wearable_provider_connections").upsert({
    user_id: user.id,
    provider,
    status: "CONNECTED",
    last_sync_at: now,
    updated_at: now,
  }, { onConflict: "user_id,provider" });
  await markRateSuccess(rate.eventId);
  return respond(req, { accepted: rows.length });
}

async function devicePing(req: Request) {
  const credential = wearableCredential(req);
  if (!credential) return respond(req, { error: "unauthorized" }, 401);
  const { data } = await admin.from("wearable_device_tokens")
    .select("token_id,user_id,expires_at,revoked_at")
    .eq("token_hash", await sha256(credential))
    .maybeSingle();
  const active = data && !data.revoked_at &&
    Date.parse(data.expires_at) > Date.now() &&
    await hasWearableCloudAccess(data.user_id);
  return active
    ? respond(req, { ok: true, serverTime: new Date().toISOString() })
    : respond(req, { error: "unauthorized" }, 401);
}

async function enqueueCommand(req: Request, body: Json) {
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  if (!await hasWearableCloudAccess(user.id)) {
    return respond(req, { error: "plan_required", requiredPlan: "plus" }, 403);
  }
  const provider = parseProvider(body.provider);
  const commandType = asString(body.commandType, 40).toUpperCase();
  if (
    provider !== "FITBIT_OS" ||
    !["START_MATCH", "RESUME_MATCH"].includes(commandType)
  ) {
    return respond(req, { error: "invalid_command" }, 400);
  }
  const payload = commandType === "RESUME_MATCH"
    ? sanitizeResumeMatch(body.payload)
    : sanitizeStartMatch(body.payload);
  if (!payload) return respond(req, { error: "invalid_command" }, 400);
  const sanitizedFormat = payload.format;
  if (
    sanitizedFormat && typeof sanitizedFormat === "object" &&
    !Array.isArray(sanitizedFormat) &&
    (sanitizedFormat as Json).gameScoringMode === "STAR_POINT"
  ) {
    // Fitbit OS does not yet advertise or implement scoring protocol v2.
    // Enforce the same fail-closed rule server-side so a direct request can
    // never reinterpret Star Point as unlimited advantages.
    return respond(req, { error: "unsupported_companion" }, 409);
  }
  const now = new Date().toISOString();
  const { data: token, error: tokenError } = await admin
    .from("wearable_device_tokens")
    .select("token_id")
    .eq("user_id", user.id)
    .eq("provider", provider)
    .is("revoked_at", null)
    .gt("expires_at", now)
    .order("last_seen_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (tokenError) throw tokenError;
  if (!token) return respond(req, { error: "device_not_connected" }, 409);
  const { data, error } = await admin.from("wearable_outbound_commands")
    .insert({
      user_id: user.id,
      provider,
      target_token_id: token.token_id,
      command_type: commandType,
      payload,
      expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
    })
    .select("command_id,expires_at")
    .single();
  if (error) throw error;
  return respond(req, {
    queued: true,
    commandId: data.command_id,
    expiresAt: data.expires_at,
  });
}

async function deviceCommands(req: Request) {
  const token = await activeDeviceToken(req);
  if (!token) return respond(req, { error: "unauthorized" }, 401);
  if (!await hasWearableCloudAccess(token.user_id)) {
    return respond(req, { error: "plan_required", requiredPlan: "plus" }, 403);
  }
  const rate = await beginRateEvent(
    await requestActorHash(req, `pull:${token.token_id}`),
    "PULL",
    120,
    60 * 1000,
  );
  if (!rate.allowed) return respond(req, { error: "rate_limited" }, 429);
  const now = new Date().toISOString();
  const { data, error } = await admin.from("wearable_outbound_commands")
    .select("command_id,command_type,payload,expires_at")
    .eq("target_token_id", token.token_id)
    .is("acknowledged_at", null)
    .gt("expires_at", now)
    .order("created_at", { ascending: true })
    .limit(10);
  if (error) throw error;
  const ids = (data ?? []).map((value) => value.command_id);
  if (ids.length > 0) {
    await admin.from("wearable_outbound_commands")
      .update({ delivered_at: now })
      .eq("target_token_id", token.token_id)
      .in("command_id", ids);
  }
  await markRateSuccess(rate.eventId);
  return respond(req, { commands: data ?? [] });
}

async function acknowledgeCommand(req: Request, body: Json) {
  const token = await activeDeviceToken(req);
  if (!token) return respond(req, { error: "unauthorized" }, 401);
  const commandId = asString(body.commandId, 40);
  const result = asString(body.result, 20).toUpperCase();
  if (
    !/^[0-9a-f-]{36}$/i.test(commandId) ||
    !["APPLIED", "REJECTED"].includes(result)
  ) {
    return respond(req, { error: "invalid_command_ack" }, 400);
  }
  const { error } = await admin.from("wearable_outbound_commands")
    .update({
      acknowledged_at: new Date().toISOString(),
      result,
    })
    .eq("target_token_id", token.token_id)
    .eq("command_id", commandId)
    .is("acknowledged_at", null);
  if (error) throw error;
  return respond(req, { acknowledged: true });
}

async function activeDeviceToken(req: Request) {
  const credential = wearableCredential(req);
  if (!credential) return null;
  const { data, error } = await admin.from("wearable_device_tokens")
    .select("token_id,user_id,provider,expires_at,revoked_at")
    .eq("token_hash", await sha256(credential))
    .maybeSingle();
  if (error) throw error;
  if (!data || data.revoked_at || Date.parse(data.expires_at) <= Date.now()) {
    return null;
  }
  return data;
}

async function drainEvents(req: Request) {
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  const { data, error } = await admin.from("wearable_ingest_events")
    .select(
      "ingest_id,provider,external_event_id,match_id,event_type,event_at,payload",
    )
    .eq("user_id", user.id)
    .is("acknowledged_at", null)
    .order("ingest_id", { ascending: true })
    .limit(100);
  if (error) throw error;
  const ids = (data ?? []).map((row) => row.ingest_id);
  if (ids.length > 0) {
    await admin.from("wearable_ingest_events")
      .update({ delivered_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .in("ingest_id", ids);
  }
  return respond(req, { events: data ?? [] });
}

async function acknowledgeEvents(req: Request, body: Json) {
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  const ids = (Array.isArray(body.ingestIds) ? body.ingestIds : [])
    .map((value) => Number(value))
    .filter((value) => Number.isSafeInteger(value) && value > 0)
    .slice(0, 100);
  if (ids.length === 0) return respond(req, { error: "invalid_ids" }, 400);
  const { error } = await admin.from("wearable_ingest_events")
    .update({ acknowledged_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .in("ingest_id", ids);
  if (error) throw error;
  return respond(req, { acknowledged: ids.length });
}

async function disconnect(req: Request, body: Json) {
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  const provider = parseProvider(body.provider);
  if (!provider) return respond(req, { error: "invalid_provider" }, 400);
  const now = new Date().toISOString();
  const { error: tokenError } = await admin.from("wearable_device_tokens")
    .update({ revoked_at: now })
    .eq("user_id", user.id)
    .eq("provider", provider)
    .is("revoked_at", null);
  if (tokenError) throw tokenError;
  const { error: connectionError } = await admin.from(
    "wearable_provider_connections",
  )
    .update({ status: "REVOKED", revoked_at: now, updated_at: now })
    .eq("user_id", user.id)
    .eq("provider", provider);
  if (connectionError) throw connectionError;
  return respond(req, { disconnected: true });
}

async function authenticatedUser(req: Request) {
  const jwt = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  if (!jwt || jwt.startsWith("Wearable ")) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  return error ? null : data.user;
}

function hasWearableCloudAccess(userId: string) {
  return hasActiveEntitlement(admin, userId, ["plus", "pro", "coach"]);
}

function sanitizeEvent(
  value: unknown,
  userId: string,
  provider: string,
): Json | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const raw = value as Json;
  const externalId = asString(raw.eventId, 128);
  const matchId = asString(raw.matchId, 128);
  const eventType = asString(raw.type, 40).toUpperCase();
  const timestampMs = Number(raw.timestampMs);
  const now = Date.now();
  if (
    externalId.length < 8 || matchId.length < 3 ||
    !EVENT_TYPES.has(eventType) ||
    !Number.isSafeInteger(timestampMs) || timestampMs < now - 7 * 864e5 ||
    timestampMs > now + 5 * 60 * 1000
  ) return null;

  const sourceMethod = asString(raw.sourceMethod, 20).toUpperCase();
  // Lifecycle seals must not silently become TAP (would unseal MANUAL_EDIT).
  const lifecycleCritical = eventType === "MATCH_COMPLETED" ||
    eventType === "MATCH_STARTED" ||
    eventType === "MATCH_PAUSED" ||
    eventType === "MATCH_RESUMED";
  if (lifecycleCritical && sourceMethod && !SOURCE_METHODS.has(sourceMethod)) {
    return null;
  }
  const payload: Json = {
    sourceMethod: SOURCE_METHODS.has(sourceMethod)
      ? sourceMethod
      : (lifecycleCritical ? "AUTO" : "TAP"),
  };
  const teamId = asString(raw.teamId, 20).toUpperCase();
  if (["TEAM_A", "TEAM_B"].includes(teamId)) payload.teamId = teamId;
  const format = asString(raw.format, 3000);
  if (format) payload.format = format;
  const sequence = Number(raw.sequence);
  if (Number.isSafeInteger(sequence) && sequence >= 0) {
    payload.sequence = sequence;
  }
  const targetEventId = asString(raw.targetEventId, 128);
  if (eventType === "UNDO" && targetEventId.length >= 8) {
    payload.targetEventId = targetEventId;
  }

  return {
    user_id: userId,
    provider,
    external_event_id: externalId,
    match_id: matchId,
    event_type: eventType,
    event_at: new Date(timestampMs).toISOString(),
    payload,
  };
}

function sanitizeStartMatch(value: unknown): Json | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const raw = value as Json;
  const matchId = asString(raw.matchId, 128);
  const format = raw.format;
  if (
    matchId.length < 3 || !format || typeof format !== "object" ||
    Array.isArray(format)
  ) return null;
  const formatRow = format as Json;
  const formatId = asString(formatRow.id, 40);
  const setsToWin = Number(formatRow.setsToWin);
  const gamesPerSet = Number(formatRow.gamesPerSet);
  const tieBreakPoints = Number(formatRow.tieBreakPoints);
  const superTieBreakPoints = Number(formatRow.superTieBreakPoints);
  const requestedScoringMode = asString(
    formatRow.gameScoringMode,
    32,
  ).toUpperCase();
  const supportedScoringModes = new Set([
    "ADVANTAGE",
    "STAR_POINT",
    "GOLDEN_POINT",
  ]);
  if (
    requestedScoringMode &&
    !supportedScoringModes.has(requestedScoringMode)
  ) return null;
  if (
    formatRow.goldenPoint !== undefined &&
    typeof formatRow.goldenPoint !== "boolean"
  ) return null;
  const gameScoringMode = requestedScoringMode ||
    (formatRow.goldenPoint === false ? "ADVANTAGE" : "GOLDEN_POINT");
  const hasFormatSchemaVersion = formatRow.formatSchemaVersion !== undefined &&
    formatRow.formatSchemaVersion !== null;
  const requestedFormatSchemaVersion = Number(formatRow.formatSchemaVersion);
  if (
    hasFormatSchemaVersion &&
    (!Number.isSafeInteger(requestedFormatSchemaVersion) ||
      requestedFormatSchemaVersion < 1 ||
      requestedFormatSchemaVersion > 2)
  ) return null;
  const formatSchemaVersion = hasFormatSchemaVersion
    ? requestedFormatSchemaVersion
    : (requestedScoringMode ? 2 : 1);
  if (
    (formatSchemaVersion >= 2 && !requestedScoringMode) ||
    (formatSchemaVersion < 2 && requestedScoringMode)
  ) return null;
  if (
    !formatId || !Number.isSafeInteger(setsToWin) || setsToWin < 1 ||
    setsToWin > 3 || !Number.isSafeInteger(gamesPerSet) || gamesPerSet < 1 ||
    gamesPerSet > 9 || !Number.isSafeInteger(tieBreakPoints) ||
    tieBreakPoints < 1 || tieBreakPoints > 21 ||
    !Number.isSafeInteger(superTieBreakPoints) || superTieBreakPoints < 1 ||
    superTieBreakPoints > 21
  ) return null;
  const assignedTeam = asString(raw.assignedTeam, 20).toUpperCase();
  if (assignedTeam && !["TEAM_A", "TEAM_B"].includes(assignedTeam)) {
    return null;
  }
  return {
    matchId,
    format: {
      id: formatId,
      name: asString(formatRow.name, 80) || "Momentum",
      // Every accepted legacy payload is upgraded at the trust boundary.
      // Emitting v1 together with the v2 discriminator would be ambiguous
      // for older readers, even when the selected mode is equivalent.
      formatSchemaVersion: 2,
      setsToWin,
      gamesPerSet,
      gameScoringMode,
      // Legacy readers still consume this field. Star Point deliberately
      // degrades to advantages instead of closing the game too early.
      goldenPoint: gameScoringMode === "GOLDEN_POINT",
      tieBreakAtGamesAll: formatRow.tieBreakAtGamesAll !== false,
      tieBreakPoints,
      superTieBreakDecider: formatRow.superTieBreakDecider === true,
      superTieBreakPoints,
      freePlay: formatRow.freePlay === true,
    },
    assignedTeam: assignedTeam || null,
    teamName: asString(raw.teamName, 60),
  };
}

// RESUME_MATCH = START_MATCH + the full phone journal. The whole command is
// rejected when any event is invalid: a partial journal would replay to a
// wrong score on the watch.
function sanitizeResumeMatch(value: unknown): Json | null {
  const base = sanitizeStartMatch(value);
  if (!base) return null;
  const raw = value as Json;
  const input = Array.isArray(raw.events) ? raw.events : [];
  if (input.length === 0 || input.length > MAX_RESUME_EVENTS) return null;
  const events = input
    .map((entry) => sanitizeResumeEvent(entry))
    .filter((entry): entry is Json => entry !== null);
  if (events.length !== input.length) return null;
  return { ...base, events, eventCount: events.length };
}

function sanitizeResumeEvent(value: unknown): Json | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const raw = value as Json;
  const eventId = asString(raw.eventId, 128);
  const eventType = asString(raw.type, 40).toUpperCase();
  const timestampMs = Number(raw.timestampMs);
  const now = Date.now();
  // Paused matches age: accept up to 30 days in the past (vs 7 for ingest).
  if (
    eventId.length < 8 || !EVENT_TYPES.has(eventType) ||
    !Number.isSafeInteger(timestampMs) ||
    timestampMs < now - 30 * 864e5 ||
    timestampMs > now + 5 * 60 * 1000
  ) return null;
  const sourceMethod = asString(raw.sourceMethod, 20).toUpperCase();
  const lifecycleCritical = eventType === "MATCH_COMPLETED" ||
    eventType === "MATCH_STARTED" ||
    eventType === "MATCH_PAUSED" ||
    eventType === "MATCH_RESUMED";
  if (lifecycleCritical && sourceMethod && !SOURCE_METHODS.has(sourceMethod)) {
    return null;
  }
  const event: Json = {
    eventId,
    type: eventType,
    timestampMs,
    sourceMethod: SOURCE_METHODS.has(sourceMethod)
      ? sourceMethod
      : (lifecycleCritical ? "AUTO" : "TAP"),
  };
  const teamId = asString(raw.teamId, 20).toUpperCase();
  if (["TEAM_A", "TEAM_B"].includes(teamId)) {
    event.teamId = teamId;
  } else if (eventType === "POINT_TEAM_A" || eventType === "POINT_TEAM_B") {
    // The watch engine ignores team-less points: reject instead of skewing.
    return null;
  }
  const sequence = Number(raw.sequence);
  if (Number.isSafeInteger(sequence) && sequence >= 0) {
    event.sequence = sequence;
  }
  const targetEventId = asString(raw.targetEventId, 128);
  if (eventType === "UNDO") {
    if (targetEventId.length < 8) return null;
    event.targetEventId = targetEventId;
  }
  return event;
}

async function beginRateEvent(
  actorHash: string,
  action: "CLAIM" | "INGEST" | "PULL",
  limit: number,
  windowMs: number,
) {
  const since = new Date(Date.now() - windowMs).toISOString();
  const { count, error } = await admin.from("wearable_gateway_rate_events")
    .select("event_id", { count: "exact", head: true })
    .eq("actor_hash", actorHash)
    .eq("action", action)
    .gte("created_at", since);
  if (error) throw error;
  if ((count ?? 0) >= limit) return { allowed: false, eventId: 0 };
  const { data, error: insertError } = await admin
    .from("wearable_gateway_rate_events")
    .insert({ actor_hash: actorHash, action })
    .select("event_id")
    .single();
  if (insertError) throw insertError;
  return { allowed: true, eventId: data.event_id as number };
}

async function markRateSuccess(eventId: number) {
  if (eventId <= 0) return;
  await admin.from("wearable_gateway_rate_events")
    .update({ success: true })
    .eq("event_id", eventId);
}

async function requestActorHash(req: Request, context: string) {
  const ip = req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(RATE_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const value = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${context}|${ip}`),
  );
  return hex(new Uint8Array(value));
}

async function readJson(req: Request): Promise<Json | null> {
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_BODY_BYTES) return null;
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) return null;
  try {
    const value = JSON.parse(text);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Json
      : null;
  } catch {
    return null;
  }
}

function parseProvider(value: unknown): Provider | null {
  const provider = asString(value, 32).toUpperCase();
  return PROVIDERS.includes(provider as Provider) ? provider as Provider : null;
}

function wearableCredential(req: Request) {
  const value = req.headers.get("authorization") ?? "";
  const match = /^Wearable\s+([A-Za-z0-9_-]{32,256})$/i.exec(value);
  return match?.[1] ?? null;
}

function asString(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function stringList(value: unknown, maxItems: number, maxLength: number) {
  if (!Array.isArray(value)) return [];
  return [
    ...new Set(value.map((item) => asString(item, maxLength)).filter(Boolean)),
  ]
    .slice(0, maxItems);
}

function randomCode(length: number): string {
  const bytes = new Uint8Array(length * 2);
  crypto.getRandomValues(bytes);
  let value = "";
  for (const byte of bytes) {
    if (byte >= Math.floor(256 / CODE_ALPHABET.length) * CODE_ALPHABET.length) {
      continue;
    }
    value += CODE_ALPHABET[byte % CODE_ALPHABET.length];
    if (value.length === length) break;
  }
  return value.length === length ? value : randomCode(length);
}

function randomToken(size: number) {
  const bytes = new Uint8Array(size);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return hex(new Uint8Array(digest));
}

function hex(bytes: Uint8Array) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function safeError(error: unknown) {
  return error instanceof Error ? error.message.slice(0, 300) : "unknown";
}

function respond(req: Request, body: unknown, status = 200) {
  return cors(
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
      },
    }),
    req,
  );
}

function cors(response: Response, req: Request) {
  const configured = (Deno.env.get("RALLYMATE_ALLOWED_ORIGINS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean);
  const origin = req.headers.get("origin");
  if (origin && configured.includes(origin)) {
    response.headers.set("access-control-allow-origin", origin);
    response.headers.set("vary", "origin");
  }
  response.headers.set(
    "access-control-allow-headers",
    "authorization, content-type",
  );
  response.headers.set("access-control-allow-methods", "POST, OPTIONS");
  return response;
}
