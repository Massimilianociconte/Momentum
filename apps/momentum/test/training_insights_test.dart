import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/domain/training_insights.dart';

TrainingLog _log(DateTime day, {int rpe = 6, int minutes = 30}) => TrainingLog(
  id: 'tl_${day.millisecondsSinceEpoch}_$rpe',
  trainingId: 'tr_volee',
  dateMs: day.millisecondsSinceEpoch,
  completed: true,
  notes: '',
  rpe: rpe,
  minutes: minutes,
);

MatchSummary _match({
  required bool won,
  int tbWon = 0,
  int tbPlayed = 0,
  int clutch = 70,
}) => MatchSummary(
  matchId: 'm$tbWon$tbPlayed$won',
  endTimeMs: 0,
  won: won,
  pointsFor: 40,
  pointsAgainst: 30,
  gamesFor: 6,
  gamesAgainst: 3,
  setsFor: 1,
  setsAgainst: 0,
  clutchScore: clutch,
  bestStreak: 4,
  durationMs: 3600000,
  teamId: null,
  roleplayed: PadelRole.left,
  opponentDifficulty: OpponentDifficulty.sameLevel,
  opponentTags: const {},
  tieBreakPointsWon: tbWon,
  tieBreakPointsPlayed: tbPlayed,
);

void main() {
  final monday = DateTime(2026, 7, 6); // lunedì

  test('empty logs → zero load, building zone', () {
    final load = TrainingLoad.compute(monday, const []);
    expect(load.sessionsThisWeek, 0);
    expect(load.minutesThisWeek, 0);
    expect(load.streakDays, 0);
    expect(load.acwr, 0);
    expect(load.zone, 'building');
  });

  test('streak counts consecutive days back from today', () {
    final logs = [
      _log(monday),
      _log(monday.subtract(const Duration(days: 1))),
      _log(monday.subtract(const Duration(days: 2))),
      // buco al giorno 3
      _log(monday.subtract(const Duration(days: 5))),
    ];
    final load = TrainingLoad.compute(monday, logs);
    expect(load.streakDays, 3);
    expect(load.sessionsThisWeek, 1); // solo il lunedì è in settimana
  });

  test('acwr flags a load spike over chronic baseline', () {
    final logs = <TrainingLog>[
      // 4 settimane croniche: 1 sessione standard/settimana.
      for (var week = 1; week <= 4; week++)
        _log(monday.subtract(Duration(days: 7 * week)), rpe: 6, minutes: 30),
      // settimana acuta: 5 sessioni dure.
      for (var d = 0; d < 5; d++)
        _log(monday.subtract(Duration(days: d)), rpe: 9, minutes: 60),
    ];
    final load = TrainingLoad.compute(monday, logs);
    expect(load.acwr, greaterThan(1.5));
    expect(load.zone, 'danger');
  });

  test(
    'recommendFocus prioritizes tie-break weakness over generic winrate',
    () {
      final summaries = [
        for (var i = 0; i < 4; i++)
          _match(won: true, tbWon: 1, tbPlayed: 5, clutch: 80),
      ];
      final plan = recommendFocus(summaries);
      expect(plan.focus, contains('tie-break'));
      expect(plan.suggestedTrainingIds, contains('tr_p_tb'));
    },
  );

  test('recommendFocus without data suggests base templates', () {
    final plan = recommendFocus(const []);
    expect(plan.suggestedTrainingIds, isNotEmpty);
  });
}
