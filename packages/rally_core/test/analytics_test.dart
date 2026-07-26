import 'package:rally_core/rally_core.dart';
import 'package:test/test.dart';

MatchSummary summary({
  required String id,
  required bool won,
  int pf = 60,
  int pa = 50,
  int clutch = 60,
  OpponentDifficulty diff = OpponentDifficulty.sameLevel,
  String? teamId,
  PadelRole role = PadelRole.undefined,
  int decisiveWon = 5,
  int decisivePlayed = 10,
  int tbWon = 0,
  int tbPlayed = 0,
}) => MatchSummary(
  matchId: id,
  endTimeMs: 0,
  won: won,
  pointsFor: pf,
  pointsAgainst: pa,
  gamesFor: won ? 12 : 8,
  gamesAgainst: won ? 8 : 12,
  setsFor: won ? 2 : 0,
  setsAgainst: won ? 0 : 2,
  clutchScore: clutch,
  bestStreak: 4,
  durationMs: 3600000,
  teamId: teamId,
  roleplayed: role,
  opponentDifficulty: diff,
  decisivePointsWon: decisiveWon,
  decisivePointsPlayed: decisivePlayed,
  tieBreakPointsWon: tbWon,
  tieBreakPointsPlayed: tbPlayed,
);

void main() {
  group('MatchStats', () {
    test('clutch, streaks and momentum from a real match', () {
      final e = PadelScoringEngine(
        matchId: 'm',
        format: MatchFormat.goldenPointBo3,
        clock: () => 0,
      )..start();
      // A wins 8 straight points (2 games).
      for (var i = 0; i < 8; i++) {
        e.addPoint(TeamId.a);
      }
      final stats = MatchStats.fromRecords(e.pointRecords);
      expect(stats.teamA.pointsWon, 8);
      expect(stats.teamA.bestStreak, 8);
      expect(stats.teamB.bestStreak, 0);
      expect(stats.momentum.last.diff, 8);
      expect(stats.teamA.clutchScore, greaterThan(50));
      expect(stats.keyMoment, isNotNull);
    });

    test('duration tolerates clock drift and clamps future outliers', () {
      var driftIndex = 0;
      final driftClock = [0, 10_000, 9_000];
      final drifted = PadelScoringEngine(
        matchId: 'drifted',
        format: MatchFormat.training,
        clock: () => driftClock[driftIndex++],
      )..start();
      drifted.addPoint(TeamId.a);
      drifted.addPoint(TeamId.b);
      expect(MatchStats.fromRecords(drifted.pointRecords).durationMs, 1000);

      var outlierIndex = 0;
      final outlierClock = [0, 1_000, 48 * 60 * 60 * 1000];
      final outlier = PadelScoringEngine(
        matchId: 'outlier',
        format: MatchFormat.training,
        clock: () => outlierClock[outlierIndex++],
      )..start();
      outlier.addPoint(TeamId.a);
      outlier.addPoint(TeamId.b);
      expect(
        MatchStats.fromRecords(outlier.pointRecords).durationMs,
        const Duration(hours: 12).inMilliseconds,
      );
    });
  });

  group('active match duration', () {
    MatchEvent event(
      String id,
      MatchEventType type,
      Duration timestamp, {
      SourceMethod method = SourceMethod.tap,
    }) => MatchEvent(
      eventId: id,
      matchId: 'timing',
      timestampMs: timestamp.inMilliseconds,
      type: type,
      sourceMethod: method,
    );

    test('excludes an overnight pause from active play', () {
      final events = [
        event('start', MatchEventType.matchStarted, Duration.zero),
        event('pause', MatchEventType.matchPaused, const Duration(minutes: 10)),
        event('resume', MatchEventType.matchResumed, const Duration(days: 1)),
        event(
          'complete',
          MatchEventType.matchCompleted,
          const Duration(days: 1, minutes: 5),
        ),
      ];

      expect(
        activeMatchDurationMs(
          events: events,
          nowMs: const Duration(days: 2).inMilliseconds,
        ),
        const Duration(minutes: 15).inMilliseconds,
      );
    });

    test('a one-point manually finished match keeps its full duration', () {
      var clockIndex = 0;
      final timestamps = [
        Duration.zero.inMilliseconds,
        const Duration(minutes: 10).inMilliseconds,
        const Duration(minutes: 20).inMilliseconds,
      ];
      final engine = PadelScoringEngine(
        matchId: 'timing',
        format: MatchFormat.training,
        clock: () => timestamps[clockIndex++],
        idGenerator: () => 'event-$clockIndex',
      )..start();
      engine.addPoint(TeamId.a);
      engine.finish(winner: TeamId.a);

      final durationMs = activeMatchDurationMs(
        events: engine.events,
        nowMs: const Duration(hours: 1).inMilliseconds,
      );
      final stats = MatchStats.fromRecords(
        engine.pointRecords,
        durationMsOverride: durationMs,
      );

      expect(engine.pointRecords, hasLength(1));
      expect(durationMs, const Duration(minutes: 20).inMilliseconds);
      expect(stats.durationMs, const Duration(minutes: 20).inMilliseconds);
    });

    test('manual finish while paused adds no paused time', () {
      final events = [
        event('start', MatchEventType.matchStarted, Duration.zero),
        event('pause', MatchEventType.matchPaused, const Duration(minutes: 5)),
        event(
          'finish',
          MatchEventType.matchCompleted,
          const Duration(days: 1),
          method: SourceMethod.manualEdit,
        ),
      ];

      expect(
        activeMatchDurationMs(
          events: events,
          nowMs: const Duration(days: 2).inMilliseconds,
        ),
        const Duration(minutes: 5).inMilliseconds,
      );
    });

    test('legacy journals fall back to durable row boundaries', () {
      final events = [
        event('point', MatchEventType.pointTeamA, const Duration(minutes: 10)),
      ];

      expect(
        activeMatchDurationMs(
          events: events,
          fallbackStartTimeMs: 0,
          fallbackEndTimeMs: const Duration(minutes: 30).inMilliseconds,
          nowMs: const Duration(hours: 1).inMilliseconds,
        ),
        const Duration(minutes: 30).inMilliseconds,
      );
    });
  });

  group('WeeklySummary', () {
    test('aggregates PRD B2 metrics', () {
      final s = WeeklySummary.compute(0, [
        summary(id: '1', won: true, pf: 71, teamId: 't1'),
        summary(id: '2', won: true, pf: 65, teamId: 't1'),
        summary(id: '3', won: false, pf: 55, teamId: 't2'),
        summary(id: '4', won: true, pf: 70, teamId: 't1'),
      ]);
      expect(s.matchesPlayed, 4);
      expect(s.wins, 3);
      expect(s.losses, 1);
      expect(s.avgPointsFor, closeTo(65.25, 0.01));
      expect(s.bestTeamId, 't1');
      expect(s.winRate, 0.75);
    });

    test('empty week', () {
      final s = WeeklySummary.compute(0, []);
      expect(s.matchesPlayed, 0);
      expect(s.winRate, 0);
    });
  });

  group('ProgressAnalyzer', () {
    test('detects only a statistically separated improvement', () {
      final recent = [
        for (var i = 0; i < 8; i++)
          summary(id: 'r$i', won: true, pf: 90, pa: 10),
      ];
      final baseline = [
        for (var i = 0; i < 8; i++)
          summary(id: 'b$i', won: false, pf: 40, pa: 60),
      ];
      final insights = ProgressAnalyzer.compare(
        recent: recent,
        baseline: baseline,
      );
      expect(insights, isNotEmpty);
      final h = ProgressAnalyzer.headline(insights);
      expect(h.improvement, isNotNull);
      expect(
        insights.any(
          (i) =>
              i.metric == 'point_share' &&
              i.direction == InsightDirection.improvement &&
              i.evidence == EvidenceQuality.reliable,
        ),
        isTrue,
      );
    });

    test('needs enough data', () {
      final insights = ProgressAnalyzer.compare(
        recent: [summary(id: '1', won: true)],
        baseline: [summary(id: '2', won: false)],
      );
      expect(insights, isEmpty);
    });
  });

  group('OpponentDifficultyScore', () {
    test('user feedback dominates', () {
      final d = OpponentDifficultyScore.compute(
        const DifficultyInputs(userFeedback: 5),
      );
      expect(d, OpponentDifficulty.muchHarder);
    });

    test('stronger declared level raises difficulty', () {
      final d = OpponentDifficultyScore.compute(
        const DifficultyInputs(
          declaredOpponentLevel: PlayerLevel.competition,
          playerLevel: PlayerLevel.intermediate,
        ),
      );
      expect(d.score, greaterThanOrEqualTo(4));
    });

    test('rating gap moves the score', () {
      final d = OpponentDifficultyScore.compute(
        const DifficultyInputs(opponentRating: 1400, playerRating: 1000),
      );
      expect(d.score, greaterThanOrEqualTo(4));
    });

    test('upset stats', () {
      final stats = OpponentDifficultyScore.stats([
        summary(id: '1', won: true, diff: OpponentDifficulty.muchHarder),
        summary(id: '2', won: false, diff: OpponentDifficulty.muchEasier),
        summary(id: '3', won: true, diff: OpponentDifficulty.sameLevel),
        summary(id: '4', won: true, diff: OpponentDifficulty.sameLevel),
      ]);
      expect(stats.upsetWins, 1);
      expect(stats.upsetLosses, 1);
      expect(stats.bestStreakVsSameLevel, 2);
    });
  });

  group('RatingEngine', () {
    test('beating a stronger opponent gains more', () {
      final vsStrong = RatingEngine.update(
        rating: 1000,
        opponentRating: 1200,
        won: true,
      );
      final vsWeak = RatingEngine.update(
        rating: 1000,
        opponentRating: 800,
        won: true,
      );
      expect(vsStrong - 1000, greaterThan(vsWeak - 1000));
      expect(vsStrong, greaterThan(1000));
    });
  });

  group('RulesSearch', () {
    final search = RulesSearch(padelRules);

    test('finds golden point rule', () {
      final r = search.search('come funziona il golden point?');
      expect(r.first.entry.id, 'golden_point');
      expect(r.first.score, greaterThan(RulesSearch.minConfidence));
    });

    test('finds let rule', () {
      final r = search.search('quando è let?');
      expect(r.map((x) => x.entry.id), contains('serve_let'));
    });

    test('finds grid rule', () {
      final r = search.search('la palla può toccare la griglia?');
      expect(r.first.entry.id, 'grid');
    });

    test('finds tie-break rule', () {
      final r = search.search('come si calcola il tie-break?');
      expect(r.first.entry.id, 'tie_break');
    });

    test('finds side change rule', () {
      final r = search.search('quando si cambia campo?');
      expect(r.first.entry.id, 'change_sides');
    });

    test('gibberish returns nothing confident', () {
      final r = search.search('xyzzy frull');
      expect(r.isEmpty || r.first.score < RulesSearch.minConfidence, isTrue);
    });
  });

  group('Wrapped', () {
    test('match wrapped headline and MVP', () {
      final e = PadelScoringEngine(
        matchId: 'm',
        format: MatchFormat.singleSet,
        clock: () => 0,
      )..start();
      while (!e.state.isCompleted) {
        e.addPoint(TeamId.a);
      }
      final stats = MatchStats.fromRecords(e.pointRecords);
      final card = MatchWrappedData.build(
        stats: stats,
        ourTeam: TeamId.a,
        won: true,
        resultLine: '6-0',
        teamLabel: 'Io + Luca',
        difficulty: OpponentDifficulty.harder,
        role: PadelRole.left,
      );
      expect(card.headline, isNotEmpty);
      expect(card.statisticalMvp, isNotEmpty);
      expect(card.bestStreak, greaterThan(0));
    });

    test('team compatibility bounded 0-100', () {
      final c = TeamWrappedData.compatibility([
        summary(id: '1', won: true, clutch: 90),
        summary(id: '2', won: true, clutch: 85),
      ]);
      expect(c, inInclusiveRange(0, 100));
      expect(c, greaterThan(60));
    });
  });
}
