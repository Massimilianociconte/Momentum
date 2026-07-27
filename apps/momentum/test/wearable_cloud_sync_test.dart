import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/services/wearable_cloud_sync.dart';

void main() {
  test('maps Garmin point envelope to an idempotent MatchEvent', () {
    final record = WearableCloudEvent.fromMap({
      'ingest_id': 42,
      'provider': 'GARMIN_CONNECT_IQ',
      'external_event_id': 'event-garmin-0001',
      'match_id': 'match-garmin-1',
      'event_type': 'POINT_TEAM_A',
      'event_at': '2026-07-12T08:30:00.000Z',
      'payload': {'sourceMethod': 'TAP', 'sequence': 3},
    });

    final event = record.toMatchEvent();
    expect(event.eventId, 'event-garmin-0001');
    expect(event.type, MatchEventType.pointTeamA);
    expect(event.teamId, TeamId.a);
    expect(event.sourceDevice, SourceDevice.garmin);
    expect(event.synced, isTrue);
    expect(event.payload!['ingestId'], 42);
  });

  test('preserves Fitbit targeted undo metadata', () {
    final record = WearableCloudEvent.fromMap({
      'ingest_id': 43,
      'provider': 'FITBIT_OS',
      'external_event_id': 'event-fitbit-undo-1',
      'match_id': 'match-fitbit-1',
      'event_type': 'UNDO',
      'event_at': '2026-07-12T08:31:00.000Z',
      'payload': {
        'sourceMethod': 'TAP',
        'teamId': 'TEAM_B',
        'targetEventId': 'event-fitbit-point-1',
      },
    });

    final event = record.toMatchEvent();
    expect(event.type, MatchEventType.undo);
    expect(event.teamId, TeamId.b);
    expect(event.sourceDevice, SourceDevice.fitbit);
    expect(event.payload!['targetEventId'], 'event-fitbit-point-1');
  });

  test('decodes a phone-provided match format when present', () {
    final format = MatchFormat.singleSet;
    final record = WearableCloudEvent.fromMap({
      'ingest_id': 44,
      'provider': 'FITBIT_OS',
      'external_event_id': 'event-fitbit-start-1',
      'match_id': 'match-fitbit-2',
      'event_type': 'MATCH_STARTED',
      'event_at': '2026-07-12T08:32:00.000Z',
      'payload': {
        'sourceMethod': 'AUTO',
        'format': jsonEncode(format.toJson()),
      },
    });

    expect(record.format()!.id, MatchFormat.singleSet.id);
    expect(record.format()!.setsToWin, 1);
  });

  test('rejects malformed or unsupported provider envelopes', () {
    expect(
      () => WearableCloudEvent.fromMap({
        'ingest_id': 1,
        'provider': 'TIZEN',
        'external_event_id': 'event-123456',
        'match_id': 'match-123',
        'event_type': 'POINT_TEAM_A',
        'event_at': '2026-07-12T08:30:00.000Z',
      }),
      throwsFormatException,
    );
  });
}
