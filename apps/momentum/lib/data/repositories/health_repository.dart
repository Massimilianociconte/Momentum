library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../domain/health_provider.dart';
import '../../services/health_connect.dart';
import '../../services/health_deduplication.dart';
import '../db/database.dart';

class HealthPersistResult {
  const HealthPersistResult({
    required this.inserted,
    required this.deduplicated,
    required this.sourceIds,
  });

  final int inserted;
  final int deduplicated;
  final Set<String> sourceIds;
}

class HealthDataRepository {
  HealthDataRepository(this.db);
  final AppDatabase db;

  Stream<List<HealthDataSource>> watchSources() =>
      (db.select(db.healthDataSources)..orderBy([
            (row) => OrderingTerm.desc(row.isPreferred),
            (row) => OrderingTerm.desc(row.updatedAtMs),
          ]))
          .watch();

  Future<List<HealthDataSource>> sources() =>
      (db.select(db.healthDataSources)..orderBy([
            (row) => OrderingTerm.desc(row.isPreferred),
            (row) => OrderingTerm.desc(row.updatedAtMs),
          ]))
          .get();

  Future<HealthDataSource> upsertSource(
    HealthSourceMetadata source, {
    bool supportsLiveData = false,
    String? connectionId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _sourceId(source);
    final existing = await (db.select(
      db.healthDataSources,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    await db
        .into(db.healthDataSources)
        .insertOnConflictUpdate(
          HealthDataSourcesCompanion.insert(
            id: id,
            provider: source.provider,
            sourceApplication: Value(source.sourceApplication),
            sourceBundleId: Value(source.sourceBundleId),
            sourceDevice: Value(source.sourceDevice),
            sourceModel: Value(source.sourceModel),
            connectionId: Value(connectionId),
            isPreferred: Value(existing?.isPreferred ?? false),
            supportsLiveData: Value(supportsLiveData),
            availableMetricsJson: Value(
              jsonEncode(source.metrics.toList()..sort()),
            ),
            detectedAtMs: existing?.detectedAtMs ?? now,
            updatedAtMs: now,
          ),
        );
    return (db.select(
      db.healthDataSources,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<HealthPersistResult> persistSummary({
    required String hubProvider,
    required HealthConnectSummary summary,
  }) async {
    final sourceIds = <String>{};
    for (final source in summary.sources) {
      sourceIds.add((await upsertSource(source)).id);
    }
    final aggregateSource = await upsertSource(
      HealthSourceMetadata(
        provider: hubProvider,
        sourceApplication: hubProvider == 'APPLE_HEALTH'
            ? 'Apple Salute (aggregato)'
            : 'Health Connect (aggregato)',
        sourceBundleId: 'rallymate.aggregate.${hubProvider.toLowerCase()}',
        sourceDevice: '',
        sourceModel: '',
        metrics: const {
          'STEPS',
          'ACTIVE_ENERGY',
          'HEART_RATE',
          'EXERCISE_MINUTES',
          'HRV',
          'SLEEP',
        },
      ),
    );
    sourceIds.add(aggregateSource.id);

    final records = <({HealthMetricType type, double value, String unit})>[
      if (summary.steps > 0)
        (
          type: HealthMetricType.steps,
          value: summary.steps.toDouble(),
          unit: 'count',
        ),
      if (summary.activeCaloriesKcal > 0)
        (
          type: HealthMetricType.activeEnergy,
          value: summary.activeCaloriesKcal,
          unit: 'kcal',
        ),
      if (summary.averageHeartRateBpm case final value?)
        (type: HealthMetricType.heartRate, value: value, unit: 'bpm'),
      if (summary.exerciseMinutes > 0)
        (
          type: HealthMetricType.exerciseMinutes,
          value: summary.exerciseMinutes.toDouble(),
          unit: 'min',
        ),
      if (summary.heartRateVariabilityMs case final value?)
        (
          type: HealthMetricType.hrv,
          value: value,
          unit: summary.heartRateVariabilityUnit,
        ),
      if (summary.sleepMinutes > 0)
        (
          type: HealthMetricType.sleep,
          value: summary.sleepMinutes.toDouble(),
          unit: 'min',
        ),
    ];

    var inserted = 0;
    var deduplicated = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final record in records) {
        final hash = _recordHash(
          provider: hubProvider,
          sourceId: aggregateSource.id,
          metric: record.type.wireValue,
          startMs: summary.start.millisecondsSinceEpoch,
          unit: record.unit,
        );
        final id = 'metric_${hash.substring(0, 32)}';
        final existing =
            await (db.select(db.healthMetricRecords)
                  ..where(
                    (row) =>
                        row.ownerId.equals('local') &
                        row.provider.equals(hubProvider) &
                        row.sourceId.equals(aggregateSource.id) &
                        row.metricType.equals(record.type.wireValue) &
                        row.startTimeMs.equals(
                          summary.start.millisecondsSinceEpoch,
                        ) &
                        row.unit.equals(record.unit),
                  )
                  ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMs)]))
                .get();
        if (existing.isNotEmpty) {
          deduplicated++;
          var canonical = existing.first;
          for (final candidate in existing) {
            if (candidate.contentHash == hash) {
              canonical = candidate;
              break;
            }
          }
          final duplicateIds = existing
              .where((row) => row.id != canonical.id)
              .map((row) => row.id)
              .toList(growable: false);
          if (duplicateIds.isNotEmpty) {
            await (db.delete(
              db.healthMetricRecords,
            )..where((row) => row.id.isIn(duplicateIds))).go();
          }
          await (db.update(
            db.healthMetricRecords,
          )..where((row) => row.id.equals(canonical.id))).write(
            HealthMetricRecordsCompanion(
              value: Value(record.value),
              endTimeMs: Value(summary.end.millisecondsSinceEpoch),
              contentHash: Value(hash),
              updatedAtMs: Value(now),
            ),
          );
          continue;
        }
        await db
            .into(db.healthMetricRecords)
            .insert(
              HealthMetricRecordsCompanion.insert(
                id: id,
                provider: hubProvider,
                sourceId: aggregateSource.id,
                metricType: record.type.wireValue,
                startTimeMs: summary.start.millisecondsSinceEpoch,
                endTimeMs: summary.end.millisecondsSinceEpoch,
                value: record.value,
                unit: record.unit,
                contentHash: hash,
                createdAtMs: now,
                updatedAtMs: now,
              ),
            );
        inserted++;
      }
    });
    return HealthPersistResult(
      inserted: inserted,
      deduplicated: deduplicated,
      sourceIds: sourceIds,
    );
  }

  Future<void> setPreferredSource({
    required HealthMetricType metric,
    required String sourceId,
  }) async {
    final source = await (db.select(
      db.healthDataSources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    if (source == null) throw StateError('health_source_not_found');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db
          .into(db.healthSourcePreferences)
          .insertOnConflictUpdate(
            HealthSourcePreferencesCompanion.insert(
              metricType: metric.wireValue,
              sourceId: sourceId,
              updatedAtMs: now,
            ),
          );
      await (db.update(db.healthDataSources)
            ..where((row) => row.id.equals(sourceId)))
          .write(const HealthDataSourcesCompanion(isPreferred: Value(true)));
    });
  }

  Future<Map<String, String>> preferredSources() async {
    final rows = await db.select(db.healthSourcePreferences).get();
    return {for (final row in rows) row.metricType: row.sourceId};
  }

  Future<void> deleteProviderData(String provider) async {
    final sourceIds =
        await (db.selectOnly(db.healthDataSources)
              ..addColumns([db.healthDataSources.id])
              ..where(db.healthDataSources.provider.equals(provider)))
            .map((row) => row.read(db.healthDataSources.id))
            .get();
    final ids = sourceIds.nonNulls.toList(growable: false);
    await db.transaction(() async {
      if (ids.isNotEmpty) {
        await (db.delete(
          db.healthSourcePreferences,
        )..where((row) => row.sourceId.isIn(ids))).go();
        await (db.delete(
          db.healthMetricRecords,
        )..where((row) => row.sourceId.isIn(ids))).go();
        // Purge biometric columns, not only the foreign key. Leaving avg HR /
        // steps / energy after "delete health data" would violate the user's
        // revoke/delete intent (store privacy + in-app delete semantics).
        await (db.update(
          db.matchHealthSummaries,
        )..where((row) => row.primarySourceId.isIn(ids))).write(
          const MatchHealthSummariesCompanion(
            primarySourceId: Value(null),
            averageHeartRate: Value(null),
            maxHeartRate: Value(null),
            minHeartRate: Value(null),
            activeEnergyKcal: Value(null),
            totalEnergyKcal: Value(null),
            steps: Value(null),
            distanceMeters: Value(null),
            highIntensityMinutes: Value(null),
            recoveryDelta: Value(null),
            sleepScore: Value(null),
            readinessScore: Value(null),
            recoveryScore: Value(null),
            strainScore: Value(null),
            dataQuality: Value('CLEARED'),
            synced: Value(false),
          ),
        );
        await (db.delete(
          db.healthDataSources,
        )..where((row) => row.id.isIn(ids))).go();
      }
      await (db.delete(
        db.healthSyncJobs,
      )..where((row) => row.provider.equals(provider))).go();
    });
  }

  Future<String> saveBleSensor({
    required String localIdentifier,
    required String displayName,
    required String manufacturer,
    required bool connected,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final identifierHash = _hash(localIdentifier);
    final id = 'ble_${identifierHash.substring(0, 32)}';
    final existing = await (db.select(
      db.bleSensorDevices,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    await db
        .into(db.bleSensorDevices)
        .insertOnConflictUpdate(
          BleSensorDevicesCompanion.insert(
            id: id,
            // The native bridge needs the OS identifier only for the active
            // connection. Persist a one-way fingerprint, never a BLE MAC.
            localIdentifier: identifierHash,
            displayName: Value(displayName),
            manufacturer: Value(manufacturer),
            capabilitiesJson: const Value('["HEART_RATE"]'),
            lastSeenAtMs: Value(now),
            isPreferred: Value(existing?.isPreferred ?? false),
            isConnected: Value(connected),
            createdAtMs: existing?.createdAtMs ?? now,
            updatedAtMs: now,
          ),
        );
    return id;
  }

  Future<void> markAllBleDisconnected() => db
      .update(db.bleSensorDevices)
      .write(
        BleSensorDevicesCompanion(
          isConnected: const Value(false),
          updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> forgetBleSensors() async {
    await db.delete(db.bleSensorDevices).go();
    await deleteProviderData('BLE_HEART_RATE');
  }

  /// Upsert the privacy-minimized health snapshot linked to a completed match.
  Future<String> upsertMatchHealthSummary({
    required String matchId,
    String? primarySourceId,
    int? durationSeconds,
    double? averageHeartRate,
    double? activeEnergyKcal,
    int? steps,
    String dataQuality = 'MEDIUM',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (db.select(db.matchHealthSummaries)
              ..where((row) => row.matchId.equals(matchId))
              ..orderBy([(row) => OrderingTerm.desc(row.calculatedAtMs)])
              ..limit(1))
            .getSingleOrNull();
    final id = existing?.id ?? 'mhs_${matchId.hashCode.abs()}_$now';
    await db
        .into(db.matchHealthSummaries)
        .insertOnConflictUpdate(
          MatchHealthSummariesCompanion.insert(
            id: id,
            matchId: matchId,
            primarySourceId: Value(primarySourceId),
            durationSeconds: Value(durationSeconds),
            averageHeartRate: Value(averageHeartRate),
            activeEnergyKcal: Value(activeEnergyKcal),
            steps: Value(steps),
            dataQuality: Value(dataQuality),
            calculatedAtMs: now,
            synced: const Value(false),
          ),
        );
    return id;
  }

  Future<MatchHealthSummary?> summaryForMatch(String matchId) =>
      (db.select(db.matchHealthSummaries)
            ..where((row) => row.matchId.equals(matchId))
            ..orderBy([(row) => OrderingTerm.desc(row.calculatedAtMs)])
            ..limit(1))
          .getSingleOrNull();

  /// Update quality flag (user confirmed / rejected a pending link).
  Future<void> setMatchHealthQuality({
    required String matchId,
    required String dataQuality,
    bool clearBiometrics = false,
  }) async {
    final existing = await summaryForMatch(matchId);
    if (existing == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (clearBiometrics) {
      await (db.update(
        db.matchHealthSummaries,
      )..where((row) => row.id.equals(existing.id))).write(
        MatchHealthSummariesCompanion(
          primarySourceId: const Value(null),
          averageHeartRate: const Value(null),
          maxHeartRate: const Value(null),
          minHeartRate: const Value(null),
          activeEnergyKcal: const Value(null),
          totalEnergyKcal: const Value(null),
          steps: const Value(null),
          distanceMeters: const Value(null),
          highIntensityMinutes: const Value(null),
          recoveryDelta: const Value(null),
          sleepScore: const Value(null),
          readinessScore: const Value(null),
          recoveryScore: const Value(null),
          strainScore: const Value(null),
          dataQuality: Value(dataQuality),
          synced: const Value(false),
          calculatedAtMs: Value(now),
        ),
      );
      return;
    }
    await (db.update(
      db.matchHealthSummaries,
    )..where((row) => row.id.equals(existing.id))).write(
      MatchHealthSummariesCompanion(
        dataQuality: Value(dataQuality),
        synced: const Value(false),
        calculatedAtMs: Value(now),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline association jobs (schema health_sync_jobs)
  // ---------------------------------------------------------------------------

  static const matchAssociateSyncType = 'MATCH_ASSOCIATE';
  static const maxAssociationRetries = 8;

  /// Idempotent enqueue: one pending job per match (`assoc_<matchId>`).
  Future<void> enqueueMatchAssociationJob({
    required String matchId,
    required String provider,
    int? dateFromMs,
    int? dateToMs,
    String? lastErrorCode,
  }) async {
    final id = associationJobId(matchId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (db.select(
      db.healthSyncJobs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null && existing.status == 'COMPLETED') {
      // Allow re-queue after a later revoke/empty window by resetting.
    }
    await db
        .into(db.healthSyncJobs)
        .insertOnConflictUpdate(
          HealthSyncJobsCompanion.insert(
            id: id,
            provider: provider,
            syncType: matchAssociateSyncType,
            dateFromMs: Value(dateFromMs),
            dateToMs: Value(dateToMs),
            status: const Value('PENDING'),
            retryCount: Value(existing?.retryCount ?? 0),
            nextRetryAtMs: Value(now),
            lastErrorCode: Value(lastErrorCode),
            createdAtMs: existing?.createdAtMs ?? now,
            completedAtMs: const Value(null),
          ),
        );
  }

  static String associationJobId(String matchId) => 'assoc_$matchId';

  static String? matchIdFromAssociationJob(String jobId) {
    if (!jobId.startsWith('assoc_')) return null;
    return jobId.substring('assoc_'.length);
  }

  Future<List<HealthSyncJob>> dueAssociationJobs({int limit = 12}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows =
        await (db.select(db.healthSyncJobs)
              ..where(
                (row) =>
                    row.syncType.equals(matchAssociateSyncType) &
                    row.status.isIn(const ['PENDING', 'FAILED']) &
                    row.retryCount.isSmallerThanValue(maxAssociationRetries),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAtMs)])
              ..limit(limit * 2))
            .get();
    return rows
        .where((job) => job.nextRetryAtMs == null || job.nextRetryAtMs! <= now)
        .take(limit)
        .toList(growable: false);
  }

  Future<void> completeAssociationJob(String matchId) async {
    final id = associationJobId(matchId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(
      db.healthSyncJobs,
    )..where((row) => row.id.equals(id))).write(
      HealthSyncJobsCompanion(
        status: const Value('COMPLETED'),
        completedAtMs: Value(now),
        lastErrorCode: const Value(null),
        nextRetryAtMs: const Value(null),
      ),
    );
  }

  Future<void> failAssociationJob({
    required String matchId,
    required String errorCode,
    String provider = 'UNKNOWN',
  }) async {
    final id = associationJobId(matchId);
    var existing = await (db.select(
      db.healthSyncJobs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      await enqueueMatchAssociationJob(
        matchId: matchId,
        provider: provider,
        lastErrorCode: errorCode,
      );
      existing = await (db.select(
        db.healthSyncJobs,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
    }
    final retry = (existing?.retryCount ?? 0) + 1;
    final delayMinutes = (5 * (1 << (retry - 1).clamp(0, 6))).clamp(5, 360);
    final next =
        DateTime.now().millisecondsSinceEpoch + delayMinutes * 60 * 1000;
    final status = retry >= maxAssociationRetries ? 'DEAD' : 'FAILED';
    await (db.update(
      db.healthSyncJobs,
    )..where((row) => row.id.equals(id))).write(
      HealthSyncJobsCompanion(
        status: Value(status),
        retryCount: Value(retry),
        nextRetryAtMs: Value(next),
        lastErrorCode: Value(errorCode),
        completedAtMs: status == 'DEAD'
            ? Value(DateTime.now().millisecondsSinceEpoch)
            : const Value(null),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cross-source deduplicated reads (analytics / association helpers)
  // ---------------------------------------------------------------------------

  /// Loads metric rows in [start, end] and collapses multi-source mirrors via
  /// [HealthDeduplicationPolicy] (Momentum preferred, hub mirrors dropped).
  Future<List<HealthMetricRecord>> queryDeduplicatedMetrics({
    required DateTime start,
    required DateTime end,
    HealthMetricType? metric,
  }) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final query = db.select(db.healthMetricRecords)
      ..where(
        (row) =>
            row.startTimeMs.isBiggerOrEqualValue(startMs) &
            row.startTimeMs.isSmallerThanValue(endMs),
      );
    if (metric != null) {
      query.where((row) => row.metricType.equals(metric.wireValue));
    }
    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final preferred = await preferredSources();
    final preferredByMetric = <HealthMetricType, String>{
      for (final entry in preferred.entries)
        ?HealthMetricType.tryFromWire(entry.key): entry.value,
    };
    final policy = HealthDeduplicationPolicy(
      preferredSourceByMetric: preferredByMetric,
    );
    final candidates = <HealthRecordCandidate>[
      for (final row in rows)
        if (HealthMetricType.tryFromWire(row.metricType) case final type?)
          HealthRecordCandidate(
            id: row.id,
            provider: row.provider,
            sourceId: row.sourceId,
            metric: type,
            start: DateTime.fromMillisecondsSinceEpoch(row.startTimeMs),
            end: DateTime.fromMillisecondsSinceEpoch(row.endTimeMs),
            value: row.value,
            unit: row.unit,
            externalRecordId: row.externalRecordId,
          ),
    ];
    final result = policy.deduplicate(candidates);
    final keptIds = {for (final c in result.records) c.id};
    return rows
        .where((row) => keptIds.contains(row.id))
        .toList(growable: false);
  }

  String _sourceId(HealthSourceMetadata source) =>
      'source_${_hash([source.provider, source.sourceBundleId, source.sourceApplication, source.sourceDevice, source.sourceModel].join('|')).substring(0, 32)}';

  String _recordHash({
    required String provider,
    required String sourceId,
    required String metric,
    required int startMs,
    required String unit,
  }) => _hash('$provider|$sourceId|$metric|$startMs|$unit');

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}
