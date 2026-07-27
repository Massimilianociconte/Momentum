/// Cross-match analytics: weekly summary, progressi/regressioni,
/// per-team/per-role/per-opponent breakdowns, elo-lite rating (PRD B2/B3/F).
library;

import 'dart:math' as math;

import 'advanced_match_analysis.dart';
import '../model/enums.dart';

/// Storage-agnostic summary of one completed match. The app maps its DB rows
/// into this; watch and backend use the same shape.
class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.endTimeMs,
    required this.won,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.gamesFor,
    required this.gamesAgainst,
    required this.setsFor,
    required this.setsAgainst,
    required this.clutchScore,
    required this.bestStreak,
    required this.durationMs,
    this.teamId,
    this.roleplayed = PadelRole.undefined,
    this.opponentDifficulty = OpponentDifficulty.sameLevel,
    this.opponentTags = const {},
    this.tieBreakPointsWon = 0,
    this.tieBreakPointsPlayed = 0,
    this.superTieBreakPointsWon = 0,
    this.superTieBreakPointsPlayed = 0,
    this.decisivePointsWon = 0,
    this.decisivePointsPlayed = 0,
    this.advancedAnalysis,
  });

  final String matchId;
  final int endTimeMs;
  final bool won;
  final int pointsFor;
  final int pointsAgainst;
  final int gamesFor;
  final int gamesAgainst;
  final int setsFor;
  final int setsAgainst;
  final int clutchScore;
  final int bestStreak;
  final int durationMs;
  final String? teamId;
  final PadelRole roleplayed;
  final OpponentDifficulty opponentDifficulty;
  final Set<OpponentTag> opponentTags;
  final int tieBreakPointsWon;
  final int tieBreakPointsPlayed;
  final int superTieBreakPointsWon;
  final int superTieBreakPointsPlayed;
  final int decisivePointsWon;
  final int decisivePointsPlayed;
  final AdvancedMatchAnalysis? advancedAnalysis;

  int get totalPoints => pointsFor + pointsAgainst;

  MatchSummary copyWith({
    int? clutchScore,
    AdvancedMatchAnalysis? advancedAnalysis,
  }) => MatchSummary(
    matchId: matchId,
    endTimeMs: endTimeMs,
    won: won,
    pointsFor: pointsFor,
    pointsAgainst: pointsAgainst,
    gamesFor: gamesFor,
    gamesAgainst: gamesAgainst,
    setsFor: setsFor,
    setsAgainst: setsAgainst,
    clutchScore: clutchScore ?? this.clutchScore,
    bestStreak: bestStreak,
    durationMs: durationMs,
    teamId: teamId,
    roleplayed: roleplayed,
    opponentDifficulty: opponentDifficulty,
    opponentTags: opponentTags,
    tieBreakPointsWon: tieBreakPointsWon,
    tieBreakPointsPlayed: tieBreakPointsPlayed,
    superTieBreakPointsWon: superTieBreakPointsWon,
    superTieBreakPointsPlayed: superTieBreakPointsPlayed,
    decisivePointsWon: decisivePointsWon,
    decisivePointsPlayed: decisivePointsPlayed,
    advancedAnalysis: advancedAnalysis ?? this.advancedAnalysis,
  );
}

/// Cross-match evidence aggregated from versioned post-match analyses.
/// Counts are pooled before rates are calculated, avoiding an unweighted
/// average that would let a 10-point match count as much as a 150-point match.
class AnalyticsPortfolio {
  const AnalyticsPortfolio({
    required this.analyzedMatches,
    required this.totalPoints,
    required this.pointWinRate,
    required this.servePointWinRate,
    required this.returnPointWinRate,
    required this.pressurePointWinRate,
    required this.breakPointConversion,
    required this.gamePointSaveRate,
    required this.closingPointRate,
    required this.clutchScore,
    required this.clutchDelta,
    required this.comebackWins,
    required this.confirmedTurningPoints,
    required this.momentumPhases,
    required this.latePhaseDelta,
    required this.latePhaseSignalSupported,
    required this.quality,
  });

  final int analyzedMatches;
  final int totalPoints;
  final RateEstimate pointWinRate;
  final RateEstimate servePointWinRate;
  final RateEstimate returnPointWinRate;
  final RateEstimate pressurePointWinRate;
  final RateEstimate breakPointConversion;
  final RateEstimate gamePointSaveRate;
  final RateEstimate closingPointRate;
  final double? clutchScore;
  final double? clutchDelta;
  final int comebackWins;
  final int confirmedTurningPoints;
  final int momentumPhases;
  final double? latePhaseDelta;
  final bool latePhaseSignalSupported;
  final EvidenceQuality quality;

  static const empty = AnalyticsPortfolio(
    analyzedMatches: 0,
    totalPoints: 0,
    pointWinRate: RateEstimate.empty,
    servePointWinRate: RateEstimate.empty,
    returnPointWinRate: RateEstimate.empty,
    pressurePointWinRate: RateEstimate.empty,
    breakPointConversion: RateEstimate.empty,
    gamePointSaveRate: RateEstimate.empty,
    closingPointRate: RateEstimate.empty,
    clutchScore: null,
    clutchDelta: null,
    comebackWins: 0,
    confirmedTurningPoints: 0,
    momentumPhases: 0,
    latePhaseDelta: null,
    latePhaseSignalSupported: false,
    quality: EvidenceQuality.insufficient,
  );

  factory AnalyticsPortfolio.fromMatches(List<MatchSummary> matches) {
    final analyses = matches
        .map((match) => match.advancedAnalysis)
        .whereType<AdvancedMatchAnalysis>()
        .where(
          (analysis) =>
              analysis.version == AdvancedMatchAnalysis.currentVersion,
        )
        .toList(growable: false);
    if (analyses.isEmpty) return empty;

    RateEstimate pool(RateEstimate Function(AdvancedMatchAnalysis) select) {
      var successes = 0;
      var trials = 0;
      for (final analysis in analyses) {
        final rate = select(analysis);
        successes += rate.successes;
        trials += rate.trials;
      }
      return RateEstimate.fromCounts(successes, trials);
    }

    final pointRate = pool((analysis) => analysis.pointWinRate);
    final pressure = pool((analysis) => analysis.pressurePointWinRate);
    const priorStrength = 12.0;
    final clutch = pressure.trials == 0
        ? null
        : (pressure.successes + priorStrength * pointRate.rate) /
              (pressure.trials + priorStrength);
    final first = pool((analysis) => analysis.firstPhasePointRate);
    final last = pool((analysis) => analysis.finalPhasePointRate);
    final lateDelta = first.hasEvidence && last.hasEvidence
        ? last.rate - first.rate
        : null;
    final lateSupported =
        lateDelta != null &&
        lateDelta.abs() >= 0.08 &&
        (last.lower > first.upper || last.upper < first.lower);
    final totalPoints = analyses.fold<int>(
      0,
      (sum, analysis) => sum + analysis.totalPoints,
    );
    final quality = analyses.length >= 8 && totalPoints >= 500
        ? EvidenceQuality.reliable
        : analyses.length >= 3 && totalPoints >= 140
        ? EvidenceQuality.developing
        : EvidenceQuality.insufficient;

    return AnalyticsPortfolio(
      analyzedMatches: analyses.length,
      totalPoints: totalPoints,
      pointWinRate: pointRate,
      servePointWinRate: pool((analysis) => analysis.servePointWinRate),
      returnPointWinRate: pool((analysis) => analysis.returnPointWinRate),
      pressurePointWinRate: pressure,
      breakPointConversion: pool((analysis) => analysis.breakPointConversion),
      gamePointSaveRate: pool((analysis) => analysis.gamePointSaveRate),
      closingPointRate: pool((analysis) => analysis.closingPointRate),
      clutchScore: clutch,
      clutchDelta: clutch == null ? null : clutch - pointRate.rate,
      comebackWins: analyses
          .where(
            (analysis) => (analysis.lowestWinProbabilityInVictory ?? 1) <= 0.30,
          )
          .length,
      confirmedTurningPoints: analyses.fold<int>(
        0,
        (sum, analysis) => sum + analysis.turningPoints.length,
      ),
      momentumPhases: analyses.fold<int>(
        0,
        (sum, analysis) => sum + analysis.momentumPhases.length,
      ),
      latePhaseDelta: lateDelta,
      latePhaseSignalSupported: lateSupported,
      quality: quality,
    );
  }
}

/// PRD B2 — resoconto settimanale.
class WeeklySummary {
  const WeeklySummary({
    required this.weekStartMs,
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.avgPointsFor,
    required this.avgPointsAgainst,
    required this.gamesWon,
    required this.gamesLost,
    required this.setsWon,
    required this.setsLost,
    required this.bestStreak,
    required this.bestMatchId,
    required this.closestMatchId,
    required this.bestTeamId,
    required this.bestRole,
    required this.avgOpponentDifficulty,
    required this.avgClutch,
  });

  final int weekStartMs;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final double avgPointsFor;
  final double avgPointsAgainst;
  final int gamesWon;
  final int gamesLost;
  final int setsWon;
  final int setsLost;
  final int bestStreak;
  final String? bestMatchId;
  final String? closestMatchId;
  final String? bestTeamId;
  final PadelRole? bestRole;
  final double avgOpponentDifficulty;
  final double avgClutch;

  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;

  static WeeklySummary compute(int weekStartMs, List<MatchSummary> matches) {
    if (matches.isEmpty) {
      return WeeklySummary(
        weekStartMs: weekStartMs,
        matchesPlayed: 0,
        wins: 0,
        losses: 0,
        avgPointsFor: 0,
        avgPointsAgainst: 0,
        gamesWon: 0,
        gamesLost: 0,
        setsWon: 0,
        setsLost: 0,
        bestStreak: 0,
        bestMatchId: null,
        closestMatchId: null,
        bestTeamId: null,
        bestRole: null,
        avgOpponentDifficulty: 0,
        avgClutch: 0,
      );
    }
    final wins = matches.where((m) => m.won).length;

    // Best match: won with the largest game margin; closest: smallest total
    // margin with most points.
    MatchSummary? best;
    for (final m in matches.where((m) => m.won)) {
      if (best == null ||
          (m.gamesFor - m.gamesAgainst) > (best.gamesFor - best.gamesAgainst)) {
        best = m;
      }
    }
    MatchSummary closest = matches.first;
    int margin(MatchSummary m) =>
        (m.gamesFor - m.gamesAgainst).abs() * 100 - m.totalPoints;
    for (final m in matches) {
      if (margin(m) < margin(closest)) closest = m;
    }

    // Best team / role by win rate (min 1 match).
    String? bestTeam;
    double bestTeamRate = -1;
    final byTeam = <String, List<MatchSummary>>{};
    for (final m in matches) {
      if (m.teamId != null) byTeam.putIfAbsent(m.teamId!, () => []).add(m);
    }
    byTeam.forEach((id, ms) {
      final r = ms.where((m) => m.won).length / ms.length;
      if (r > bestTeamRate) {
        bestTeamRate = r;
        bestTeam = id;
      }
    });

    PadelRole? bestRole;
    double bestRoleRate = -1;
    final byRole = <PadelRole, List<MatchSummary>>{};
    for (final m in matches) {
      if (m.roleplayed != PadelRole.undefined) {
        byRole.putIfAbsent(m.roleplayed, () => []).add(m);
      }
    }
    byRole.forEach((role, ms) {
      final r = ms.where((m) => m.won).length / ms.length;
      if (r > bestRoleRate) {
        bestRoleRate = r;
        bestRole = role;
      }
    });

    return WeeklySummary(
      weekStartMs: weekStartMs,
      matchesPlayed: matches.length,
      wins: wins,
      losses: matches.length - wins,
      avgPointsFor: _avg(matches.map((m) => m.pointsFor)),
      avgPointsAgainst: _avg(matches.map((m) => m.pointsAgainst)),
      gamesWon: _sum(matches.map((m) => m.gamesFor)),
      gamesLost: _sum(matches.map((m) => m.gamesAgainst)),
      setsWon: _sum(matches.map((m) => m.setsFor)),
      setsLost: _sum(matches.map((m) => m.setsAgainst)),
      bestStreak: matches
          .map((m) => m.bestStreak)
          .reduce((a, b) => a > b ? a : b),
      bestMatchId: best?.matchId,
      closestMatchId: closest.matchId,
      bestTeamId: bestTeam,
      bestRole: bestRole,
      avgOpponentDifficulty: _avg(
        matches.map((m) => m.opponentDifficulty.score),
      ),
      avgClutch: _avg(matches.map((m) => m.clutchScore)),
    );
  }
}

/// Direction of an insight (PRD B3: almeno un miglioramento e una
/// regressione se dati sufficienti).
enum InsightDirection { improvement, regression, neutral }

class Insight {
  const Insight({
    required this.metric,
    required this.deltaPct,
    required this.direction,
    required this.text,
    this.evidence = EvidenceQuality.developing,
    this.sampleSize = 0,
  });

  final String metric;

  /// Signed percentage delta, e.g. +12.0.
  final double deltaPct;
  final InsightDirection direction;
  final EvidenceQuality evidence;
  final int sampleSize;

  /// Human sentence, e.g. "+12% punti vinti nei game decisivi."
  final String text;
}

/// Compares a recent window vs a baseline window on PRD B3 metrics.
class ProgressAnalyzer {
  static const _minMatches = 2;

  /// Standard comparisons: settimana precedente, ultime 5, ultime 10.
  static List<Insight> compare({
    required List<MatchSummary> recent,
    required List<MatchSummary> baseline,
    String label = '',
  }) {
    if (recent.length < _minMatches || baseline.length < _minMatches) {
      return const [];
    }
    final insights = <Insight>[];

    void addRate(
      String metric,
      RateEstimate recentRate,
      RateEstimate baselineRate,
      String unit, {
      bool higherIsBetter = true,
      int minimumTrials = 20,
      double minimumDelta = 0.06,
    }) {
      if (recentRate.trials < minimumTrials ||
          baselineRate.trials < minimumTrials) {
        return;
      }
      final delta = recentRate.rate - baselineRate.rate;
      final intervalsSeparated =
          recentRate.lower > baselineRate.upper ||
          recentRate.upper < baselineRate.lower;
      if (delta.abs() < minimumDelta || !intervalsSeparated) return;
      final improved = higherIsBetter ? delta > 0 : delta < 0;
      final deltaPoints = delta * 100;
      final sign = deltaPoints > 0 ? '+' : '';
      final evidence = recentRate.trials >= 80 && baselineRate.trials >= 80
          ? EvidenceQuality.reliable
          : EvidenceQuality.developing;
      insights.add(
        Insight(
          metric: metric,
          deltaPct: double.parse(deltaPoints.toStringAsFixed(1)),
          direction: improved
              ? InsightDirection.improvement
              : InsightDirection.regression,
          text: '$sign${deltaPoints.toStringAsFixed(0)} punti % $unit$label',
          evidence: evidence,
          sampleSize: recentRate.trials + baselineRate.trials,
        ),
      );
    }

    RateEstimate pooled(
      List<MatchSummary> matches,
      int Function(MatchSummary) successes,
      int Function(MatchSummary) trials,
    ) {
      final total = _sum(matches.map(trials));
      return RateEstimate.fromCounts(_sum(matches.map(successes)), total);
    }

    addRate(
      'point_share',
      pooled(recent, (m) => m.pointsFor, (m) => m.totalPoints),
      pooled(baseline, (m) => m.pointsFor, (m) => m.totalPoints),
      'quota punti vinti',
    );
    addRate(
      'game_share',
      pooled(recent, (m) => m.gamesFor, (m) => m.gamesFor + m.gamesAgainst),
      pooled(baseline, (m) => m.gamesFor, (m) => m.gamesFor + m.gamesAgainst),
      'quota game vinti',
      minimumTrials: 12,
      minimumDelta: 0.10,
    );
    addRate(
      'win_rate',
      RateEstimate.fromCounts(recent.where((m) => m.won).length, recent.length),
      RateEstimate.fromCounts(
        baseline.where((m) => m.won).length,
        baseline.length,
      ),
      'vittorie',
      minimumTrials: 8,
      minimumDelta: 0.15,
    );

    final recentPortfolio = AnalyticsPortfolio.fromMatches(recent);
    final baselinePortfolio = AnalyticsPortfolio.fromMatches(baseline);
    addRate(
      'pressure_points',
      recentPortfolio.pressurePointWinRate,
      baselinePortfolio.pressurePointWinRate,
      'rendimento ad alta pressione',
      minimumTrials: 12,
      minimumDelta: 0.10,
    );
    addRate(
      'serve_points',
      recentPortfolio.servePointWinRate,
      baselinePortfolio.servePointWinRate,
      'punti vinti al servizio',
      minimumTrials: 24,
      minimumDelta: 0.07,
    );
    addRate(
      'return_points',
      recentPortfolio.returnPointWinRate,
      baselinePortfolio.returnPointWinRate,
      'punti vinti in risposta',
      minimumTrials: 24,
      minimumDelta: 0.07,
    );
    addRate(
      'tie_break',
      pooled(recent, (m) => m.tieBreakPointsWon, (m) => m.tieBreakPointsPlayed),
      pooled(
        baseline,
        (m) => m.tieBreakPointsWon,
        (m) => m.tieBreakPointsPlayed,
      ),
      'rendimento nei tie-break',
      minimumTrials: 14,
      minimumDelta: 0.12,
    );

    insights.sort((a, b) => b.deltaPct.abs().compareTo(a.deltaPct.abs()));
    return insights;
  }

  /// Convenience: top improvement + top regression, per acceptance criteria.
  static ({Insight? improvement, Insight? regression}) headline(
    List<Insight> insights,
  ) {
    Insight? imp, reg;
    for (final i in insights) {
      if (i.direction == InsightDirection.improvement) {
        imp ??= i;
      } else if (i.direction == InsightDirection.regression) {
        reg ??= i;
      }
    }
    return (improvement: imp, regression: reg);
  }
}

/// Elo-lite internal rating (feeds Opponent Difficulty Score, PRD F5).
class RatingEngine {
  static const initial = 1000.0;
  static const kFactor = 32.0;

  /// Returns the new rating after a match against [opponentRating].
  static double update({
    required double rating,
    required double opponentRating,
    required bool won,
  }) {
    final expected = 1 / (1 + math.pow(10, (opponentRating - rating) / 400));
    return rating + kFactor * ((won ? 1 : 0) - expected);
  }
}

double _avg(Iterable<num> xs) {
  var n = 0;
  var s = 0.0;
  for (final x in xs) {
    s += x;
    n++;
  }
  return n == 0 ? 0 : s / n;
}

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
