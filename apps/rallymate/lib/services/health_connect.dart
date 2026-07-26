/// Health bridge multipiattaforma, gated to Pro+ in the UI/entitlements layer.
///
/// Stesso canale e wire format su entrambe le piattaforme:
///  - Android → Google Health Connect (HealthConnectBridge.kt)
///  - iOS     → Apple Salute / HealthKit (HealthKitBridge.swift)
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthConnectStatus {
  const HealthConnectStatus({
    required this.available,
    required this.granted,
    required this.availability,
    this.partial = false,
    this.providerPackage,
  });

  final bool available;
  final bool granted;
  /// At least one core metric granted, but not the full core set.
  final bool partial;
  final String availability;
  final String? providerPackage;

  /// True when any useful health read is possible (full or partial grants).
  bool get canRead => granted || partial;

  factory HealthConnectStatus.unavailable([
    String availability = 'unsupported',
  ]) {
    return HealthConnectStatus(
      available: false,
      granted: false,
      partial: false,
      availability: availability,
    );
  }

  factory HealthConnectStatus.fromMap(Map<Object?, Object?> map) {
    return HealthConnectStatus(
      available: map['available'] as bool? ?? false,
      granted: map['granted'] as bool? ?? false,
      partial: map['partial'] as bool? ?? false,
      availability: map['availability'] as String? ?? 'unknown',
      providerPackage: map['providerPackage'] as String?,
    );
  }

  String get label {
    if (granted) return 'Permessi attivi';
    if (partial) return 'Permessi parziali';
    return switch (availability) {
      'available' => 'Disponibile',
      'updateRequired' => 'Aggiornamento richiesto',
      'unavailable' => 'Non disponibile',
      _ => 'Non supportato',
    };
  }
}

class HealthConnectSummary {
  const HealthConnectSummary({
    required this.start,
    required this.end,
    required this.steps,
    required this.activeCaloriesKcal,
    required this.averageHeartRateBpm,
    required this.exerciseMinutes,
    required this.heartRateVariabilityMs,
    required this.heartRateVariabilityMethod,
    required this.sleepMinutes,
    required this.sources,
  });

  final DateTime start;
  final DateTime end;
  final int steps;
  final double activeCaloriesKcal;
  final double? averageHeartRateBpm;
  final int exerciseMinutes;
  final double? heartRateVariabilityMs;
  final String heartRateVariabilityMethod;
  final int sleepMinutes;
  final List<HealthSourceMetadata> sources;

  factory HealthConnectSummary.fromMap(Map<Object?, Object?> map) {
    return HealthConnectSummary(
      start: DateTime.fromMillisecondsSinceEpoch(map['startMs'] as int? ?? 0),
      end: DateTime.fromMillisecondsSinceEpoch(map['endMs'] as int? ?? 0),
      steps: map['steps'] as int? ?? 0,
      activeCaloriesKcal: (map['activeCaloriesKcal'] as num?)?.toDouble() ?? 0,
      averageHeartRateBpm: (map['averageHeartRateBpm'] as num?)?.toDouble(),
      exerciseMinutes: map['exerciseMinutes'] as int? ?? 0,
      heartRateVariabilityMs: (map['heartRateVariabilityMs'] as num?)
          ?.toDouble(),
      heartRateVariabilityMethod:
          map['heartRateVariabilityMethod']?.toString().toUpperCase() ??
          (HealthConnectService.isApple ? 'SDNN' : 'RMSSD'),
      sleepMinutes: map['sleepMinutes'] as int? ?? 0,
      sources: ((map['sources'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => HealthSourceMetadata.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }

  String get heartRateVariabilityUnit =>
      heartRateVariabilityMethod == 'SDNN' ? 'ms_sdnn' : 'ms_rmssd';
}

class HealthSourceMetadata {
  const HealthSourceMetadata({
    required this.provider,
    required this.sourceApplication,
    required this.sourceBundleId,
    required this.sourceDevice,
    required this.sourceModel,
    required this.metrics,
  });

  final String provider;
  final String sourceApplication;
  final String sourceBundleId;
  final String sourceDevice;
  final String sourceModel;
  final Set<String> metrics;

  factory HealthSourceMetadata.fromMap(Map<String, Object?> map) {
    final application = map['sourceApplication']?.toString() ?? '';
    final bundleId = map['sourceBundleId']?.toString() ?? '';
    return HealthSourceMetadata(
      provider:
          map['provider']?.toString() ??
          inferProvider(application: application, bundleId: bundleId),
      sourceApplication: application,
      sourceBundleId: bundleId,
      sourceDevice: map['sourceDevice']?.toString() ?? '',
      sourceModel: map['sourceModel']?.toString() ?? '',
      metrics: ((map['metrics'] as List?) ?? const [])
          .map((item) => item.toString())
          .toSet(),
    );
  }

  static String inferProvider({
    required String application,
    required String bundleId,
  }) {
    final fingerprint = '$application $bundleId'.toLowerCase();
    if (fingerprint.contains('oura')) return 'OURA_HEALTH_HUB';
    if (fingerprint.contains('ringconn')) return 'RINGCONN_HEALTH_HUB';
    if (fingerprint.contains('ultrahuman')) {
      return 'ULTRAHUMAN_HEALTH_HUB';
    }
    if (fingerprint.contains('zepp') || fingerprint.contains('amazfit')) {
      return 'ZEPP_HEALTH_HUB';
    }
    return HealthConnectService.isApple ? 'APPLE_HEALTH' : 'HEALTH_CONNECT';
  }
}

/// Finestra della giornata corrente nel fuso orario locale del dispositivo.
///
/// Non usare `now - 24h`: dopo mezzanotte includerebbe dati del giorno
/// precedente e, nei cambi di ora legale, non rappresenterebbe comunque una
/// giornata civile.
class HealthDayWindow {
  const HealthDayWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory HealthDayWindow.current([DateTime? clock]) {
    final end = (clock ?? DateTime.now()).toLocal();
    return HealthDayWindow(
      start: DateTime(end.year, end.month, end.day),
      end: end,
    );
  }
}

class HealthConnectService {
  HealthConnectService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.rallymate/health_connect');

  final MethodChannel _channel;

  /// The native side can lose a pending result (Health Connect permission
  /// sheet surviving an activity recreation, provider process death), and the
  /// platform future would then never complete and hang the caller.
  static const _channelTimeout = Duration(seconds: 20);

  static bool get supportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True su iOS (provider = Apple Salute invece di Google Health Connect).
  static bool get isApple => !kIsWeb && Platform.isIOS;

  /// Nome del provider salute per la UI.
  static String get providerName =>
      isApple ? 'Apple Salute' : 'Google Health Connect';

  Future<HealthConnectStatus> status() async {
    if (!supportedPlatform) {
      return HealthConnectStatus.unavailable('unsupported');
    }
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('status')
          .timeout(_channelTimeout);
      if (map == null) return HealthConnectStatus.unavailable();
      return HealthConnectStatus.fromMap(map);
    } on MissingPluginException {
      return HealthConnectStatus.unavailable();
    } on PlatformException {
      return HealthConnectStatus.unavailable();
    } on TimeoutException {
      return HealthConnectStatus.unavailable();
    }
  }

  Future<HealthConnectStatus> requestPermissions() async {
    if (!supportedPlatform) {
      return HealthConnectStatus.unavailable('unsupported');
    }
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('requestPermissions')
          // The user may take a while in the system sheet; be generous, but
          // never wait forever for a result that may never arrive.
          .timeout(const Duration(minutes: 3));
      if (map == null) return HealthConnectStatus.unavailable();
      return HealthConnectStatus.fromMap(map);
    } on MissingPluginException {
      return HealthConnectStatus.unavailable();
    } on PlatformException {
      return HealthConnectStatus.unavailable();
    } on TimeoutException {
      return HealthConnectStatus.unavailable();
    }
  }

  Future<HealthConnectSummary?> readSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!supportedPlatform) return null;
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('readSummary', {
            'startMs': start.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
          })
          .timeout(_channelTimeout);
      if (map == null) return null;
      return HealthConnectSummary.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<HealthConnectSummary?> readToday({DateTime? clock}) {
    final window = HealthDayWindow.current(clock);
    return readSummary(start: window.start, end: window.end);
  }
}

final healthConnectServiceProvider = Provider<HealthConnectService>(
  (_) => HealthConnectService(),
);

final healthConnectStatusProvider = FutureProvider<HealthConnectStatus>((ref) {
  return ref.watch(healthConnectServiceProvider).status();
});

final healthTodayProvider = FutureProvider.autoDispose<HealthConnectSummary?>((
  ref,
) async {
  final status = await ref.watch(healthConnectStatusProvider.future);
  if (!status.canRead) return null;
  return ref.watch(healthConnectServiceProvider).readToday();
});
