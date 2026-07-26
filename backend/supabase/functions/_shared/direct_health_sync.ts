import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  type CloudMetric,
  fetchProviderJson,
  persistCloudMetrics,
  validProviderAccessToken,
} from "./health_cloud_provider.ts";

type AdminClient = SupabaseClient;
type Json = Record<string, unknown>;

export async function syncOuraRange(
  admin: AdminClient,
  userId: string,
  startDate: string,
  endDate: string,
) {
  const token = await validProviderAccessToken(
    admin,
    userId,
    "OURA_DIRECT",
  );
  const query = new URLSearchParams({
    start_date: startDate,
    end_date: endDate,
  });
  const [readiness, dailySleep, sleep] = await Promise.all([
    ouraCollection("daily_readiness", query, token),
    ouraCollection("daily_sleep", query, token),
    ouraCollection("sleep", query, token),
  ]);
  const metrics = [
    ...parseOuraDaily(readiness, "READINESS", "score"),
    ...parseOuraDaily(dailySleep, "SLEEP_SCORE", "score"),
    ...parseOuraSleep(sleep),
  ];
  return persistCloudMetrics(admin, userId, "OURA_DIRECT", metrics);
}

export async function syncWhoopRange(
  admin: AdminClient,
  userId: string,
  start: string,
  end: string,
) {
  const token = await validProviderAccessToken(
    admin,
    userId,
    "WHOOP_DIRECT",
  );
  const query = new URLSearchParams({
    start,
    end,
    limit: "25",
  });
  const [recoveries, sleeps, workouts, cycles] = await Promise.all([
    whoopCollection("recovery", query, token),
    whoopCollection("activity/sleep", query, token),
    whoopCollection("activity/workout", query, token),
    whoopCollection("cycle", query, token),
  ]);
  const metrics = [
    ...parseWhoopRecoveries(recoveries),
    ...parseWhoopSleeps(sleeps),
    ...parseWhoopWorkouts(workouts),
    ...parseWhoopCycles(cycles),
  ];
  return persistCloudMetrics(admin, userId, "WHOOP_DIRECT", metrics);
}

export async function syncWhoopResource(
  admin: AdminClient,
  userId: string,
  eventType: string,
  resourceId: string,
) {
  const supported = eventType.startsWith("workout.") ||
    eventType.startsWith("sleep.") || eventType.startsWith("recovery.");
  if (!supported) throw new Error("unsupported_webhook_type");
  if (eventType.endsWith(".deleted")) {
    await deleteProviderResource(admin, userId, resourceId);
    return { imported: 0, deleted: true };
  }
  const token = await validProviderAccessToken(
    admin,
    userId,
    "WHOOP_DIRECT",
  );
  let endpoint: string;
  let parser: (records: Json[]) => CloudMetric[];
  if (eventType.startsWith("workout.")) {
    endpoint = `activity/workout/${encodeURIComponent(resourceId)}`;
    parser = parseWhoopWorkouts;
  } else if (eventType.startsWith("sleep.")) {
    endpoint = `activity/sleep/${encodeURIComponent(resourceId)}`;
    parser = parseWhoopSleeps;
  } else if (eventType.startsWith("recovery.")) {
    // V2 recovery webhooks identify the related sleep UUID. The recovery
    // collection is bounded to the recent window and filtered by sleep_id.
    const end = new Date().toISOString();
    const start = new Date(Date.now() - 7 * 864e5).toISOString();
    const values = await whoopCollection(
      "recovery",
      new URLSearchParams({ start, end, limit: "25" }),
      token,
    );
    return persistCloudMetrics(
      admin,
      userId,
      "WHOOP_DIRECT",
      parseWhoopRecoveries(values.filter((row) => row.sleep_id === resourceId)),
    );
  } else {
    throw new Error("unsupported_webhook_type");
  }
  const value = await fetchProviderJson(
    `https://api.prod.whoop.com/developer/v2/${endpoint}`,
    token,
  );
  return persistCloudMetrics(
    admin,
    userId,
    "WHOOP_DIRECT",
    parser([value]),
  );
}

export async function whoopSubject(accessToken: string) {
  const profile = await fetchProviderJson(
    "https://api.prod.whoop.com/developer/v2/user/profile/basic",
    accessToken,
  );
  const id = profile.user_id;
  if (typeof id !== "number" && typeof id !== "string") {
    throw new Error("whoop_subject_missing");
  }
  // Name and email returned by this endpoint are intentionally discarded.
  return String(id);
}

async function ouraCollection(
  endpoint: string,
  query: URLSearchParams,
  token: string,
) {
  const value = await fetchProviderJson(
    `https://api.ouraring.com/v2/usercollection/${endpoint}?${query}`,
    token,
  );
  return records(value, "data");
}

async function whoopCollection(
  endpoint: string,
  query: URLSearchParams,
  token: string,
) {
  const result: Json[] = [];
  const seenTokens = new Set<string>();
  let nextToken = "";
  for (let page = 0; page < 8; page++) {
    const pageQuery = new URLSearchParams(query);
    if (nextToken) pageQuery.set("nextToken", nextToken);
    const value = await fetchProviderJson(
      `https://api.prod.whoop.com/developer/v2/${endpoint}?${pageQuery}`,
      token,
    );
    result.push(...records(value, "records"));
    const next = text(value.next_token, 512);
    if (!next) return result;
    if (seenTokens.has(next)) throw new Error("whoop_pagination_cycle");
    seenTokens.add(next);
    nextToken = next;
  }
  throw new Error("whoop_pagination_limit");
}

export function parseOuraDaily(
  rows: Json[],
  metricType: "READINESS" | "SLEEP_SCORE",
  field: string,
) {
  return rows.flatMap((row) => {
    const score = number(row[field]);
    const day = date(row.day);
    const id = text(row.id, 200);
    if (score === null || !day || !id) return [];
    return [metric({
      externalId: id,
      metricType,
      startTime: `${day}T00:00:00.000Z`,
      endTime: `${day}T23:59:59.999Z`,
      value: clamp(score, 0, 100),
      unit: "score",
      aggregationScope: "DAILY",
      metadata: { day },
    })];
  });
}

export function parseOuraSleep(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    const id = text(row.id, 200);
    const start = timestamp(row.bedtime_start);
    const end = timestamp(row.bedtime_end);
    if (!id || !start || !end || end < start) continue;
    const duration = number(row.total_sleep_duration);
    const hrv = number(row.average_hrv);
    const heartRate = number(row.average_heart_rate);
    if (duration !== null && duration >= 0) {
      result.push(metric({
        externalId: id,
        metricType: "SLEEP",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: Math.min(duration, 86_400),
        unit: "seconds",
        aggregationScope: "RECOVERY",
      }));
    }
    if (hrv !== null && hrv >= 0) {
      result.push(metric({
        externalId: id,
        metricType: "HRV",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: Math.min(hrv, 1000),
        unit: "ms_rmssd",
        aggregationScope: "RECOVERY",
      }));
    }
    if (heartRate !== null && heartRate >= 20 && heartRate <= 300) {
      result.push(metric({
        externalId: id,
        metricType: "HEART_RATE",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: heartRate,
        unit: "bpm",
        aggregationScope: "RECOVERY",
      }));
    }
  }
  return result;
}

export function parseOuraActivity(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    const id = text(row.id, 200);
    const day = date(row.day);
    if (!id || !day) continue;
    const start = `${day}T00:00:00.000Z`;
    const end = `${day}T23:59:59.999Z`;
    const steps = number(row.steps);
    const activeEnergy = number(row.active_calories);
    if (steps !== null && steps >= 0) {
      result.push(metric({
        externalId: id,
        metricType: "STEPS",
        startTime: start,
        endTime: end,
        value: Math.min(steps, 500_000),
        unit: "count",
        aggregationScope: "DAILY",
      }));
    }
    if (activeEnergy !== null && activeEnergy >= 0) {
      result.push(metric({
        externalId: id,
        metricType: "ACTIVE_ENERGY",
        startTime: start,
        endTime: end,
        value: Math.min(activeEnergy, 100_000),
        unit: "kcal",
        aggregationScope: "DAILY",
      }));
    }
  }
  return result;
}

export function parseWhoopRecoveries(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    if (row.score_state !== "SCORED") continue;
    const score = object(row.score);
    const id = text(row.sleep_id, 200);
    const at = timestamp(row.updated_at) ?? timestamp(row.created_at);
    if (!score || !id || !at) continue;
    addWhoopRecoveryMetric(
      result,
      id,
      at,
      "RECOVERY",
      score.recovery_score,
      "score",
    );
    addWhoopRecoveryMetric(
      result,
      id,
      at,
      "HRV",
      score.hrv_rmssd_milli,
      "ms_rmssd",
    );
    addWhoopRecoveryMetric(
      result,
      id,
      at,
      "RESTING_HEART_RATE",
      score.resting_heart_rate,
      "bpm",
    );
  }
  return result;
}

function addWhoopRecoveryMetric(
  target: CloudMetric[],
  id: string,
  at: Date,
  metricType: "RECOVERY" | "HRV" | "RESTING_HEART_RATE",
  rawValue: unknown,
  unit: string,
) {
  const value = number(rawValue);
  if (value === null || value < 0) return;
  target.push(metric({
    externalId: id,
    metricType,
    startTime: at.toISOString(),
    endTime: at.toISOString(),
    value,
    unit,
    aggregationScope: "RECOVERY",
  }));
}

export function parseWhoopSleeps(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    const id = text(row.id, 200);
    const start = timestamp(row.start);
    const end = timestamp(row.end);
    const score = object(row.score);
    if (!id || !start || !end || !score || end < start) continue;
    const stages = object(score.stage_summary);
    const inBedMs = number(stages?.total_in_bed_time_milli);
    const awakeMs = number(stages?.total_awake_time_milli) ?? 0;
    if (inBedMs !== null) {
      result.push(metric({
        externalId: id,
        metricType: "SLEEP",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: Math.max(0, Math.min(86_400, (inBedMs - awakeMs) / 1000)),
        unit: "seconds",
        aggregationScope: "RECOVERY",
        metadata: { nap: row.nap === true },
      }));
    }
    const performance = number(score.sleep_performance_percentage);
    if (performance !== null) {
      result.push(metric({
        externalId: id,
        metricType: "SLEEP_SCORE",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: clamp(performance, 0, 100),
        unit: "score",
        aggregationScope: "RECOVERY",
      }));
    }
  }
  return result;
}

export function parseWhoopWorkouts(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    const id = text(row.id, 200);
    const start = timestamp(row.start);
    const end = timestamp(row.end);
    const score = object(row.score);
    if (!id || !start || !end || !score || end < start) continue;
    const metadata = {
      sport: text(row.sport_name, 80) || "unknown",
      scoreState: text(row.score_state, 32) || "unknown",
    };
    result.push(metric({
      externalId: id,
      metricType: "WORKOUT",
      startTime: start.toISOString(),
      endTime: end.toISOString(),
      value: Math.max(0, (end.getTime() - start.getTime()) / 1000),
      unit: "seconds",
      aggregationScope: "WORKOUT",
      metadata,
    }));
    const strain = number(score.strain);
    if (strain !== null) {
      result.push(metric({
        externalId: id,
        metricType: "STRAIN",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: clamp(strain, 0, 100),
        unit: "score",
        aggregationScope: "WORKOUT",
        metadata,
      }));
    }
    const averageHeartRate = number(score.average_heart_rate);
    if (
      averageHeartRate !== null && averageHeartRate >= 20 &&
      averageHeartRate <= 300
    ) {
      result.push(metric({
        externalId: id,
        metricType: "HEART_RATE",
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        value: averageHeartRate,
        unit: "bpm",
        aggregationScope: "WORKOUT",
        metadata,
      }));
    }
  }
  return result;
}

export function parseWhoopCycles(rows: Json[]) {
  const result: CloudMetric[] = [];
  for (const row of rows) {
    if (row.score_state !== "SCORED") continue;
    const id = text(row.id, 200);
    const start = timestamp(row.start);
    const end = timestamp(row.end) ?? timestamp(row.updated_at);
    const score = object(row.score);
    const strain = number(score?.strain);
    if (!id || !start || !end || strain === null || end < start) continue;
    result.push(metric({
      externalId: id,
      metricType: "STRAIN",
      startTime: start.toISOString(),
      endTime: end.toISOString(),
      value: clamp(strain, 0, 100),
      unit: "score",
      aggregationScope: "DAILY",
    }));
  }
  return result;
}

async function deleteProviderResource(
  admin: AdminClient,
  userId: string,
  resourceId: string,
) {
  const { error } = await admin.from("health_metric_records").delete()
    .eq("user_id", userId)
    .eq("provider", "WHOOP_DIRECT")
    .eq("external_record_id", resourceId.slice(0, 200));
  if (error) throw error;
}

function records(value: Json, key: string) {
  const rows = value[key];
  return Array.isArray(rows)
    ? rows.filter((row): row is Json => Boolean(row) && typeof row === "object")
    : [];
}

function object(value: unknown): Json | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Json
    : null;
}

function text(value: unknown, max: number) {
  if (typeof value !== "string" && typeof value !== "number") return "";
  return String(value).trim().slice(0, max);
}

function number(value: unknown) {
  const parsed = typeof value === "number" ? value : Number.NaN;
  return Number.isFinite(parsed) ? parsed : null;
}

function date(value: unknown) {
  const valueText = text(value, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(valueText) ? valueText : "";
}

function timestamp(value: unknown) {
  const valueText = text(value, 40);
  const parsed = new Date(valueText);
  return valueText && Number.isFinite(parsed.getTime()) ? parsed : null;
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function metric(value: CloudMetric) {
  return value;
}
