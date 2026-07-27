library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_sync.dart';

enum WorkoutDetectionMode {
  off,
  ask,
  quickStart;

  String get wire => switch (this) {
    off => 'OFF',
    ask => 'ASK',
    quickStart => 'QUICK_START',
  };

  static WorkoutDetectionMode fromWire(String? value) => switch (value) {
    'ASK' => ask,
    'QUICK_START' => quickStart,
    _ => off,
  };
}

class WorkoutDetectionPreferences {
  const WorkoutDetectionPreferences({
    this.mode = WorkoutDetectionMode.off,
    this.racketSportsOnly = true,
    this.onlyWhenWorn = false,
  });

  final WorkoutDetectionMode mode;
  final bool racketSportsOnly;

  /// Kept in the cross-platform contract, but disabled until a provider
  /// exposes a documented, reliable worn-state signal to third-party apps.
  final bool onlyWhenWorn;

  bool get enabled => mode != WorkoutDetectionMode.off;

  WorkoutDetectionPreferences copyWith({
    WorkoutDetectionMode? mode,
    bool? racketSportsOnly,
    bool? onlyWhenWorn,
  }) => WorkoutDetectionPreferences(
    mode: mode ?? this.mode,
    racketSportsOnly: racketSportsOnly ?? this.racketSportsOnly,
    onlyWhenWorn: onlyWhenWorn ?? this.onlyWhenWorn,
  );

  Map<String, Object?> toMap() => {
    'mode': mode.wire,
    'racketSportsOnly': racketSportsOnly,
    'onlyWhenWorn': onlyWhenWorn,
    'schemaVersion': 1,
  };

  factory WorkoutDetectionPreferences.fromMap(Map<String, Object?> value) =>
      WorkoutDetectionPreferences(
        mode: WorkoutDetectionMode.fromWire(
          value['mode'] is String ? value['mode']! as String : null,
        ),
        racketSportsOnly: value['racketSportsOnly'] is bool
            ? value['racketSportsOnly']! as bool
            : true,
        // Never silently enable an unsupported sensor-derived condition.
        onlyWhenWorn: value['onlyWhenWorn'] is bool
            ? value['onlyWhenWorn']! as bool
            : false,
      );
}

class WorkoutDetectionPreferencesController
    extends Notifier<WorkoutDetectionPreferences> {
  static const _modeKey = 'workout_detection_mode';
  static const _racketOnlyKey = 'workout_detection_racket_only';
  static const _wornOnlyKey = 'workout_detection_worn_only';
  int _revision = 0;

  @override
  WorkoutDetectionPreferences build() {
    unawaited(_load());
    return const WorkoutDetectionPreferences();
  }

  Future<void> setMode(WorkoutDetectionMode mode) async {
    await _commit(state.copyWith(mode: mode));
  }

  Future<void> setRacketSportsOnly(bool enabled) async {
    await _commit(state.copyWith(racketSportsOnly: enabled));
  }

  Future<void> _load() async {
    final revisionAtStart = _revision;
    final storage = await SharedPreferences.getInstance();
    if (revisionAtStart != _revision) return;
    state = WorkoutDetectionPreferences(
      mode: WorkoutDetectionMode.fromWire(storage.getString(_modeKey)),
      racketSportsOnly: storage.getBool(_racketOnlyKey) ?? true,
      onlyWhenWorn: storage.getBool(_wornOnlyKey) ?? false,
    );
    await _sendToWearable();
  }

  Future<void> _commit(WorkoutDetectionPreferences next) async {
    _revision += 1;
    state = next;
    final storage = await SharedPreferences.getInstance();
    await Future.wait([
      storage.setString(_modeKey, next.mode.wire),
      storage.setBool(_racketOnlyKey, next.racketSportsOnly),
      storage.setBool(_wornOnlyKey, next.onlyWhenWorn),
    ]);
    await _sendToWearable();
  }

  Future<void> _sendToWearable() async {
    await ref
        .read(watchSyncProvider.notifier)
        .updateWorkoutDetectionPreferences(state.toMap());
  }
}

final workoutDetectionPreferencesProvider =
    NotifierProvider<
      WorkoutDetectionPreferencesController,
      WorkoutDetectionPreferences
    >(WorkoutDetectionPreferencesController.new);
