/// Insight allenamento per atleti: carico settimanale (session-RPE),
/// rapporto acuto:cronico (ACWR) e focus consigliato dai dati partita.
/// Tutto puro e deterministico: testabile senza DB né rete.
library;

import 'package:rally_core/rally_core.dart';

import '../data/db/database.dart';

/// Carico di allenamento calcolato dai log locali.
///
/// Il carico di una sessione è `minuti × RPE` (session-RPE, Foster):
/// se RPE o minuti non sono registrati si usano default prudenti (6 e 30).
class TrainingLoad {
  const TrainingLoad({
    required this.sessionsThisWeek,
    required this.minutesThisWeek,
    required this.streakDays,
    required this.avgRpe7d,
    required this.acwr,
  });

  final int sessionsThisWeek;
  final int minutesThisWeek;

  /// Giorni consecutivi (a ritroso da oggi) con almeno una sessione.
  final int streakDays;

  /// RPE medio ultimi 7 giorni (0 se nessuna sessione).
  final double avgRpe7d;

  /// Acute:Chronic Workload Ratio: carico 7gg vs media settimanale 28gg.
  /// 0 quando non c'è storico sufficiente.
  final double acwr;

  /// Fascia di rischio secondo la letteratura (0.8-1.3 = sweet spot).
  String get zone {
    if (acwr == 0) return 'building';
    if (acwr < 0.8) return 'under';
    if (acwr <= 1.3) return 'optimal';
    if (acwr <= 1.5) return 'high';
    return 'danger';
  }

  String get zoneLabel => switch (zone) {
    'building' => 'Costruisci lo storico',
    'under' => 'Puoi spingere di più',
    'optimal' => 'Carico ottimale',
    'high' => 'Carico alto: dosa',
    _ => 'Rischio: recupera',
  };

  String get zoneAdvice => switch (zone) {
    'building' =>
      'Registra RPE e minuti a fine sessione: dopo 2-3 settimane il '
          'carico diventa una bussola.',
    'under' =>
      'Stai allenando meno del tuo standard: una sessione in più questa '
          'settimana mantiene gli adattamenti.',
    'optimal' =>
      'Sei nella zona 0.8-1.3: il volume attuale fa crescere senza '
          'accumulare rischio.',
    'high' =>
      'Il volume è salito in fretta: inserisci una sessione leggera o '
          'tecnica al posto di una intensa.',
    _ =>
      'Carico molto sopra il tuo standard: 1-2 giorni di recupero attivo '
          'valgono più di un altro allenamento.',
  };

  static TrainingLoad compute(DateTime now, List<TrainingLog> logs) {
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    int loadOf(TrainingLog l) {
      final minutes = l.minutes > 0 ? l.minutes : 30;
      final rpe = l.rpe > 0 ? l.rpe : 6;
      return minutes * rpe;
    }

    final completed = logs.where((l) => l.completed).toList();

    final thisWeek = completed
        .where((l) => l.dateMs >= weekStart.millisecondsSinceEpoch)
        .toList();
    final minutesThisWeek = thisWeek.fold(
      0,
      (a, l) => a + (l.minutes > 0 ? l.minutes : 30),
    );

    // Streak: giorni consecutivi con sessione, partendo da oggi o ieri.
    final trainedDays = completed
        .map((l) => DateTime.fromMillisecondsSinceEpoch(l.dateMs))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    var streak = 0;
    var cursor = trainedDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (trainedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // RPE medio 7 giorni.
    final sevenDaysAgo = today
        .subtract(const Duration(days: 6))
        .millisecondsSinceEpoch;
    final recent = completed.where((l) => l.dateMs >= sevenDaysAgo).toList();
    final withRpe = recent.where((l) => l.rpe > 0).toList();
    final avgRpe = withRpe.isEmpty
        ? 0.0
        : withRpe.fold(0, (a, l) => a + l.rpe) / withRpe.length;

    // ACWR: carico 7gg vs media settimanale dei 28gg precedenti.
    final acuteLoad = recent.fold(0, (a, l) => a + loadOf(l));
    final chronicStart = today
        .subtract(const Duration(days: 34))
        .millisecondsSinceEpoch;
    final chronicEnd = sevenDaysAgo;
    final chronicLogs = completed
        .where((l) => l.dateMs >= chronicStart && l.dateMs < chronicEnd)
        .toList();
    final chronicWeekly = chronicLogs.fold(0, (a, l) => a + loadOf(l)) / 4.0;
    final acwr = chronicWeekly < 60
        ? 0.0 // storico insufficiente: nessun giudizio.
        : acuteLoad / chronicWeekly;

    return TrainingLoad(
      sessionsThisWeek: thisWeek.length,
      minutesThisWeek: minutesThisWeek,
      streakDays: streak,
      avgRpe7d: avgRpe,
      acwr: double.parse(acwr.toStringAsFixed(2)),
    );
  }
}

/// Focus settimanale consigliato incrociando i dati partita.
class TrainingFocusPlan {
  const TrainingFocusPlan({
    required this.title,
    required this.subtitle,
    required this.focus,
    required this.metric,
    required this.microGoal,
    this.suggestedTrainingIds = const [],
  });

  final String title;
  final String subtitle;
  final String focus;
  final String metric;
  final String microGoal;

  /// Id dei template seed più adatti al focus (mostrati come scorciatoia).
  final List<String> suggestedTrainingIds;
}

TrainingFocusPlan recommendFocus(List<MatchSummary> summaries) {
  if (summaries.isEmpty) {
    return const TrainingFocusPlan(
      title: 'Costruisci la prima base dati',
      subtitle:
          'Completa un allenamento breve e registra il prossimo match: '
          'da lì Padelandia collegherà punti deboli e routine.',
      focus: 'volée + uscita parete',
      metric: 'dati in arrivo',
      microGoal: '2 sessioni base da 25-30 min',
      suggestedTrainingIds: ['tr_volee', 'tr_parete', 'tr_warmup'],
    );
  }
  final played = summaries.length;
  final wins = summaries.where((m) => m.won).length;
  final winRate = wins / played;
  final clutch =
      summaries.map((m) => m.clutchScore).reduce((a, b) => a + b) / played;
  final avgDiff =
      summaries.map((m) => m.opponentDifficulty.score).reduce((a, b) => a + b) /
      played;

  // Tie-break e punti decisivi: i dati più specifici vincono sui generici.
  final tbPlayed =
      summaries.fold(0, (a, m) => a + m.tieBreakPointsPlayed) +
      summaries.fold(0, (a, m) => a + m.superTieBreakPointsPlayed);
  final tbWon =
      summaries.fold(0, (a, m) => a + m.tieBreakPointsWon) +
      summaries.fold(0, (a, m) => a + m.superTieBreakPointsWon);
  final decPlayed = summaries.fold(0, (a, m) => a + m.decisivePointsPlayed);
  final decWon = summaries.fold(0, (a, m) => a + m.decisivePointsWon);

  if (tbPlayed >= 10 && tbWon / tbPlayed < 0.45) {
    return TrainingFocusPlan(
      title: 'Focus: tie-break',
      subtitle:
          'Vinci ${(tbWon / tbPlayed * 100).round()}% dei punti nei '
          'tie-break: la differenza lì è routine mentale, non tecnica.',
      focus: 'tie-break training',
      metric: 'TB ${(tbWon / tbPlayed * 100).round()}%',
      microGoal: '3 tie-break simulati + routine pre-punto',
      suggestedTrainingIds: const ['tr_p_tb', 'tr_p_pressure'],
    );
  }
  if (decPlayed >= 12 && decWon / decPlayed < 0.42) {
    return TrainingFocusPlan(
      title: 'Focus: punti decisivi',
      subtitle:
          'Sui punti che pesano (parità, golden point) il rendimento cala: '
          'allena scelte semplici sotto pressione.',
      focus: 'pressione + scelte',
      metric: 'decisivi ${(decWon / decPlayed * 100).round()}%',
      microGoal: 'Game secchi 0-30 due volte a settimana',
      suggestedTrainingIds: const ['tr_p_pressure', 'tr_p_tb'],
    );
  }
  if (clutch < 55) {
    return const TrainingFocusPlan(
      title: 'Focus: punti decisivi',
      subtitle:
          'Il clutch score è sotto la zona comfort: servono routine brevi, '
          'tie-break simulati e respirazione tra i punti.',
      focus: 'tie-break training',
      metric: 'clutch basso',
      microGoal: '3 tie-break simulati prima del weekend',
      suggestedTrainingIds: ['tr_p_tb'],
    );
  }
  if (winRate < .50) {
    return TrainingFocusPlan(
      title: 'Focus: stabilità sotto pressione',
      subtitle:
          'Padelandia suggerisce controllo di rete e lob difensivo per '
          'ridurre errori gratuiti e recuperare campo.',
      focus: 'controllo + lob',
      metric: 'win rate ${(winRate * 100).round()}%',
      microGoal: '2 sessioni controllo, 1 uscita di parete',
      suggestedTrainingIds: const ['tr_volee', 'tr_difesa', 'tr_parete'],
    );
  }
  if (avgDiff >= 4) {
    return TrainingFocusPlan(
      title: 'Focus: partite dure',
      subtitle:
          'Stai affrontando avversari forti: lavora su servizio + primo '
          'colpo e transizione rapida verso la rete.',
      focus: 'primo colpo',
      metric: 'diff. media ${avgDiff.toStringAsFixed(1)}/5',
      microGoal: '40 servizi mirati + 20 prime volée',
      suggestedTrainingIds: const ['tr_servizio', 'tr_p_transition'],
    );
  }
  return TrainingFocusPlan(
    title: 'Mantieni ritmo e crescita',
    subtitle:
        'La base è buona: alterna routine tecnica e programma premium per '
        'trasformare continuità in vantaggio competitivo.',
    focus: 'routine completa',
    metric: 'win rate ${(winRate * 100).round()}%',
    microGoal: '2 sessioni tecniche + 1 sessione clutch',
    suggestedTrainingIds: const ['tr_p_condition', 'tr_p_transition'],
  );
}
