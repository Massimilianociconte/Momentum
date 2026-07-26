/**
 * Single-owner workout recording policy, shared by the Fitbit app and its
 * tests. Mirrors the watchOS/Wear OS/Garmin state machines: Fitbit OS also
 * allows one exercise at a time, so RallyMate never competes for it and never
 * restarts a recording that already ended without explicit user consent.
 */

export const RECORDING_MODES = ["RALLYMATE_MANAGED", "EXTERNAL_MANAGED", "DISABLED"];

export const RECORDING_MODE_LABELS = {
  RALLYMATE_MANAGED: "REGISTRA CON PADELANDIA",
  EXTERNAL_MANAGED: "USO UN'ALTRA APP",
  DISABLED: "NON REGISTRARE",
};

export const RECORDING_EXCLUSIVITY_NOTE = "UN SOLO ALLENAMENTO ALLA VOLTA";

export const RECORDING_STATES = {
  IDLE: "idle",
  PREPARING: "preparing",
  RUNNING: "running",
  PAUSED: "paused",
  STOPPING: "stopping",
  SAVED: "saved",
  FAILED: "failed",
  EXTERNAL_OWNED: "externalOwned",
  DISABLED: "disabled",
};

export const START_DECISIONS = {
  START: "START",
  DUPLICATE: "DUPLICATE_START_IGNORED",
  SUPPRESSED: "AUTO_RESTART_SUPPRESSED",
  EXTERNAL: "USER_CHOICE_EXTERNAL",
  DISABLED: "USER_CHOICE_DISABLED",
};

const OWNING_STATES = [
  RECORDING_STATES.PREPARING,
  RECORDING_STATES.RUNNING,
  RECORDING_STATES.PAUSED,
  RECORDING_STATES.STOPPING,
];

const TERMINAL_STATES = [
  RECORDING_STATES.SAVED,
  RECORDING_STATES.FAILED,
  RECORDING_STATES.EXTERNAL_OWNED,
  RECORDING_STATES.DISABLED,
];

export function normalizeRecordingMode(mode) {
  return RECORDING_MODES.indexOf(mode) >= 0 ? mode : "RALLYMATE_MANAGED";
}

export function nextRecordingMode(mode) {
  const index = RECORDING_MODES.indexOf(normalizeRecordingMode(mode));
  return RECORDING_MODES[(index + 1) % RECORDING_MODES.length];
}

export function ownsSession(state) {
  return OWNING_STATES.indexOf(state) >= 0;
}

export function isTerminal(state) {
  return TERMINAL_STATES.indexOf(state) >= 0;
}

/** Only an exercise RallyMate still owns must be stopped during app unload. */
export function shouldFinalizeOnUnload(state) {
  return state === RECORDING_STATES.RUNNING ||
    state === RECORDING_STATES.PAUSED;
}

export function initialRecordingState(mode) {
  const normalized = normalizeRecordingMode(mode);
  if (normalized === "EXTERNAL_MANAGED") return RECORDING_STATES.EXTERNAL_OWNED;
  if (normalized === "DISABLED") return RECORDING_STATES.DISABLED;
  return RECORDING_STATES.IDLE;
}

/**
 * The only gate allowed to call `exercise.start`.
 * @param {string} mode user-chosen recording owner
 * @param {string} state current recording state
 * @param {boolean} userInitiated true only for an explicit restart request
 */
export function startDecision(mode, state, userInitiated) {
  const normalized = normalizeRecordingMode(mode);
  if (normalized === "DISABLED") return START_DECISIONS.DISABLED;
  if (normalized === "EXTERNAL_MANAGED") return START_DECISIONS.EXTERNAL;
  if (ownsSession(state)) return START_DECISIONS.DUPLICATE;
  if (isTerminal(state) && userInitiated !== true) return START_DECISIONS.SUPPRESSED;
  return START_DECISIONS.START;
}

/** Adds a segment when a recording actually starts. */
export function openSegment(segments, atMs) {
  const list = (segments || []).slice();
  list.push({ startedAt: atMs, endedAt: null, saved: false, endReason: null });
  return list;
}

/** Closes the open segment exactly once; extra calls are no-ops. */
export function closeSegment(segments, atMs, reason, saved) {
  const list = (segments || []).slice();
  const last = list[list.length - 1];
  if (!last || last.endedAt !== null) return list;
  list[list.length - 1] = {
    startedAt: last.startedAt,
    endedAt: Math.max(last.startedAt, atMs),
    saved: saved === true,
    endReason: reason || null,
  };
  return list;
}

/** Non-overlapping saved recording inside the match window. */
export function recordedDurationMs(segments, matchStartMs, matchEndMs, nowMs) {
  const upper = matchEndMs === null || matchEndMs === undefined ? nowMs : matchEndMs;
  const ranges = (segments || [])
    .filter((segment) => segment.saved)
    .map((segment) => {
      const start = Math.max(segment.startedAt, matchStartMs);
      const end = Math.min(
        segment.endedAt === null || segment.endedAt === undefined ? nowMs : segment.endedAt,
        upper
      );
      return { start: start, end: end };
    })
    .filter((range) => range.end > range.start)
    .sort((a, b) => a.start - b.start);

  let total = 0;
  let current = null;
  for (let index = 0; index < ranges.length; index += 1) {
    const range = ranges[index];
    if (current === null) {
      current = range;
    } else if (range.start <= current.end) {
      // Overlapping segments merge; they are never summed twice.
      current = { start: current.start, end: Math.max(current.end, range.end) };
    } else {
      total += current.end - current.start;
      current = range;
    }
  }
  if (current !== null) total += current.end - current.start;
  return total;
}

/** Honest verdict on what the saved data covers. */
export function recordingQuality(options) {
  const mode = normalizeRecordingMode(options.mode);
  const state = options.state || RECORDING_STATES.IDLE;
  const segments = options.segments || [];
  const nowMs = options.nowMs;
  const matchStartMs = options.matchStartMs;
  const matchEndMs = options.matchEndMs === undefined ? null : options.matchEndMs;
  const completeCoverage = options.completeCoverage || 0.9;

  const matchDurationMs = Math.max(
    0,
    (matchEndMs === null ? nowMs : matchEndMs) - matchStartMs
  );
  const saved = segments.filter((segment) => segment.saved);
  const recorded = recordedDurationMs(segments, matchStartMs, matchEndMs, nowMs);

  let completeness;
  if (mode === "DISABLED") {
    completeness = "none";
  } else if (mode === "EXTERNAL_MANAGED") {
    completeness = "external";
  } else if (ownsSession(state) && matchEndMs === null) {
    completeness = "pending";
  } else if (saved.length === 0 || recorded <= 0) {
    completeness = state === RECORDING_STATES.EXTERNAL_OWNED ? "external" : "none";
  } else if (
    saved.length === 1 &&
    matchDurationMs > 0 &&
    recorded / matchDurationMs >= completeCoverage
  ) {
    completeness = "complete";
  } else {
    completeness = "partial";
  }

  return {
    completeness: completeness,
    matchDurationMs: matchDurationMs,
    recordedDurationMs: recorded,
    segmentCount: saved.length,
    coverage: matchDurationMs > 0 ? Math.min(1, recorded / matchDurationMs) : 0,
    label: qualityLabel(completeness),
  };
}

function qualityLabel(completeness) {
  if (completeness === "complete") return "DATI SALUTE COMPLETI";
  if (completeness === "partial") return "DATI SALUTE PARZIALI";
  if (completeness === "external") return "REGISTRATO DA ALTRA APP";
  if (completeness === "pending") return "REGISTRAZIONE IN CORSO";
  return "NESSUN DATO SALUTE";
}

/** Structured log line: states, reason, timestamp. No health values, no ids. */
export function recordingLogLine(from, to, reason, atMs, matchToken) {
  return `${atMs} ${matchToken} ${from}->${to} ${reason}`;
}

/** Opaque, non-reversible short token used only to correlate log lines. */
export function matchToken(matchId) {
  if (!matchId) return "-";
  let hash = 0x811c9dc5;
  for (let index = 0; index < matchId.length; index += 1) {
    hash ^= matchId.charCodeAt(index) & 0xff;
    hash = (hash * 0x01000193) >>> 0;
  }
  return `m${hash.toString(16)}`;
}
