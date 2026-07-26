import 'package:rally_core/rally_core.dart';
import 'package:test/test.dart';

void _winGame(PadelScoringEngine engine, TeamId team) {
  for (var i = 0; i < 4; i++) {
    engine.addPoint(team);
  }
}

AdvancedMatchAnalysis _analyze(
  PadelScoringEngine engine, {
  TeamId perspective = TeamId.a,
}) => AdvancedMatchAnalytics.analyze(
  records: engine.pointRecords,
  format: engine.format,
  perspectiveTeam: perspective,
  matchWinner: engine.state.winner,
);

void main() {
  group('RateEstimate', () {
    test('Wilson interval remains bounded and honest on tiny samples', () {
      final estimate = RateEstimate.fromCounts(1, 1);
      expect(estimate.rate, 1);
      expect(estimate.lower, greaterThan(0));
      expect(estimate.lower, lessThan(0.5));
      expect(estimate.upper, closeTo(1, 1e-12));
    });

    test('empty sample is explicitly evidence-free', () {
      expect(RateEstimate.empty.hasEvidence, isFalse);
      expect(RateEstimate.empty.lower, 0);
      expect(RateEstimate.empty.upper, 1);
    });
  });

  group('AdvancedMatchAnalytics', () {
    test('does not manufacture a clutch score without pressure evidence', () {
      final engine = PadelScoringEngine(
        matchId: 'free',
        format: MatchFormat.training,
        clock: () => 1000,
      )..start();
      engine.addPoint(TeamId.a);
      engine.addPoint(TeamId.b);

      final analysis = _analyze(engine);
      expect(analysis.pressurePointWinRate.trials, 0);
      expect(analysis.clutchScore, isNull);
      expect(analysis.quality, EvidenceQuality.insufficient);
    });

    test('tie-break match point is high leverage and confirmed post-match', () {
      final engine = PadelScoringEngine(
        matchId: 'tb',
        format: MatchFormat.singleSet,
        clock: () => 1000,
      )..start();
      for (var game = 0; game < 6; game++) {
        _winGame(engine, TeamId.a);
        _winGame(engine, TeamId.b);
      }
      for (var point = 0; point < 6; point++) {
        engine.addPoint(TeamId.a);
        engine.addPoint(TeamId.b);
      }
      engine.addPoint(TeamId.a); // 7-6, match point.
      engine.addPoint(TeamId.a); // 8-6, match.

      final analysis = _analyze(engine);
      expect(engine.state.isCompleted, isTrue);
      expect(analysis.turningPoints, isNotEmpty);
      expect(
        analysis.turningPoints.any(
          (point) => point.kind == TurningPointKind.matchPoint,
        ),
        isTrue,
      );
      expect(
        analysis.turningPoints
            .map((point) => point.leverage)
            .reduce((a, b) => a > b ? a : b),
        greaterThan(0.1),
      );
    });

    test('undoed point is absent from analytics evidence', () {
      final engine = PadelScoringEngine(
        matchId: 'undo',
        format: MatchFormat.training,
        clock: () => 1000,
      )..start();
      engine.addPoint(TeamId.a);
      engine.addPoint(TeamId.b);
      engine.undo();

      final analysis = _analyze(engine);
      expect(analysis.totalPoints, 1);
      expect(analysis.pointWinRate.successes, 1);
      expect(analysis.pointWinRate.trials, 1);
    });

    test('offline segmentation reports sustained phases, not every streak', () {
      final engine = PadelScoringEngine(
        matchId: 'segments',
        format: MatchFormat.training,
        clock: () => 1000,
      )..start();
      for (var i = 0; i < 18; i++) {
        engine.addPoint(TeamId.b);
      }
      for (var i = 0; i < 18; i++) {
        engine.addPoint(TeamId.a);
      }

      final analysis = _analyze(engine);
      expect(analysis.momentumPhases.length, greaterThanOrEqualTo(2));
      expect(
        analysis.momentumPhases.map((phase) => phase.team),
        containsAll([TeamId.a, TeamId.b]),
      );
      expect(analysis.latePhaseSignalSupported, isTrue);
    });

    test('analysis JSON preserves versioned evidence and turning points', () {
      final engine = PadelScoringEngine(
        matchId: 'json',
        format: MatchFormat.singleSet,
        clock: () => 1000,
      )..start();
      while (!engine.state.isCompleted) {
        engine.addPoint(TeamId.a);
      }
      final analysis = _analyze(engine);
      final decoded = AdvancedMatchAnalysis.fromJson(analysis.toJson());

      expect(decoded.version, AdvancedMatchAnalysis.currentVersion);
      expect(decoded.totalPoints, analysis.totalPoints);
      expect(decoded.pointWinRate.trials, analysis.pointWinRate.trials);
      expect(decoded.turningPoints.length, analysis.turningPoints.length);
    });
  });

  test(
    'portfolio pools point counts instead of averaging match percentages',
    () {
      AdvancedMatchAnalysis analysis(int wins, int total) =>
          AdvancedMatchAnalysis(
            version: AdvancedMatchAnalysis.currentVersion,
            perspectiveTeam: TeamId.a,
            totalPoints: total,
            pointWinRate: RateEstimate.fromCounts(wins, total),
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

      MatchSummary summary(String id, AdvancedMatchAnalysis advanced) =>
          MatchSummary(
            matchId: id,
            endTimeMs: 0,
            won: true,
            pointsFor: advanced.pointWinRate.successes,
            pointsAgainst:
                advanced.pointWinRate.trials - advanced.pointWinRate.successes,
            gamesFor: 0,
            gamesAgainst: 0,
            setsFor: 0,
            setsAgainst: 0,
            clutchScore: 50,
            bestStreak: 0,
            durationMs: 0,
            advancedAnalysis: advanced,
          );

      final portfolio = AnalyticsPortfolio.fromMatches([
        summary('small', analysis(10, 10)),
        summary('large', analysis(45, 90)),
      ]);
      expect(portfolio.pointWinRate.rate, closeTo(0.55, 0.0001));
      expect(portfolio.pointWinRate.trials, 100);
    },
  );
}
