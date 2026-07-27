library;

import '../domain/health_provider.dart';
import 'wearable_provider_service.dart';

class CloudHealthDataProvider implements HealthDataProvider {
  CloudHealthDataProvider(this.descriptor, this.service);

  final HealthProviderDescriptor descriptor;
  final WearableProviderService service;

  @override
  String get providerId => descriptor.id;

  @override
  HealthProviderCapabilities get capabilities => descriptor.capabilities;

  @override
  Future<HealthProviderConnectionStatus> connect() async {
    await service.authorizeDirectHealth(providerId);
    return HealthProviderConnectionStatus(
      providerId: providerId,
      state: 'PENDING',
      authorizedMetrics: const {},
    );
  }

  @override
  Future<void> deleteImportedData() => service.disconnect(providerId);

  @override
  Future<void> disconnect() => service.disconnect(providerId);

  @override
  Future<Set<HealthMetricType>> getAvailableMetrics() async {
    final status = await service.directHealthStatus(providerId);
    return status.connected ? capabilities.metrics : const {};
  }

  @override
  Future<HealthProviderConnectionStatus> getConnectionStatus() async {
    final status = await service.directHealthStatus(providerId);
    return HealthProviderConnectionStatus(
      providerId: providerId,
      state: status.available ? status.status : 'UNAVAILABLE',
      authorizedMetrics: status.connected ? capabilities.metrics : const {},
      lastSyncAt: status.lastSyncAt,
      errorCode: status.needsReconnect ? 'reconnect_required' : null,
    );
  }

  @override
  Future<List<Object>> getSourceMetadata() async => const [];

  @override
  Future<HealthProviderConnectionStatus> refreshAuthorization() =>
      getConnectionStatus();

  @override
  Future<HealthSyncResult> syncDateRange(DateTime start, DateTime end) async {
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 31)) {
      throw ArgumentError.value(
        end.difference(start),
        'range',
        'Cloud health import range must be between 0 and 31 days',
      );
    }
    final startedAt = DateTime.now();
    final result = await service.syncDirectHealth(
      providerId,
      start: start,
      end: end,
    );
    return HealthSyncResult(
      providerId: providerId,
      recordsImported: result.imported,
      recordsDeduplicated: 0,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<HealthSyncResult> syncRecentData() {
    final end = DateTime.now();
    return syncDateRange(end.subtract(const Duration(days: 7)), end);
  }
}
