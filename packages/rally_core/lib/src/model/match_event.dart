/// Event-sourced match log (PRD data model + Rischio 1 mitigation).
library;

import 'enums.dart';

/// Immutable match event. The full score is always reconstructable by
/// replaying events in order (acceptance criteria: "il punteggio deve essere
/// ricostruibile dagli eventi").
class MatchEvent {
  const MatchEvent({
    required this.eventId,
    required this.matchId,
    required this.timestampMs,
    required this.type,
    this.teamId,
    this.scoreBefore,
    this.scoreAfter,
    this.sourceDevice = SourceDevice.phone,
    this.sourceMethod = SourceMethod.tap,
    this.synced = false,
    this.payload,
    this.sourceUserId,
    this.sourceTeamId,
    this.duoMode = false,
    this.createdLocallyAtMs,
  });

  final String eventId;
  final String matchId;

  /// Epoch millis UTC. Monotonic ordering is guaranteed by sequence in the
  /// list, not by the clock (watches can drift).
  final int timestampMs;
  final MatchEventType type;

  /// Scoring team for POINT_* events.
  final TeamId? teamId;

  /// Compact display score strings, e.g. "40-30 | 5-4 | 1-0" (audit only,
  /// never used to derive state).
  final String? scoreBefore;
  final String? scoreAfter;

  final SourceDevice sourceDevice;
  final SourceMethod sourceMethod;
  final bool synced;

  /// Extra data (e.g. SCORE_EDITED carries the explicit new score).
  final Map<String, Object?>? payload;

  /// Duo Mode attribution: cloud user id of the account whose device
  /// generated the event (audit + server-side authorization).
  final String? sourceUserId;

  /// Duo Mode attribution: the team the generating device is assigned to.
  final TeamId? sourceTeamId;

  /// True when the event was generated inside a Duo Mode session.
  final bool duoMode;

  /// Duo Mode offline queue: when the event was created on the device,
  /// before any sync happened (server keeps its own received timestamp).
  final int? createdLocallyAtMs;

  MatchEvent copyWith({bool? synced, String? scoreBefore, String? scoreAfter}) {
    return MatchEvent(
      eventId: eventId,
      matchId: matchId,
      timestampMs: timestampMs,
      type: type,
      teamId: teamId,
      scoreBefore: scoreBefore ?? this.scoreBefore,
      scoreAfter: scoreAfter ?? this.scoreAfter,
      sourceDevice: sourceDevice,
      sourceMethod: sourceMethod,
      synced: synced ?? this.synced,
      payload: payload,
      sourceUserId: sourceUserId,
      sourceTeamId: sourceTeamId,
      duoMode: duoMode,
      createdLocallyAtMs: createdLocallyAtMs,
    );
  }

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'matchId': matchId,
    'ts': timestampMs,
    'type': type.wire,
    if (teamId != null) 'teamId': teamId!.wire,
    if (scoreBefore != null) 'scoreBefore': scoreBefore,
    if (scoreAfter != null) 'scoreAfter': scoreAfter,
    'sourceDevice': sourceDevice.wire,
    'sourceMethod': sourceMethod.wire,
    'synced': synced,
    if (payload != null) 'payload': payload,
    // Duo Mode extras: emitted only when set, so the wire format stays
    // byte-compatible with pre-duo watch builds.
    if (sourceUserId != null) 'sourceUserId': sourceUserId,
    if (sourceTeamId != null) 'sourceTeamId': sourceTeamId!.wire,
    if (duoMode) 'duo': true,
    if (createdLocallyAtMs != null) 'createdLocallyAt': createdLocallyAtMs,
  };

  factory MatchEvent.fromJson(Map<String, Object?> json) => MatchEvent(
    eventId: json['eventId'] as String,
    matchId: json['matchId'] as String,
    timestampMs: json['ts'] as int,
    type: MatchEventType.fromWire(json['type'] as String),
    teamId: json['teamId'] == null
        ? null
        : TeamId.fromWire(json['teamId'] as String),
    scoreBefore: json['scoreBefore'] as String?,
    scoreAfter: json['scoreAfter'] as String?,
    sourceDevice: SourceDevice.fromWire(
      json['sourceDevice'] as String? ?? 'PHONE',
    ),
    sourceMethod: SourceMethod.fromWire(
      json['sourceMethod'] as String? ?? 'TAP',
    ),
    synced: json['synced'] as bool? ?? false,
    payload: (json['payload'] as Map?)?.cast<String, Object?>(),
    sourceUserId: json['sourceUserId'] as String?,
    sourceTeamId: json['sourceTeamId'] == null
        ? null
        : TeamId.fromWire(json['sourceTeamId'] as String),
    duoMode: json['duo'] as bool? ?? false,
    createdLocallyAtMs: json['createdLocallyAt'] as int?,
  );
}
