/// Match report: risultato, stats base free, analytics premium
/// (momentum, clutch, punti decisivi) e accesso alla Wrapped card.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/brand.dart';
import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../domain/entitlements.dart';
import '../../domain/health_provider.dart';
import '../../services/match_health_sync.dart';

final matchDetailProvider = FutureProvider.autoDispose
    .family<
      ({
        MatchRow row,
        PadelScoringEngine engine,
        MatchStats stats,
        AdvancedMatchAnalysis advanced,
      }),
      String
    >((ref, id) async {
      final repo = ref.watch(matchRepoProvider);
      final row = await repo.byId(id);
      if (row == null) throw StateError('Match non trovato');
      final events = await repo.eventsFor(id);
      final format = MatchFormat.fromJson(
        (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
      );
      final engine = PadelScoringEngine.replay(
        matchId: id,
        format: format,
        events: events,
        firstServer: row.firstServerTeam,
      );
      final stats = MatchStats.fromRecords(
        engine.pointRecords,
        durationMsOverride: activeMatchDurationMs(
          events: engine.events,
          fallbackStartTimeMs: row.startTimeMs,
          fallbackEndTimeMs: row.endTimeMs,
        ),
      );
      final myTeam = row.duoMode && row.duoTeam != null
          ? TeamId.fromWire(row.duoTeam!)
          : TeamId.a;
      final advanced = AdvancedMatchAnalytics.analyze(
        records: engine.pointRecords,
        format: format,
        perspectiveTeam: myTeam,
        matchWinner: engine.state.winner,
      );
      return (row: row, engine: engine, stats: stats, advanced: advanced);
    });

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchDetailProvider(matchId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (d) => _Detail(d.row, d.engine, d.stats, d.advanced),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail(this.row, this.engine, this.stats, this.advanced);
  final MatchRow row;
  final PadelScoringEngine engine;
  final MatchStats stats;
  final AdvancedMatchAnalysis advanced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = engine.state;
    // Duo Mode: la timeline è canonica (A/B), la prospettiva è il team
    // assegnato a questo device.
    final myTeam = row.duoMode && row.duoTeam != null
        ? TeamId.fromWire(row.duoTeam!)
        : TeamId.a;
    final won = s.winner == myTeam;
    final mirror = myTeam == TeamId.b;
    final us = myTeam == TeamId.a ? stats.teamA : stats.teamB;
    final them = myTeam == TeamId.a ? stats.teamB : stats.teamA;

    final scoreLine = s.completedSets.isEmpty
        ? (mirror
              ? '${s.freePlayB} - ${s.freePlayA}'
              : '${s.freePlayA} - ${s.freePlayB}')
        : s.completedSets
              .map(
                (x) => x.isSuperTieBreak
                    ? (mirror
                          ? '${x.tieBreakB}-${x.tieBreakA}'
                          : '${x.tieBreakA}-${x.tieBreakB}')
                    : (mirror
                          ? '${x.gamesB}-${x.gamesA}'
                          : '${x.gamesA}-${x.gamesB}'),
              )
              .join('  ');
    final localInsight = _localInsight(
      won: won,
      hasWinner: s.winner != null,
      usPoints: us.pointsWon,
      themPoints: them.pointsWon,
      usServe: us.serveHoldRate,
      usStreak: us.bestStreak,
      turning: advanced.turningPoints.isNotEmpty
          ? _turningPointLabel(advanced.turningPoints.last)
          : null,
    );
    final matchCtx = _postMatchContext(
      row: row,
      scoreLine: scoreLine,
      won: won,
      us: us,
      them: them,
      stats: stats,
      insight: localInsight,
    );
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report partita'),
        leading: const SafeBackButton(fallback: AppLocations.home),
        actions: [
          IconButton(
            tooltip: 'Momentum Wrapped',
            icon: const Icon(Icons.ios_share),
            onPressed: () => context.push('/match/${row.id}/wrapped'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/match/${row.id}/wrapped'),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Condividi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (!ents.llmAssistant) {
                      pushPaywall(
                        context,
                        gate: 'llm_assistant',
                        plan: Plan.pro,
                        reason: gates['llm_assistant']!.pitch,
                        returnTo: '/match/${row.id}',
                      );
                      return;
                    }
                    context.push(
                      Uri(
                        path: '/pro-chat',
                        queryParameters: {
                          'mode': 'POST_MATCH',
                          'matchId': row.id,
                          'ctx': matchCtx,
                          'q':
                              'Analizza questa partita e dimmi 3 priorità.',
                        },
                      ).toString(),
                    );
                  },
                  icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: Text(
                    ents.llmAssistant
                        ? AppBrand.assistantName
                        : 'Pallino Pro',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/match/new'),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Di nuovo'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Risultato + peak-end insight
          SectionCard(
            child: Column(
              children: [
                Text(
                  won
                      ? 'VITTORIA'
                      : (s.winner == null ? 'PARTITA' : 'BATTAGLIA'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: won
                        ? RallyColors.win
                        : (s.winner == null
                              ? Colors.white70
                              : RallyColors.teamGold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  scoreLine,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (row.opponentLabel.isNotEmpty) 'vs ${row.opponentLabel}',
                    formatDuration(stats.durationMs),
                    '${stats.totalPoints} punti',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RallyColors.lime.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: RallyColors.lime.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    localInsight,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (row.duoMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: RallyColors.lime.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: RallyColors.lime.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '⌚⌚ Duo Mode · giocata insieme dai due team'
                      '${row.duoTeam != null ? ' · tu: '
                                '${row.duoTeam == 'TEAM_A' ? 'Team A' : 'Team B'}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: RallyColors.lime,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats base (free)
          SectionCard(
            title: 'STATISTICHE',
            child: Column(
              children: [
                _statRow('Punti vinti', '${us.pointsWon}', '${them.pointsWon}'),
                _statRow(
                  'Miglior streak',
                  '${us.bestStreak}',
                  '${them.bestStreak}',
                ),
                _statRow(
                  'Punti al servizio',
                  '${(us.serveHoldRate * 100).round()}%',
                  '${(them.serveHoldRate * 100).round()}%',
                ),
                if (us.tieBreakPointsPlayed > 0)
                  _statRow(
                    'Tie-break',
                    '${us.tieBreakPointsWon}/${us.tieBreakPointsPlayed}',
                    '${them.tieBreakPointsWon}/${them.tieBreakPointsPlayed}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Svolta confermata soltanto dopo l'analisi dell'intera timeline.
          if (advanced.turningPoints.isNotEmpty) ...[
            SectionCard(
              title: 'SVOLTA CONFERMATA',
              child: Row(
                children: [
                  const Icon(
                    Icons.track_changes_rounded,
                    color: RallyColors.teamGold,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _turningPointLabel(advanced.turningPoints.last),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Punto ${advanced.turningPoints.last.pointIndex + 1} · '
                          'leva ${(advanced.turningPoints.last.leverage * 100).round()}% · '
                          'conferma ${(advanced.turningPoints.last.confirmationRate * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Premium: clutch + momentum + decisivi
          PremiumGate(
            gateKey: 'premium_analytics',
            entitled: (e) => e.premiumAnalytics,
            child: Column(
              children: [
                SectionCard(
                  title: 'PRESSIONE · STIMA CORRETTA',
                  child: Row(
                    children: [
                      _clutchRing(
                        advanced.clutchScore == null
                            ? null
                            : (advanced.clutchScore! * 100).round(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              advanced.pressurePointWinRate.trials == 0
                                  ? 'Nessun rally ad alta leva'
                                  : '${advanced.pressurePointWinRate.successes}/'
                                        '${advanced.pressurePointWinRate.trials} '
                                        'rally ad alta leva vinti',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              advanced.pressurePointWinRate.trials == 0
                                  ? 'Il valore non viene inventato: serve un campione reale.'
                                  : 'IC 90% '
                                        '${(advanced.pressurePointWinRate.lower * 100).round()}–'
                                        '${(advanced.pressurePointWinRate.upper * 100).round()}% · '
                                        'correzione per piccoli campioni.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'ANDAMENTO CUMULATIVO DEI PUNTI',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 120,
                        child: CustomPaint(
                          size: const Size.fromHeight(120),
                          painter: _MomentumPainter(stats.momentum),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Grafico descrittivo: la differenza cumulativa non viene presentata come prova di momentum.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (advanced.momentumPhases.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'FASI PERSISTENTI · POST-MATCH',
                    child: Column(
                      children: [
                        for (final phase in advanced.momentumPhases)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(
                                  phase.team == myTeam
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: phase.team == myTeam
                                      ? RallyColors.win
                                      : RallyColors.loss,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Punti ${phase.startPoint + 1}–${phase.endPoint + 1}: '
                                    '${(phase.pointRate.rate * 100).round()}% per '
                                    '${phase.team == myTeam ? 'noi' : 'loro'} '
                                    '(n=${phase.length}).',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Health after emotional peak + stats (less cold interrupt).
          _MatchHealthCard(matchId: row.id),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/training'),
            icon: const Icon(Icons.fitness_center_outlined),
            label: const Text('Allena un punto debole'),
          ),
        ],
      ),
    );
  }

  static String _localInsight({
    required bool won,
    required bool hasWinner,
    required int usPoints,
    required int themPoints,
    required double usServe,
    required int usStreak,
    required String? turning,
  }) {
    if (turning != null && turning.isNotEmpty) {
      return turning;
    }
    final total = usPoints + themPoints;
    final pct = total == 0 ? 0 : ((usPoints / total) * 100).round();
    if (!hasWinner) {
      return 'Allenamento registrato · $usPoints-$themPoints punti · '
          'streak max $usStreak.';
    }
    if (won) {
      return 'Vittoria con $pct% dei punti · hold servizio '
          '${(usServe * 100).round()}% · streak $usStreak.';
    }
    return 'Battaglia a $pct% dei punti · hold ${(usServe * 100).round()}% · '
        'prossima priorità: solidità nei momenti chiave.';
  }

  static String _postMatchContext({
    required MatchRow row,
    required String scoreLine,
    required bool won,
    required TeamMatchStats us,
    required TeamMatchStats them,
    required MatchStats stats,
    required String insight,
  }) {
    return [
      'Match id=${row.id}',
      'Esito: ${won ? 'VITTORIA' : 'SCONFITTA/BATTAGLIA'}',
      'Punteggio: $scoreLine',
      if (row.opponentLabel.isNotEmpty) 'Avversari: ${row.opponentLabel}',
      if (row.myRole.isNotEmpty) 'Ruolo: ${row.myRole}',
      'Punti: noi ${us.pointsWon} · loro ${them.pointsWon}',
      'Serve hold: noi ${(us.serveHoldRate * 100).round()}% · '
          'loro ${(them.serveHoldRate * 100).round()}%',
      'Streak: noi ${us.bestStreak} · loro ${them.bestStreak}',
      'Durata: ${formatDuration(stats.durationMs)} · '
          'tot ${stats.totalPoints} punti',
      'Insight locale: $insight',
      'Analizza form, coppia e 3 priorità di allenamento.',
    ].join('. ');
  }

  Widget _statRow(String label, String us, String them) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              us,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: RallyColors.teamUs,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              them,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: RallyColors.teamThem,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _turningPointLabel(TurningPoint point) => switch (point.kind) {
    TurningPointKind.matchPointSaved => 'Match point annullato e consolidato',
    TurningPointKind.matchPoint => 'Match point trasformato',
    TurningPointKind.setPoint => 'Set point che ha spostato la partita',
    TurningPointKind.breakPoint => 'Break confermato nella fase successiva',
    TurningPointKind.sustainedShift => 'Cambio di controllo persistente',
  };

  Widget _clutchRing(int? score) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: (score ?? 0) / 100,
              strokeWidth: 7,
              backgroundColor: Colors.white12,
              color: score == null
                  ? Colors.white24
                  : score >= 65
                  ? RallyColors.win
                  : score >= 45
                  ? RallyColors.lime
                  : RallyColors.loss,
            ),
          ),
          Text(
            score == null ? '—' : '$score',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MatchHealthCard extends ConsumerStatefulWidget {
  const _MatchHealthCard({required this.matchId});

  final String matchId;

  @override
  ConsumerState<_MatchHealthCard> createState() => _MatchHealthCardState();
}

class _MatchHealthCardState extends ConsumerState<_MatchHealthCard> {
  late Future<MatchHealthSummary?> _future = _load();
  bool _busy = false;

  Future<MatchHealthSummary?> _load() =>
      ref.read(healthDataRepoProvider).summaryForMatch(widget.matchId);

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchHealthSyncProvider)
          .associateCompletedMatch(widget.matchId);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _future = _load();
        });
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchHealthSyncProvider)
          .confirmPendingAssociation(widget.matchId);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _future = _load();
        });
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchHealthSyncProvider)
          .rejectPendingAssociation(widget.matchId);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _future = _load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchHealthSummary?>(
      future: _future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return SectionCard(
            title: 'DATI SALUTE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nessun dato salute associato ancora. La partita è salvata '
                  'in locale; i dati di Apple Salute / Health Connect si '
                  'collegano automaticamente quando disponibili e autorizzati.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white54,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_busy ? 'Sincronizzazione…' : 'Sincronizza ora'),
                ),
              ],
            ),
          );
        }
        final pending =
            MatchHealthDataQuality.isPendingConfirm(summary.dataQuality);
        final cleared = summary.dataQuality == MatchHealthDataQuality.cleared;
        if (cleared) {
          return SectionCard(
            title: 'DATI SALUTE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Associazione salute rimossa o rifiutata. Puoi riprovare la '
                  'sincronizzazione in qualsiasi momento.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white54,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sincronizza di nuovo'),
                ),
              ],
            ),
          );
        }
        return SectionCard(
          title: pending
              ? 'CONFERMA DATI SALUTE'
              : 'DATI SALUTE ASSOCIATI',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pending) ...[
                const Text(
                  'Abbiamo trovato metriche che sembrano relative a questa '
                  'partita. Confermi il collegamento? Fino alla conferma non '
                  'vengono usate come fonte automatica ad alta confidenza.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (summary.averageHeartRate != null)
                _healthRow(
                  'Freq. cardiaca media',
                  '${summary.averageHeartRate!.round()} bpm',
                ),
              if (summary.activeEnergyKcal != null)
                _healthRow(
                  'Calorie attive',
                  '${summary.activeEnergyKcal!.round()} kcal',
                ),
              if (summary.steps != null)
                _healthRow('Passi', '${summary.steps}'),
              if (summary.durationSeconds != null)
                _healthRow(
                  'Durata sessione',
                  '${(summary.durationSeconds! / 60).round()} min',
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Qualità: ${summary.dataQuality} · fonte ibrida (locale + hub salute)',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
              ),
              if (pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _confirm,
                        child: const Text('Conferma'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _reject,
                        child: const Text('Rifiuta'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _sync,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Aggiorna da hub salute'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _healthRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter(this.points);
  final List<MomentumPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxAbs = points
        .map((p) => p.diff.abs())
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);
    final midY = size.height / 2;
    final dx = size.width / (points.length - 1);

    final axis = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axis);

    final pathUp = Path()..moveTo(0, midY);
    for (var i = 0; i < points.length; i++) {
      final y = midY - (points[i].diff / maxAbs) * (midY - 6);
      pathUp.lineTo(i * dx, y);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [RallyColors.teamUs, RallyColors.teamThem],
      ).createShader(Offset.zero & size);
    canvas.drawPath(pathUp, line);

    // Set separators.
    var lastSet = points.first.setIndex;
    final sep = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var i = 0; i < points.length; i++) {
      if (points[i].setIndex != lastSet) {
        lastSet = points[i].setIndex;
        canvas.drawLine(Offset(i * dx, 0), Offset(i * dx, size.height), sep);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) => old.points != points;
}
