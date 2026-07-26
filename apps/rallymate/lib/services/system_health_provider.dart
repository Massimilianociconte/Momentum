library;

import '../data/repositories/health_repository.dart';
import '../domain/health_provider.dart';
import 'health_connect.dart';

class SystemHealthDataProvider implements HealthDataProvider {
  SystemHealthDataProvider(this.bridge, this.repository);

  final HealthConnectService bridge;
  final HealthDataRepository repository;

  @override
  String get providerId =>
      HealthConnectService.isApple ? 'APPLE_HEALTH' : 'HEALTH_CONNECT';

  @override
  HealthProviderCapabilities get capabilities => HealthProviderCapabilities(
    metrics: const {
      HealthMetricType.workout,
      HealthMetricType.heartRate,
      HealthMetricType.activeEnergy,
      HealthMetricType.steps,
      HealthMetricType.exerciseMinutes,
      HealthMetricType.hrv,
      HealthMetricType.sleep,
    },
    supportsWorkoutImport: true,
    supportsHeartRate: true,
    supportsSleep: true,
    supportsHrv: true,
    supportsHistoricalImport: true,
    supportsGuidedPairing: true,
    supportsHealthHubImport: true,
  );

  @override
  Future<HealthProviderConnectionStatus> connect() async {
    final status = await bridge.requestPermissions();
    return _status(status);
  }

  @override
  Future<void> disconnect() => repository.deleteProviderData(providerId);

  @override
  Future<void> deleteImportedData() =>
      repository.deleteProviderData(providerId);

  @override
  Future<Set<HealthMetricType>> getAvailableMetrics() async {
    final summary = await bridge.readToday();
    if (summary == null) return const {};
    return {
      if (summary.steps > 0) HealthMetricType.steps,
      if (summary.activeCaloriesKcal > 0) HealthMetricType.activeEnergy,
      if (summary.averageHeartRateBpm != null) HealthMetricType.heartRate,
      if (summary.exerciseMinutes > 0) HealthMetricType.exerciseMinutes,
      if (summary.heartRateVariabilityMs != null) HealthMetricType.hrv,
      if (summary.sleepMinutes > 0) HealthMetricType.sleep,
    };
  }

  @override
  Future<HealthProviderConnectionStatus> getConnectionStatus() async =>
      _status(await bridge.status());

  @override
  Future<List<Object>> getSourceMetadata() async {
    final summary = await bridge.readToday();
    return summary?.sources.cast<Object>() ?? const [];
  }

  @override
  Future<HealthProviderConnectionStatus> refreshAuthorization() =>
      getConnectionStatus();

  @override
  Future<HealthSyncResult> syncDateRange(DateTime start, DateTime end) async {
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 7)) {
      throw ArgumentError.value(
        end.difference(start),
        'range',
        'Health import range must be between 0 and 7 days',
      );
    }
    final startedAt = DateTime.now();
    final summary = await bridge.readSummary(start: start, end: end);
    if (summary == null) {
      return HealthSyncResult(
        providerId: providerId,
        recordsImported: 0,
        recordsDeduplicated: 0,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
    }
    final result = await repository.persistSummary(
      hubProvider: providerId,
      summary: summary,
    );
    return HealthSyncResult(
      providerId: providerId,
      recordsImported: result.inserted,
      recordsDeduplicated: result.deduplicated,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<HealthSyncResult> syncRecentData() {
    final window = HealthDayWindow.current();
    return syncDateRange(window.start, window.end);
  }

  HealthProviderConnectionStatus _status(HealthConnectStatus status) {
    // Partial grants (canRead) still allow first sync / association.
    final connected = status.granted || status.canRead || status.partial;
    return HealthProviderConnectionStatus(
      providerId: providerId,
      state: connected
          ? 'CONNECTED'
          : status.available
          ? 'AVAILABLE'
          : 'UNAVAILABLE',
      authorizedMetrics: connected ? capabilities.metrics : const {},
    );
  }
}
