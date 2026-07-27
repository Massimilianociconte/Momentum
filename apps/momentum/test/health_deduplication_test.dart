import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/domain/health_provider.dart';
import 'package:rallymate/services/health_deduplication.dart';

void main() {
  HealthRecordCandidate record({
    required String id,
    required String provider,
    required String sourceId,
    HealthMetricType metric = HealthMetricType.workout,
    double value = 60,
  }) => HealthRecordCandidate(
    id: id,
    provider: provider,
    sourceId: sourceId,
    metric: metric,
    start: DateTime(2026, 7, 13, 18),
    end: DateTime(2026, 7, 13, 19),
    value: value,
    unit: metric == HealthMetricType.workout ? 'min' : 'score',
  );

  test('RallyMate workout wins over a mirrored health-hub copy', () {
    const policy = HealthDeduplicationPolicy();
    final result = policy.deduplicate([
      record(id: 'hub', provider: 'APPLE_HEALTH', sourceId: 'apple'),
      record(id: 'match', provider: 'RALLYMATE', sourceId: 'rallymate'),
    ]);

    expect(result.records.single.id, 'match');
    expect(result.duplicateIds, {'hub'});
  });

  test('explicit preferred source wins equivalent measurements', () {
    const policy = HealthDeduplicationPolicy(
      preferredSourceByMetric: {HealthMetricType.readiness: 'oura'},
    );
    final result = policy.deduplicate([
      record(
        id: 'generic',
        provider: 'APPLE_HEALTH',
        sourceId: 'apple',
        metric: HealthMetricType.readiness,
        value: 82,
      ),
      record(
        id: 'oura',
        provider: 'OURA_DIRECT',
        sourceId: 'oura',
        metric: HealthMetricType.readiness,
        value: 82,
      ),
    ]);

    expect(result.records.single.id, 'oura');
    expect(result.duplicateIds, {'generic'});
  });

  test('non-overlapping sessions remain separate', () {
    const policy = HealthDeduplicationPolicy();
    final first = record(
      id: 'first',
      provider: 'RALLYMATE',
      sourceId: 'rallymate',
    );
    final second = HealthRecordCandidate(
      id: 'second',
      provider: 'RALLYMATE',
      sourceId: 'rallymate',
      metric: HealthMetricType.workout,
      start: DateTime(2026, 7, 13, 20),
      end: DateTime(2026, 7, 13, 21),
      value: 60,
      unit: 'min',
    );
    final result = policy.deduplicate([first, second]);

    expect(result.records, hasLength(2));
    expect(result.duplicateIds, isEmpty);
  });
}
