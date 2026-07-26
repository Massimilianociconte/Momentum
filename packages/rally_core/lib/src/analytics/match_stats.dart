/// Single-match analytics computed from [PointRecord]s (PRD F1/F2, G2).
library;

import '../engine/point_record.dart';
import '../model/enums.dart';

const _maxPlausibleMatchDurationMs = 12 * 60 * 60 * 1000;

class TeamMatchStats {
  const TeamMatchStats({
    required this.team,
    required this.pointsWon,
    required this.pointsLost,
    required this.bestStreak,
    required this.decisivePointsPlayed,
    required this.decisivePointsWon,
    required this.breakPointsPlayed,
    required this.breakPointsConverted,
    required this.gamePointsSaved,
    required this.tieBreakPointsPlayed,
    required this.tieBreakPointsWon,
    required this.superTieBreakPointsPlayed,
    required this.superTieBreakPointsWon,
    required this.clutchScore,
    required this.pointsWonOnServe,
    required this.pointsPlayedOnServe,
  });

  final TeamId team;
  final int pointsWon;
  final int pointsLost;
  final int bestStreak;
  final int decisivePointsPlayed;
  final int decisivePointsWon;
  final int breakPointsPlayed;
  final int breakPointsConverted;
  final int gamePointsSaved;
  final int tieBreakPointsPlayed;
  final int tieBreakPointsWon;
  final int superTieBreakPointsPlayed;
  final int superTieBreakPointsWon;

  /// 0–100, weighted performance on decisive points.
  final int clutchScore;

  final int pointsWonOnServe;
  final int pointsPlayedOnServe;

  double get decisiveRate =>
      decisivePointsPlayed == 0 ? 0 : decisivePointsWon / decisivePointsPlayed;
  double get tieBreakRate =>
      tieBreakPointsPlayed == 0 ? 0 : tieBreakPointsWon / tieBreakPointsPlayed;
  double get serveHoldRate =>
      pointsPlayedOnServe == 0 ? 0 : pointsWonOnServe / pointsPlayedOnServe;
}

/// One entry of the momentum chart: cumulative point differential
/// (team A minus team B) after each rally.
class MomentumPoint {
  const MomentumPoint(this.pointIndex, this.diff, this.setIndex);
  final int pointIndex;
  final int diff;
  final int setIndex;
}

class KeyMoment {
  const KeyMoment({required this.description, required this.pointIndex});
  final String description;
  final int pointIndex;
}

class MatchStats {
  const MatchStats({
    required this.teamA,
    required this.teamB,
    required this.totalPoints,
    required this.momentum,
    required this.keyMoment,
    required this.durationMs,
    required this.thirdSetDrop,
  });

  final TeamMatchStats teamA;
  final TeamMatchStats teamB;
  final int totalPoints;
  final List<MomentumPoint> momentum;
  final KeyMoment? keyMoment;
  final int durationMs;

  /// Point-win-rate delta of team A in the deciding set vs previous sets
  /// (negative = calo nel terzo set). Null if no deciding set played.
  final double? thirdSetDrop;

  TeamMatchStats forTeam(TeamId t) => t == TeamId.a ? teamA : teamB;

  static MatchStats fromRecords(
    List<PointRecord> records, {
    int? durationMsOverride,
  }) {
    final momentum = <MomentumPoint>[];
    var diff = 0;
    for (final r in records) {
      diff += r.winner == TeamId.a ? 1 : -1;
      momentum.add(MomentumPoint(r.index, diff, r.setIndex));
    }

    final a = _teamStats(TeamId.a, records);
    final b = _teamStats(TeamId.b, records);

    final timestamps = records.map((record) => record.timestampMs);
    final minTimestamp = records.isEmpty
        ? 0
        : timestamps.reduce((a, b) => a < b ? a : b);
    final maxTimestamp = records.isEmpty
        ? 0
        : timestamps.reduce((a, b) => a > b ? a : b);
    final recordDurationMs = (maxTimestamp - minTimestamp)
        .clamp(0, _maxPlausibleMatchDurationMs)
        .toInt();
    final durationMs = (durationMsOverride ?? recordDurationMs)
        .clamp(0, _maxPlausibleMatchDurationMs)
        .toInt();

    return MatchStats(
      teamA: a,
      teamB: b,
      totalPoints: records.length,
      momentum: momentum,
      keyMoment: _keyMoment(records),
      durationMs: durationMs,
      thirdSetDrop: _thirdSetDrop(records),
    );
  }

  static TeamMatchStats _teamStats(TeamId team, List<PointRecord> records) {
    var won = 0, lost = 0, streak = 0, best = 0;
    var decP = 0, decW = 0;
    var bpP = 0, bpW = 0, gpSaved = 0;
    var tbP = 0, tbW = 0, stbP = 0, stbW = 0;
    var clutchNum = 0.0, clutchDen = 0.0;
    var serveW = 0, serveP = 0;

    for (final r in records) {
      final winnerIsTeam = r.winner == team;
      if (winnerIsTeam) {
        won++;
        streak++;
        if (streak > best) best = streak;
      } else {
        lost++;
        streak = 0;
      }

      final w = r.clutchWeight;
      if (w > 0) {
        decP++;
        clutchDen += w;
        if (winnerIsTeam) {
          decW++;
          clutchNum += w;
        }
      }
      if (r.breakPointFor.contains(team)) {
        bpP++;
        if (winnerIsTeam) bpW++;
      }
      // Game point against us that we won = saved.
      if (r.gamePointFor.contains(team.opponent) &&
          !r.gamePointFor.contains(team) &&
          winnerIsTeam) {
        gpSaved++;
      }
      if (r.inTieBreak) {
        tbP++;
        if (winnerIsTeam) tbW++;
      }
      if (r.inSuperTieBreak) {
        stbP++;
        if (winnerIsTeam) stbW++;
      }
      if (r.servingTeam == team) {
        serveP++;
        if (winnerIsTeam) serveW++;
      }
    }

    final clutch = clutchDen == 0
        ? 50
        : ((clutchNum / clutchDen) * 100).round();

    return TeamMatchStats(
      team: team,
      pointsWon: won,
      pointsLost: lost,
      bestStreak: best,
      decisivePointsPlayed: decP,
      decisivePointsWon: decW,
      breakPointsPlayed: bpP,
      breakPointsConverted: bpW,
      gamePointsSaved: gpSaved,
      tieBreakPointsPlayed: tbP,
      tieBreakPointsWon: tbW,
      superTieBreakPointsPlayed: stbP,
      superTieBreakPointsWon: stbW,
      clutchScore: clutch,
      pointsWonOnServe: serveW,
      pointsPlayedOnServe: serveP,
    );
  }

  static KeyMoment? _keyMoment(List<PointRecord> records) {
    if (records.isEmpty) return null;
    // Longest run of consecutive points by one team.
    TeamId? runTeam;
    var run = 0, bestRun = 0, bestEnd = 0;
    TeamId bestTeam = TeamId.a;
    for (final r in records) {
      if (r.winner == runTeam) {
        run++;
      } else {
        runTeam = r.winner;
        run = 1;
      }
      if (run > bestRun) {
        bestRun = run;
        bestEnd = r.index;
        bestTeam = r.winner;
      }
    }
    // Match points saved beat streaks as narrative.
    for (final r in records) {
      if (r.matchPointFor.isNotEmpty && !r.matchPointFor.contains(r.winner)) {
        return KeyMoment(
          description: 'Match point annullato',
          pointIndex: r.index,
        );
      }
    }
    if (bestRun >= 4) {
      final name = bestTeam == TeamId.a ? 'Noi' : 'Loro';
      return KeyMoment(
        description: 'Parziale di $bestRun punti di fila ($name)',
        pointIndex: bestEnd,
      );
    }
    return null;
  }

  static double? _thirdSetDrop(List<PointRecord> records) {
    final maxSet = records.isEmpty
        ? 0
        : records.map((r) => r.setIndex).reduce(_max);
    if (maxSet < 2) return null;
    final early = records.where((r) => r.setIndex < 2).toList();
    final late = records.where((r) => r.setIndex >= 2).toList();
    if (early.isEmpty || late.isEmpty) return null;
    double rate(List<PointRecord> rs) =>
        rs.where((r) => r.winner == TeamId.a).length / rs.length;
    return rate(late) - rate(early);
  }

  static int _max(int a, int b) => a > b ? a : b;
}
