library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';

import '../core/providers.dart';
import '../features/live/live_match_controller.dart';
import 'match_scoring_lock.dart';
import 'wearable_provider_service.dart';

class WearableCloudEvent {
  const WearableCloudEvent({
    required this.ingestId,
    required this.provider,
    required this.eventId,
    required this.matchId,
    required this.eventType,
    required this.timestampMs,
    required this.payload,
  });

  final int ingestId;
  final String provider;
  final String eventId;
  final String matchId;
  final MatchEventType eventType;
  final int timestampMs;
  final Map<String, Object?> payload;

  factory WearableCloudEvent.fromMap(Map<String, Object?> value) {
    final ingestId = (value['ingest_id'] as num?)?.toInt();
    final provider = value['provider']?.toString() ?? '';
    final eventId = value['external_event_id']?.toString() ?? '';
    final matchId = value['match_id']?.toString() ?? '';
    final eventType = MatchEventType.tryFromWire(
      value['event_type']?.toString() ?? '',
    );
    final eventAt = DateTime.tryParse(value['event_at']?.toString() ?? '');
    if (ingestId == null ||
        ingestId <= 0 ||
        !const {'GARMIN_CONNECT_IQ', 'FITBIT_OS'}.contains(provider) ||
        eventId.length < 8 ||
        matchId.length < 3 ||
        eventType == null ||
        eventAt == null) {
      throw const FormatException('Invalid wearable event envelope');
    }
    return WearableCloudEvent(
      ingestId: ingestId,
      provider: provider,
      eventId: eventId,
      matchId: matchId,
      eventType: eventType,
      timestampMs: eventAt.millisecondsSinceEpoch,
      payload: (value['payload'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  MatchEvent toMatchEvent() {
    final team = switch (eventType) {
      MatchEventType.pointTeamA => TeamId.a,
      MatchEventType.pointTeamB => TeamId.b,
      _ => switch (payload['teamId']?.toString()) {
        'TEAM_A' => TeamId.a,
        'TEAM_B' => TeamId.b,
        _ => null,
      },
    };
    // Preserve targetEventId at payload root for engine-targeted undo.
    final mergedPayload = <String, Object?>{
      ...payload,
      'wearableProvider': provider,
      'ingestId': ingestId,
      if ((payload['targetEventId']?.toString() ?? '').isNotEmpty)
        'targetEventId': payload['targetEventId'].toString(),
    };
    return MatchEvent(
      eventId: eventId,
      matchId: matchId,
      timestampMs: timestampMs,
      type: eventType,
      teamId: team,
      sourceDevice: provider == 'GARMIN_CONNECT_IQ'
          ? SourceDevice.garmin
          : SourceDevice.fitbit,
      sourceMethod: SourceMethod.fromWire(
        payload['sourceMethod']?.toString() ?? 'TAP',
      ),
      synced: true,
      payload: mergedPayload,
    );
  }

  MatchFormat? format() {
    final raw = payload['format'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      return MatchFormat.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class WearableCloudSyncResult {
  const WearableCloudSyncResult({
    required this.processedEvents,
    required this.providers,
    required this.matchIds,
  });

  final int processedEvents;
  final Set<String> providers;
  final Set<String> matchIds;

  static const empty = WearableCloudSyncResult(
    processedEvents: 0,
    providers: {},
    matchIds: {},
  );
}

class WearableCloudSyncCoordinator {
  WearableCloudSyncCoordinator(this.ref);

  final Ref ref;
  Future<WearableCloudSyncResult>? _activeSync;

  Future<WearableCloudSyncResult> sync() async {
    final running = _activeSync;
    if (running != null) return running;
    final future = _syncNow();
    _activeSync = future;
    try {
      return await future;
    } finally {
      _activeSync = null;
    }
  }

  Future<WearableCloudSyncResult> _syncNow() async {
    final transport = ref.read(wearableProviderServiceProvider);
    final repo = ref.read(matchRepoProvider);
    var processed = 0;
    final providers = <String>{};
    final matchIds = <String>{};

    for (var page = 0; page < 5; page++) {
      final raw = await transport.drainCloudEvents();
      if (raw.isEmpty) break;
      final records = <WearableCloudEvent>[];
      final malformedIngestIds = <int>[];
      for (final value in raw) {
        try {
          records.add(WearableCloudEvent.fromMap(value));
        } on FormatException {
          // A malformed record (gateway↔app schema drift) must not poison
          // the page: without an ack the same page would be re-downloaded
          // and re-fail on every sync, stalling valid events forever.
          final ingestId = (value['ingest_id'] as num?)?.toInt();
          if (ingestId != null && ingestId > 0) {
            malformedIngestIds.add(ingestId);
          }
          debugPrint('wearable_cloud_sync: skipped malformed event $ingestId');
        }
      }
      if (malformedIngestIds.isNotEmpty) {
        await transport.acknowledgeCloudEvents(malformedIngestIds);
      }
      final grouped = <String, List<WearableCloudEvent>>{};
      for (final record in records) {
        grouped.putIfAbsent(record.matchId, () => []).add(record);
      }
      for (final entry in grouped.entries) {
        final group = List<WearableCloudEvent>.of(entry.value)
          ..sort(compareWearableCausalOrder);
        await repo.mergeSyncedEvents(
          matchId: entry.key,
          events: group.map((record) => record.toMatchEvent()).toList(),
          // Null → mergeSyncedEvents applies the single app-wide default
          // (goldenPointBo3); keep BLE and cloud paths deterministic.
          format: group.map((record) => record.format()).nonNulls.firstOrNull,
        );
        await transport.acknowledgeCloudEvents(
          group.map((record) => record.ingestId),
        );
        processed += group.length;
        providers.addAll(group.map((record) => record.provider));
        matchIds.add(entry.key);
        await _afterWearableMerge(
          matchId: entry.key,
          providers: group.map((r) => r.provider).toSet(),
          events: group.map((r) => r.toMatchEvent()).toList(),
        );
      }
      if (raw.length < 100) break;
    }

    if (processed > 0) {
      ref.invalidate(recentMatchesProvider);
      ref.invalidate(summariesProvider);
    }
    return WearableCloudSyncResult(
      processedEvents: processed,
      providers: providers,
      matchIds: matchIds,
    );
  }

  /// Local-first merge for Garmin peer batches (no cloud ACK required).
  Future<void> commitGarminEvents(List<Map<String, Object?>> events) async {
    if (events.isEmpty) return;
    final repo = ref.read(matchRepoProvider);
    final grouped = <String, List<MatchEvent>>{};
    final formats = <String, MatchFormat?>{};
    for (final raw in events) {
      final matchEvent = matchEventFromWearableMap(
        raw,
        sourceDevice: SourceDevice.garmin,
      );
      if (matchEvent == null) continue;
      grouped.putIfAbsent(matchEvent.matchId, () => []).add(matchEvent);
      formats.putIfAbsent(
        matchEvent.matchId,
        () => formatFromWearableMap(raw),
      );
    }
    for (final entry in grouped.entries) {
      final ordered = List<MatchEvent>.of(entry.value)
        ..sort(compareMatchEventCausalOrder);
      await repo.mergeSyncedEvents(
        matchId: entry.key,
        events: ordered,
        format: formats[entry.key],
      );
      await _afterWearableMerge(
        matchId: entry.key,
        providers: const {'GARMIN_CONNECT_IQ'},
        events: ordered,
      );
    }
    if (grouped.isNotEmpty) {
      ref.invalidate(recentMatchesProvider);
      ref.invalidate(summariesProvider);
    }
  }

  /// Lock phone only after real wearable scoring activity; unlock on complete.
  /// Deferred invalidate matches Duo (avoid mid-tap engine rebuild).
  Future<void> _afterWearableMerge({
    required String matchId,
    required Set<String> providers,
    required List<MatchEvent> events,
  }) async {
    final lock = ref.read(matchScoringLockProvider);
    final hasScoringEvent = events.any(
      (e) =>
          e.type == MatchEventType.pointTeamA ||
          e.type == MatchEventType.pointTeamB ||
          e.type == MatchEventType.matchStarted ||
          e.type == MatchEventType.matchCompleted,
    );
    final completed = events.any((e) => e.type == MatchEventType.matchCompleted);
    if (completed) {
      await lock.unlock(matchId);
    } else if (hasScoringEvent) {
      for (final provider in providers) {
        if (MatchScoringLockService.locksPhoneScoring(provider)) {
          await lock.lock(matchId, provider);
          break;
        }
      }
    }
    // Same FIFO as local taps when the live screen owns the controller.
    try {
      await ref
          .read(liveMatchProvider(matchId).notifier)
          .reloadAfterExternalMerge();
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      ref.invalidate(liveMatchProvider(matchId));
    }
  }
}

/// Causal order: device sequence when present AND from the same device,
/// else event_at, else eventId. Sequence numbers are local to each physical
/// device; comparing them across devices produces meaningless ordering.
int compareWearableCausalOrder(WearableCloudEvent a, WearableCloudEvent b) {
  final deviceA = a.payload['deviceId']?.toString();
  final deviceB = b.payload['deviceId']?.toString();
  // Only trust sequence comparison when both events originate from the same
  // physical device (same deviceId). Cross-device sequences are independent
  // counters and must not be compared.
  if (deviceA != null && deviceA == deviceB) {
    final seqA = (a.payload['sequence'] as num?)?.toInt();
    final seqB = (b.payload['sequence'] as num?)?.toInt();
    if (seqA != null && seqB != null && seqA != seqB) {
      return seqA.compareTo(seqB);
    }
  }
  final byTime = a.timestampMs.compareTo(b.timestampMs);
  if (byTime != 0) return byTime;
  return a.eventId.compareTo(b.eventId);
}

int compareMatchEventCausalOrder(MatchEvent a, MatchEvent b) {
  final deviceA = a.payload?['deviceId']?.toString();
  final deviceB = b.payload?['deviceId']?.toString();
  if (deviceA != null && deviceA == deviceB) {
    final seqA = (a.payload?['sequence'] as num?)?.toInt();
    final seqB = (b.payload?['sequence'] as num?)?.toInt();
    if (seqA != null && seqB != null && seqA != seqB) {
      return seqA.compareTo(seqB);
    }
  }
  final byTime = a.timestampMs.compareTo(b.timestampMs);
  if (byTime != 0) return byTime;
  return a.eventId.compareTo(b.eventId);
}

MatchEvent? matchEventFromWearableMap(
  Map<String, Object?> value, {
  required SourceDevice sourceDevice,
}) {
  final eventId = value['eventId']?.toString() ?? '';
  final matchId = value['matchId']?.toString() ?? '';
  final eventType = MatchEventType.tryFromWire(value['type']?.toString() ?? '');
  final timestampMs = (value['timestampMs'] as num?)?.toInt();
  if (eventId.length < 8 ||
      matchId.length < 3 ||
      eventType == null ||
      timestampMs == null) {
    return null;
  }
  final team = switch (eventType) {
    MatchEventType.pointTeamA => TeamId.a,
    MatchEventType.pointTeamB => TeamId.b,
    _ => switch (value['teamId']?.toString()) {
      'TEAM_A' => TeamId.a,
      'TEAM_B' => TeamId.b,
      _ => null,
    },
  };
  final payload = <String, Object?>{
    if (value['sourceMethod'] != null) 'sourceMethod': value['sourceMethod'],
    if (value['sequence'] is num) 'sequence': (value['sequence'] as num).toInt(),
    if ((value['targetEventId']?.toString() ?? '').isNotEmpty)
      'targetEventId': value['targetEventId'].toString(),
    if ((value['teamId']?.toString() ?? '').isNotEmpty)
      'teamId': value['teamId'].toString(),
    if (value['format'] != null) 'format': value['format'],
    'wearableProvider': sourceDevice.wire,
  };
  return MatchEvent(
    eventId: eventId,
    matchId: matchId,
    timestampMs: timestampMs,
    type: eventType,
    teamId: team,
    sourceDevice: sourceDevice,
    sourceMethod: SourceMethod.fromWire(
      value['sourceMethod']?.toString() ?? 'TAP',
    ),
    synced: true,
    payload: payload,
  );
}

MatchFormat? formatFromWearableMap(Map<String, Object?> value) {
  final raw = value['format'];
  if (raw is! String || raw.isEmpty) return null;
  try {
    return MatchFormat.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

final wearableCloudSyncProvider = Provider<WearableCloudSyncCoordinator>(
  WearableCloudSyncCoordinator.new,
);
