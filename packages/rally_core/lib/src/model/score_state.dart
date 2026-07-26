/// Derived score state (never persisted as source of truth — events are).
library;

import 'enums.dart';

/// Points inside a normal game, in tennis notation.
/// 0,1,2,3 = 0/15/30/40; ad = advantage (only with advantage scoring).
class GamePoints {
  const GamePoints(this.a, this.b, {this.advantage});

  final int a;
  final int b;
  final TeamId? advantage;

  static const labels = ['0', '15', '30', '40'];

  String labelFor(TeamId team) {
    if (advantage != null) return advantage == team ? 'AD' : '40';
    final v = team == TeamId.a ? a : b;
    return labels[v.clamp(0, 3)];
  }

  /// Short, glanceable context for mobile and wearable scoreboards.
  ///
  /// The score remains the source of truth; this copy only explains what the
  /// next rally means and can be announced by accessibility services.
  String? situationLabel({
    required bool goldenPoint,
    String teamALabel = 'NOI',
    String teamBLabel = 'LORO',
  }) {
    final holder = advantage;
    if (holder != null) {
      final label = holder == TeamId.a ? teamALabel : teamBLabel;
      return 'VANTAGGIO $label · un punto per il game';
    }
    if (isDeuce) {
      return goldenPoint
          ? '40 PARI · prossimo punto decisivo'
          : '40 PARI · si gioca ai vantaggi';
    }
    return null;
  }

  /// Deuce with golden point → next point wins the game.
  bool get isDeuce => advantage == null && a >= 3 && b >= 3;
}

/// A finished set, with optional tie-break detail.
class SetResult {
  const SetResult({
    required this.gamesA,
    required this.gamesB,
    this.tieBreakA,
    this.tieBreakB,
    this.isSuperTieBreak = false,
  });

  final int gamesA;
  final int gamesB;
  final int? tieBreakA;
  final int? tieBreakB;
  final bool isSuperTieBreak;

  TeamId get winner => gamesA > gamesB ? TeamId.a : TeamId.b;

  Map<String, Object?> toJson() => {
    'gamesA': gamesA,
    'gamesB': gamesB,
    if (tieBreakA != null) 'tieBreakA': tieBreakA,
    if (tieBreakB != null) 'tieBreakB': tieBreakB,
    'isSuperTieBreak': isSuperTieBreak,
  };

  factory SetResult.fromJson(Map<String, Object?> json) => SetResult(
    gamesA: json['gamesA'] as int,
    gamesB: json['gamesB'] as int,
    tieBreakA: json['tieBreakA'] as int?,
    tieBreakB: json['tieBreakB'] as int?,
    isSuperTieBreak: json['isSuperTieBreak'] as bool? ?? false,
  );
}

/// Full live snapshot, shown on watch and phone.
class MatchState {
  const MatchState({
    required this.status,
    required this.points,
    required this.gamesA,
    required this.gamesB,
    required this.setsA,
    required this.setsB,
    required this.completedSets,
    required this.servingTeam,
    required this.inTieBreak,
    required this.inSuperTieBreak,
    required this.tieBreakA,
    required this.tieBreakB,
    required this.freePlayA,
    required this.freePlayB,
    required this.totalGamesPlayed,
    required this.sideChangePending,
    this.winner,
  });

  final MatchStatus status;
  final GamePoints points;
  final int gamesA;
  final int gamesB;
  final int setsA;
  final int setsB;
  final List<SetResult> completedSets;
  final TeamId servingTeam;
  final bool inTieBreak;
  final bool inSuperTieBreak;
  final int tieBreakA;
  final int tieBreakB;

  /// Free-play (training) rally points.
  final int freePlayA;
  final int freePlayB;

  final int totalGamesPlayed;

  /// True right after an odd game (or every 6 points in tie-break):
  /// players should change ends.
  final bool sideChangePending;

  final TeamId? winner;

  bool get isCompleted => status == MatchStatus.completed;

  /// Compact display, e.g. "40-30 | 5-4 | 1-0" or "TB 5-3 | 6-6 | 0-0".
  /// Free-play (training) shows rally counters when no set structure is active.
  String get display {
    final sets = '$setsA-$setsB';
    final games = '$gamesA-$gamesB';
    if (inTieBreak || inSuperTieBreak) {
      final label = inSuperTieBreak ? 'STB' : 'TB';
      return '$label $tieBreakA-$tieBreakB | $games | $sets';
    }
    // Training free-play: games/sets stay 0 while freePlayA/B hold the score.
    if (gamesA == 0 &&
        gamesB == 0 &&
        setsA == 0 &&
        setsB == 0 &&
        completedSets.isEmpty &&
        (freePlayA > 0 || freePlayB > 0 || points.a == 0 && points.b == 0)) {
      // Prefer free-play counters when structured points are unused.
      if (points.a == 0 && points.b == 0) {
        return '$freePlayA-$freePlayB';
      }
    }
    return '${points.labelFor(TeamId.a)}-${points.labelFor(TeamId.b)} | $games | $sets';
  }

  Map<String, Object?> toJson() => {
    'status': status.wire,
    'pointsA': points.a,
    'pointsB': points.b,
    'advantage': points.advantage?.wire,
    'gamesA': gamesA,
    'gamesB': gamesB,
    'setsA': setsA,
    'setsB': setsB,
    'completedSets': completedSets.map((s) => s.toJson()).toList(),
    'servingTeam': servingTeam.wire,
    'inTieBreak': inTieBreak,
    'inSuperTieBreak': inSuperTieBreak,
    'tieBreakA': tieBreakA,
    'tieBreakB': tieBreakB,
    'freePlayA': freePlayA,
    'freePlayB': freePlayB,
    'totalGamesPlayed': totalGamesPlayed,
    'sideChangePending': sideChangePending,
    'winner': winner?.wire,
  };
}
