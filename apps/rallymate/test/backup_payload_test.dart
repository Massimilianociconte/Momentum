import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/cloud/backup_payload.dart';

void main() {
  test('backup v2 is hierarchical and round-trips every user record', () {
    final payload = BackupPayloadCodec.encode(
      players: [
        {'id': 'p1', 'name': 'Marco'},
      ],
      teams: [
        {'id': 't1', 'name': 'Team Uno'},
      ],
      matches: [
        {
          'id': 'm1',
          'formatJson': '{}',
          'summaryJson': '{"derived":"must-not-be-backed-up"}',
        },
      ],
      events: [
        {'eventId': 'e1', 'matchId': 'm1', 'seq': 1},
        {'eventId': 'e2', 'matchId': 'm1', 'seq': 2},
      ],
      trainingLogs: [
        {'id': 'l1', 'trainingId': 'volley'},
      ],
      preferences: const {'onboarding_done': 'true'},
      createdAt: DateTime.utc(2026, 7, 12, 10),
    );

    expect(payload['format'], BackupPayloadCodec.format);
    expect(payload['v'], BackupPayloadCodec.currentVersion);
    expect(
      (payload['excluded'] as List),
      containsAll(['healthData', 'authTokens', 'deviceRegistry']),
    );

    final decoded = BackupPayloadCodec.decode(payload);
    expect(decoded.players.single['id'], 'p1');
    expect(decoded.teams.single['id'], 't1');
    expect(decoded.matches.single['id'], 'm1');
    expect(decoded.matches.single['summaryJson'], isNull);
    expect(decoded.events.map((row) => row['eventId']), ['e1', 'e2']);
    expect(decoded.trainingLogs.single['id'], 'l1');
    expect(decoded.preferences['onboarding_done'], 'true');
  });

  test('backup rejects an event without its owning match', () {
    expect(
      () => BackupPayloadCodec.encode(
        players: const [],
        teams: const [],
        matches: const [],
        events: const [
          {'eventId': 'orphan', 'matchId': 'missing'},
        ],
        trainingLogs: const [],
        preferences: const {},
      ),
      throwsFormatException,
    );
  });

  test('backup detects truncated or manipulated record counts', () {
    final payload = BackupPayloadCodec.encode(
      players: const [],
      teams: const [],
      matches: const [],
      events: const [],
      trainingLogs: const [],
      preferences: const {},
    );
    (payload['counts'] as Map<String, int>)['matches'] = 1;

    expect(() => BackupPayloadCodec.decode(payload), throwsFormatException);
  });

  test('legacy v1 backups remain restorable', () {
    final decoded = BackupPayloadCodec.decode({
      'v': 1,
      'players': [
        {'id': 'legacy-player'},
      ],
      'teams': <Object?>[],
      'matches': <Object?>[],
      'events': <Object?>[],
      'trainingLogs': <Object?>[],
    });

    expect(decoded.players.single['id'], 'legacy-player');
    expect(decoded.preferences, isEmpty);
  });

  test('backup strips device-local image paths from every payload', () {
    final decoded = BackupPayloadCodec.decode(
      BackupPayloadCodec.encode(
        players: const [
          {
            'id': 'old-me',
            'name': 'Marco',
            'isMe': true,
            'avatarLocalPath': '/old/device/avatar.jpg',
          },
        ],
        teams: const [
          {
            'id': 'team-1',
            'name': 'Team',
            'imageLocalPath': '/old/device/team.jpg',
          },
        ],
        matches: const [],
        events: const [],
        trainingLogs: const [],
        preferences: const {},
      ),
    );

    expect(decoded.players.single['avatarLocalPath'], isNull);
    expect(decoded.teams.single['imageLocalPath'], isNull);
  });

  test('restore keeps one local me id and remaps team references', () {
    final reconciled = reconcileBackupIdentity(
      const BackupData(
        players: [
          {
            'id': 'old-me',
            'name': 'Profilo completo',
            'isMe': true,
            'avatarLocalPath': '/old/device/avatar.jpg',
          },
          {'id': 'partner', 'name': 'Luca', 'isMe': false},
        ],
        teams: [
          {'id': 'team-1', 'playerAId': 'old-me', 'playerBId': 'partner'},
        ],
        matches: [],
        events: [],
        trainingLogs: [],
        preferences: {},
      ),
      localMeId: 'device-me',
    );

    final meRows = reconciled.players.where((row) => row['isMe'] == true);
    expect(meRows, hasLength(1));
    expect(meRows.single['id'], 'device-me');
    expect(meRows.single['name'], 'Profilo completo');
    expect(meRows.single['avatarLocalPath'], isNull);
    expect(
      reconciled.players.map((row) => row['id']),
      isNot(contains('old-me')),
    );
    expect(reconciled.teams.single['playerAId'], 'device-me');
    expect(reconciled.teams.single['playerBId'], 'partner');
  });
}
