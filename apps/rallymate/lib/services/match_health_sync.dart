/// Hybrid match ↔ health association.
///
/// Strategy:
/// 1. Match timeline is always local-first (source of truth).
/// 2. After completion, import OS aggregates for the match window.
/// 3. Associate only with real non-empty metrics and honest confidence.
/// 4. Dedup via content hash when re-importing.
/// 5. Retriable failures enqueue `health_sync_jobs` for offline reconciliation.
/// 6. Ambiguous temporal matches require explicit user confirmation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../data/repositories/health_repository.dart';
import '../domain/health_provider.dart';
import 'health_connect.dart';

class MatchHealthSyncResult {
  const MatchHealthSyncResult({
    required this.associated,
    required this.reason,
    this.summaryId,
    this.averageHeartRate,
    this.activeEnergyKcal,
    this.steps,
    this.ownership = WorkoutSessionOwnership.none,
    this.pendingConfirmation = false,
    this.queuedForRetry = false,
  });

  final bool associated;
  final String reason;
  final String? summaryId;
  final double? averageHeartRate;
  final double? activeEnergyKcal;
  final int? steps;
  final WorkoutSessionOwnership ownership;
  final bool pendingConfirmation;
  final bool queuedForRetry;
}

class MatchHealthSyncService {
  MatchHealthSyncService(this.ref);

  final Ref ref;

  static const _retriableReasons = {
    'health_unavailable',
    'health_unauthorized',
    'no_health_data',
    'empty_health_window',
  };

  /// Longest window whose OS aggregates may still be attributed to a match.
  ///
  /// A match paused in one session and resumed hours (or a day) later is a
  /// single RallyMate match but several separate stretches of play: summing
  /// steps and calories over the whole span would credit the match with a
  /// night's worth of activity. Beyond this bound the import is refused
  /// instead of writing an inflated number.
  static const _maxAttributableWindow = Duration(hours: 4);

  Future<MatchHealthSyncResult> associateCompletedMatch(String matchId) async {
    final result = await _associateOnce(matchId);
    if (result.associated || result.pendingConfirmation) {
      await ref.read(healthDataRepoProvider).completeAssociationJob(matchId);
      return result;
    }
    if (_retriableReasons.contains(result.reason)) {
      final hub = HealthConnectService.isApple
          ? 'APPLE_HEALTH'
          : 'HEALTH_CONNECT';
      final match = await ref.read(matchRepoProvider).byId(matchId);
      await ref
          .read(healthDataRepoProvider)
          .enqueueMatchAssociationJob(
            matchId: matchId,
            provider: hub,
            dateFromMs: match?.startTimeMs,
            dateToMs: match?.endTimeMs,
            lastErrorCode: result.reason,
          );
      await ref
          .read(healthDataRepoProvider)
          .failAssociationJob(matchId: matchId, errorCode: result.reason);
      return MatchHealthSyncResult(
        associated: false,
        reason: result.reason,
        queuedForRetry: true,
        ownership: WorkoutSessionOwnership.none,
      );
    }
    return result;
  }

  /// Drain due offline association jobs (foreground / resume).
  Future<int> processDueJobs({int limit = 8}) async {
    final repo = ref.read(healthDataRepoProvider);
    final jobs = await repo.dueAssociationJobs(limit: limit);
    var processed = 0;
    for (final job in jobs) {
      final matchId = HealthDataRepository.matchIdFromAssociationJob(job.id);
      if (matchId == null || matchId.isEmpty) {
        continue;
      }
      final result = await _associateOnce(matchId);
      processed++;
      if (result.associated || result.pendingConfirmation) {
        await repo.completeAssociationJob(matchId);
      } else if (_retriableReasons.contains(result.reason)) {
        await repo.failAssociationJob(
          matchId: matchId,
          errorCode: result.reason,
        );
      } else {
        // Permanent failure (match missing, insufficient confidence, etc.).
        await repo.completeAssociationJob(matchId);
      }
    }
    return processed;
  }

  Future<void> confirmPendingAssociation(String matchId) async {
    await ref
        .read(healthDataRepoProvider)
        .setMatchHealthQuality(
          matchId: matchId,
          dataQuality: MatchHealthDataQuality.mediumConfirmed,
        );
    await ref.read(healthDataRepoProvider).completeAssociationJob(matchId);
  }

  Future<void> rejectPendingAssociation(String matchId) async {
    await ref
        .read(healthDataRepoProvider)
        .setMatchHealthQuality(
          matchId: matchId,
          dataQuality: MatchHealthDataQuality.cleared,
          clearBiometrics: true,
        );
    await ref.read(healthDataRepoProvider).completeAssociationJob(matchId);
  }

  Future<MatchHealthSyncResult> _associateOnce(String matchId) async {
    final match = await ref.read(matchRepoProvider).byId(matchId);
    if (match == null) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'match_not_found',
      );
    }
    final startMs = match.startTimeMs;
    if (startMs == null) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'invalid_match_range',
      );
    }
    final endMs = match.endTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    if (endMs <= startMs) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'invalid_match_range',
      );
    }

    final bridge = ref.read(healthConnectServiceProvider);
    final status = await bridge.status();
    if (!status.available) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'health_unavailable',
      );
    }
    // Partial grants still allow reads of whatever the OS exposes.
    if (!status.canRead) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'health_unauthorized',
      );
    }

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    // Multi-session match (paused today, resumed tomorrow): the span is not a
    // play window, so its aggregates say nothing about this match. Refusing is
    // permanent — retrying cannot make the window shorter.
    if (end.difference(start) > _maxAttributableWindow) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'window_too_long',
      );
    }
    final windowStart = start.subtract(const Duration(minutes: 5));
    final windowEnd = end.add(const Duration(minutes: 5));

    final summary = await bridge.readSummary(
      start: windowStart,
      end: windowEnd,
    );
    if (summary == null) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'no_health_data',
      );
    }

    final hasSignal =
        summary.steps > 0 ||
        summary.activeCaloriesKcal > 0 ||
        summary.averageHeartRateBpm != null ||
        summary.exerciseMinutes > 0;
    if (!hasSignal) {
      return const MatchHealthSyncResult(
        associated: false,
        reason: 'empty_health_window',
      );
    }

    final hubProvider = HealthConnectService.isApple
        ? 'APPLE_HEALTH'
        : 'HEALTH_CONNECT';
    final persist = await ref
        .read(healthDataRepoProvider)
        .persistSummary(hubProvider: hubProvider, summary: summary);

    // Cross-source collapse for analytics consistency (side-effect free read).
    await ref
        .read(healthDataRepoProvider)
        .queryDeduplicatedMetrics(start: windowStart, end: windowEnd);

    // Do NOT fabricate workout candidates from aggregate source labels using
    // the match window as start/end — that forced false HIGH automatic links.
    // Without true exercise intervals, keep window metrics only (MEDIUM).
    final multiSource =
        summary.sources.map((s) => s.provider).toSet().length > 1;
    final preferredSource = summary.sources.any(
      (s) =>
          s.sourceBundleId.toLowerCase().contains('rallymate') ||
          s.sourceApplication.toLowerCase().contains('momentum') ||
          // Legacy display name kept for sessions written before the rebrand.
          s.sourceApplication.toLowerCase().contains('padelandia') ||
          s.sourceApplication.toLowerCase().contains('rallymate'),
    );

    final String dataQuality;
    final String reason;
    final WorkoutSessionOwnership ownership;
    final bool pendingConfirmation;
    final bool associated;

    // Window metrics only — user can confirm on match detail if needed.
    dataQuality = MatchHealthDataQuality.windowMetricsOnly;
    reason = 'window_metrics_only';
    ownership = preferredSource
        ? WorkoutSessionOwnership.appOwned
        : (multiSource
              ? WorkoutSessionOwnership.multiSource
              : WorkoutSessionOwnership.imported);
    pendingConfirmation = false;
    associated = true;

    final durationSeconds = end.difference(start).inSeconds;
    final summaryId = await ref
        .read(healthDataRepoProvider)
        .upsertMatchHealthSummary(
          matchId: matchId,
          primarySourceId: persist.sourceIds.isEmpty
              ? null
              : persist.sourceIds.first,
          durationSeconds: durationSeconds,
          averageHeartRate: summary.averageHeartRateBpm,
          activeEnergyKcal: summary.activeCaloriesKcal > 0
              ? summary.activeCaloriesKcal
              : null,
          steps: summary.steps > 0 ? summary.steps : null,
          dataQuality: dataQuality,
        );

    return MatchHealthSyncResult(
      associated: associated,
      reason: reason,
      summaryId: summaryId,
      averageHeartRate: summary.averageHeartRateBpm,
      activeEnergyKcal: summary.activeCaloriesKcal > 0
          ? summary.activeCaloriesKcal
          : null,
      steps: summary.steps > 0 ? summary.steps : null,
      ownership: ownership,
      pendingConfirmation: pendingConfirmation,
    );
  }
}

final matchHealthSyncProvider = Provider(
  (ref) => MatchHealthSyncService(ref),
);
