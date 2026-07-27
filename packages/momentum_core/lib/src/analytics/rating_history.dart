/// Rating Momentum (PRD F5): elo-lite personale calcolato in locale dalla
/// cronologia dei match completati.
///
/// L'avversario di ogni partita non ha un rating reale: viene stimato dal
/// proprio rating corrente più l'Opponent Difficulty dichiarato/derivato,
/// con la stessa scala usata da [OpponentDifficultyScore] (200 elo ≈ 1
/// gradino di difficoltà). Il risultato è deterministico, spiegabile e
/// ricalcolabile da zero a ogni lettura: nessuno stato persistito oltre
/// ai [MatchSummary] già esistenti.
library;

import 'aggregate_stats.dart';

/// Rating dopo una singola partita completata.
class RatingPoint {
  const RatingPoint({
    required this.matchId,
    required this.endTimeMs,
    required this.rating,
    required this.delta,
    required this.won,
  });

  final String matchId;
  final int endTimeMs;

  /// Rating DOPO questa partita.
  final double rating;

  /// Variazione prodotta da questa partita (positiva o negativa).
  final double delta;
  final bool won;
}

/// Serie storica del rating, in ordine cronologico (vecchio → nuovo).
class RatingHistory {
  const RatingHistory._(this.points);

  final List<RatingPoint> points;

  /// Scala condivisa con [OpponentDifficultyScore]: 1 gradino di
  /// difficoltà ≈ 200 punti elo.
  static const eloPerDifficultyStep = 200.0;

  bool get isEmpty => points.isEmpty;

  /// Rating attuale (dopo l'ultima partita). [RatingEngine.initial] se non
  /// c'è ancora storico.
  double get current =>
      points.isEmpty ? RatingEngine.initial : points.last.rating;

  /// Variazione del rating nelle ultime [n] partite.
  double deltaOverLast(int n) {
    if (points.isEmpty || n <= 0) return 0;
    final start = points.length <= n
        ? RatingEngine.initial
        : points[points.length - n - 1].rating;
    return points.last.rating - start;
  }

  /// Ricostruisce la serie da [summaries] (accetta qualsiasi ordine: viene
  /// riordinata per endTimeMs crescente, a parità di tempo per matchId così
  /// il risultato è stabile tra ricalcoli).
  static RatingHistory compute(List<MatchSummary> summaries) {
    final ordered = [...summaries]
      ..sort((a, b) {
        final byTime = a.endTimeMs.compareTo(b.endTimeMs);
        return byTime != 0 ? byTime : a.matchId.compareTo(b.matchId);
      });

    var rating = RatingEngine.initial;
    final points = <RatingPoint>[];
    for (final match in ordered) {
      final opponent =
          rating + (match.opponentDifficulty.score - 3) * eloPerDifficultyStep;
      final next = RatingEngine.update(
        rating: rating,
        opponentRating: opponent,
        won: match.won,
      );
      points.add(
        RatingPoint(
          matchId: match.matchId,
          endTimeMs: match.endTimeMs,
          rating: next,
          delta: next - rating,
          won: match.won,
        ),
      );
      rating = next;
    }
    return RatingHistory._(List.unmodifiable(points));
  }
}
