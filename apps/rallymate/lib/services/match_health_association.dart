library;

class HealthWorkoutCandidate {
  const HealthWorkoutCandidate({
    required this.id,
    required this.provider,
    required this.start,
    required this.end,
    required this.activityType,
    this.sharedMatchId,
    this.isPreferredSource = false,
  });

  final String id;
  final String provider;
  final DateTime start;
  final DateTime end;
  final String activityType;
  final String? sharedMatchId;
  final bool isPreferredSource;
}

enum MatchHealthAssociationAction { automatic, askUser, none }

class MatchHealthAssociationDecision {
  const MatchHealthAssociationDecision({
    required this.action,
    required this.confidence,
    required this.reason,
    this.workout,
  });

  final MatchHealthAssociationAction action;
  final double confidence;
  final String reason;
  final HealthWorkoutCandidate? workout;
}

class MatchHealthAssociationPolicy {
  const MatchHealthAssociationPolicy({
    this.tolerance = const Duration(minutes: 20),
  });

  final Duration tolerance;

  MatchHealthAssociationDecision choose({
    required String matchId,
    required DateTime matchStart,
    required DateTime matchEnd,
    required Iterable<HealthWorkoutCandidate> workouts,
  }) {
    if (!matchEnd.isAfter(matchStart)) {
      return const MatchHealthAssociationDecision(
        action: MatchHealthAssociationAction.none,
        confidence: 0,
        reason: 'invalid_match_range',
      );
    }
    final ranked = workouts.map((workout) {
      if (workout.sharedMatchId == matchId) {
        return (workout: workout, score: 1.0, reason: 'shared_match_id');
      }
      final windowStart = matchStart.subtract(tolerance);
      final windowEnd = matchEnd.add(tolerance);
      final overlapStart = workout.start.isAfter(windowStart)
          ? workout.start
          : windowStart;
      final overlapEnd = workout.end.isBefore(windowEnd)
          ? workout.end
          : windowEnd;
      if (!overlapEnd.isAfter(overlapStart)) {
        return (workout: workout, score: 0.0, reason: 'no_time_overlap');
      }
      final matchDuration = matchEnd.difference(matchStart).inSeconds;
      final overlap = overlapEnd.difference(overlapStart).inSeconds;
      var score = matchDuration <= 0
          ? 0.0
          : (overlap / matchDuration).clamp(0, 1).toDouble();
      final normalizedType = workout.activityType.toLowerCase();
      if (const {
        'padel',
        'tennis',
        'racquet_sport',
        'racket_sport',
      }.contains(normalizedType)) {
        score += 0.12;
      }
      if (workout.isPreferredSource) score += 0.05;
      return (
        workout: workout,
        score: score.clamp(0.0, 1.0).toDouble(),
        reason: 'time_overlap',
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty || ranked.first.score < 0.55) {
      return const MatchHealthAssociationDecision(
        action: MatchHealthAssociationAction.none,
        confidence: 0,
        reason: 'insufficient_confidence',
      );
    }
    final best = ranked.first;
    return MatchHealthAssociationDecision(
      action: best.score >= 0.95
          ? MatchHealthAssociationAction.automatic
          : MatchHealthAssociationAction.askUser,
      confidence: best.score,
      reason: best.reason,
      workout: best.workout,
    );
  }
}
