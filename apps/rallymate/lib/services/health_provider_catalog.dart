library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/health_provider.dart';

abstract final class HealthFeatureFlags {
  static const _oura = String.fromEnvironment(
    'RALLYMATE_HEALTH_OURA_DIRECT',
    defaultValue: '',
  );
  static const _whoop = String.fromEnvironment(
    'RALLYMATE_HEALTH_WHOOP_DIRECT',
    defaultValue: '',
  );
  static const _zepp = String.fromEnvironment(
    'RALLYMATE_HEALTH_ZEPP',
    defaultValue: '',
  );
  static const _ble = String.fromEnvironment(
    'RALLYMATE_HEALTH_BLE_HR',
    defaultValue: '',
  );
  static const _rings = String.fromEnvironment(
    'RALLYMATE_HEALTH_RING_SOURCES',
    defaultValue: '',
  );
  static const _multiSource = String.fromEnvironment(
    'RALLYMATE_HEALTH_MULTI_SOURCE',
    defaultValue: '',
  );

  static HealthRolloutState? overrideFor(String flag) {
    final value = switch (flag) {
      'health_oura_direct' => _oura,
      'health_whoop_direct' => _whoop,
      'health_zepp' => _zepp,
      'health_ble_hr' => _ble,
      'health_ring_sources' => _rings,
      'health_multi_source' => _multiSource,
      _ => '',
    };
    return value.isEmpty ? null : HealthRolloutState.fromWire(value);
  }
}

class HealthProviderCatalog {
  const HealthProviderCatalog({
    required this.updatedAt,
    required this.providers,
  });

  final DateTime updatedAt;
  final List<HealthProviderDescriptor> providers;

  String get phonePlatform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'unsupported',
  };

  List<HealthProviderDescriptor> forCurrentPhone({
    bool includeInternal = false,
  }) => providers
      .where((provider) {
        if (!provider.supportsPhone(phonePlatform) || !provider.isEnabled) {
          return false;
        }
        return includeInternal || provider.isPublic;
      })
      .toList(growable: false);

  HealthProviderDescriptor? byId(String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  static Future<HealthProviderCatalog> load() async {
    final raw = await rootBundle.loadString(
      'assets/config/health_provider_compatibility.json',
    );
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    final providers = ((json['providers'] as List?) ?? const [])
        .map(
          (item) => HealthProviderDescriptor.fromJson(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .map((provider) {
          final override = HealthFeatureFlags.overrideFor(provider.featureFlag);
          return override == null
              ? provider
              : provider.copyWith(rollout: override);
        })
        .toList(growable: false);
    return HealthProviderCatalog(
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      providers: providers,
    );
  }
}

final healthProviderCatalogProvider = FutureProvider(
  (_) => HealthProviderCatalog.load(),
);
