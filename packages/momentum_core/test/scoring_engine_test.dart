import 'package:rally_core/rally_core.dart';
import 'package:test/test.dart';

PadelScoringEngine engine(MatchFormat format) {
  var t = 0;
  var i = 0;
  return PadelScoringEngine(
    matchId: 'm1',
    format: format,
    clock: () => t += 1000,
    idGenerator: () => 'e${i++}',
  );
}

void winGame(PadelScoringEngine e, TeamId team) {
  final wasGames = team == TeamId.a ? e.state.gamesA : e.state.gamesB;
  final wasSets = team == TeamId.a ? e.state.setsA : e.state.setsB;
  while (!e.state.isCompleted) {
    e.addPoint(team);
    final games = team == TeamId.a ? e.state.gamesA : e.state.gamesB;
    final sets = team == TeamId.a ? e.state.setsA : e.state.setsB;
    if (games > wasGames || sets > wasSets || e.state.isCompleted) return;
  }
}

/// Like [winGame] but returns the [ScoringResult] of the game-winning point.
ScoringResult playGame(PadelScoringEngine e, TeamId team) {
  final wasGames = team == TeamId.a ? e.state.gamesA : e.state.gamesB;
  final wasSets = team == TeamId.a ? e.state.setsA : e.state.setsB;
  while (true) {
    final r = e.addPoint(team);
    final games = team == TeamId.a ? e.state.gamesA : e.state.gamesB;
    final sets = team == TeamId.a ? e.state.setsA : e.state.setsB;
    if (games > wasGames || sets > wasSets || e.state.isCompleted) return r;
  }
}

void winSet(PadelScoringEngine e, TeamId team) {
  final wasSets = team == TeamId.a ? e.state.setsA : e.state.setsB;
  while (!e.state.isCompleted) {
    winGame(e, team);
    final sets = team == TeamId.a ? e.state.setsA : e.state.setsB;
    if (sets > wasSets || e.state.isCompleted) return;
  }
}

void main() {
  test('default event IDs are canonical unique UUID v4 values', () {
    final e = PadelScoringEngine(
      matchId: 'uuid-match',
      format: MatchFormat.advantageBo3,
    );
    final ids = <String>[
      ...e.start().newEvents.map((event) => event.eventId),
      ...e.addPoint(TeamId.a).newEvents.map((event) => event.eventId),
      ...e.addPoint(TeamId.b).newEvents.map((event) => event.eventId),
    ];
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(ids, hasLength(3));
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(id, matches(uuidV4));
    }
  });

  group('golden point scoring', () {
    test('four straight points win a game', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
      }
      expect(e.state.points.labelFor(TeamId.a), '40');
      final r = e.addPoint(TeamId.a);
      expect(e.state.gamesA, 1);
      expect(e.state.points.labelFor(TeamId.a), '0');
      expect(r.transitions, contains(ScoreTransition.gameWon));
      expect(r.transitions, contains(ScoreTransition.sideChange));
    });

    test('golden point: 40-40 next point wins', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
      }
      expect(e.state.points.isDeuce, isTrue);
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.goldenPoint,
        ),
        '40 PARI · prossimo punto decisivo',
      );
      e.addPoint(TeamId.b);
      expect(e.state.gamesB, 1);
    });
  });

  group('advantage scoring', () {
    test('deuce → advantage → game', () {
      final e = engine(MatchFormat.advantageBo3)..start();
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
      }
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.advantage,
        ),
        '40 PARI · si gioca ai vantaggi',
      );
      e.addPoint(TeamId.a); // AD A
      expect(e.state.points.labelFor(TeamId.a), 'AD');
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.advantage,
        ),
        'VANTAGGIO NOI · un punto per il game',
      );
      e.addPoint(TeamId.b); // back to deuce
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), '40');
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.advantage,
        ),
        '40 PARI · si gioca ai vantaggi',
      );
      e.addPoint(TeamId.b); // AD B
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.advantage,
          teamALabel: 'CASA',
          teamBLabel: 'OSPITI',
        ),
        'VANTAGGIO OSPITI · un punto per il game',
      );
      e.addPoint(TeamId.b); // game B
      expect(e.state.gamesB, 1);
    });

    test('advantage alternates through deuce and undo restores deuce', () {
      final e = engine(MatchFormat.advantageBo3)..start();
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
      }

      e.addPoint(TeamId.a);
      expect(e.state.points.labelFor(TeamId.a), 'AD');
      expect(e.state.points.labelFor(TeamId.b), '40');

      e.addPoint(TeamId.b);
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), '40');

      e.addPoint(TeamId.b);
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), 'AD');

      e.addPoint(TeamId.a);
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), '40');

      e.addPoint(TeamId.a);
      expect(e.state.points.labelFor(TeamId.a), 'AD');
      e.undo();
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), '40');
    });
  });

  group('FIP Star Point scoring', () {
    void reachFirstDeuce(PadelScoringEngine e) {
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
      }
    }

    test('deuce 1 → AD1 → deuce 2 → AD2 → Star Point → game', () {
      final e = engine(MatchFormat.starPointBo3)..start();
      reachFirstDeuce(e);

      expect(e.state.points.deuceNumber, 1);
      expect(e.state.points.isStarPoint, isFalse);
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.starPoint,
        ),
        'PARITÀ 1 · prossimo punto vale VANTAGGIO 1',
      );

      e.addPoint(TeamId.a); // Advantage 1 A.
      expect(e.state.points.advantage, TeamId.a);
      expect(e.state.points.deuceNumber, 1);
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.starPoint,
        ),
        'VANTAGGIO 1 NOI · un punto per il game',
      );

      e.addPoint(TeamId.b); // Deuce 2.
      expect(e.state.points.advantage, isNull);
      expect(e.state.points.deuceNumber, 2);
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.starPoint,
        ),
        'PARITÀ 2 · prossimo punto vale VANTAGGIO 2',
      );

      e.addPoint(TeamId.b); // Advantage 2 B.
      expect(e.state.points.advantage, TeamId.b);
      expect(e.state.points.deuceNumber, 2);
      e.addPoint(TeamId.a); // Deuce 3 / Star Point.
      expect(e.state.points.advantage, isNull);
      expect(e.state.points.deuceNumber, 3);
      expect(e.state.points.isStarPoint, isTrue);
      expect(
        e.state.points.situationLabel(
          gameScoringMode: GameScoringMode.starPoint,
        ),
        'STAR POINT · prossimo punto decide il game',
      );

      final result = e.addPoint(TeamId.b);
      expect(result.transitions, contains(ScoreTransition.gameWon));
      expect(e.state.gamesB, 1);
      expect(e.state.points.deuceNumber, 0);
      final deciding = e.pointRecords.last;
      expect(deciding.isStarPoint, isTrue);
      expect(deciding.gamePointFor, {TeamId.a, TeamId.b});
      expect(deciding.breakPointFor, {TeamId.b});
    });

    test('the holder can close the game from advantage 1 or advantage 2', () {
      final fromAdvantageOne = engine(MatchFormat.starPointBo3)..start();
      reachFirstDeuce(fromAdvantageOne);
      fromAdvantageOne.addPoint(TeamId.a);
      fromAdvantageOne.addPoint(TeamId.a);
      expect(fromAdvantageOne.state.gamesA, 1);

      final fromAdvantageTwo = engine(MatchFormat.starPointBo3)..start();
      reachFirstDeuce(fromAdvantageTwo);
      fromAdvantageTwo.addPoint(TeamId.a);
      fromAdvantageTwo.addPoint(TeamId.b); // Deuce 2.
      fromAdvantageTwo.addPoint(TeamId.b);
      fromAdvantageTwo.addPoint(TeamId.b);
      expect(fromAdvantageTwo.state.gamesB, 1);
    });

    test('undo restores the exact Star Point phase across game boundary', () {
      final e = engine(MatchFormat.starPointBo3)..start();
      reachFirstDeuce(e);
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b); // Deuce 2.
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.a); // Deuce 3.
      e.addPoint(TeamId.b); // Game B.
      expect(e.state.gamesB, 1);

      e.undo();
      expect(e.state.gamesB, 0);
      expect(e.state.points.deuceNumber, 3);
      expect(e.state.points.isStarPoint, isTrue);

      e.undo(); // Undo the point that cancelled Advantage 2 B.
      expect(e.state.points.advantage, TeamId.b);
      expect(e.state.points.deuceNumber, 2);
    });

    test('score edit carries phase and legacy 40-40 defaults to deuce 1', () {
      final legacy = engine(MatchFormat.starPointBo3)..start();
      legacy.editScore(pointsA: 3, pointsB: 3, gamesA: 2, gamesB: 2);
      expect(legacy.state.points.deuceNumber, 1);
      expect(legacy.state.points.isStarPoint, isFalse);

      final explicit = engine(MatchFormat.starPointBo3)..start();
      final edit = explicit.editScore(
        pointsA: 3,
        pointsB: 3,
        gamesA: 2,
        gamesB: 2,
        deuceNumber: 3,
      );
      expect(edit.newEvents.single.payload?['deuceNumber'], 3);
      expect(explicit.state.points.deuceNumber, 3);
      expect(explicit.state.points.isStarPoint, isTrue);
      explicit.addPoint(TeamId.a);
      expect(explicit.state.gamesA, 3);
    });

    test(
      'score edit preserves advantage phases and normalizes invalid 4-4',
      () {
        final advantage = engine(MatchFormat.starPointBo3)..start();
        advantage.editScore(
          pointsA: 4,
          pointsB: 3,
          gamesA: 1,
          gamesB: 1,
          deuceNumber: 2,
        );
        expect(advantage.state.points.advantage, TeamId.a);
        expect(advantage.state.points.deuceNumber, 2);
        advantage.addPoint(TeamId.a);
        expect(advantage.state.gamesA, 2);

        final invalid = engine(MatchFormat.starPointBo3)..start();
        invalid.editScore(
          pointsA: 4,
          pointsB: 4,
          gamesA: 0,
          gamesB: 0,
          deuceNumber: 3,
        );
        expect(invalid.state.points.advantage, isNull);
        expect(invalid.state.points.isStarPoint, isTrue);
      },
    );

    test('replay reconstructs deuce number without persisted snapshots', () {
      final original = engine(MatchFormat.starPointBo3)..start();
      reachFirstDeuce(original);
      original.addPoint(TeamId.a);
      original.addPoint(TeamId.b);
      original.addPoint(TeamId.b);
      original.addPoint(TeamId.a);
      expect(original.state.points.deuceNumber, 3);

      final replayed = PadelScoringEngine.replay(
        matchId: original.matchId,
        format: MatchFormat.starPointBo3,
        events: original.events,
      );
      expect(replayed.state.display, original.state.display);
      expect(replayed.state.points.deuceNumber, 3);
      expect(replayed.state.points.isStarPoint, isTrue);
      expect(replayed.state.toJson()['deuceNumber'], 3);
      expect(replayed.state.toJson()['isStarPoint'], isTrue);
    });
  });

  group('sets and tie-break', () {
    test('6-0 wins the set', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winSet(e, TeamId.a);
      expect(e.state.setsA, 1);
      expect(e.state.completedSets.single.gamesA, 6);
      expect(e.state.completedSets.single.gamesB, 0);
    });

    test('7-5 wins the set (no tie-break at 6-5)', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 5; i++) {
        winGame(e, TeamId.a);
        winGame(e, TeamId.b);
      }
      expect(e.state.gamesA, 5);
      expect(e.state.gamesB, 5);
      winGame(e, TeamId.a); // 6-5
      expect(e.state.setsA, 0);
      winGame(e, TeamId.a); // 7-5
      expect(e.state.setsA, 1);
      expect(e.state.completedSets.single.gamesA, 7);
      expect(e.state.completedSets.single.gamesB, 5);
    });

    test('tie-break at 6-6, first to 7 by 2, recorded 7-6', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 6; i++) {
        winGame(e, TeamId.a);
        winGame(e, TeamId.b);
      }
      expect(e.state.inTieBreak, isTrue);
      // 6-6 in the TB, then 8-6.
      for (var i = 0; i < 6; i++) {
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
      }
      expect(e.state.inTieBreak, isTrue);
      e.addPoint(TeamId.a);
      expect(e.state.inTieBreak, isTrue); // 7-6, only 1 ahead
      e.addPoint(TeamId.a); // 8-6
      expect(e.state.setsA, 1);
      final s = e.state.completedSets.single;
      expect(s.gamesA, 7);
      expect(s.gamesB, 6);
      expect(s.tieBreakA, 8);
      expect(s.tieBreakB, 6);
    });

    test('tie-break serve rotation 1-2-2 and side change every 6', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 6; i++) {
        winGame(e, TeamId.a);
        winGame(e, TeamId.b);
      }
      final first = e.state.servingTeam;
      e.addPoint(TeamId.a); // after point 1 serve switches
      expect(e.state.servingTeam, first.opponent);
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.a); // points 2,3 done → back to first
      expect(e.state.servingTeam, first);
      // 6 total points → side change flag
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.a);
      final r = e.addPoint(TeamId.b);
      expect(r.transitions, contains(ScoreTransition.sideChange));
    });
  });

  // FIP Rules of Padel, Rule 11 (Change of ends): every odd game, and at the
  // end of a set only when that set's total number of games is odd.
  group('change of ends', () {
    test('set won 6-4 does not change ends (even total)', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 4; i++) {
        playGame(e, TeamId.a);
        playGame(e, TeamId.b);
      }
      playGame(e, TeamId.a); // 5-4
      final r = playGame(e, TeamId.a); // 6-4 → set
      expect(r.transitions, contains(ScoreTransition.setWon));
      expect(r.transitions, isNot(contains(ScoreTransition.sideChange)));
      expect(e.state.sideChangePending, isFalse);
    });

    test('deferred change happens after game 1 of the next set', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 4; i++) {
        playGame(e, TeamId.a);
        playGame(e, TeamId.b);
      }
      playGame(e, TeamId.a);
      playGame(e, TeamId.a); // 6-4, no change of ends yet
      final r = playGame(e, TeamId.b); // first game of set 2
      expect(r.transitions, contains(ScoreTransition.sideChange));
      expect(e.state.sideChangePending, isTrue);
    });

    test('set won 6-3 changes ends (odd total)', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 3; i++) {
        playGame(e, TeamId.a);
        playGame(e, TeamId.b);
      }
      playGame(e, TeamId.a);
      playGame(e, TeamId.a); // 5-3
      final r = playGame(e, TeamId.a); // 6-3 → set
      expect(r.transitions, contains(ScoreTransition.setWon));
      expect(r.transitions, contains(ScoreTransition.sideChange));
      expect(e.state.sideChangePending, isTrue);
    });

    test('set won 6-0 does not change ends', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 5; i++) {
        playGame(e, TeamId.a);
      }
      final r = playGame(e, TeamId.a); // 6-0 → set
      expect(r.transitions, isNot(contains(ScoreTransition.sideChange)));
      expect(e.state.sideChangePending, isFalse);
    });

    test('set won on tie-break changes ends (7-6 = 13 games)', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      for (var i = 0; i < 6; i++) {
        playGame(e, TeamId.a);
        playGame(e, TeamId.b);
      }
      expect(e.state.inTieBreak, isTrue);
      late ScoringResult r;
      for (var i = 0; i < 7; i++) {
        r = e.addPoint(TeamId.a);
      }
      expect(r.transitions, contains(ScoreTransition.setWon));
      expect(r.transitions, contains(ScoreTransition.sideChange));
      expect(e.state.sideChangePending, isTrue);
    });

    test('match-winning set leaves no pending change of ends', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winSet(e, TeamId.a);
      for (var i = 0; i < 3; i++) {
        playGame(e, TeamId.a);
        playGame(e, TeamId.b);
      }
      playGame(e, TeamId.a);
      playGame(e, TeamId.a); // 5-3
      final r = playGame(e, TeamId.a); // 6-3 → set and match
      expect(r.transitions, contains(ScoreTransition.matchWon));
      expect(e.state.isCompleted, isTrue);
      expect(e.state.sideChangePending, isFalse);
    });
  });

  // FIP Regola 4: chi serve per primo si decide al sorteggio. Break e hold
  // sono derivati dalla rotazione, quindi devono seguire quella scelta.
  group('first server', () {
    PadelScoringEngine engineServing(TeamId first) {
      var t = 0;
      var i = 0;
      return PadelScoringEngine(
        matchId: 'm-first-server',
        format: MatchFormat.goldenPointBo3,
        firstServer: first,
        clock: () => t += 1000,
        idGenerator: () => 'e${i++}',
      );
    }

    test('team B serving first owns the rotation', () {
      final e = engineServing(TeamId.b)..start();
      expect(e.state.servingTeam, TeamId.b);
      playGame(e, TeamId.a);
      expect(e.state.servingTeam, TeamId.a);
      playGame(e, TeamId.a);
      expect(e.state.servingTeam, TeamId.b);
    });

    test('break point belongs to the returning team', () {
      final e = engineServing(TeamId.b)..start();
      for (var i = 0; i < 3; i++) {
        e.addPoint(TeamId.a);
      }
      // A is returning: 40-0 for A is a break point, not a hold.
      final record = e.pointRecords.last;
      expect(record.servingTeam, TeamId.b);
      final next = e.addPoint(TeamId.a);
      expect(next.transitions, contains(ScoreTransition.gameWon));
      expect(e.pointRecords.last.breakPointFor, contains(TeamId.a));
    });

    test('replay keeps the first server it was given', () {
      final e = engineServing(TeamId.b)..start();
      playGame(e, TeamId.a);
      final replayed = PadelScoringEngine.replay(
        matchId: 'm-first-server',
        format: MatchFormat.goldenPointBo3,
        events: e.events,
        firstServer: TeamId.b,
      );
      expect(replayed.state.servingTeam, e.state.servingTeam);
      expect(replayed.state.servingTeam, TeamId.a);
    });
  });

  group('match completion', () {
    test('two sets win the match', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winSet(e, TeamId.a);
      winSet(e, TeamId.a);
      expect(e.state.isCompleted, isTrue);
      expect(e.state.winner, TeamId.a);
      // No points accepted after completion.
      final r = e.addPoint(TeamId.b);
      expect(r.newEvents, isEmpty);
    });

    test('super tie-break decides third set', () {
      final e = engine(MatchFormat.superTieBreakBo3)..start();
      winSet(e, TeamId.a);
      winSet(e, TeamId.b);
      expect(e.state.inSuperTieBreak, isTrue);
      for (var i = 0; i < 9; i++) {
        e.addPoint(TeamId.a);
      }
      expect(e.state.isCompleted, isFalse);
      e.addPoint(TeamId.a); // 10-0
      expect(e.state.isCompleted, isTrue);
      expect(e.state.winner, TeamId.a);
      expect(e.state.completedSets.last.isSuperTieBreak, isTrue);
      expect(e.state.completedSets.last.tieBreakA, 10);
    });

    test('single set format ends after one set', () {
      final e = engine(MatchFormat.singleSet)..start();
      winSet(e, TeamId.b);
      expect(e.state.isCompleted, isTrue);
      expect(e.state.winner, TeamId.b);
    });

    test('training free play counts rally points, manual finish', () {
      final e = engine(MatchFormat.training)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      expect(e.state.freePlayA, 2);
      expect(e.state.freePlayB, 1);
      expect(e.state.isCompleted, isFalse);
      e.finish();
      expect(e.state.isCompleted, isTrue);
      expect(e.state.winner, TeamId.a);
    });

    test('score edits cannot mutate a completed match live or on replay', () {
      final e = engine(MatchFormat.training)..start();
      e.addPoint(TeamId.a);
      e.finish(winner: TeamId.a);
      final eventCount = e.events.length;

      final edit = e.editScore(pointsA: 0, pointsB: 0, gamesA: 4, gamesB: 3);
      expect(edit.newEvents, isEmpty);
      expect(e.events, hasLength(eventCount));
      expect(e.state.freePlayA, 1);

      final lateEdit = MatchEvent(
        eventId: 'late-edit',
        matchId: e.matchId,
        timestampMs: 999999,
        type: MatchEventType.scoreEdited,
        sourceMethod: SourceMethod.manualEdit,
        payload: const {'pointsA': 0, 'pointsB': 0, 'gamesA': 4, 'gamesB': 3},
      );
      final replayed = PadelScoringEngine.replay(
        matchId: e.matchId,
        format: MatchFormat.training,
        events: [...e.events, lateEdit],
      );
      expect(replayed.state.isCompleted, isTrue);
      expect(replayed.state.freePlayA, 1);
      expect(replayed.state.gamesA, 0);
    });
  });

  group('undo', () {
    test('undo reverts a simple point', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      expect(e.state.points.labelFor(TeamId.a), '15');
      e.undo();
      expect(e.state.points.labelFor(TeamId.a), '0');
      expect(e.canUndo, isFalse);
    });

    test('undo works across a game boundary', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winGame(e, TeamId.a);
      expect(e.state.gamesA, 1);
      e.undo();
      expect(e.state.gamesA, 0);
      expect(e.state.points.labelFor(TeamId.a), '40');
    });

    test('undo works across a set boundary', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winSet(e, TeamId.a);
      expect(e.state.setsA, 1);
      e.undo();
      expect(e.state.setsA, 0);
      expect(e.state.gamesA, 5);
    });

    test('undo after match completion reopens the match', () {
      final e = engine(MatchFormat.singleSet)..start();
      winSet(e, TeamId.a);
      expect(e.state.isCompleted, isTrue);
      e.undo();
      expect(e.state.isCompleted, isFalse);
      expect(e.state.setsA, 0);
    });

    test(
      'manual finish seals the match: undo and double finish are no-ops',
      () {
        final e = engine(MatchFormat.training)..start();
        e.addPoint(TeamId.a);
        e.addPoint(TeamId.b);
        e.finish(winner: TeamId.a);
        expect(e.state.isCompleted, isTrue);
        expect(e.canUndo, isFalse);
        final eventCount = e.events.length;
        final undo = e.undo();
        expect(undo.newEvents, isEmpty);
        expect(e.state.freePlayA, 1);
        expect(e.state.isCompleted, isTrue);
        final again = e.finish(winner: TeamId.b);
        expect(again.newEvents, isEmpty);
        expect(e.events, hasLength(eventCount));
        expect(e.state.winner, TeamId.a);
      },
    );

    test('free-play display shows rally counters', () {
      final e = engine(MatchFormat.training)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      expect(e.state.display, '2-1');
    });

    test('multiple undos pop in order', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.a);
      e.undo();
      e.undo();
      expect(e.state.points.labelFor(TeamId.a), '15');
      expect(e.state.points.labelFor(TeamId.b), '0');
    });
  });

  group('team-scoped undo (Duo Mode)', () {
    test('undo(team) cancels the last point of that team only', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b); // last event overall is B's
      e.undo(team: TeamId.a);
      expect(e.state.points.labelFor(TeamId.a), '0');
      expect(e.state.points.labelFor(TeamId.b), '15');
    });

    test('undo(team) with no team point is a no-op', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      expect(e.canUndoTeam(TeamId.b), isFalse);
      final r = e.undo(team: TeamId.b);
      expect(r.newEvents, isEmpty);
      expect(e.state.points.labelFor(TeamId.a), '15');
    });

    test('team undo is order-independent across interleaved logs', () {
      // Device 1 order: A, B, UNDO(A) — device 2 order: B, A, UNDO(A).
      MatchEvent evt(String id, int ts, MatchEventType t, {TeamId? team}) =>
          MatchEvent(
            eventId: id,
            matchId: 'm1',
            timestampMs: ts,
            type: t,
            teamId: team,
          );
      final d1 = [
        evt('s', 0, MatchEventType.matchStarted),
        evt('pa', 1, MatchEventType.pointTeamA, team: TeamId.a),
        evt('pb', 2, MatchEventType.pointTeamB, team: TeamId.b),
        evt('u', 3, MatchEventType.undo, team: TeamId.a),
      ];
      final d2 = [d1[0], d1[2], d1[1], d1[3]];
      final e1 = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: d1,
      );
      final e2 = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: d2,
      );
      expect(e1.state.points.labelFor(TeamId.a), '0');
      expect(e1.state.points.labelFor(TeamId.b), '15');
      expect(e2.state.display, e1.state.display);
    });

    test('global undo still cancels the most recent event', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      e.undo();
      expect(e.state.points.labelFor(TeamId.a), '15');
      expect(e.state.points.labelFor(TeamId.b), '0');
    });

    test('targetEventId undo cancels the exact point (Garmin/Fitbit wire)', () {
      MatchEvent evt(
        String id,
        int ts,
        MatchEventType t, {
        TeamId? team,
        Map<String, Object?>? payload,
      }) => MatchEvent(
        eventId: id,
        matchId: 'm1',
        timestampMs: ts,
        type: t,
        teamId: team,
        payload: payload,
      );
      final log = [
        evt('s', 0, MatchEventType.matchStarted),
        evt('pa', 1, MatchEventType.pointTeamA, team: TeamId.a),
        evt('pb', 2, MatchEventType.pointTeamB, team: TeamId.b),
        evt(
          'u',
          3,
          MatchEventType.undo,
          team: TeamId.a,
          payload: const {'targetEventId': 'pa'},
        ),
      ];
      final replayed = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: log,
      );
      expect(replayed.state.points.labelFor(TeamId.a), '0');
      expect(replayed.state.points.labelFor(TeamId.b), '15');
    });
  });

  group('event sourcing / reconstruction', () {
    test('state is fully reconstructible from the event log', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winSet(e, TeamId.a);
      winGame(e, TeamId.b);
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      e.undo();

      final rebuilt = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: e.events,
      );
      expect(rebuilt.state.display, e.state.display);
      expect(rebuilt.state.setsA, e.state.setsA);
      expect(rebuilt.state.gamesB, e.state.gamesB);
      expect(rebuilt.pointRecords.length, e.pointRecords.length);
    });

    test('JSON round-trip preserves the log', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.b);
      e.undo();
      final json = e.eventsToJson();
      final events = json.map(MatchEvent.fromJson).toList();
      final rebuilt = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: events,
      );
      expect(rebuilt.state.display, e.state.display);
    });

    test('derived events are appended for audit', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      winGame(e, TeamId.a);
      expect(
        e.events.map((ev) => ev.type),
        contains(MatchEventType.gameCompleted),
      );
    });
  });

  group('serving rotation', () {
    test('teams alternate serve every game', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      expect(e.state.servingTeam, TeamId.a);
      winGame(e, TeamId.a);
      expect(e.state.servingTeam, TeamId.b);
      winGame(e, TeamId.a);
      expect(e.state.servingTeam, TeamId.a);
    });
  });

  group('pause/resume and edit', () {
    test('pause and resume change status', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.pause();
      expect(e.state.status, MatchStatus.paused);
      e.resume();
      expect(e.state.status, MatchStatus.inProgress);
    });

    test('points queued after pause cannot mutate the match', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.pause();
      final eventCount = e.events.length;

      final result = e.addPoint(TeamId.a);

      expect(result.newEvents, isEmpty);
      expect(e.events, hasLength(eventCount));
      expect(e.state.status, MatchStatus.paused);
      expect(e.state.points.labelFor(TeamId.a), '0');
    });

    test(
      'replay applies delayed watch point after pause as implicit resume',
      () {
        MatchEvent event(String id, int timestamp, MatchEventType type) =>
            MatchEvent(
              eventId: id,
              matchId: 'm1',
              timestampMs: timestamp,
              type: type,
              teamId: type == MatchEventType.pointTeamA ? TeamId.a : null,
            );
        final replayed = PadelScoringEngine.replay(
          matchId: 'm1',
          format: MatchFormat.goldenPointBo3,
          events: [
            event('start', 1, MatchEventType.matchStarted),
            event('pause', 2, MatchEventType.matchPaused),
            event('late-point', 3, MatchEventType.pointTeamA),
          ],
        );

        // Dual-device desync: journal points after pause resume then score.
        expect(replayed.state.status, MatchStatus.inProgress);
        expect(replayed.state.points.labelFor(TeamId.a), '15');
        expect(replayed.pointRecords, hasLength(1));
      },
    );

    test('undo and score edit are no-ops while paused', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.pause();
      final eventCount = e.events.length;

      final undo = e.undo();
      final edit = e.editScore(pointsA: 3, pointsB: 2, gamesA: 4, gamesB: 3);

      expect(undo.newEvents, isEmpty);
      expect(edit.newEvents, isEmpty);
      expect(e.events, hasLength(eventCount));
      expect(e.state.status, MatchStatus.paused);
      expect(e.state.points.labelFor(TeamId.a), '15');
      expect(e.state.gamesA, 0);
    });

    test(
      'replay ignores paused undo and edit without poisoning later undo',
      () {
        MatchEvent event(
          String id,
          int timestamp,
          MatchEventType type, {
          TeamId? team,
          Map<String, Object?>? payload,
        }) => MatchEvent(
          eventId: id,
          matchId: 'm1',
          timestampMs: timestamp,
          type: type,
          teamId: team,
          payload: payload,
        );

        final replayed = PadelScoringEngine.replay(
          matchId: 'm1',
          format: MatchFormat.goldenPointBo3,
          events: [
            event('start', 1, MatchEventType.matchStarted),
            event('point-a', 2, MatchEventType.pointTeamA, team: TeamId.a),
            event('pause', 3, MatchEventType.matchPaused),
            event('paused-undo', 4, MatchEventType.undo),
            event(
              'paused-edit',
              5,
              MatchEventType.scoreEdited,
              payload: const {
                'pointsA': 3,
                'pointsB': 0,
                'gamesA': 4,
                'gamesB': 0,
              },
            ),
            event('resume', 6, MatchEventType.matchResumed),
            event('point-b', 7, MatchEventType.pointTeamB, team: TeamId.b),
            event('valid-undo', 8, MatchEventType.undo),
          ],
        );

        expect(replayed.state.status, MatchStatus.inProgress);
        expect(replayed.state.points.labelFor(TeamId.a), '15');
        expect(replayed.state.points.labelFor(TeamId.b), '0');
        expect(replayed.state.gamesA, 0);
        expect(replayed.pointRecords.map((record) => record.winner), [
          TeamId.a,
        ]);
      },
    );

    test('manual score edit applies and is undoable', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      e.editScore(pointsA: 2, pointsB: 3, gamesA: 4, gamesB: 2);
      expect(e.state.points.labelFor(TeamId.a), '30');
      expect(e.state.gamesA, 4);
      e.undo();
      expect(e.state.gamesA, 0);
      expect(e.state.points.labelFor(TeamId.a), '15');
    });
  });

  group('point records / analytics context', () {
    test('game point, break point and deuce flags', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      // A serves. Bring B to 40-0 → break point for B.
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.b);
      e.addPoint(TeamId.a); // record should carry breakPointFor B
      final r = e.pointRecords[3];
      expect(r.gamePointFor, {TeamId.b});
      expect(r.breakPointFor, {TeamId.b});
    });

    test('match point flag on championship point', () {
      final e = engine(MatchFormat.singleSet)..start();
      for (var i = 0; i < 5; i++) {
        winGame(e, TeamId.a);
      }
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.a);
      e.addPoint(TeamId.a); // 40-0, game/set/match point
      e.addPoint(TeamId.a); // match over
      final last = e.pointRecords.last;
      expect(last.matchPointFor, {TeamId.a});
      expect(last.setPointFor, {TeamId.a});
    });
  });

  group('duo mode', () {
    test('duo engine stamps attribution on every event', () {
      var t = 0;
      var i = 0;
      final e = PadelScoringEngine(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        duoMode: true,
        sourceUserId: 'user-a',
        assignedTeam: TeamId.a,
        clock: () => t += 1000,
        idGenerator: () => 'e${i++}',
      )..start();
      final r = e.addPoint(TeamId.a);
      final point = r.newEvents.first;
      expect(point.duoMode, isTrue);
      expect(point.sourceUserId, 'user-a');
      expect(point.sourceTeamId, TeamId.a);
      expect(point.createdLocallyAtMs, isNotNull);
    });

    test('duo attribution fields survive JSON round-trip', () {
      final e = MatchEvent(
        eventId: 'evt1',
        matchId: 'm1',
        timestampMs: 1,
        type: MatchEventType.pointTeamB,
        teamId: TeamId.b,
        duoMode: true,
        sourceUserId: 'user-b',
        sourceTeamId: TeamId.b,
        createdLocallyAtMs: 42,
      );
      final back = MatchEvent.fromJson(e.toJson());
      expect(back.duoMode, isTrue);
      expect(back.sourceUserId, 'user-b');
      expect(back.sourceTeamId, TeamId.b);
      expect(back.createdLocallyAtMs, 42);
    });

    test('non-duo events keep the pre-duo wire format', () {
      final e = MatchEvent(
        eventId: 'evt1',
        matchId: 'm1',
        timestampMs: 1,
        type: MatchEventType.pointTeamA,
        teamId: TeamId.a,
      );
      final json = e.toJson();
      expect(json.containsKey('duo'), isFalse);
      expect(json.containsKey('sourceUserId'), isFalse);
      expect(json.containsKey('sourceTeamId'), isFalse);
      expect(json.containsKey('createdLocallyAt'), isFalse);
    });

    test('session lifecycle events are audit-only on replay', () {
      final e = engine(MatchFormat.goldenPointBo3)..start();
      e.addPoint(TeamId.a);
      final withLifecycle = [
        ...e.events,
        MatchEvent(
          eventId: 'j1',
          matchId: 'm1',
          timestampMs: 99,
          type: MatchEventType.deviceJoinedMatch,
          sourceTeamId: TeamId.b,
          duoMode: true,
        ),
        MatchEvent(
          eventId: 'c1',
          matchId: 'm1',
          timestampMs: 100,
          type: MatchEventType.teamConfirmed,
          teamId: TeamId.b,
          duoMode: true,
        ),
      ];
      final replayed = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: withLifecycle,
      );
      expect(replayed.state.points.labelFor(TeamId.a), '15');
      expect(replayed.state.status, MatchStatus.inProgress);
    });

    test('team undos from both devices converge on interleaved logs', () {
      // Device 1 log: A, B, UNDO(A) — Device 2 log: B, A, UNDO(A).
      MatchEvent pt(String id, TeamId team, int ts) => MatchEvent(
        eventId: id,
        matchId: 'm1',
        timestampMs: ts,
        type: team == TeamId.a
            ? MatchEventType.pointTeamA
            : MatchEventType.pointTeamB,
        teamId: team,
      );
      MatchEvent und(String id, TeamId team, int ts) => MatchEvent(
        eventId: id,
        matchId: 'm1',
        timestampMs: ts,
        type: MatchEventType.undo,
        teamId: team,
      );
      final log1 = [
        pt('a1', TeamId.a, 1),
        pt('b1', TeamId.b, 2),
        und('u1', TeamId.a, 3),
      ];
      final log2 = [
        pt('b1', TeamId.b, 2),
        pt('a1', TeamId.a, 1),
        und('u1', TeamId.a, 3),
      ];
      final s1 = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: log1,
      ).state;
      final s2 = PadelScoringEngine.replay(
        matchId: 'm1',
        format: MatchFormat.goldenPointBo3,
        events: log2,
      ).state;
      expect(s1.points.labelFor(TeamId.a), s2.points.labelFor(TeamId.a));
      expect(s1.points.labelFor(TeamId.b), s2.points.labelFor(TeamId.b));
      expect(s1.points.labelFor(TeamId.a), '0');
      expect(s1.points.labelFor(TeamId.b), '15');
    });
  });
}
