library;

import '../data/repositories/health_repository.dart';
import '../domain/health_provider.dart';
import 'ble_heart_rate.dart';
import 'health_connect.dart';

/// Unified provider adapter for user-initiated Bluetooth SIG heart-rate
/// sensors. Pairing remains explicit because choosing a peripheral cannot be
/// represented safely by a generic connect() call.
class BleHeartRateDataProvider implements HealthDataProvider {
  BleHeartRateDataProvider(this.service, this.repository);

  final BleHeartRateService service;
  final HealthDataRepository repository;

  @override
  String get providerId => 'BLE_HEART_RATE';

  @override
  HealthProviderCapabilities get capabilities =>
      const HealthProviderCapabilities(
        metrics: {HealthMetricType.heartRate},
        supportsHeartRate: true,
        supportsLiveHeartRate: true,
        supportsGuidedPairing: true,
        supportsDirectPairing: true,
      );

  @override
  Future<HealthProviderConnectionStatus> connect() async =>
      _status(await service.requestPermissions());

  @override
  Future<void> disconnect() => service.disconnect();

  @override
  Future<void> deleteImportedData() async {
    await service.disconnect();
    await repository.forgetBleSensors();
  }

  @override
  Future<Set<HealthMetricType>> getAvailableMetrics() async {
    final status = await service.currentStatus();
    return status.supported ? capabilities.metrics : const {};
  }

  @override
  Future<HealthProviderConnectionStatus> getConnectionStatus() async =>
      _status(await service.currentStatus());

  @override
  Future<List<Object>> getSourceMetadata() async {
    final status = await service.currentStatus();
    if (!status.connected) return const [];
    return <Object>[
      HealthSourceMetadata(
        provider: providerId,
        sourceApplication: status.name ?? 'Sensore cardiaco Bluetooth',
        sourceBundleId: 'bluetooth.sig.hrs',
        sourceDevice: '',
        sourceModel: status.name ?? '',
        metrics: const {'HEART_RATE'},
      ),
    ];
  }

  @override
  Future<HealthProviderConnectionStatus> refreshAuthorization() =>
      getConnectionStatus();

  @override
  Future<HealthSyncResult> syncDateRange(DateTime start, DateTime end) async {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'Must be after start');
    }
    final now = DateTime.now();
    return HealthSyncResult(
      providerId: providerId,
      recordsImported: 0,
      recordsDeduplicated: 0,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<HealthSyncResult> syncRecentData() {
    final end = DateTime.now();
    return syncDateRange(end.subtract(const Duration(minutes: 1)), end);
  }

  HealthProviderConnectionStatus _status(BleHeartRateStatus status) =>
      HealthProviderConnectionStatus(
        providerId: providerId,
        state: status.connected
            ? 'CONNECTED'
            : status.supported
            ? 'AVAILABLE'
            : 'UNAVAILABLE',
        authorizedMetrics: status.permissionsGranted
            ? capabilities.metrics
            : const {},
        errorCode: !status.bluetoothEnabled && status.supported
            ? 'bluetooth_off'
            : null,
      );
}
