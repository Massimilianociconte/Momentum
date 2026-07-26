import assert from "node:assert/strict";
import test from "node:test";

import {
  RECORDING_STATES,
  START_DECISIONS,
  closeSegment,
  initialRecordingState,
  matchToken,
  nextRecordingMode,
  normalizeRecordingMode,
  openSegment,
  recordedDurationMs,
  recordingLogLine,
  recordingQuality,
  shouldFinalizeOnUnload,
  startDecision,
} from "../common/workout_recording.js";

const START = 1_700_000_000_000;
const at = (minutes) => START + minutes * 60_000;

test("recording mode falls back to the RallyMate-managed owner", () => {
  assert.equal(normalizeRecordingMode(undefined), "RALLYMATE_MANAGED");
  assert.equal(normalizeRecordingMode("NONSENSE"), "RALLYMATE_MANAGED");
  assert.equal(normalizeRecordingMode("DISABLED"), "DISABLED");
});

test("the selector cycles through the three owners", () => {
  assert.equal(nextRecordingMode("RALLYMATE_MANAGED"), "EXTERNAL_MANAGED");
  assert.equal(nextRecordingMode("EXTERNAL_MANAGED"), "DISABLED");
  assert.equal(nextRecordingMode("DISABLED"), "RALLYMATE_MANAGED");
});

test("only the first start is accepted for a match", () => {
  assert.equal(
    startDecision("RALLYMATE_MANAGED", RECORDING_STATES.IDLE, false),
    START_DECISIONS.START
  );
  assert.equal(
    startDecision("RALLYMATE_MANAGED", RECORDING_STATES.RUNNING, false),
    START_DECISIONS.DUPLICATE
  );
});

test("a terminated recording is never restarted automatically", () => {
  for (const state of [
    RECORDING_STATES.SAVED,
    RECORDING_STATES.FAILED,
    RECORDING_STATES.EXTERNAL_OWNED,
  ]) {
    assert.equal(
      startDecision("RALLYMATE_MANAGED", state, false),
      START_DECISIONS.SUPPRESSED
    );
  }
  assert.equal(
    startDecision("RALLYMATE_MANAGED", RECORDING_STATES.EXTERNAL_OWNED, true),
    START_DECISIONS.START
  );
});

test("app unload finalizes only an exercise RallyMate still owns", () => {
  assert.equal(shouldFinalizeOnUnload(RECORDING_STATES.RUNNING), true);
  assert.equal(shouldFinalizeOnUnload(RECORDING_STATES.PAUSED), true);
  assert.equal(shouldFinalizeOnUnload(RECORDING_STATES.SAVED), false);
  assert.equal(shouldFinalizeOnUnload(RECORDING_STATES.EXTERNAL_OWNED), false);
  assert.equal(shouldFinalizeOnUnload(RECORDING_STATES.DISABLED), false);
});

test("the external and disabled owners never open a session", () => {
  assert.equal(
    startDecision("EXTERNAL_MANAGED", RECORDING_STATES.IDLE, true),
    START_DECISIONS.EXTERNAL
  );
  assert.equal(
    startDecision("DISABLED", RECORDING_STATES.IDLE, true),
    START_DECISIONS.DISABLED
  );
  assert.equal(initialRecordingState("EXTERNAL_MANAGED"), RECORDING_STATES.EXTERNAL_OWNED);
  assert.equal(initialRecordingState("DISABLED"), RECORDING_STATES.DISABLED);
});

test("a segment closes exactly once", () => {
  let segments = openSegment([], at(0));
  segments = closeSegment(segments, at(90), "SESSION_ENDED", true);
  const again = closeSegment(segments, at(95), "SESSION_ENDED", true);
  assert.equal(again.length, 1);
  assert.equal(again[0].endedAt, at(90));
  assert.equal(again[0].saved, true);
});

test("overlapping segments are merged, not summed", () => {
  const segments = [
    { startedAt: at(0), endedAt: at(30), saved: true, endReason: null },
    { startedAt: at(20), endedAt: at(50), saved: true, endReason: null },
  ];
  assert.equal(recordedDurationMs(segments, at(0), at(90), at(90)), 50 * 60_000);
});

test("a full match reports complete coverage", () => {
  let segments = openSegment([], at(0));
  segments = closeSegment(segments, at(90), "SESSION_ENDED", true);
  const quality = recordingQuality({
    mode: "RALLYMATE_MANAGED",
    state: RECORDING_STATES.SAVED,
    segments,
    matchStartMs: at(0),
    matchEndMs: at(90),
    nowMs: at(90),
  });
  assert.equal(quality.completeness, "complete");
  assert.equal(quality.recordedDurationMs, 90 * 60_000);
});

test("a five minute segment on a ninety minute match is reported partial", () => {
  let segments = openSegment([], at(0));
  segments = closeSegment(segments, at(5), "OWNED_BY_OTHER_APP", true);
  const quality = recordingQuality({
    mode: "RALLYMATE_MANAGED",
    state: RECORDING_STATES.EXTERNAL_OWNED,
    segments,
    matchStartMs: at(0),
    matchEndMs: at(90),
    nowMs: at(90),
  });
  assert.equal(quality.completeness, "partial");
  assert.equal(quality.recordedDurationMs, 5 * 60_000);
  assert.ok(quality.coverage < 0.1);
});

test("an unfinished match reports pending, not complete", () => {
  const segments = openSegment([], at(0));
  const quality = recordingQuality({
    mode: "RALLYMATE_MANAGED",
    state: RECORDING_STATES.RUNNING,
    segments,
    matchStartMs: at(0),
    matchEndMs: null,
    nowMs: at(20),
  });
  assert.equal(quality.completeness, "pending");
});

test("log lines carry states and reason without identifiers", () => {
  const line = recordingLogLine(
    RECORDING_STATES.RUNNING,
    RECORDING_STATES.EXTERNAL_OWNED,
    "OWNED_BY_OTHER_APP",
    at(5),
    matchToken("mt_fb_secret-user-match")
  );
  assert.ok(line.includes("running->externalOwned"));
  assert.ok(line.includes("OWNED_BY_OTHER_APP"));
  assert.ok(!line.includes("secret-user-match"));
});

test("scoring stays blocked until the resumed journal is complete", async () => {
  const { isResumeComplete, isResumeIncomplete, normalizePendingResume, resumeProgressLabel } =
    await import("../common/resume_state.js");

  const pending = { commandId: "c1", matchId: "mt_fb_1", eventCount: 12 };
  const partial = { matchId: "mt_fb_1", events: new Array(5).fill({}) };
  const full = { matchId: "mt_fb_1", events: new Array(12).fill({}) };

  assert.equal(isResumeIncomplete(pending, partial), true);
  assert.equal(isResumeComplete(pending, partial), false);
  assert.equal(isResumeIncomplete(pending, full), false);
  assert.equal(isResumeComplete(pending, full), true);
  assert.equal(resumeProgressLabel(pending, partial), "RIPRESA 5/12");

  // A marker for another match must never block the current one.
  assert.equal(isResumeIncomplete(pending, { matchId: "other", events: [] }), false);
  // Malformed markers are ignored rather than wedging the app.
  assert.equal(normalizePendingResume({ commandId: "", matchId: "mt", eventCount: 3 }), null);
  assert.equal(normalizePendingResume(null), null);
  assert.equal(isResumeIncomplete(null, partial), false);
});
