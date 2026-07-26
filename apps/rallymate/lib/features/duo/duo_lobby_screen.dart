/// Duo Mode lobby: collega il secondo team con un codice temporaneo,
/// assegna gli smartwatch (uno per team) e avvia la partita condivisa.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../services/cloud/duo_service.dart';
import '../../services/watch_sync.dart';
import '../../services/wearable_match_dispatcher.dart';
import '../social/invite_share_sheet.dart';

class DuoLobbyScreen extends ConsumerStatefulWidget {
  const DuoLobbyScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<DuoLobbyScreen> createState() => _DuoLobbyScreenState();
}

class _DuoLobbyScreenState extends ConsumerState<DuoLobbyScreen>
    with WidgetsBindingObserver {
  MatchRow? _row;
  DuoSessionInfo? _session;
  Timer? _poll;
  bool _watchSent = false;
  bool _sendingWatch = false;
  bool _recoveringSession = false;
  String? _creationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Polling leggero: "In attesa di conferma dell'altro team…" si aggiorna
    // da solo, senza realtime dedicato. Pausa in background (vedi lifecycle).
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _load() async {
    final row = await ref.read(matchRepoProvider).byId(widget.matchId);
    if (!mounted) return;
    setState(() => _row = row);
    if (row != null && row.duoMode && row.duoSessionId == null) {
      await _recoverSession(row);
    } else {
      await _refresh();
    }
  }

  Future<void> _recoverSession([MatchRow? candidate]) async {
    if (_recoveringSession) return;
    final row = candidate ?? _row;
    if (row == null || row.duoSessionId != null) return;
    setState(() {
      _recoveringSession = true;
      _creationError = null;
    });
    try {
      final format = MatchFormat.fromJson(
        (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
      );
      final result = await ref
          .read(duoServiceProvider)
          .createSession(
            matchId: row.id,
            format: format,
            myTeam: row.duoTeam == null
                ? TeamId.a
                : TeamId.fromWire(row.duoTeam!),
          );
      final refreshed = await ref.read(matchRepoProvider).byId(row.id);
      if (!mounted) return;
      setState(() {
        _row = refreshed ?? row;
        _session = result.session;
        _creationError = result.error;
      });
      if (result.session != null) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _creationError =
              'Recupero non riuscito. Controlla la rete e riprova.',
        );
      }
    } finally {
      if (mounted) setState(() => _recoveringSession = false);
    }
  }

  Future<void> _refresh() async {
    final sid = _row?.duoSessionId;
    if (sid == null) return;
    final info = await ref.read(duoServiceProvider).sessionStatus(sid);
    if (!mounted || info == null) return;
    if (info.status == 'CANCELLED') {
      // L'altro team (o il creatore) ha annullato la sessione.
      _poll?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partita Duo annullata dall’altro team.')),
      );
      context.go('/home');
      return;
    }
    setState(() => _session = info);
  }

  TeamId get _myTeam =>
      _row?.duoTeam == null ? TeamId.a : TeamId.fromWire(_row!.duoTeam!);

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final code = _session?.joinCode ?? row?.duoJoinCode;
    final guestIn = _session?.guestJoined ?? false;
    final nativeWatchConnected = ref.watch(watchSyncProvider).connected;
    final providerWatchConnected = ref.watch(
      connectedDevicesProvider.select(
        (value) => value.value?.any(isScoringWearableReady) ?? false,
      ),
    );
    final watchConnected = nativeWatchConnected || providerWatchConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Duo Mode')),
      body: row == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _card(
                  title: 'IL TUO TEAM',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Slot canonico della timeline + prospettiva locale:
                        // per questo device il proprio team è sempre "Noi".
                        _myTeam == TeamId.a ? 'Team A · Noi' : 'Team B · Noi',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Questo telefono e il suo smartwatch segnano solo '
                        'i punti di questo team.',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (row.duoSessionId == null) ...[
                  _card(
                    title: 'COLLEGAMENTO CLOUD',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _creationError ??
                              'Sto recuperando la sessione con lo stesso '
                                  'identificativo sicuro.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _recoveringSession
                              ? null
                              : () => _recoverSession(),
                          icon: _recoveringSession
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _recoveringSession
                                ? 'Recupero…'
                                : 'Riprova collegamento',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _card(
                  title: 'INVITA L’ALTRO TEAM',
                  child: Column(
                    children: [
                      const Text(
                        'Fai inserire questo codice nell’app dell’altro '
                        'team (Nuova partita → Duo Mode → Ho un codice).',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: code == null
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Codice copiato'),
                                  ),
                                );
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: RallyColors.lime.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: RallyColors.lime.withValues(alpha: 0.5),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              code ?? '· · · · · · · ·',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                                color: RallyColors.lime,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (row.duoSessionId != null)
                        OutlinedButton.icon(
                          onPressed: () => showInviteShareSheet(
                            context,
                            ref,
                            kind: 'DUO',
                            matchId: row.id,
                            duoSessionId: row.duoSessionId,
                          ),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('Condividi link o QR sicuro'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!guestIn) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'In attesa di conferma dell’altro '
                              'team…',
                            ),
                          ] else ...[
                            const Icon(
                              Icons.check_circle,
                              color: RallyColors.win,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('L’altro team è collegato ✓'),
                          ],
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Il codice scade dopo 2 ore.',
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'IL TUO SMARTWATCH',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watchConnected
                            ? 'Watch collegato · segnerà solo i punti del '
                                  'tuo team'
                            : 'Watch non raggiungibile: puoi comunque '
                                  'segnare dal telefono.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: _sendingWatch ? null : _sendToWatch,
                        icon: Icon(_watchSent ? Icons.check : Icons.watch),
                        label: Text(
                          _watchSent
                              ? 'Inviato al watch ⌚'
                              : 'Assegna questo team al watch',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: row?.duoSessionId == null || _recoveringSession
                      ? null
                      : () => context.pushReplacement(
                          '/match/${widget.matchId}/live',
                        ),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    guestIn ? 'Avvia partita' : 'Avvia senza aspettare',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RallyColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Future<void> _sendToWatch() async {
    final row = _row;
    if (row == null) return;
    setState(() => _sendingWatch = true);
    try {
      final format = MatchFormat.fromJson(
        (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
      );
      final watchTeam = row.teamId == null
          ? null
          : await ref.read(teamRepoProvider).byId(row.teamId!);
      final delivery = await ref
          .read(wearableMatchDispatcherProvider)
          .startMatch(
            matchId: row.id,
            format: format,
            assignedTeam: _myTeam,
            teamName: watchTeam?.name,
            teamImagePath: watchTeam?.imageLocalPath,
            teamImageVersion: watchTeam?.imageVersion ?? 0,
            teamScoringStyle: watchTeam?.scoringStyle ?? 'AUTO',
          );
      if (!mounted) return;
      setState(() => _watchSent = delivery.sent);
      if (!delivery.sent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(delivery.message)));
      }
    } finally {
      if (mounted) setState(() => _sendingWatch = false);
    }
  }

  Future<void> _cancel() async {
    // La lobby è raggiungibile anche a partita in corso (scorciatoia dal
    // live): l'abbandono chiude la sessione per entrambi i team, quindi
    // va confermato esplicitamente.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abbandonare la partita Duo?'),
        content: const Text(
          'Il collegamento con l’altro team verrà chiuso. Gli eventi già '
          'segnati restano salvati sul telefono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, resta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    var info = _session;
    if (info == null) {
      if (_row?.duoSessionId == null) {
        await _recoverSession();
      } else {
        await _refresh();
      }
      info = _session;
    }
    if (!mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile confermare la chiusura cloud. Controlla la rete e '
            'riprova: la partita locale resta recuperabile.',
          ),
        ),
      );
      return;
    }
    final left = await ref.read(duoServiceProvider).leaveSession(info);
    if (!mounted) return;
    if (!left) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chiusura cloud non confermata. La partita resta disponibile.',
          ),
        ),
      );
      return;
    }
    await ref
        .read(matchRepoProvider)
        .setStatus(widget.matchId, MatchStatus.abandoned);
    // A terminal lifecycle must reach every companion before the lobby leaves:
    // otherwise an old START_MATCH application context can reopen the match
    // after the watch app is closed.
    await ref
        .read(watchSyncProvider.notifier)
        .sendMatchLifecycle(
          matchId: widget.matchId,
          action: 'ABANDONED',
          status: MatchStatus.abandoned.wire,
        );
    if (mounted) context.go('/home');
  }
}
