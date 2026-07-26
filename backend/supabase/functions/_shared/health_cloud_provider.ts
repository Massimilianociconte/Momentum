import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  decryptProviderToken,
  encryptProviderToken,
  randomToken,
  requiredEnv,
  sha256,
} from "./provider_security.ts";

export type DirectHealthProvider = "OURA_DIRECT" | "WHOOP_DIRECT";

export type CloudMetric = {
  externalId: string;
  metricType:
    | "WORKOUT"
    | "HEART_RATE"
    | "ACTIVE_ENERGY"
    | "TOTAL_ENERGY"
    | "STEPS"
    | "EXERCISE_MINUTES"
    | "DISTANCE"
    | "HRV"
    | "SLEEP"
    | "SLEEP_SCORE"
    | "READINESS"
    | "RECOVERY"
    | "STRAIN"
    | "RESTING_HEART_RATE";
  startTime: string;
  endTime: string;
  value: number;
  unit: string;
  aggregationScope: "DAILY" | "WORKOUT" | "MATCH" | "RECOVERY";
  metadata?: Record<string, string | number | boolean | null>;
};

type AdminClient = SupabaseClient;
type TokenResponse = {
  access_token: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
};
type StoredConnection = {
  connection_id: string;
  access_token_ciphertext: string | null;
  access_token_iv: string | null;
  refresh_token_ciphertext: string | null;
  refresh_token_iv: string | null;
  token_expires_at: string | null;
  refresh_lock_id: string | null;
  refresh_lock_expires_at: string | null;
  scopes: string[];
  status: string;
};

const configs = {
  OURA_DIRECT: {
    clientIdEnv: "OURA_CLIENT_ID",
    clientSecretEnv: "OURA_CLIENT_SECRET",
    redirectUriEnv: "OURA_REDIRECT_URI",
    authorizeUrl: "https://cloud.ouraring.com/oauth/authorize",
    tokenUrl: "https://api.ouraring.com/oauth/token",
    revokeUrl: "https://api.ouraring.com/oauth/revoke",
    // Direct Oura access is reserved for provider-specific recovery metrics.
    // Workouts already flow through HealthKit/Health Connect, so requesting
    // that scope would add duplicate data and unnecessary consent surface.
    scopes: ["daily"],
    sourceName: "Oura Cloud",
    sourceBundleId: "cloud.ouraring.com",
  },
  WHOOP_DIRECT: {
    clientIdEnv: "WHOOP_CLIENT_ID",
    clientSecretEnv: "WHOOP_CLIENT_SECRET",
    redirectUriEnv: "WHOOP_REDIRECT_URI",
    authorizeUrl: "https://api.prod.whoop.com/oauth/oauth2/auth",
    tokenUrl: "https://api.prod.whoop.com/oauth/oauth2/token",
    revokeUrl: "https://api.prod.whoop.com/developer/v2/user/access",
    scopes: [
      "offline",
      "read:recovery",
      "read:cycles",
      "read:workout",
      "read:sleep",
      "read:profile",
    ],
    sourceName: "WHOOP Cloud",
    sourceBundleId: "developer.whoop.com",
  },
} as const;

export function providerConfig(provider: DirectHealthProvider) {
  return configs[provider];
}

export async function assertProviderRollout(
  admin: AdminClient,
  provider: DirectHealthProvider,
) {
  const { data, error } = await admin.from("health_provider_features")
    .select("rollout,support_status,capabilities")
    .eq("provider", provider)
    .maybeSingle();
  if (error) throw error;
  if (!data || data.rollout === "DISABLED") {
    throw new Error("provider_not_enabled");
  }
  return data as {
    rollout: "INTERNAL" | "BETA" | "PRODUCTION";
    support_status: string;
    capabilities: string[];
  };
}

export function buildAuthorizationUrl(
  provider: DirectHealthProvider,
  state: string,
) {
  const config = configs[provider];
  const query = new URLSearchParams({
    client_id: requiredEnv(config.clientIdEnv),
    redirect_uri: requiredEnv(config.redirectUriEnv),
    response_type: "code",
    scope: config.scopes.join(" "),
    state,
  });
  return `${config.authorizeUrl}?${query}`;
}

export async function exchangeAuthorizationCode(
  provider: DirectHealthProvider,
  code: string,
) {
  const config = configs[provider];
  return await tokenRequest(
    provider,
    new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: requiredEnv(config.clientIdEnv),
      client_secret: requiredEnv(config.clientSecretEnv),
      redirect_uri: requiredEnv(config.redirectUriEnv),
    }),
  );
}

export async function saveProviderTokens(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
  tokens: TokenResponse,
  providerSubject?: string,
) {
  const access = await encryptProviderToken(
    tokens.access_token,
    userId,
    provider,
    "access",
  );
  const refresh = tokens.refresh_token
    ? await encryptProviderToken(
      tokens.refresh_token,
      userId,
      provider,
      "refresh",
    )
    : null;
  const config = configs[provider];
  const row: Record<string, unknown> = {
    user_id: userId,
    provider,
    status: "CONNECTED",
    connection_type: "CLOUD_OAUTH",
    support_status: "INTERNAL",
    access_token_ciphertext: access.ciphertext,
    access_token_iv: access.iv,
    token_expires_at: new Date(
      Date.now() + Math.max(60, Number(tokens.expires_in) || 3600) * 1000,
    ).toISOString(),
    scopes: (tokens.scope ?? config.scopes.join(" ")).split(/\s+/)
      .filter(Boolean),
    consented_at: new Date().toISOString(),
    revoked_at: null,
    last_error_code: null,
    refresh_lock_id: null,
    refresh_lock_expires_at: null,
    updated_at: new Date().toISOString(),
  };
  if (providerSubject) {
    row.provider_subject_hash = await sha256(providerSubject);
  }
  if (refresh) {
    row.refresh_token_ciphertext = refresh.ciphertext;
    row.refresh_token_iv = refresh.iv;
  }
  const { error } = await admin.from("wearable_provider_connections")
    .upsert(row, { onConflict: "user_id,provider" });
  if (error) throw error;
}

export async function validProviderAccessToken(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
  waitAttempt = 0,
): Promise<string> {
  const connection = await readConnection(admin, userId, provider);
  if (!connection || connection.status !== "CONNECTED") {
    throw new Error("provider_not_connected");
  }
  if (
    connection.access_token_ciphertext && connection.access_token_iv &&
    Date.parse(connection.token_expires_at ?? "") > Date.now() + 90_000
  ) {
    return decryptProviderToken(
      connection.access_token_ciphertext,
      connection.access_token_iv,
      userId,
      provider,
      "access",
    );
  }
  if (!connection.refresh_token_ciphertext || !connection.refresh_token_iv) {
    await markReconnectRequired(admin, userId, provider, "missing_refresh");
    throw new Error("provider_reconnect_required");
  }

  const lockId = crypto.randomUUID();
  const now = new Date().toISOString();
  const lockExpiresAt = new Date(Date.now() + 20_000).toISOString();
  const { data: claimed, error: claimError } = await admin
    .from("wearable_provider_connections")
    .update({
      refresh_lock_id: lockId,
      refresh_lock_expires_at: lockExpiresAt,
      updated_at: now,
    })
    .eq("connection_id", connection.connection_id)
    .eq("refresh_token_ciphertext", connection.refresh_token_ciphertext)
    .or(`refresh_lock_expires_at.is.null,refresh_lock_expires_at.lt.${now}`)
    .select("connection_id")
    .maybeSingle();
  if (claimError) throw claimError;
  if (!claimed) {
    if (waitAttempt >= 8) throw new Error("provider_refresh_busy");
    await delay(250 + waitAttempt * 100);
    return validProviderAccessToken(
      admin,
      userId,
      provider,
      waitAttempt + 1,
    );
  }

  try {
    const refreshToken = await decryptProviderToken(
      connection.refresh_token_ciphertext,
      connection.refresh_token_iv,
      userId,
      provider,
      "refresh",
    );
    const config = configs[provider];
    const tokens = await tokenRequest(
      provider,
      new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: refreshToken,
        client_id: requiredEnv(config.clientIdEnv),
        client_secret: requiredEnv(config.clientSecretEnv),
      }),
    );
    await saveProviderTokens(admin, userId, provider, tokens);
    return tokens.access_token;
  } catch (error) {
    const code = error instanceof Error ? error.message : "refresh_failed";
    const isTransient = code.includes("429") || code.includes("500") ||
      code.includes("502") || code.includes("503") || code.includes("timeout");
    if (isTransient) {
      await releaseRefreshLock(admin, userId, provider, lockId);
    } else {
      await markReconnectRequired(admin, userId, provider, code.slice(0, 80));
    }
    throw error;
  }
}

export async function fetchProviderJson(
  url: string,
  accessToken: string,
  init: RequestInit = {},
) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12_000);
    try {
      const response = await fetch(url, {
        ...init,
        signal: controller.signal,
        headers: {
          accept: "application/json",
          authorization: `Bearer ${accessToken}`,
          ...(init.headers ?? {}),
        },
      });
      if (response.status === 429 && attempt === 0) {
        const retrySeconds = Math.min(
          3,
          Math.max(1, Number(response.headers.get("retry-after")) || 1),
        );
        await delay(retrySeconds * 1000);
        continue;
      }
      const value = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(`provider_http_${response.status}`);
      return value as Record<string, unknown>;
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new Error("provider_http_429");
}

export async function persistCloudMetrics(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
  metrics: CloudMetric[],
) {
  if (metrics.length > 1000) throw new Error("provider_metric_batch_too_large");
  const connection = await readConnection(admin, userId, provider);
  if (!connection) throw new Error("provider_not_connected");
  const config = configs[provider];
  const sourceId = await deterministicUuid(
    `${userId}|${provider}|${config.sourceBundleId}`,
  );
  const availableMetrics = [...new Set(metrics.map((row) => row.metricType))];
  const { error: sourceError } = await admin.from("health_data_sources")
    .upsert({
      source_id: sourceId,
      user_id: userId,
      provider,
      source_application: config.sourceName,
      source_bundle_id: config.sourceBundleId,
      source_device: "",
      source_model: "",
      connection_id: connection.connection_id,
      is_preferred: false,
      supports_live_data: false,
      available_metrics: availableMetrics,
      updated_at: new Date().toISOString(),
    }, {
      onConflict:
        "user_id,provider,source_bundle_id,source_device,source_model",
    });
  if (sourceError) throw sourceError;

  const rows = await Promise.all(metrics.map(async (metric) => ({
    user_id: userId,
    provider,
    source_id: sourceId,
    external_record_id: metric.externalId.slice(0, 200),
    metric_type: metric.metricType,
    start_time: metric.startTime,
    end_time: metric.endTime,
    value: finite(metric.value),
    unit: metric.unit.slice(0, 24),
    aggregation_scope: metric.aggregationScope,
    metadata: metric.metadata ?? {},
    content_hash: await sha256(
      `${provider}|${metric.externalId}|${metric.metricType}`,
    ),
    sync_version: 1,
    updated_at: new Date().toISOString(),
  })));
  for (let start = 0; start < rows.length; start += 200) {
    const { error } = await admin.from("health_metric_records")
      .upsert(rows.slice(start, start + 200), {
        onConflict: "user_id,content_hash",
      });
    if (error) throw error;
  }
  const { error: syncStateError } = await admin.from(
    "wearable_provider_connections",
  ).update({
    last_sync_at: new Date().toISOString(),
    last_error_code: null,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("provider", provider);
  if (syncStateError) throw syncStateError;
  return { imported: rows.length, sourceId };
}

export async function disconnectProvider(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
) {
  const connection = await readConnection(admin, userId, provider);
  if (connection?.access_token_ciphertext && connection.access_token_iv) {
    try {
      const token = await decryptProviderToken(
        connection.access_token_ciphertext,
        connection.access_token_iv,
        userId,
        provider,
        "access",
      );
      const config = configs[provider];
      if (provider === "OURA_DIRECT") {
        await fetchWithTimeout(
          `${config.revokeUrl}?access_token=${encodeURIComponent(token)}`,
        );
      } else {
        await fetchWithTimeout(config.revokeUrl, {
          method: "DELETE",
          headers: { authorization: `Bearer ${token}` },
        });
      }
    } catch {
      // Local revocation and deletion must still complete if the provider is
      // unavailable or the token was already revoked.
    }
  }
  const { error } = await admin.from("wearable_provider_connections").update({
    status: "REVOKED",
    access_token_ciphertext: null,
    access_token_iv: null,
    refresh_token_ciphertext: null,
    refresh_token_iv: null,
    token_expires_at: null,
    refresh_lock_id: null,
    refresh_lock_expires_at: null,
    revoked_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("provider", provider);
  if (error) throw error;
  const { data: sources, error: sourceLookupError } = await admin
    .from("health_data_sources")
    .select("source_id")
    .eq("user_id", userId)
    .eq("provider", provider);
  if (sourceLookupError) throw sourceLookupError;
  const sourceIds = (sources ?? []).map((row) => row.source_id as string);
  if (sourceIds.length > 0) {
    const { error: summaryError } = await admin
      .from("match_health_summaries")
      .delete()
      .eq("user_id", userId)
      .in("primary_source_id", sourceIds);
    if (summaryError) throw summaryError;
  }
  const { error: metricError } = await admin.from("health_metric_records")
    .delete()
    .eq("user_id", userId).eq("provider", provider);
  if (metricError) throw metricError;
  const { error: sourceError } = await admin.from("health_data_sources")
    .delete()
    .eq("user_id", userId).eq("provider", provider);
  if (sourceError) throw sourceError;
  const { error: jobError } = await admin.from("health_sync_jobs").delete()
    .eq("user_id", userId).eq("provider", provider);
  if (jobError) throw jobError;
}

export async function readProviderStatus(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
) {
  const rollout = await admin.from("health_provider_features")
    .select("rollout,support_status,capabilities")
    .eq("provider", provider).maybeSingle();
  if (rollout.error) throw rollout.error;
  const { data, error } = await admin.from("wearable_provider_connections")
    .select("status,scopes,consented_at,last_sync_at,last_error_code")
    .eq("user_id", userId).eq("provider", provider).maybeSingle();
  if (error) throw error;
  return {
    available: rollout.data?.rollout !== "DISABLED",
    rollout: rollout.data?.rollout ?? "DISABLED",
    supportStatus: rollout.data?.support_status ?? "RESEARCH",
    capabilities: rollout.data?.capabilities ?? [],
    connected: data?.status === "CONNECTED",
    status: data?.status ?? "DISCONNECTED",
    scopes: data?.scopes ?? [],
    consentedAt: data?.consented_at ?? null,
    lastSyncAt: data?.last_sync_at ?? null,
    needsReconnect: data?.status === "REFRESH_REQUIRED",
  };
}

export { randomToken, requiredEnv, sha256 };

async function tokenRequest(
  provider: DirectHealthProvider,
  params: URLSearchParams,
) {
  const response = await fetchWithTimeout(configs[provider].tokenUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });
  const value = await response.json().catch(() => ({})) as Partial<
    TokenResponse
  >;
  if (!response.ok || !value.access_token) {
    throw new Error(`provider_token_${response.status}`);
  }
  return value as TokenResponse;
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  timeoutMs = 12_000,
) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("provider_http_timeout");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function readConnection(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
) {
  const { data, error } = await admin.from("wearable_provider_connections")
    .select(
      "connection_id,access_token_ciphertext,access_token_iv," +
        "refresh_token_ciphertext,refresh_token_iv,token_expires_at," +
        "refresh_lock_id,refresh_lock_expires_at,scopes,status",
    )
    .eq("user_id", userId).eq("provider", provider).maybeSingle();
  if (error) throw error;
  return data as StoredConnection | null;
}

async function markReconnectRequired(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
  code: string,
) {
  const { error } = await admin.from("wearable_provider_connections").update({
    status: "REFRESH_REQUIRED",
    refresh_lock_id: null,
    refresh_lock_expires_at: null,
    last_error_code: code.slice(0, 100),
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("provider", provider);
  if (error) throw error;
}

async function releaseRefreshLock(
  admin: AdminClient,
  userId: string,
  provider: DirectHealthProvider,
  lockId: string,
) {
  await admin.from("wearable_provider_connections").update({
    refresh_lock_id: null,
    refresh_lock_expires_at: null,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("provider", provider)
    .eq("refresh_lock_id", lockId);
}

async function deterministicUuid(value: string) {
  const hash = await sha256(value);
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-` +
    `8${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
}

function finite(value: number) {
  if (!Number.isFinite(value)) throw new Error("invalid_metric_value");
  return Math.round(value * 10_000) / 10_000;
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
