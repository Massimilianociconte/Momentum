library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cloud/cloud_service.dart';

class WearableProviderException implements Exception {
  const WearableProviderException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Enforces the durable Garmin acknowledgement order.
///
/// Local phone journal is authoritative (same as Apple Watch / Wear OS): a
/// batch may leave the native queue only after the local match journal has
/// committed it and the ACK parcel reached the watch. Cloud ingest is
/// best-effort after local durability so court play still works offline.
class GarminQueueCommitBarrier {
  const GarminQueueCommitBarrier._();

  static Future<bool> commit({
    required Future<void> Function() commitToPhone,
    Future<void> Function()? ingestBackend,
    required Future<bool> Function() acknowledgeWatch,
    required Future<void> Function() removeNativeQueueEntry,
  }) async {
    await commitToPhone();
    if (ingestBackend != null) {
      try {
        await ingestBackend();
      } catch (_) {
        // Cloud is secondary: do not block watch ACK on network/plan failures.
      }
    }
    if (!await acknowledgeWatch()) return false;
    await removeNativeQueueEntry();
    return true;
  }
}

/// Result of waiting for a Garmin application-level START_MATCH response.
class GarminStartMatchResult {
  const GarminStartMatchResult({required this.accepted, this.reason});

  final bool accepted;
  final String? reason;
}

/// Live Fitbit pairing state from `my_wearable_connections`.
class FitbitConnectionInfo {
  const FitbitConnectionInfo({
    required this.status,
    required this.activeDevices,
  });

  final String status;
  final int activeDevices;

  /// Server row is CONNECTED and at least one non-expired device token exists.
  bool get isPairedLive => status == 'CONNECTED' && activeDevices > 0;
}

class GarminDeviceInfo {
  const GarminDeviceInfo({
    required this.nativeId,
    required this.deviceId,
    required this.name,
    required this.status,
    required this.appRegistered,
    this.model = '',
  });

  final String nativeId;
  final String deviceId;
  final String name;
  final String model;
  final String status;
  final bool appRegistered;
  bool get connected => status == 'CONNECTED';

  factory GarminDeviceInfo.fromMap(Map<Object?, Object?> value) =>
      GarminDeviceInfo(
        nativeId: value['nativeId']?.toString() ?? '',
        deviceId: value['deviceId']?.toString() ?? '',
        name: value['name']?.toString() ?? 'Garmin',
        model: value['model']?.toString() ?? '',
        status: value['status']?.toString() ?? 'UNKNOWN',
        appRegistered: value['appRegistered'] == true,
      );
}

class FitbitPairingCode {
  const FitbitPairingCode({
    required this.code,
    required this.displayCode,
    required this.expiresAt,
  });

  final String code;
  final String displayCode;
  final DateTime expiresAt;
}

class GoogleHealthStatus {
  const GoogleHealthStatus({
    required this.connected,
    required this.status,
    required this.needsReconnect,
    this.lastSyncAt,
  });

  final bool connected;
  final String status;
  final bool needsReconnect;
  final DateTime? lastSyncAt;
}

class GoogleHealthToday {
  const GoogleHealthToday({
    required this.steps,
    required this.activeEnergyKcal,
    required this.exerciseMinutes,
    this.averageHeartRateBpm,
  });

  final int steps;
  final double activeEnergyKcal;
  final int exerciseMinutes;
  final double? averageHeartRateBpm;
}

class DirectHealthProviderStatus {
  const DirectHealthProviderStatus({
    required this.providerId,
    required this.available,
    required this.connected,
    required this.status,
    required this.needsReconnect,
    required this.rollout,
    this.lastSyncAt,
  });

  final String providerId;
  final bool available;
  final bool connected;
  final String status;
  final bool needsReconnect;
  final String rollout;
  final DateTime? lastSyncAt;
}

class DirectHealthSyncResult {
  const DirectHealthSyncResult({required this.imported, this.sourceId});

  final int imported;
  final String? sourceId;
}

class WearableProviderService {
  WearableProviderService() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const _channel = MethodChannel('com.rallymate/provider_wearables');
  final _nativeEvents = StreamController<MethodCall>.broadcast();

  Stream<MethodCall> get nativeEvents => _nativeEvents.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    _nativeEvents.add(call);
    return null;
  }

  Future<Map<String, Object?>> garminStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'garminInitialize',
    );
    return _stringMap(raw);
  }

  Future<List<GarminDeviceInfo>> garminDevices() async {
    final raw = await _channel.invokeListMethod<Object?>('garminDevices');
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(GarminDeviceInfo.fromMap)
        .toList(growable: false);
  }

  Future<void> selectGarminDevices() async {
    try {
      await _channel.invokeMethod<bool>('garminSelectDevices');
    } on MissingPluginException {
      // Android exposes Garmin Connect's known devices directly; iOS opens
      // Garmin Connect so the user explicitly shares selected devices.
    }
  }

  Future<Map<String, Object?>> registerGarminDevice(String nativeId) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'garminRegisterDevice',
      {'nativeId': nativeId},
    );
    return _stringMap(value);
  }

  Future<bool> openGarminStore(String? nativeId) async {
    return await _channel.invokeMethod<bool>('garminOpenStore', {
          'nativeId': ?nativeId,
        }) ??
        false;
  }

  Future<bool> openGarminCompanionStore() async {
    return await _channel.invokeMethod<bool>('garminOpenCompanionStore') ??
        false;
  }

  Future<bool> sendGarmin(String nativeId, Map<String, Object?> payload) async {
    return await _channel.invokeMethod<bool>('garminSend', {
          'nativeId': nativeId,
          'payload': payload,
        }) ??
        false;
  }

  Future<bool> testGarmin(String nativeId, {bool point = false}) async {
    final expected = point ? 'TEST_POINT_ACK' : 'PONG';
    final completer = Completer<bool>();
    late StreamSubscription<MethodCall> subscription;
    subscription = nativeEvents.listen((call) {
      if (call.method != 'garminMessage') return;
      final entry = _stringMap(call.arguments as Map?);
      final payload = _stringMap(entry['payload'] as Map?);
      if (payload['type'] == expected && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    final sent = await sendGarmin(nativeId, {
      'type': point ? 'TEST_POINT' : 'PING',
    });
    if (!sent) {
      await subscription.cancel();
      return false;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return false;
    } finally {
      await subscription.cancel();
    }
  }

  /// Waits for application-level START_MATCH_ACK / START_MATCH_REJECTED.
  /// Transport SUCCESS alone is not enough (watch may reject unsynced journals).
  /// [events] optionally carries the full phone journal so a paused match
  /// resumes on the watch mid-score.
  Future<GarminStartMatchResult> startGarminMatch({
    required String nativeId,
    required String matchId,
    required Map<String, Object?> format,
    String? assignedTeam,
    List<Map<String, Object?>>? events,
  }) async {
    final completer = Completer<GarminStartMatchResult>();
    late StreamSubscription<MethodCall> subscription;
    subscription = nativeEvents.listen((call) {
      if (call.method != 'garminMessage') return;
      final entry = _stringMap(call.arguments as Map?);
      final payload = _stringMap(entry['payload'] as Map?);
      final type = payload['type']?.toString();
      final responseMatchId = payload['matchId']?.toString();
      if (responseMatchId != null &&
          responseMatchId.isNotEmpty &&
          responseMatchId != matchId) {
        return;
      }
      if (type == 'START_MATCH_ACK' && !completer.isCompleted) {
        completer.complete(const GarminStartMatchResult(accepted: true));
      } else if (type == 'START_MATCH_REJECTED' && !completer.isCompleted) {
        completer.complete(
          GarminStartMatchResult(
            accepted: false,
            reason: payload['reason']?.toString(),
          ),
        );
      }
    });
    final sent = await sendGarmin(nativeId, {
      'type': 'START_MATCH',
      'matchId': matchId,
      'format': format,
      'assignedTeam': ?assignedTeam,
      if (events != null && events.isNotEmpty) 'events': events,
    });
    if (!sent) {
      await subscription.cancel();
      return const GarminStartMatchResult(
        accepted: false,
        reason: 'transport_failed',
      );
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return const GarminStartMatchResult(accepted: false, reason: 'timeout');
    } finally {
      await subscription.cancel();
    }
  }

  /// Relays journal batches after they have been stored on the phone.
  /// Native queue entries leave only after local journal commit + watch ACK.
  /// [commitEventsToPhone] must merge the given flattened events into the local
  /// match journal (not only drain the cloud inbox).
  /// [onControlMessage] observes non-EVENT_BATCH payloads (e.g. REQUEST_RESUME)
  /// before the durable queue entry is acknowledged, so control requests
  /// survive even when Flutter was down when the watch sent them.
  Future<int> syncGarminQueue({
    required Future<void> Function(List<Map<String, Object?>> events)
    commitEventsToPhone,
    Future<void> Function(String nativeId, Map<String, Object?> payload)?
    onControlMessage,
  }) async {
    final raw = await _channel.invokeListMethod<Object?>('garminDrainMessages');
    final queue = (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(_stringMap)
        .toList(growable: false);
    var synced = 0;
    for (final entry in queue) {
      final queueId = entry['queueId']?.toString() ?? '';
      final nativeId = entry['nativeId']?.toString() ?? '';
      final payload = _stringMap(entry['payload'] as Map?);
      if (queueId.isEmpty) continue;
      // Control messages (PONG, START_MATCH_ACK, REQUEST_RESUME, …) are not
      // score events: surface them to the handler, then drop them from the
      // durable queue. ACK even on handler failure so a poison message can
      // never wedge the queue — the user can simply re-request from the watch.
      if (payload['type'] != 'EVENT_BATCH') {
        if (onControlMessage != null) {
          try {
            await onControlMessage(nativeId, payload);
          } catch (_) {
            // Best-effort: resume requests are user-retryable.
          }
        }
        await _ackNativeQueue([queueId]);
        continue;
      }
      final events = ((payload['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((event) => _flattenGarminEvent(_stringMap(event)))
          .where((event) => event.isNotEmpty)
          .toList(growable: false);
      if (events.isEmpty) {
        await _ackNativeQueue([queueId]);
        continue;
      }
      final eventIds = events
          .map((event) => event['eventId'] as String)
          .toList(growable: false);
      // Per-entry error isolation: a failure on one batch (e.g. commitToPhone
      // throws, or ACK times out) must not block subsequent batches.
      try {
        final committed = await GarminQueueCommitBarrier.commit(
          commitToPhone: () => commitEventsToPhone(events),
          ingestBackend: () async {
            await _invoke('wearable-gateway', {
              'action': 'ingest_mobile',
              'provider': 'GARMIN_CONNECT_IQ',
              'events': events,
            });
          },
          acknowledgeWatch: () => nativeId.isNotEmpty
              ? sendGarmin(nativeId, {'type': 'ACK', 'eventIds': eventIds})
              : Future.value(false),
          removeNativeQueueEntry: () => _ackNativeQueue([queueId]),
        );
        if (committed) {
          synced += events.length;
        }
      } catch (_) {
        // Head-of-line isolation: skip this entry, continue with the rest.
        // The native queue entry is preserved for the next sync cycle.
      }
    }
    return synced;
  }

  Future<FitbitPairingCode> createFitbitPairing() async {
    final data = await _invoke('wearable-gateway', {
      'action': 'create_pairing',
      'provider': 'FITBIT_OS',
    });
    return FitbitPairingCode(
      code: data['code']?.toString() ?? '',
      displayCode: data['displayCode']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(data['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  Future<String> fitbitConnectionStatus() async {
    final info = await fitbitConnectionInfo();
    return info.status;
  }

  Future<FitbitConnectionInfo> fitbitConnectionInfo() async {
    final client = await _requiredClient();
    final result = await client.rpc('my_wearable_connections');
    for (final row in (result as List? ?? const []).whereType<Map>()) {
      if (row['provider'] == 'FITBIT_OS') {
        return FitbitConnectionInfo(
          status: row['status']?.toString() ?? 'DISCONNECTED',
          activeDevices: (row['active_devices'] as num?)?.toInt() ?? 0,
        );
      }
    }
    return const FitbitConnectionInfo(status: 'DISCONNECTED', activeDevices: 0);
  }

  /// Non-destructive Fitbit setup probe: reads the cloud inbox without ACK.
  /// Returns true when at least one fresh POINT_* (or any FITBIT_OS event when
  /// [requirePoint] is false) is waiting after [notBefore].
  Future<bool> probeFitbitInbox({
    DateTime? notBefore,
    bool requirePoint = true,
  }) async {
    final raw = await drainCloudEvents();
    final cutoff = notBefore?.millisecondsSinceEpoch;
    for (final value in raw) {
      if (value['provider']?.toString() != 'FITBIT_OS') continue;
      final eventType = value['event_type']?.toString() ?? '';
      if (requirePoint &&
          eventType != 'POINT_TEAM_A' &&
          eventType != 'POINT_TEAM_B') {
        continue;
      }
      final eventAt = DateTime.tryParse(value['event_at']?.toString() ?? '');
      if (cutoff != null &&
          eventAt != null &&
          eventAt.millisecondsSinceEpoch < cutoff) {
        continue;
      }
      return true;
    }
    return false;
  }

  Future<List<Map<String, Object?>>> drainCloudEvents() async {
    final data = await _invoke('wearable-gateway', {'action': 'drain'});
    return ((data['events'] as List?) ?? const [])
        .whereType<Map>()
        .map(_stringMap)
        .toList(growable: false);
  }

  Future<void> acknowledgeCloudEvents(Iterable<int> ingestIds) async {
    final ids = ingestIds.toSet().take(100).toList(growable: false);
    if (ids.isEmpty) return;
    await _invoke('wearable-gateway', {
      'action': 'acknowledge',
      'ingestIds': ids,
    });
  }

  Future<bool> queueFitbitStartMatch({
    required String matchId,
    required Map<String, Object?> format,
    String? assignedTeam,
    String? teamName,
  }) async {
    final data = await _invoke('wearable-gateway', {
      'action': 'enqueue_command',
      'provider': 'FITBIT_OS',
      'commandType': 'START_MATCH',
      'payload': {
        'matchId': matchId,
        'format': format,
        'assignedTeam': ?assignedTeam,
        if (teamName?.isNotEmpty == true) 'teamName': teamName,
      },
    });
    return data['queued'] == true;
  }

  /// Queues a RESUME_MATCH command carrying the full phone journal so the
  /// Fitbit app rebuilds the paused match mid-score. The phone never talks to
  /// the watch directly: delivery happens via wearable-gateway + companion.
  Future<bool> queueFitbitResumeMatch({
    required String matchId,
    required Map<String, Object?> format,
    required List<Map<String, Object?>> events,
    String? assignedTeam,
    String? teamName,
  }) async {
    final data = await _invoke('wearable-gateway', {
      'action': 'enqueue_command',
      'provider': 'FITBIT_OS',
      'commandType': 'RESUME_MATCH',
      'payload': {
        'matchId': matchId,
        'format': format,
        'assignedTeam': ?assignedTeam,
        if (teamName?.isNotEmpty == true) 'teamName': teamName,
        'events': events,
      },
    });
    return data['queued'] == true;
  }

  Future<GoogleHealthStatus> googleHealthStatus() async {
    final data = await _invoke('google-health', {'action': 'status'});
    return GoogleHealthStatus(
      connected: data['connected'] == true,
      status: data['status']?.toString() ?? 'DISCONNECTED',
      needsReconnect: data['needsReconnect'] == true,
      lastSyncAt: DateTime.tryParse(data['lastSyncAt']?.toString() ?? ''),
    );
  }

  Future<void> authorizeGoogleHealth() async {
    final data = await _invoke('google-health', {'action': 'authorize'});
    final uri = Uri.tryParse(data['authorizationUrl']?.toString() ?? '');
    if (uri == null || !uri.isScheme('https')) {
      throw const WearableProviderException(
        'Il server non ha restituito un collegamento Google valido.',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const WearableProviderException(
        'Impossibile aprire il consenso Google Health.',
      );
    }
  }

  Future<GoogleHealthToday> syncGoogleHealthToday() async {
    final now = DateTime.now();
    final timezone =
        await _channel.invokeMethod<String>('providerLocalTimeZone') ??
        now.timeZoneName;
    final data = await _invoke('google-health', {
      'action': 'today',
      'localDate': DateFormat('yyyy-MM-dd').format(now),
      'timezone': timezone,
    });
    final summary = _stringMap(data['summary'] as Map?);
    return GoogleHealthToday(
      steps: (summary['steps'] as num?)?.toInt() ?? 0,
      activeEnergyKcal:
          (summary['active_energy_kcal'] as num?)?.toDouble() ?? 0,
      exerciseMinutes: (summary['exercise_minutes'] as num?)?.toInt() ?? 0,
      averageHeartRateBpm: (summary['average_heart_rate_bpm'] as num?)
          ?.toDouble(),
    );
  }

  Future<DirectHealthProviderStatus> directHealthStatus(String provider) async {
    final data = await _invoke('health-provider', {
      'action': 'status',
      'provider': provider,
    });
    return DirectHealthProviderStatus(
      providerId: provider,
      available: data['available'] == true,
      connected: data['connected'] == true,
      status: data['status']?.toString() ?? 'DISCONNECTED',
      needsReconnect: data['needsReconnect'] == true,
      rollout: data['rollout']?.toString() ?? 'DISABLED',
      lastSyncAt: DateTime.tryParse(data['lastSyncAt']?.toString() ?? ''),
    );
  }

  Future<void> authorizeDirectHealth(String provider) async {
    final data = await _invoke('health-provider', {
      'action': 'authorize',
      'provider': provider,
    });
    final uri = Uri.tryParse(data['authorizationUrl']?.toString() ?? '');
    if (uri == null || !uri.isScheme('https')) {
      throw const WearableProviderException(
        'Il server non ha restituito un collegamento sicuro.',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const WearableProviderException(
        'Impossibile aprire il consenso del provider.',
      );
    }
  }

  Future<DirectHealthSyncResult> syncDirectHealth(
    String provider, {
    DateTime? start,
    DateTime? end,
  }) async {
    final data = await _invoke('health-provider', {
      'action': 'sync',
      'provider': provider,
      if (start != null) 'startDate': start.toUtc().toIso8601String(),
      if (end != null) 'endDate': end.toUtc().toIso8601String(),
    });
    final result = _stringMap(data['result'] as Map?);
    return DirectHealthSyncResult(
      imported: (result['imported'] as num?)?.toInt() ?? 0,
      sourceId: result['sourceId']?.toString(),
    );
  }

  Future<void> disconnect(String provider) async {
    if (provider == 'GOOGLE_HEALTH') {
      await _invoke('google-health', {'action': 'disconnect'});
      return;
    }
    if (provider == 'OURA_DIRECT' || provider == 'WHOOP_DIRECT') {
      await _invoke('health-provider', {
        'action': 'disconnect',
        'provider': provider,
      });
      return;
    }
    await _invoke('wearable-gateway', {
      'action': 'disconnect',
      'provider': provider,
    });
  }

  Map<String, Object?> _flattenGarminEvent(Map<String, Object?> value) {
    final payload = _stringMap(value['payload'] as Map?);
    final eventId = value['eventId']?.toString() ?? '';
    final matchId = value['matchId']?.toString() ?? '';
    final eventType = value['eventType']?.toString() ?? '';
    final timestamp = value['timestampMs'];
    if (eventId.length < 8 || matchId.length < 3 || timestamp is! num) {
      return const {};
    }
    final rawFormat = payload['format'];
    final format = rawFormat is Map
        ? jsonEncode(
            rawFormat.map((key, value) => MapEntry(key.toString(), value)),
          )
        : rawFormat?.toString();
    final teamId = switch (eventType) {
      'POINT_TEAM_A' => 'TEAM_A',
      'POINT_TEAM_B' => 'TEAM_B',
      'UNDO' => payload['teamId']?.toString(),
      _ => payload['teamId']?.toString(),
    };
    return {
      'eventId': eventId,
      'matchId': matchId,
      'type': eventType,
      'timestampMs': timestamp.toInt(),
      'sourceMethod': payload['sourceMethod']?.toString() ?? 'TAP',
      if (teamId != null && teamId.isNotEmpty) 'teamId': teamId,
      if (format?.isNotEmpty == true) 'format': format,
      if (payload['sequence'] is num)
        'sequence': (payload['sequence'] as num).toInt(),
      if ((payload['targetEventId']?.toString() ?? '').isNotEmpty)
        'targetEventId': payload['targetEventId'].toString(),
    };
  }

  Future<void> _ackNativeQueue(List<String> ids) async {
    await _channel.invokeMethod<bool>('garminAcknowledgeMessages', {
      'queueIds': ids,
    });
  }

  Future<Map<String, Object?>> _invoke(
    String function,
    Map<String, Object?> body,
  ) async {
    final client = await _requiredClient();
    try {
      final response = await client.functions
          .invoke(function, body: body)
          .timeout(const Duration(seconds: 15));
      return _stringMap(response.data as Map?);
    } on FunctionException catch (error) {
      final details = error.details;
      final map = details is Map
          ? _stringMap(details)
          : const <String, Object?>{};
      final code = map['error']?.toString();
      throw WearableProviderException(switch (code) {
        'plan_required' => 'Questa integrazione richiede il piano indicato.',
        'rate_limited' => 'Troppi tentativi. Attendi qualche minuto.',
        'server_not_configured' =>
          'Il provider non è ancora configurato sul server Padelandia.',
        'reconnect_required' =>
          'Ricollega il provider e concedi di nuovo i permessi.',
        'provider_not_available' =>
          'Questa integrazione è ancora in verifica e non è attiva.',
        'sync_too_frequent' =>
          'I dati sono già aggiornati. Attendi un minuto prima di riprovare.',
        _ => 'Collegamento temporaneamente non disponibile.',
      }, code: code);
    } on TimeoutException {
      throw const WearableProviderException(
        'Rete lenta o assente. I dati locali restano al sicuro: riprova più tardi.',
      );
    }
  }

  Future<SupabaseClient> _requiredClient() async {
    await initCloud();
    final client = cloudClient;
    if (client == null) {
      throw const WearableProviderException(
        'Servizi online non disponibili. Riprova più tardi.',
      );
    }
    if (client.auth.currentSession == null) {
      throw const WearableProviderException(
        'Accedi al tuo account Padelandia prima di collegare il wearable.',
      );
    }
    return client;
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _nativeEvents.close();
  }
}

Map<String, Object?> _stringMap(Map? value) =>
    (value ?? const {}).map((key, value) => MapEntry(key.toString(), value));

final wearableProviderServiceProvider = Provider<WearableProviderService>((
  ref,
) {
  final service = WearableProviderService();
  ref.onDispose(service.dispose);
  return service;
});
