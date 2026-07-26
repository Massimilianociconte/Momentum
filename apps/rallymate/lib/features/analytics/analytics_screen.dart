/// Analytics personali (PRD Modulo F): base free, avanzate premium.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/team_visuals.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../services/health_connect.dart';
import '../../services/pdf_report_service.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _window = 10;

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(summariesProvider);
    final teams = ref.watch(teamsProvider).value ?? const <Team>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (all) {
          if (all.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                EmptyStateCard(
                  icon: Icons.insights,
                  title: 'Analisi pronte dopo il primo match',
                  message:
                      'Segna una partita per vedere win rate, punti '
                      'medi, streak, risultati tipici e consigli tecnici.',
                  primaryLabel: 'Nuova partita',
                  primaryIcon: Icons.play_arrow,
                  onPrimary: () => context.push('/match/new'),
                  secondaryLabel: 'Allenati prima',
                  secondaryIcon: Icons.fitness_center,
                  onSecondary: () => context.go('/training'),
                ),
              ],
            );
          }
          final myRole = ref.watch(meProvider).value?.preferredRole;
          final selected = all.take(math.min(_window, all.length)).toList();
          final portfolio = AnalyticsPortfolio.fromMatches(selected);
          final entitlements = ref.watch(entitlementsProvider);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _AnalyticsRangeSelector(
                selected: _window,
                available: all.length,
                onChanged: (value) => setState(() => _window = value),
              ),
              const SizedBox(height: 12),
              _AnalyticsEvidenceHero(
                portfolio: portfolio,
                selectedMatches: selected.length,
              ),
              const SizedBox(height: 12),
              _baseStats(selected),
              const SizedBox(height: 12),
              const _RatingCard(),
              const SizedBox(height: 12),
              _performanceTrend(selected),
              if (teams.any(
                (team) => selected.any((summary) => summary.teamId == team.id),
              )) ...[
                const SizedBox(height: 12),
                _teamBreakdown(selected, teams),
              ],
              const SizedBox(height: 12),
              PremiumGate(
                gateKey: 'premium_analytics',
                entitled: (e) => e.premiumAnalytics,
                child: Column(
                  children: [
                    _decisivePerformance(portfolio),
                    const SizedBox(height: 12),
                    _patternIntelligence(portfolio),
                    const SizedBox(height: 12),
                    _weeklyTrend(all),
                    const SizedBox(height: 12),
                    _clutchTrend(selected),
                    const SizedBox(height: 12),
                    _progressAndRegression(all),
                    const SizedBox(height: 12),
                    _byRole(selected),
                    const SizedBox(height: 12),
                    _roleAdvice(myRole),
                    const SizedBox(height: 12),
                    _byDifficulty(selected),
                    const SizedBox(height: 12),
                    _fitnessToday(entitlements.healthConnectSync),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // PRD F5: statistiche avanzate per difficoltà avversari (Pro).
              PremiumGate(
                gateKey: 'difficulty_advanced',
                entitled: (e) => e.advancedDifficulty,
                child: _difficultyStats(context, selected),
              ),
              const SizedBox(height: 12),
              _ExportPdfCard(summaries: selected),
            ],
          );
        },
      ),
    );
  }

  Widget _teamBreakdown(List<MatchSummary> all, List<Team> teams) {
    final activeTeams =
        teams
            .map(
              (team) => (
                team: team,
                matches: all
                    .where((summary) => summary.teamId == team.id)
                    .toList(growable: false),
              ),
            )
            .where((entry) => entry.matches.isNotEmpty)
            .toList()
          ..sort((a, b) => b.matches.length.compareTo(a.matches.length));
    return SectionCard(
      title: 'RENDIMENTO DEI TEAM',
      child: Column(
        children: [
          for (var index = 0; index < activeTeams.length; index++) ...[
            if (index > 0) const Divider(height: 18),
            Builder(
              builder: (context) {
                final entry = activeTeams[index];
                final wins = entry.matches.where((match) => match.won).length;
                final rate = (wins / entry.matches.length * 100).round();
                return Row(
                  children: [
                    TeamAvatar(team: entry.team, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${entry.matches.length} partite · $wins vittorie',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        color: rate >= 50 ? RallyColors.win : RallyColors.loss,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ---- free

  Widget _baseStats(List<MatchSummary> all) {
    final wins = all.where((m) => m.won).length;
    final winRate = wins / all.length;
    final pointsFor = all.fold(0, (sum, match) => sum + match.pointsFor);
    final pointsAgainst = all.fold(
      0,
      (sum, match) => sum + match.pointsAgainst,
    );
    final pointShare = pointsFor + pointsAgainst == 0
        ? 0.0
        : pointsFor / (pointsFor + pointsAgainst);
    var streak = 0, best = 0;
    for (final m in all.reversed) {
      streak = m.won ? streak + 1 : 0;
      if (streak > best) best = streak;
    }
    // Interrupted/legacy sessions can carry a missing start timestamp and
    // therefore an epoch-sized duration. They must not poison user analytics.
    final plausibleDurations = all
        .map((match) => match.durationMs)
        .where(
          (duration) =>
              duration > 0 &&
              duration <= const Duration(hours: 12).inMilliseconds,
        )
        .toList(growable: false);
    final avgDur = plausibleDurations.isEmpty
        ? null
        : plausibleDurations.reduce((a, b) => a + b) ~/
              plausibleDurations.length;

    // PRD F1: risultato più frequente (in set, es. "2-0").
    final resultCounts = <String, int>{};
    for (final m in all) {
      final r = '${m.setsFor}-${m.setsAgainst}';
      resultCounts[r] = (resultCounts[r] ?? 0) + 1;
    }
    final frequentResult =
        (resultCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final gamesWon = all.fold(0, (a, m) => a + m.gamesFor);
    final gamesLost = all.fold(0, (a, m) => a + m.gamesAgainst);
    final setsWon = all.fold(0, (a, m) => a + m.setsFor);
    final setsLost = all.fold(0, (a, m) => a + m.setsAgainst);

    final metrics = [
      _AnalyticsMetric('Partite', '${all.length}', Icons.sports_tennis),
      _AnalyticsMetric(
        'Win rate',
        '${(winRate * 100).round()}%',
        Icons.emoji_events_outlined,
        color: winRate >= 0.5 ? RallyColors.win : RallyColors.loss,
        detail: '$wins vittorie',
      ),
      _AnalyticsMetric(
        'Quota punti',
        '${(pointShare * 100).round()}%',
        Icons.compare_arrows,
        color: pointShare >= 0.5 ? RallyColors.cyan : RallyColors.teamGold,
        detail: '$pointsFor su ${pointsFor + pointsAgainst}',
      ),
      _AnalyticsMetric(
        'Miglior streak',
        '$best',
        Icons.local_fire_department_outlined,
        color: RallyColors.teamGold,
      ),
      _AnalyticsMetric('Game', '$gamesWon-$gamesLost', Icons.grid_view_rounded),
      _AnalyticsMetric('Set', '$setsWon-$setsLost', Icons.layers_outlined),
      _AnalyticsMetric(
        'Durata media',
        avgDur == null ? '—' : formatDuration(avgDur),
        Icons.timer_outlined,
        detail: avgDur == null ? 'dato non disponibile' : null,
      ),
      _AnalyticsMetric(
        'Risultato tipico',
        frequentResult,
        Icons.scoreboard_outlined,
      ),
    ];
    return SectionCard(
      title: 'RIEPILOGO IMMEDIATO',
      child: _AnalyticsMetricGrid(metrics: metrics),
    );
  }

  Widget _performanceTrend(List<MatchSummary> matches) {
    return SectionCard(
      title: 'CONTROLLO DEL GIOCO · ${matches.length} PARTITE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatchPerformanceChart(matches: matches.reversed.toList()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _LegendDot(color: RallyColors.win, label: 'Quota punti vinti'),
              _LegendDot(color: RallyColors.teamThem, label: 'Quota avversari'),
              _LegendDot(color: RallyColors.lime, label: 'Vittoria'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decisivePerformance(AnalyticsPortfolio portfolio) {
    final pressure = portfolio.pressurePointWinRate;
    final clutch = portfolio.clutchScore;
    final clutchDelta = portfolio.clutchDelta;
    return SectionCard(
      title: 'PRESSIONE E CHIUSURA',
      trailing: _EvidenceBadge(quality: portfolio.quality),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PressureHeadline(
            rate: pressure,
            clutchScore: clutch,
            clutchDelta: clutchDelta,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _AnalyticsMetricGrid(
            metrics: [
              _AnalyticsMetric(
                'Break convertiti',
                _rateLabel(portfolio.breakPointConversion),
                Icons.sports_tennis_rounded,
                color: RallyColors.cyan,
                detail: _sampleLabel(portfolio.breakPointConversion),
              ),
              _AnalyticsMetric(
                'Chiusura game',
                _rateLabel(portfolio.closingPointRate),
                Icons.flag_rounded,
                color: RallyColors.win,
                detail: _sampleLabel(portfolio.closingPointRate),
              ),
              _AnalyticsMetric(
                'Game point salvati',
                _rateLabel(portfolio.gamePointSaveRate),
                Icons.shield_outlined,
                color: RallyColors.teamGold,
                detail: _sampleLabel(portfolio.gamePointSaveRate),
              ),
              _AnalyticsMetric(
                'Rimonte profonde',
                '${portfolio.comebackWins}',
                Icons.replay_circle_filled_rounded,
                color: RallyColors.training,
                detail: 'vittorie da ≤30% neutro',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Il clutch usa solo rally ad alta leva e viene corretto verso la media personale quando il campione è piccolo.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _patternIntelligence(AnalyticsPortfolio portfolio) {
    final late = portfolio.latePhaseDelta;
    final lateText = late == null
        ? 'Servono più rally per confrontare apertura e fase finale.'
        : portfolio.latePhaseSignalSupported
        ? '${late >= 0 ? 'Crescita' : 'Calo'} finale confermato: '
              '${late >= 0 ? '+' : ''}${(late * 100).round()} punti %.'
        : 'Nessun cambiamento finale supera la soglia di evidenza.';
    return SectionCard(
      title: 'PATTERN CONFERMATI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EvidenceRateBar(
            label: 'Punti al servizio',
            estimate: portfolio.servePointWinRate,
            color: RallyColors.lime,
          ),
          const SizedBox(height: 12),
          _EvidenceRateBar(
            label: 'Punti in risposta',
            estimate: portfolio.returnPointWinRate,
            color: RallyColors.cyan,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                portfolio.latePhaseSignalSupported
                    ? (late! >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded)
                    : Icons.horizontal_rule_rounded,
                color: portfolio.latePhaseSignalSupported
                    ? (late! >= 0 ? RallyColors.win : RallyColors.loss)
                    : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lateText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _CompactEvidenceStat(
                value: '${portfolio.confirmedTurningPoints}',
                label: 'svolte confermate',
                color: RallyColors.teamGold,
              ),
              _CompactEvidenceStat(
                value: '${portfolio.momentumPhases}',
                label: 'fasi persistenti',
                color: RallyColors.teamThem,
              ),
              _CompactEvidenceStat(
                value: '${portfolio.totalPoints}',
                label: 'rally analizzati',
                color: RallyColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Le fasi derivano da segmentazione offline a likelihood penalizzata: una semplice streak non viene etichettata come momentum.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  static String _rateLabel(RateEstimate rate) =>
      rate.trials == 0 ? '—' : '${(rate.rate * 100).round()}%';

  static String _sampleLabel(RateEstimate rate) => rate.trials == 0
      ? 'campione assente'
      : '${rate.successes}/${rate.trials} · IC 90%';

  Widget _progressAndRegression(List<MatchSummary> all) {
    final size = math.min(5, all.length ~/ 2);
    if (size < 2) {
      return const SectionCard(
        title: 'PROGRESSI E REGRESSIONI',
        child: Text(
          'Servono almeno quattro partite per confrontare due periodi reali.',
          style: TextStyle(color: Colors.white60, height: 1.35),
        ),
      );
    }
    final insights = ProgressAnalyzer.compare(
      recent: all.take(size).toList(),
      baseline: all.skip(size).take(size).toList(),
    );
    if (insights.isEmpty) {
      return const SectionCard(
        title: 'PROGRESSI E REGRESSIONI',
        child: Text(
          'Prestazioni stabili: nessuna variazione supera la soglia del rumore statistico.',
          style: TextStyle(color: Colors.white60, height: 1.35),
        ),
      );
    }
    return SectionCard(
      title: 'PROGRESSI E REGRESSIONI',
      child: Column(
        children: [
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    insight.direction == InsightDirection.improvement
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: insight.direction == InsightDirection.improvement
                        ? RallyColors.win
                        : RallyColors.loss,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_qualityLabel(insight.evidence)} · '
                          'campione ${insight.sampleSize}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fitnessToday(bool enabled) {
    if (!enabled) {
      return SectionCard(
        title: 'FITNESS · OGGI',
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: RallyColors.teamGold),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Gli aggregati Apple Salute / Health Connect sono disponibili con il piano Pro e consenso esplicito.',
                style: TextStyle(color: Colors.white60, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/profile?focus=health'),
              child: const Text('Configura'),
            ),
          ],
        ),
      );
    }
    final status = ref.watch(healthConnectStatusProvider);
    if (status.value?.granted != true) {
      return SectionCard(
        title: 'FITNESS · OGGI',
        child: Row(
          children: [
            const Icon(Icons.favorite_border, color: RallyColors.teamGold),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Collega il servizio salute per mostrare soltanto gli aggregati autorizzati della giornata corrente.',
                style: TextStyle(color: Colors.white60, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/profile?focus=health'),
              child: const Text('Collega'),
            ),
          ],
        ),
      );
    }
    final today = ref.watch(healthTodayProvider);
    return SectionCard(
      title: 'FITNESS · OGGI',
      child: today.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => const Text(
          'Dati salute temporaneamente non disponibili.',
          style: TextStyle(color: Colors.white60),
        ),
        data: (summary) {
          if (summary == null) {
            return const Text(
              'Nessun aggregato disponibile per oggi.',
              style: TextStyle(color: Colors.white60),
            );
          }
          return Column(
            children: [
              _AnalyticsMetricGrid(
                metrics: [
                  _AnalyticsMetric(
                    'Passi',
                    '${summary.steps}',
                    Icons.directions_walk_rounded,
                  ),
                  _AnalyticsMetric(
                    'Minuti attivi',
                    '${summary.exerciseMinutes}',
                    Icons.timer_outlined,
                  ),
                  _AnalyticsMetric(
                    'Energia attiva',
                    '${summary.activeCaloriesKcal.round()} kcal',
                    Icons.local_fire_department_outlined,
                  ),
                  _AnalyticsMetric(
                    'FC media',
                    summary.averageHeartRateBpm == null
                        ? '—'
                        : '${summary.averageHeartRateBpm!.round()} bpm',
                    Icons.favorite_rounded,
                    color: RallyColors.loss,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Finestra: da mezzanotte locale a ora.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aggiorna dati di oggi',
                    onPressed: () => ref.invalidate(healthTodayProvider),
                    icon: const Icon(Icons.refresh, size: 19),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// PRD F2: trend settimanali — win rate ultime 8 settimane.
  Widget _weeklyTrend(List<MatchSummary> all) {
    final now = DateTime.now();
    final thisWeekStart = now
        .subtract(Duration(days: now.weekday - 1))
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final weeks = <({int played, int won})>[];
    for (var i = 7; i >= 0; i--) {
      final start = thisWeekStart.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final inWeek = all.where(
        (m) =>
            m.endTimeMs >= start.millisecondsSinceEpoch &&
            m.endTimeMs < end.millisecondsSinceEpoch,
      );
      weeks.add((
        played: inWeek.length,
        won: inWeek.where((m) => m.won).length,
      ));
    }
    return SectionCard(
      title: 'TREND — ULTIME 8 SETTIMANE',
      child: SizedBox(
        height: 92,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final w in weeks)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (w.played > 0) ...[
                        Text(
                          '${w.won}/${w.played}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 8 + 56 * (w.won / w.played),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                RallyColors.court,
                                w.won / w.played >= 0.5
                                    ? RallyColors.win
                                    : RallyColors.loss,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ] else
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// PRD F3: consigli tecnici per ruolo (terminologia padel).
  Widget _roleAdvice(String? roleWire) {
    final (title, tips) = switch (roleWire) {
      'LEFT' => (
        'CONSIGLI PER IL GIOCATORE DI SINISTRA',
        [
          'Gestione smash: scegli per 3, per 4 o al centro in base alla '
              'posizione degli avversari, non alla potenza.',
          'Bandeja e vibora per difendere la rete senza regalare il punto.',
          'Chiusura a rete: dopo l\'attacco, recupera subito la posizione.',
          'Pazienza nei punti lunghi: l\'errore forzato è dell\'avversario.',
        ],
      ),
      'RIGHT' => (
        'CONSIGLI PER IL GIOCATORE DI DESTRA',
        [
          'Uscita di parete solida: blocco corto o profondo, mai a metà.',
          'Lob difensivo sopra il giocatore di sinistra avversario.',
          'Volée di controllo: prepara il punto per il compagno.',
          'Copertura centrale nei momenti difensivi.',
        ],
      ),
      'FLEX' => (
        'CONSIGLI FLEX',
        [
          'Confronta il rendimento nei due lati e scegli il lato forte '
              'nelle partite che contano.',
          'Allena il lato debole negli allenamenti, non nei tornei.',
          'Colpo neutro dal centro quando cambi lato a metà partita.',
        ],
      ),
      _ => (
        'CONSIGLI',
        [
          'Imposta il tuo ruolo nel profilo per ricevere consigli '
              'specifici destra/sinistra basati sulle tue partite.',
        ],
      ),
    };
    return SectionCard(
      title: title,
      child: Column(
        children: [
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯 ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- premium

  Widget _clutchTrend(List<MatchSummary> all) {
    final recent = all
        .take(10)
        .where(
          (match) =>
              (match.advancedAnalysis?.pressurePointWinRate.trials ?? 0) > 0,
        )
        .toList()
        .reversed
        .toList();
    if (recent.isEmpty) {
      return const SectionCard(
        title: 'PRESSIONE MATCH PER MATCH',
        child: Text(
          'Nessun campione ad alta leva disponibile nella finestra selezionata.',
          style: TextStyle(color: Colors.white60, height: 1.35),
        ),
      );
    }
    return SectionCard(
      title: 'PRESSIONE MATCH PER MATCH · ${recent.length}',
      child: SizedBox(
        height: 112,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final m in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${(m.advancedAnalysis!.pressurePointWinRate.rate * 100).round()}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height:
                            70 * m.advancedAnalysis!.pressurePointWinRate.rate,
                        decoration: BoxDecoration(
                          color: m.won
                              ? RallyColors.win
                              : RallyColors.loss.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'n${m.advancedAnalysis!.pressurePointWinRate.trials}',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _byRole(List<MatchSummary> all) {
    final byRole = <PadelRole, List<MatchSummary>>{};
    for (final m in all) {
      byRole.putIfAbsent(m.roleplayed, () => []).add(m);
    }
    byRole.remove(PadelRole.undefined);
    if (byRole.isEmpty) {
      return const SectionCard(
        title: 'PER RUOLO',
        child: Text(
          'Indica il tuo ruolo quando crei una partita per vedere le '
          'statistiche destra/sinistra.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }
    return SectionCard(
      title: 'PER RUOLO',
      child: Column(
        children: [
          for (final e in byRole.entries)
            _rateRow(
              switch (e.key) {
                PadelRole.left => 'Sinistra',
                PadelRole.right => 'Destra',
                PadelRole.flex => 'Flex',
                PadelRole.undefined => '—',
              },
              e.value.where((m) => m.won).length / e.value.length,
              '${e.value.length} partite',
            ),
        ],
      ),
    );
  }

  Widget _byDifficulty(List<MatchSummary> all) {
    final byDiff = <int, List<MatchSummary>>{};
    for (final m in all) {
      byDiff.putIfAbsent(m.opponentDifficulty.score, () => []).add(m);
    }
    return SectionCard(
      title: 'PER DIFFICOLTÀ AVVERSARI · DICHIARATA',
      child: Column(
        children: [
          for (final k in (byDiff.keys.toList()..sort()))
            _rateRow(
              'Difficoltà $k/5',
              byDiff[k]!.where((m) => m.won).length / byDiff[k]!.length,
              '${byDiff[k]!.length} partite',
            ),
        ],
      ),
    );
  }

  Widget _difficultyStats(BuildContext context, List<MatchSummary> all) {
    final st = OpponentDifficultyScore.stats(all);
    final byId = {for (final m in all) m.matchId: m};
    final bestWin = byId[st.bestWinMatchId];
    final worstLoss = byId[st.worstLossMatchId];
    return SectionCard(
      title: 'IMPRESE · DIFFICOLTÀ AVVERSARI',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatTile(
                label: 'Upset win',
                value: '${st.upsetWins}',
                color: RallyColors.win,
              ),
              StatTile(
                label: 'Upset loss',
                value: '${st.upsetLosses}',
                color: RallyColors.loss,
              ),
              StatTile(
                label: 'Streak pari livello',
                value: '${st.bestStreakVsSameLevel}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatTile(
                label: 'Vinte vs più forti',
                value: '${st.winsVsHarder}',
                color: RallyColors.lime,
              ),
              StatTile(
                label: 'Perse vs più deboli',
                value: '${st.lossesVsEasier}',
                color: st.lossesVsEasier > 0 ? RallyColors.loss : null,
              ),
              const SizedBox(width: 72),
            ],
          ),
          if (bestWin != null || worstLoss != null) ...[
            const Divider(height: 20),
            if (bestWin != null)
              _extremeMatchRow(
                context,
                icon: Icons.military_tech,
                color: RallyColors.win,
                label: 'Miglior vittoria',
                summary: bestWin,
              ),
            if (worstLoss != null)
              _extremeMatchRow(
                context,
                icon: Icons.trending_down,
                color: RallyColors.loss,
                label: 'Peggior sconfitta',
                summary: worstLoss,
              ),
          ],
        ],
      ),
    );
  }

  Widget _extremeMatchRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required MatchSummary summary,
  }) {
    final when = DateTime.fromMillisecondsSinceEpoch(summary.endTimeMs);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/match/${summary.matchId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Difficoltà ${summary.opponentDifficulty.score}/5 · '
                    '${summary.setsFor}-${summary.setsAgainst} set · '
                    '${when.day}/${when.month}/${when.year}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _rateRow(String label, double rate, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 10,
                backgroundColor: Colors.white10,
                color: rate >= 0.5 ? RallyColors.win : RallyColors.loss,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${(rate * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _qualityLabel(EvidenceQuality quality) => switch (quality) {
  EvidenceQuality.reliable => 'Evidenza solida',
  EvidenceQuality.developing => 'Campione in crescita',
  EvidenceQuality.insufficient => 'Campione iniziale',
};

Color _qualityColor(EvidenceQuality quality) => switch (quality) {
  EvidenceQuality.reliable => RallyColors.win,
  EvidenceQuality.developing => RallyColors.teamGold,
  EvidenceQuality.insufficient => Colors.white54,
};

class _AnalyticsEvidenceHero extends StatelessWidget {
  const _AnalyticsEvidenceHero({
    required this.portfolio,
    required this.selectedMatches,
  });

  final AnalyticsPortfolio portfolio;
  final int selectedMatches;

  @override
  Widget build(BuildContext context) {
    final pointRate = portfolio.pointWinRate;
    final quality = portfolio.quality;
    final accent = _qualityColor(quality);
    final rateLabel = pointRate.hasEvidence
        ? '${(pointRate.rate * 100).round()}%'
        : '—';
    final interval = pointRate.hasEvidence
        ? 'IC 90% · ${(pointRate.lower * 100).round()}–${(pointRate.upper * 100).round()}%'
        : 'Analisi eventi in preparazione';

    return Semantics(
      container: true,
      label:
          'Performance intelligence, $rateLabel dei punti vinti, ${_qualityLabel(quality)}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123A55), Color(0xFF142438), Color(0xFF1E2434)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RallyColors.cyan.withValues(alpha: 0.22)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -18,
              child: Icon(
                Icons.query_stats_rounded,
                size: 112,
                color: RallyColors.cyan.withValues(alpha: 0.055),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFORMANCE INTELLIGENCE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 330;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _qualityLabel(quality),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Motore post-partita v${AdvancedMatchAnalysis.currentVersion} · '
                          '$selectedMatches match · ${portfolio.totalPoints} rally',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    );
                    final score = Column(
                      crossAxisAlignment: compact
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          rateLabel,
                          style: const TextStyle(
                            color: RallyColors.cyan,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'quota punti vinti',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 14), score],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 16),
                        score,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _HeroEvidenceItem(
                      icon: Icons.rule_rounded,
                      label: interval,
                    ),
                    const _HeroEvidenceItem(
                      icon: Icons.history_toggle_off_rounded,
                      label: 'Solo match conclusi',
                    ),
                    const _HeroEvidenceItem(
                      icon: Icons.replay_rounded,
                      label: 'Replay verificabile',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroEvidenceItem extends StatelessWidget {
  const _HeroEvidenceItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
      ),
    ],
  );
}

class _EvidenceBadge extends StatelessWidget {
  const _EvidenceBadge({required this.quality});

  final EvidenceQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(quality);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _qualityLabel(quality),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PressureHeadline extends StatelessWidget {
  const _PressureHeadline({
    required this.rate,
    required this.clutchScore,
    required this.clutchDelta,
  });

  final RateEstimate rate;
  final double? clutchScore;
  final double? clutchDelta;

  @override
  Widget build(BuildContext context) {
    final score = clutchScore;
    final delta = clutchDelta;
    final color = delta == null
        ? Colors.white38
        : delta >= 0
        ? RallyColors.win
        : RallyColors.teamGold;
    return Row(
      children: [
        SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: score ?? 0,
                  strokeWidth: 7,
                  backgroundColor: Colors.white10,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score == null ? '—' : '${(score * 100).round()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'CLUTCH',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rate.hasEvidence
                    ? '${(rate.rate * 100).round()}% nei rally ad alta leva'
                    : 'Campione pressione non disponibile',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                rate.hasEvidence
                    ? 'IC 90% ${(rate.lower * 100).round()}–${(rate.upper * 100).round()}% '
                          '· ${rate.successes}/${rate.trials}'
                    : 'Il valore apparirà dopo una partita con rally strutturalmente decisivi.',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 5),
                Text(
                  '${delta >= 0 ? '+' : ''}${(delta * 100).round()} punti % rispetto alla tua base',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EvidenceRateBar extends StatelessWidget {
  const _EvidenceRateBar({
    required this.label,
    required this.estimate,
    required this.color,
  });

  final String label;
  final RateEstimate estimate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              estimate.hasEvidence ? '${(estimate.rate * 100).round()}%' : '—',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              estimate.hasEvidence ? 'n=${estimate.trials}' : 'nessun dato',
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  if (estimate.hasEvidence)
                    Positioned(
                      left: width * estimate.lower,
                      width: math.max(2, width * estimate.width),
                      top: 1,
                      bottom: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  if (estimate.hasEvidence)
                    Positioned(
                      left: (width * estimate.rate - 2).clamp(0, width - 4),
                      top: -2,
                      child: Container(
                        width: 4,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CompactEvidenceStat extends StatelessWidget {
  const _CompactEvidenceStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
        ),
      ],
    ),
  );
}

class _AnalyticsRangeSelector extends StatelessWidget {
  const _AnalyticsRangeSelector({
    required this.selected,
    required this.available,
    required this.onChanged,
  });

  final int selected;
  final int available;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'La tua forma',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 3),
        Text(
          'Finestre omogenee, eventi reali, campione dichiarato.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
    final selector = SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 5, label: Text('5')),
        ButtonSegment(value: 10, label: Text('10')),
        ButtonSegment(value: 20, label: Text('20')),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -2, vertical: -2),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = constraints.maxWidth < 360
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 10), selector],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  selector,
                ],
              );
        return Stack(
          children: [
            content,
            Semantics(
              label: '$available partite totali disponibili',
              child: const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _AnalyticsMetric {
  const _AnalyticsMetric(
    this.label,
    this.value,
    this.icon, {
    this.color = Colors.white,
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;
}

class _AnalyticsMetricGrid extends StatelessWidget {
  const _AnalyticsMetricGrid({required this.metrics});

  final List<_AnalyticsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 7),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: metric.color.withValues(alpha: 0.75),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(metric.icon, size: 14, color: metric.color),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: metric.color,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (metric.detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      metric.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MatchPerformanceChart extends StatelessWidget {
  const _MatchPerformanceChart({required this.matches});

  final List<MatchSummary> matches;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label:
          'Grafico della quota di punti vinti e persi nelle ultime ${matches.length} partite',
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: CustomPaint(painter: _MatchPerformancePainter(matches)),
      ),
    );
  }
}

class _MatchPerformancePainter extends CustomPainter {
  const _MatchPerformancePainter(this.matches);

  final List<MatchSummary> matches;

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty) return;
    const horizontalPadding = 9.0;
    const topPadding = 9.0;
    const bottomPadding = 20.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - horizontalPadding * 2;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) {
      final y = topPadding + chartHeight * line / 3;
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        grid,
      );
    }

    Offset point(int index, double value) {
      final x = matches.length == 1
          ? size.width / 2
          : horizontalPadding + chartWidth * index / (matches.length - 1);
      final y = topPadding + chartHeight * (1 - value.clamp(0, 1));
      return Offset(x, y);
    }

    void drawSeries(double Function(MatchSummary) value, Color color) {
      final path = Path();
      for (var index = 0; index < matches.length; index++) {
        final current = point(index, value(matches[index]));
        index == 0
            ? path.moveTo(current.dx, current.dy)
            : path.lineTo(current.dx, current.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.4,
      );
      for (var index = 0; index < matches.length; index++) {
        canvas.drawCircle(
          point(index, value(matches[index])),
          2.8,
          Paint()..color = color,
        );
      }
    }

    double share(MatchSummary match) =>
        match.totalPoints == 0 ? 0.5 : match.pointsFor / match.totalPoints;
    drawSeries(share, RallyColors.win);
    drawSeries((match) => 1 - share(match), RallyColors.teamThem);

    for (var index = 0; index < matches.length; index++) {
      final x = matches.length == 1
          ? size.width / 2
          : horizontalPadding + chartWidth * index / (matches.length - 1);
      canvas.drawCircle(
        Offset(x, size.height - 7),
        3,
        Paint()
          ..color = matches[index].won
              ? RallyColors.lime
              : RallyColors.loss.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MatchPerformancePainter oldDelegate) =>
      oldDelegate.matches != matches;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Rating Padelandia (PRD F5): elo-lite locale che pesa le vittorie con la
/// difficoltà dell'avversario. Serie ricalcolata dallo storico, zero stato.
class _RatingCard extends ConsumerWidget {
  const _RatingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(ratingHistoryProvider).value;
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final rating = history.current.round();
    final delta = history.deltaOverLast(5);
    final deltaLabel =
        '${delta >= 0 ? '+' : ''}${delta.round()} nelle ultime '
        '${history.points.length < 5 ? history.points.length : 5} partite';
    final deltaColor = delta >= 0 ? RallyColors.win : RallyColors.loss;
    final series = history.points.length > 20
        ? history.points.sublist(history.points.length - 20)
        : history.points;

    return SectionCard(
      title: 'INDICE PADELANDIA · INDICATIVO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$rating',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: RallyColors.lime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(
                        delta >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: deltaColor,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          deltaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: deltaColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: 12),
            RepaintBoundary(
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RatingSparklinePainter(
                    ratings: [for (final p in series) p.rating],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Indice locale basato su risultato e difficoltà dichiarata. Non è '
            'un ranking federale e diventa più stabile con lo storico.',
            style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RatingSparklinePainter extends CustomPainter {
  _RatingSparklinePainter({required this.ratings});

  final List<double> ratings;

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.length < 2) return;
    var min = ratings.first, max = ratings.first;
    for (final value in ratings) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    final span = (max - min) < 8 ? 8.0 : max - min;
    final mid = (max + min) / 2;
    final dx = size.width / (ratings.length - 1);
    double y(double value) =>
        size.height / 2 - (value - mid) / span * (size.height - 8);

    final path = Path()..moveTo(0, y(ratings.first));
    for (var i = 1; i < ratings.length; i++) {
      path.lineTo(i * dx, y(ratings[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = RallyColors.lime,
    );

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RallyColors.lime.withValues(alpha: 0.20),
            RallyColors.lime.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawCircle(
      Offset(size.width, y(ratings.last)),
      3.5,
      Paint()..color = RallyColors.lime,
    );
  }

  @override
  bool shouldRepaint(covariant _RatingSparklinePainter old) =>
      old.ratings.length != ratings.length ||
      (ratings.isNotEmpty &&
          old.ratings.isNotEmpty &&
          old.ratings.last != ratings.last);
}

/// Export PDF del report (PRD 8 Plus + H2): genera in locale e condivide.
class _ExportPdfCard extends ConsumerStatefulWidget {
  const _ExportPdfCard({required this.summaries});

  final List<MatchSummary> summaries;

  @override
  ConsumerState<_ExportPdfCard> createState() => _ExportPdfCardState();
}

class _ExportPdfCardState extends ConsumerState<_ExportPdfCard> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final me = ref.read(meProvider).value;
      final name = (me?.nickname.isNotEmpty == true)
          ? me!.nickname
          : (me?.name.isNotEmpty == true ? me!.name : 'Giocatore Padelandia');
      final bytes = await PdfReportService.seasonReport(
        playerName: name,
        windowLabel: 'ultime ${widget.summaries.length} partite',
        summaries: widget.summaries,
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'rallymate_report.pdf',
            ),
          ],
          text: 'Il mio report padel — generato con Padelandia',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export non riuscito. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGate(
      gateKey: 'pdf_export',
      entitled: (e) => e.pdfExport,
      child: SectionCard(
        title: 'EXPORT',
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Report PDF della finestra selezionata: stats, ruoli, '
                'difficoltà avversari e imprese.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white60,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _busy || widget.summaries.isEmpty ? null : _export,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Esporta PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
