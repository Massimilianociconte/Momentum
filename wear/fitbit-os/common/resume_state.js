/**
 * Guard for a RESUME_MATCH handoff whose journal is still arriving.
 *
 * The phone sends the match header first and the journal in chunks. Until the
 * watermark is reached the local match shows an incomplete score, so scoring
 * must stay blocked: a tap accepted at that moment would be appended to a
 * match whose real score is still on the way, and the two would diverge.
 *
 * The pending marker is part of the persisted state, so an app reload during
 * the transfer does not turn a half-restored match into a scoreable one.
 */

export function normalizePendingResume(value) {
  if (!value || typeof value !== "object") return null;
  const commandId = typeof value.commandId === "string" ? value.commandId : "";
  const matchId = typeof value.matchId === "string" ? value.matchId : "";
  const eventCount = Number(value.eventCount);
  if (!commandId || matchId.length < 3) return null;
  if (!Number.isFinite(eventCount) || eventCount < 1) return null;
  return { commandId: commandId, matchId: matchId, eventCount: eventCount };
}

/** True while the journal of [match] has not reached the expected watermark. */
export function isResumeIncomplete(pending, match) {
  const normalized = normalizePendingResume(pending);
  if (!normalized || !match) return false;
  if (match.matchId !== normalized.matchId) return false;
  const events = Array.isArray(match.events) ? match.events : [];
  return events.length < normalized.eventCount;
}

/** True when the watermark is reached and the command can be acknowledged. */
export function isResumeComplete(pending, match) {
  const normalized = normalizePendingResume(pending);
  if (!normalized || !match) return false;
  if (match.matchId !== normalized.matchId) return false;
  const events = Array.isArray(match.events) ? match.events : [];
  return events.length >= normalized.eventCount;
}

/** Progress label shown while the journal is still arriving. */
export function resumeProgressLabel(pending, match) {
  const normalized = normalizePendingResume(pending);
  if (!normalized || !match) return "";
  const events = Array.isArray(match.events) ? match.events : [];
  const received = Math.min(events.length, normalized.eventCount);
  return `RIPRESA ${received}/${normalized.eventCount}`;
}
