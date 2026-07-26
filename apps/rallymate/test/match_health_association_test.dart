import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/match_health_association.dart';

void main() {
  const policy = MatchHealthAssociationPolicy();
  final matchStart = DateTime(2026, 7, 13, 18);
  final matchEnd = DateTime(2026, 7, 13, 19, 30);

  test('shared match ID is associated automatically', () {
    final decision = policy.choose(
      matchId: 'match-1',
      matchStart: matchStart,
      matchEnd: matchEnd,
      workouts: [
        HealthWorkoutCandidate(
          id: 'workout-1',
          provider: 'RALLYMATE',
          start: matchStart,
          end: matchEnd,
          activityType: 'padel',
          sharedMatchId: 'match-1',
        ),
      ],
    );

    expect(decision.action, MatchHealthAssociationAction.automatic);
    expect(decision.confidence, 1);
    expect(decision.reason, 'shared_match_id');
  });

  test('strong temporal match asks for confirmation without shared ID', () {
    final decision = policy.choose(
      matchId: 'match-1',
      matchStart: matchStart,
      matchEnd: matchEnd,
      workouts: [
        HealthWorkoutCandidate(
          id: 'workout-2',
          provider: 'APPLE_HEALTH',
          start: matchStart.add(const Duration(minutes: 10)),
          end: matchEnd.subtract(const Duration(minutes: 10)),
          activityType: 'racquet_sport',
        ),
      ],
    );

    expect(decision.action, MatchHealthAssociationAction.askUser);
    expect(decision.confidence, greaterThan(0.85));
  });

  test('uncertain workout is never associated automatically', () {
    final decision = policy.choose(
      matchId: 'match-1',
      matchStart: matchStart,
      matchEnd: matchEnd,
      workouts: [
        HealthWorkoutCandidate(
          id: 'workout-3',
          provider: 'HEALTH_CONNECT',
          start: DateTime(2026, 7, 13, 10),
          end: DateTime(2026, 7, 13, 11),
          activityType: 'walking',
        ),
      ],
    );

    expect(decision.action, MatchHealthAssociationAction.none);
    expect(decision.workout, isNull);
  });

  test('synthetic preferred padel window must not force automatic HIGH', () {
    // Regression: a fake full-window "padel" preferred candidate used to score
    // ~1.0 and auto-associate with HIGH quality despite no real OS workout.
    final decision = policy.choose(
      matchId: 'match-1',
      matchStart: matchStart,
      matchEnd: matchEnd,
      workouts: const [],
    );

    expect(decision.action, MatchHealthAssociationAction.none);
    expect(decision.workout, isNull);
    expect(decision.confidence, 0);
  });

  test('full-window preferred padel is automatic only with real candidate', () {
    final decision = policy.choose(
      matchId: 'match-1',
      matchStart: matchStart,
      matchEnd: matchEnd,
      workouts: [
        HealthWorkoutCandidate(
          id: 'real-workout',
          provider: 'RALLYMATE',
          start: matchStart,
          end: matchEnd,
          activityType: 'padel',
          isPreferredSource: true,
          sharedMatchId: 'match-1',
        ),
      ],
    );

    expect(decision.action, MatchHealthAssociationAction.automatic);
    expect(decision.reason, 'shared_match_id');
  });
}
