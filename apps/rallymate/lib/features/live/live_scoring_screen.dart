/// Live scoring (PRD Modulo D): due pulsanti grandi, undo, Blind Mode,
/// vibrazioni, mascotte non invadente.
///
/// Battery: screen wakelock only while match is actively in progress and the
/// app is foregrounded — released on pause, completion, background, dispose.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/providers.dart';
import '../../core/team_visuals.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../services/cloud/duo_service.dart';
import '../../services/match_scoring_lock.dart';
import '../../services/voice_scoring.dart';
import '../../services/wearable_match_dispatcher.dart';
import '../rules/rules_assistant_screen.dart';
import '../social/invite_share_sheet.dart';
import 'live_match_controller.dart';

enum _StarPointEditPhase {
  deuceOne(1),
  advantageOneA(1, TeamId.a),
  advantageOneB(1, TeamId.b),
  deuceTwo(2),
  advantageTwoA(2, TeamId.a),
  advantageTwoB(2, TeamId.b),
  starPoint(3);

  const _StarPointEditPhase(this.deuceNumber, [this.advantage]);

  final int deuceNumber;
  final TeamId? advantage;

  static _StarPointEditPhase fromPoints(GamePoints points) {
    if (points.advantage == TeamId.a) {
      return points.deuceNumber <= 1 ? advantageOneA : advantageTwoA;
    }
    if (points.advantage == TeamId.b) {
      return points.deuceNumber <= 1 ? advantageOneB : advantageTwoB;
    }
    if (points.deuceNumber >= 3) return starPoint;
    if (points.deuceNumber == 2) return deuceTwo;
    return deuceOne;
  }
}

bool _isStarPointPhaseScore(int pointsA, int pointsB) =>
    (pointsA == 3 && pointsB == 3) ||
    (pointsA == 4 && pointsB == 3) ||
    (pointsA == 3 && pointsB == 4);

_StarPointEditPhase _phaseForEditedPoints(
  int pointsA,
  int pointsB,
  _StarPointEditPhase current,
) {
  final secondCycle = current.deuceNumber >= 2;
  if (pointsA == 4 && pointsB == 3) {
    return secondCycle
        ? _StarPointEditPhase.advantageTwoA
        : _StarPointEditPhase.advantageOneA;
  }
  if (pointsA == 3 && pointsB == 4) {
    return secondCycle
        ? _StarPointEditPhase.advantageTwoB
        : _StarPointEditPhase.advantageOneB;
  }
  return current;
}

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({
    super.key,
    required this.matchId,
    this.resumeOnOpen = false,
  });
  final String matchId;
  final bool resumeOnOpen;

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen>
    with WidgetsBindingObserver {
  bool _blindMode = false;
  final _voice = VoiceScoring();
  bool _listening = false;
  bool _resumeRequested = false;

  /// Auto-complete: short undo window before report (like watch ports).
  bool _matchWinInterstitial = false;
  Timer? _matchWinTimer;
  int _matchWinSecondsLeft = 0;
  bool _wakelockHeld = false;
  bool _appInForeground = true;

  static const _matchWinWindow = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchWinTimer?.cancel();
    unawaited(_voice.cancel());
    unawaited(_releaseWakelock());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Battery: never keep screen on while backgrounded / inactive.
    _appInForeground = state == AppLifecycleState.resumed;
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    unawaited(_syncWakelock(live));
  }

  Future<void> _syncWakelock(LiveMatchState? live) async {
    final want =
        _appInForeground &&
        live != null &&
        !_matchWinInterstitial &&
        canAcceptLocalPoint(live.score.status);
    if (want == _wakelockHeld) return;
    try {
      if (want) {
        await WakelockPlus.enable();
        _wakelockHeld = true;
      } else {
        await WakelockPlus.disable();
        _wakelockHeld = false;
      }
    } catch (_) {
      // Platform may deny; scoring remains usable without keep-awake.
      _wakelockHeld = false;
    }
  }

  Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    _wakelockHeld = false;
  }

  void _cancelMatchWinWindow() {
    _matchWinTimer?.cancel();
    _matchWinTimer = null;
    if (_matchWinInterstitial && mounted) {
      setState(() {
        _matchWinInterstitial = false;
        _matchWinSecondsLeft = 0;
      });
    } else {
      _matchWinInterstitial = false;
      _matchWinSecondsLeft = 0;
    }
  }

  void _startMatchWinWindow() {
    if (_matchWinInterstitial) return;
    _matchWinTimer?.cancel();
    setState(() {
      _matchWinInterstitial = true;
      _matchWinSecondsLeft = _matchWinWindow.inSeconds;
    });
    unawaited(_releaseWakelock());
    _matchWinTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_matchWinSecondsLeft <= 1) {
        t.cancel();
        _goToReport();
        return;
      }
      setState(() => _matchWinSecondsLeft--);
    });
  }

  void _goToReport() {
    _matchWinTimer?.cancel();
    _matchWinTimer = null;
    _matchWinInterstitial = false;
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      context.pushReplacement('/match/${widget.matchId}');
    }
  }

  Future<void> _undoMatchWin() async {
    _cancelMatchWinWindow();
    await ref.read(liveMatchProvider(widget.matchId).notifier).undo();
    if (!mounted) return;
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    unawaited(_syncWakelock(live));
  }

  void _haptics(List<ScoreTransition> transitions) {
    // PRD D1: breve = punto, doppia = undo, lunga = game/set.
    if (transitions.contains(ScoreTransition.matchWon) ||
        transitions.contains(ScoreTransition.setWon) ||
        transitions.contains(ScoreTransition.gameWon)) {
      HapticFeedback.heavyImpact();
    } else if (transitions.contains(ScoreTransition.undone)) {
      HapticFeedback.mediumImpact();
      Future.delayed(
        const Duration(milliseconds: 120),
        HapticFeedback.mediumImpact,
      );
    } else if (transitions.contains(ScoreTransition.point)) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveMatchProvider(widget.matchId));

    final loaded = async.valueOrNull;
    if (widget.resumeOnOpen &&
        !_resumeRequested &&
        loaded?.score.status == MatchStatus.paused) {
      _resumeRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(liveMatchProvider(widget.matchId).notifier).resume();
      });
    }

    // Keep-awake tracks live state without holding during pause/complete.
    unawaited(_syncWakelock(loaded));

    ref.listen(liveMatchProvider(widget.matchId), (prev, next) {
      final s = next.valueOrNull;
      if (s == null) return;
      _haptics(s.lastTransitions);
      unawaited(_syncWakelock(s));
      final message = s.persistenceMessage;
      if (message != null &&
          message != prev?.valueOrNull?.persistenceMessage &&
          mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        });
      }
      final becameComplete =
          s.score.isCompleted &&
          s.row.status == MatchStatus.completed.wire &&
          prev?.valueOrNull?.score.isCompleted != true;
      if (becameComplete && mounted) {
        // Auto match-win: undo window. Manual finish navigates itself.
        final autoWin = s.lastTransitions.contains(ScoreTransition.matchWon);
        if (autoWin && ModalRoute.of(context)?.isCurrent == true) {
          _startMatchWinWindow();
        }
      }
      if (!s.score.isCompleted && _matchWinInterstitial) {
        _cancelMatchWinWindow();
      }
    });

    // Duo Mode: mantiene vivo il polling push/pull della sessione condivisa
    // finché questa schermata è aperta.
    if (async.valueOrNull?.isDuo == true) {
      ref.watch(duoLiveSyncProvider(widget.matchId));
    }

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (live) {
        final child = _blindMode ? _blind(live) : _normal(live);
        if (!_matchWinInterstitial) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            _MatchWinInterstitial(
              scoreDisplay: live.score.display,
              secondsLeft: _matchWinSecondsLeft,
              canUndo: live.canUndo,
              onUndo: live.canUndo ? _undoMatchWin : null,
              onReport: _goToReport,
            ),
          ],
        );
      },
    );
  }

  /// Etichette team: in Duo Mode la timeline è canonica (A/B) e "NOI" è il
  /// team assegnato a questo device.
  String _teamLabel(TeamId team, TeamId? duoTeam) {
    if (duoTeam == null) return team == TeamId.a ? 'NOI' : 'LORO';
    return team == duoTeam ? 'NOI' : 'LORO';
  }

  Color _teamColor(TeamId team, TeamId? duoTeam) {
    if (duoTeam == null) {
      return team == TeamId.a ? RallyColors.teamUs : RallyColors.teamThem;
    }
    return team == duoTeam ? RallyColors.teamUs : RallyColors.teamThem;
  }

  String _starPointPhaseLabel(_StarPointEditPhase phase, TeamId? duoTeam) {
    if (phase == _StarPointEditPhase.starPoint) return 'Star Point';
    final advantage = phase.advantage;
    if (advantage == null) return 'Parità ${phase.deuceNumber}';
    return 'Vantaggio ${phase.deuceNumber} '
        '${_teamLabel(advantage, duoTeam)}';
  }

  // ------------------------------------------------------------- normale

  Widget _normal(LiveMatchState live) {
    final s = live.score;
    final paused = s.status == MatchStatus.paused;
    final ctrl = ref.read(liveMatchProvider(widget.matchId).notifier);
    final freePlay = live.format.freePlay;
    final duoTeam = live.duoTeam;
    final teamId = live.row.teamId;
    final localTeams = ref.watch(teamsProvider).valueOrNull ?? const <Team>[];
    Team? selectedTeam;
    if (teamId != null) {
      for (final team in localTeams) {
        if (team.id == teamId) {
          selectedTeam = team;
          break;
        }
      }
    }
    final visualTeam = selectedTeam;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(ctrl));
      },
      child: Scaffold(
        appBar: AppBar(
          title: _MatchClock(
            events: live.events,
            fallbackStartTimeMs: live.row.startTimeMs,
            fallbackEndTimeMs: live.row.endTimeMs,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmExit(ctrl),
          ),
          actions: [
            IconButton(
              tooltip: 'Comando vocale',
              icon: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: _listening ? RallyColors.lime : null,
              ),
              onPressed: _listening ? null : _voiceCommand,
            ),
            IconButton(
              tooltip: 'Pallino e regole',
              icon: const Icon(
                Icons.auto_awesome_rounded,
                color: RallyColors.lime,
              ),
              onPressed: _quickRules,
            ),
            PopupMenuButton<String>(
              tooltip: 'Altre azioni partita',
              onSelected: (value) {
                switch (value) {
                  case 'blind':
                    setState(() => _blindMode = true);
                    return;
                  case 'invite':
                    showInviteShareSheet(
                      context,
                      ref,
                      kind: 'MATCH',
                      matchId: widget.matchId,
                    );
                    return;
                  case 'duo':
                    context.push('/match/${widget.matchId}/duo');
                    return;
                  case 'to_watch':
                    unawaited(_sendToWatch(live));
                    return;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'blind',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.visibility_off_outlined),
                    title: Text('Blind Mode'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'to_watch',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.watch_outlined),
                    title: Text('Invia al watch'),
                  ),
                ),
                PopupMenuItem(
                  value: live.isDuo ? 'duo' : 'invite',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      live.isDuo ? Icons.qr_code_2 : Icons.person_add_alt_1,
                    ),
                    title: Text(
                      live.isDuo
                          ? 'Duo, invito e watch'
                          : 'Invita alla partita',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (live.persistenceMessage != null)
                FutureBuilder<bool>(
                  future: ref
                      .read(matchScoringLockProvider)
                      .isPhoneScoringBlocked(widget.matchId),
                  builder: (context, snap) {
                    final blocked = snap.data == true;
                    final msg = live.persistenceMessage!;
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: RallyColors.lime.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RallyColors.lime.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            blocked ? Icons.watch : Icons.info_outline_rounded,
                            color: RallyColors.lime,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              msg,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (blocked)
                            TextButton(
                              onPressed: () => ctrl.reclaimPhoneScoring(),
                              child: const Text('Telefono'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              if (paused)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: RallyColors.teamGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RallyColors.teamGold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pause_circle_outline,
                        color: RallyColors.teamGold,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Partita sospesa: riprendila prima di segnare.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: ctrl.resume,
                        child: const Text('Riprendi'),
                      ),
                    ],
                  ),
                ),
              if (live.isDuo)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: RallyColors.lime.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RallyColors.lime.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⌚⌚ ', style: TextStyle(fontSize: 13)),
                      Flexible(
                        child: Text(
                          'Duo Mode · questo dispositivo segna solo i punti '
                          'di ${duoTeam == null ? 'NOI' : _teamLabel(duoTeam, duoTeam)} '
                          '· partita sincronizzata',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: RallyColors.lime,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _scoreHeader(s, live.format, freePlay, duoTeam),
              if (s.sideChangePending)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: RallyColors.court,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Cambio campo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _pointButton(
                          _teamLabel(TeamId.a, duoTeam),
                          _teamColor(TeamId.a, duoTeam),
                          !paused && (duoTeam == null || duoTeam == TeamId.a)
                              ? visualTeam
                              : null,
                          paused || (duoTeam != null && duoTeam != TeamId.a)
                              ? null
                              : () => ctrl.point(TeamId.a),
                          allowManualEdit: !paused && !live.isDuo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pointButton(
                          _teamLabel(TeamId.b, duoTeam),
                          _teamColor(TeamId.b, duoTeam),
                          !paused && duoTeam == TeamId.b ? visualTeam : null,
                          paused || (duoTeam != null && duoTeam != TeamId.b)
                              ? null
                              : () => ctrl.point(TeamId.b),
                          allowManualEdit: !paused && !live.isDuo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !paused && live.canUndo ? ctrl.undo : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('Annulla'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmExit(ctrl),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Termina'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreHeader(
    MatchState s,
    MatchFormat format,
    bool freePlay, [
    TeamId? duoTeam,
  ]) {
    final serveA = s.servingTeam == TeamId.a;
    final pointSituation = freePlay || s.inTieBreak || s.inSuperTieBreak
        ? null
        : s.points.situationLabel(
            gameScoringMode: format.gameScoringMode,
            teamALabel: _teamLabel(TeamId.a, duoTeam),
            teamBLabel: _teamLabel(TeamId.b, duoTeam),
          );
    final isStarPoint =
        format.gameScoringMode == GameScoringMode.starPoint &&
        s.points.isStarPoint;
    const starPointInstruction =
        'Chi risponde sceglie il lato · nei misti riceve chi ha lo stesso '
        'sesso del battitore';
    final situationColor = isStarPoint
        ? RallyColors.teamGold
        : s.points.advantage == null
        ? RallyColors.lime
        : _teamColor(s.points.advantage!, duoTeam);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: RallyColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: RallyColors.glow(RallyColors.court, blur: 16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _teamScore(
                _teamLabel(TeamId.a, duoTeam),
                _teamColor(TeamId.a, duoTeam),
                serveA,
                s,
                TeamId.a,
                freePlay,
              ),
              Column(
                children: [
                  Text(
                    '${s.setsA} - ${s.setsB}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'SET',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
              _teamScore(
                _teamLabel(TeamId.b, duoTeam),
                _teamColor(TeamId.b, duoTeam),
                !serveA,
                s,
                TeamId.b,
                freePlay,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!freePlay)
            Text(
              s.inTieBreak || s.inSuperTieBreak
                  ? (s.inSuperTieBreak ? 'SUPER TIE-BREAK' : 'TIE-BREAK')
                  : 'Game ${s.gamesA} - ${s.gamesB}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: s.inTieBreak || s.inSuperTieBreak
                    ? RallyColors.lime
                    : Colors.white54,
              ),
            ),
          if (pointSituation != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                label: isStarPoint
                    ? '$pointSituation. $starPointInstruction'
                    : pointSituation,
                excludeSemantics: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    key: ValueKey(pointSituation),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: situationColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: situationColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pointSituation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: situationColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isStarPoint) ...[
                          const SizedBox(height: 4),
                          const Text(
                            starPointInstruction,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: RallyColors.teamGold,
                              fontSize: 10,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (s.completedSets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                s.completedSets
                    .map(
                      (x) => x.isSuperTieBreak
                          ? 'STB ${x.tieBreakA}-${x.tieBreakB}'
                          : '${x.gamesA}-${x.gamesB}',
                    )
                    .join('  ·  '),
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamScore(
    String label,
    Color color,
    bool serving,
    MatchState s,
    TeamId team,
    bool freePlay,
  ) {
    final String points;
    if (freePlay) {
      points = team == TeamId.a ? '${s.freePlayA}' : '${s.freePlayB}';
    } else if (s.inTieBreak || s.inSuperTieBreak) {
      points = team == TeamId.a ? '${s.tieBreakA}' : '${s.tieBreakB}';
    } else {
      points = s.points.labelFor(team);
    }
    return Column(
      children: [
        Row(
          children: [
            if (serving)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(
              begin: 1.35,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            points,
            key: ValueKey(points),
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pointButton(
    String label,
    Color color,
    Team? team,
    VoidCallback? onTap, {
    required bool allowManualEdit,
  }) {
    // Duo Mode: onTap null = team dell'altro device, pulsante disattivato.
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: enabled
              ? RallyColors.glow(color, blur: 14)
              : const <BoxShadow>[],
        ),
        child: TeamScoringSurface(
          team: team,
          enabled: enabled,
          onTap: onTap ?? () {},
          // A full-score edit in Duo Mode would let one device rewrite the
          // other team. Corrections remain event-scoped through Undo.
          onLongPress: allowManualEdit ? _manualEdit : null,
          semanticLabel: '$label, aggiungi un punto',
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: team != null ? Colors.white : color,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- blind mode

  Widget _blind(LiveMatchState live) {
    final ctrl = ref.read(liveMatchProvider(widget.matchId).notifier);
    final duoTeam = live.duoTeam;
    final us = duoTeam ?? TeamId.a;
    final them = us == TeamId.a ? TeamId.b : TeamId.a;
    // Same exit protection as normal mode — accidental back loses the court.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(ctrl));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Noi, aggiungi un punto',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ctrl.point(us, method: SourceMethod.blindTap),
                        child: Container(
                          color: RallyColors.teamUs.withValues(alpha: 0.05),
                          alignment: Alignment.center,
                          child: const Text(
                            'NOI',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.white12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      enabled: duoTeam == null,
                      label: 'Loro, aggiungi un punto',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: duoTeam != null
                            ? null
                            : () => ctrl.point(
                                them,
                                method: SourceMethod.blindTap,
                              ),
                        child: Container(
                          color: RallyColors.teamThem.withValues(alpha: 0.05),
                          alignment: Alignment.center,
                          child: Text(
                            'LORO',
                            style: TextStyle(
                              color: duoTeam != null
                                  ? Colors.white12
                                  : Colors.white38,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Punteggio ${live.score.display}',
                    child: Text(
                      live.score.display,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ctrl.undo(),
                        icon: const Icon(Icons.undo, color: Colors.white70),
                        label: const Text(
                          'Annulla',
                          style: TextStyle(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _blindMode = false),
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.white54,
                        ),
                        label: const Text(
                          'Esci Blind',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- dialoghi

  Future<void> _manualEdit() async {
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    if (live == null) return;
    final s = live.score;
    final freePlay = live.format.freePlay;
    var pa = s.points.a, pb = s.points.b, ga = s.gamesA, gb = s.gamesB;
    var fpa = s.freePlayA, fpb = s.freePlayB;
    var starPointPhase = _StarPointEditPhase.fromPoints(s.points);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(freePlay ? 'Correzione allenamento' : 'Correzione manuale'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (freePlay) ...[
                _stepper(
                  'Punti NOI',
                  fpa,
                  null,
                  (v) => setLocal(() => fpa = v),
                  maxValue: 99,
                ),
                _stepper(
                  'Punti LORO',
                  fpb,
                  null,
                  (v) => setLocal(() => fpb = v),
                  maxValue: 99,
                ),
              ] else ...[
                _stepper(
                  'Punti NOI',
                  pa,
                  GamePoints.labels,
                  (v) => setLocal(() {
                    pa = v;
                    starPointPhase = _phaseForEditedPoints(
                      pa,
                      pb,
                      starPointPhase,
                    );
                  }),
                ),
                _stepper(
                  'Punti LORO',
                  pb,
                  GamePoints.labels,
                  (v) => setLocal(() {
                    pb = v;
                    starPointPhase = _phaseForEditedPoints(
                      pa,
                      pb,
                      starPointPhase,
                    );
                  }),
                ),
                _stepper('Game NOI', ga, null, (v) => setLocal(() => ga = v)),
                _stepper('Game LORO', gb, null, (v) => setLocal(() => gb = v)),
                if (live.format.gameScoringMode == GameScoringMode.starPoint &&
                    _isStarPointPhaseScore(pa, pb)) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Fase Star Point',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label:
                        'Fase Star Point corrente: '
                        '${_starPointPhaseLabel(starPointPhase, live.duoTeam)}',
                    child: DropdownButtonFormField<_StarPointEditPhase>(
                      key: ValueKey(starPointPhase),
                      initialValue: starPointPhase,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fase sul 40 pari',
                        isDense: true,
                      ),
                      items: [
                        for (final phase in _StarPointEditPhase.values)
                          DropdownMenuItem(
                            value: phase,
                            child: Text(
                              _starPointPhaseLabel(phase, live.duoTeam),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocal(() => starPointPhase = value);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Applica'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final ctrl = ref.read(liveMatchProvider(widget.matchId).notifier);
      if (freePlay) {
        await ctrl.edit(
          pointsA: 0,
          pointsB: 0,
          gamesA: 0,
          gamesB: 0,
          freePlayA: fpa,
          freePlayB: fpb,
        );
      } else {
        final isStarPointPhase =
            live.format.gameScoringMode == GameScoringMode.starPoint &&
            _isStarPointPhaseScore(pa, pb);
        final advantage = isStarPointPhase ? starPointPhase.advantage : null;
        await ctrl.edit(
          pointsA: isStarPointPhase ? (advantage == TeamId.a ? 4 : 3) : pa,
          pointsB: isStarPointPhase ? (advantage == TeamId.b ? 4 : 3) : pb,
          gamesA: ga,
          gamesB: gb,
          deuceNumber: live.format.gameScoringMode == GameScoringMode.starPoint
              ? (isStarPointPhase ? starPointPhase.deuceNumber : 0)
              : null,
        );
      }
    }
  }

  Widget _stepper(
    String label,
    int value,
    List<String>? labels,
    ValueChanged<int> on, {
    int maxValue = 7,
  }) {
    final max = labels != null ? labels.length - 1 : maxValue;
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 0 ? () => on(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: Text(
              labels != null && value < labels.length
                  ? labels[value]
                  : '$value',
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => on(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  /// Mid-match handoff: phone journal is attached by sendMatchToWatch.
  Future<void> _sendToWatch(LiveMatchState live) async {
    final delivery = await ref
        .read(wearableMatchDispatcherProvider)
        .startMatch(
          matchId: widget.matchId,
          format: live.format,
          assignedTeam: live.duoTeam,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(delivery.message)));
  }

  Future<void> _confirmExit(LiveMatchController ctrl) async {
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    final myTeam = live?.duoTeam ?? TeamId.a;
    final otherTeam = myTeam == TeamId.a ? TeamId.b : TeamId.a;
    // Single sheet: pause + winner + stay (fewer taps under stress).
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RallyColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Esci dalla partita',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Scegli come chiudere o metti in pausa.'),
            ),
            ListTile(
              leading: const Icon(
                Icons.emoji_events_outlined,
                color: RallyColors.lime,
              ),
              title: const Text('Termina · Noi vincono'),
              onTap: () => Navigator.pop(ctx, 'win_us'),
            ),
            ListTile(
              leading: const Icon(Icons.sports_tennis_outlined),
              title: const Text('Termina · Loro vincono'),
              onTap: () => Navigator.pop(ctx, 'win_them'),
            ),
            ListTile(
              leading: const Icon(Icons.pause),
              title: const Text('Sospendi'),
              subtitle: const Text('Riprendi più tardi dalla home'),
              onTap: () => Navigator.pop(ctx, 'pause'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Continua a giocare'),
              onTap: () => Navigator.pop(ctx, 'stay'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    switch (choice) {
      case 'win_us':
        await ctrl.finishManually(winner: myTeam);
        if (mounted) context.pushReplacement('/match/${widget.matchId}');
      case 'win_them':
        await ctrl.finishManually(winner: otherTeam);
        if (mounted) context.pushReplacement('/match/${widget.matchId}');
      case 'pause':
        await ctrl.pause();
        if (mounted) context.go('/home');
    }
  }

  /// PRD D3: tap microfono → ascolto 3-5s → comando chiuso → conferma
  /// aptica → chiusura ascolto. Nessun ascolto continuo.
  Future<void> _voiceCommand() async {
    final ctrl = ref.read(liveMatchProvider(widget.matchId).notifier);
    setState(() => _listening = true);
    try {
      final cmd = await _voice.listenOnce();
      if (!mounted) return;
      final duoTeam = ref
          .read(liveMatchProvider(widget.matchId))
          .valueOrNull
          ?.duoTeam;
      final us = duoTeam ?? TeamId.a;
      final them = us == TeamId.a ? TeamId.b : TeamId.a;
      switch (cmd) {
        case VoiceCommand.pointUs:
          await ctrl.point(us, method: SourceMethod.voice);
        case VoiceCommand.pointThem:
          if (duoTeam != null) {
            // Duo: this device only scores its own team.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('In Duo Mode segna solo i punti del tuo team.'),
                ),
              );
            }
          } else {
            await ctrl.point(them, method: SourceMethod.voice);
          }
        case VoiceCommand.undo:
          await ctrl.undo();
        case VoiceCommand.pause:
          await ctrl.pause();
        case VoiceCommand.resume:
          await ctrl.resume();
        case VoiceCommand.finish:
          final finished = await _finishWithWinner(ctrl);
          if (finished && mounted) {
            context.pushReplacement('/match/${widget.matchId}');
          }
        case null:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_voiceFailureMessage(_voice.lastFailure))),
            );
          }
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  String _voiceFailureMessage(VoiceFailure? failure) => switch (failure) {
    VoiceFailure.permissionDenied =>
      'Abilita Microfono e Riconoscimento vocale nelle impostazioni.',
    VoiceFailure.unavailable =>
      'Il riconoscimento vocale non è disponibile su questo dispositivo.',
    VoiceFailure.busy => 'Il microfono è già in uso. Riprova tra poco.',
    VoiceFailure.timeout =>
      'Tempo scaduto. Tocca il microfono e pronuncia un comando breve.',
    VoiceFailure.recognitionError =>
      'Riconoscimento non riuscito. Controlla la connessione o riprova.',
    VoiceFailure.noMatch ||
    null => 'Non ho capito. Prova: "Noi", "Loro", "Annulla" o "Pausa".',
  };

  Future<bool> _finishWithWinner(LiveMatchController ctrl) async {
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    if (live == null) return false;
    final myTeam = live.duoTeam ?? TeamId.a;
    final otherTeam = myTeam == TeamId.a ? TeamId.b : TeamId.a;
    final winner = await showModalBottomSheet<TeamId>(
      context: context,
      backgroundColor: RallyColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Chi ha vinto?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Serve un vincitore per salvare statistiche corrette.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Noi'),
              onTap: () => Navigator.pop(sheetContext, myTeam),
            ),
            ListTile(
              leading: const Icon(Icons.sports_tennis_outlined),
              title: const Text('Loro'),
              onTap: () => Navigator.pop(sheetContext, otherTeam),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Continua a giocare'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (winner == null || !mounted) return false;
    await ctrl.finishManually(winner: winner);
    return true;
  }

  void _quickRules() {
    // PRD E1: mascotte durante la partita = bottom sheet, non invadente.
    final live = ref.read(liveMatchProvider(widget.matchId)).valueOrNull;
    final ctx = live == null
        ? null
        : 'Punteggio attuale: ${live.score.display}. '
              'Formato: ${live.row.formatJson}.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RallyColors.night,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, controller) => RulesAssistantSheet(
          scrollController: controller,
          matchId: widget.matchId,
          matchContext: ctx,
        ),
      ),
    );
  }
}

/// Orologio partita autonomo: il tick da 1s fa il rebuild solo di questo
/// Text, mai dell'intero albero di scoring.
class _MatchClock extends StatefulWidget {
  const _MatchClock({
    required this.events,
    required this.fallbackStartTimeMs,
    required this.fallbackEndTimeMs,
  });

  final List<MatchEvent> events;
  final int? fallbackStartTimeMs;
  final int? fallbackEndTimeMs;

  @override
  State<_MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<_MatchClock> {
  Timer? _ticker;
  late Duration _elapsed = _currentElapsed();

  Duration _currentElapsed() => matchActiveElapsed(
    events: widget.events,
    fallbackStartTimeMs: widget.fallbackStartTimeMs,
    fallbackEndTimeMs: widget.fallbackEndTimeMs,
  );

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _currentElapsed());
    });
  }

  @override
  void didUpdateWidget(covariant _MatchClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _elapsed = _currentElapsed();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = _elapsed;
    return Text(
      '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}',
    );
  }
}

Duration matchElapsedFromStart(int? startTimeMs, {DateTime? clock}) {
  if (startTimeMs == null) return Duration.zero;
  final nowMs = (clock ?? DateTime.now()).millisecondsSinceEpoch;
  return Duration(
    milliseconds: (nowMs - startTimeMs).clamp(0, 12 * 60 * 60 * 1000).toInt(),
  );
}

Duration matchActiveElapsed({
  required Iterable<MatchEvent> events,
  int? fallbackStartTimeMs,
  int? fallbackEndTimeMs,
  DateTime? clock,
}) => Duration(
  milliseconds: activeMatchDurationMs(
    events: events,
    fallbackStartTimeMs: fallbackStartTimeMs,
    fallbackEndTimeMs: fallbackEndTimeMs,
    nowMs: clock?.millisecondsSinceEpoch,
  ),
);

/// Short post-match undo window (battery-light: no animation loops).
class _MatchWinInterstitial extends StatelessWidget {
  const _MatchWinInterstitial({
    required this.scoreDisplay,
    required this.secondsLeft,
    required this.canUndo,
    required this.onUndo,
    required this.onReport,
  });

  final String scoreDisplay;
  final int secondsLeft;
  final bool canUndo;
  final Future<void> Function()? onUndo;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'MATCH',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: RallyColors.lime,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                scoreDisplay,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                canUndo
                    ? 'Puoi annullare l’ultimo punto ($secondsLeft s)'
                    : 'Partita salvata · apri il report',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              if (canUndo && onUndo != null) ...[
                FilledButton.icon(
                  onPressed: () => onUndo!(),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Annulla ultimo punto'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: RallyColors.lime,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(
                  canUndo ? 'Vai al report ($secondsLeft)' : 'Vai al report',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
