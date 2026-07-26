import { me as appbit } from "appbit";
import { display } from "display";
import document from "document";
import * as fs from "fs";
import { vibration } from "haptics";
import { peerSocket } from "messaging";

import {
  addPoint,
  createEventId,
  createMatch,
  displayPoint,
  finishMatch,
  formatPreset,
  mergeEvents,
  pauseMatch,
  pointSituation,
  resumeMatch,
  undo,
} from "../common/scoring";
import { fitMessageBatch } from "../common/message_batch";
import {
  isResumeComplete,
  isResumeIncomplete,
  normalizePendingResume,
  resumeProgressLabel,
} from "../common/resume_state";
import { DEVICE_RETRY_MS, shouldRetryOnDevice } from "../common/power_policy";
import {
  RECORDING_MODE_LABELS,
  RECORDING_STATES,
  START_DECISIONS,
  closeSegment,
  initialRecordingState,
  matchToken,
  nextRecordingMode,
  normalizeRecordingMode,
  openSegment,
  recordingLogLine,
  recordingQuality,
  shouldFinalizeOnUnload,
  startDecision,
} from "../common/workout_recording";
import {
  exerciseOwnedByOtherApp,
  pauseExercise,
  resumeExercise,
  startExercise,
  stopExercise,
} from "./exercise_owner";

const STATE_FILE = "rallymate-state.json";
const NOTICE_FILE = "rallymate-plus-notice.json";
const elements = {
  teamA: document.getElementById("team-a"),
  teamB: document.getElementById("team-b"),
  labelA: document.getElementById("team-a-label"),
  labelB: document.getElementById("team-b-label"),
  pointScore: document.getElementById("point-score"),
  matchScore: document.getElementById("match-score"),
  pointSituation: document.getElementById("point-situation"),
  syncStatus: document.getElementById("sync-status"),
  title: document.getElementById("title"),
  undo: document.getElementById("undo"),
  undoLabel: document.getElementById("undo-label"),
  pauseResume: document.getElementById("pause-resume"),
  pauseResumeLabel: document.getElementById("pause-resume-label"),
  finish: document.getElementById("finish"),
  finishLabel: document.getElementById("finish-label"),
  startPanel: document.getElementById("start-panel"),
  formatNext: document.getElementById("format-next"),
  formatLabel: document.getElementById("format-label"),
  startMatch: document.getElementById("start-match"),
  recordingNext: document.getElementById("recording-next"),
  recordingLabel: document.getElementById("recording-label"),
  finishConfirm: document.getElementById("finish-confirm"),
  finishSummary: document.getElementById("finish-summary"),
  confirmFinish: document.getElementById("confirm-finish"),
  cancelFinish: document.getElementById("cancel-finish"),
  matchDone: document.getElementById("match-done"),
  doneSummary: document.getElementById("done-summary"),
  doneSync: document.getElementById("done-sync"),
  doneHealth: document.getElementById("done-health"),
  newMatch: document.getElementById("new-match"),
  subscriptionNotice: document.getElementById("subscription-notice"),
  subscriptionNoticeOk: document.getElementById("subscription-notice-ok"),
};

let noticeVisible = !loadNoticeAcknowledged();
let retryTimer = null;
/** Last transport/account status from companion; not clobbered by outbox render. */
let lastTransportStatus = null;
/**
 * RESUME_MATCH in flight: {commandId, matchId, eventCount}. APPLIED is acked
 * only once the whole journal reached the watch; until then the command stays
 * unacked on the server and gets redelivered (merge is idempotent).
 */
/// Restored from the saved state: a reload during the journal transfer must
/// not turn a half-restored match into a scoreable one.
let pendingResume = normalizePendingResume(persisted.pendingResume);
const formatIds = [
  "ADV_BO3",
  "GOLDEN_BO3",
  "SUPER_TB_BO3",
  "SINGLE_SET",
  "TRAINING",
];

let persisted = loadState();
if (!persisted) {
  const matchId = `fitbit-${Date.now().toString(36)}`;
  const match = createMatch(matchId);
  persisted = {
    match,
    outbox: [],
    lastFormatId: "ADV_BO3",
  };
  saveState();
}
let setupVisible = !persisted.match.started;
let finishVisible = false;
let selectedFormatId = formatIds.includes(persisted.lastFormatId)
  ? persisted.lastFormatId
  : "ADV_BO3";
let selectedRecordingMode = normalizeRecordingMode(persisted.lastRecordingMode);
if (!persisted.recording) {
  persisted.recording = defaultRecording(selectedRecordingMode);
}

elements.teamA.onclick = () => score("TEAM_A");
elements.teamB.onclick = () => score("TEAM_B");
elements.undo.onclick = undoLast;
elements.pauseResume.onclick = togglePause;
elements.finish.onclick = requestFinish;
elements.formatNext.onclick = selectNextFormat;
elements.recordingNext.onclick = selectNextRecordingMode;
elements.startMatch.onclick = startLocalMatch;
elements.confirmFinish.onclick = confirmFinish;
elements.cancelFinish.onclick = cancelFinish;
elements.newMatch.onclick = openNewMatch;
elements.subscriptionNoticeOk.onclick = acknowledgeSubscriptionNotice;

peerSocket.onopen = () => {
  cancelRetry();
  flush();
  requestCommands();
};
peerSocket.onmessage = (event) => receive(event.data);
peerSocket.onerror = () => render();
display.addEventListener("change", () => {
  if (!display.on) saveState();
  if (display.on && !display.aodActive) flush();
  else cancelRetry();
  render();
});
appbit.onunload = () => {
  cancelRetry();
  endRecording(persisted.match.matchId, "APP_UNLOADED");
  saveState();
};

if (appbit.permissions.granted("access_aod")) {
  display.aodAllowed = true;
}

render();
flush();

function score(team) {
  if (noticeVisible || setupVisible || finishVisible) return;
  // The journal of a resumed match is still arriving: a point accepted now
  // would be appended to a score that is not yet the real one.
  if (isResumeIncomplete(pendingResume, persisted.match)) {
    vibration.start("nudge");
    return;
  }
  const previous = persisted;
  const before = previous.match;
  const eventId = nextId(before.nextSequence);
  let next = addPoint(before, team, eventId, Date.now());
  if (next === before || next.events.length === before.events.length) return;
  const outbox = previous.outbox.concat(
    wireEvent(next.events[next.events.length - 1], next),
  );
  if (!before.complete && next.complete) {
    const completed = lifecycleEvent(
      "MATCH_COMPLETED",
      next.matchId,
      next.nextSequence,
    );
    next = mergeEvents(next, [completed]);
    outbox.push(completed);
  }
  persisted = { ...previous, match: next, outbox };
  if (!saveState()) {
    persisted = previous;
    elements.syncStatus.text = "MEMORIA NON DISPONIBILE";
    vibration.start("nudge-max");
    return;
  }
  vibration.start("bump");
  if (!before.complete && next.complete) endRecording(next.matchId, "MATCH_FINISHED");
  render();
  flush();
}

function undoLast() {
  if (noticeVisible || setupVisible || finishVisible) return;
  if (isResumeIncomplete(pendingResume, persisted.match)) return;
  const previous = persisted;
  const before = previous.match;
  const next = undo(
    before,
    before.assignedTeam,
    nextId(before.nextSequence),
    Date.now(),
  );
  if (next.events.length === before.events.length) return;
  const undoEvent = next.events[next.events.length - 1];
  persisted = {
    ...previous,
    match: next,
    outbox: previous.outbox.concat(wireEvent(undoEvent, next)),
  };
  if (!saveState()) {
    persisted = previous;
    elements.syncStatus.text = "MEMORIA NON DISPONIBILE";
    vibration.start("nudge-max");
    return;
  }
  vibration.start("confirmation");
  render();
  flush();
}

function togglePause() {
  if (noticeVisible || setupVisible || finishVisible || persisted.match.complete) {
    return;
  }
  if (isResumeIncomplete(pendingResume, persisted.match)) return;
  const previous = persisted;
  const before = previous.match;
  const eventId = nextId(before.nextSequence);
  const next = before.paused
    ? resumeMatch(before, eventId)
    : pauseMatch(before, eventId);
  if (next.events.length === before.events.length) return;
  // Mirrors the match state onto the exercise; never reopens a closed one.
  if (before.paused) resumeExercise();
  else pauseExercise();
  persisted = {
    ...previous,
    match: next,
    outbox: previous.outbox.concat(
      wireEvent(next.events[next.events.length - 1], next),
    ),
  };
  if (!saveState()) {
    persisted = previous;
    vibration.start("nudge-max");
    return;
  }
  vibration.start("confirmation");
  render();
  flush();
}

function requestFinish() {
  if (
    noticeVisible || setupVisible || persisted.match.complete ||
    !persisted.match.started
  ) return;
  finishVisible = true;
  vibration.start("bump");
  render();
}

function cancelFinish() {
  finishVisible = false;
  render();
}

function confirmFinish() {
  const previous = persisted;
  const before = previous.match;
  const next = finishMatch(before, nextId(before.nextSequence), Date.now());
  if (next.events.length === before.events.length) {
    finishVisible = false;
    render();
    return;
  }
  persisted = {
    ...previous,
    match: next,
    outbox: previous.outbox.concat(
      wireEvent(next.events[next.events.length - 1], next),
    ),
  };
  if (!saveState()) {
    persisted = previous;
    vibration.start("nudge-max");
    return;
  }
  finishVisible = false;
  endRecording(next.matchId, "MATCH_FINISHED");
  vibration.start("confirmation");
  render();
  flush();
}

function selectNextFormat() {
  const index = formatIds.indexOf(selectedFormatId);
  selectedFormatId = formatIds[(index + 1) % formatIds.length];
  vibration.start("bump");
  render();
}

function startLocalMatch() {
  if (noticeVisible) return;
  const previous = persisted;
  const matchId = `fitbit-${Date.now().toString(36)}-${Math.floor(Math.random() * 4096).toString(36)}`;
  let match = createMatch(matchId, {
    format: formatPreset(selectedFormatId),
    started: true,
  });
  const started = lifecycleEvent("MATCH_STARTED", matchId, 0, match.format);
  match = mergeEvents(match, [started]);
  match.nextSequence = 1;
  persisted = {
    ...previous,
    match,
    lastFormatId: selectedFormatId,
    lastRecordingMode: selectedRecordingMode,
    // Owner frozen for the whole match: changing the default later never
    // moves ownership of a recording already in progress.
    recording: defaultRecording(selectedRecordingMode),
    outbox: previous.outbox.concat(started),
  };
  if (!saveState()) {
    persisted = previous;
    vibration.start("nudge-max");
    return;
  }
  setupVisible = false;
  finishVisible = false;
  beginRecording(matchId, false);
  vibration.start("confirmation");
  render();
  flush();
}

function selectNextRecordingMode() {
  selectedRecordingMode = nextRecordingMode(selectedRecordingMode);
  render();
}

function defaultRecording(mode) {
  const normalized = normalizeRecordingMode(mode);
  return {
    mode: normalized,
    state: initialRecordingState(normalized),
    segments: [],
    startedAt: null,
  };
}

/**
 * Single gate allowed to open an exercise. Duplicates and terminal states are
 * refused here, so scoring taps and re-renders can never restart a recording
 * that another app took over.
 */
function beginRecording(matchId, userInitiated) {
  const recording = persisted.recording || defaultRecording(selectedRecordingMode);
  const decision = startDecision(recording.mode, recording.state, userInitiated === true);
  if (decision !== START_DECISIONS.START) {
    if (decision === START_DECISIONS.EXTERNAL) {
      applyRecording(matchId, recording, RECORDING_STATES.EXTERNAL_OWNED, decision);
    } else if (decision === START_DECISIONS.DISABLED) {
      applyRecording(matchId, recording, RECORDING_STATES.DISABLED, decision);
    }
    return;
  }
  if (exerciseOwnedByOtherApp()) {
    // Expected condition, not an error: leave the other app's exercise alone.
    applyRecording(matchId, recording, RECORDING_STATES.EXTERNAL_OWNED, "OWNED_BY_OTHER_APP");
    return;
  }
  const outcome = startExercise();
  if (outcome === "started") {
    const now = Date.now();
    persisted.recording = {
      mode: recording.mode,
      state: RECORDING_STATES.RUNNING,
      segments: openSegment(recording.segments, now),
      startedAt: now,
    };
    logRecording(matchId, recording.state, RECORDING_STATES.RUNNING, "SESSION_RUNNING");
    saveState();
    return;
  }
  const failedState = outcome === "other_app"
    ? RECORDING_STATES.EXTERNAL_OWNED
    : RECORDING_STATES.FAILED;
  applyRecording(matchId, recording, failedState, outcome.toUpperCase());
}

/** Idempotent: a match that already finalised its recording stays untouched. */
function endRecording(matchId, reason) {
  const recording = persisted.recording || defaultRecording(selectedRecordingMode);
  if (!shouldFinalizeOnUnload(recording.state)) {
    return;
  }
  const saved = stopExercise();
  const now = Date.now();
  persisted.recording = {
    mode: recording.mode,
    state: saved ? RECORDING_STATES.SAVED : RECORDING_STATES.FAILED,
    segments: closeSegment(recording.segments, now, reason, saved),
    startedAt: recording.startedAt,
  };
  logRecording(
    matchId,
    recording.state,
    persisted.recording.state,
    reason,
  );
  saveState();
}

function applyRecording(matchId, recording, state, reason) {
  persisted.recording = {
    mode: recording.mode,
    state,
    segments: closeSegment(recording.segments, Date.now(), reason, false),
    startedAt: recording.startedAt,
  };
  logRecording(matchId, recording.state, state, reason);
  saveState();
  render();
}

function logRecording(matchId, from, to, reason) {
  // Previous state, new state, reason and timestamp. No health values, no ids.
  console.log(recordingLogLine(from, to, reason, Date.now(), matchToken(matchId)));
}

function matchStartedAtMs(match) {
  const started = (match.events || []).find(
    (event) => event.type === "MATCH_STARTED",
  );
  if (started && started.ts) return started.ts;
  const first = (match.events || [])[0];
  return first && first.ts ? first.ts : Date.now();
}

function matchEndedAtMs(match) {
  const completed = (match.events || [])
    .filter((event) => event.type === "MATCH_COMPLETED")
    .pop();
  return completed && completed.ts ? completed.ts : null;
}

function openNewMatch() {
  selectedFormatId = formatIds.includes(persisted.lastFormatId)
    ? persisted.lastFormatId
    : "ADV_BO3";
  selectedRecordingMode = normalizeRecordingMode(persisted.lastRecordingMode);
  setupVisible = true;
  finishVisible = false;
  render();
}

function receive(message) {
  if (!message || typeof message !== "object") return;
  if (message.type === "ack" && Array.isArray(message.eventIds)) {
    const acknowledged = new Set(message.eventIds);
    const outbox = persisted.outbox.filter(
      (event) => !acknowledged.has(event.eventId),
    );
    const previous = persisted;
    persisted = { ...persisted, outbox };
    if (!saveState()) persisted = previous;
    render();
  } else if (message.type === "remote_events" && Array.isArray(message.events)) {
    const previous = persisted;
    // Resume chunks scope the whole message by matchId; per-event matchId
    // still wins when present (legacy live mirroring).
    const messageScope = typeof message.matchId === "string" ? message.matchId : "";
    const sameMatchEvents = message.events.filter((item) => {
      const scope = item && item.matchId ? item.matchId : messageScope;
      return !scope || scope === persisted.match.matchId;
    });
    persisted = {
      ...persisted,
      match: mergeEvents(persisted.match, sameMatchEvents),
    };
    if (!saveState()) persisted = previous;
    maybeCompleteResume();
    render();
  } else if (message.type === "status") {
    lastTransportStatus = message.value;
    render();
  } else if (message.type === "start_match") {
    receiveStartMatch(message);
  } else if (message.type === "resume_match") {
    receiveResumeMatch(message);
  }
}

function receiveStartMatch(message) {
  const commandId = typeof message.commandId === "string" ? message.commandId : "";
  const matchId = typeof message.matchId === "string" ? message.matchId : "";
  if (!commandId || matchId.length < 3) return;
  if (persisted.match.matchId === matchId) {
    sendCommandAck(commandId, "APPLIED");
    return;
  }
  // Never replace an in-progress match (even if outbox already ACKed).
  if (persisted.match.started && !persisted.match.complete) {
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  if (persisted.outbox.length > 0 && !persisted.match.complete) {
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  const remoteFormat = message.format || {};
  let match = createMatch(matchId, {
    assignedTeam: message.assignedTeam || null,
    started: true,
    format: {
      setsToWin: remoteFormat.setsToWin || 2,
      gamesToWin: remoteFormat.gamesPerSet || 6,
      tieBreakAt: remoteFormat.gamesPerSet || 6,
      tieBreakPoints: remoteFormat.tieBreakPoints || 7,
      goldenPoint: remoteFormat.goldenPoint === true,
      superTieBreakDecider: remoteFormat.superTieBreakDecider === true,
      superTieBreakPoints: remoteFormat.superTieBreakPoints || 10,
      freePlay: remoteFormat.freePlay === true,
    },
  });
  const started = lifecycleEvent("MATCH_STARTED", matchId, 0, remoteFormat);
  match = mergeEvents(match, [started]);
  match.nextSequence = 1;
  const previous = persisted;
  persisted = {
    ...previous,
    match,
    outbox: previous.outbox.concat(started),
  };
  if (!saveState()) {
    persisted = previous;
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  sendCommandAck(commandId, "APPLIED");
  setupVisible = false;
  finishVisible = false;
  vibration.start("confirmation");
  render();
  flush();
}

// Mid-match handoff: the phone journal replaces the local match wholesale.
// No fresh MATCH_STARTED is appended (the journal already carries it) and
// resumed events never enter the outbox: the phone owns them already.
function receiveResumeMatch(message) {
  const commandId = typeof message.commandId === "string" ? message.commandId : "";
  const matchId = typeof message.matchId === "string" ? message.matchId : "";
  const eventCount = Number(message.eventCount);
  if (!commandId || matchId.length < 3) return;
  if (!Number.isFinite(eventCount) || eventCount < 1) {
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  if (persisted.match.matchId === matchId) {
    // Redelivery: keep waiting for (or confirm) the journal watermark.
    setPendingResume({ commandId, matchId, eventCount });
    maybeCompleteResume();
    return;
  }
  // Never replace an in-progress match (even if outbox already ACKed).
  if (persisted.match.started && !persisted.match.complete) {
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  if (persisted.outbox.length > 0 && !persisted.match.complete) {
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  const remoteFormat = message.format || {};
  const match = createMatch(matchId, {
    assignedTeam: message.assignedTeam || null,
    started: true,
    format: {
      setsToWin: remoteFormat.setsToWin || 2,
      gamesToWin: remoteFormat.gamesPerSet || 6,
      tieBreakAt: remoteFormat.gamesPerSet || 6,
      tieBreakPoints: remoteFormat.tieBreakPoints || 7,
      goldenPoint: remoteFormat.goldenPoint === true,
      superTieBreakDecider: remoteFormat.superTieBreakDecider === true,
      superTieBreakPoints: remoteFormat.superTieBreakPoints || 10,
      freePlay: remoteFormat.freePlay === true,
    },
  });
  const previous = persisted;
  persisted = { ...previous, match };
  if (!saveState()) {
    persisted = previous;
    sendCommandAck(commandId, "REJECTED");
    return;
  }
  setPendingResume({ commandId, matchId, eventCount });
  setupVisible = false;
  finishVisible = false;
  vibration.start("confirmation");
  render();
}

/// Keeps the marker in the persisted state so an app reload mid-transfer still
/// knows the journal is incomplete.
function setPendingResume(value) {
  pendingResume = normalizePendingResume(value);
  persisted = { ...persisted, pendingResume: pendingResume };
  saveState();
}

function maybeCompleteResume() {
  if (!pendingResume) return;
  if (persisted.match.matchId !== pendingResume.matchId) {
    setPendingResume(null);
    return;
  }
  if (!isResumeComplete(pendingResume, persisted.match)) return;
  sendCommandAck(pendingResume.commandId, "APPLIED");
  setPendingResume(null);
  vibration.start("confirmation");
}

function requestCommands() {
  if (peerSocket.readyState !== peerSocket.OPEN) return;
  try {
    peerSocket.send({ type: "request_commands" });
  } catch (_) {
    // The next app launch/open event retries the durable server command.
  }
}

function sendCommandAck(commandId, result) {
  if (peerSocket.readyState !== peerSocket.OPEN) return;
  try {
    peerSocket.send({ type: "command_ack", commandId, result });
  } catch (_) {
    // Redelivery is idempotent by matchId and will generate another ACK.
  }
}

function flush() {
  cancelRetry();
  if (persisted.outbox.length === 0 || peerSocket.readyState !== peerSocket.OPEN) {
    return;
  }
  try {
    const batch = fitMessageBatch(persisted.outbox);
    if (batch.length === 0) {
      elements.syncStatus.text = "EVENTO NON INVIABILE";
      return;
    }
    peerSocket.send({ type: "events", events: batch });
  } catch (_) {
    // The durable outbox remains on-device until the companion reconnects.
  }
  scheduleRetry();
}

function scheduleRetry() {
  if (!shouldRetryOnDevice(
    persisted.outbox.length,
    peerSocket.readyState === peerSocket.OPEN,
    display.on && !display.aodActive,
  )) return;
  retryTimer = setTimeout(() => {
    retryTimer = null;
    flush();
  }, DEVICE_RETRY_MS);
}

function cancelRetry() {
  if (retryTimer === null) return;
  clearTimeout(retryTimer);
  retryTimer = null;
}

function render() {
  const match = persisted.match;
  elements.pointScore.text = `${displayPoint(match, "TEAM_A")} - ${displayPoint(match, "TEAM_B")}`;
  elements.matchScore.text = `${match.setsA} SET ${match.setsB}  ·  ${match.gamesA} GAME ${match.gamesB}`;
  elements.pointSituation.text = pointSituation(match);
  // Sticky account/plan errors must not be wiped by outbox progress labels.
  const stickyTransport =
    lastTransportStatus === "pairing_required" ||
    lastTransportStatus === "rate_limited" ||
    lastTransportStatus === "premium_required";
  const transportLabel = stickyTransport
    ? statusCopy(lastTransportStatus)
    : null;
  // While the journal is still arriving the score on screen is not the real
  // one yet: say so instead of showing a silent partial score.
  const resumeLabel = isResumeIncomplete(pendingResume, match)
    ? resumeProgressLabel(pendingResume, match)
    : null;
  elements.syncStatus.text =
    resumeLabel ||
    transportLabel ||
    (match.complete
      ? "PARTITA COMPLETATA"
      : persisted.outbox.length === 0
        ? lastTransportStatus === "paired"
          ? "ACCOUNT COLLEGATO"
          : "SINCRONIZZATO"
        : peerSocket.readyState === peerSocket.OPEN
          ? `INVIO ${persisted.outbox.length}`
          : `SALVATO OFFLINE · ${persisted.outbox.length}`);

  const aod = Boolean(display.aodActive);
  const doneVisible = match.complete && !setupVisible && !finishVisible;
  const modalVisible = setupVisible || finishVisible || doneVisible || noticeVisible;
  const controlsVisible = !aod && !modalVisible;
  elements.title.style.display = aod ? "none" : "inline";
  elements.pointScore.y = aod ? "46%" : "17%";
  elements.pointScore.style.fill = aod ? "#b8b8b8" : "#ffffff";
  elements.matchScore.y = aod ? "59%" : "52%";
  elements.matchScore.style.fill = aod ? "#707070" : "#ffffff";
  elements.pointSituation.y = aod ? "67%" : "57%";
  elements.pointSituation.style.fill = aod ? "#626262" : "#c8f135";
  elements.syncStatus.style.display = aod ? "none" : "inline";
  elements.teamA.style.display = aod ? "none" : "inline";
  elements.teamB.style.display = aod ? "none" : "inline";
  elements.teamA.style.fill = aod
    ? "#000000"
    : match.paused ? "#172233" : "#17324d";
  elements.teamB.style.fill = aod
    ? "#000000"
    : match.paused ? "#172233" : "#244229";
  elements.labelA.style.display = aod ? "none" : "inline";
  elements.labelB.style.display = aod ? "none" : "inline";
  elements.undo.style.display = controlsVisible ? "inline" : "none";
  elements.undoLabel.style.display = controlsVisible ? "inline" : "none";
  elements.pauseResume.style.display = controlsVisible ? "inline" : "none";
  elements.pauseResumeLabel.style.display = controlsVisible ? "inline" : "none";
  elements.pauseResumeLabel.text = match.paused ? "RIPRENDI" : "PAUSA";
  elements.finish.style.display = controlsVisible ? "inline" : "none";
  elements.finishLabel.style.display = controlsVisible ? "inline" : "none";

  elements.startPanel.style.display = setupVisible && !aod ? "inline" : "none";
  elements.formatLabel.text = formatLabel(selectedFormatId);
  elements.recordingLabel.text = RECORDING_MODE_LABELS[selectedRecordingMode];
  elements.finishConfirm.style.display = finishVisible && !aod ? "inline" : "none";
  elements.finishSummary.text = `${displayPoint(match, "TEAM_A")} - ${displayPoint(match, "TEAM_B")}`;
  elements.matchDone.style.display = doneVisible && !aod ? "inline" : "none";
  elements.doneSummary.text = `SET ${match.setsA} - ${match.setsB}`;
  elements.doneSync.text = persisted.outbox.length === 0
    ? "SINCRONIZZATO"
    : `SALVATO · ${persisted.outbox.length} IN CODA`;
  elements.doneHealth.text = healthSummary(match);
  elements.subscriptionNotice.style.display = noticeVisible && !aod
    ? "inline"
    : "none";
}

/** Honest verdict: a short segment is never shown as the match duration. */
function healthSummary(match) {
  const recording = persisted.recording || defaultRecording(selectedRecordingMode);
  const quality = recordingQuality({
    mode: recording.mode,
    state: recording.state,
    segments: recording.segments,
    matchStartMs: matchStartedAtMs(match),
    matchEndMs: matchEndedAtMs(match),
    nowMs: Date.now(),
  });
  if (quality.completeness === "complete" || quality.completeness === "partial") {
    const minutes = Math.round(quality.recordedDurationMs / 60000);
    const total = Math.round(quality.matchDurationMs / 60000);
    return `${quality.label} · ${minutes}/${total} MIN`;
  }
  return quality.label;
}

function formatLabel(id) {
  if (id === "GOLDEN_BO3") return "GOLDEN POINT · 3 SET";
  if (id === "SUPER_TB_BO3") return "SUPER TIE-BREAK";
  if (id === "SINGLE_SET") return "PARTITA SECCA";
  if (id === "TRAINING") return "ALLENAMENTO LIBERO";
  return "VANTAGGI · 3 SET";
}

function acknowledgeSubscriptionNotice() {
  try {
    fs.writeFileSync(NOTICE_FILE, { acknowledged: true }, "json");
    noticeVisible = false;
  } catch (_) {
    vibration.start("nudge-max");
  }
  render();
}

function loadNoticeAcknowledged() {
  try {
    return fs.readFileSync(NOTICE_FILE, "json")?.acknowledged === true;
  } catch (_) {
    return false;
  }
}

function loadState() {
  try {
    const value = fs.readFileSync(STATE_FILE, "json");
    if (!value || !value.match || !Array.isArray(value.outbox)) return null;
    const started = value.match.started === true ||
      value.match.events?.length > 0 ||
      value.outbox.some(
        (event) => event.matchId === value.match.matchId && event.type === "MATCH_STARTED",
      );
    const base = createMatch(value.match.matchId, {
      assignedTeam: value.match.assignedTeam || null,
      format: value.match.format || {},
      started,
    });
    const match = mergeEvents(base, value.match.events || []);
    match.nextSequence = Math.max(
      match.nextSequence,
      Number(value.match.nextSequence) || 0,
    );
    return { ...value, match };
  } catch (_) {
    return null;
  }
}

function saveState() {
  try {
    fs.writeFileSync(STATE_FILE, persisted, "json");
    return true;
  } catch (_) {
    return false;
  }
}

function wireEvent(event, match) {
  return {
    eventId: event.eventId,
    matchId: match.matchId,
    type: event.type,
    ...(event.team || event.teamId
      ? { teamId: event.team || event.teamId }
      : {}),
    ...(event.targetEventId ? { targetEventId: event.targetEventId } : {}),
    timestampMs: event.timestampMs,
    sequence: event.sequence,
    sourceMethod: event.sourceMethod || "TAP",
    format: JSON.stringify(formatForWire(match.format)),
  };
}

function lifecycleEvent(type, matchId, sequence, format = null) {
  return {
    eventId: nextId(sequence),
    matchId,
    type,
    timestampMs: Date.now(),
    sequence,
    sourceMethod: "AUTO",
    ...(format ? { format: JSON.stringify(formatForWire(format)) } : {}),
  };
}

function formatForWire(format) {
  return {
    id: format.id || "ADV_BO3",
    name: format.name || "Vantaggi - meglio di 3",
    setsToWin: format.setsToWin || 2,
    gamesPerSet: format.gamesPerSet || format.gamesToWin || 6,
    goldenPoint: format.goldenPoint === true,
    tieBreakAtGamesAll: format.tieBreakAtGamesAll !== false,
    tieBreakPoints: format.tieBreakPoints || 7,
    superTieBreakDecider: format.superTieBreakDecider === true,
    superTieBreakPoints: format.superTieBreakPoints || 10,
    freePlay: format.freePlay === true,
  };
}

function nextId(_sequence) {
  return createEventId();
}

function statusCopy(value) {
  if (value === "paired") return "ACCOUNT COLLEGATO";
  if (value === "pairing_required") return "INSERISCI IL CODICE";
  if (value === "rate_limited") return "RIPROVA TRA POCO";
  if (value === "premium_required") return "RICHIEDE RALLYMATE PLUS";
  return "SALVATO SUL WATCH";
}
