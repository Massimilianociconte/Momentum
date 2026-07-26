library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchFamily {
  const WatchFamily({
    required this.id,
    required this.manufacturer,
    required this.family,
    required this.phonePlatforms,
    required this.watchOs,
    required this.minimumVersion,
    required this.support,
    required this.models,
    required this.companionApp,
    required this.features,
    required this.limitations,
    required this.source,
    required this.provider,
    required this.connectionMode,
    required this.requiresPlan,
    required this.screenless,
    required this.artworkAsset,
  });

  final String id;
  final String manufacturer;
  final String family;
  final List<String> phonePlatforms;
  final String watchOs;
  final String minimumVersion;
  final String support;
  final List<String> models;
  final String companionApp;
  final List<String> features;
  final List<String> limitations;
  final String source;
  final String provider;
  final String connectionMode;
  final String requiresPlan;
  final bool screenless;
  final String artworkAsset;

  bool supportsPhone(String platform) => phonePlatforms.contains(platform);
  bool get isSupported =>
      support == 'FULL' || support == 'CONDITIONAL' || support == 'HEALTH_ONLY';
  bool get canScore => features.contains('scoring');
  bool get isHealthOnly => support == 'HEALTH_ONLY';
  bool get isRetired => support == 'RETIRED';

  factory WatchFamily.fromJson(Map<String, Object?> json) => WatchFamily(
    id: json['id']! as String,
    manufacturer: json['manufacturer']! as String,
    family: json['family']! as String,
    phonePlatforms: _strings(json['phonePlatforms']),
    watchOs: json['watchOs']! as String,
    minimumVersion: json['minimumVersion']! as String,
    support: json['support']! as String,
    models: _strings(json['models']),
    companionApp: json['companionApp']! as String,
    features: _strings(json['features']),
    limitations: _strings(json['limitations']),
    source: json['source']! as String,
    provider: (json['provider'] as String?) ?? 'PLATFORM_NATIVE',
    connectionMode: (json['connectionMode'] as String?) ?? 'native',
    requiresPlan: (json['requiresPlan'] as String?) ?? 'free',
    screenless: (json['screenless'] as bool?) ?? false,
    artworkAsset: (json['artworkAsset'] as String?) ?? '',
  );

  static List<String> _strings(Object? value) =>
      ((value as List?) ?? const []).map((item) => item.toString()).toList();
}

class WatchCompatibilityCatalog {
  const WatchCompatibilityCatalog({
    required this.updatedAt,
    required this.families,
  });

  final DateTime updatedAt;
  final List<WatchFamily> families;

  String get phonePlatform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'unsupported',
  };

  List<WatchFamily> forCurrentPhone() => families
      .where((family) => family.supportsPhone(phonePlatform))
      .toList(growable: false);

  static Future<WatchCompatibilityCatalog> load() async {
    final raw = await rootBundle.loadString(
      'assets/config/watch_compatibility.json',
    );
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    final families = ((json['families'] as List?) ?? const [])
        .map(
          (item) => WatchFamily.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(growable: false);
    return WatchCompatibilityCatalog(
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      families: families,
    );
  }
}

final watchCompatibilityProvider = FutureProvider(
  (_) => WatchCompatibilityCatalog.load(),
);
