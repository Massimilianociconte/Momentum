import { me as companion } from "companion";
import { peerSocket } from "messaging";
import { settingsStorage } from "settings";

import { GATEWAY_URL } from "./runtime-config";
import { companionWakeInterval } from "../common/power_policy";
import {
  RALLYMATE_MESSAGE_BUDGET_BYTES,
  utf8ByteLength,
} from "../common/message_batch";

const TOKEN_KEY = "rallymate.fitbit.deviceToken";
const PAIRING_KEY = "pairingCode";
let sending = false;
let pulling = false;
let pending = loadPending();
let activeMatch = false;

settingsStorage.addEventListener("change", (event) => {
  if (event.key === PAIRING_KEY) claimPairing().catch(reportTemporaryFailure);
});
peerSocket.onmessage = (event) => {
  if (event.data && event.data.type === "events" && Array.isArray(event.data.events)) {
    enqueue(event.data.events);
    flush().catch(reportTemporaryFailure);
  } else if (event.data && event.data.type === "request_commands") {
    pollCommands().catch(reportTemporaryFailure);
  } else if (event.data && event.data.type === "command_ack") {
    acknowledgeCommand(event.data).catch(reportTemporaryFailure);
  }
};
peerSocket.onopen = () => {
  sendStatus(token() ? "paired" : "pairing_required");
  flush().catch(reportTemporaryFailure);
  pollCommands().catch(reportTemporaryFailure);
};

if (companion.permissions.granted("run_background")) {
  updateWakeInterval();
  companion.addEventListener("wakeinterval", () => {
    flush().catch(reportTemporaryFailure);
    pollCommands().catch(reportTemporaryFailure);
  });
}

claimPairing().catch(() => sendStatus(token() ? "paired" : "pairing_required"));

async function claimPairing() {
  const code = setting(PAIRING_KEY).replace(/[^a-z0-9]/gi, "").toUpperCase();
  if (code.length !== 8 || token()) return;
  const response = await request({
    action: "claim",
    provider: "FITBIT_OS",
    code,
    displayName: "Fitbit OS watch",
    capabilities: ["scoring", "duo", "offline", "haptics", "aod"],
  });
  if (!response.ok || typeof response.body.token !== "string") {
    sendStatus(response.status === 429 ? "rate_limited" : "pairing_required");
    return;
  }
  localStorage.setItem(TOKEN_KEY, response.body.token);
  settingsStorage.removeItem(PAIRING_KEY);
  sendStatus("paired");
  await flush();
  await pollCommands();
}

async function pollCommands() {
  const credential = token();
  if (pulling || !credential || peerSocket.readyState !== peerSocket.OPEN) return;
  pulling = true;
  try {
    const response = await request(
      { action: "commands" },
      { authorization: `Wearable ${credential}` },
    );
    if (response.status === 401) {
      localStorage.removeItem(TOKEN_KEY);
      sendStatus("pairing_required");
      return;
    }
    if (response.status === 403) {
      sendStatus("premium_required");
      return;
    }
    const command = Array.isArray(response.body.commands)
      ? response.body.commands[0]
      : null;
    if (!command) return;
    if (command.command_type === "RESUME_MATCH") {
      await deliverResume(command);
      return;
    }
    const message = {
      type: "start_match",
      commandId: command.command_id,
      ...(command.payload || {}),
    };
    if (JSON.stringify(message).length > 900) {
      await acknowledgeCommand({
        commandId: command.command_id,
        result: "REJECTED",
      });
      return;
    }
    send(message);
  } finally {
    pulling = false;
  }
}

// RESUME_MATCH carries the full phone journal: too large for a single
// peerSocket message, so it ships as a header followed by remote_events
// chunks. The watch acks APPLIED only once the whole journal is merged, so
// an interrupted delivery is simply redelivered on the next poll.
async function deliverResume(command) {
  const payload = command.payload || {};
  const events = Array.isArray(payload.events) ? payload.events : [];
  const header = {
    type: "resume_match",
    commandId: command.command_id,
    matchId: payload.matchId,
    format: payload.format,
    assignedTeam: payload.assignedTeam,
    teamName: payload.teamName,
    eventCount: events.length,
  };
  if (
    events.length === 0 ||
    utf8ByteLength(JSON.stringify(header)) > RALLYMATE_MESSAGE_BUDGET_BYTES
  ) {
    await acknowledgeCommand({
      commandId: command.command_id,
      result: "REJECTED",
    });
    return;
  }
  const batches = [];
  let batch = [];
  for (const event of events) {
    const candidate = batch.concat(event);
    const encoded = JSON.stringify({
      type: "remote_events",
      matchId: payload.matchId,
      events: candidate,
    });
    if (utf8ByteLength(encoded) <= RALLYMATE_MESSAGE_BUDGET_BYTES) {
      batch = candidate;
      continue;
    }
    if (batch.length === 0) {
      // A single event exceeding the budget can never be delivered.
      await acknowledgeCommand({
        commandId: command.command_id,
        result: "REJECTED",
      });
      return;
    }
    batches.push(batch);
    batch = [event];
  }
  if (batch.length > 0) batches.push(batch);
  send(header);
  for (const chunk of batches) {
    send({ type: "remote_events", matchId: payload.matchId, events: chunk });
  }
}

async function acknowledgeCommand(message) {
  const credential = token();
  if (!credential || typeof message.commandId !== "string") return;
  const result = message.result === "APPLIED" ? "APPLIED" : "REJECTED";
  const response = await request(
    {
      action: "acknowledge_command",
      commandId: message.commandId,
      result,
    },
    { authorization: `Wearable ${credential}` },
  );
  if (response.ok) await pollCommands();
}

function enqueue(events) {
  const known = new Set(pending.map((event) => event.eventId));
  for (const event of events) {
    if (event && typeof event.eventId === "string" && !known.has(event.eventId)) {
      pending.push(event);
      known.add(event.eventId);
    }
    if (event?.type === "MATCH_STARTED" || event?.type === "MATCH_RESUMED") {
      activeMatch = true;
    } else if (event?.type === "MATCH_COMPLETED") {
      activeMatch = false;
    }
  }
  if (pending.length > 500) pending = pending.slice(-500);
  savePending();
  updateWakeInterval();
}

async function flush() {
  const credential = token();
  if (sending || !credential || pending.length === 0) {
    if (!credential) sendStatus("pairing_required");
    return;
  }
  sending = true;
  const batch = pending.slice(0, 50);
  try {
    const response = await request(
      { action: "ingest", events: batch },
      { authorization: `Wearable ${credential}` },
    );
    if (response.status === 401) {
      localStorage.removeItem(TOKEN_KEY);
      sendStatus("pairing_required");
      return;
    }
    if (response.status === 403 && response.body.error === "plan_required") {
      sendStatus("premium_required");
      return;
    }
    if (!response.ok) {
      sendStatus(response.status === 429 ? "rate_limited" : "offline");
      return;
    }
    const accepted = new Set(batch.map((event) => event.eventId));
    pending = pending.filter((event) => !accepted.has(event.eventId));
    savePending();
    updateWakeInterval();
    send({ type: "ack", eventIds: [...accepted] });
    if (pending.length > 0) setTimeout(() => flush().catch(reportTemporaryFailure), 250);
  } finally {
    sending = false;
  }
}

function updateWakeInterval() {
  if (!companion.permissions.granted("run_background")) return;
  companion.wakeInterval = companionWakeInterval(pending.length, activeMatch);
}

function loadPending() {
  try {
    const value = JSON.parse(localStorage.getItem("rallymate.fitbit.pending") || "[]");
    return Array.isArray(value) ? value.slice(-500) : [];
  } catch (_) {
    return [];
  }
}

function savePending() {
  try {
    localStorage.setItem("rallymate.fitbit.pending", JSON.stringify(pending));
  } catch (_) {
    // The watch retains its durable outbox and will retransmit after reconnect.
  }
}

async function request(body, extraHeaders = {}) {
  const response = await fetch(GATEWAY_URL, {
    method: "POST",
    headers: { "content-type": "application/json", ...extraHeaders },
    body: JSON.stringify(body),
  });
  let value = {};
  try {
    value = await response.json();
  } catch (_) {
    // Empty or non-JSON errors are represented by the HTTP status only.
  }
  return { ok: response.ok, status: response.status, body: value };
}

function setting(key) {
  const raw = settingsStorage.getItem(key);
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed === "string") return parsed.trim();
    if (parsed && typeof parsed.value === "string") return parsed.value.trim();
  } catch (_) {
    return raw.trim();
  }
  return "";
}

function token() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

function sendStatus(value) {
  send({ type: "status", value });
}

function send(message) {
  if (peerSocket.readyState !== peerSocket.OPEN) return;
  try {
    peerSocket.send(message);
  } catch (_) {
    // Device will ask again after the next peerSocket reconnect.
  }
}

function reportTemporaryFailure() {
  sendStatus("offline");
}
