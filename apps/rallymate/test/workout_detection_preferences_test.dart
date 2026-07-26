import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/workout_detection_preferences.dart';

void main() {
  group('WorkoutDetectionPreferences', () {
    test('defaults to an explicitly disabled and privacy-safe state', () {
      const preferences = WorkoutDetectionPreferences();

      expect(preferences.mode, WorkoutDetectionMode.off);
      expect(preferences.enabled, isFalse);
      expect(preferences.racketSportsOnly, isTrue);
      expect(preferences.onlyWhenWorn, isFalse);
    });

    test('round-trips the versioned wearable payload', () {
      const original = WorkoutDetectionPreferences(
        mode: WorkoutDetectionMode.quickStart,
        racketSportsOnly: false,
      );

      final restored = WorkoutDetectionPreferences.fromMap(original.toMap());

      expect(restored.mode, WorkoutDetectionMode.quickStart);
      expect(restored.racketSportsOnly, isFalse);
      expect(restored.onlyWhenWorn, isFalse);
      expect(original.toMap()['schemaVersion'], 1);
    });

    test('malformed provider values fail closed', () {
      final restored = WorkoutDetectionPreferences.fromMap({
        'mode': 3,
        'racketSportsOnly': 'yes',
        'onlyWhenWorn': 1,
      });

      expect(restored.mode, WorkoutDetectionMode.off);
      expect(restored.racketSportsOnly, isTrue);
      expect(restored.onlyWhenWorn, isFalse);
    });
  });
}
