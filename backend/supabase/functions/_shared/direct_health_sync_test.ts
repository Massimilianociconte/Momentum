import { assertEquals } from "jsr:@std/assert@1";
import {
  parseOuraSleep,
  parseWhoopRecoveries,
  parseWhoopSleeps,
  parseWhoopWorkouts,
} from "./direct_health_sync.ts";

Deno.test("Oura sleep parser emits bounded aggregates without raw samples", () => {
  const metrics = parseOuraSleep([{
    id: "sleep-1",
    bedtime_start: "2026-07-12T22:30:00+02:00",
    bedtime_end: "2026-07-13T06:30:00+02:00",
    total_sleep_duration: 25_200,
    average_hrv: 48.2,
    average_heart_rate: 57.4,
  }]);
  assertEquals(metrics.map((value) => value.metricType), [
    "SLEEP",
    "HRV",
    "HEART_RATE",
  ]);
  assertEquals(metrics[0].value, 25_200);
  assertEquals(metrics[1].unit, "ms_rmssd");
  assertEquals(
    metrics.every((value) => value.aggregationScope === "RECOVERY"),
    true,
  );
});

Deno.test("WHOOP recovery parser ignores pending scores", () => {
  const metrics = parseWhoopRecoveries([{
    sleep_id: "sleep-pending",
    updated_at: "2026-07-13T06:30:00Z",
    score_state: "PENDING_SCORE",
  }, {
    sleep_id: "sleep-scored",
    updated_at: "2026-07-13T06:31:00Z",
    score_state: "SCORED",
    score: {
      recovery_score: 72,
      hrv_rmssd_milli: 45.8,
      resting_heart_rate: 54,
    },
  }]);
  assertEquals(metrics.map((value) => value.metricType), [
    "RECOVERY",
    "HRV",
    "RESTING_HEART_RATE",
  ]);
  assertEquals(metrics[1].unit, "ms_rmssd");
});

Deno.test("WHOOP sleep duration excludes awake time", () => {
  const metrics = parseWhoopSleeps([{
    id: "sleep-1",
    start: "2026-07-12T22:00:00Z",
    end: "2026-07-13T06:00:00Z",
    nap: false,
    score: {
      sleep_performance_percentage: 85,
      stage_summary: {
        total_in_bed_time_milli: 28_800_000,
        total_awake_time_milli: 1_800_000,
      },
    },
  }]);
  assertEquals(metrics[0].metricType, "SLEEP");
  assertEquals(metrics[0].value, 27_000);
  assertEquals(metrics[1].value, 85);
});

Deno.test("WHOOP workout parser persists summaries, not heart-rate samples", () => {
  const metrics = parseWhoopWorkouts([{
    id: "workout-1",
    start: "2026-07-13T18:00:00Z",
    end: "2026-07-13T19:30:00Z",
    sport_name: "padel",
    score_state: "SCORED",
    score: { strain: 12.4, average_heart_rate: 142 },
  }]);
  assertEquals(metrics.map((value) => value.metricType), [
    "WORKOUT",
    "STRAIN",
    "HEART_RATE",
  ]);
  assertEquals(metrics[0].value, 5400);
});
