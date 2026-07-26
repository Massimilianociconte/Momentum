/// Live match controller: wraps the rally_core engine, persists every
/// event immediately (crash-safe, PRD acceptance: partita recuperabile),
/// and finalizes the summary at completion.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';
import '../../services/cloud/duo_service.dart';
import '../../services/cloud/friend_groups_service.dart';

import '../../services/match_health_sync.dart';
import '../../services/match_scoring_lock.dart';
import '../../services/notifications.dart';
import '../../services/watch_sync.dart';

class LiveMatchState {
  const LiveMatchState({
    required this.row,
    required this.format,
    required this.score,
    required this.canUndo,
    required this.events,
    this.lastTransitions = const [],
    this.loading = false,
    this.persistenceMessage,
  });

  final MatchRow row;
  final MatchFormat format;
  final MatchState score;
  final bool canUndo;
  final List<MatchEvent> events;
  final List<ScoreTransition> lastTransitions;
  final bool loading;
  final String? persistenceMessage;

  /// Duo Mode: team assegnato a questo device (null = partita classica).
  TeamId? get duoTeam =>
      row.duoMode && row.duoTeam != null ? TeamId.fromWire(row.duoTeam!) : null;
  bool get isDuo => row.duoMode;
}

bool canAcceptLocalPoint(MatchStatus status) =>
    status == MatchStatus.created || status == MatchStatus.inProgress;

class LiveMatchController
    extends AutoDisposeFamilyAsyncNotifier<LiveMatchState, String> {
  PadelScoringEngine? _engine;
  bool _finalized = false;

  /// Catena FIFO delle mutazioni: due tap ravvicinati (o tap + undo) non
  /// devono mai interlacciare engine e persistenza.
  Future<void> _serial = Future.value();

  MatchRepository get _repo => ref.read(matchRepoProvider);

  @override
  Future<LiveMatchState> build(String arg) async {
    final stored = await _repo.byId(arg);
    if (stored == null) {
      throw StateError('Match $arg not found');
    }
    var row = stored;
    final events = await _repo.eventsFor(arg);
    final format = MatchFormat.fromJson(
      (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
    );
    // Duo Mode: ogni evento generato qui viene attribuito a questo account
    // e al team assegnato al device (il backend autorizza via RLS).
    final duoTeam = row.duoMode && row.duoTeam != null
        ? TeamId.fromWire(row.duoTeam!)
        : null;
    final engine = PadelScoringEngine.replay(
      matchId: arg,
      format: format,
      events: events,
      duoMode: row.duoMode,
      assignedTeam: duoTeam,
      sourceUserId: row.duoMode ? ref.read(duoServiceProvider).userId : null,
    );
    if (events.isEmpty) {
      final r = engine.start();
      await _repo.appendEvents(arg, r.newEvents);
    }
    String? persistenceMessage;
    if (engine.state.isCompleted && row.status != MatchStatus.completed.wire) {
      try {
        final reconciled = await _repo.reconcileFromEventLog(arg);
        if (reconciled != null) row = reconciled.row;
      } catch (_) {
        persistenceMessage =
            'La partita è al sicuro nel registro eventi, ma il riepilogo '
            'non è ancora stato finalizzato. Riproveremo alla riapertura.';
      }
    }
    _engine = engine;
    // Watch/cloud may have completed the match without phone finalize.
    if (engine.state.isCompleted ||
        row.status == MatchStatus.completed.wire ||
        row.status == MatchStatus.abandoned.wire) {
      unawaited(ref.read(matchScoringLockProvider).unlock(arg));
    }
    return LiveMatchState(
      row: row,
      format: format,
      score: engine.state,
      canUndo: duoTeam == null ? engine.canUndo : engine.canUndoTeam(duoTeam),
      events: engine.events,
      persistenceMessage: persistenceMessage,
    );
  }

  Future<void> point(TeamId team, {SourceMethod method = SourceMethod.tap}) {
    if (!canAcceptLocalPoint(
      state.valueOrNull?.score.status ?? MatchStatus.created,
    )) {
      return Future.value();
    }
    // Duo Mode: questo device segna SOLO i punti del proprio team — è la
    // barriera che evita punti duplicati tra i due smartwatch/telefoni.
    final duoTeam = state.valueOrNull?.duoTeam;
    if (duoTeam != null && team != duoTeam) return Future.value();
    return _mutateGuarded((e) => e.addPoint(team, method: method));
  }

  /// In Duo Mode l'undo è team-scoped: annulla solo l'ultimo punto del
  /// proprio team, così i log interlacciati dei due device convergono.
  Future<void> undo() =>
      _mutateGuarded((e) => e.undo(team: state.valueOrNull?.duoTeam));

  Future<void> pause() async {
    await _mutateGuarded((e) => e.pause());
    // A paused match is a synchronised resource: the companion receives the
    // status *and* the journal, so it can resume the match on its own.
    unawaited(_publishCompanionLifecycle('PAUSED'));
  }

  Future<void> resume() async {
    await _mutateGuarded((e) => e.resume());
    unawaited(_publishCompanionLifecycle('RESUMED'));
  }

  Future<void> _publishCompanionLifecycle(String action) async {
    try {
      await ref
          .read(watchSyncProvider.notifier)
          .sendMatchLifecycle(matchId: arg, action: action);
    } catch (_) {
      // Companion delivery is best-effort; scoring stays local-first and the
      // snapshot is republished on the next foreground.
    }
  }

  /// Rebuild engine from durable DB after an external wearable merge.
  /// Serialized on the same FIFO as local points to avoid mid-tap races.
  Future<void> reloadAfterExternalMerge() {
    final next = _serial.then((_) => _reloadFromDisk());
    _serial = next.catchError((_) {});
    return next;
  }

  Future<void> _reloadFromDisk() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final row = (await _repo.byId(arg)) ?? current.row;
    final events = await _repo.eventsFor(arg);
    final duoTeam = row.duoMode && row.duoTeam != null
        ? TeamId.fromWire(row.duoTeam!)
        : null;
    final restored = PadelScoringEngine.replay(
      matchId: arg,
      format: current.format,
      events: events,
      duoMode: row.duoMode,
      assignedTeam: duoTeam,
      sourceUserId: row.duoMode ? ref.read(duoServiceProvider).userId : null,
    );
    _engine = restored;
    if (restored.state.isCompleted ||
        row.status == MatchStatus.completed.wire) {
      unawaited(ref.read(matchScoringLockProvider).unlockIfPresent(arg));
    }
    state = AsyncData(
      LiveMatchState(
        row: row,
        format: current.format,
        score: restored.state,
        canUndo: duoTeam == null
            ? restored.canUndo
            : restored.canUndoTeam(duoTeam),
        events: restored.events,
        lastTransitions: const [],
      ),
    );
  }

  Future<void> edit({
    required int pointsA,
    required int pointsB,
    required int gamesA,
    required int gamesB,
    int? freePlayA,
    int? freePlayB,
    int? tieBreakA,
    int? tieBreakB,
  }) {
    // Duo: absolute score edits never leave the phone (server forbids
    // SCORE_EDITED). Refuse locally to avoid irreversible timeline forks.
    if (state.valueOrNull?.isDuo == true) return Future.value();
    if (state.valueOrNull?.score.isCompleted == true) return Future.value();
    return _mutateGuarded(
      (e) => e.editScore(
        pointsA: pointsA,
        pointsB: pointsB,
        gamesA: gamesA,
        gamesB: gamesB,
        freePlayA: freePlayA,
        freePlayB: freePlayB,
        tieBreakA: tieBreakA,
        tieBreakB: tieBreakB,
      ),
    );
  }

  Future<void> finishManually({required TeamId winner}) async {
    // Escape hatch: manual finish always allowed so a dead wearable cannot
    // brick the match after a queued-but-never-applied START.
    final lock = ref.read(matchScoringLockProvider);
    if (await lock.isPhoneScoringBlocked(arg)) {
      await lock.unlock(arg);
    }
    await _mutate((e) => e.finish(winner: winner));
  }

  /// Reclaim phone scoring (user-driven escape from wearable exclusive lock).
  Future<void> reclaimPhoneScoring() async {
    // Sticky reclaim: subsequent wearable merges must not re-block phone taps.
    await ref.read(matchScoringLockProvider).reclaimPhone(arg);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      LiveMatchState(
        row: current.row,
        format: current.format,
        score: current.score,
        canUndo: current.canUndo,
        events: current.events,
        lastTransitions: current.lastTransitions,
        persistenceMessage:
            'Punteggio tornato sul telefono. Evita di segnare anche sul watch.',
      ),
    );
  }

  /// Blocks phone-side scoring when Garmin/Fitbit owns the live match.
  Future<void> _mutateGuarded(
    ScoringResult Function(PadelScoringEngine) op,
  ) async {
    final blocked =
        await ref.read(matchScoringLockProvider).isPhoneScoringBlocked(arg);
    if (blocked) {
      final current = state.valueOrNull;
      if (current == null) return;
      // Auto-clear lock if match already finished on another device.
      if (current.score.isCompleted ||
          current.row.status == MatchStatus.completed.wire) {
        await ref.read(matchScoringLockProvider).unlock(arg);
        await _mutate(op);
        return;
      }
      state = AsyncData(
        LiveMatchState(
          row: current.row,
          format: current.format,
          score: current.score,
          canUndo: current.canUndo,
          events: current.events,
          lastTransitions: current.lastTransitions,
          persistenceMessage:
              'Punteggio sul wearable. Usa il watch, termina la partita dal '
              'menu, oppure attendi la sync — i tap sono bloccati per evitare '
              'punti doppi.',
        ),
      );
      return;
    }
    await _mutate(op);
  }

  Future<void> _mutate(ScoringResult Function(PadelScoringEngine) op) {
    final next = _serial.then((_) => _mutateNow(op));
    // La catena non deve rompersi se una mutazione fallisce.
    _serial = next.catchError((_) {});
    return next;
  }

  Future<void> _mutateNow(ScoringResult Function(PadelScoringEngine) op) async {
    final engine = _engine;
    final current = state.valueOrNull;
    if (engine == null || current == null) return;
    final ScoringResult result;
    try {
      result = op(engine);
    } on StateError {
      // Operazione non valida per lo stato corrente (es. punto dopo la
      // fine partita da un evento watch in ritardo): ignora.
      return;
    }
    if (result.newEvents.isNotEmpty) {
      try {
        await _repo.appendEvents(arg, result.newEvents);
      } catch (firstError, firstStack) {
        // Retry singolo: un errore SQLite transitorio non deve perdere il
        // punto appena segnato.
        try {
          await _repo.appendEvents(arg, result.newEvents);
        } catch (_) {
          await _restoreDurableState(
            current,
            'Punto non salvato. Il punteggio è stato ripristinato '
            'all’ultimo stato sicuro: libera spazio e riprova.',
          );
          Error.throwWithStackTrace(firstError, firstStack);
        }
      }
    }
    final duoTeam = current.duoTeam;
    var nextRow = current.row;
    String? persistenceMessage;
    final completedNow =
        result.state.isCompleted &&
        result.transitions.contains(ScoreTransition.matchWon);
    final reopenedFromComplete = current.score.isCompleted &&
        !result.state.isCompleted &&
        result.transitions.contains(ScoreTransition.undone);
    if (reopenedFromComplete) {
      // Allow side-effects (notify, health) to re-run after a later re-finish.
      _finalized = false;
    }
    try {
      if (completedNow) {
        final reconciled = await _repo.reconcileFromEventLog(arg);
        if (reconciled != null) nextRow = reconciled.row;
      } else if (result.state.status == MatchStatus.paused ||
          result.state.status == MatchStatus.inProgress) {
        // Reconcile clears stale summary/winner/end fields after undoing a
        // completed match, not just the status wire value.
        final reconciled = await _repo.reconcileFromEventLog(arg);
        if (reconciled != null) {
          nextRow = reconciled.row;
        } else {
          await _repo.setStatus(arg, result.state.status);
          nextRow = (await _repo.byId(arg)) ?? nextRow;
        }
      }
    } catch (_) {
      persistenceMessage = completedNow
          ? 'Punteggio salvato. Il riepilogo verrà finalizzato '
                'automaticamente alla riapertura.'
          : 'Punteggio salvato, aggiornamento dello stato in attesa.';
    }
    state = AsyncData(
      LiveMatchState(
        row: nextRow,
        format: current.format,
        score: result.state,
        canUndo: duoTeam == null ? engine.canUndo : engine.canUndoTeam(duoTeam),
        events: engine.events,
        lastTransitions: result.transitions,
        persistenceMessage: persistenceMessage,
      ),
    );
    if (completedNow && nextRow.status == MatchStatus.completed.wire) {
      unawaited(_afterLocalCompletion(nextRow));
    }
  }

  Future<void> _restoreDurableState(
    LiveMatchState current,
    String message,
  ) async {
    final row = (await _repo.byId(arg)) ?? current.row;
    final events = await _repo.eventsFor(arg);
    final duoTeam = row.duoMode && row.duoTeam != null
        ? TeamId.fromWire(row.duoTeam!)
        : null;
    final restored = PadelScoringEngine.replay(
      matchId: arg,
      format: current.format,
      events: events,
      duoMode: row.duoMode,
      assignedTeam: duoTeam,
      sourceUserId: row.duoMode ? ref.read(duoServiceProvider).userId : null,
    );
    _engine = restored;
    state = AsyncData(
      LiveMatchState(
        row: row,
        format: current.format,
        score: restored.state,
        canUndo: duoTeam == null
            ? restored.canUndo
            : restored.canUndoTeam(duoTeam),
        events: restored.events,
        persistenceMessage: message,
      ),
    );
  }

  Future<void> _afterLocalCompletion(MatchRow persistedRow) async {
    final engine = _engine;
    if (engine == null) return;
    if (!engine.state.isCompleted) return;
    if (_finalized) return;
    _finalized = true;
    unawaited(ref.read(matchScoringLockProvider).unlock(arg));
    if (persistedRow.duoMode) {
      // Sync di fine partita (priorità 3 del piano costi): assicura che la
      // timeline cloud sia completa. La chiusura server è a due fasi: ogni
      // partecipante deve aver rigiocato lo stesso high-water mark.
      try {
        await ref.read(duoServiceProvider).syncNow(arg);
      } catch (_) {
        // The durable local queue remains authoritative and is retried by the
        // foreground Duo synchronizer.
      }
    }
    try {
      await ref
          .read(notificationServiceProvider)
          .showMatchCompleted(score: engine.state.display, matchId: arg);
    } catch (_) {
      // A local notification is optional and must never roll back a match.
    }
    // Hybrid health: local match is authoritative; OS health data is imported
    // and associated afterwards without blocking completion.
    unawaited(_associateHealth(arg));
    // COMPLETED must reach the wearables so they never offer a resume for a
    // match that is already over.
    unawaited(_publishCompanionLifecycle('COMPLETED'));
    ref.invalidate(recentMatchesProvider);
    ref.invalidate(summariesProvider);
    // Classifiche di gruppo (Pro): ripubblica gli aggregati appena la
    // partita entra nello storico. Best-effort, mai bloccante.
    unawaited(_maybePublishGroupStats());
  }

  Future<void> _associateHealth(String matchId) async {
    try {
      await ref.read(matchHealthSyncProvider).associateCompletedMatch(matchId);
    } catch (_) {
      // Health association is best-effort; scoring is already durable.
    }
  }

  Future<void> _maybePublishGroupStats() async {
    try {
      final flag = await ref
          .read(keyValueRepoProvider)
          .get('has_friend_groups');
      if (flag == 'true') await publishGroupStats(ref);
    } catch (_) {
      // La classifica si riallinea alla prossima apertura dei gruppi.
    }
  }

  /// Engine access for the detail/wrapped views right after completion.
  PadelScoringEngine? get engine => _engine;
}

final liveMatchProvider = AsyncNotifierProvider.autoDispose
    .family<LiveMatchController, LiveMatchState, String>(
      LiveMatchController.new,
    );
