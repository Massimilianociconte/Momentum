/// Matchmaking social (PRD K): scoring puro e deterministico, testabile
/// senza rete. Nessuna posizione precisa: solo compatibilità e badge.
library;

import 'dart:math' as math;

import 'package:rally_core/rally_core.dart';

/// Skill score 0-100 dal proprio storico (usato anche come mirror cloud
/// `profiles.skill_score`). Con zero partite parte da 62 (intermedio).
int playerScore(List<MatchSummary> summaries) {
  if (summaries.isEmpty) return 62;
  final played = summaries.length;
  final wins = summaries.where((m) => m.won).length;
  final winRate = wins / played;
  final clutch =
      summaries.map((m) => m.clutchScore).reduce((a, b) => a + b) / played;
  final streak = summaries
      .map((m) => m.bestStreak)
      .reduce((a, b) => math.max(a, b));
  final volume = math.min(12, played) / 12;
  final raw = 38 + winRate * 24 + clutch * 0.22 + volume * 10 + streak * 1.2;
  return raw.clamp(45, 98).round();
}

/// Badge leggibile dal punteggio (stessa scala ovunque).
String badgeForScore(int score) {
  if (score >= 90) return 'A+';
  if (score >= 82) return 'A-';
  if (score >= 74) return 'B+';
  if (score >= 66) return 'B';
  if (score >= 58) return 'C+';
  return 'C';
}

/// Compatibilità 0-100 tra me e un altro giocatore.
///
/// Pesi: vicinanza di livello 40, sovrapposizione disponibilità 20,
/// complementarità di ruolo 15, affinità di stile 15, affidabilità 10.
/// Deterministico: stessi input → stesso punteggio.
int compatibilityScore({
  required int myScore,
  required int otherScore,
  required String myAvailability,
  required String otherAvailability,
  required List<String> myStyles,
  required List<String> otherStyles,
  required String myRole,
  required String otherRole,
  required int otherReliability,
}) {
  // Livello: 0 diff = pieno, 30+ diff = zero.
  final diff = (myScore - otherScore).abs();
  final level = math.max(0.0, 1 - diff / 30) * 40;

  // Disponibilità: match esatto pieno, FLEX compatibile con tutto a metà.
  final availability = myAvailability == otherAvailability
      ? 20.0
      : (myAvailability == 'FLEX' || otherAvailability == 'FLEX')
      ? 12.0
      : 4.0;

  // Ruolo: LEFT+RIGHT è la coppia ideale; FLEX/UNDEFINED si adatta;
  // stesso lato fisso penalizza.
  final role = switch ((myRole, otherRole)) {
    ('LEFT', 'RIGHT') || ('RIGHT', 'LEFT') => 15.0,
    ('FLEX', _) || (_, 'FLEX') => 12.0,
    ('UNDEFINED', _) || (_, 'UNDEFINED') => 10.0,
    _ => 5.0, // stesso lato
  };

  // Stile: tag condivisi = intesa; nessun tag = neutro.
  final shared = myStyles.toSet().intersection(otherStyles.toSet()).length;
  final style = myStyles.isEmpty || otherStyles.isEmpty
      ? 9.0
      : math.min(15.0, 6.0 + shared * 4.5);

  final reliability = (otherReliability.clamp(0, 100)) / 100 * 10;

  return (level + availability + role + style + reliability)
      .clamp(0, 100)
      .round();
}

/// Posizione pseudo-casuale ma stabile sulla mappa (0.10-0.90) derivata
/// dall'id utente: la vera posizione non lascia mai il server (privacy PRD K).
({double dx, double dy}) mapPositionFor(String userId) {
  var h = 0;
  for (final c in userId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final dx = 0.10 + (h % 1000) / 1000 * 0.80;
  final dy = 0.10 + ((h ~/ 1000) % 1000) / 1000 * 0.80;
  return (dx: dx, dy: dy);
}
