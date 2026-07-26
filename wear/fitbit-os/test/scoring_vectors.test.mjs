// Conformità cross-piattaforma: rigioca i vettori generati da rally_core
// (wear/shared/scoring_vectors.json) sull'engine Fitbit e confronta gli
// snapshot passo per passo. Il contratto è l'engine Dart.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  addPoint,
  createMatch,
  displayPoint,
  finishMatch,
  pauseMatch,
  resumeMatch,
  undo,
} from "../common/scoring.js";

const document = JSON.parse(
  readFileSync(
    new URL("../../shared/scoring_vectors.json", import.meta.url),
    "utf8",
  ),
);

// Il formato Dart usa gamesPerSet/tieBreakAtGamesAll; l'engine Fitbit
// gamesToWin/tieBreakAt. Tutti i vettori condivisi hanno
// tieBreakAtGamesAll=true, quindi la soglia coincide con gamesPerSet.
function toFitbitFormat(format) {
  assert.equal(
    format.tieBreakAtGamesAll,
    true,
    "vettore non rappresentabile dall'engine Fitbit",
  );
  return {
    id: format.id,
    name: format.name,
    setsToWin: format.setsToWin,
    gamesToWin: format.gamesPerSet,
    tieBreakAt: format.gamesPerSet,
    tieBreakPoints: format.tieBreakPoints,
    goldenPoint: format.goldenPoint,
    superTieBreakDecider: format.superTieBreakDecider,
    superTieBreakPoints: format.superTieBreakPoints,
    freePlay: format.freePlay,
  };
}

function applyStep(match, step, index) {
  const eventId = `vec-${index}`;
  const timestampMs = 1750000000000 + index * 1000;
  switch (step.op) {
    case "point":
      return addPoint(match, step.team, eventId, timestampMs);
    case "undo":
      return undo(match, step.team ?? null, eventId, timestampMs);
    case "pause":
      return pauseMatch(match, eventId, timestampMs);
    case "resume":
      return resumeMatch(match, eventId, timestampMs);
    case "finish":
      return finishMatch(match, eventId, timestampMs);
    default:
      throw new Error(`Operazione sconosciuta: ${step.op}`);
  }
}

function assertSnapshot(match, expect, context) {
  assert.equal(match.setsA, expect.setsA, `${context} setsA`);
  assert.equal(match.setsB, expect.setsB, `${context} setsB`);
  assert.equal(match.gamesA, expect.gamesA, `${context} gamesA`);
  assert.equal(match.gamesB, expect.gamesB, `${context} gamesB`);
  assert.equal(match.complete, expect.completed, `${context} completed`);
  assert.equal(match.paused, expect.paused, `${context} paused`);
  assert.equal(match.winner ?? null, expect.winner, `${context} winner`);
  assert.equal(
    match.tieBreak,
    expect.inTieBreak || expect.inSuperTieBreak,
    `${context} tieBreak`,
  );
  assert.equal(
    match.superTieBreak,
    expect.inSuperTieBreak,
    `${context} superTieBreak`,
  );
  assert.equal(
    displayPoint(match, "TEAM_A"),
    expect.labelA,
    `${context} labelA`,
  );
  assert.equal(
    displayPoint(match, "TEAM_B"),
    expect.labelB,
    `${context} labelB`,
  );
  if (!match.format.freePlay && !match.tieBreak) {
    assert.equal(
      match.advantage ?? null,
      expect.advantage,
      `${context} advantage`,
    );
  }
  if (match.tieBreak) {
    assert.equal(match.pointsA, expect.tieBreakA, `${context} tieBreakA`);
    assert.equal(match.pointsB, expect.tieBreakB, `${context} tieBreakB`);
  }
  if (match.format.freePlay) {
    assert.equal(match.pointsA, expect.freePlayA, `${context} freePlayA`);
    assert.equal(match.pointsB, expect.freePlayB, `${context} freePlayB`);
  }
  assert.equal(
    match.completedSets.length,
    expect.completedSets.length,
    `${context} completedSets.length`,
  );
  expect.completedSets.forEach((set, i) => {
    assert.equal(
      match.completedSets[i].gamesA,
      set.gamesA,
      `${context} completedSets[${i}].gamesA`,
    );
    assert.equal(
      match.completedSets[i].gamesB,
      set.gamesB,
      `${context} completedSets[${i}].gamesB`,
    );
  });
}

for (const vector of document.vectors) {
  if (!vector.platforms.includes("fitbit")) continue;
  test(`vettore ${vector.id}`, () => {
    let match = createMatch(`vec_${vector.id}`, {
      format: toFitbitFormat(vector.format),
      started: true,
    });
    vector.steps.forEach((step, index) => {
      match = applyStep(match, step, index);
      assertSnapshot(match, step.expect, `${vector.id}#${index} (${step.op})`);
    });
  });
}
