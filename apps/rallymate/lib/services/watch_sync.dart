/// Watch ⇄ phone sync bridge (PRD 9.2 + acceptance: partita recuperabile
/// se watch e telefono perdono connessione).
///
/// Protocollo (stesso JSON su entrambe le piattaforme):
///  - phone → watch  `startMatch`  {matchId, format, teamLabels}
///  - watch → phone  `events`      {matchId, events: [MatchEvent JSON...]}
///  - watch → phone  `requestState`{matchId}  → phone risponde con l'event log
///
/// Trasporti nativi:
///  - iOS:    WatchConnectivity (WCSession, transferUserInfo per affidabilità)
///  - Android: Wearable Data Layer API (MessageClient + DataClient)
///
/// Il canale è idempotente: gli eventi hanno eventId univoci e
/// MatchRepository.appendEvents usa insertOrIgnore, quindi un re-sync
/// completo non duplica mai nulla.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../data/db/database.dart';
import '../features/live/live_match_controller.dart';
import 'wearable_provider_service.dart';

class WatchSyncState {
  const WatchSyncState({
    this.supported = false,
    this.paired = false,
    this.companionInstalled = false,
    this.reachable = false,
    this.connected = false,
    this.permissionsComplete = true,
    this.platformLabel = '',
    this.deviceName = '',
    this.status = 'CHECKING',
    this.capabilities = const [],
    this.scoringProtocolVersion = 0,
    this.scoringCapabilityProbed = false,
  });

  final bool supported;
  final bool paired;
  final bool companionInstalled;
  final bool reachable;
  final bool connected;
  final bool permissionsComplete;
  final String platformLabel;
  final String deviceName;
  final String status;
  final List<String> capabilities;
  final int scoringProtocolVersion;
  final bool scoringCapabilityProbed;

  /// Companion can receive durable match payloads (installed + paired).
  /// Real-time messaging still requires [reachable].
  bool get ready => connected && companionInstalled;

  factory WatchSyncState.fromMap(Map<String, Object?> value) => WatchSyncState(
    supported: value['supported'] as bool? ?? true,
    paired: value['paired'] as bool? ?? false,
    companionInstalled: value['companionInstalled'] as bool? ?? false,
    reachable: value['reachable'] as bool? ?? false,
    connected: value['connected'] as bool? ?? false,
    permissionsComplete: value['permissionsComplete'] as bool? ?? true,
    platformLabel: value['platform'] as String? ?? '',
    deviceName: value['deviceName'] as String? ?? '',
    status: value['status'] as String? ?? 'NOT_REACHABLE',
    capabilities: ((value['capabilities'] as List?) ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    scoringProtocolVersion:
        (value['scoringProtocolVersion'] as num?)?.toInt() ?? 0,
    scoringCapabilityProbed: value['scoringCapabilityProbed'] == true,
  );
}

class WatchSyncService extends Notifier<WatchSyncState> {
  static const _channel = MethodChannel('com.rallymate/watch');
  static const _nativeTimeout = Duration(seconds: 10);
  static const _phoneAuthorityVersionStorageKey =
      'watch_sync_phone_authority_version_v1';
  static const _maxPhoneAuthorityVersion = 0x7FFFFFFFFFFFFFFF;

  /// Runtime-only proof produced by a successful native `refreshStatus`.
  ///
  /// This deliberately does not come from the persisted diagnostics row:
  /// the phone and companion can be updated independently, so an old v2 row
  /// must never authorize a Star Point payload after a probe failure.
  bool _starPointCapabilityFreshlyProven = false;

  /// A successful explicit probe grants one immediate Star Point dispatch.
  ///
  /// [WearableMatchDispatcher] probes before choosing the target. Consuming
  /// this permit in [sendMatchToWatch] avoids a second Apple Watch round trip,
  /// while direct callers still have to perform their own fresh probe.
  bool _starPointDispatchPermit = false;

  /// Keeps startup refreshes and explicit authorization probes in FIFO order.
  /// Without this queue, a slower stale startup response could overwrite a
  /// later failed explicit probe and accidentally re-authorize Star Point.
  Future<void> _nativeProbeTail = Future<void>.value();
  Future<void> _resumablePublishTail = Future<void>.value();
  Future<void> _authorityVersionTail = Future<void>.value();

  /// Monotonic phone-side generation for authoritative resumable snapshots.
  ///
  /// A reconnect can redeliver an older Data Item/application context after a
  /// newer clear. The watch rejects that stale generation instead of
  /// resurrecting a removed Star Point match.
  int _lastPhoneAuthorityVersion = 0;
  SharedPreferences? _authorityVersionPreferences;
  bool _authorityVersionInitialized = false;
  bool _authorityVersionStorageFailedClosed = false;

  /// Atomically reserves and persists the next phone authority generation.
  ///
  /// Lifecycle messages and resumable snapshots intentionally share this
  /// allocator. Persisting the high-water mark before returning means a
  /// process relaunch or a wall-clock rollback cannot reuse an emitted value.
  /// An unreadable/corrupt value or a failed write is not recoverable safely
  /// in-process: publishing a guessed generation could resurrect stale state,
  /// so every later allocation remains fail-closed for this service instance.
  Future<int?> _nextPhoneAuthorityVersion() {
    final completer = Completer<int?>();
    _authorityVersionTail = _authorityVersionTail.then((_) async {
      if (_authorityVersionStorageFailedClosed) {
        completer.complete(null);
        return;
      }
      try {
        final preferences = _authorityVersionPreferences ??=
            await SharedPreferences.getInstance();
        if (!_authorityVersionInitialized) {
          final stored = preferences.get(_phoneAuthorityVersionStorageKey);
          if (stored != null &&
              (stored is! int ||
                  stored <= 0 ||
                  stored >= _maxPhoneAuthorityVersion)) {
            _authorityVersionStorageFailedClosed = true;
            completer.complete(null);
            return;
          }
          _lastPhoneAuthorityVersion = stored as int? ?? 0;
          _authorityVersionInitialized = true;
        }

        final wallClock = DateTime.now().microsecondsSinceEpoch;
        final base = wallClock > _lastPhoneAuthorityVersion
            ? wallClock
            : _lastPhoneAuthorityVersion;
        if (base <= 0 || base >= _maxPhoneAuthorityVersion - 1) {
          _authorityVersionStorageFailedClosed = true;
          completer.complete(null);
          return;
        }
        final next = base + 1;

        // Advance the in-memory high-water even if the platform reports an
        // ambiguous failed write, so this process can never reuse [next].
        _lastPhoneAuthorityVersion = next;
        final persisted = await preferences.setInt(
          _phoneAuthorityVersionStorageKey,
          next,
        );
        if (!persisted) {
          _authorityVersionStorageFailedClosed = true;
          completer.complete(null);
          return;
        }
        completer.complete(next);
      } catch (_) {
        _authorityVersionStorageFailedClosed = true;
        completer.complete(null);
      }
    });
    return completer.future;
  }

  @override
  WatchSyncState build() {
    _channel.setMethodCallHandler(_onNativeCall);
    unawaited(refresh());
    _drainQueuedEvents();
    // The wearable must find its resumable matches even if the phone was
    // restarted between the pause and the next session on court.
    unawaited(publishResumableMatches());
    return const WatchSyncState();
  }

  Future<T> _serializeNativeProbe<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _nativeProbeTail = _nativeProbeTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<WatchSyncState> refresh() => _serializeNativeProbe(_refreshNow);

  Future<WatchSyncState> _refreshNow() async {
    final next = await _freshNativeStatus();
    if (next == null) {
      _revokeStarPointCapabilityProof();
      return state;
    }
    try {
      await _applyStatus(next, freshNativeProbe: true);
    } catch (_) {
      _revokeStarPointCapabilityProof();
    }
    return state;
  }

  /// Proves that the companion currently speaks the Star Point v2 protocol.
  ///
  /// The method always invokes the native bridge. A cached Riverpod/Drift
  /// capability is never accepted as authority, and every transport failure
  /// revokes the previous proof.
  Future<bool> proveStarPointCapability() =>
      _serializeNativeProbe(_proveStarPointCapabilityNow);

  Future<bool> _proveStarPointCapabilityNow() async {
    _starPointDispatchPermit = false;
    final next = await _freshNativeStatus();
    if (next == null) {
      _revokeStarPointCapabilityProof();
      return false;
    }
    try {
      await _applyStatus(next, freshNativeProbe: true);
    } catch (_) {
      _revokeStarPointCapabilityProof();
      return false;
    }
    final supported = _supportsStarPoint(next);
    _starPointDispatchPermit = supported;
    return supported;
  }

  Future<WatchSyncState?> _freshNativeStatus() async {
    try {
      final res = await _channel
          .invokeMapMethod<String, Object?>('refreshStatus')
          .timeout(_nativeTimeout);
      if (res == null) return null;
      return WatchSyncState.fromMap(res);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on TimeoutException {
      return null;
    } on TypeError {
      // Malformed native capability payloads fail closed.
      return null;
    }
  }

  bool _supportsStarPoint(WatchSyncState value) =>
      value.scoringCapabilityProbed &&
      value.scoringProtocolVersion >= 2 &&
      value.capabilities.contains('star_point_v1');

  bool _supportsDecidingSet(WatchSyncState value) =>
      value.scoringCapabilityProbed &&
      value.capabilities.contains('deciding_set_no_tiebreak_v1');

  /// Proves that the companion can score a deciding set without tie-break
  /// (format schema v3).
  ///
  /// Unlike the Star Point path this keeps no permit: every dispatch probes
  /// the bridge again, which is strictly more conservative. A companion that
  /// does not advertise the token would silently play a tie-break at 6-6 and
  /// diverge from the phone.
  Future<bool> proveDecidingSetCapability() =>
      _serializeNativeProbe(_proveDecidingSetCapabilityNow);

  Future<bool> _proveDecidingSetCapabilityNow() async {
    final next = await _freshNativeStatus();
    if (next == null) return false;
    try {
      await _applyStatus(next, freshNativeProbe: true);
    } catch (_) {
      return false;
    }
    return _supportsDecidingSet(next);
  }

  bool _sameCapabilities(List<String> left, List<String> right) {
    final leftSet = left.toSet();
    final rightSet = right.toSet();
    return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
  }

  void _revokeStarPointCapabilityProof() {
    final changed =
        _starPointCapabilityFreshlyProven || _starPointDispatchPermit;
    _starPointCapabilityFreshlyProven = false;
    _starPointDispatchPermit = false;
    if (changed) {
      // Re-publish immediately without Star Point rows. This is one-way and
      // never calls refreshStatus, so it cannot form a probe/snapshot loop.
      unawaited(publishResumableMatches());
    }
  }

  Future<bool> _authorizeStarPointDispatch() async {
    if (_starPointDispatchPermit) {
      _starPointDispatchPermit = false;
      return _starPointCapabilityFreshlyProven;
    }
    final supported = await proveStarPointCapability();
    // Consume the permit created by this probe; it cannot authorize a later
    // unrelated transfer.
    _starPointDispatchPermit = false;
    return supported;
  }

  Future<bool> testConnection({bool point = false}) async {
    try {
      final ok =
          await _channel
              .invokeMethod<bool>(point ? 'testPoint' : 'testConnection')
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
      if (ok) {
        await refresh();
        final id = _deviceId(state.platformLabel);
        if (id != null) {
          await ref.read(connectedDeviceRepoProvider).markSynced(id);
        }
      }
      return ok;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _applyStatus(
    WatchSyncState next, {
    bool freshNativeProbe = false,
  }) async {
    final previous = state;
    final previousStarPointProof = _starPointCapabilityFreshlyProven;
    if (freshNativeProbe) {
      _starPointCapabilityFreshlyProven = _supportsStarPoint(next);
      if (!_starPointCapabilityFreshlyProven) {
        _starPointDispatchPermit = false;
      }
    } else if (!_supportsStarPoint(next)) {
      // A native connection change can revoke, but never grant, authority.
      _starPointCapabilityFreshlyProven = false;
      _starPointDispatchPermit = false;
    }
    final capabilityChanged =
        previous.scoringProtocolVersion != next.scoringProtocolVersion ||
        previous.scoringCapabilityProbed != next.scoringCapabilityProbed ||
        !_sameCapabilities(previous.capabilities, next.capabilities) ||
        previousStarPointProof != _starPointCapabilityFreshlyProven;
    state = next;
    if (next.platformLabel.isEmpty) return;
    final provider = switch (next.platformLabel) {
      'Apple Watch' => 'APPLE_WATCH',
      'Wear OS' => 'WEAR_OS',
      _ => next.platformLabel.toUpperCase().replaceAll(' ', '_'),
    };
    // Radio reachability must never auto-mark READY / setupStep 6.
    // Guided proof (ping + point) owns READY; otherwise CONNECTED / NOT_REACHABLE.
    final radioStatus = next.reachable || next.connected
        ? 'CONNECTED'
        : (next.companionInstalled
              ? 'NOT_REACHABLE'
              : (next.status == 'COMPANION_MISSING'
                    ? 'COMPANION_MISSING'
                    : next.status));
    final existing = await ref.read(connectedDeviceRepoProvider).all();
    final existingRow = existing
        .where((d) => d.platform == next.platformLabel)
        .firstOrNull;
    // Preserve proven READY from wizard tests; never demote proven via radio alone
    // unless companion is gone.
    final status = existingRow?.status == 'READY' && next.companionInstalled
        ? 'READY'
        : (radioStatus == 'READY' ? 'CONNECTED' : radioStatus);
    final setupStep = existingRow != null && existingRow.setupStep > 0
        ? existingRow.setupStep
        : (next.companionInstalled || next.paired ? 2 : 1);
    await ref
        .read(connectedDeviceRepoProvider)
        .upsertDiagnostics(
          platform: next.platformLabel,
          family: next.platformLabel,
          displayName: next.deviceName.isEmpty
              ? next.platformLabel
              : next.deviceName,
          status: status,
          capabilitiesJson: jsonEncode({
            'provider': provider,
            'features': next.capabilities,
            'scoringProtocolVersion': next.scoringProtocolVersion,
            'scoringCapabilityProbed': next.scoringCapabilityProbed,
            'paired': next.paired,
            'companionInstalled': next.companionInstalled,
            'reachable': next.reachable,
          }),
          companionInstalled: next.companionInstalled,
          permissionsComplete: next.permissionsComplete,
          setupStep: setupStep.clamp(0, 6),
          connected: next.connected || next.reachable,
        );
    if (capabilityChanged) {
      // A newly compatible companion receives Star Point resumables; a
      // downgrade gets the filtered snapshot. publishResumableMatches does
      // not probe, therefore this cannot recurse into _applyStatus.
      unawaited(publishResumableMatches());
    }
  }

  String? _deviceId(String platform) {
    if (platform.isEmpty) return null;
    return 'watch_${platform.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}';
  }

  Future<void> _drainQueuedEvents() async {
    try {
      final json = await _channel.invokeMethod<String>('drainEvents');
      if (json == null || json.isEmpty) return;
      final pending = (jsonDecode(json) as List)
          .map((e) => (e as Map).cast<String, Object?>())
          .toList(growable: false);
      final remaining = <Map<String, Object?>>[];
      for (final args in pending) {
        final merged = await _mergeEvents(args);
        if (!merged) remaining.add(args);
      }
      await _channel.invokeMethod<bool>('replaceQueuedEvents', {
        'pendingJson': jsonEncode(remaining),
      });
    } on MissingPluginException {
      // Native side not wired yet (e.g. tests): no queued events.
    } on PlatformException {
      // Platforms without a native queue can safely ignore this.
    } on FormatException {
      // Malformed native queue: do not crash app startup.
    } on TypeError {
      // Defensive guard against platform payload drift.
    }
  }

  Future<bool> syncProfileImage({String? path, required int version}) async {
    try {
      return await _channel
              .invokeMethod<bool>('syncProfileImage', {
                if (path?.isNotEmpty == true) 'path': path,
                'version': version,
              })
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Sends privacy-sensitive workout-detection preferences through the
  /// native, device-local bridge. No account, health metric or location is
  /// attached to this payload.
  Future<bool> updateWorkoutDetectionPreferences(
    Map<String, Object?> preferences,
  ) async {
    try {
      return await _channel
              .invokeMethod<bool>(
                'updateWorkoutDetectionPreferences',
                preferences,
              )
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Invia la configurazione partita al watch (PRD C1 punto 7).
  ///
  /// [duoTeam] (Duo Mode): assegna il watch a un solo team — il watch
  /// mostrerà un unico pulsante "PUNTO NOSTRO" e potrà annullare solo i
  /// punti di quel team.
  ///
  /// Retry once after refreshing WatchConnectivity state: a cold start or
  /// race between pairing and the first START_MATCH used to drop the payload.
  Future<bool> sendMatchToWatch({
    required String matchId,
    required MatchFormat format,
    TeamId? duoTeam,
    String? teamName,
    String? teamImagePath,
    int teamImageVersion = 0,
    String teamScoringStyle = 'AUTO',
    String? sourceUserId,
    bool premiumEnabled = false,
    bool assistantEnabled = false,
    String? assistantEndpoint,
    String? assistantAccessToken,
    String? assistantPublishableKey,
    int? assistantExpiresAtMs,
    List<String> teamNames = const [],

    /// When set, bootstraps mid-match handoff so the watch does not start 0–0.
    List<MatchEvent>? events,
  }) async {
    if (format.gameScoringMode == GameScoringMode.starPoint &&
        !await _authorizeStarPointDispatch()) {
      return false;
    }
    if (format.requiresDecidingSetProtocol &&
        !await proveDecidingSetCapability()) {
      return false;
    }
    // Always prefer an explicit journal; otherwise load durable local log.
    final journal =
        events ?? await ref.read(matchRepoProvider).eventsFor(matchId);
    // The serving rotation is part of the match, not of the format: without it
    // the companion would replay every hold and break for the wrong pair.
    final row = await ref.read(matchRepoProvider).byId(matchId);
    final args = <String, Object?>{
      'matchId': matchId,
      'format': jsonEncode(format.toJson()),
      'firstServer': (row?.firstServerTeam ?? TeamId.a).wire,
      // Critical: watch must replay phone log for mid-match / live handoff.
      'events': jsonEncode(journal.map((e) => e.toJson()).toList()),
      if (duoTeam != null) 'duoTeam': duoTeam.wire,
      if (teamName?.isNotEmpty == true) 'teamName': teamName,
      if (teamImagePath?.isNotEmpty == true) 'teamImagePath': teamImagePath,
      'teamImageVersion': teamImageVersion,
      'teamScoringStyle': teamScoringStyle,
      if (sourceUserId?.isNotEmpty == true) 'sourceUserId': sourceUserId,
      'premiumEnabled': premiumEnabled,
      'assistantEnabled': assistantEnabled,
      if (assistantEnabled && assistantEndpoint?.isNotEmpty == true)
        'assistantEndpoint': assistantEndpoint,
      if (assistantEnabled && assistantAccessToken?.isNotEmpty == true)
        'assistantAccessToken': assistantAccessToken,
      if (assistantEnabled && assistantPublishableKey?.isNotEmpty == true)
        'assistantPublishableKey': assistantPublishableKey,
      if (assistantEnabled && assistantExpiresAtMs != null)
        'assistantExpiresAtMs': assistantExpiresAtMs,
      'teamNames': teamNames.take(12).toList(growable: false),
      if (teamName?.isNotEmpty == true) 'defaultTeamName': teamName,
    };
    try {
      var ok =
          await _channel
              .invokeMethod<bool>('startMatch', args)
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
      if (ok) {
        unawaited(refresh());
        return true;
      }
      // Session may still be activating after pairing / app reinstall.
      await refresh();
      if (format.gameScoringMode == GameScoringMode.starPoint &&
          !_starPointCapabilityFreshlyProven) {
        return false;
      }
      if (!state.companionInstalled && !state.paired) return false;
      ok =
          await _channel
              .invokeMethod<bool>('startMatch', args)
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
      if (ok) unawaited(refresh());
      return ok;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Durable pause/resume/complete for the companion.
  ///
  /// Delivered through the reliable queued channel (`transferUserInfo` on iOS,
  /// a Data Item on Wear OS) with the full event journal attached, so the watch
  /// can resume the match and keep scoring with no connectivity at all.
  /// Safe no-op on platforms without a listener (returns false, no throw).
  Future<bool> sendMatchLifecycle({
    required String matchId,
    required String action,
    MatchFormat? format,
    List<MatchEvent>? events,
    String? status,
  }) async {
    try {
      final journal =
          events ?? await ref.read(matchRepoProvider).eventsFor(matchId);
      final row = await ref.read(matchRepoProvider).byId(matchId);
      MatchFormat? resolvedFormat = format;
      Map<String, Object?>? summary;
      if (row != null) {
        // A malformed stored format must not block the lifecycle delivery:
        // the status still has to reach the companion.
        try {
          resolvedFormat ??= MatchFormat.fromJson(
            (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
          );
          summary = await _summaryFor(row, journal: journal);
        } catch (_) {
          summary = null;
        }
      }
      if (resolvedFormat?.gameScoringMode == GameScoringMode.starPoint &&
          !await _authorizeStarPointDispatch()) {
        return false;
      }
      if (resolvedFormat?.requiresDecidingSetProtocol == true &&
          !await proveDecidingSetCapability()) {
        return false;
      }
      final authorityVersion = await _nextPhoneAuthorityVersion();
      if (authorityVersion == null) return false;
      final authorityScope = resolvedFormat == null
          ? null
          : (resolvedFormat.gameScoringMode == GameScoringMode.starPoint
                ? 'STAR_POINT'
                : 'NON_STAR_POINT');
      final ok =
          await _channel
              .invokeMethod<bool>('matchLifecycle', {
                'matchId': matchId,
                'action': action,
                'status': status ?? row?.status,
                // Version == journal length: every device derives the same
                // number from the same events, with no clock comparison.
                'stateVersion': journal.length,
                'idempotencyKey': '$matchId#$action#${journal.length}',
                'ts': DateTime.now().millisecondsSinceEpoch,
                if (authorityScope != null) ...<String, Object?>{
                  'authoritySource': 'PHONE',
                  'authorityScope': authorityScope,
                  'authorityVersion': authorityVersion,
                },
                if (resolvedFormat != null)
                  'format': jsonEncode(resolvedFormat.toJson()),
                'events': jsonEncode(
                  journal.map((e) => e.toJson()).toList(growable: false),
                ),
                if (summary != null) 'summary': jsonEncode(summary),
              })
              .timeout(_nativeTimeout, onTimeout: () => false) ??
          false;
      // The snapshot always follows so the "latest state" channel and the
      // reliable event channel cannot drift apart.
      unawaited(publishResumableMatches());
      return ok;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Publishes the snapshot of resumable matches through the "latest state"
  /// channel (application context on iOS, Data Item on Wear OS).
  Future<bool> publishResumableMatches() {
    final publication = _resumablePublishTail.then(
      (_) => _publishResumableMatchesNow(),
    );
    // Keep every write FIFO. Otherwise two best-effort refreshes could leave
    // an older Data Item as the persistent reconnect value even though an
    // already-running watch correctly rejected it by authorityVersion.
    _resumablePublishTail = publication.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return publication;
  }

  Future<bool> _publishResumableMatchesNow() async {
    try {
      final repo = ref.read(matchRepoProvider);
      final rows = await repo.resumableMatches();
      final legacyEntries = <Map<String, Object?>>[];
      final v2Entries = <Map<String, Object?>>[];
      for (final row in rows) {
        // One corrupt row must never suppress the whole snapshot.
        try {
          final journal = await repo.eventsFor(row.id);
          final summary = await _summaryFor(row, journal: journal);
          final starPoint = _summaryUsesStarPoint(summary);
          v2Entries.add(summary);
          // Garmin and every schema-v1 companion always get a useful filtered
          // snapshot instead of losing all resumable matches.
          if (!starPoint) {
            legacyEntries.add(summary);
          }
        } catch (_) {
          continue;
        }
      }
      // Connect IQ uses its own transport: push the same snapshot there so a
      // Garmin knows about compatible paused matches too.
      unawaited(_publishToGarmin(legacyEntries));

      final authorityVersion = await _nextPhoneAuthorityVersion();
      if (authorityVersion == null) return false;
      final hasStarPoint = v2Entries.any(_summaryUsesStarPoint);
      final mayPublishStarPoint =
          hasStarPoint && _starPointCapabilityFreshlyProven;

      if (!mayPublishStarPoint) {
        // Clear the v2 slot first, even after a capability downgrade. The
        // native bridge only permits this capability-less write when it is an
        // authenticated, authoritative and empty STAR_POINT snapshot.
        final v2ClearOk = await _publishNativeResumableSnapshot(
          const <Map<String, Object?>>[],
          requiresScoringV2: true,
          authorityVersion: authorityVersion,
          clearScoringV2Slot: true,
        );
        // Keep a deterministic clear-before-legacy order for every transport.
        // Apple stores the two snapshots under distinct keys in its single
        // application-context envelope; Wear OS stores distinct Data Items.
        final legacyOk = await _publishNativeResumableSnapshot(
          legacyEntries,
          requiresScoringV2: false,
          authorityVersion: authorityVersion,
        );
        return legacyOk && v2ClearOk;
      }

      // With a freshly proven v2 companion, publish the compatible partition
      // first and the full snapshot second. Both transports retain independent
      // v1/v2 slots, and the scoped authority makes delivery order harmless.
      final legacyOk = await _publishNativeResumableSnapshot(
        legacyEntries,
        requiresScoringV2: false,
        authorityVersion: authorityVersion,
      );
      final v2Ok = await _publishNativeResumableSnapshot(
        v2Entries,
        requiresScoringV2: true,
        authorityVersion: authorityVersion,
      );
      return legacyOk && v2Ok;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Mirrors the snapshot to registered Garmin devices over Connect IQ.
  /// Best effort: a Garmin that is not reachable simply misses this round and
  /// receives the next one.
  Future<void> _publishToGarmin(List<Map<String, Object?>> matches) async {
    try {
      final devices = await ref.read(connectedDeviceRepoProvider).all();
      final garmin = devices.where(
        (device) => device.id.startsWith('watch_garmin_'),
      );
      if (garmin.isEmpty) return;
      final service = ref.read(wearableProviderServiceProvider);
      final reachable = await service.garminDevices();
      for (final device in garmin) {
        final expectedId = device.id.replaceFirst('watch_garmin_', '');
        final target = reachable
            .where((item) => item.deviceId == expectedId)
            .firstOrNull;
        if (target == null) continue;
        await service.sendGarmin(target.nativeId, {
          'type': 'RESUMABLE_SNAPSHOT',
          'matches': matches,
        });
      }
    } catch (_) {
      // Connect IQ availability is best effort and never blocks the phone.
    }
  }

  Future<bool> _publishNativeResumableSnapshot(
    List<Map<String, Object?>> entries, {
    required bool requiresScoringV2,
    required int authorityVersion,
    bool clearScoringV2Slot = false,
  }) async {
    var newest = 0;
    for (final entry in entries) {
      final updatedAt = entry['updatedAtMs'] as int? ?? 0;
      if (updatedAt > newest) newest = updatedAt;
    }
    final active = entries
        .where(
          (entry) => entry['status']?.toString() == MatchStatus.inProgress.wire,
        )
        .firstOrNull;
    return await _channel
            .invokeMethod<bool>('publishResumableMatches', {
              'matches': jsonEncode(entries),
              'stateVersion': entries.length,
              'requiresScoringV2': requiresScoringV2,
              'authoritative': true,
              'authoritySource': 'PHONE',
              'authorityScope': requiresScoringV2
                  ? 'STAR_POINT'
                  : 'NON_STAR_POINT',
              'authorityVersion': authorityVersion,
              'clearScoringV2Slot': clearScoringV2Slot,
              'lastUpdatedAtMs': newest == 0
                  ? DateTime.now().millisecondsSinceEpoch
                  : newest,
              if (active != null)
                'activeMatchId': active['matchId']?.toString(),
            })
            .timeout(_nativeTimeout, onTimeout: () => false) ??
        false;
  }

  bool _summaryUsesStarPoint(Map<String, Object?> summary) {
    final format = summary['format'];
    return format is Map &&
        format['gameScoringMode']?.toString() == GameScoringMode.starPoint.wire;
  }

  /// Compact, wearable-sized description of a match. The journal itself is
  /// delivered separately by [sendMatchLifecycle].
  Future<Map<String, Object?>> _summaryFor(
    MatchRow row, {
    required List<MatchEvent> journal,
  }) async {
    final format = MatchFormat.fromJson(
      (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
    );
    final engine = PadelScoringEngine.replay(
      matchId: row.id,
      format: format,
      events: journal,
      firstServer: row.firstServerTeam,
      duoMode: row.duoMode,
      assignedTeam: row.duoTeam == null ? null : TeamId.fromWire(row.duoTeam!),
    );
    final score = engine.state;
    final pausedAt = journal
        .where((event) => event.type == MatchEventType.matchPaused)
        .lastOrNull
        ?.timestampMs;
    final team = row.teamId == null
        ? null
        : await ref.read(teamRepoProvider).byId(row.teamId!);
    return <String, Object?>{
      'matchId': row.id,
      'status': row.status,
      'stateVersion': journal.length,
      'updatedAtMs': journal.lastOrNull?.timestampMs ?? row.startTimeMs ?? 0,
      'pausedAtMs': row.status == MatchStatus.paused.wire ? pausedAt : null,
      'teamLabel': team?.name ?? row.opponentLabel,
      'scoreLine':
          '${score.points.labelFor(TeamId.a)}-${score.points.labelFor(TeamId.b)}',
      'setsLabel': '${score.setsA}-${score.setsB}',
      'gamesLabel': '${score.gamesA}-${score.gamesB}',
      'format': format.toJson(),
      'sourceDevice': 'PHONE',
      'eventCount': journal.length,
      'journalAvailable': journal.isNotEmpty,
    };
  }

  /// Eventi in arrivo dal watch: merge idempotente nel log locale.
  Future<Object?> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'events':
        final args = (call.arguments as Map).cast<String, Object?>();
        return _mergeEvents(args);
      case 'requestState':
        final args = (call.arguments as Map).cast<String, Object?>();
        final matchId = args['matchId'] as String;
        final events = await ref.read(matchRepoProvider).eventsFor(matchId);
        return jsonEncode(events.map((e) => e.toJson()).toList());
      case 'connectionChanged':
        final args = (call.arguments as Map).cast<String, Object?>();
        final next = WatchSyncState.fromMap(args);
        final wasConnected = state.connected;
        await _applyStatus(next);
        // Republish on reconnection so the companion converges on the same
        // state after any period of disconnection.
        if (next.connected && !wasConnected) {
          unawaited(publishResumableMatches());
        }
        return true;
    }
    return null;
  }

  Future<bool> _mergeEvents(Map<String, Object?> args) async {
    try {
      final matchId = args['matchId'] as String;
      final list = (jsonDecode(args['events'] as String) as List)
          .map((e) => MatchEvent.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      final formatJson = args['format'] as String?;
      final format = formatJson == null
          ? null
          : MatchFormat.fromJson(
              (jsonDecode(formatJson) as Map).cast<String, Object?>(),
            );
      await ref
          .read(matchRepoProvider)
          .mergeSyncedEvents(matchId: matchId, events: list, format: format);
      // Serialize engine rebuild on the same FIFO as local phone taps.
      try {
        await ref
            .read(liveMatchProvider(matchId).notifier)
            .reloadAfterExternalMerge();
      } catch (_) {
        // Provider may be disposed if live screen is closed — invalidate lists.
        ref.invalidate(liveMatchProvider(matchId));
      }
      ref.invalidate(recentMatchesProvider);
      ref.invalidate(summariesProvider);
      // Events coming from the watch (a resume, for instance) change the match
      // status here: republish so both devices converge on the same snapshot.
      unawaited(publishResumableMatches());
      return true;
    } on FormatException {
      return false;
    } on StateError {
      return false;
    } on TypeError {
      return false;
    }
  }
}

final watchSyncProvider = NotifierProvider<WatchSyncService, WatchSyncState>(
  WatchSyncService.new,
);
