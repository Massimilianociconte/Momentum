/// Match duration derived from lifecycle events.
///
/// Only intervals in which the match is actively in progress are counted:
/// time between PAUSE and RESUME (or COMPLETE) is deliberately excluded.
library;

import '../model/enums.dart';
import '../model/match_event.dart';

const _maxPlausibleMatchDurationMs = 12 * 60 * 60 * 1000;
const _futureClockToleranceMs = 5 * 60 * 1000;

/// Returns active-play milliseconds for [events].
///
/// Event order is authoritative because phone and wearable clocks can drift.
/// [fallbackStartTimeMs] and [fallbackEndTimeMs] support legacy journals that
/// predate lifecycle events. A still-active match is closed at [nowMs].
int activeMatchDurationMs({
  required Iterable<MatchEvent> events,
  int? fallbackStartTimeMs,
  int? fallbackEndTimeMs,
  int? nowMs,
}) {
  final journal = events.toList(growable: false);
  final clock = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final latestPlausibleTimestamp = clock + _futureClockToleranceMs;

  int normalize(int timestampMs) =>
      timestampMs.clamp(0, latestPlausibleTimestamp).toInt();

  int? normalizedFallbackStart = fallbackStartTimeMs == null
      ? null
      : normalize(fallbackStartTimeMs);
  final normalizedFallbackEnd = fallbackEndTimeMs == null
      ? null
      : normalize(fallbackEndTimeMs);

  final hasStartEvent = journal.any(
    (event) => event.type == MatchEventType.matchStarted,
  );
  var status = MatchStatus.created;
  int? activeSince;
  var totalMs = 0;
  var manuallyCompleted = false;

  void begin(int timestampMs) {
    activeSince = normalize(timestampMs);
    status = MatchStatus.inProgress;
  }

  void close(int timestampMs) {
    final start = activeSince;
    if (start == null) return;
    final end = normalize(timestampMs);
    totalMs += (end - start).clamp(0, _maxPlausibleMatchDurationMs).toInt();
    activeSince = null;
  }

  // Old logs can contain points but no MATCH_STARTED. In that case the
  // durable row start is the best available beginning of active play.
  if (!hasStartEvent && normalizedFallbackStart != null) {
    begin(normalizedFallbackStart);
  }

  for (final event in journal) {
    final timestamp = normalize(event.timestampMs);
    switch (event.type) {
      case MatchEventType.matchStarted:
        if (status == MatchStatus.created) begin(timestamp);
      case MatchEventType.matchPaused:
        if (status == MatchStatus.inProgress) {
          close(timestamp);
          status = MatchStatus.paused;
        }
      case MatchEventType.matchResumed:
        if (status == MatchStatus.paused) begin(timestamp);
      case MatchEventType.pointTeamA:
      case MatchEventType.pointTeamB:
        if (status == MatchStatus.created) {
          begin(normalizedFallbackStart ?? timestamp);
        }
      case MatchEventType.matchCompleted:
        if (status == MatchStatus.inProgress) close(timestamp);
        status = MatchStatus.completed;
        manuallyCompleted = event.sourceMethod == SourceMethod.manualEdit;
      case MatchEventType.undo:
        // An undo can reopen an automatically completed match. Manual finish
        // is terminal and remains non-undoable in the scoring engine.
        if (status == MatchStatus.completed && !manuallyCompleted) {
          begin(timestamp);
        }
      case MatchEventType.scoreEdited:
      case MatchEventType.gameCompleted:
      case MatchEventType.setCompleted:
      case MatchEventType.sideChange:
      case MatchEventType.deviceJoinedMatch:
      case MatchEventType.deviceLeftMatch:
      case MatchEventType.teamConfirmed:
        break;
    }
  }

  if (status == MatchStatus.inProgress && activeSince != null) {
    close(normalizedFallbackEnd ?? clock);
  }

  return totalMs.clamp(0, _maxPlausibleMatchDurationMs).toInt();
}
