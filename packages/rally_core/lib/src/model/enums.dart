/// Core enums shared across phone/watch/backend.
///
/// Wire values (`wire`) are the canonical strings used in the JSON sync
/// protocol and in the Kotlin (Wear OS) and Swift (watchOS) ports. Never
/// rename a wire value without a protocol version bump.
library;

/// One of the two sides on court.
enum TeamId {
  a('TEAM_A'),
  b('TEAM_B');

  const TeamId(this.wire);
  final String wire;

  TeamId get opponent => this == TeamId.a ? TeamId.b : TeamId.a;

  static TeamId fromWire(String w) =>
      TeamId.values.firstWhere((e) => e.wire == w);
}

/// Padel role. Role drives which analytics and advice are shown (PRD A1/F3).
enum PadelRole {
  left('LEFT'),
  right('RIGHT'),
  flex('FLEX'),
  undefined('UNDEFINED');

  const PadelRole(this.wire);
  final String wire;

  static PadelRole fromWire(String w) =>
      PadelRole.values.firstWhere((e) => e.wire == w, orElse: () => undefined);
}

enum DominantHand {
  rightHand('RIGHT'),
  leftHand('LEFT');

  const DominantHand(this.wire);
  final String wire;

  static DominantHand fromWire(String w) => DominantHand.values.firstWhere(
    (e) => e.wire == w,
    orElse: () => rightHand,
  );
}

/// Self-declared player level, also used for opponent difficulty inputs.
enum PlayerLevel {
  beginner('BEGINNER', 1.0),
  improver('IMPROVER', 2.0),
  intermediate('INTERMEDIATE', 3.0),
  advanced('ADVANCED', 4.0),
  competition('COMPETITION', 5.0);

  const PlayerLevel(this.wire, this.numeric);
  final String wire;
  final double numeric;

  static PlayerLevel fromWire(String w) => PlayerLevel.values.firstWhere(
    (e) => e.wire == w,
    orElse: () => intermediate,
  );
}

/// Opponent tags (PRD C3). Feed rankings and streaks.
enum OpponentTag {
  beginners('BEGINNERS'),
  sameLevel('SAME_LEVEL'),
  slightlyStronger('SLIGHTLY_STRONGER'),
  muchStronger('MUCH_STRONGER'),
  defensive('DEFENSIVE'),
  aggressive('AGGRESSIVE'),
  regular('REGULAR'),
  irregular('IRREGULAR'),
  leftHanded('LEFT_HANDED'),
  fixedPair('FIXED_PAIR'),
  occasionalPair('OCCASIONAL_PAIR'),
  tournament('TOURNAMENT'),
  friendly('FRIENDLY');

  const OpponentTag(this.wire);
  final String wire;

  static OpponentTag? tryFromWire(String w) {
    for (final t in OpponentTag.values) {
      if (t.wire == w) return t;
    }
    return null;
  }
}

/// Opponent Difficulty Score (PRD F5): 1 = molto più facile … 5 = molto più
/// difficile.
enum OpponentDifficulty {
  muchEasier(1, 'MUCH_EASIER'),
  easier(2, 'EASIER'),
  sameLevel(3, 'SAME_LEVEL'),
  harder(4, 'HARDER'),
  muchHarder(5, 'MUCH_HARDER');

  const OpponentDifficulty(this.score, this.wire);
  final int score;
  final String wire;

  static OpponentDifficulty fromScore(num s) {
    final v = s.round().clamp(1, 5);
    return OpponentDifficulty.values.firstWhere((e) => e.score == v);
  }

  static OpponentDifficulty fromWire(String w) => OpponentDifficulty.values
      .firstWhere((e) => e.wire == w, orElse: () => sameLevel);
}

enum MatchStatus {
  created('CREATED'),
  inProgress('IN_PROGRESS'),
  paused('PAUSED'),
  completed('COMPLETED'),
  abandoned('ABANDONED');

  const MatchStatus(this.wire);
  final String wire;

  static MatchStatus fromWire(String w) =>
      MatchStatus.values.firstWhere((e) => e.wire == w);
}

/// Event types (PRD data model, MatchEvent).
enum MatchEventType {
  matchStarted('MATCH_STARTED'),
  pointTeamA('POINT_TEAM_A'),
  pointTeamB('POINT_TEAM_B'),
  undo('UNDO'),
  gameCompleted('GAME_COMPLETED'),
  setCompleted('SET_COMPLETED'),
  sideChange('SIDE_CHANGE'),
  matchPaused('MATCH_PAUSED'),
  matchResumed('MATCH_RESUMED'),
  matchCompleted('MATCH_COMPLETED'),
  scoreEdited('SCORE_EDITED'),
  // Duo Mode session lifecycle (audit-only on replay).
  deviceJoinedMatch('DEVICE_JOINED_MATCH'),
  deviceLeftMatch('DEVICE_LEFT_MATCH'),
  teamConfirmed('TEAM_CONFIRMED');

  const MatchEventType(this.wire);
  final String wire;

  static MatchEventType fromWire(String w) =>
      MatchEventType.values.firstWhere((e) => e.wire == w);

  static MatchEventType? tryFromWire(String w) {
    for (final t in MatchEventType.values) {
      if (t.wire == w) return t;
    }
    return null;
  }
}

/// Where the event was produced.
enum SourceDevice {
  phone('PHONE'),
  appleWatch('APPLE_WATCH'),
  wearOs('WEAR_OS'),
  garmin('GARMIN_CONNECT_IQ'),
  fitbit('FITBIT_OS');

  const SourceDevice(this.wire);
  final String wire;

  static SourceDevice fromWire(String w) =>
      SourceDevice.values.firstWhere((e) => e.wire == w, orElse: () => phone);
}

/// How the event was produced (PRD D1-D3).
enum SourceMethod {
  tap('TAP'),
  blindTap('BLIND_TAP'),
  voice('VOICE'),
  manualEdit('MANUAL_EDIT'),
  auto('AUTO');

  const SourceMethod(this.wire);
  final String wire;

  static SourceMethod fromWire(String w) =>
      SourceMethod.values.firstWhere((e) => e.wire == w, orElse: () => tap);
}
