library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';

import '../core/providers.dart';
import '../data/db/database.dart';
import 'match_scoring_lock.dart';
import 'watch_sync.dart';
import 'wearable_provider_service.dart';
import 'cloud/duo_service.dart';
import 'cloud/cloud_config.dart';
import 'cloud/cloud_service.dart';

const _scoringWearableProviders = {
  'APPLE_WATCH',
  'WEAR_OS',
  'GARMIN_CONNECT_IQ',
  'FITBIT_OS',
};

/// Journal types the watch scoring engines can replay. Derived/audit types
/// (GAME_COMPLETED, SIDE_CHANGE, Duo lifecycle, …) are recomputed on replay.
const _wearableJournalTypes = {
  MatchEventType.matchStarted,
  MatchEventType.pointTeamA,
  MatchEventType.pointTeamB,
  MatchEventType.undo,
  MatchEventType.matchPaused,
  MatchEventType.matchResumed,
  MatchEventType.matchCompleted,
};

/// Match statuses a wearable may resume mid-score.
const _resumableStatuses = {'CREATED', 'IN_PROGRESS', 'PAUSED'};

String wearableProviderFor(ConnectedDevice device) {
  try {
    final value = jsonDecode(device.capabilitiesJson);
    if (value is Map && value['provider'] is String) {
      return value['provider'] as String;
    }
  } catch (_) {
    // Legacy device records use platform as provider.
  }
  return device.platform;
}

bool isScoringWearableReady(ConnectedDevice device) {
  final provider = wearableProviderFor(device);
  if (!_scoringWearableProviders.contains(provider)) return false;
  // Live READY always qualifies.
  if (device.status == 'READY') return true;
  // Native phone↔watch bridges can still deliver durable START_MATCH while
  // momentarily unreachable (wrist down / companion suspended).
  if (device.status == 'NOT_REACHABLE' &&
      (provider == 'APPLE_WATCH' || provider == 'WEAR_OS') &&
      device.companionInstalled) {
    return true;
  }
  return false;
}

class WearableDispatchResult {
  const WearableDispatchResult({
    required this.sent,
    required this.provider,
    required this.message,
  });

  final bool sent;
  final String provider;
  final String message;
}

class WearableMatchDispatcher {
  const WearableMatchDispatcher(this.ref);

  final Ref ref;

  Future<WearableDispatchResult> startMatch({
    required String matchId,
    required MatchFormat format,
    TeamId? assignedTeam,
    String? teamName,
    String? teamImagePath,
    int teamImageVersion = 0,
    String teamScoringStyle = 'AUTO',
  }) async {
    final devices = await ref.read(connectedDeviceRepoProvider).all();
    final ready = devices.where(isScoringWearableReady).toList();
    final selected =
        ready.where((device) => device.isDefault).firstOrNull ??
        ready.firstOrNull;
    final provider = selected == null ? '' : wearableProviderFor(selected);

    try {
      switch (provider) {
        case 'GARMIN_CONNECT_IQ':
          return _startGarmin(
            selected!,
            matchId: matchId,
            format: format,
            assignedTeam: assignedTeam,
            events: _garminJournal(
              await ref.read(matchRepoProvider).eventsFor(matchId),
            ),
          );
        case 'FITBIT_OS':
          final service = ref.read(wearableProviderServiceProvider);
          final fitbitEvents = _fitbitJournal(
            await ref.read(matchRepoProvider).eventsFor(matchId),
          );
          // Mid-match handoff travels as RESUME_MATCH (journal included) so
          // the watch rebuilds the score; a fresh match keeps START_MATCH.
          final hasProgress =
              fitbitEvents != null &&
              fitbitEvents.any((event) => event['type'] != 'MATCH_STARTED');
          final queued = hasProgress
              ? await service.queueFitbitResumeMatch(
                  matchId: matchId,
                  format: format.toJson(),
                  assignedTeam: assignedTeam?.wire,
                  teamName: teamName,
                  events: fitbitEvents,
                )
              : await service.queueFitbitStartMatch(
                  matchId: matchId,
                  format: format.toJson(),
                  assignedTeam: assignedTeam?.wire,
                  teamName: teamName,
                );
          // Soft-lock on successful queue to close the dual-score window.
          // Sticky reclaim still lets the user take phone control; if Fitbit
          // never opens, reclaim or finish clears the lock.
          if (queued) {
            await ref
                .read(matchScoringLockProvider)
                .lock(matchId, 'FITBIT_OS');
          }
          return WearableDispatchResult(
            sent: queued,
            provider: provider,
            message: queued
                ? 'Partita pronta sul Fitbit. Punteggio sul watch per evitare '
                    'doppi punti; usa “Telefono” in live se vuoi segnare qui.'
                : 'Il Fitbit non ha confermato la coda partita.',
          );
        case 'GOOGLE_HEALTH':
          return const WearableDispatchResult(
            sent: false,
            provider: 'GOOGLE_HEALTH',
            message:
                'Questo wearable è solo salute e non dispone di uno schermo di scoring.',
          );
        case 'TIZEN_RETIRED':
          return const WearableDispatchResult(
            sent: false,
            provider: 'TIZEN_RETIRED',
            message: 'Le nuove app Tizen non sono più distribuibili.',
          );
        default:
          final entitlements = ref.read(entitlementsProvider);
          final auth = ref.read(cloudAuthProvider);
          final session = auth.profileLinked ? await freshCloudSession() : null;
          final assistantEnabled =
              entitlements.llmAssistant &&
              auth.profileLinked &&
              session != null &&
              CloudConfig.supabaseConfigured;
          final sent = await ref
              .read(watchSyncProvider.notifier)
              .sendMatchToWatch(
                matchId: matchId,
                format: format,
                duoTeam: assignedTeam,
                teamName: teamName,
                teamImagePath: teamImagePath,
                teamImageVersion: teamImageVersion,
                teamScoringStyle: teamScoringStyle,
                sourceUserId: ref.read(duoServiceProvider).userId,
                premiumEnabled: ref.read(entitlementsProvider).duoMode,
                assistantEnabled: assistantEnabled,
                assistantEndpoint: assistantEnabled
                    ? '${CloudConfig.functionsBase}/assistant'
                    : null,
                assistantAccessToken: assistantEnabled
                    ? session.accessToken
                    : null,
                assistantPublishableKey: assistantEnabled
                    ? CloudConfig.supabaseAnonKey
                    : null,
                assistantExpiresAtMs: assistantEnabled
                    ? (session.expiresAt ?? 0) * 1000
                    : null,
                teamNames: [if (teamName?.isNotEmpty == true) teamName!],
              );
          final live = ref.read(watchSyncProvider);
          return WearableDispatchResult(
            sent: sent,
            provider: provider.isEmpty ? 'NATIVE_WATCH' : provider,
            message: sent
                ? (live.reachable
                      ? 'Partita inviata al watch. Gli eventi arriveranno automaticamente.'
                      : 'Partita accodata al watch: si aprirà o si aggiornerà non appena raggiungibile.')
                : live.companionInstalled
                ? 'Watch non raggiungibile: la partita resta sul telefono e verrà ritentata.'
                : 'Companion non installata o watch non associato. Apri Gestione dispositivi.',
          );
      }
    } on WearableProviderException catch (error) {
      return WearableDispatchResult(
        sent: false,
        provider: provider,
        message: error.message,
      );
    }
  }

  Future<WearableDispatchResult> _startGarmin(
    ConnectedDevice selected, {
    required String matchId,
    required MatchFormat format,
    TeamId? assignedTeam,
    List<Map<String, Object?>>? events,
  }) async {
    final service = ref.read(wearableProviderServiceProvider);
    final devices = await service.garminDevices();
    final expectedId = selected.id.replaceFirst('watch_garmin_', '');
    // Never fall back to "any connected" Garmin — multi-device households
    // must target the registered device only.
    final device = devices
        .where((item) => item.deviceId == expectedId)
        .firstOrNull;
    if (device == null) {
      return const WearableDispatchResult(
        sent: false,
        provider: 'GARMIN_CONNECT_IQ',
        message:
            'Garmin registrato non raggiungibile. Riapri la configurazione o seleziona di nuovo il dispositivo corretto.',
      );
    }
    final registration = await service.registerGarminDevice(device.nativeId);
    if (registration['appInstalled'] != true) {
      await service.openGarminStore(device.nativeId);
      return const WearableDispatchResult(
        sent: false,
        provider: 'GARMIN_CONNECT_IQ',
        message: 'Installa prima Padelandia dal Connect IQ Store.',
      );
    }
    // Durable-ish start: retry with REQUEST_SYNC between attempts so a watch
    // with pending events can flush before accepting a new match.
    GarminStartMatchResult result = const GarminStartMatchResult(
      accepted: false,
      reason: 'transport_failed',
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await service.sendGarmin(device.nativeId, {'type': 'REQUEST_SYNC'});
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
      result = await service.startGarminMatch(
        nativeId: device.nativeId,
        matchId: matchId,
        format: format.toJson(),
        assignedTeam: assignedTeam?.wire,
        events: events,
      );
      if (result.accepted) break;
      if (result.reason != 'pending_match_not_synchronized' &&
          result.reason != 'timeout' &&
          result.reason != 'active_match_in_progress') {
        break;
      }
    }
    if (result.accepted) {
      await ref
          .read(matchScoringLockProvider)
          .lock(matchId, 'GARMIN_CONNECT_IQ');
    }
    final message = switch (result.reason) {
      _ when result.accepted =>
        'Partita inviata al Garmin. I tap sul telefono restano bloccati per evitare punti doppi.',
      'pending_match_not_synchronized' =>
        'Il Garmin ha una partita non ancora sincronizzata. Apri Padelandia sul watch, attendi la sync e riprova.',
      'active_match_in_progress' =>
        'C’è già una partita in corso sul Garmin. Completala o sincronizzala prima di inviarne un’altra.',
      'timeout' =>
        'Nessuna conferma dal Garmin. Apri Padelandia sul watch e riprova.',
      'transport_failed' =>
        'Garmin non raggiungibile. Apri Garmin Connect e Padelandia sul watch.',
      _ =>
        'Il Garmin non ha accettato la partita. Apri Padelandia sul watch e riprova.',
    };
    return WearableDispatchResult(
      sent: result.accepted,
      provider: 'GARMIN_CONNECT_IQ',
      message: message,
    );
  }

  /// Handles durable non-EVENT_BATCH payloads drained from the native Garmin
  /// queue. REQUEST_RESUME is answered with a complete START_MATCH carrying
  /// the phone journal, so the watch resumes the paused match mid-score.
  Future<void> handleGarminControlMessage(
    String nativeId,
    Map<String, Object?> payload,
  ) async {
    if (payload['type'] != 'REQUEST_RESUME' || nativeId.isEmpty) return;
    final matchId = payload['matchId']?.toString() ?? '';
    if (matchId.length < 8) return;
    final repo = ref.read(matchRepoProvider);
    final row = await repo.byId(matchId);
    if (row == null || !_resumableStatuses.contains(row.status)) {
      // The watch is waiting after an explicit tap: never leave it silent.
      await _rejectGarminResume(nativeId, matchId, 'not_resumable');
      return;
    }
    final events = _garminJournal(await repo.eventsFor(matchId));
    // SCORE_EDITED (or an oversize journal) cannot be replayed on the watch:
    // skip the handoff, the match stays resumable on the phone.
    if (events == null) {
      await _rejectGarminResume(nativeId, matchId, 'journal_unsupported');
      return;
    }
    final format = MatchFormat.fromJson(
      (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
    );
    final result = await ref
        .read(wearableProviderServiceProvider)
        .startGarminMatch(
          nativeId: nativeId,
          matchId: matchId,
          format: format.toJson(),
          assignedTeam: row.duoMode ? row.duoTeam : null,
          events: events,
        );
    if (result.accepted) {
      await ref
          .read(matchScoringLockProvider)
          .lock(matchId, 'GARMIN_CONNECT_IQ');
    } else {
      await _rejectGarminResume(nativeId, matchId, 'transport_failed');
    }
  }

  /// Tells the watch its resume request cannot be honoured, with a reason it
  /// can turn into a readable toast. Best effort: a Garmin that went away
  /// simply misses it and the match stays resumable on the phone.
  Future<void> _rejectGarminResume(
    String nativeId,
    String matchId,
    String reason,
  ) async {
    try {
      await ref.read(wearableProviderServiceProvider).sendGarmin(nativeId, {
        'type': 'RESUME_REJECTED',
        'matchId': matchId,
        'reason': reason,
      });
    } on WearableProviderException {
      // Nothing else to do: the phone remains the place to resume.
    }
  }

  /// Maps the phone journal to the Garmin Monkey C event shape.
  /// Returns null when the journal cannot be replayed on the watch
  /// (SCORE_EDITED present or too many events for watch storage).
  List<Map<String, Object?>>? _garminJournal(List<MatchEvent> journal) {
    if (journal.any((event) => event.type == MatchEventType.scoreEdited)) {
      return null;
    }
    final supported = journal
        .where((event) => _wearableJournalTypes.contains(event.type))
        .toList(growable: false);
    // Watch storage caps at RM_MAX_EVENTS (500) minus headroom.
    if (supported.length > 400) return null;
    return [
      for (var i = 0; i < supported.length; i++)
        {
          'id': supported[i].eventId,
          'type': supported[i].type.wire,
          'sourceMethod': supported[i].sourceMethod.wire,
          'target': supported[i].payload?['targetEventId']?.toString(),
          if (supported[i].teamId != null)
            'teamId': supported[i].teamId!.wire,
          'sequence': i + 1,
          'timestampMs': supported[i].timestampMs,
        },
    ];
  }

  /// Maps the phone journal to the Fitbit wire event shape.
  /// Returns null when the journal cannot be replayed on the watch
  /// (SCORE_EDITED present or over the gateway 250-event cap).
  List<Map<String, Object?>>? _fitbitJournal(List<MatchEvent> journal) {
    if (journal.any((event) => event.type == MatchEventType.scoreEdited)) {
      return null;
    }
    final supported = journal
        .where((event) => _wearableJournalTypes.contains(event.type))
        .toList(growable: false);
    if (supported.length > 250) return null;
    return [
      for (var i = 0; i < supported.length; i++)
        {
          'eventId': supported[i].eventId,
          'type': supported[i].type.wire,
          if (_fitbitTeamFor(supported[i]) != null)
            'teamId': _fitbitTeamFor(supported[i]),
          'timestampMs': supported[i].timestampMs,
          'sequence': i + 1,
          'sourceMethod': supported[i].sourceMethod.wire,
          if ((supported[i].payload?['targetEventId']?.toString() ?? '')
              .isNotEmpty)
            'targetEventId': supported[i].payload!['targetEventId'].toString(),
        },
    ];
  }

  /// Fitbit requires an explicit team on POINT_* events.
  String? _fitbitTeamFor(MatchEvent event) => switch (event.type) {
    MatchEventType.pointTeamA => TeamId.a.wire,
    MatchEventType.pointTeamB => TeamId.b.wire,
    _ => event.teamId?.wire,
  };
}

final wearableMatchDispatcherProvider = Provider<WearableMatchDispatcher>(
  WearableMatchDispatcher.new,
);
