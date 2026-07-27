/// Opponent Difficulty Score (PRD F5): 1..5 index combining declared level,
/// internal rating, history, tags, results and user feedback.
library;

import 'aggregate_stats.dart';
import '../model/enums.dart';

class DifficultyInputs {
  const DifficultyInputs({
    this.declaredOpponentLevel,
    this.playerLevel,
    this.opponentRating,
    this.playerRating,
    this.previousResultsVsOpponent = const [],
    this.tags = const {},
    this.userFeedback,
  });

  final PlayerLevel? declaredOpponentLevel;
  final PlayerLevel? playerLevel;
  final double? opponentRating;
  final double? playerRating;

  /// true = win, ordered oldest→newest.
  final List<bool> previousResultsVsOpponent;
  final Set<OpponentTag> tags;

  /// Direct user feedback 1..5, dominates when present.
  final int? userFeedback;
}

class OpponentDifficultyScore {
  static OpponentDifficulty compute(DifficultyInputs i) {
    if (i.userFeedback != null) {
      return OpponentDifficulty.fromScore(i.userFeedback!);
    }

    var score = 3.0;

    // Declared level difference: each level ≈ 0.8 difficulty steps.
    if (i.declaredOpponentLevel != null && i.playerLevel != null) {
      final d = i.declaredOpponentLevel!.numeric - i.playerLevel!.numeric;
      score += d * 0.8;
    }

    // Internal rating difference: 200 elo ≈ 1 difficulty step.
    if (i.opponentRating != null && i.playerRating != null) {
      final d = (i.opponentRating! - i.playerRating!) / 200.0;
      score += d.clamp(-2.0, 2.0);
    }

    // History: losing often to them = harder.
    if (i.previousResultsVsOpponent.length >= 2) {
      final losses = i.previousResultsVsOpponent.where((w) => !w).length;
      final lossRate = losses / i.previousResultsVsOpponent.length;
      score += (lossRate - 0.5) * 2.0;
    }

    // Tags nudge the score.
    if (i.tags.contains(OpponentTag.muchStronger)) score += 1.2;
    if (i.tags.contains(OpponentTag.slightlyStronger)) score += 0.6;
    if (i.tags.contains(OpponentTag.beginners)) score -= 1.2;
    if (i.tags.contains(OpponentTag.tournament)) score += 0.3;

    return OpponentDifficulty.fromScore(score.clamp(1, 5));
  }

  /// PRD F5 statistics over a match history.
  static DifficultyStats stats(List<MatchSummary> matches) {
    var vsSameStreak = 0, bestVsSameStreak = 0;
    var winsVsHarder = 0, lossesVsEasier = 0;
    var upsetWins = 0, upsetLosses = 0;
    MatchSummary? bestWin, worstLoss;

    for (final m in matches) {
      final d = m.opponentDifficulty.score;
      if (d == 3) {
        vsSameStreak = m.won ? vsSameStreak + 1 : 0;
        if (vsSameStreak > bestVsSameStreak) bestVsSameStreak = vsSameStreak;
      }
      if (d >= 4 && m.won) {
        winsVsHarder++;
        if (d == 5) upsetWins++;
        if (bestWin == null || d > bestWin.opponentDifficulty.score) {
          bestWin = m;
        }
      }
      if (d <= 2 && !m.won) {
        lossesVsEasier++;
        if (d == 1) upsetLosses++;
        if (worstLoss == null || d < worstLoss.opponentDifficulty.score) {
          worstLoss = m;
        }
      }
    }

    return DifficultyStats(
      bestStreakVsSameLevel: bestVsSameStreak,
      winsVsHarder: winsVsHarder,
      lossesVsEasier: lossesVsEasier,
      upsetWins: upsetWins,
      upsetLosses: upsetLosses,
      bestWinMatchId: bestWin?.matchId,
      worstLossMatchId: worstLoss?.matchId,
    );
  }
}

class DifficultyStats {
  const DifficultyStats({
    required this.bestStreakVsSameLevel,
    required this.winsVsHarder,
    required this.lossesVsEasier,
    required this.upsetWins,
    required this.upsetLosses,
    required this.bestWinMatchId,
    required this.worstLossMatchId,
  });

  final int bestStreakVsSameLevel;
  final int winsVsHarder;
  final int lossesVsEasier;
  final int upsetWins;
  final int upsetLosses;
  final String? bestWinMatchId;
  final String? worstLossMatchId;
}
