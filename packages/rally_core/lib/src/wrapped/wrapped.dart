/// Rally Wrapped (PRD Modulo G): shareable card data generators.
/// Pure data — rendering (immagine/link) è compito dell'app.
library;

import '../analytics/aggregate_stats.dart';
import '../analytics/match_stats.dart';
import '../model/enums.dart';

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

  static MatchWrappedData build({
    required MatchStats stats,
    required TeamId ourTeam,
    required bool won,
    required String resultLine,
    required String teamLabel,
    required OpponentDifficulty difficulty,
    required PadelRole role,
  }) {
    final us = stats.forTeam(ourTeam);
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
    );
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
