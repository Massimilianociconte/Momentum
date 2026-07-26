/// Sessione di allenamento guidata (premium): timer per esercizio,
/// pausa/salta, e a fine sessione registrazione RPE + minuti effettivi.
/// Il percorso free registra comunque RPE e durata dal riepilogo.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/padelandia_video_player.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/training_videos.dart';
import '../../data/db/database.dart';
import '../../services/notifications.dart';
import 'training_session_draft.dart';

typedef Drill = ({String name, int minutes, String note});

List<Drill> drillsOf(Training t) => [
  for (final d
      in (jsonDecode(t.drillsJson) as List).cast<Map<String, dynamic>>())
    (
      name: d['name'] as String? ?? '',
      minutes: (d['minutes'] as num?)?.toInt() ?? 5,
      note: d['note'] as String? ?? '',
    ),
];

/// Registra il completamento con RPE: unico punto di scrittura del log,
/// usato sia dal percorso guidato sia dal completamento manuale.
Future<void> logTrainingDone(
  BuildContext context,
  WidgetRef ref,
  Training t, {
  required int minutes,
}) async {
  final rpe = await _askRpe(context);
  await ref
      .read(trainingRepoProvider)
      .logCompletion(t.id, rpe: rpe ?? 0, minutes: minutes);
  await ref.read(notificationServiceProvider).showTrainingCompleted(t.title);
  await ref
      .read(notificationServiceProvider)
      .scheduleTrainingReminder(DateTime.now().add(const Duration(days: 3)));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rpe == null
              ? 'Allenamento completato! 💪'
              : 'Completato · RPE $rpe · $minutes min 💪',
        ),
      ),
    );
  }
}

/// Selettore sforzo percepito 1-10 (annullabile: il log si salva comunque).
Future<int?> _askRpe(BuildContext context) {
  var value = 6.0;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Quanto è stata dura?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _rpeLabel(value.round()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: RallyColors.lime,
              ),
            ),
            Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              label: '${value.round()}',
              onChanged: (v) => setLocal(() => value = v),
            ),
            const Text(
              'RPE (sforzo percepito): alimenta il tuo carico settimanale '
              'e i consigli di recupero.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Salta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, value.round()),
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}

String _rpeLabel(int rpe) => switch (rpe) {
  <= 2 => '$rpe · Molto leggero',
  <= 4 => '$rpe · Leggero',
  <= 6 => '$rpe · Impegnativo',
  <= 8 => '$rpe · Duro',
  _ => '$rpe · Massimale',
};

/// Avvia la sessione guidata a schermo intero (bottom sheet).
/// Optional [draft] resumes an interrupted session (local KV only).
Future<void> showGuidedSession(
  BuildContext context,
  WidgetRef ref,
  Training t, {
  TrainingSessionDraft? draft,
}) async {
  final result = await showModalBottomSheet<_SessionExit>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: RallyColors.night,
    builder: (_) => _GuidedSessionSheet(training: t, draft: draft),
  );
  final kv = ref.read(keyValueRepoProvider);
  if (result == null) return;
  switch (result.kind) {
    case _SessionExitKind.saved:
      await clearTrainingDraft(kv);
      if (context.mounted) {
        await logTrainingDone(
          context,
          ref,
          t,
          minutes: result.elapsedMinutes.clamp(1, 24 * 60),
        );
      }
    case _SessionExitKind.later:
      await saveTrainingDraft(
        kv,
        result.draft ??
            TrainingSessionDraft(
              trainingId: t.id,
              drillIndex: 0,
              remainingSeconds: 0,
              elapsedSeconds: result.elapsedMinutes * 60,
              savedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessione salvata in bozza. Riprendila dalla Home.'),
          ),
        );
      }
    case _SessionExitKind.discard:
      await clearTrainingDraft(kv);
  }
}

enum _SessionExitKind { saved, later, discard }

class _SessionExit {
  const _SessionExit.saved(this.elapsedMinutes)
      : kind = _SessionExitKind.saved,
        draft = null;
  const _SessionExit.later(this.draft)
      : kind = _SessionExitKind.later,
        elapsedMinutes = 0;
  const _SessionExit.discard()
      : kind = _SessionExitKind.discard,
        elapsedMinutes = 0,
        draft = null;

  final _SessionExitKind kind;
  final int elapsedMinutes;
  final TrainingSessionDraft? draft;
}

class _GuidedSessionSheet extends StatefulWidget {
  const _GuidedSessionSheet({required this.training, this.draft});
  final Training training;
  final TrainingSessionDraft? draft;

  @override
  State<_GuidedSessionSheet> createState() => _GuidedSessionSheetState();
}

class _GuidedSessionSheetState extends State<_GuidedSessionSheet>
    with WidgetsBindingObserver {
  late final List<Drill> _drills = drillsOf(widget.training);
  late int _index;
  late int _remainingSeconds;
  bool _paused = false;
  Timer? _timer;

  // Wall-clock based elapsed time to survive app backgrounding.
  late DateTime _startInstant;
  Duration _accumulatedPause = Duration.zero;
  DateTime? _pauseStart;
  late int _resumeBaseElapsed;

  int get _elapsedSeconds {
    final pausedExtra = _pauseStart != null
        ? DateTime.now().difference(_pauseStart!)
        : Duration.zero;
    final live = (DateTime.now().difference(_startInstant) -
            _accumulatedPause -
            pausedExtra)
        .inSeconds;
    return (_resumeBaseElapsed + live).clamp(0, 86400);
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null &&
        draft.trainingId == widget.training.id &&
        _drills.isNotEmpty) {
      _index = draft.drillIndex.clamp(0, _drills.length - 1);
      final maxRem = _drills[_index].minutes * 60;
      _remainingSeconds = draft.remainingSeconds.clamp(0, maxRem);
      _resumeBaseElapsed = draft.elapsedSeconds.clamp(0, 86400);
    } else {
      _index = 0;
      _remainingSeconds = _drills.isEmpty ? 0 : _drills.first.minutes * 60;
      _resumeBaseElapsed = 0;
    }
    _startInstant = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    // 1s UI tick only while sheet is open — no background work.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recompute on resume so backgrounded time is correctly counted.
    // Auto-pause when backgrounded to avoid draining battery on a running timer UI.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_paused && mounted) {
        setState(() {
          _paused = true;
          _pauseStart = DateTime.now();
        });
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  TrainingSessionDraft _currentDraft() {
    return TrainingSessionDraft(
      trainingId: widget.training.id,
      drillIndex: _index,
      remainingSeconds: _remainingSeconds,
      elapsedSeconds: _elapsedSeconds,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _tick() {
    if (_paused || !mounted) return;
    final drillDone = _remainingSeconds > 0 &&
        _remainingSeconds - 1 <= 0;
    setState(() {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      }
    });
    // Call _next outside setState to avoid Navigator.pop during build.
    if (drillDone) _next(auto: true);
  }

  void _next({bool auto = false}) {
    if (_index >= _drills.length - 1) {
      _finish();
      return;
    }
    _index++;
    _remainingSeconds = _drills[_index].minutes * 60;
  }

  void _finish() {
    _timer?.cancel();
    // Arrotonda per eccesso: 40 secondi di lavoro valgono 1 minuto.
    Navigator.pop(
      context,
      _SessionExit.saved((_elapsedSeconds / 60).ceil()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_drills.isEmpty) {
      // Template senza esercizi: niente da guidare.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.pop(context, const _SessionExit.discard()),
      );
      return const SizedBox.shrink();
    }
    final drill = _drills[_index];
    final total = drill.minutes * 60;
    final progress = total == 0 ? 0.0 : 1 - _remainingSeconds / total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.training.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_index + 1}/${_drills.length}',
                  style: const TextStyle(
                    color: RallyColors.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trainingVideoForDrill(drill.name) != null) ...[
              Center(
                child: PadelandiaVideoPlayer(
                  key: ValueKey('drill-video-$_index-${drill.name}'),
                  assetPath: trainingVideoForDrill(drill.name)!,
                  maxHeight: 240,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 148,
                    height: 148,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white10,
                          color: _paused ? Colors.white38 : RallyColors.lime,
                        ),
                        Center(
                          child: Text(
                            _fmt(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    drill.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (drill.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      drill.note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  onPressed: () => setState(() {
                    _paused = !_paused;
                    if (_paused) {
                      _pauseStart = DateTime.now();
                    } else if (_pauseStart != null) {
                      _accumulatedPause +=
                          DateTime.now().difference(_pauseStart!);
                      _pauseStart = null;
                    }
                  }),
                  iconSize: 30,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  tooltip: _paused ? 'Riprendi' : 'Pausa',
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(_next),
                  iconSize: 30,
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Prossimo esercizio',
                ),
                IconButton.filledTonal(
                  onPressed: _confirmEnd,
                  iconSize: 30,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Termina',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tempo totale ${_fmt(_elapsedSeconds)}',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminare la sessione?'),
        content: Text('Hai completato ${_fmt(_elapsedSeconds)} di lavoro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continua'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: const Text('Riprendi più tardi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Esci senza salvare'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Salva sessione'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') _finish();
    if (action == 'later') {
      _timer?.cancel();
      Navigator.pop(context, _SessionExit.later(_currentDraft()));
    }
    if (action == 'discard') {
      _timer?.cancel();
      Navigator.pop(context, const _SessionExit.discard());
    }
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
