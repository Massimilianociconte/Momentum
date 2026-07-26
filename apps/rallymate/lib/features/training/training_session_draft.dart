/// Local draft for interrupted guided training sessions.
///
/// Battery / privacy: JSON only in local KV — no cloud, no background timer.
library;

import 'dart:convert';

import '../../data/repositories/repositories.dart';

const trainingDraftKvKey = 'training_session_draft_v1';

class TrainingSessionDraft {
  const TrainingSessionDraft({
    required this.trainingId,
    required this.drillIndex,
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.savedAtMs,
  });

  final String trainingId;
  final int drillIndex;
  final int remainingSeconds;
  final int elapsedSeconds;
  final int savedAtMs;

  Map<String, Object?> toJson() => {
        'trainingId': trainingId,
        'drillIndex': drillIndex,
        'remainingSeconds': remainingSeconds,
        'elapsedSeconds': elapsedSeconds,
        'savedAtMs': savedAtMs,
      };

  static TrainingSessionDraft? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, Object?>();
      final id = map['trainingId'] as String?;
      if (id == null || id.isEmpty) return null;
      return TrainingSessionDraft(
        trainingId: id,
        drillIndex: (map['drillIndex'] as num?)?.toInt() ?? 0,
        remainingSeconds: (map['remainingSeconds'] as num?)?.toInt() ?? 0,
        elapsedSeconds: (map['elapsedSeconds'] as num?)?.toInt() ?? 0,
        savedAtMs: (map['savedAtMs'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Discard drafts older than 7 days (stale / battery-friendly cleanup).
  bool get isFresh {
    if (savedAtMs <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch - savedAtMs;
    return age >= 0 && age < const Duration(days: 7).inMilliseconds;
  }
}

Future<TrainingSessionDraft?> loadTrainingDraft(
  KeyValueRepository kv,
) async {
  final draft = TrainingSessionDraft.tryParse(await kv.get(trainingDraftKvKey));
  if (draft == null) return null;
  if (!draft.isFresh) {
    await kv.set(trainingDraftKvKey, '');
    return null;
  }
  return draft;
}

Future<void> saveTrainingDraft(
  KeyValueRepository kv,
  TrainingSessionDraft draft,
) =>
    kv.set(trainingDraftKvKey, jsonEncode(draft.toJson()));

Future<void> clearTrainingDraft(KeyValueRepository kv) =>
    kv.set(trainingDraftKvKey, '');
