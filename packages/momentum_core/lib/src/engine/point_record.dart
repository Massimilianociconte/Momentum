/// Per-point analytics context, regenerated from the event log.
library;

import '../model/enums.dart';

/// One rally with full scoring context *before* the point was played.
/// This is the raw material for clutch score, momentum, decisive-game
/// analysis, tie-break performance, third-set drop, etc. (PRD F1/F2).
class PointRecord {
  const PointRecord({
    required this.index,
    required this.winner,
    required this.timestampMs,
    required this.setIndex,
    required this.gameIndexInSet,
    required this.inTieBreak,
    required this.inSuperTieBreak,
    required this.servingTeam,
    required this.gamePointFor,
    required this.setPointFor,
    required this.matchPointFor,
    required this.breakPointFor,
    required this.isDeucePoint,
    required this.isStarPoint,
    required this.sourceDevice,
    required this.sourceMethod,
    required this.scoreBefore,
    required this.scoreAfter,
  });

  final int index;
  final TeamId winner;
  final int timestampMs;

  /// 0-based set index at the time of the point.
  final int setIndex;

  /// 0-based game index within the set.
  final int gameIndexInSet;
  final bool inTieBreak;
  final bool inSuperTieBreak;
  final TeamId servingTeam;

  /// Teams that had game point before this rally (can be both at no-ad
  /// deuce? No: golden point means the winner takes the game, both are at
  /// game point — the set contains both teams in that case).
  final Set<TeamId> gamePointFor;
  final Set<TeamId> setPointFor;
  final Set<TeamId> matchPointFor;

  /// Receiving team having game point = break point.
  final Set<TeamId> breakPointFor;

  /// 40-40 (deuce or golden point situation).
  final bool isDeucePoint;

  /// Deciding point reached at deuce 3 in the FIP Star Point format.
  final bool isStarPoint;

  final SourceDevice sourceDevice;
  final SourceMethod sourceMethod;

  /// Full deterministic score context around this rally. These snapshots are
  /// rebuilt from the event log and never persisted as an independent source
  /// of truth. They let post-match analytics measure the structural importance
  /// of a point without guessing from a label such as "break point".
  final PointScoreSnapshot scoreBefore;
  final PointScoreSnapshot scoreAfter;

  PointRecord withScoreAfter(PointScoreSnapshot value) => PointRecord(
    index: index,
    winner: winner,
    timestampMs: timestampMs,
    setIndex: setIndex,
    gameIndexInSet: gameIndexInSet,
    inTieBreak: inTieBreak,
    inSuperTieBreak: inSuperTieBreak,
    servingTeam: servingTeam,
    gamePointFor: gamePointFor,
    setPointFor: setPointFor,
    matchPointFor: matchPointFor,
    breakPointFor: breakPointFor,
    isDeucePoint: isDeucePoint,
    isStarPoint: isStarPoint,
    sourceDevice: sourceDevice,
    sourceMethod: sourceMethod,
    scoreBefore: scoreBefore,
    scoreAfter: value,
  );

  /// A point is "decisive" for [team] when the team faced or held a
  /// game/set/match point, or it was a deuce/golden point, or late tie-break.
  bool isDecisiveFor(TeamId team) =>
      gamePointFor.isNotEmpty ||
      setPointFor.isNotEmpty ||
      matchPointFor.isNotEmpty ||
      isDeucePoint;

  /// Weight used by the clutch score.
  double get clutchWeight {
    if (matchPointFor.isNotEmpty) return 2.0;
    if (setPointFor.isNotEmpty) return 1.5;
    if (inSuperTieBreak) return 1.4;
    if (inTieBreak) return 1.2;
    if (breakPointFor.isNotEmpty) return 1.2;
    if (gamePointFor.isNotEmpty || isDeucePoint) return 1.0;
    return 0.0;
  }
}

/// Compact score snapshot used exclusively by deterministic post-match
/// analysis. It mirrors the scoring engine state but deliberately excludes UI
/// strings and sync metadata.
class PointScoreSnapshot {
  const PointScoreSnapshot({
    required this.pointsA,
    required this.pointsB,
    required this.gamesA,
    required this.gamesB,
    required this.setsA,
    required this.setsB,
    required this.inTieBreak,
    required this.inSuperTieBreak,
    required this.tieBreakA,
    required this.tieBreakB,
    required this.freePlayA,
    required this.freePlayB,
    required this.deuceNumber,
    required this.completed,
    this.winner,
  });

  /// Internal game counters: 0..3 are 0/15/30/40 and 4 is advantage.
  final int pointsA;
  final int pointsB;
  final int gamesA;
  final int gamesB;
  final int setsA;
  final int setsB;
  final bool inTieBreak;
  final bool inSuperTieBreak;
  final int tieBreakA;
  final int tieBreakB;
  final int freePlayA;
  final int freePlayB;
  final int deuceNumber;
  final bool completed;
  final TeamId? winner;
}
