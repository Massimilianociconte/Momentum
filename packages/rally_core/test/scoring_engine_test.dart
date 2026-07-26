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
        e.state.points.situationLabel(goldenPoint: true),
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
        e.state.points.situationLabel(goldenPoint: false),
        '40 PARI · si gioca ai vantaggi',
      );
      e.addPoint(TeamId.a); // AD A
      expect(e.state.points.labelFor(TeamId.a), 'AD');
      expect(
        e.state.points.situationLabel(goldenPoint: false),
        'VANTAGGIO NOI · un punto per il game',
      );
      e.addPoint(TeamId.b); // back to deuce
      expect(e.state.points.labelFor(TeamId.a), '40');
      expect(e.state.points.labelFor(TeamId.b), '40');
      expect(
        e.state.points.situationLabel(goldenPoint: false),
        '40 PARI · si gioca ai vantaggi',
      );
      e.addPoint(TeamId.b); // AD B
      expect(
        e.state.points.situationLabel(
          goldenPoint: false,
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

    test('manual finish seals the match: undo and double finish are no-ops', () {
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
    });

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

    test('replay applies delayed watch point after pause as implicit resume',
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
    });

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
