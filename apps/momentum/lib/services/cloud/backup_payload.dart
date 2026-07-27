library;

import 'dart:convert';

/// Stable, versioned representation of a Momentum Premium backup.
///
/// Health data, authentication tokens, billing state and device diagnostics
/// are deliberately outside this contract. Analytics are reconstructed from
/// matches and their event timelines instead of being duplicated.
abstract final class BackupPayloadCodec {
  static const format = 'rallymate-backup';
  // v3 makes Star Point formats fail closed on older app builds. The nested
  // payload shape is unchanged; only the compatibility boundary is bumped.
  static const currentVersion = 3;
  static const maxPayloadBytes = 20 * 1024 * 1024;
  static const maxRecordsPerSection = 500000;

  static Map<String, Object?> encode({
    required List<Map<String, Object?>> players,
    required List<Map<String, Object?>> teams,
    required List<Map<String, Object?>> matches,
    required List<Map<String, Object?>> events,
    required List<Map<String, Object?>> trainingLogs,
    required Map<String, String> preferences,
    DateTime? createdAt,
  }) {
    final portablePlayers = players
        .map(
          (row) => Map<String, Object?>.from(row)..['avatarLocalPath'] = null,
        )
        .toList(growable: false);
    final portableTeams = teams
        .map((row) => Map<String, Object?>.from(row)..['imageLocalPath'] = null)
        .toList(growable: false);
    final eventsByMatch = <String, List<Map<String, Object?>>>{};
    for (final event in events) {
      final matchId = event['matchId'] as String?;
      if (matchId == null || matchId.isEmpty) {
        throw const FormatException('Evento senza matchId');
      }
      eventsByMatch.putIfAbsent(matchId, () => []).add(event);
    }

    final nestedMatches = matches
        .map((match) {
          final id = match['id'] as String?;
          if (id == null || id.isEmpty) {
            throw const FormatException('Partita senza id');
          }
          final canonicalMatch = Map<String, Object?>.from(match)
            ..['summaryJson'] = null;
          return <String, Object?>{
            ...canonicalMatch,
            'events':
                eventsByMatch.remove(id) ?? const <Map<String, Object?>>[],
          };
        })
        .toList(growable: false);
    if (eventsByMatch.isNotEmpty) {
      throw const FormatException('Timeline riferita a una partita assente');
    }

    final payload = <String, Object?>{
      'format': format,
      'v': currentVersion,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'sections': <String, Object?>{
        'profile': <String, Object?>{'players': portablePlayers},
        'teams': portableTeams,
        'matches': nestedMatches,
        'training': <String, Object?>{'logs': trainingLogs},
        'preferences': preferences,
      },
      'counts': <String, int>{
        'players': portablePlayers.length,
        'teams': portableTeams.length,
        'matches': matches.length,
        'events': events.length,
        'trainingLogs': trainingLogs.length,
      },
      'analytics': const <String, Object?>{
        'storage': 'derived',
        'rebuildFrom': <String>['matches', 'events', 'trainingLogs'],
      },
      'excluded': const <String>[
        'healthData',
        'authTokens',
        'billingEntitlements',
        'deviceRegistry',
        'notificationTokens',
        'localFilePaths',
      ],
    };
    _validateSize(payload);
    return payload;
  }

  static BackupData decode(Map<String, Object?> payload) {
    _validateSize(payload);
    final version = payload['v'] as int? ?? 0;
    if (version <= 0 || version > currentVersion) {
      throw FormatException('Versione backup non supportata: $version');
    }
    return version == 1 ? _decodeLegacy(payload) : _decodeV2(payload);
  }

  static BackupData _decodeV2(Map<String, Object?> payload) {
    if (payload['format'] != format) {
      throw const FormatException('Formato backup non riconosciuto');
    }
    final sections = _map(payload['sections'], 'sections');
    final profile = _map(sections['profile'], 'sections.profile');
    final training = _map(sections['training'], 'sections.training');
    final matchesWithEvents = _rows(sections['matches'], 'matches');
    final matches = <Map<String, Object?>>[];
    final events = <Map<String, Object?>>[];
    for (final nested in matchesWithEvents) {
      final match = Map<String, Object?>.from(nested);
      events.addAll(_rows(match.remove('events'), 'matches.events'));
      matches.add(match);
    }

    final data = BackupData(
      players: _rows(profile['players'], 'players'),
      teams: _rows(sections['teams'], 'teams'),
      matches: matches,
      events: events,
      trainingLogs: _rows(training['logs'], 'training.logs'),
      preferences: _stringMap(sections['preferences'], 'preferences'),
    );
    _validateCounts(payload['counts'], data);
    return data;
  }

  static BackupData _decodeLegacy(Map<String, Object?> payload) => BackupData(
    players: _rows(payload['players'], 'players'),
    teams: _rows(payload['teams'], 'teams'),
    matches: _rows(payload['matches'], 'matches'),
    events: _rows(payload['events'], 'events'),
    trainingLogs: _rows(payload['trainingLogs'], 'trainingLogs'),
    preferences: const {},
  );

  static Map<String, Object?> _map(Object? value, String label) {
    if (value is! Map) throw FormatException('$label non valido');
    return value.cast<String, Object?>();
  }

  static List<Map<String, Object?>> _rows(Object? value, String label) {
    if (value == null) return const [];
    if (value is! List || value.length > maxRecordsPerSection) {
      throw FormatException('$label non valido o troppo grande');
    }
    return value
        .map((row) {
          if (row is! Map) throw FormatException('Record $label non valido');
          return row.cast<String, Object?>();
        })
        .toList(growable: false);
  }

  static Map<String, String> _stringMap(Object? value, String label) {
    if (value == null) return const {};
    final raw = _map(value, label);
    return raw.map((key, item) {
      if (item is! String) throw FormatException('$label.$key non valido');
      return MapEntry(key, item);
    });
  }

  static void _validateCounts(Object? value, BackupData data) {
    final counts = _map(value, 'counts');
    final actual = <String, int>{
      'players': data.players.length,
      'teams': data.teams.length,
      'matches': data.matches.length,
      'events': data.events.length,
      'trainingLogs': data.trainingLogs.length,
    };
    for (final entry in actual.entries) {
      if (counts[entry.key] != entry.value) {
        throw FormatException('Conteggio ${entry.key} non coerente');
      }
    }
  }

  static void _validateSize(Map<String, Object?> payload) {
    final bytes = utf8.encode(jsonEncode(payload)).length;
    if (bytes > maxPayloadBytes) {
      throw const FormatException('Backup oltre il limite di 20 MB');
    }
  }
}

/// Makes a backup portable to a device that already owns a bootstrap profile.
/// Restored profile fields win, while the local `me` id stays stable so teams
/// created on this device keep valid foreign keys.
BackupData reconcileBackupIdentity(
  BackupData data, {
  required String? localMeId,
}) {
  final selectedMeIndex = data.players.indexWhere((row) => row['isMe'] == true);
  final selectedMe = selectedMeIndex < 0 ? null : data.players[selectedMeIndex];
  final backupMeId = selectedMe?['id'] as String?;
  final targetMeId = localMeId?.isNotEmpty == true ? localMeId : backupMeId;
  final idRemap = <String, String>{
    if (backupMeId != null && targetMeId != null) backupMeId: targetMeId,
  };

  final players = <Map<String, Object?>>[];
  if (selectedMe != null && targetMeId != null) {
    players.add(
      Map<String, Object?>.from(selectedMe)
        ..['id'] = targetMeId
        ..['isMe'] = true
        ..['avatarLocalPath'] = null,
    );
  }
  for (var index = 0; index < data.players.length; index++) {
    if (index == selectedMeIndex) continue;
    final row = Map<String, Object?>.from(data.players[index]);
    final id = row['id'] as String?;
    // A malformed duplicate cannot overwrite the selected local profile.
    if (selectedMe != null && id == targetMeId) continue;
    row['isMe'] = false;
    row['avatarLocalPath'] = null;
    players.add(row);
  }

  String? remapPlayer(Object? value) {
    final id = value as String?;
    return id == null ? null : idRemap[id] ?? id;
  }

  final teams = data.teams
      .map((source) {
        final row = Map<String, Object?>.from(source);
        row['playerAId'] = remapPlayer(row['playerAId']);
        row['playerBId'] = remapPlayer(row['playerBId']);
        row['imageLocalPath'] = null;
        return row;
      })
      .toList(growable: false);

  return BackupData(
    players: players,
    teams: teams,
    matches: data.matches,
    events: data.events,
    trainingLogs: data.trainingLogs,
    preferences: data.preferences,
  );
}

class BackupData {
  const BackupData({
    required this.players,
    required this.teams,
    required this.matches,
    required this.events,
    required this.trainingLogs,
    required this.preferences,
  });

  final List<Map<String, Object?>> players;
  final List<Map<String, Object?>> teams;
  final List<Map<String, Object?>> matches;
  final List<Map<String, Object?>> events;
  final List<Map<String, Object?>> trainingLogs;
  final Map<String, String> preferences;
}
