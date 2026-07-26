library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../data/repositories/health_repository.dart';
import 'health_connect.dart';

class BleHeartRateStatus {
  const BleHeartRateStatus({
    required this.supported,
    required this.bluetoothEnabled,
    required this.permissionsGranted,
    required this.connected,
    this.identifier,
    this.name,
  });

  final bool supported;
  final bool bluetoothEnabled;
  final bool permissionsGranted;
  final bool connected;
  final String? identifier;
  final String? name;

  factory BleHeartRateStatus.fromMap(Map<Object?, Object?>? value) {
    final map = value ?? const {};
    return BleHeartRateStatus(
      supported: map['supported'] == true,
      bluetoothEnabled: map['bluetoothEnabled'] == true,
      permissionsGranted: map['permissionsGranted'] == true,
      connected: map['connected'] == true,
      identifier: map['identifier']?.toString(),
      name: map['name']?.toString(),
    );
  }
}

class BleHeartRateDevice {
  const BleHeartRateDevice({
    required this.identifier,
    required this.name,
    required this.signal,
  });

  final String identifier;
  final String name;
  final int signal;

  factory BleHeartRateDevice.fromMap(Map<Object?, Object?> value) {
    final rawName =
        (value['name'] ?? value['localName'])?.toString().trim() ?? '';
    final safeName = rawName
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final rawSignal = value['signal'] ?? value['rssi'];
    final parsedSignal = rawSignal is num
        ? rawSignal.toInt()
        : int.tryParse(rawSignal?.toString() ?? '') ?? -127;
    return BleHeartRateDevice(
      identifier: (value['identifier'] ?? value['id'])?.toString().trim() ?? '',
      name: safeName.isEmpty
          ? 'Sensore cardiaco'
          : safeName.length <= 80
          ? safeName
          : safeName.substring(0, 80),
      signal: parsedSignal.clamp(-127, 20),
    );
  }
}

class BleHeartRateMeasurement {
  const BleHeartRateMeasurement({required this.bpm, required this.timestamp});

  final int bpm;
  final DateTime timestamp;
}

class BleHeartRateException implements Exception {
  const BleHeartRateException(this.code);
  final String code;

  String get userMessage => switch (code) {
    'permissions_required' =>
      'Consenti l’accesso Bluetooth per cercare il sensore.',
    'permissions_denied_settings' =>
      'Bluetooth negato in modo permanente. Apri Impostazioni e abilita '
          'Bluetooth (e Posizione su Android 11 e precedenti per lo scan BLE).',
    'bluetooth_off' => 'Attiva Bluetooth e riprova.',
    'scan_busy' => 'La ricerca è già in corso.',
    'scan_failed' =>
      'Ricerca non riuscita. Attiva il sensore e riprova la scansione.',
    'device_missing' =>
      'Il sensore non è più raggiungibile. Avvicinalo e riprova.',
    'sensor_incompatible' =>
      'Il dispositivo non espone il profilo cardiaco Bluetooth standard.',
    'connect_timeout' =>
      'Connessione scaduta. Avvicina o riattiva il sensore e riprova.',
    'connect_busy' => 'È già in corso un collegamento al sensore.',
    'connect_failed' => 'Collegamento interrotto. Avvicina il sensore e riprova.',
    'connect_cancelled' => 'Collegamento annullato.',
    'permission_busy' => 'Richiesta permessi già in corso. Attendi un istante.',
    _ => 'Il sensore non è disponibile in questo momento.',
  };

  /// Permanent deny / settings recovery path.
  bool get needsSettings =>
      code == 'permissions_denied_settings' || code == 'permissions_required';

  @override
  String toString() => userMessage;
}

class BleHeartRateService {
  BleHeartRateService(this.repository) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const _channel = MethodChannel('com.rallymate/ble_heart_rate');
  final HealthDataRepository repository;
  final _heartRate = StreamController<BleHeartRateMeasurement>.broadcast();
  final _status = StreamController<BleHeartRateStatus>.broadcast();

  Stream<BleHeartRateMeasurement> get measurements => _heartRate.stream;
  Stream<BleHeartRateStatus> get statusChanges => _status.stream;

  Future<BleHeartRateStatus> currentStatus() async {
    late final BleHeartRateStatus status;
    try {
      status = BleHeartRateStatus.fromMap(
        await _channel.invokeMapMethod<Object?, Object?>('status'),
      );
    } on MissingPluginException {
      status = const BleHeartRateStatus(
        supported: false,
        bluetoothEnabled: false,
        permissionsGranted: false,
        connected: false,
      );
    } on PlatformException {
      // Native Bluetooth stack error: report as supported but not ready.
      status = const BleHeartRateStatus(
        supported: true,
        bluetoothEnabled: false,
        permissionsGranted: false,
        connected: false,
      );
    }
    // A GATT connection belongs to the current native process. A sensor row
    // remembered from a previous launch is historical metadata, not evidence
    // that the radio link is still alive.
    if (!status.connected) await repository.markAllBleDisconnected();
    return status;
  }

  Future<BleHeartRateStatus> requestPermissions() async =>
      BleHeartRateStatus.fromMap(await _invokeMap('requestPermissions'));

  /// Opens system app settings for permanent Bluetooth denial recovery.
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BleHeartRateDevice>> scan() async {
    try {
      final values = await _channel.invokeListMethod<Object?>('scan');
      final devicesByIdentifier = <String, BleHeartRateDevice>{};
      for (final value in values ?? const <Object?>[]) {
        if (value is! Map) continue;
        final device = BleHeartRateDevice.fromMap(
          Map<Object?, Object?>.from(value),
        );
        if (device.identifier.isEmpty) continue;

        final previous = devicesByIdentifier[device.identifier];
        if (previous == null || device.signal > previous.signal) {
          devicesByIdentifier[device.identifier] = device;
        }
      }
      return devicesByIdentifier.values.toList(growable: false)
        ..sort((a, b) => b.signal.compareTo(a.signal));
    } on PlatformException catch (error) {
      throw BleHeartRateException(error.code);
    }
  }

  Future<void> connect(BleHeartRateDevice device) async {
    try {
      await _channel.invokeMethod<bool>('connect', {
        'identifier': device.identifier,
      });
      final sensorId = await repository.saveBleSensor(
        localIdentifier: device.identifier,
        displayName: device.name,
        manufacturer: '',
        connected: true,
      );
      await repository.upsertSource(
        HealthSourceMetadata(
          provider: 'BLE_HEART_RATE',
          sourceApplication: device.name,
          sourceBundleId: 'bluetooth.sig.hrs.$sensorId',
          sourceDevice: '',
          sourceModel: device.name,
          metrics: const {'HEART_RATE'},
        ),
        supportsLiveData: true,
      );
    } on PlatformException catch (error) {
      throw BleHeartRateException(error.code);
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<bool>('disconnect');
    } on MissingPluginException {
      // Desktop/tests have no native BLE runtime.
    }
    await repository.markAllBleDisconnected();
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'heartRate' && call.arguments is Map) {
      final map = call.arguments as Map;
      final bpm = (map['bpm'] as num?)?.toInt();
      final timestampMs = (map['timestampMs'] as num?)?.toInt();
      if (bpm != null && bpm >= 20 && bpm <= 300 && timestampMs != null) {
        _heartRate.add(
          BleHeartRateMeasurement(
            bpm: bpm,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
          ),
        );
      }
    } else if (call.method == 'connectionChanged' && call.arguments is Map) {
      final state = BleHeartRateStatus.fromMap(
        (call.arguments as Map).cast<Object?, Object?>(),
      );
      _status.add(state);
      if (!state.connected) await repository.markAllBleDisconnected();
    }
    return null;
  }

  Future<Map<Object?, Object?>?> _invokeMap(String method) async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(method);
    } on PlatformException catch (error) {
      throw BleHeartRateException(error.code);
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _heartRate.close();
    _status.close();
  }
}
