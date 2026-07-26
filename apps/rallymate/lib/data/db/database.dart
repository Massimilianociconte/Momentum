/// Local-first Drift database (PRD 5.1: la versione gratuita funziona
/// quasi interamente in locale).
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local players (me + recurring partners). No cloud account needed.
class Players extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nickname => text().withDefault(const Constant(''))();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  TextColumn get dominantHand => text().withDefault(const Constant('RIGHT'))();
  TextColumn get preferredRole =>
      text().withDefault(const Constant('UNDEFINED'))();
  TextColumn get level => text().withDefault(const Constant('INTERMEDIATE'))();
  TextColumn get goal => text().withDefault(const Constant(''))();
  TextColumn get clubs => text().withDefault(const Constant(''))();
  TextColumn get bio => text().withDefault(const Constant(''))();
  TextColumn get homeArea => text().withDefault(const Constant(''))();
  TextColumn get preferredSide =>
      text().withDefault(const Constant('UNDEFINED'))();
  TextColumn get preferredTime => text().withDefault(const Constant(''))();
  TextColumn get playFrequency => text().withDefault(const Constant(''))();
  TextColumn get privacy => text().withDefault(const Constant('PRIVATE'))();

  /// Processed square portrait inside app support. Free accounts keep this
  /// device-local; paid cloud backup can mirror it to private Storage.
  TextColumn get avatarLocalPath => text().nullable()();
  TextColumn get avatarCloudPath => text().nullable()();
  IntColumn get avatarVersion => integer().withDefault(const Constant(0))();
  IntColumn get avatarCloudVersion =>
      integer().withDefault(const Constant(0))();

  /// Disponibilità matchmaking: TODAY | EVENING | WEEKEND | FLEX | HIDDEN.
  TextColumn get availability => text().withDefault(const Constant('FLEX'))();

  /// Tag stile di gioco (csv): control, attack, defense, flex.
  TextColumn get styleTags => text().withDefault(const Constant(''))();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Team profiles (PRD A2): "Io + Luca", "Team torneo"...
class Teams extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  @ReferenceName('teamsAsPlayerA')
  TextColumn get playerAId => text().references(Players, #id)();

  @ReferenceName('teamsAsPlayerB')
  TextColumn get playerBId => text().nullable().references(Players, #id)();
  TextColumn get playerBName => text().withDefault(const Constant(''))();
  TextColumn get roleA => text().withDefault(const Constant('UNDEFINED'))();
  TextColumn get roleB => text().withDefault(const Constant('UNDEFINED'))();
  TextColumn get tacticalNotes => text().withDefault(const Constant(''))();
  TextColumn get goals => text().withDefault(const Constant(''))();

  /// Processed square image stored inside app support, never an external URI.
  TextColumn get imageLocalPath => text().nullable()();

  /// Private Supabase Storage object path. A signed URL is resolved on demand.
  TextColumn get imageCloudPath => text().nullable()();
  IntColumn get imageVersion => integer().withDefault(const Constant(0))();
  IntColumn get imageCloudVersion => integer().withDefault(const Constant(0))();
  TextColumn get scoringStyle => text().withDefault(const Constant('AUTO'))();
  IntColumn get colorArgb =>
      integer().withDefault(const Constant(0xFFC8F135))();

  /// Cloud team UUID, created lazily after sign-in; local IDs remain stable.
  TextColumn get cloudId => text().nullable()();
  TextColumn get cloudRole =>
      text().withDefault(const Constant('LOCAL'))(); // LOCAL | OWNER | MEMBER
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-only registry used by the pairing wizard. It stores logical product
/// information and capabilities, never serial numbers, MAC addresses or other
/// hardware identifiers.
class ConnectedDevices extends Table {
  TextColumn get id => text()();
  TextColumn get platform => text()(); // APPLE_WATCH | WEAR_OS
  TextColumn get family => text().withDefault(const Constant(''))();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get alias => text().withDefault(const Constant(''))();
  TextColumn get status =>
      text().withDefault(const Constant('NOT_REACHABLE'))();
  TextColumn get capabilitiesJson => text().withDefault(const Constant('{}'))();
  BoolColumn get companionInstalled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get permissionsComplete =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get setupStep => integer().withDefault(const Constant(0))();
  IntColumn get lastSeenAtMs => integer().nullable()();
  IntColumn get lastSyncAtMs => integer().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local attribution for HealthKit, Health Connect, cloud providers and BLE.
/// Hardware serials and MAC addresses are deliberately excluded.
class HealthDataSources extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  TextColumn get provider => text()();
  TextColumn get sourceApplication => text().withDefault(const Constant(''))();
  TextColumn get sourceBundleId => text().withDefault(const Constant(''))();
  TextColumn get sourceDevice => text().withDefault(const Constant(''))();
  TextColumn get sourceModel => text().withDefault(const Constant(''))();
  TextColumn get connectionId => text().nullable()();
  BoolColumn get isPreferred => boolean().withDefault(const Constant(false))();
  BoolColumn get supportsLiveData =>
      boolean().withDefault(const Constant(false))();
  TextColumn get availableMetricsJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get detectedAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Normalized local aggregates. High-frequency samples are not persisted here
/// unless the user explicitly starts a Padelandia workout.
class HealthMetricRecords extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  TextColumn get provider => text()();
  TextColumn get sourceId => text().references(HealthDataSources, #id)();
  TextColumn get externalRecordId => text().nullable()();
  TextColumn get metricType => text()();
  IntColumn get startTimeMs => integer()();
  IntColumn get endTimeMs => integer()();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  TextColumn get contentHash => text()();
  IntColumn get syncVersion => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class HealthSourcePreferences extends Table {
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  TextColumn get metricType => text()();
  TextColumn get sourceId => text().references(HealthDataSources, #id)();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {ownerId, metricType};
}

/// Match-level, privacy-minimized health result used by analytics and backup.
/// Raw heart-rate series stay on device by default.
class MatchHealthSummaries extends Table {
  TextColumn get id => text()();
  TextColumn get matchId =>
      text().references(Matches, #id, onDelete: KeyAction.cascade)();
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  TextColumn get primarySourceId =>
      text().nullable().references(HealthDataSources, #id)();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get averageHeartRate => real().nullable()();
  RealColumn get maxHeartRate => real().nullable()();
  RealColumn get minHeartRate => real().nullable()();
  RealColumn get activeEnergyKcal => real().nullable()();
  RealColumn get totalEnergyKcal => real().nullable()();
  IntColumn get steps => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get highIntensityMinutes => integer().nullable()();
  RealColumn get recoveryDelta => real().nullable()();
  RealColumn get sleepScore => real().nullable()();
  RealColumn get readinessScore => real().nullable()();
  RealColumn get recoveryScore => real().nullable()();
  RealColumn get strainScore => real().nullable()();
  TextColumn get dataQuality => text().withDefault(const Constant('UNKNOWN'))();
  IntColumn get calculatedAtMs => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class HealthSyncJobs extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  TextColumn get provider => text()();
  TextColumn get syncType => text()();
  IntColumn get dateFromMs => integer().nullable()();
  IntColumn get dateToMs => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAtMs => integer().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get completedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// BLE devices are device-local. [localIdentifier] stores only a SHA-256
/// fingerprint of the OS identifier; raw UUIDs and Android MAC addresses are
/// used transiently by the native bridge and never persisted or uploaded.
class BleSensorDevices extends Table {
  TextColumn get id => text()();
  TextColumn get localIdentifier => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get deviceType =>
      text().withDefault(const Constant('HEART_RATE_SENSOR'))();
  TextColumn get manufacturer => text().withDefault(const Constant(''))();
  TextColumn get capabilitiesJson => text().withDefault(const Constant('[]'))();
  IntColumn get lastSeenAtMs => integer().nullable()();
  BoolColumn get isPreferred => boolean().withDefault(const Constant(false))();
  BoolColumn get isConnected => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Match header. Score lives in MatchEventRows (event sourcing).
@DataClassName('MatchRow')
class Matches extends Table {
  TextColumn get id => text()();
  TextColumn get teamId => text().nullable().references(Teams, #id)();
  TextColumn get formatJson => text()();
  TextColumn get status => text().withDefault(const Constant('CREATED'))();
  IntColumn get startTimeMs => integer().nullable()();
  IntColumn get endTimeMs => integer().nullable()();
  BoolColumn get wonByUs => boolean().nullable()();
  TextColumn get myRole => text().withDefault(const Constant('UNDEFINED'))();
  TextColumn get opponentLabel => text().withDefault(const Constant(''))();
  TextColumn get opponentTags => text().withDefault(const Constant(''))();
  IntColumn get opponentDifficulty =>
      integer().withDefault(const Constant(3))();
  TextColumn get location => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Cached rally_core MatchSummary as JSON (computed on completion).
  TextColumn get summaryJson => text().nullable()();

  /// Duo Mode: partita condivisa tra due team connessi (premium).
  BoolColumn get duoMode => boolean().withDefault(const Constant(false))();

  /// Team assegnato a QUESTO device/account nella timeline condivisa
  /// (TEAM_A/TEAM_B). Nullo per le partite classiche.
  TextColumn get duoTeam => text().nullable()();

  /// Sessione cloud duo_sessions collegata + codice invito da mostrare.
  TextColumn get duoSessionId => text().nullable()();
  TextColumn get duoJoinCode => text().nullable()();

  /// Account cloud che ha collegato questa copia locale della sessione Duo.
  /// Impedisce che un logout/login attribuisca eventi pendenti al nuovo utente.
  TextColumn get duoOwnerUserId => text().nullable()();

  /// Ultimo stato confermato dal protocollo cloud a due fasi.
  TextColumn get duoCloudStatus => text().nullable()();
  IntColumn get duoLastSyncAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Event-sourced score log (PRD data model MatchEvent).
class MatchEventRows extends Table {
  TextColumn get eventId => text()();
  TextColumn get matchId => text().references(Matches, #id)();
  IntColumn get seq => integer()();
  IntColumn get timestampMs => integer()();
  TextColumn get type => text()();
  TextColumn get teamId => text().nullable()();
  TextColumn get scoreBefore => text().nullable()();
  TextColumn get scoreAfter => text().nullable()();
  TextColumn get sourceDevice => text().withDefault(const Constant('PHONE'))();
  TextColumn get sourceMethod => text().withDefault(const Constant('TAP'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get payloadJson => text().nullable()();

  /// Attribuzione Duo Mode (audit + push cloud selettivo).
  TextColumn get sourceUserId => text().nullable()();
  TextColumn get sourceTeamId => text().nullable()();
  BoolColumn get duoMode => boolean().withDefault(const Constant(false))();
  IntColumn get createdLocallyAtMs => integer().nullable()();

  /// True quando l'evento è già sulla timeline cloud della sessione Duo
  /// (push riuscito o evento ricevuto dal server): non va ripushato.
  BoolColumn get cloudSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// Training templates (PRD H1/H2). Free templates are seeded locally.
class Trainings extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get role => text().withDefault(const Constant('UNDEFINED'))();
  BoolColumn get premium => boolean().withDefault(const Constant(false))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();

  /// JSON list of drills: [{name, minutes, note}].
  TextColumn get drillsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

class TrainingLogs extends Table {
  TextColumn get id => text()();
  TextColumn get trainingId => text().references(Trainings, #id)();
  IntColumn get dateMs => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Sforzo percepito 1-10 (RPE, 0 = non registrato) e minuti effettivi:
  /// alimentano il carico settimanale (ACWR) del training.
  IntColumn get rpe => integer().withDefault(const Constant(0))();
  IntColumn get minutes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key-value store (settings, entitlements cache, onboarding flag).
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Players,
    Teams,
    Matches,
    MatchEventRows,
    Trainings,
    TrainingLogs,
    ConnectedDevices,
    HealthDataSources,
    HealthMetricRecords,
    HealthSourcePreferences,
    MatchHealthSummaries,
    HealthSyncJobs,
    BleSensorDevices,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'rallymate'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  static const _performanceIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_players_is_me ON players (is_me)',
    'CREATE INDEX IF NOT EXISTS idx_teams_active_created '
        'ON teams (archived, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_matches_recent '
        'ON matches (start_time_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_matches_status_end '
        'ON matches (status, end_time_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_match_events_match_seq '
        'ON match_event_rows (match_id, seq)',
    'CREATE INDEX IF NOT EXISTS idx_match_events_sync '
        'ON match_event_rows (match_id, synced, cloud_synced)',
    'CREATE INDEX IF NOT EXISTS idx_matches_duo_owner_sync '
        'ON matches (duo_owner_user_id, duo_cloud_status, start_time_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_training_logs_date '
        'ON training_logs (date_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_connected_devices_default_seen '
        'ON connected_devices (is_default, last_seen_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_health_sources_provider_preferred '
        'ON health_data_sources (provider, is_preferred, updated_at_ms DESC)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_health_records_content_hash '
        'ON health_metric_records (owner_id, content_hash)',
    'CREATE INDEX IF NOT EXISTS idx_health_records_metric_time '
        'ON health_metric_records (metric_type, start_time_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_health_source_preferences_source '
        'ON health_source_preferences (source_id)',
    'CREATE INDEX IF NOT EXISTS idx_match_health_match '
        'ON match_health_summaries (match_id, calculated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_health_sync_pending '
        'ON health_sync_jobs (status, next_retry_at_ms)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_ble_sensor_local_identifier '
        'ON ble_sensor_devices (local_identifier)',
  ];

  Future<void> _createPerformanceIndexes() async {
    for (final statement in _performanceIndexes) {
      await customStatement(statement);
    }
  }

  /// Pre-release builds briefly shipped the Duo ownership columns while the
  /// SQLite `user_version` was still 10. A later upgrade must therefore treat
  /// these additions as idempotent instead of assuming version and physical
  /// schema are perfectly aligned. This preserves every local match/event on
  /// affected devices and also makes a retry safe after an interrupted update.
  Future<void> _addColumnIfMissing(
    String tableName, {
    required String columnName,
    required Future<void> Function() add,
  }) async {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(tableName) ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(columnName)) {
      throw ArgumentError('Invalid SQLite identifier');
    }
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    final exists = columns.any((row) => row.read<String>('name') == columnName);
    if (!exists) await add();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createPerformanceIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(players, players.availability);
        await m.addColumn(players, players.styleTags);
        await m.addColumn(trainingLogs, trainingLogs.rpe);
        await m.addColumn(trainingLogs, trainingLogs.minutes);
      }
      if (from < 3) {
        // Duo Mode (premium): partite condivise tra due team.
        await m.addColumn(matches, matches.duoMode);
        await m.addColumn(matches, matches.duoTeam);
        await m.addColumn(matches, matches.duoSessionId);
        await m.addColumn(matches, matches.duoJoinCode);
        await m.addColumn(matchEventRows, matchEventRows.sourceUserId);
        await m.addColumn(matchEventRows, matchEventRows.sourceTeamId);
        await m.addColumn(matchEventRows, matchEventRows.duoMode);
        await m.addColumn(matchEventRows, matchEventRows.createdLocallyAtMs);
        await m.addColumn(matchEventRows, matchEventRows.cloudSynced);
      }
      if (from < 5) {
        await m.addColumn(teams, teams.imageLocalPath);
        await m.addColumn(teams, teams.imageCloudPath);
        await m.addColumn(teams, teams.imageVersion);
        await m.addColumn(teams, teams.scoringStyle);
        await m.addColumn(teams, teams.colorArgb);
        await m.addColumn(teams, teams.cloudId);
        await m.createTable(connectedDevices);
      }
      if (from < 6) {
        await m.addColumn(teams, teams.imageCloudVersion);
      }
      if (from < 7) {
        await m.addColumn(players, players.bio);
        await m.addColumn(players, players.homeArea);
        await m.addColumn(players, players.preferredSide);
        await m.addColumn(players, players.preferredTime);
      }
      if (from < 8) {
        await m.addColumn(teams, teams.cloudRole);
      }
      if (from < 9) {
        await m.addColumn(players, players.avatarLocalPath);
        await m.addColumn(players, players.avatarCloudPath);
        await m.addColumn(players, players.avatarVersion);
        await m.addColumn(players, players.avatarCloudVersion);
      }
      if (from < 10) {
        await m.createTable(healthDataSources);
        await m.createTable(healthMetricRecords);
        await m.createTable(healthSourcePreferences);
        await m.createTable(matchHealthSummaries);
        await m.createTable(healthSyncJobs);
        await m.createTable(bleSensorDevices);
      }
      if (from < 11) {
        await _addColumnIfMissing(
          'matches',
          columnName: 'duo_owner_user_id',
          add: () => m.addColumn(matches, matches.duoOwnerUserId),
        );
        await _addColumnIfMissing(
          'matches',
          columnName: 'duo_cloud_status',
          add: () => m.addColumn(matches, matches.duoCloudStatus),
        );
        await _addColumnIfMissing(
          'matches',
          columnName: 'duo_last_sync_at_ms',
          add: () => m.addColumn(matches, matches.duoLastSyncAtMs),
        );
        // Columns declared in tables but missing from earlier migrations.
        await _addColumnIfMissing(
          'players',
          columnName: 'play_frequency',
          add: () => m.addColumn(players, players.playFrequency),
        );
        await _addColumnIfMissing(
          'players',
          columnName: 'privacy',
          add: () => m.addColumn(players, players.privacy),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'player_b_name',
          add: () => m.addColumn(teams, teams.playerBName),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'role_a',
          add: () => m.addColumn(teams, teams.roleA),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'role_b',
          add: () => m.addColumn(teams, teams.roleB),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'tactical_notes',
          add: () => m.addColumn(teams, teams.tacticalNotes),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'goals',
          add: () => m.addColumn(teams, teams.goals),
        );
        await _addColumnIfMissing(
          'teams',
          columnName: 'archived',
          add: () => m.addColumn(teams, teams.archived),
        );
      }

      // The index set includes columns and tables introduced after schema 4.
      // Build it only after every structural migration so multi-version
      // upgrades (for example v3 -> v8) cannot reference a table too early.
      await _createPerformanceIndexes();
    },
  );
}
