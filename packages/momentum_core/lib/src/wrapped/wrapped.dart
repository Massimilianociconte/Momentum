/// Rally Wrapped (PRD Modulo G): shareable card data generators.
/// Pure data — rendering (immagine/link) è compito dell'app.
library;

import '../analytics/aggregate_stats.dart';
import '../analytics/match_stats.dart';
import '../model/enums.dart';
import '../model/score_state.dart';

/// One set as it must appear on a shareable scoreboard, already oriented to
/// the sharer's team.
class WrappedSetScore {
  const WrappedSetScore({
    required this.us,
    required this.them,
    this.tieBreakUs,
    this.tieBreakThem,
    this.isSuperTieBreak = false,
  });

  final int us;
  final int them;

  /// Tie-break detail, shown as a superscript next to the games.
  final int? tieBreakUs;
  final int? tieBreakThem;
  final bool isSuperTieBreak;

  bool get wonByUs => us > them;

  /// Losing side's tie-break points: the number a scoreboard prints small,
  /// e.g. 7-6⁵.
  int? get tieBreakLoserPoints {
    final a = tieBreakUs;
    final b = tieBreakThem;
    if (a == null || b == null) return null;
    return a < b ? a : b;
  }
}

/// A statistic the card is allowed to print.
///
/// Only built when the metric has a real sample, so a card never shows a
/// fabricated `0%` for something that was never played (no break point faced,
/// no tie-break, a match scored without serve tracking…).
class WrappedStat {
  const WrappedStat({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;

  /// Sample behind the value, e.g. "3/5". Null when the value is self-evident.
  final String? detail;
}

class MatchWrappedData {
  const MatchWrappedData({
    required this.resultLine,
    required this.durationMinutes,
    required this.teamLabel,
    required this.totalPoints,
    required this.bestStreak,
    required this.keyMoment,
    required this.clutchScore,
    required this.opponentDifficulty,
    required this.rolePlayed,
    required this.statisticalMvp,
    required this.headline,
    this.won = false,
    this.sets = const [],
    this.pointsWon = 0,
    this.pointsLost = 0,
    this.momentum = const [],
    this.stats = const [],
    this.formatLabel,
    this.playedAt,
    this.freePlay = false,
  });

  final String resultLine;
  final int durationMinutes;
  final String teamLabel;
  final int totalPoints;
  final int bestStreak;
  final String? keyMoment;
  final int clutchScore;
  final OpponentDifficulty opponentDifficulty;
  final PadelRole rolePlayed;

  /// "MVP statistico": la metrica dove il team ha brillato di più.
  final String statisticalMvp;

  /// Frase dinamica, e.g. "Hai vinto una battaglia da 143 punti."
  final String headline;

  final bool won;

  /// Set giocati, già orientati sulla prospettiva di chi condivide.
  final List<WrappedSetScore> sets;

  final int pointsWon;
  final int pointsLost;

  /// Differenziale punti cumulato dalla nostra prospettiva, punto per punto.
  /// È la serie reale usata per disegnare la curva di momentum.
  final List<int> momentum;

  /// Metriche con campione reale, già pronte da stampare.
  final List<WrappedStat> stats;

  final String? formatLabel;
  final DateTime? playedAt;
  final bool freePlay;

  /// Quota di punti vinti sul totale, 0–1. Null se non ci sono punti.
  double? get pointShare {
    final total = pointsWon + pointsLost;
    return total == 0 ? null : pointsWon / total;
  }

  static MatchWrappedData build({
    required MatchStats stats,
    required TeamId ourTeam,
    required bool won,
    required String resultLine,
    required String teamLabel,
    required OpponentDifficulty difficulty,
    required PadelRole role,
    List<SetResult> completedSets = const [],
    String? formatLabel,
    DateTime? playedAt,
    bool freePlay = false,
  }) {
    final us = stats.forTeam(ourTeam);
    final mirror = ourTeam == TeamId.b;
    final headline = _headline(
      won: won,
      totalPoints: stats.totalPoints,
      clutch: us.clutchScore,
      difficulty: difficulty,
      comeback: stats.keyMoment?.description.contains('Match point') ?? false,
    );

    return MatchWrappedData(
      resultLine: resultLine,
      durationMinutes: (stats.durationMs / 60000).round(),
      teamLabel: teamLabel,
      totalPoints: stats.totalPoints,
      bestStreak: us.bestStreak,
      keyMoment: stats.keyMoment?.description,
      clutchScore: us.clutchScore,
      opponentDifficulty: difficulty,
      rolePlayed: role,
      statisticalMvp: _mvpMetric(us),
      headline: headline,
      won: won,
      sets: [
        for (final set in completedSets)
          WrappedSetScore(
            us: mirror ? set.gamesB : set.gamesA,
            them: mirror ? set.gamesA : set.gamesB,
            tieBreakUs: mirror ? set.tieBreakB : set.tieBreakA,
            tieBreakThem: mirror ? set.tieBreakA : set.tieBreakB,
            isSuperTieBreak: set.isSuperTieBreak,
          ),
      ],
      pointsWon: us.pointsWon,
      pointsLost: us.pointsLost,
      // MomentumPoint.diff is always A-minus-B: flip it for team B so the
      // curve rises when the sharer is ahead.
      momentum: [
        for (final point in stats.momentum) mirror ? -point.diff : point.diff,
      ],
      stats: _realStats(us),
      formatLabel: formatLabel,
      playedAt: playedAt,
      freePlay: freePlay,
    );
  }

  /// Metrics with an actual sample behind them, strongest first.
  ///
  /// A metric with zero trials is omitted rather than printed as `0%`: the
  /// card must never suggest a failure that never had the chance to happen.
  static List<WrappedStat> _realStats(TeamMatchStats us) {
    String pct(double rate) => '${(rate * 100).round()}%';
    final entries = <(WrappedStat, double)>[
      if (us.breakPointsPlayed > 0)
        (
          WrappedStat(
            label: 'Break point',
            value: pct(us.breakPointsConverted / us.breakPointsPlayed),
            detail: '${us.breakPointsConverted}/${us.breakPointsPlayed}',
          ),
          us.breakPointsConverted / us.breakPointsPlayed,
        ),
      if (us.pointsPlayedOnServe > 0)
        (
          WrappedStat(
            label: 'Al servizio',
            value: pct(us.serveHoldRate),
            detail: '${us.pointsWonOnServe}/${us.pointsPlayedOnServe}',
          ),
          us.serveHoldRate,
        ),
      if (us.decisivePointsPlayed > 0)
        (
          WrappedStat(
            label: 'Punti decisivi',
            value: pct(us.decisiveRate),
            detail: '${us.decisivePointsWon}/${us.decisivePointsPlayed}',
          ),
          us.decisiveRate,
        ),
      if (us.tieBreakPointsPlayed > 0)
        (
          WrappedStat(
            label: 'Tie-break',
            value: pct(us.tieBreakRate),
            detail: '${us.tieBreakPointsWon}/${us.tieBreakPointsPlayed}',
          ),
          us.tieBreakRate,
        ),
      if (us.gamePointsSaved > 0)
        (
          WrappedStat(
            label: 'Game point annullati',
            value: '${us.gamePointsSaved}',
          ),
          1,
        ),
    ];
    entries.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final entry in entries) entry.$1];
  }

  static String _mvpMetric(TeamMatchStats us) {
    final candidates = <(String, double)>[
      ('Clutch score ${us.clutchScore}/100', us.clutchScore / 100),
      if (us.tieBreakPointsPlayed > 0)
        ('Tie-break ${(us.tieBreakRate * 100).round()}%', us.tieBreakRate),
      if (us.breakPointsPlayed > 0)
        (
          'Break point ${us.breakPointsConverted}/${us.breakPointsPlayed}',
          us.breakPointsPlayed == 0
              ? 0
              : us.breakPointsConverted / us.breakPointsPlayed,
        ),
      if (us.pointsPlayedOnServe > 0)
        ('Al servizio ${(us.serveHoldRate * 100).round()}%', us.serveHoldRate),
      ('Miglior streak ${us.bestStreak} punti', us.bestStreak / 10),
    ];
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    return candidates.first.$1;
  }

  static String _headline({
    required bool won,
    required int totalPoints,
    required int clutch,
    required OpponentDifficulty difficulty,
    required bool comeback,
  }) {
    if (comeback && won) return 'Rimonta da campioni: match point annullato!';
    if (won && difficulty.score >= 4) {
      return 'Impresa! Battuta una coppia più forte.';
    }
    if (won && totalPoints >= 120) {
      return 'Hai vinto una battaglia da $totalPoints punti.';
    }
    if (won && clutch >= 75) {
      return 'Freddi nei momenti che contano: clutch $clutch/100.';
    }
    if (won) return 'Vittoria di squadra. Avanti così!';
    if (!won && clutch >= 70) {
      return 'Sconfitta di misura: nei punti decisivi c\'eri.';
    }
    if (!won && difficulty.score >= 4) {
      return 'Hai tenuto testa a una coppia più forte.';
    }
    return 'Partita da rivedere: i dati dicono dove migliorare.';
  }
}

class WeeklyWrappedData {
  const WeeklyWrappedData({
    required this.matchesPlayed,
    required this.wins,
    required this.avgPointsFor,
    required this.bestTeamLabel,
    required this.bestRole,
    required this.improvementLine,
    required this.regressionLine,
    required this.bestStreak,
    required this.hardestOpponentBeaten,
    required this.headline,
  });

  final int matchesPlayed;
  final int wins;
  final double avgPointsFor;
  final String? bestTeamLabel;
  final PadelRole? bestRole;
  final String? improvementLine;
  final String? regressionLine;
  final int bestStreak;
  final String? hardestOpponentBeaten;
  final String headline;

  static WeeklyWrappedData build({
    required WeeklySummary summary,
    required List<Insight> insights,
    String? bestTeamLabel,
    String? hardestOpponentBeaten,
  }) {
    final h = ProgressAnalyzer.headline(insights);
    return WeeklyWrappedData(
      matchesPlayed: summary.matchesPlayed,
      wins: summary.wins,
      avgPointsFor: summary.avgPointsFor,
      bestTeamLabel: bestTeamLabel,
      bestRole: summary.bestRole,
      improvementLine: h.improvement?.text,
      regressionLine: h.regression?.text,
      bestStreak: summary.bestStreak,
      hardestOpponentBeaten: hardestOpponentBeaten,
      headline: _headline(summary),
    );
  }

  static String _headline(WeeklySummary s) {
    if (s.matchesPlayed == 0) return 'Settimana di riposo. Il campo aspetta.';
    if (s.winRate >= 0.75) {
      return 'Settimana dominante: ${s.wins} vittorie su ${s.matchesPlayed}.';
    }
    if (s.matchesPlayed >= 4) {
      return '${s.matchesPlayed} partite in 7 giorni. Che ritmo!';
    }
    return 'La tua settimana padel: ${s.wins}V-${s.losses}S.';
  }
}

class TeamWrappedData {
  const TeamWrappedData({
    required this.teamName,
    required this.record,
    required this.compatibilityScore,
    required this.bestStreak,
    required this.performanceVsLevels,
    required this.idealRoles,
    required this.headline,
  });

  final String teamName;

  /// e.g. "18V - 7S".
  final String record;

  /// 0–100 (PRD A2 compatibilità).
  final int compatibilityScore;
  final int bestStreak;

  /// e.g. "72% vs pari livello, 38% vs coppie difensive".
  final String performanceVsLevels;

  /// e.g. "Tu a sinistra, Luca a destra".
  final String idealRoles;
  final String headline;

  static TeamWrappedData build({
    required String teamName,
    required List<MatchSummary> matches,
    required String idealRoles,
  }) {
    final wins = matches.where((m) => m.won).length;
    final losses = matches.length - wins;

    var streak = 0, best = 0;
    for (final m in matches) {
      streak = m.won ? streak + 1 : 0;
      if (streak > best) best = streak;
    }

    final byDiff = <int, List<MatchSummary>>{};
    for (final m in matches) {
      byDiff.putIfAbsent(m.opponentDifficulty.score, () => []).add(m);
    }
    final parts = <String>[];
    for (final entry
        in byDiff.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final r = entry.value.where((m) => m.won).length / entry.value.length;
      parts.add('${(r * 100).round()}% vs difficoltà ${entry.key}/5');
    }

    return TeamWrappedData(
      teamName: teamName,
      record: '${wins}V - ${losses}S',
      compatibilityScore: compatibility(matches),
      bestStreak: best,
      performanceVsLevels: parts.join(' · '),
      idealRoles: idealRoles,
      headline: wins > losses
          ? '$teamName: coppia che vince non si cambia.'
          : '$teamName: i margini di crescita sono chiari.',
    );
  }

  /// Compatibility 0-100: win rate + clutch + closeness of contribution.
  static int compatibility(List<MatchSummary> matches) {
    if (matches.isEmpty) return 50;
    final winRate = matches.where((m) => m.won).length / matches.length;
    final avgClutch =
        matches.map((m) => m.clutchScore).reduce((a, b) => a + b) /
        matches.length;
    final score = winRate * 60 + (avgClutch / 100) * 40;
    return score.round().clamp(0, 100);
  }
}
