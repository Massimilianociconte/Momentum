import test from "node:test";
import assert from "node:assert/strict";
import {
  addPoint,
  createMatch,
  displayPoint,
  finishMatch,
  formatPreset,
  mergeEvents,
  pauseMatch,
  pointSituation,
  resumeMatch,
  undo,
} from "../common/scoring.js";
import {
  FITBIT_MESSAGE_LIMIT_BYTES,
  fitMessageBatch,
  utf8ByteLength,
} from "../common/message_batch.js";

function points(match, team, count, offset = 0) {
  let next = match;
  for (let index = 0; index < count; index += 1) {
    next = addPoint(
      next,
      team,
      `${team}-${offset + index}-event`,
      offset + index,
    );
  }
  return next;
}

test("deuce, advantage, return to deuce and game are deterministic", () => {
  let match = createMatch("match-deuce");
  match = points(match, "TEAM_A", 3);
  match = points(match, "TEAM_B", 3, 10);
  assert.equal(pointSituation(match), "40 PARI · VANTAGGI");
  match = addPoint(match, "TEAM_A", "adv-a-event", 20);
  assert.equal(displayPoint(match, "TEAM_A"), "AD");
  assert.equal(pointSituation(match), "VANTAGGIO TEAM A");
  match = addPoint(match, "TEAM_B", "deuce-event", 21);
  assert.equal(displayPoint(match, "TEAM_A"), "40");
  assert.equal(displayPoint(match, "TEAM_B"), "40");
  assert.equal(pointSituation(match), "40 PARI · VANTAGGI");
  match = addPoint(match, "TEAM_B", "adv-b-event", 22);
  assert.equal(displayPoint(match, "TEAM_B"), "AD");
  match = addPoint(match, "TEAM_A", "deuce-2-event", 23);
  match = addPoint(match, "TEAM_A", "adv-a-2-event", 24);
  match = addPoint(match, "TEAM_A", "game-a-event", 25);
  assert.equal(match.gamesA, 1);
  assert.equal(displayPoint(match, "TEAM_A"), "0");
});

test("undo replays the event timeline instead of decrementing state", () => {
  let match = createMatch("match-undo");
  match = points(match, "TEAM_A", 4);
  assert.equal(match.gamesA, 1);
  match = undo(match);
  assert.equal(match.gamesA, 0);
  assert.equal(displayPoint(match, "TEAM_A"), "40");
});

test("duo assignment rejects opponent points and undo touches only own team", () => {
  let match = createMatch("match-duo", { assignedTeam: "TEAM_A" });
  match = addPoint(match, "TEAM_B", "blocked-event", 1);
  assert.equal(match.events.length, 0);
  match = addPoint(match, "TEAM_A", "own-event-1", 2);
  const merged = mergeEvents(match, [{
    eventId: "remote-event-1",
    type: "POINT_TEAM_B",
    team: "TEAM_B",
    timestampMs: 3,
    sequence: 1,
  }]);
  const undone = undo(merged, "TEAM_A");
  assert.equal(displayPoint(undone, "TEAM_A"), "0");
  assert.equal(displayPoint(undone, "TEAM_B"), "15");
  assert.equal(undone.events.at(-1).type, "UNDO");
  assert.equal(undone.events.at(-1).targetEventId, "own-event-1");
});

test("duplicate and late events are merged idempotently in sequence order", () => {
  const base = addPoint(
    createMatch("match-merge"),
    "TEAM_A",
    "event-0001",
    2,
  );
  const late = {
    eventId: "event-0000",
    type: "POINT_TEAM_B",
    team: "TEAM_B",
    timestampMs: 1,
    sequence: 0,
  };
  const merged = mergeEvents(base, [base.events[0], late, late]);
  assert.equal(merged.events.length, 2);
  assert.equal(displayPoint(merged, "TEAM_A"), "15");
  assert.equal(displayPoint(merged, "TEAM_B"), "15");
});

test("tie-break requires two points and closes a set", () => {
  let match = createMatch("match-tiebreak", {
    format: { setsToWin: 1, gamesToWin: 1, tieBreakAt: 1, tieBreakPoints: 7 },
  });
  match = points(match, "TEAM_A", 4);
  match = points(match, "TEAM_B", 4, 10);
  assert.equal(match.tieBreak, true);
  for (let index = 0; index < 6; index += 1) {
    match = addPoint(match, "TEAM_A", `tb-a-${index}-event`, 30 + index * 2);
    match = addPoint(match, "TEAM_B", `tb-b-${index}-event`, 31 + index * 2);
  }
  match = addPoint(match, "TEAM_A", "tb-a-6-event", 50);
  assert.equal(match.complete, false);
  match = addPoint(match, "TEAM_A", "tb-a-7-event", 51);
  assert.equal(match.complete, true);
  assert.equal(match.winner, "TEAM_A");
});

test("peer batches stay below Fitbit's 1027 byte socket limit", () => {
  const events = Array.from({ length: 50 }, (_, index) => ({
    eventId: `event-${index.toString().padStart(3, "0")}-abcdefghijklmnop`,
    matchId: "match-fitbit-message-budget",
    type: index % 2 === 0 ? "POINT_TEAM_A" : "POINT_TEAM_B",
    teamId: index % 2 === 0 ? "TEAM_A" : "TEAM_B",
    timestampMs: 1783843200000 + index,
    sequence: index,
    sourceMethod: "TAP",
  }));
  const batch = fitMessageBatch(events);
  const bytes = utf8ByteLength(JSON.stringify({ type: "events", events: batch }));
  assert.ok(batch.length > 0);
  assert.ok(batch.length < events.length);
  assert.ok(bytes < FITBIT_MESSAGE_LIMIT_BYTES);
});

test("golden point closes a deuce game with the next point", () => {
  let match = createMatch("match-golden", {
    format: { goldenPoint: true },
  });
  match = points(match, "TEAM_A", 3);
  match = points(match, "TEAM_B", 3, 10);
  assert.equal(pointSituation(match), "40 PARI · PUNTO DECISIVO");
  match = addPoint(match, "TEAM_A", "golden-point", 20);
  assert.equal(match.gamesA, 1);
  assert.equal(match.pointsA, 0);
  assert.equal(match.pointsB, 0);
});

test("free play keeps a numeric rally counter without ending the match", () => {
  let match = createMatch("match-training", { format: { freePlay: true } });
  match = points(match, "TEAM_B", 12);
  assert.equal(displayPoint(match, "TEAM_B"), "12");
  assert.equal(match.complete, false);
});

test("pause, resume and manual finish remain replayable after an offline restart", () => {
  let match = createMatch("match-lifecycle", { started: true });
  match = addPoint(match, "TEAM_A", "point-before-pause", 1);
  match = pauseMatch(match, "pause-event", 2);
  assert.equal(match.paused, true);
  const blocked = addPoint(match, "TEAM_A", "blocked-point", 3);
  assert.equal(blocked.events.length, match.events.length);
  match = resumeMatch(match, "resume-event", 4);
  assert.equal(match.paused, false);
  match = finishMatch(match, "finish-event", 5);
  assert.equal(match.complete, true);
  assert.equal(match.events.at(-1).sourceMethod, "MANUAL_EDIT");

  const restored = mergeEvents(
    createMatch("match-lifecycle", { started: true }),
    match.events,
  );
  assert.equal(restored.complete, true);
  assert.equal(displayPoint(restored, "TEAM_A"), "15");
});

test("paused point and undo are no-ops live and after merged replay", () => {
  let match = createMatch("match-paused-log", { started: true });
  match = addPoint(match, "TEAM_A", "point-a", 1);
  match = pauseMatch(match, "pause", 2);

  const livePoint = addPoint(match, "TEAM_B", "live-paused-point", 3);
  const liveUndo = undo(match, null, "live-paused-undo", 4);
  assert.equal(livePoint.events.length, match.events.length);
  assert.equal(liveUndo.events.length, match.events.length);

  match = mergeEvents(match, [
    {
      eventId: "logged-paused-point",
      type: "POINT_TEAM_B",
      team: "TEAM_B",
      teamId: "TEAM_B",
      timestampMs: 3,
      sequence: 2,
      sourceMethod: "TAP",
    },
    {
      eventId: "logged-paused-undo",
      type: "UNDO",
      targetEventId: "point-a",
      timestampMs: 4,
      sequence: 3,
      sourceMethod: "TAP",
    },
  ]);
  assert.equal(match.paused, true);
  assert.equal(displayPoint(match, "TEAM_A"), "15");
  assert.equal(displayPoint(match, "TEAM_B"), "0");

  match = resumeMatch(match, "resume", 5);
  match = addPoint(match, "TEAM_B", "point-b", 6);
  match = undo(match, null, "valid-undo", 7);
  assert.equal(match.paused, false);
  assert.equal(displayPoint(match, "TEAM_A"), "15");
  assert.equal(displayPoint(match, "TEAM_B"), "0");
});

test("watch format presets keep deterministic official scoring modes", () => {
  assert.equal(formatPreset("ADV_BO3").goldenPoint, false);
  assert.equal(formatPreset("GOLDEN_BO3").goldenPoint, true);
  assert.equal(formatPreset("SINGLE_SET").setsToWin, 1);
  assert.equal(formatPreset("SUPER_TB_BO3").superTieBreakDecider, true);
  assert.equal(formatPreset("TRAINING").freePlay, true);
});

test("start and derived completion remain in the journal without blocking undo", () => {
  let match = mergeEvents(createMatch("match-audit"), [{
    eventId: "match-started",
    matchId: "match-audit",
    type: "MATCH_STARTED",
    timestampMs: 0,
    sequence: 0,
    sourceMethod: "AUTO",
  }]);
  assert.equal(match.started, true);
  match = mergeEvents(match, [{
    eventId: "derived-completion",
    matchId: "match-audit",
    type: "MATCH_COMPLETED",
    timestampMs: 2,
    sequence: 2,
    sourceMethod: "AUTO",
  }]);
  assert.equal(match.complete, false);

  let completed = createMatch("match-derived", {
    started: true,
    format: { setsToWin: 1, gamesToWin: 1, tieBreakAt: 6 },
  });
  completed = points(completed, "TEAM_A", 8);
  assert.equal(completed.complete, true);
  completed = mergeEvents(completed, [{
    eventId: "derived-finish",
    matchId: "match-derived",
    type: "MATCH_COMPLETED",
    timestampMs: 20,
    sequence: completed.nextSequence,
    sourceMethod: "AUTO",
  }]);
  const reopened = undo(completed, null, "undo-final", 21);
  assert.equal(reopened.complete, false);
  assert.equal(reopened.events.some((event) => event.type === "MATCH_COMPLETED"), true);
});
