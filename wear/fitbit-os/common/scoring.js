import { createEventId } from "./event_id.js";

export { createEventId } from "./event_id.js";

const DEFAULT_FORMAT = Object.freeze({
  id: "ADV_BO3",
  name: "Vantaggi - meglio di 3",
  setsToWin: 2,
  gamesToWin: 6,
  tieBreakAt: 6,
  tieBreakPoints: 7,
  goldenPoint: false,
  superTieBreakDecider: false,
  superTieBreakPoints: 10,
  freePlay: false,
});

export function createMatch(matchId, options = {}) {
  return rebuild({
    version: 1,
    matchId,
    format: { ...DEFAULT_FORMAT, ...(options.format || {}) },
    assignedTeam: options.assignedTeam || null,
    started: options.started === true,
    events: [],
    nextSequence: 0,
  });
}

export function addPoint(match, team, eventId, timestampMs = Date.now()) {
  if (team !== "TEAM_A" && team !== "TEAM_B") return match;
  if (
    match.complete || match.paused ||
    (match.assignedTeam && match.assignedTeam !== team)
  ) {
    return match;
  }
  if (match.events.some((event) => event.eventId === eventId)) return match;
  return rebuild({
    ...match,
    events: match.events.concat({
      eventId,
      type: team === "TEAM_A" ? "POINT_TEAM_A" : "POINT_TEAM_B",
      team,
      teamId: team,
      timestampMs,
      sequence: match.nextSequence,
      sourceMethod: "TAP",
    }),
    nextSequence: match.nextSequence + 1,
  });
}

export function undo(
  match,
  assignedTeam = match.assignedTeam,
  eventId = createEventId(),
  timestampMs = Date.now(),
) {
  const manuallyCompleted = match.events.some(
    (event) =>
      event.type === "MATCH_COMPLETED" &&
      event.sourceMethod === "MANUAL_EDIT",
  );
  if (
    match.paused || manuallyCompleted ||
    match.events.some((event) => event.eventId === eventId)
  ) {
    return match;
  }
  const undone = new Set(
    match.events
      .filter((event) => event.type === "UNDO" && event.targetEventId)
      .map((event) => event.targetEventId),
  );
  let target = null;
  for (let cursor = match.events.length - 1; cursor >= 0; cursor -= 1) {
    const event = match.events[cursor];
    if (
      (event.type === "POINT_TEAM_A" || event.type === "POINT_TEAM_B") &&
      !undone.has(event.eventId) &&
      (!assignedTeam || (event.team || event.teamId) === assignedTeam)
    ) {
      target = event;
      break;
    }
  }
  if (!target) return match;
  return rebuild({
    ...match,
    events: match.events.concat({
      eventId,
      type: "UNDO",
      team: target.team || target.teamId,
      teamId: target.team || target.teamId,
      targetEventId: target.eventId,
      timestampMs,
      sequence: match.nextSequence,
      sourceMethod: "TAP",
    }),
    nextSequence: match.nextSequence + 1,
  });
}

export function pauseMatch(match, eventId, timestampMs = Date.now()) {
  return appendLifecycle(match, "MATCH_PAUSED", eventId, timestampMs, "TAP");
}

export function resumeMatch(match, eventId, timestampMs = Date.now()) {
  return appendLifecycle(match, "MATCH_RESUMED", eventId, timestampMs, "TAP");
}

export function finishMatch(match, eventId, timestampMs = Date.now()) {
  return appendLifecycle(
    match,
    "MATCH_COMPLETED",
    eventId,
    timestampMs,
    "MANUAL_EDIT",
  );
}

export function formatPreset(id) {
  if (id === "GOLDEN_BO3") {
    return { ...DEFAULT_FORMAT, id, name: "Golden point", goldenPoint: true };
  }
  if (id === "SINGLE_SET") {
    return { ...DEFAULT_FORMAT, id, name: "Partita secca", setsToWin: 1 };
  }
  if (id === "SUPER_TB_BO3") {
    return {
      ...DEFAULT_FORMAT,
      id,
      name: "Super tie-break decisivo",
      superTieBreakDecider: true,
    };
  }
  if (id === "TRAINING") {
    return { ...DEFAULT_FORMAT, id, name: "Allenamento libero", freePlay: true };
  }
  return { ...DEFAULT_FORMAT };
}

export function mergeEvents(match, incoming) {
  const byId = new Map(match.events.map((event) => [event.eventId, event]));
  for (const event of incoming || []) {
    if (
      event && typeof event.eventId === "string" &&
      isSupportedEvent(event) &&
      !byId.has(event.eventId)
    ) {
      byId.set(event.eventId, {
        ...event,
        team: event.team || event.teamId || null,
      });
    }
  }
  const events = [...byId.values()].sort(compareEvents);
  const nextSequence = events.reduce(
    (maximum, event) => Math.max(maximum, Number(event.sequence) + 1 || 0),
    match.nextSequence || 0,
  );
  return rebuild({ ...match, events, nextSequence });
}

export function displayPoint(match, team) {
  if (match.format.freePlay) {
    return String(team === "TEAM_A" ? match.pointsA : match.pointsB);
  }
  if (match.tieBreak) {
    return String(team === "TEAM_A" ? match.pointsA : match.pointsB);
  }
  if (match.advantage === team) return "AD";
  return ["0", "15", "30", "40"][
    team === "TEAM_A" ? match.pointsA : match.pointsB
  ] || "40";
}

export function pointSituation(match) {
  if (match.paused) return "IN PAUSA";
  if (match.complete || match.format.freePlay || match.tieBreak) return "";
  if (match.advantage === "TEAM_A") return "VANTAGGIO TEAM A";
  if (match.advantage === "TEAM_B") return "VANTAGGIO TEAM B";
  if (match.pointsA < 3 || match.pointsB < 3) return "";
  return match.format.goldenPoint
    ? "40 PARI · PUNTO DECISIVO"
    : "40 PARI · VANTAGGI";
}

function rebuild(match) {
  const state = {
    ...match,
    setsA: 0,
    setsB: 0,
    gamesA: 0,
    gamesB: 0,
    pointsA: 0,
    pointsB: 0,
    advantage: null,
    tieBreak: false,
    superTieBreak: false,
    complete: false,
    winner: null,
    completedSets: [],
    started: match.started === true || match.events.length > 0,
    paused: false,
  };
  const resolution = resolveUndoLifecycle(state.events);
  for (let index = 0; index < state.events.length; index += 1) {
    const event = state.events[index];
    if (resolution.ignored.has(index)) continue;
    if (event.type === "MATCH_STARTED") {
      state.started = true;
    } else if (event.type === "MATCH_PAUSED" && !state.complete) {
      state.paused = true;
    } else if (
      event.type === "MATCH_RESUMED" && !state.complete && state.paused
    ) {
      state.paused = false;
    } else if (
      event.type === "MATCH_COMPLETED" &&
      event.sourceMethod === "MANUAL_EDIT" &&
      !state.complete
    ) {
      state.complete = true;
      state.paused = false;
      state.winner = event.team || event.teamId || leadingTeam(state);
    } else if (
      !state.complete && !state.paused &&
      !resolution.cancelled.has(event.eventId) &&
      (event.type === "POINT_TEAM_A" || event.type === "POINT_TEAM_B")
    ) {
      applyPoint(state, event.team || event.teamId);
    }
  }
  return state;
}

/**
 * Resolve explicit Fitbit UNDO targets while respecting lifecycle state.
 * Events logged during pause are retained for audit/sync, but are score no-ops
 * and cannot consume a later valid UNDO.
 */
function resolveUndoLifecycle(events) {
  const cancelled = new Set();
  const ignored = new Set();
  const active = [];
  let lifecycle = "created";
  let manuallyCompleted = false;

  events.forEach((event, index) => {
    switch (event.type) {
      case "MATCH_STARTED":
        if (lifecycle === "created") lifecycle = "in_progress";
        break;
      case "MATCH_PAUSED":
        if (lifecycle === "in_progress") lifecycle = "paused";
        break;
      case "MATCH_RESUMED":
        if (lifecycle === "paused") lifecycle = "in_progress";
        break;
      case "POINT_TEAM_A":
      case "POINT_TEAM_B":
        if (lifecycle === "paused" || lifecycle === "completed") {
          ignored.add(index);
          break;
        }
        if (lifecycle === "created") lifecycle = "in_progress";
        active.push(event.eventId);
        break;
      case "MATCH_COMPLETED":
        lifecycle = "completed";
        if (event.sourceMethod === "MANUAL_EDIT") manuallyCompleted = true;
        break;
      case "UNDO": {
        if (lifecycle === "paused") {
          ignored.add(index);
          break;
        }
        const targetIndex = active.lastIndexOf(event.targetEventId);
        if (targetIndex < 0) break;
        cancelled.add(active.splice(targetIndex, 1)[0]);
        if (lifecycle === "completed" && !manuallyCompleted) {
          lifecycle = "in_progress";
        }
        break;
      }
      default:
        break;
    }
  });
  return { cancelled, ignored };
}

function appendLifecycle(match, type, eventId, timestampMs, sourceMethod) {
  if (!eventId || match.events.some((event) => event.eventId === eventId)) {
    return match;
  }
  if (type === "MATCH_PAUSED" && (match.complete || match.paused || !match.started)) {
    return match;
  }
  if (type === "MATCH_RESUMED" && (match.complete || !match.paused)) {
    return match;
  }
  if (type === "MATCH_COMPLETED" && (match.complete || !match.started)) {
    return match;
  }
  return rebuild({
    ...match,
    events: match.events.concat({
      eventId,
      type,
      timestampMs,
      sequence: match.nextSequence,
      sourceMethod,
    }),
    nextSequence: match.nextSequence + 1,
  });
}

function isSupportedEvent(event) {
  if (!event || typeof event.eventId !== "string") return false;
  if (event.type === "POINT_TEAM_A" || event.type === "POINT_TEAM_B") {
    const team = event.team || event.teamId;
    return team === "TEAM_A" || team === "TEAM_B";
  }
  return [
    "UNDO",
    "MATCH_STARTED",
    "MATCH_PAUSED",
    "MATCH_RESUMED",
    "MATCH_COMPLETED",
  ].includes(event.type);
}

function leadingTeam(state) {
  // Parity with rally_core: sets, then games, then (free play only) rally
  // points. A mid-game point lead never decides a manual finish.
  if (state.setsA !== state.setsB) return state.setsA > state.setsB ? "TEAM_A" : "TEAM_B";
  if (state.gamesA !== state.gamesB) return state.gamesA > state.gamesB ? "TEAM_A" : "TEAM_B";
  if (state.format.freePlay && state.pointsA !== state.pointsB) {
    return state.pointsA > state.pointsB ? "TEAM_A" : "TEAM_B";
  }
  return null;
}

function applyPoint(state, team) {
  const side = team === "TEAM_A" ? "A" : "B";
  const other = side === "A" ? "B" : "A";
  if (state.format.freePlay) {
    state[`points${side}`] += 1;
    return;
  }
  if (state.tieBreak) {
    state[`points${side}`] += 1;
    const own = state[`points${side}`];
    const theirs = state[`points${other}`];
    const target = state.superTieBreak
      ? state.format.superTieBreakPoints
      : state.format.tieBreakPoints;
    if (own >= target && own - theirs >= 2) {
      finishSet(
        state,
        team,
        state.gamesA + (side === "A" ? 1 : 0),
        state.gamesB + (side === "B" ? 1 : 0),
      );
    }
    return;
  }

  const own = state[`points${side}`];
  const theirs = state[`points${other}`];
  if (own === 3 && theirs === 3) {
    if (state.format.goldenPoint) {
      finishGame(state, team);
      return;
    }
    if (state.advantage === team) {
      finishGame(state, team);
    } else if (state.advantage) {
      state.advantage = null;
    } else {
      state.advantage = team;
    }
    return;
  }
  if (own === 3 && theirs < 3) {
    finishGame(state, team);
    return;
  }
  state[`points${side}`] = own + 1;
}

function finishGame(state, team) {
  const side = team === "TEAM_A" ? "A" : "B";
  const other = side === "A" ? "B" : "A";
  state[`games${side}`] += 1;
  state.pointsA = 0;
  state.pointsB = 0;
  state.advantage = null;
  const own = state[`games${side}`];
  const theirs = state[`games${other}`];
  if (own >= state.format.gamesToWin && own - theirs >= 2) {
    finishSet(state, team, state.gamesA, state.gamesB);
  } else if (
    state.gamesA === state.format.tieBreakAt &&
    state.gamesB === state.format.tieBreakAt
  ) {
    state.tieBreak = true;
  }
}

function finishSet(state, team, gamesA, gamesB) {
  state.completedSets.push({ gamesA, gamesB });
  if (team === "TEAM_A") state.setsA += 1;
  else state.setsB += 1;
  state.gamesA = 0;
  state.gamesB = 0;
  state.pointsA = 0;
  state.pointsB = 0;
  state.advantage = null;
  state.tieBreak = false;
  state.superTieBreak = false;
  if (
    state.setsA >= state.format.setsToWin ||
    state.setsB >= state.format.setsToWin
  ) {
    state.complete = true;
    state.winner = team;
  } else if (
    state.format.superTieBreakDecider &&
    state.setsA === state.format.setsToWin - 1 &&
    state.setsB === state.format.setsToWin - 1
  ) {
    state.tieBreak = true;
    state.superTieBreak = true;
  }
}

function compareEvents(left, right) {
  const sequence = Number(left.sequence) - Number(right.sequence);
  if (Number.isFinite(sequence) && sequence !== 0) return sequence;
  const timestamp = Number(left.timestampMs) - Number(right.timestampMs);
  if (Number.isFinite(timestamp) && timestamp !== 0) return timestamp;
  return String(left.eventId).localeCompare(String(right.eventId));
}
