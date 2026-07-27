/// Duo Mode (premium): due team connessi segnano la stessa partita da due
/// smartwatch, uno per team.
///
/// Architettura MVP (costi minimi, niente realtime obbligatorio):
///  - lo scoring resta locale ed event-sourced su ogni telefono/watch;
///  - il telefono di ogni team fa PUSH degli eventi del proprio team sulla
///    timeline cloud `duo_events` (insert idempotente per eventId) e PULL
///    con polling leggero degli eventi dell'altro team;
///  - l'ordine autorevole è quello logico validato dal backend (timestamp
///    locale entro limiti anti-abuso, poi sequenza server): dopo ogni pull la
///    sequenza locale viene riallineata, così i due device convergono;
///  - offline: gli eventi restano accodati in locale (cloudSynced=false) e
///    partono al prossimo push.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../features/live/live_match_controller.dart';
import 'cloud_service.dart';

const _netTimeout = Duration(seconds: 12);

const duoStarPointUnsupportedMessage =
    'Star Point richiede due dispositivi con protocollo di punteggio v2 e '
    'per ora non è disponibile in Duo Mode. Usa Singolo dispositivo.';

const duoDecidingSetUnsupportedMessage =
    'Il set decisivo senza tie-break richiede due dispositivi con schema '
    'formato v3 e per ora non è disponibile in Duo Mode. '
    'Usa Singolo dispositivo.';

/// Formats both Duo devices are guaranteed to score identically.
///
/// A device on an older build ignores fields it does not know: Star Point
/// would degrade to Advantage and a deciding set without tie-break would open
/// a tie-break at 6-6. Both cases produce two different matches, so they are
/// refused rather than negotiated.
bool supportsDuoScoring(MatchFormat format) =>
    format.gameScoringMode != GameScoringMode.starPoint &&
    !format.requiresDecidingSetProtocol;

/// Message explaining why [supportsDuoScoring] refused [format].
String duoUnsupportedFormatMessage(MatchFormat format) =>
    format.gameScoringMode == GameScoringMode.starPoint
    ? duoStarPointUnsupportedMessage
    : duoDecidingSetUnsupportedMessage;

/// Tipi di evento che viaggiano sulla timeline cloud. I derivati
/// (GAME_COMPLETED, SET_COMPLETED, SIDE_CHANGE) restano locali: ogni replay
/// li rigenera e duplicarli in cloud è solo rumore/costo.
const _pushableTypes = {
  MatchEventType.matchStarted,
  MatchEventType.pointTeamA,
  MatchEventType.pointTeamB,
  MatchEventType.undo,
  MatchEventType.matchPaused,
  MatchEventType.matchResumed,
  MatchEventType.matchCompleted,
  MatchEventType.deviceJoinedMatch,
  MatchEventType.deviceLeftMatch,
  MatchEventType.teamConfirmed,
};

class DuoSessionInfo {
  const DuoSessionInfo({
    required this.sessionId,
    required this.matchId,
    required this.myTeam,
    required this.status,
    this.joinCode,
    this.format,
    this.firstServer = TeamId.a,
    this.guestJoined = false,
  });

  final String sessionId;
  final String matchId;
  final TeamId myTeam;
  final String status; // PENDING | ACTIVE | FINALIZING | COMPLETED | CANCELLED
  final String? joinCode;
  final MatchFormat? format;

  /// Coppia al servizio nel primo game (FIP Regola 4). Entrambi i device
  /// devono rigiocare il journal condiviso con lo stesso valore, altrimenti
  /// servizio, risposta, break e hold finiscono sulla coppia sbagliata.
  final TeamId firstServer;
  final bool guestJoined;
}

class DuoService {
  DuoService(this.ref);
  final Ref ref;

  /// Ultimo `seq` server visto per match: consente al polling da 4s di
  /// scaricare la timeline completa solo quando esiste davvero qualcosa di
  /// nuovo (probe da 1 riga al posto del full pull a ogni tick).
  final Map<String, int> _pullHighWater = {};
  final Map<String, ({int seq, bool completed})> _lastAcknowledgement = {};
  final Map<String, Future<bool>> _syncInFlight = {};

  SupabaseClient? get _client => cloudClient;

  String? get userId => _client?.auth.currentUser?.id;
  bool get available => _client != null && userId != null;

  void _logTestUser(String op) {
    // I test user devono essere distinguibili nei log (§11) e non
    // inquinare le metriche di conversione.
    final ents = ref.read(entitlementsProvider);
    if (ents.premiumOverride) {
      debugPrint('[DUO][TEST-USER] $op (override attivo, nessun acquisto)');
    }
  }

  /// Crea la sessione cloud per una partita locale e ritorna il codice
  /// invito. Errore in italiano se non possibile.
  Future<({DuoSessionInfo? session, String? error, bool canDiscardLocal})>
  createSession({
    required String matchId,
    required MatchFormat format,
    TeamId myTeam = TeamId.a,
    TeamId firstServer = TeamId.a,
  }) async {
    // Fail closed before auth, local pending markers or remote mutations. Until
    // Duo negotiates the scoring protocol of both phones, a legacy peer would
    // decode Star Point's goldenPoint=false fallback as ADVANTAGE and would
    // open a tie-break in a deciding set meant to be played out.
    if (!supportsDuoScoring(format)) {
      return (
        session: null,
        error: duoUnsupportedFormatMessage(format),
        canDiscardLocal: true,
      );
    }
    final c = _client;
    if (c == null) {
      return (
        session: null,
        error: 'Servizi online non disponibili.',
        canDiscardLocal: true,
      );
    }
    final uid = c.auth.currentUser?.id;
    if (uid == null) {
      return (
        session: null,
        error: 'Accedi prima al tuo account',
        canDiscardLocal: true,
      );
    }
    try {
      final marked = await ref
          .read(matchRepoProvider)
          .markDuoCreationPending(matchId);
      if (!marked) {
        return (
          session: null,
          error: 'Partita Duo locale non recuperabile.',
          canDiscardLocal: false,
        );
      }
    } catch (_) {
      // Never call the remote RPC without first durably storing its
      // idempotency key locally.
      return (
        session: null,
        error: 'Impossibile preparare il recupero della partita Duo.',
        canDiscardLocal: false,
      );
    }
    _logTestUser('createSession $matchId');
    try {
      final res = await c
          .rpc<dynamic>(
            'duo_create_session',
            params: {
              'p_match_id': matchId,
              'p_format': format.toJson(),
              'p_team': myTeam.wire,
              'p_first_server': firstServer.wire,
            },
          )
          .timeout(_netTimeout);
      final data = (res as Map).cast<String, Object?>();
      if (data['ok'] == false) {
        return (
          session: null,
          error: _duoError(data['error']?.toString()),
          canDiscardLocal: true,
        );
      }
      final info = DuoSessionInfo(
        sessionId: data['sessionId'] as String,
        matchId: data['matchId'] as String,
        myTeam: myTeam,
        status: data['status'] as String? ?? 'PENDING',
        joinCode: data['joinCode'] as String?,
        format: format,
        firstServer: firstServer,
      );
      await ref
          .read(matchRepoProvider)
          .linkDuoSession(
            matchId,
            sessionId: info.sessionId,
            ownerUserId: uid,
            joinCode: info.joinCode,
            duoTeam: myTeam,
            cloudStatus: info.status,
          );
      return (session: info, error: null, canDiscardLocal: false);
    } on PostgrestException catch (e) {
      return (
        session: null,
        error: e.code == '42501'
            ? 'Duo Mode richiede il piano Plus (o un account di test).'
            : e.message,
        canDiscardLocal: true,
      );
    } on TimeoutException {
      // The RPC may have committed before its response was lost. Keep the
      // local idempotency key and retry this same matchId from the lobby.
      return (
        session: null,
        error: 'Esito di rete incerto: recupero della sessione in corso.',
        canDiscardLocal: false,
      );
    } catch (_) {
      // This also covers a local link failure after a successful RPC.
      return (
        session: null,
        error: 'Creazione incerta: riprova senza creare un’altra partita.',
        canDiscardLocal: false,
      );
    }
  }

  /// Entra in una sessione con il codice invito. Crea (o riusa) la partita
  /// locale condivisa e ritorna la sessione con il team assegnato.
  Future<({DuoSessionInfo? session, String? error})> joinByCode(
    String code,
  ) async {
    final c = _client;
    if (c == null) {
      return (session: null, error: 'Servizi online non disponibili.');
    }
    if (c.auth.currentUser == null) {
      return (session: null, error: 'Accedi prima al tuo account');
    }
    _logTestUser('joinByCode');
    try {
      final res = await c
          .rpc<dynamic>(
            'duo_join_session',
            params: {'p_code': code.trim().toUpperCase()},
          )
          .timeout(_netTimeout);
      final data = (res as Map).cast<String, Object?>();
      if (data['ok'] == false) {
        return (session: null, error: _duoError(data['error']?.toString()));
      }
      final myTeam = TeamId.fromWire(data['myTeam'] as String);
      final format = MatchFormat.fromJson(
        ((data['format'] as Map?) ?? const {}).cast<String, Object?>(),
      );
      if (!supportsDuoScoring(format)) {
        return (session: null, error: duoUnsupportedFormatMessage(format));
      }
      // Assente se la sessione è stata creata da un client precedente: quel
      // client aveva rigiocato con TEAM_A, che resta quindi il default giusto.
      final firstServer = data['firstServer'] == TeamId.b.wire
          ? TeamId.b
          : TeamId.a;
      final matchId = data['matchId'] as String;
      final info = DuoSessionInfo(
        sessionId: data['sessionId'] as String,
        matchId: matchId,
        myTeam: myTeam,
        status: data['status'] as String? ?? 'ACTIVE',
        format: format,
        firstServer: firstServer,
        guestJoined: true,
      );

      final repo = ref.read(matchRepoProvider);
      // opponentLabel vuota: nello storico la partita è già marcata ⌚⌚ Duo,
      // "vs Duo Mode" sarebbe solo rumore.
      await repo.create(
        matchId: matchId,
        format: format,
        duoMode: true,
        duoTeam: myTeam,
        firstServer: firstServer,
      );
      await repo.linkDuoSession(
        matchId,
        sessionId: info.sessionId,
        ownerUserId: c.auth.currentUser!.id,
        duoTeam: myTeam,
        cloudStatus: info.status,
      );
      await _appendLifecycle(info, MatchEventType.deviceJoinedMatch);
      await _appendLifecycle(
        info,
        MatchEventType.teamConfirmed,
        teamId: myTeam,
      );
      ref.invalidate(recentMatchesProvider);
      return (session: info, error: null);
    } on PostgrestException catch (e) {
      final msg = switch (e.message) {
        final m when m.contains('invalid_code') =>
          'Codice non valido: controlla e riprova.',
        final m when m.contains('code_expired') =>
          'Codice scaduto: chiedi all’altro team di crearne uno nuovo.',
        final m when m.contains('session_full') =>
          'Un altro giocatore è già entrato in questa partita.',
        final m when m.contains('session_closed') =>
          'La partita non è più aperta.',
        final m when m.contains('auth_required') =>
          'Accedi prima al tuo account',
        _ => 'Accesso alla partita non riuscito.',
      };
      return (session: null, error: msg);
    } on TimeoutException {
      return (session: null, error: 'Rete lenta o assente. Riprova.');
    } catch (_) {
      return (session: null, error: 'Accesso alla partita non riuscito.');
    }
  }

  /// Stato sessione (per il lobby: "in attesa dell'altro team…").
  Future<DuoSessionInfo?> sessionStatus(String sessionId) async {
    final c = _client;
    if (c == null) return null;
    try {
      final row = await c
          .from('duo_sessions')
          .select(
            'session_id, match_id, status, join_code, creator_id, '
            'creator_team, guest_id, guest_team, format_json',
          )
          .eq('session_id', sessionId)
          .maybeSingle()
          .timeout(_netTimeout);
      if (row == null) return null;
      final mine = row['creator_id'] == userId
          ? row['creator_team'] as String
          : (row['guest_team'] as String? ?? 'TEAM_B');
      return DuoSessionInfo(
        sessionId: row['session_id'] as String,
        matchId: row['match_id'] as String,
        myTeam: TeamId.fromWire(mine),
        status: row['status'] as String,
        joinCode: row['join_code'] as String?,
        guestJoined: row['guest_id'] != null,
        format: MatchFormat.fromJson(
          ((row['format_json'] as Map?) ?? const {}).cast<String, Object?>(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> setSessionStatus(String sessionId, String status) async {
    final c = _client;
    if (c == null) return false;
    try {
      final response = await c
          .rpc(
            'duo_set_session_status',
            params: {'p_session_id': sessionId, 'p_status': status},
          )
          .timeout(_netTimeout);
      if (response is Map && response['ok'] == false) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({String status, int maxSeq})?> _acknowledgeReplay({
    required String sessionId,
    required int seenSeq,
    required bool completed,
  }) async {
    final c = _client;
    if (c == null) return null;
    final fingerprint = (seq: seenSeq, completed: completed);
    if (_lastAcknowledgement[sessionId] == fingerprint) return null;
    try {
      final response = await c
          .rpc<dynamic>(
            'duo_ack_state',
            params: {
              'p_session_id': sessionId,
              'p_seen_seq': seenSeq,
              'p_completed': completed,
            },
          )
          .timeout(_netTimeout);
      final data = (response as Map).cast<String, Object?>();
      if (data['ok'] == true) {
        _lastAcknowledgement[sessionId] = fingerprint;
        return (
          status: data['status'] as String? ?? 'ACTIVE',
          maxSeq: (data['maxSeq'] as num?)?.toInt() ?? seenSeq,
        );
      }
    } on TimeoutException {
      // Retry on the next foreground tick.
    } catch (_) {
      // Older backend or transient RPC failure: keep the acknowledgement
      // pending instead of pretending the other participant has seen it.
    }
    return null;
  }

  /// Abbandona la sessione (Duo Mode §10): registra l'evento e, se sei il
  /// creatore in attesa, annulla la sessione.
  Future<bool> leaveSession(DuoSessionInfo info) async {
    // While the invite is still open, confirm remote cancellation before
    // hiding the local match. Otherwise a lost response would leave a live
    // join code that the creator believes to be closed.
    if (!info.guestJoined &&
        !await setSessionStatus(info.sessionId, 'CANCELLED')) {
      return false;
    }
    await _appendLifecycle(
      info,
      MatchEventType.deviceLeftMatch,
      teamId: info.myTeam,
    );
    await syncNow(info.matchId);
    return true;
  }

  Future<void> _appendLifecycle(
    DuoSessionInfo info,
    MatchEventType type, {
    TeamId? teamId,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final event = MatchEvent(
      eventId: generateEventId(),
      matchId: info.matchId,
      timestampMs: now,
      type: type,
      teamId: teamId,
      sourceMethod: SourceMethod.auto,
      duoMode: true,
      sourceUserId: userId,
      sourceTeamId: info.myTeam,
      createdLocallyAtMs: now,
    );
    await ref.read(matchRepoProvider).appendEvents(info.matchId, [event]);
  }

  // ------------------------------------------------------------------ sync

  /// Push eventi locali non sincronizzati + pull timeline server + riallineo
  /// ordine. Ritorna true se sono arrivati eventi nuovi dal server.
  Future<bool> syncNow(String matchId) {
    final running = _syncInFlight[matchId];
    if (running != null) return running;
    late final Future<bool> next;
    next = _syncNow(matchId).whenComplete(() {
      if (identical(_syncInFlight[matchId], next)) {
        _syncInFlight.remove(matchId);
      }
    });
    _syncInFlight[matchId] = next;
    return next;
  }

  Future<int> syncPendingMatches({int limit = 30}) async {
    final uid = userId;
    if (_client == null || uid == null) return 0;
    final candidates = await ref
        .read(matchRepoProvider)
        .duoSyncCandidates(uid, limit: limit);
    var attempted = 0;
    for (final match in candidates) {
      await syncNow(match.id);
      attempted++;
    }
    return attempted;
  }

  Future<bool> _syncNow(String matchId) async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return false;
    final repo = ref.read(matchRepoProvider);
    final match = await repo.byId(matchId);
    final sessionId = match?.duoSessionId;
    if (match == null || !match.duoMode || sessionId == null) return false;
    try {
      final format = MatchFormat.fromJson(
        (jsonDecode(match.formatJson) as Map).cast<String, Object?>(),
      );
      if (!supportsDuoScoring(format)) {
        debugPrint('[DUO] sync ignorato: Star Point richiede protocollo v2');
        return false;
      }
    } catch (_) {
      debugPrint('[DUO] sync ignorato: formato partita non valido');
      return false;
    }
    if (match.duoOwnerUserId != null && match.duoOwnerUserId != uid) {
      debugPrint('[DUO] sync ignorato: sessione collegata a un altro account');
      return false;
    }
    if (match.duoOwnerUserId == null) {
      final attributedUsers = (await repo.eventsFor(
        matchId,
      )).map((event) => event.sourceUserId).whereType<String>().toSet();
      if (attributedUsers.isNotEmpty && !attributedUsers.contains(uid)) {
        debugPrint('[DUO] sync legacy ignorato: attribuzione account diversa');
        return false;
      }
      if (attributedUsers.contains(uid)) await repo.markDuoOwner(matchId, uid);
    }
    final myTeam = match.duoTeam == null
        ? TeamId.a
        : TeamId.fromWire(match.duoTeam!);
    final pendingPushableIds = <String>{};

    // ---- PUSH (solo eventi del proprio device/team; il server rifiuta
    // comunque quelli non autorizzati via RLS).
    try {
      final pending = await repo.duoUnsyncedRows(matchId);
      final rows = <Map<String, Object?>>[];
      final pushedIds = <String>{};
      for (final r in pending) {
        final type = MatchEventType.tryFromWire(r.type);
        if (type == null || !_pushableTypes.contains(type)) {
          // Derivati/locali: mai in cloud, ma non vanno ritentati per sempre.
          pushedIds.add(r.eventId);
          continue;
        }
        pendingPushableIds.add(r.eventId);
        if (r.sourceUserId != null && r.sourceUserId != uid) {
          debugPrint('[DUO] evento ${r.eventId} appartiene a un altro account');
          continue;
        }
        if (r.sourceTeamId != null && r.sourceTeamId != myTeam.wire) {
          debugPrint('[DUO] evento ${r.eventId} appartiene a un altro team');
          continue;
        }
        // Punti/undo dell'altro team arrivati via pull hanno già
        // cloudSynced=true; qui restano solo eventi generati localmente
        // (telefono o watch collegato a questo telefono).
        rows.add({
          'event_id': r.eventId,
          'session_id': sessionId,
          'match_id': matchId,
          'ts_ms': r.timestampMs,
          'type': r.type,
          'team_id': r.teamId,
          'score_before': r.scoreBefore,
          'score_after': r.scoreAfter,
          'source_device': r.sourceDevice,
          'source_method': r.sourceMethod,
          'source_user_id': uid,
          'source_team_id': r.sourceTeamId ?? myTeam.wire,
          'payload': r.payloadJson == null ? null : jsonDecode(r.payloadJson!),
          'created_locally_at': r.createdLocallyAtMs ?? r.timestampMs,
        });
        pushedIds.add(r.eventId);
      }
      if (rows.isNotEmpty) {
        // upsert con ignoreDuplicates: re-push idempotente per eventId.
        await c
            .from('duo_events')
            .upsert(rows, onConflict: 'event_id', ignoreDuplicates: true)
            .timeout(_netTimeout);
        pendingPushableIds.removeAll(rows.map((row) => row['event_id']!));
      }
      await repo.markCloudSynced(matchId, pushedIds);
    } on PostgrestException catch (e) {
      debugPrint('[DUO] push respinto (${e.code}): ${e.message}');
      // RLS/rete: gli eventi restano in coda e si ritenta al prossimo giro.
    } on TimeoutException {
      // Offline: coda intatta.
    } catch (_) {}

    // ---- PULL + riallineo ordine server.
    try {
      // Probe: la timeline server è append-only con seq monotono, quindi se
      // il seq massimo non è cambiato dall'ultimo pull riuscito non c'è
      // nulla da scaricare né da riallineare. Al primo giro (o dopo un
      // riavvio) il high-water è assente e si fa sempre il pull completo.
      final lastSeq = _pullHighWater[matchId];
      if (lastSeq != null) {
        final probe = await c
            .from('duo_events')
            .select('seq')
            .eq('match_id', matchId)
            .order('seq', ascending: false)
            .limit(1)
            .timeout(_netTimeout);
        final maxSeq = probe.isEmpty
            ? 0
            : ((probe.first['seq'] as num?)?.toInt() ?? 0);
        if (maxSeq <= lastSeq) {
          final acknowledgement = await _acknowledgeReplay(
            sessionId: sessionId,
            seenSeq: lastSeq,
            completed:
                match.status == MatchStatus.completed.wire &&
                pendingPushableIds.isEmpty,
          );
          if (acknowledgement != null) {
            await repo.updateDuoCloudState(matchId, acknowledgement.status);
            await repo.markDuoOwner(matchId, uid);
          }
          return false;
        }
      }
      final rows = await c
          .from('duo_events')
          .select(
            'event_id, ts_ms, type, team_id, score_before, '
            'score_after, source_device, source_method, source_user_id, '
            'source_team_id, payload, created_locally_at, seq',
          )
          .eq('match_id', matchId)
          .order('created_locally_at', ascending: true)
          .order('seq', ascending: true)
          .timeout(_netTimeout);
      if (rows.isEmpty) {
        _pullHighWater[matchId] = 0;
        final acknowledgement = await _acknowledgeReplay(
          sessionId: sessionId,
          seenSeq: 0,
          completed: false,
        );
        if (acknowledgement != null) {
          await repo.updateDuoCloudState(matchId, acknowledgement.status);
          await repo.markDuoOwner(matchId, uid);
        }
        return false;
      }

      final before = await repo.eventsFor(matchId);
      final known = before.map((e) => e.eventId).toSet();
      final serverIds = <String>[];
      final incoming = <MatchEvent>[];
      for (final r in rows) {
        final id = r['event_id'] as String;
        serverIds.add(id);
        if (known.contains(id)) continue;
        final type = MatchEventType.tryFromWire(r['type'] as String);
        if (type == null) continue;
        incoming.add(
          MatchEvent(
            eventId: id,
            matchId: matchId,
            timestampMs: (r['ts_ms'] as num).toInt(),
            type: type,
            teamId: r['team_id'] == null
                ? null
                : TeamId.fromWire(r['team_id'] as String),
            scoreBefore: r['score_before'] as String?,
            scoreAfter: r['score_after'] as String?,
            sourceDevice: SourceDevice.fromWire(
              r['source_device'] as String? ?? 'PHONE',
            ),
            sourceMethod: SourceMethod.fromWire(
              r['source_method'] as String? ?? 'TAP',
            ),
            payload: (r['payload'] as Map?)?.cast<String, Object?>(),
            duoMode: true,
            sourceUserId: r['source_user_id'] as String?,
            sourceTeamId: r['source_team_id'] == null
                ? null
                : TeamId.fromWire(r['source_team_id'] as String),
            createdLocallyAtMs: (r['created_locally_at'] as num?)?.toInt(),
          ),
        );
      }
      if (incoming.isNotEmpty) {
        await repo.appendEvents(matchId, incoming, cloudSynced: true);
      }
      // L'ordine server è la timeline ufficiale: i replay dei due telefoni
      // devono convergere allo stesso punteggio.
      final orderChanged = await repo.realignDuoOrder(matchId, serverIds);
      // Pull + riallineo completati: da qui il probe può fidarsi del seq.
      final pulledMaxSeq = rows
          .map((r) => (r['seq'] as num?)?.toInt() ?? 0)
          .fold<int>(0, (max, seq) => seq > max ? seq : max);
      if (pulledMaxSeq > 0) _pullHighWater[matchId] = pulledMaxSeq;
      final reconciled = await repo.reconcileFromEventLog(matchId);
      final reconciliationChanged =
          reconciled != null &&
          (reconciled.row.status != match.status ||
              reconciled.row.summaryJson != match.summaryJson);
      final acknowledgement = await _acknowledgeReplay(
        sessionId: sessionId,
        seenSeq: pulledMaxSeq,
        completed:
            (reconciled?.engine.state.isCompleted ?? false) &&
            pendingPushableIds.isEmpty,
      );
      if (acknowledgement != null) {
        await repo.updateDuoCloudState(matchId, acknowledgement.status);
      }
      await repo.markDuoOwner(matchId, uid);
      if (incoming.isNotEmpty || orderChanged || reconciliationChanged) {
        // Defer invalidation so an in-flight local point mutation can finish
        // append+publish before the live engine is rebuilt from the DB.
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          ref.invalidate(liveMatchProvider(matchId));
          ref.invalidate(recentMatchesProvider);
          ref.invalidate(summariesProvider);
        });
      }
      return incoming.isNotEmpty || orderChanged || reconciliationChanged;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('[DUO] pull non riuscito: $e');
      return false;
    }
  }
}

String _duoError(String? code) => switch (code) {
  'premium_required' =>
    'Duo Mode richiede il piano Plus (o un account di test).',
  'rate_limited' => 'Troppi tentativi. Attendi qualche minuto e riprova.',
  'invalid_code' => 'Codice non valido: controlla e riprova.',
  'code_expired' =>
    'Codice scaduto: chiedi all’altro team di crearne uno nuovo.',
  'session_full' => 'Un altro giocatore è già entrato in questa partita.',
  'session_closed' => 'La partita non è più aperta.',
  'auth_required' => 'Accedi prima al tuo account.',
  'match_not_available' =>
    'Questa partita è già collegata a un’altra sessione.',
  'invalid_session' => 'Configurazione della partita non valida.',
  _ => 'Operazione Duo non riuscita.',
};

final duoServiceProvider = Provider<DuoService>((ref) => DuoService(ref));

/// Polling leggero della sessione Duo mentre la partita è aperta a schermo.
/// 4s: abbastanza reattivo per il punteggio, ~15 richieste/minuto per match
/// attivo — nessun servizio realtime dedicato.
class DuoLiveSync {
  DuoLiveSync(this.ref, this.matchId) {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    _tick();
  }

  final Ref ref;
  final String matchId;
  Timer? _timer;
  bool _busy = false;

  Future<void> _tick() async {
    // Skip radio work while the process is backgrounded; resume re-ticks via
    // the next periodic fire when the user returns.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(duoServiceProvider).syncNow(matchId);
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

final duoLiveSyncProvider = Provider.autoDispose.family<DuoLiveSync, String>((
  ref,
  matchId,
) {
  final sync = DuoLiveSync(ref, matchId);
  ref.onDispose(sync.dispose);
  return sync;
});
