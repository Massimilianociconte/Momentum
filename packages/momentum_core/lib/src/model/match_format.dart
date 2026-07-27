/// Match formats (PRD C2).
library;

import 'enums.dart';

/// Fully describes how a padel match is scored.
///
/// Presets cover: set classico con vantaggi, Star Point, Golden Point,
/// tie-break, super tie-break come terzo set, meglio di 3, partita secca,
/// allenamento libero e formati custom.
class MatchFormat {
  const MatchFormat({
    required this.id,
    required this.name,
    this.formatSchemaVersion = currentSchemaVersion,
    this.setsToWin = 2,
    this.gamesPerSet = 6,
    this.gameScoringMode = GameScoringMode.goldenPoint,
    this.tieBreakAtGamesAll = true,
    this.tieBreakPoints = 7,
    this.tieBreakInDecidingSet = true,
    this.superTieBreakDecider = false,
    this.superTieBreakPoints = 10,
    this.freePlay = false,
  }) : assert(setsToWin >= 1 && setsToWin <= 3),
       assert(gamesPerSet >= 1);

  /// v3 adds [tieBreakInDecidingSet]. Companions that only understand v2 read
  /// it as `true`, so dispatchers must capability-gate a format that sets it
  /// to false — exactly like Star Point.
  static const currentSchemaVersion = 3;

  /// Stable identifier, part of the sync protocol.
  final String id;
  final String name;

  /// Version of the normalized format payload emitted by [toJson].
  final int formatSchemaVersion;

  /// Sets needed to win the match (2 = best of 3, 1 = one set / secca).
  final int setsToWin;

  /// Games needed to win a set (with 2-game margin, else tie-break).
  final int gamesPerSet;

  /// Rule applied when both pairs reach 40.
  final GameScoringMode gameScoringMode;

  /// Compatibility getter for callers written before format schema v2.
  ///
  /// New code must use [gameScoringMode], because `false` cannot distinguish
  /// Advantage from Star Point.
  bool get goldenPoint => gameScoringMode == GameScoringMode.goldenPoint;

  /// Tie-break at gamesPerSet-all (e.g. 6-6).
  final bool tieBreakAtGamesAll;
  final int tieBreakPoints;

  /// FIP Rule 1, Option 1.4: when previously agreed, the deciding set can be
  /// played without a tie-break, so at gamesPerSet-all the set continues until
  /// a pair leads by two games. Only meaningful when [tieBreakAtGamesAll].
  final bool tieBreakInDecidingSet;

  /// Replace the deciding set with a super tie-break.
  final bool superTieBreakDecider;
  final int superTieBreakPoints;

  /// Allenamento libero: rally point counting only, no games/sets.
  final bool freePlay;

  /// Best of 3, Golden Point, tie-break at 6-6.
  static const goldenPointBo3 = MatchFormat(
    id: 'GOLDEN_BO3',
    name: 'Golden point — meglio di 3',
  );

  /// Traditional advantage scoring, best of 3.
  static const advantageBo3 = MatchFormat(
    id: 'ADV_BO3',
    name: 'Vantaggi — meglio di 3',
    gameScoringMode: GameScoringMode.advantage,
  );

  /// FIP 2026 Star Point: two advantage cycles, then a deciding point.
  static const starPointBo3 = MatchFormat(
    id: 'STAR_POINT_BO3',
    name: 'Star Point — meglio di 3',
    gameScoringMode: GameScoringMode.starPoint,
  );

  /// Best of 3 with a 10-point super tie-break instead of the third set.
  static const superTieBreakBo3 = MatchFormat(
    id: 'SUPER_TB_BO3',
    name: 'Super tie-break al terzo',
    superTieBreakDecider: true,
  );

  /// FIP alternative score method 1(b): the deciding set is replaced by a
  /// 7-point tie-break.
  static const matchTieBreak7Bo3 = MatchFormat(
    id: 'MATCH_TB7_BO3',
    name: 'Tie-break decisivo a 7',
    superTieBreakDecider: true,
    superTieBreakPoints: 7,
  );

  /// FIP alternative score method 1(a): sets are won at 4 games, tie-break at
  /// 4-4.
  static const miniSetBo3 = MatchFormat(
    id: 'MINI_SET_BO3',
    name: 'Mini-set a 4 game',
    gamesPerSet: 4,
  );

  /// FIP Rule 1, Option 1.4: advantage scoring with a deciding set played to
  /// two games of margin instead of a tie-break.
  static const advantageDecidingSetBo3 = MatchFormat(
    id: 'ADV_NO_TB_THIRD_BO3',
    name: 'Terzo set senza tie-break',
    gameScoringMode: GameScoringMode.advantage,
    tieBreakInDecidingSet: false,
  );

  /// One-set match (partita secca).
  static const singleSet = MatchFormat(
    id: 'SINGLE_SET',
    name: 'Partita secca — 1 set',
    setsToWin: 1,
  );

  /// Free training: only counts points.
  static const training = MatchFormat(
    id: 'TRAINING',
    name: 'Allenamento libero',
    setsToWin: 1,
    freePlay: true,
  );

  static const presets = <MatchFormat>[
    goldenPointBo3,
    starPointBo3,
    advantageBo3,
    superTieBreakBo3,
    matchTieBreak7Bo3,
    miniSetBo3,
    advantageDecidingSetBo3,
    singleSet,
    training,
  ];

  /// Total sets that can be played.
  int get maxSets => setsToWin * 2 - 1;

  /// True when a companion older than schema v3 would score this format
  /// differently, because it cannot represent [tieBreakInDecidingSet].
  bool get requiresDecidingSetProtocol =>
      tieBreakAtGamesAll && !tieBreakInDecidingSet;

  Map<String, Object?> toJson() => {
    'formatSchemaVersion': currentSchemaVersion,
    'id': id,
    'name': name,
    'setsToWin': setsToWin,
    'gamesPerSet': gamesPerSet,
    'gameScoringMode': gameScoringMode.wire,
    // Kept during the schema-v2 transition for legacy readers. Star Point is
    // deliberately false; dispatchers must capability-gate legacy companions
    // because a boolean alone cannot represent the new rule.
    'goldenPoint': goldenPoint,
    'tieBreakAtGamesAll': tieBreakAtGamesAll,
    'tieBreakPoints': tieBreakPoints,
    // Schema v3. Legacy readers ignore it and score the deciding set with a
    // tie-break, so dispatchers capability-gate formats that set it to false.
    'tieBreakInDecidingSet': tieBreakInDecidingSet,
    'superTieBreakDecider': superTieBreakDecider,
    'superTieBreakPoints': superTieBreakPoints,
    'freePlay': freePlay,
  };

  factory MatchFormat.fromJson(Map<String, Object?> json) {
    final wire = json['gameScoringMode'] as String?;
    final explicitMode = wire == null
        ? null
        : GameScoringMode.tryFromWire(wire);
    final legacyGoldenPoint = json['goldenPoint'] as bool?;
    final mode =
        explicitMode ??
        (legacyGoldenPoint == false
            ? GameScoringMode.advantage
            : GameScoringMode.goldenPoint);
    return MatchFormat(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Custom',
      // Decoded formats are normalized to the current schema before they are
      // persisted or sent again, including legacy schema-v1 payloads.
      formatSchemaVersion: currentSchemaVersion,
      setsToWin: json['setsToWin'] as int? ?? 2,
      gamesPerSet: json['gamesPerSet'] as int? ?? 6,
      gameScoringMode: mode,
      tieBreakAtGamesAll: json['tieBreakAtGamesAll'] as bool? ?? true,
      tieBreakPoints: json['tieBreakPoints'] as int? ?? 7,
      // Absent in schema v1/v2 payloads: those formats always had a deciding
      // set tie-break, so `true` is the correct upgrade default.
      tieBreakInDecidingSet: json['tieBreakInDecidingSet'] as bool? ?? true,
      superTieBreakDecider: json['superTieBreakDecider'] as bool? ?? false,
      superTieBreakPoints: json['superTieBreakPoints'] as int? ?? 10,
      freePlay: json['freePlay'] as bool? ?? false,
    );
  }
}
