library;

import '../domain/health_provider.dart';

class HealthRecordCandidate {
  const HealthRecordCandidate({
    required this.id,
    required this.provider,
    required this.sourceId,
    required this.metric,
    required this.start,
    required this.end,
    required this.value,
    required this.unit,
    this.externalRecordId,
  });

  final String id;
  final String provider;
  final String sourceId;
  final HealthMetricType metric;
  final DateTime start;
  final DateTime end;
  final double value;
  final String unit;
  final String? externalRecordId;
}

class HealthDeduplicationResult {
  const HealthDeduplicationResult({
    required this.records,
    required this.duplicateIds,
  });

  final List<HealthRecordCandidate> records;
  final Set<String> duplicateIds;
}

/// Deterministic, provider-aware deduplication for mirrored health records.
/// It never adds values from two overlapping copies of the same session.
class HealthDeduplicationPolicy {
  const HealthDeduplicationPolicy({this.preferredSourceByMetric = const {}});

  final Map<HealthMetricType, String> preferredSourceByMetric;

  HealthDeduplicationResult deduplicate(Iterable<HealthRecordCandidate> input) {
    final sorted = input.toList()
      ..sort((a, b) {
        final metricOrder = a.metric.index.compareTo(b.metric.index);
        if (metricOrder != 0) return metricOrder;
        final timeOrder = a.start.compareTo(b.start);
        if (timeOrder != 0) return timeOrder;
        return _rank(b).compareTo(_rank(a));
      });
    final kept = <HealthRecordCandidate>[];
    final duplicates = <String>{};
    for (final candidate in sorted) {
      final matchIndex = kept.indexWhere(
        (existing) => _sameMeasurement(existing, candidate),
      );
      if (matchIndex < 0) {
        kept.add(candidate);
        continue;
      }
      final existing = kept[matchIndex];
      if (_rank(candidate) > _rank(existing)) {
        duplicates.add(existing.id);
        kept[matchIndex] = candidate;
      } else {
        duplicates.add(candidate.id);
      }
    }
    return HealthDeduplicationResult(
      records: List.unmodifiable(kept),
      duplicateIds: Set.unmodifiable(duplicates),
    );
  }

  bool _sameMeasurement(HealthRecordCandidate a, HealthRecordCandidate b) {
    if (a.metric != b.metric || a.unit != b.unit) return false;
    if (a.externalRecordId != null &&
        b.externalRecordId != null &&
        a.provider == b.provider) {
      return a.externalRecordId == b.externalRecordId;
    }
    final overlap = _overlapRatio(a.start, a.end, b.start, b.end);
    if (overlap < 0.9) return false;
    final scale = a.value.abs().clamp(1.0, double.infinity);
    return (a.value - b.value).abs() / scale <= 0.01;
  }

  int _rank(HealthRecordCandidate candidate) {
    if (preferredSourceByMetric[candidate.metric] == candidate.sourceId) {
      return 100;
    }
    return switch (candidate.metric) {
      HealthMetricType.workout => candidate.provider == 'RALLYMATE' ? 90 : 50,
      HealthMetricType.readiness =>
        candidate.provider == 'OURA_DIRECT' ? 90 : 40,
      HealthMetricType.recovery ||
      HealthMetricType.strain => candidate.provider == 'WHOOP_DIRECT' ? 90 : 40,
      _ =>
        candidate.provider == 'APPLE_HEALTH' ||
                candidate.provider == 'HEALTH_CONNECT'
            ? 70
            : 60,
    };
  }

  double _overlapRatio(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final latestStart = aStart.isAfter(bStart) ? aStart : bStart;
    final earliestEnd = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    if (!earliestEnd.isAfter(latestStart)) return 0;
    final overlap = earliestEnd.difference(latestStart).inMilliseconds;
    final shortest = [
      aEnd.difference(aStart).inMilliseconds,
      bEnd.difference(bStart).inMilliseconds,
    ].reduce((a, b) => a < b ? a : b);
    return shortest <= 0 ? 0 : overlap / shortest;
  }
}
