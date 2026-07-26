import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/data/repositories/health_repository.dart';
import 'package:rallymate/domain/health_provider.dart';
import 'package:rallymate/services/health_connect.dart';
import 'package:rallymate/services/health_deduplication.dart';

void main() {
  late AppDatabase db;
  late HealthDataRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = HealthDataRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue and complete match association job', () async {
    await repository.enqueueMatchAssociationJob(
      matchId: 'match-42',
      provider: 'HEALTH_CONNECT',
      dateFromMs: 1,
      dateToMs: 2,
      lastErrorCode: 'no_health_data',
    );

    final due = await repository.dueAssociationJobs();
    expect(due, hasLength(1));
    expect(due.single.id, 'assoc_match-42');
    expect(
      HealthDataRepository.matchIdFromAssociationJob(due.single.id),
      'match-42',
    );

    await repository.completeAssociationJob('match-42');
    final after = await repository.dueAssociationJobs();
    expect(after, isEmpty);

    final row = await (db.select(
      db.healthSyncJobs,
    )..where((t) => t.id.equals('assoc_match-42'))).getSingle();
    expect(row.status, 'COMPLETED');
  });

  test('failAssociationJob applies exponential backoff', () async {
    await repository.enqueueMatchAssociationJob(
      matchId: 'm1',
      provider: 'APPLE_HEALTH',
    );
    await repository.failAssociationJob(
      matchId: 'm1',
      errorCode: 'health_unauthorized',
    );

    final row = await (db.select(
      db.healthSyncJobs,
    )..where((t) => t.id.equals('assoc_m1'))).getSingle();
    expect(row.status, 'FAILED');
    expect(row.retryCount, 1);
    expect(row.lastErrorCode, 'health_unauthorized');
    expect(row.nextRetryAtMs, isNotNull);
    // Not due yet (5 min backoff).
    expect(await repository.dueAssociationJobs(), isEmpty);
  });

  test('queryDeduplicatedMetrics keeps preferred RallyMate over hub mirror', () async {
    final now = DateTime(2026, 7, 21, 12);
    final start = now.subtract(const Duration(hours: 1));
    final end = now;

    final rallySource = await repository.upsertSource(
      const HealthSourceMetadata(
        provider: 'RALLYMATE',
        sourceApplication: 'RallyMate',
        sourceBundleId: 'com.rallymate.rallymate',
        sourceDevice: '',
        sourceModel: '',
        metrics: {'WORKOUT'},
      ),
    );
    final hubSource = await repository.upsertSource(
      const HealthSourceMetadata(
        provider: 'HEALTH_CONNECT',
        sourceApplication: 'Health Connect',
        sourceBundleId: 'com.google.android.apps.healthdata',
        sourceDevice: '',
        sourceModel: '',
        metrics: {'WORKOUT'},
      ),
    );

    final ts = start.millisecondsSinceEpoch;
    final te = end.millisecondsSinceEpoch;
    final created = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.healthMetricRecords)
        .insert(
          HealthMetricRecordsCompanion.insert(
            id: 'm_rm',
            provider: 'RALLYMATE',
            sourceId: rallySource.id,
            metricType: HealthMetricType.workout.wireValue,
            startTimeMs: ts,
            endTimeMs: te,
            value: 60,
            unit: 'min',
            contentHash: 'h1',
            createdAtMs: created,
            updatedAtMs: created,
          ),
        );
    await db
        .into(db.healthMetricRecords)
        .insert(
          HealthMetricRecordsCompanion.insert(
            id: 'm_hub',
            provider: 'HEALTH_CONNECT',
            sourceId: hubSource.id,
            metricType: HealthMetricType.workout.wireValue,
            startTimeMs: ts,
            endTimeMs: te,
            value: 60,
            unit: 'min',
            contentHash: 'h2',
            createdAtMs: created,
            updatedAtMs: created,
          ),
        );

    // Policy unit-level sanity: RallyMate wins.
    const policy = HealthDeduplicationPolicy();
    final dedup = policy.deduplicate([
      HealthRecordCandidate(
        id: 'm_rm',
        provider: 'RALLYMATE',
        sourceId: rallySource.id,
        metric: HealthMetricType.workout,
        start: start,
        end: end,
        value: 60,
        unit: 'min',
      ),
      HealthRecordCandidate(
        id: 'm_hub',
        provider: 'HEALTH_CONNECT',
        sourceId: hubSource.id,
        metric: HealthMetricType.workout,
        start: start,
        end: end,
        value: 60,
        unit: 'min',
      ),
    ]);
    expect(dedup.records, hasLength(1));
    expect(dedup.records.single.id, 'm_rm');

    final rows = await repository.queryDeduplicatedMetrics(
      start: start.subtract(const Duration(minutes: 1)),
      end: end.add(const Duration(minutes: 1)),
      metric: HealthMetricType.workout,
    );
    expect(rows, hasLength(1));
    expect(rows.single.id, 'm_rm');
    expect(rows.single.provider, 'RALLYMATE');
  });

  test('setMatchHealthQuality clears biometrics on reject', () async {
    // Need a match row for FK.
    await db
        .into(db.matches)
        .insert(
          MatchesCompanion.insert(
            id: 'match-x',
            formatJson: '{}',
          ),
        );
    await repository.upsertMatchHealthSummary(
      matchId: 'match-x',
      averageHeartRate: 140,
      activeEnergyKcal: 300,
      steps: 4000,
      dataQuality: MatchHealthDataQuality.pendingConfirm,
    );

    await repository.setMatchHealthQuality(
      matchId: 'match-x',
      dataQuality: MatchHealthDataQuality.cleared,
      clearBiometrics: true,
    );

    final summary = await repository.summaryForMatch('match-x');
    expect(summary, isNotNull);
    expect(summary!.dataQuality, MatchHealthDataQuality.cleared);
    expect(summary.averageHeartRate, isNull);
    expect(summary.steps, isNull);
    expect(summary.activeEnergyKcal, isNull);
  });
}
