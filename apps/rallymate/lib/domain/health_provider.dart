library;

enum HealthProviderSupportStatus {
  notSupported('NOT_SUPPORTED'),
  research('RESEARCH'),
  experimental('EXPERIMENTAL'),
  internal('INTERNAL'),
  beta('BETA'),
  production('PRODUCTION'),
  indirect('INDIRECT');

  const HealthProviderSupportStatus(this.wireValue);
  final String wireValue;

  bool get canHavePublicArtwork =>
      const {experimental, internal, beta, production, indirect}.contains(this);

  static HealthProviderSupportStatus fromWire(String value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => HealthProviderSupportStatus.notSupported,
      );
}

enum HealthProviderCategory {
  systemHub('SYSTEM_HUB'),
  cloudProvider('CLOUD_PROVIDER'),
  indirectSource('INDIRECT_SOURCE'),
  liveSensor('LIVE_SENSOR'),
  scoringWearable('SCORING_WEARABLE');

  const HealthProviderCategory(this.wireValue);
  final String wireValue;

  static HealthProviderCategory fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => HealthProviderCategory.indirectSource,
  );
}

enum HealthConnectionType {
  healthKit('HEALTH_KIT'),
  healthConnect('HEALTH_CONNECT'),
  cloudOAuth('CLOUD_OAUTH'),
  bluetoothHeartRate('BLUETOOTH_HEART_RATE'),
  nativeCompanion('NATIVE_COMPANION');

  const HealthConnectionType(this.wireValue);
  final String wireValue;

  static HealthConnectionType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => HealthConnectionType.healthConnect,
  );
}

enum HealthMetricType {
  workout('WORKOUT'),
  heartRate('HEART_RATE'),
  activeEnergy('ACTIVE_ENERGY'),
  totalEnergy('TOTAL_ENERGY'),
  steps('STEPS'),
  exerciseMinutes('EXERCISE_MINUTES'),
  distance('DISTANCE'),
  hrv('HRV'),
  sleep('SLEEP'),
  sleepScore('SLEEP_SCORE'),
  readiness('READINESS'),
  recovery('RECOVERY'),
  strain('STRAIN'),
  restingHeartRate('RESTING_HEART_RATE');

  const HealthMetricType(this.wireValue);
  final String wireValue;

  static HealthMetricType? tryFromWire(String value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

/// How a workout/session is owned relative to Momentum.
///
/// Distinguishes app-started sessions from external, imported and multi-source
/// recordings so scoring, watch and phone health never confuse them.
enum WorkoutSessionOwnership {
  /// Session started and owned by Momentum (phone/watch companion).
  appOwned('APP_OWNED'),

  /// External session detected; Momentum observes without taking ownership.
  externalPassive('EXTERNAL_PASSIVE'),

  /// Aggregates imported later from HealthKit / Health Connect.
  imported('IMPORTED'),

  /// Concurrent contributions from multiple providers after dedup.
  multiSource('MULTI_SOURCE'),

  /// No health session linked.
  none('NONE');

  const WorkoutSessionOwnership(this.wireValue);
  final String wireValue;

  static WorkoutSessionOwnership fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => WorkoutSessionOwnership.none,
  );
}

/// Match-level health link quality stored in [MatchHealthSummaries.dataQuality].
abstract final class MatchHealthDataQuality {
  static const high = 'HIGH';
  static const medium = 'MEDIUM';
  static const mediumConfirmed = 'MEDIUM_CONFIRMED';
  static const windowMetricsOnly = 'MEDIUM_WINDOW';
  static const pendingConfirm = 'PENDING_CONFIRM';
  static const cleared = 'CLEARED';
  static const unknown = 'UNKNOWN';

  static bool isPendingConfirm(String quality) => quality == pendingConfirm;
  static bool isLinked(String quality) =>
      quality == high ||
      quality == medium ||
      quality == mediumConfirmed ||
      quality == windowMetricsOnly;
}

enum HealthRolloutState {
  disabled('disabled'),
  internal('internal'),
  beta('beta'),
  production('production');

  const HealthRolloutState(this.wireValue);
  final String wireValue;

  bool get enabled => this != disabled;

  static HealthRolloutState fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value.toLowerCase(),
    orElse: () => HealthRolloutState.disabled,
  );
}

class HealthProviderCapabilities {
  const HealthProviderCapabilities({
    required this.metrics,
    this.supportsWorkoutImport = false,
    this.supportsHeartRate = false,
    this.supportsLiveHeartRate = false,
    this.supportsSleep = false,
    this.supportsHrv = false,
    this.supportsRecovery = false,
    this.supportsReadiness = false,
    this.supportsWebhooks = false,
    this.supportsBackgroundSync = false,
    this.supportsHistoricalImport = false,
    this.supportsScoringApp = false,
    this.supportsGuidedPairing = false,
    this.supportsDirectPairing = false,
    this.supportsHealthHubImport = false,
    this.supportsCloudOAuth = false,
  });

  final Set<HealthMetricType> metrics;
  final bool supportsWorkoutImport;
  final bool supportsHeartRate;
  final bool supportsLiveHeartRate;
  final bool supportsSleep;
  final bool supportsHrv;
  final bool supportsRecovery;
  final bool supportsReadiness;
  final bool supportsWebhooks;
  final bool supportsBackgroundSync;
  final bool supportsHistoricalImport;
  final bool supportsScoringApp;
  final bool supportsGuidedPairing;
  final bool supportsDirectPairing;
  final bool supportsHealthHubImport;
  final bool supportsCloudOAuth;

  factory HealthProviderCapabilities.fromJson(Map<String, Object?> json) {
    final metrics = ((json['metrics'] as List?) ?? const [])
        .map((item) => HealthMetricType.tryFromWire(item.toString()))
        .nonNulls
        .toSet();
    bool flag(String key) => json[key] == true;
    return HealthProviderCapabilities(
      metrics: metrics,
      supportsWorkoutImport: flag('supportsWorkoutImport'),
      supportsHeartRate: flag('supportsHeartRate'),
      supportsLiveHeartRate: flag('supportsLiveHeartRate'),
      supportsSleep: flag('supportsSleep'),
      supportsHrv: flag('supportsHrv'),
      supportsRecovery: flag('supportsRecovery'),
      supportsReadiness: flag('supportsReadiness'),
      supportsWebhooks: flag('supportsWebhooks'),
      supportsBackgroundSync: flag('supportsBackgroundSync'),
      supportsHistoricalImport: flag('supportsHistoricalImport'),
      supportsScoringApp: flag('supportsScoringApp'),
      supportsGuidedPairing: flag('supportsGuidedPairing'),
      supportsDirectPairing: flag('supportsDirectPairing'),
      supportsHealthHubImport: flag('supportsHealthHubImport'),
      supportsCloudOAuth: flag('supportsCloudOAuth'),
    );
  }
}

class HealthProviderDescriptor {
  const HealthProviderDescriptor({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.connectionType,
    required this.support,
    required this.rollout,
    required this.phonePlatforms,
    required this.capabilities,
    required this.sourceUrl,
    required this.artworkAsset,
    required this.limitations,
    required this.requiresPremium,
    required this.featureFlag,
  });

  final String id;
  final String displayName;
  final String description;
  final HealthProviderCategory category;
  final HealthConnectionType connectionType;
  final HealthProviderSupportStatus support;
  final HealthRolloutState rollout;
  final Set<String> phonePlatforms;
  final HealthProviderCapabilities capabilities;
  final Uri sourceUrl;
  final String artworkAsset;
  final List<String> limitations;
  final bool requiresPremium;
  final String featureFlag;

  bool supportsPhone(String platform) => phonePlatforms.contains(platform);
  bool get isEnabled => rollout.enabled;
  bool get isPublic =>
      rollout == HealthRolloutState.beta ||
      rollout == HealthRolloutState.production;
  bool get isHealthOnly => !capabilities.supportsScoringApp;

  HealthProviderDescriptor copyWith({HealthRolloutState? rollout}) =>
      HealthProviderDescriptor(
        id: id,
        displayName: displayName,
        description: description,
        category: category,
        connectionType: connectionType,
        support: support,
        rollout: rollout ?? this.rollout,
        phonePlatforms: phonePlatforms,
        capabilities: capabilities,
        sourceUrl: sourceUrl,
        artworkAsset: artworkAsset,
        limitations: limitations,
        requiresPremium: requiresPremium,
        featureFlag: featureFlag,
      );

  factory HealthProviderDescriptor.fromJson(Map<String, Object?> json) {
    final rawUrl = json['sourceUrl']?.toString() ?? '';
    final sourceUrl = Uri.tryParse(rawUrl);
    if (sourceUrl == null || !sourceUrl.isScheme('https')) {
      throw FormatException('Invalid official source URL for ${json['id']}');
    }
    return HealthProviderDescriptor(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      description: json['description']! as String,
      category: HealthProviderCategory.fromWire(json['category']! as String),
      connectionType: HealthConnectionType.fromWire(
        json['connectionType']! as String,
      ),
      support: HealthProviderSupportStatus.fromWire(json['support']! as String),
      rollout: HealthRolloutState.fromWire(json['rollout']! as String),
      phonePlatforms: ((json['phonePlatforms'] as List?) ?? const [])
          .map((item) => item.toString())
          .toSet(),
      capabilities: HealthProviderCapabilities.fromJson(
        (json['capabilities'] as Map).cast<String, Object?>(),
      ),
      sourceUrl: sourceUrl,
      artworkAsset: json['artworkAsset']?.toString() ?? '',
      limitations: ((json['limitations'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      requiresPremium: json['requiresPremium'] == true,
      featureFlag: json['featureFlag']?.toString() ?? '',
    );
  }
}

class HealthProviderConnectionStatus {
  const HealthProviderConnectionStatus({
    required this.providerId,
    required this.state,
    required this.authorizedMetrics,
    this.lastSyncAt,
    this.errorCode,
  });

  final String providerId;
  final String state;
  final Set<HealthMetricType> authorizedMetrics;
  final DateTime? lastSyncAt;
  final String? errorCode;

  bool get connected => state == 'CONNECTED';

  bool get available => state == 'AVAILABLE' || connected;
}

class HealthSyncResult {
  const HealthSyncResult({
    required this.providerId,
    required this.recordsImported,
    required this.recordsDeduplicated,
    required this.startedAt,
    required this.completedAt,
  });

  final String providerId;
  final int recordsImported;
  final int recordsDeduplicated;
  final DateTime startedAt;
  final DateTime completedAt;
}

abstract interface class HealthDataProvider {
  String get providerId;
  HealthProviderCapabilities get capabilities;

  Future<HealthProviderConnectionStatus> connect();
  Future<void> disconnect();
  Future<HealthProviderConnectionStatus> refreshAuthorization();
  Future<HealthProviderConnectionStatus> getConnectionStatus();
  Future<HealthSyncResult> syncRecentData();
  Future<HealthSyncResult> syncDateRange(DateTime start, DateTime end);
  Future<Set<HealthMetricType>> getAvailableMetrics();
  Future<List<Object>> getSourceMetadata();
  Future<void> deleteImportedData();
}
