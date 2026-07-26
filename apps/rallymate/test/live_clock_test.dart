import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/features/live/live_match_controller.dart';
import 'package:rallymate/features/live/live_scoring_screen.dart';

void main() {
  test('match clock resumes from the durable start time after reopening', () {
    final now = DateTime.utc(2026, 7, 18, 12);
    final start = now.subtract(const Duration(hours: 1, minutes: 7));

    expect(
      matchElapsedFromStart(start.millisecondsSinceEpoch, clock: now),
      const Duration(hours: 1, minutes: 7),
    );
  });

  test('match clock clamps invalid future or implausibly old starts', () {
    final now = DateTime.utc(2026, 7, 18, 12);
    expect(
      matchElapsedFromStart(
        now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        clock: now,
      ),
      Duration.zero,
    );
    expect(
      matchElapsedFromStart(
        now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
        clock: now,
      ),
      const Duration(hours: 12),
    );
  });

  test('active clock excludes an overnight pause and resumes from it', () {
    final start = DateTime.utc(2026, 7, 17, 9);
    final pause = start.add(const Duration(minutes: 10));
    final resume = DateTime.utc(2026, 7, 18, 8);
    final now = resume.add(const Duration(minutes: 5));
    MatchEvent event(String id, MatchEventType type, DateTime timestamp) =>
        MatchEvent(
          eventId: id,
          matchId: 'clock',
          timestampMs: timestamp.millisecondsSinceEpoch,
          type: type,
        );

    expect(
      matchActiveElapsed(
        events: [
          event('start', MatchEventType.matchStarted, start),
          event('pause', MatchEventType.matchPaused, pause),
          event('resume', MatchEventType.matchResumed, resume),
        ],
        fallbackStartTimeMs: start.millisecondsSinceEpoch,
        clock: now,
      ),
      const Duration(minutes: 15),
    );
  });

  test('local scoring remains blocked until a paused match resumes', () {
    expect(canAcceptLocalPoint(MatchStatus.paused), isFalse);
    expect(canAcceptLocalPoint(MatchStatus.inProgress), isTrue);
  });
}
