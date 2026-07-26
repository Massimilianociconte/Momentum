/// Evidence-aware, post-match analytics derived from the canonical point log.
///
/// The engine deliberately runs only after replay. It separates descriptive
/// evidence (counts and Wilson intervals) from model-based quantities (neutral
/// match leverage) and never treats a single live point as a durable pattern.
library;

import 'dart:math' as math;

import '../engine/point_record.dart';
import '../model/enums.dart';
import '../model/match_format.dart';

enum EvidenceQuality { insufficient, developing, reliable }

extension EvidenceQualityWire on EvidenceQuality {
  String get wire => name.toUpperCase();

  static EvidenceQuality fromWire(String? value) => switch (value) {
    'RELIABLE' => EvidenceQuality.reliable,
    'DEVELOPING' => EvidenceQuality.developing,
    _ => EvidenceQuality.insufficient,
  };
}

/// Binomial rate with a two-sided Wilson score interval.
///
/// A 90% interval is used for product feedback: it remains conservative on
/// small samples without making the UI unusably silent. Raw counts are always
/// exposed so callers can apply stricter thresholds where needed.
class RateEstimate {
  const RateEstimate({
    required this.successes,
    required this.trials,
    required this.rate,
    required this.lower,
    required this.upper,
  });

  static const empty = RateEstimate(
    successes: 0,
    trials: 0,
    rate: 0,
    lower: 0,
    upper: 1,
  );

  final int successes;
  final int trials;
  final double rate;
  final double lower;
  final double upper;

  double get width => upper - lower;
  bool get hasEvidence => trials > 0;

  factory RateEstimate.fromCounts(
    int successes,
    int trials, {
    double z = 1.6448536269514722,
  }) {
    if (trials <= 0) return empty;
    final boundedSuccesses = successes.clamp(0, trials);
    final p = boundedSuccesses / trials;
    final z2 = z * z;
    final denominator = 1 + z2 / trials;
    final center = (p + z2 / (2 * trials)) / denominator;
    final margin =
        z * math.sqrt((p * (1 - p) + z2 / (4 * trials)) / trials) / denominator;
    return RateEstimate(
      successes: boundedSuccesses,
      trials: trials,
      rate: p,
      lower: (center - margin).clamp(0, 1),
      upper: (center + margin).clamp(0, 1),
    );
  }

  Map<String, Object?> toJson() => {
    'successes': successes,
    'trials': trials,
    'rate': rate,
    'lower': lower,
    'upper': upper,
  };

  factory RateEstimate.fromJson(Map<String, Object?> json) => RateEstimate(
    successes: json['successes'] as int? ?? 0,
    trials: json['trials'] as int? ?? 0,
    rate: (json['rate'] as num?)?.toDouble() ?? 0,
    lower: (json['lower'] as num?)?.toDouble() ?? 0,
    upper: (json['upper'] as num?)?.toDouble() ?? 1,
  );
}

enum TurningPointKind {
  matchPointSaved,
  matchPoint,
  setPoint,
  breakPoint,
  sustainedShift,
}

class TurningPoint {
  const TurningPoint({
    required this.pointIndex,
    required this.team,
    required this.kind,
    required this.leverage,
    required this.winProbabilityBefore,
    required this.winProbabilityAfter,
    required this.confirmationRate,
  });

  final int pointIndex;
  final TeamId team;
  final TurningPointKind kind;

  /// Neutral-model match probability difference between winning and losing
  /// the rally. This is structural importance, not a prediction.
  final double leverage;
  final double winProbabilityBefore;
  final double winProbabilityAfter;

  /// Share of the confirmation window won by [team]. The point is emitted only
  /// when its direction survives a post-point window or closes a set/match.
  final double confirmationRate;

  Map<String, Object?> toJson() => {
    'pointIndex': pointIndex,
    'team': team.wire,
    'kind': kind.name,
    'leverage': leverage,
    'before': winProbabilityBefore,
    'after': winProbabilityAfter,
    'confirmationRate': confirmationRate,
  };

  factory TurningPoint.fromJson(Map<String, Object?> json) => TurningPoint(
    pointIndex: json['pointIndex'] as int,
    team: TeamId.fromWire(json['team'] as String),
    kind: TurningPointKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => TurningPointKind.sustainedShift,
    ),
    leverage: (json['leverage'] as num).toDouble(),
    winProbabilityBefore: (json['before'] as num).toDouble(),
    winProbabilityAfter: (json['after'] as num).toDouble(),
    confirmationRate: (json['confirmationRate'] as num).toDouble(),
  );
}

class MomentumPhase {
  const MomentumPhase({
    required this.startPoint,
    required this.endPoint,
    required this.team,
    required this.pointRate,
    required this.deltaFromMatch,
  });

  final int startPoint;
  final int endPoint;
  final TeamId team;
  final RateEstimate pointRate;
  final double deltaFromMatch;

  int get length => endPoint - startPoint + 1;

  Map<String, Object?> toJson() => {
    'startPoint': startPoint,
    'endPoint': endPoint,
    'team': team.wire,
    'pointRate': pointRate.toJson(),
    'deltaFromMatch': deltaFromMatch,
  };

  factory MomentumPhase.fromJson(Map<String, Object?> json) => MomentumPhase(
    startPoint: json['startPoint'] as int,
    endPoint: json['endPoint'] as int,
    team: TeamId.fromWire(json['team'] as String),
    pointRate: RateEstimate.fromJson(
      (json['pointRate'] as Map).cast<String, Object?>(),
    ),
    deltaFromMatch: (json['deltaFromMatch'] as num).toDouble(),
  );
}

class AdvancedMatchAnalysis {
  const AdvancedMatchAnalysis({
    required this.version,
    required this.perspectiveTeam,
    required this.totalPoints,
    required this.pointWinRate,
    required this.servePointWinRate,
    required this.returnPointWinRate,
    required this.pressurePointWinRate,
    required this.breakPointConversion,
    required this.gamePointSaveRate,
    required this.closingPointRate,
    required this.firstPhasePointRate,
    required this.finalPhasePointRate,
    required this.latePhaseDelta,
    required this.latePhaseSignalSupported,
    required this.clutchScore,
    required this.clutchDelta,
    required this.leverageThreshold,
    required this.averageLeverage,
    required this.lowestWinProbabilityInVictory,
    required this.turningPoints,
    required this.momentumPhases,
    required this.quality,
  });

  static const currentVersion = 2;

  final int version;
  final TeamId perspectiveTeam;
  final int totalPoints;
  final RateEstimate pointWinRate;
  final RateEstimate servePointWinRate;
  final RateEstimate returnPointWinRate;
  final RateEstimate pressurePointWinRate;
  final RateEstimate breakPointConversion;
  final RateEstimate gamePointSaveRate;
  final RateEstimate closingPointRate;
  final RateEstimate firstPhasePointRate;
  final RateEstimate finalPhasePointRate;
  final double? latePhaseDelta;
  final bool latePhaseSignalSupported;

  /// Empirical-Bayes pressure-point rate, shrunk toward the match baseline.
  /// Null means there is no pressure sample and must not be rendered as 50.
  final double? clutchScore;
  final double? clutchDelta;
  final double leverageThreshold;
  final double averageLeverage;
  final double? lowestWinProbabilityInVictory;
  final List<TurningPoint> turningPoints;
  final List<MomentumPhase> momentumPhases;
  final EvidenceQuality quality;

  Map<String, Object?> toJson() => {
    'version': version,
    'perspectiveTeam': perspectiveTeam.wire,
    'totalPoints': totalPoints,
    'pointWinRate': pointWinRate.toJson(),
    'servePointWinRate': servePointWinRate.toJson(),
    'returnPointWinRate': returnPointWinRate.toJson(),
    'pressurePointWinRate': pressurePointWinRate.toJson(),
    'breakPointConversion': breakPointConversion.toJson(),
    'gamePointSaveRate': gamePointSaveRate.toJson(),
    'closingPointRate': closingPointRate.toJson(),
    'firstPhasePointRate': firstPhasePointRate.toJson(),
    'finalPhasePointRate': finalPhasePointRate.toJson(),
    'latePhaseDelta': latePhaseDelta,
    'latePhaseSignalSupported': latePhaseSignalSupported,
    'clutchScore': clutchScore,
    'clutchDelta': clutchDelta,
    'leverageThreshold': leverageThreshold,
    'averageLeverage': averageLeverage,
    'lowestWinProbabilityInVictory': lowestWinProbabilityInVictory,
    'turningPoints': turningPoints.map((point) => point.toJson()).toList(),
    'momentumPhases': momentumPhases.map((phase) => phase.toJson()).toList(),
    'quality': quality.wire,
  };

  factory AdvancedMatchAnalysis.fromJson(Map<String, Object?> json) =>
      AdvancedMatchAnalysis(
        version: json['version'] as int? ?? 1,
        perspectiveTeam: TeamId.fromWire(
          json['perspectiveTeam'] as String? ?? TeamId.a.wire,
        ),
        totalPoints: json['totalPoints'] as int? ?? 0,
        pointWinRate: _rateFrom(json, 'pointWinRate'),
        servePointWinRate: _rateFrom(json, 'servePointWinRate'),
        returnPointWinRate: _rateFrom(json, 'returnPointWinRate'),
        pressurePointWinRate: _rateFrom(json, 'pressurePointWinRate'),
        breakPointConversion: _rateFrom(json, 'breakPointConversion'),
        gamePointSaveRate: _rateFrom(json, 'gamePointSaveRate'),
        closingPointRate: _rateFrom(json, 'closingPointRate'),
        firstPhasePointRate: _rateFrom(json, 'firstPhasePointRate'),
        finalPhasePointRate: _rateFrom(json, 'finalPhasePointRate'),
        latePhaseDelta: (json['latePhaseDelta'] as num?)?.toDouble(),
        latePhaseSignalSupported:
            json['latePhaseSignalSupported'] as bool? ?? false,
        clutchScore: (json['clutchScore'] as num?)?.toDouble(),
        clutchDelta: (json['clutchDelta'] as num?)?.toDouble(),
        leverageThreshold: (json['leverageThreshold'] as num?)?.toDouble() ?? 0,
        averageLeverage: (json['averageLeverage'] as num?)?.toDouble() ?? 0,
        lowestWinProbabilityInVictory:
            (json['lowestWinProbabilityInVictory'] as num?)?.toDouble(),
        turningPoints: (json['turningPoints'] as List? ?? const [])
            .map(
              (item) =>
                  TurningPoint.fromJson((item as Map).cast<String, Object?>()),
            )
            .toList(growable: false),
        momentumPhases: (json['momentumPhases'] as List? ?? const [])
            .map(
              (item) =>
                  MomentumPhase.fromJson((item as Map).cast<String, Object?>()),
            )
            .toList(growable: false),
        quality: EvidenceQualityWire.fromWire(json['quality'] as String?),
      );

  static RateEstimate _rateFrom(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! Map) return RateEstimate.empty;
    return RateEstimate.fromJson(value.cast<String, Object?>());
  }
}

abstract final class AdvancedMatchAnalytics {
  static AdvancedMatchAnalysis analyze({
    required List<PointRecord> records,
    required MatchFormat format,
    required TeamId perspectiveTeam,
    required TeamId? matchWinner,
  }) {
    if (records.isEmpty) {
      return AdvancedMatchAnalysis(
        version: AdvancedMatchAnalysis.currentVersion,
        perspectiveTeam: perspectiveTeam,
        totalPoints: 0,
        pointWinRate: RateEstimate.empty,
        servePointWinRate: RateEstimate.empty,
        returnPointWinRate: RateEstimate.empty,
        pressurePointWinRate: RateEstimate.empty,
        breakPointConversion: RateEstimate.empty,
        gamePointSaveRate: RateEstimate.empty,
        closingPointRate: RateEstimate.empty,
        firstPhasePointRate: RateEstimate.empty,
        finalPhasePointRate: RateEstimate.empty,
        latePhaseDelta: null,
        latePhaseSignalSupported: false,
        clutchScore: null,
        clutchDelta: null,
        leverageThreshold: 0,
        averageLeverage: 0,
        lowestWinProbabilityInVictory: null,
        turningPoints: const [],
        momentumPhases: const [],
        quality: EvidenceQuality.insufficient,
      );
    }

    int won(Iterable<PointRecord> values) =>
        values.where((record) => record.winner == perspectiveTeam).length;
    RateEstimate estimate(Iterable<PointRecord> values) {
      final list = values.toList(growable: false);
      return RateEstimate.fromCounts(won(list), list.length);
    }

    final pointRate = estimate(records);
    final serve = estimate(
      records.where((record) => record.servingTeam == perspectiveTeam),
    );
    final onReturn = estimate(
      records.where((record) => record.servingTeam != perspectiveTeam),
    );

    final model = _NeutralMatchModel(format);
    final leveraged = <_LeveragePoint>[];
    for (final record in records) {
      final before = format.freePlay
          ? 0.5
          : model.probability(record.scoreBefore);
      final after = format.freePlay
          ? 0.5
          : model.probability(record.scoreAfter);
      leveraged.add(
        _LeveragePoint(
          record: record,
          before: before,
          after: after,
          leverage: format.freePlay
              ? 0
              : (2 * (after - before).abs()).clamp(0, 1),
        ),
      );
    }

    final nonZero =
        leveraged
            .map((point) => point.leverage)
            .where((value) => value > 0.000001)
            .toList()
          ..sort();
    final quartile = nonZero.isEmpty
        ? 0.0
        : nonZero[((nonZero.length - 1) * 0.75).round()];
    final leverageThreshold = math.max(0.04, quartile);
    final pressureRecords = leveraged
        .where(
          (point) =>
              point.leverage >= leverageThreshold ||
              point.record.setPointFor.isNotEmpty ||
              point.record.matchPointFor.isNotEmpty,
        )
        .map((point) => point.record)
        .toList(growable: false);
    final pressure = estimate(pressureRecords);

    final breakOpportunities = records
        .where((record) => record.breakPointFor.contains(perspectiveTeam))
        .toList(growable: false);
    final breakConversion = estimate(breakOpportunities);
    final saveOpportunities = records
        .where(
          (record) =>
              record.gamePointFor.contains(perspectiveTeam.opponent) &&
              !record.gamePointFor.contains(perspectiveTeam),
        )
        .toList(growable: false);
    final gamePointSaves = estimate(saveOpportunities);
    final closingOpportunities = records
        .where(
          (record) =>
              record.gamePointFor.contains(perspectiveTeam) &&
              !record.gamePointFor.contains(perspectiveTeam.opponent),
        )
        .toList(growable: false);
    final closing = estimate(closingOpportunities);

    final phaseSize = records.length ~/ 3;
    final firstPhase = phaseSize < 8
        ? RateEstimate.empty
        : estimate(records.take(phaseSize));
    final finalPhase = phaseSize < 8
        ? RateEstimate.empty
        : estimate(records.skip(records.length - phaseSize));
    final lateDelta = firstPhase.hasEvidence && finalPhase.hasEvidence
        ? finalPhase.rate - firstPhase.rate
        : null;
    final lateSignal =
        lateDelta != null &&
        lateDelta.abs() >= 0.10 &&
        (finalPhase.lower > firstPhase.upper ||
            finalPhase.upper < firstPhase.lower);

    // Shrink pressure performance toward the match baseline. Six equivalent
    // prior rallies keep tiny samples from producing extreme clutch scores.
    const priorStrength = 6.0;
    final clutchScore = pressure.trials == 0
        ? null
        : (pressure.successes + priorStrength * pointRate.rate) /
              (pressure.trials + priorStrength);
    final clutchDelta = clutchScore == null
        ? null
        : clutchScore - pointRate.rate;
    final averageLeverage = leveraged.isEmpty
        ? 0.0
        : leveraged.fold<double>(0, (sum, point) => sum + point.leverage) /
              leveraged.length;

    final probabilities = leveraged.map((point) => point.after).toList();
    final turningPoints = _turningPoints(
      leveraged,
      probabilities,
      leverageThreshold,
    );
    final phases = _momentumPhases(records, perspectiveTeam, pointRate);

    double? lowestWinProbability;
    if (!format.freePlay && matchWinner == perspectiveTeam) {
      lowestWinProbability = leveraged
          .map(
            (point) =>
                perspectiveTeam == TeamId.a ? point.before : 1 - point.before,
          )
          .reduce(math.min);
    }

    final quality = records.length >= 80 && pressure.trials >= 10
        ? EvidenceQuality.reliable
        : records.length >= 35
        ? EvidenceQuality.developing
        : EvidenceQuality.insufficient;

    return AdvancedMatchAnalysis(
      version: AdvancedMatchAnalysis.currentVersion,
      perspectiveTeam: perspectiveTeam,
      totalPoints: records.length,
      pointWinRate: pointRate,
      servePointWinRate: serve,
      returnPointWinRate: onReturn,
      pressurePointWinRate: pressure,
      breakPointConversion: breakConversion,
      gamePointSaveRate: gamePointSaves,
      closingPointRate: closing,
      firstPhasePointRate: firstPhase,
      finalPhasePointRate: finalPhase,
      latePhaseDelta: lateDelta,
      latePhaseSignalSupported: lateSignal,
      clutchScore: clutchScore,
      clutchDelta: clutchDelta,
      leverageThreshold: leverageThreshold,
      averageLeverage: averageLeverage,
      lowestWinProbabilityInVictory: lowestWinProbability,
      turningPoints: turningPoints,
      momentumPhases: phases,
      quality: quality,
    );
  }

  static List<TurningPoint> _turningPoints(
    List<_LeveragePoint> points,
    List<double> afterProbabilities,
    double threshold,
  ) {
    final candidates = <({TurningPoint point, double score})>[];
    for (var index = 0; index < points.length; index++) {
      final item = points[index];
      final record = item.record;
      if (item.leverage < threshold) continue;

      final end = math.min(points.length, index + 5);
      final window = points.sublist(index, end);
      final teamWins = window
          .where((point) => point.record.winner == record.winner)
          .length;
      final confirmation = teamWins / window.length;
      final closesMatch = record.scoreAfter.completed;
      final closesSet =
          record.scoreAfter.setsA != record.scoreBefore.setsA ||
          record.scoreAfter.setsB != record.scoreBefore.setsB;
      final finalProbability = afterProbabilities[end - 1];
      final directionPersists = record.winner == TeamId.a
          ? finalProbability + 0.02 >= item.after
          : finalProbability - 0.02 <= item.after;
      if (!closesMatch &&
          !closesSet &&
          (confirmation < 0.60 || !directionPersists)) {
        continue;
      }

      final kind = record.matchPointFor.isNotEmpty
          ? (record.matchPointFor.contains(record.winner)
                ? TurningPointKind.matchPoint
                : TurningPointKind.matchPointSaved)
          : record.setPointFor.isNotEmpty
          ? TurningPointKind.setPoint
          : record.breakPointFor.isNotEmpty
          ? TurningPointKind.breakPoint
          : TurningPointKind.sustainedShift;
      final point = TurningPoint(
        pointIndex: record.index,
        team: record.winner,
        kind: kind,
        leverage: item.leverage,
        winProbabilityBefore: item.before,
        winProbabilityAfter: item.after,
        confirmationRate: confirmation,
      );
      // A point that actually closes the match/set must outrank an adjacent
      // precursor with identical neutral leverage. Otherwise stable sorting
      // could label 6-6 as the turning point and hide the audited match point.
      final closureBonus = closesMatch ? 1.0 : (closesSet ? 0.3 : 0.0);
      candidates.add((
        point: point,
        score: item.leverage * confirmation + closureBonus,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final selected = <TurningPoint>[];
    for (final candidate in candidates) {
      if (selected.any(
        (point) => (point.pointIndex - candidate.point.pointIndex).abs() < 3,
      )) {
        continue;
      }
      selected.add(candidate.point);
      if (selected.length == 3) break;
    }
    selected.sort((a, b) => a.pointIndex.compareTo(b.pointIndex));
    return List.unmodifiable(selected);
  }

  /// Exact offline penalized-likelihood segmentation for a Bernoulli sequence.
  /// With match logs below a few hundred rallies, O(n^2) optimal partitioning
  /// is deterministic and cheaper than maintaining an online heuristic. Only
  /// segments whose Wilson interval excludes the match baseline are surfaced.
  static List<MomentumPhase> _momentumPhases(
    List<PointRecord> records,
    TeamId perspectiveTeam,
    RateEstimate matchRate,
  ) {
    final n = records.length;
    if (n < 18) return const [];
    final minSegment = math.max(6, math.sqrt(n).floor());
    final prefix = List<int>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] =
          prefix[i] + (records[i].winner == perspectiveTeam ? 1 : 0);
    }

    double segmentCost(int start, int end) {
      final length = end - start;
      final wins = prefix[end] - prefix[start];
      final p = ((wins + 0.5) / (length + 1)).clamp(0.000001, 0.999999);
      return -(wins * math.log(p) + (length - wins) * math.log(1 - p));
    }

    final penalty = 3 * math.log(n.toDouble());
    final costs = List<double>.filled(n + 1, double.infinity);
    final previous = List<int>.filled(n + 1, -1);
    costs[0] = -penalty;
    for (var end = minSegment; end <= n; end++) {
      for (var start = 0; start <= end - minSegment; start++) {
        if (start != 0 &&
            (costs[start].isInfinite || end - start < minSegment)) {
          continue;
        }
        final candidate = costs[start] + segmentCost(start, end) + penalty;
        if (candidate < costs[end]) {
          costs[end] = candidate;
          previous[end] = start;
        }
      }
    }
    if (previous[n] < 0) return const [];

    final ranges = <({int start, int end})>[];
    var cursor = n;
    while (cursor > 0) {
      final start = previous[cursor];
      if (start < 0) return const [];
      ranges.add((start: start, end: cursor));
      cursor = start;
    }
    if (ranges.length <= 1) return const [];

    final phases = <MomentumPhase>[];
    for (final range in ranges.reversed) {
      final length = range.end - range.start;
      final wins = prefix[range.end] - prefix[range.start];
      final estimate = RateEstimate.fromCounts(wins, length);
      final delta = estimate.rate - matchRate.rate;
      final separated =
          estimate.lower > matchRate.rate || estimate.upper < matchRate.rate;
      if (delta.abs() < 0.14 || !separated) continue;
      phases.add(
        MomentumPhase(
          startPoint: range.start,
          endPoint: range.end - 1,
          team: delta >= 0 ? perspectiveTeam : perspectiveTeam.opponent,
          pointRate: estimate,
          deltaFromMatch: delta,
        ),
      );
    }
    phases.sort(
      (a, b) => (b.deltaFromMatch.abs() * b.length).compareTo(
        a.deltaFromMatch.abs() * a.length,
      ),
    );
    return List.unmodifiable(phases.take(3));
  }
}

class _LeveragePoint {
  const _LeveragePoint({
    required this.record,
    required this.before,
    required this.after,
    required this.leverage,
  });

  final PointRecord record;
  final double before;
  final double after;
  final double leverage;
}

/// Absorbing Markov model under a neutral 50/50 rally assumption.
///
/// The output measures score leverage only. It intentionally does not claim to
/// predict the actual players, whose serve/return strengths are unknown.
class _NeutralMatchModel {
  _NeutralMatchModel(this.format);

  final MatchFormat format;
  final Map<String, double> _cache = {};

  double probability(PointScoreSnapshot snapshot) =>
      _probability(_ModelState.fromSnapshot(snapshot)).clamp(0, 1);

  double _probability(_ModelState state) {
    if (state.setsA >= format.setsToWin) return 1;
    if (state.setsB >= format.setsToWin) return 0;
    final key = state.key;
    final cached = _cache[key];
    if (cached != null) return cached;

    late final double result;
    if (state.inSuperTieBreak) {
      final q = _winByTwoProbability(
        state.tieBreakA,
        state.tieBreakB,
        format.superTieBreakPoints,
      );
      result =
          q * _probability(_afterSet(state, TeamId.a)) +
          (1 - q) * _probability(_afterSet(state, TeamId.b));
    } else if (state.inTieBreak) {
      final q = _winByTwoProbability(
        state.tieBreakA,
        state.tieBreakB,
        format.tieBreakPoints,
      );
      result =
          q * _probability(_afterSet(state, TeamId.a)) +
          (1 - q) * _probability(_afterSet(state, TeamId.b));
    } else {
      final q = _gameProbability(state.pointsA, state.pointsB);
      if (!format.tieBreakAtGamesAll &&
          state.gamesA >= format.gamesPerSet - 1 &&
          state.gamesB >= format.gamesPerSet - 1) {
        final lead = state.gamesA - state.gamesB;
        final qSet = lead == 0
            ? 0.25 + 0.5 * q
            : lead == 1
            ? 0.5 + 0.5 * q
            : lead == -1
            ? 0.5 * q
            : (lead > 1 ? 1.0 : 0.0);
        result =
            qSet * _probability(_afterSet(state, TeamId.a)) +
            (1 - qSet) * _probability(_afterSet(state, TeamId.b));
      } else {
        result =
            q * _probability(_afterGame(state, TeamId.a)) +
            (1 - q) * _probability(_afterGame(state, TeamId.b));
      }
    }
    _cache[key] = result;
    return result;
  }

  double _gameProbability(int a, int b) {
    if (format.goldenPoint) {
      if (a >= 4) return 1;
      if (b >= 4) return 0;
      if (a >= 3 && b >= 3) return 0.5;
    } else {
      if (a == 4 && b == 3) return 0.75;
      if (b == 4 && a == 3) return 0.25;
      if (a >= 3 && b >= 3) return 0.5;
      if (a >= 4 && a - b >= 2) return 1;
      if (b >= 4 && b - a >= 2) return 0;
    }
    return 0.5 * _gameProbability(a + 1, b) + 0.5 * _gameProbability(a, b + 1);
  }

  double _winByTwoProbability(int a, int b, int target) {
    if (a >= target && a - b >= 2) return 1;
    if (b >= target && b - a >= 2) return 0;
    if (a >= target - 1 && b >= target - 1) {
      final lead = a - b;
      if (lead == 0) return 0.5;
      if (lead == 1) return 0.75;
      if (lead == -1) return 0.25;
    }
    return 0.5 * _winByTwoProbability(a + 1, b, target) +
        0.5 * _winByTwoProbability(a, b + 1, target);
  }

  _ModelState _afterGame(_ModelState state, TeamId winner) {
    var gamesA = state.gamesA + (winner == TeamId.a ? 1 : 0);
    var gamesB = state.gamesB + (winner == TeamId.b ? 1 : 0);
    final leader = winner == TeamId.a ? gamesA : gamesB;
    final other = winner == TeamId.a ? gamesB : gamesA;
    if (leader >= format.gamesPerSet && leader - other >= 2) {
      return _afterSet(state, winner);
    }
    if (format.tieBreakAtGamesAll &&
        gamesA == format.gamesPerSet &&
        gamesB == format.gamesPerSet) {
      return state.copyWith(
        pointsA: 0,
        pointsB: 0,
        gamesA: gamesA,
        gamesB: gamesB,
        inTieBreak: true,
        tieBreakA: 0,
        tieBreakB: 0,
      );
    }
    return state.copyWith(
      pointsA: 0,
      pointsB: 0,
      gamesA: gamesA,
      gamesB: gamesB,
    );
  }

  _ModelState _afterSet(_ModelState state, TeamId winner) {
    final setsA = state.setsA + (winner == TeamId.a ? 1 : 0);
    final setsB = state.setsB + (winner == TeamId.b ? 1 : 0);
    final decider =
        format.superTieBreakDecider &&
        setsA == format.setsToWin - 1 &&
        setsB == format.setsToWin - 1;
    return state.copyWith(
      pointsA: 0,
      pointsB: 0,
      gamesA: 0,
      gamesB: 0,
      setsA: setsA,
      setsB: setsB,
      inTieBreak: false,
      inSuperTieBreak: decider,
      tieBreakA: 0,
      tieBreakB: 0,
    );
  }
}

class _ModelState {
  const _ModelState({
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
  });

  factory _ModelState.fromSnapshot(PointScoreSnapshot value) => _ModelState(
    pointsA: value.pointsA,
    pointsB: value.pointsB,
    gamesA: value.gamesA,
    gamesB: value.gamesB,
    setsA: value.setsA,
    setsB: value.setsB,
    inTieBreak: value.inTieBreak,
    inSuperTieBreak: value.inSuperTieBreak,
    tieBreakA: value.tieBreakA,
    tieBreakB: value.tieBreakB,
  );

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

  String get key =>
      '$pointsA:$pointsB:$gamesA:$gamesB:$setsA:$setsB:'
      '${inTieBreak ? 1 : 0}:${inSuperTieBreak ? 1 : 0}:'
      '$tieBreakA:$tieBreakB';

  _ModelState copyWith({
    int? pointsA,
    int? pointsB,
    int? gamesA,
    int? gamesB,
    int? setsA,
    int? setsB,
    bool? inTieBreak,
    bool? inSuperTieBreak,
    int? tieBreakA,
    int? tieBreakB,
  }) => _ModelState(
    pointsA: pointsA ?? this.pointsA,
    pointsB: pointsB ?? this.pointsB,
    gamesA: gamesA ?? this.gamesA,
    gamesB: gamesB ?? this.gamesB,
    setsA: setsA ?? this.setsA,
    setsB: setsB ?? this.setsB,
    inTieBreak: inTieBreak ?? this.inTieBreak,
    inSuperTieBreak: inSuperTieBreak ?? this.inSuperTieBreak,
    tieBreakA: tieBreakA ?? this.tieBreakA,
    tieBreakB: tieBreakB ?? this.tieBreakB,
  );
}
