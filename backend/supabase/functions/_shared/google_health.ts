import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  decryptProviderToken,
  encryptProviderToken,
  requiredEnv,
  sha256,
} from "./provider_security.ts";

export { requiredEnv, sha256 } from "./provider_security.ts";

export const GOOGLE_HEALTH_PROVIDER = "GOOGLE_HEALTH";
export const GOOGLE_HEALTH_SCOPES = [
  "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
  "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
];

const HEALTH_API = "https://health.googleapis.com/v4";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

type AdminClient = SupabaseClient;
type TokenResponse = {
  access_token: string;
  expires_in: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
};
type StoredConnection = {
  access_token_ciphertext: string | null;
  access_token_iv: string | null;
  refresh_token_ciphertext: string | null;
  refresh_token_iv: string | null;
  token_expires_at: string | null;
  scopes: string[];
  status: string;
};

export async function saveGoogleTokens(
  admin: AdminClient,
  userId: string,
  tokens: TokenResponse,
  providerSubject: string,
) {
  const access = await encryptProviderToken(
    tokens.access_token,
    userId,
    GOOGLE_HEALTH_PROVIDER,
    "access",
  );
  const refresh = tokens.refresh_token
    ? await encryptProviderToken(
      tokens.refresh_token,
      userId,
      GOOGLE_HEALTH_PROVIDER,
      "refresh",
    )
    : null;
  const expiresAt = new Date(
    Date.now() + Math.max(60, Number(tokens.expires_in) || 3600) * 1000,
  ).toISOString();
  const scopes = (tokens.scope ?? GOOGLE_HEALTH_SCOPES.join(" "))
    .split(/\s+/).filter(Boolean);
  const row: Record<string, unknown> = {
    user_id: userId,
    provider: GOOGLE_HEALTH_PROVIDER,
    status: "CONNECTED",
    provider_subject_hash: await sha256(providerSubject),
    access_token_ciphertext: access.ciphertext,
    access_token_iv: access.iv,
    token_expires_at: expiresAt,
    scopes,
    consented_at: new Date().toISOString(),
    revoked_at: null,
    last_error_code: null,
    updated_at: new Date().toISOString(),
  };
  if (refresh) {
    row.refresh_token_ciphertext = refresh.ciphertext;
    row.refresh_token_iv = refresh.iv;
  }
  const { error } = await admin.from("wearable_provider_connections")
    .upsert(row, { onConflict: "user_id,provider" });
  if (error) throw error;
}

export async function validAccessToken(admin: AdminClient, userId: string) {
  const { data, error } = await admin.from("wearable_provider_connections")
    .select(
      "access_token_ciphertext,access_token_iv,refresh_token_ciphertext," +
        "refresh_token_iv,token_expires_at,scopes,status",
    )
    .eq("user_id", userId)
    .eq("provider", GOOGLE_HEALTH_PROVIDER)
    .maybeSingle();
  if (error) throw error;
  const connection = data as StoredConnection | null;
  if (!connection || connection.status !== "CONNECTED") {
    throw new Error("google_health_not_connected");
  }
  if (
    connection.access_token_ciphertext && connection.access_token_iv &&
    Date.parse(connection.token_expires_at ?? "") > Date.now() + 90_000
  ) {
    return decryptProviderToken(
      connection.access_token_ciphertext,
      connection.access_token_iv,
      userId,
      GOOGLE_HEALTH_PROVIDER,
      "access",
    );
  }
  if (!connection.refresh_token_ciphertext || !connection.refresh_token_iv) {
    await markRefreshRequired(admin, userId, "missing_refresh_token");
    throw new Error("google_health_reconnect_required");
  }

  const refreshToken = await decryptProviderToken(
    connection.refresh_token_ciphertext,
    connection.refresh_token_iv,
    userId,
    GOOGLE_HEALTH_PROVIDER,
    "refresh",
  );
  const params = new URLSearchParams({
    client_id: requiredEnv("GOOGLE_HEALTH_CLIENT_ID"),
    client_secret: requiredEnv("GOOGLE_HEALTH_CLIENT_SECRET"),
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  });
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });
  const value = await response.json().catch(() => ({})) as Partial<
    TokenResponse
  >;
  if (!response.ok || !value.access_token) {
    await markRefreshRequired(admin, userId, `refresh_${response.status}`);
    throw new Error("google_health_reconnect_required");
  }
  const encrypted = await encryptProviderToken(
    value.access_token,
    userId,
    GOOGLE_HEALTH_PROVIDER,
    "access",
  );
  const expiresAt = new Date(
    Date.now() + Math.max(60, Number(value.expires_in) || 3600) * 1000,
  ).toISOString();
  // Google may rotate the refresh token on a refresh. Dropping the new one
  // leaves the stored (now invalid) token behind, and the next refresh fails
  // with reconnect_required — the user is silently disconnected.
  const rotatedRefresh = typeof value.refresh_token === "string" &&
      value.refresh_token.length > 0
    ? await encryptProviderToken(
      value.refresh_token,
      userId,
      GOOGLE_HEALTH_PROVIDER,
      "refresh",
    )
    : null;
  const update: Record<string, unknown> = {
    access_token_ciphertext: encrypted.ciphertext,
    access_token_iv: encrypted.iv,
    token_expires_at: expiresAt,
    status: "CONNECTED",
    last_error_code: null,
    updated_at: new Date().toISOString(),
  };
  if (rotatedRefresh) {
    update.refresh_token_ciphertext = rotatedRefresh.ciphertext;
    update.refresh_token_iv = rotatedRefresh.iv;
  }
  const { error: updateError } = await admin.from(
    "wearable_provider_connections",
  )
    .update(update)
    .eq("user_id", userId)
    .eq("provider", GOOGLE_HEALTH_PROVIDER);
  if (updateError) throw updateError;
  return value.access_token;
}

export async function fetchAndStoreDailySummary(
  admin: AdminClient,
  userId: string,
  localDate: string,
  timezone: string,
) {
  const parts = parseDate(localDate);
  if (!parts) throw new Error("invalid_local_date");
  const token = await validAccessToken(admin, userId);
  const range = dailyRange(parts);
  const dataTypes = [
    "steps",
    "active-energy-burned",
    "active-minutes",
    "heart-rate",
  ];
  const responses = await Promise.all(dataTypes.map(async (dataType) => {
    const response = await fetch(
      `${HEALTH_API}/users/me/dataTypes/${dataType}/dataPoints:dailyRollUp`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          accept: "application/json",
          "content-type": "application/json",
        },
        body: JSON.stringify({ range, windowSizeDays: 1, pageSize: 1 }),
      },
    );
    if (response.status === 403 && dataType === "heart-rate") return null;
    if (!response.ok) {
      throw new Error(`google_health_${dataType}_${response.status}`);
    }
    const value = await response.json() as Record<string, unknown>;
    const points = Array.isArray(value.rollupDataPoints)
      ? value.rollupDataPoints as Record<string, unknown>[]
      : [];
    return points[0] ?? null;
  }));

  const [stepsPoint, energyPoint, minutesPoint, heartPoint] = responses;
  const steps = integerAt(stepsPoint, ["steps", "countSum"]);
  const activeEnergy = numberAt(energyPoint, ["activeEnergyBurned", "kcalSum"]);
  const minutesRows = nestedArray(minutesPoint, [
    "activeMinutes",
    "activeMinutesRollupByActivityLevel",
  ]);
  const exerciseMinutes = minutesRows.reduce(
    (sum, row) => sum + integerAt(row, ["activeMinutesSum"]),
    0,
  );
  const averageHeartRate = nullableNumberAt(heartPoint, [
    "heartRate",
    "beatsPerMinuteAvg",
  ]);
  const summary = {
    user_id: userId,
    provider: GOOGLE_HEALTH_PROVIDER,
    local_date: localDate,
    timezone: timezone.slice(0, 80),
    steps,
    active_energy_kcal: activeEnergy,
    exercise_minutes: exerciseMinutes,
    average_heart_rate_bpm: averageHeartRate,
    source_updated_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  const { error } = await admin.from("wearable_daily_health_summaries")
    .upsert(summary, { onConflict: "user_id,provider,local_date" });
  if (error) throw error;
  const retentionStart = new Date(
    Date.UTC(parts.year, parts.month - 1, parts.day) - 29 * 864e5,
  ).toISOString().slice(0, 10);
  await admin.from("wearable_daily_health_summaries")
    .delete()
    .eq("user_id", userId)
    .eq("provider", GOOGLE_HEALTH_PROVIDER)
    .lt("local_date", retentionStart);
  await admin.from("wearable_provider_connections")
    .update({
      last_sync_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId)
    .eq("provider", GOOGLE_HEALTH_PROVIDER);
  return summary;
}

export async function exchangeAuthorizationCode(code: string) {
  const params = new URLSearchParams({
    client_id: requiredEnv("GOOGLE_HEALTH_CLIENT_ID"),
    client_secret: requiredEnv("GOOGLE_HEALTH_CLIENT_SECRET"),
    redirect_uri: requiredEnv("GOOGLE_HEALTH_REDIRECT_URI"),
    code,
    grant_type: "authorization_code",
  });
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });
  const value = await response.json().catch(() => ({})) as Partial<
    TokenResponse
  >;
  if (!response.ok || !value.access_token || !value.expires_in) {
    throw new Error(`google_oauth_exchange_${response.status}`);
  }
  return value as TokenResponse;
}

export async function googleHealthIdentity(accessToken: string) {
  const response = await fetch(`${HEALTH_API}/users/me/identity`, {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });
  if (!response.ok) {
    throw new Error(`google_health_identity_${response.status}`);
  }
  const value = await response.json() as Record<string, unknown>;
  const id = typeof value.healthUserId === "string" ? value.healthUserId : "";
  if (!id) throw new Error("google_health_identity_missing");
  return id;
}

export async function revokeGoogleHealth(admin: AdminClient, userId: string) {
  let token: string | null = null;
  try {
    token = await validAccessToken(admin, userId);
  } catch {
    // Local revocation still completes if Google already invalidated consent.
  }
  if (token) {
    await fetch(
      `https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(token)}`,
      {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
      },
    ).catch(() => null);
  }
  const now = new Date().toISOString();
  const { error } = await admin.from("wearable_provider_connections").update({
    status: "REVOKED",
    access_token_ciphertext: null,
    access_token_iv: null,
    refresh_token_ciphertext: null,
    refresh_token_iv: null,
    token_expires_at: null,
    revoked_at: now,
    updated_at: now,
  }).eq("user_id", userId).eq("provider", GOOGLE_HEALTH_PROVIDER);
  if (error) throw error;
  await admin.from("wearable_daily_health_summaries")
    .delete().eq("user_id", userId).eq("provider", GOOGLE_HEALTH_PROVIDER);
}

async function markRefreshRequired(
  admin: AdminClient,
  userId: string,
  code: string,
) {
  await admin.from("wearable_provider_connections").update({
    status: "REFRESH_REQUIRED",
    last_error_code: code.slice(0, 80),
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId).eq("provider", GOOGLE_HEALTH_PROVIDER);
}

export function parseDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;
  return { year, month, day };
}

export function dailyRange(start: {
  year: number;
  month: number;
  day: number;
}) {
  const next = new Date(
    Date.UTC(start.year, start.month - 1, start.day) + 864e5,
  );
  const time = { hours: 0, minutes: 0, seconds: 0, nanos: 0 };
  return {
    start: { date: start, time },
    end: {
      date: {
        year: next.getUTCFullYear(),
        month: next.getUTCMonth() + 1,
        day: next.getUTCDate(),
      },
      time,
    },
  };
}

function nestedValue(value: Record<string, unknown> | null, path: string[]) {
  let current: unknown = value;
  for (const key of path) {
    if (!current || typeof current !== "object" || Array.isArray(current)) {
      return null;
    }
    current = (current as Record<string, unknown>)[key];
  }
  return current;
}

function integerAt(value: Record<string, unknown> | null, path: string[]) {
  const parsed = Number(nestedValue(value, path) ?? 0);
  return Number.isFinite(parsed) ? Math.max(0, Math.round(parsed)) : 0;
}

function numberAt(value: Record<string, unknown> | null, path: string[]) {
  const parsed = Number(nestedValue(value, path) ?? 0);
  return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
}

function nullableNumberAt(
  value: Record<string, unknown> | null,
  path: string[],
) {
  const raw = nestedValue(value, path);
  if (raw === null || raw === undefined) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function nestedArray(value: Record<string, unknown> | null, path: string[]) {
  const rows = nestedValue(value, path);
  return Array.isArray(rows)
    ? rows.filter((row): row is Record<string, unknown> =>
      Boolean(row && typeof row === "object" && !Array.isArray(row))
    )
    : [];
}
