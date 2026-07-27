library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locks local phone scoring when a cloud-mediated wearable owns the match.
///
/// Apple Watch / Wear OS stay peer-first and allow dual input. Garmin and
/// Fitbit use higher-latency paths where concurrent phone taps double-count.
class MatchScoringLockService {
  MatchScoringLockService();

  static const _prefix = 'match_scoring_owner_v1_';
  static const _reclaimPrefix = 'match_scoring_reclaimed_v1_';

  /// Providers that must exclusive-own scoring after a successful dispatch.
  static bool locksPhoneScoring(String provider) =>
      provider == 'GARMIN_CONNECT_IQ' || provider == 'FITBIT_OS';

  Future<void> lock(String matchId, String provider) async {
    if (matchId.isEmpty || !locksPhoneScoring(provider)) return;
    final prefs = await SharedPreferences.getInstance();
    // Sticky reclaim: do not re-lock after user explicitly took phone control.
    if (prefs.getBool('$_reclaimPrefix$matchId') == true) return;
    await prefs.setString('$_prefix$matchId', provider);
  }

  Future<void> unlock(String matchId) async {
    if (matchId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$matchId');
  }

  /// User reclaim: unlock and prevent wearable merge from re-locking this match.
  Future<void> reclaimPhone(String matchId) async {
    if (matchId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$matchId');
    await prefs.setBool('$_reclaimPrefix$matchId', true);
  }

  Future<void> clearReclaim(String matchId) async {
    if (matchId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_reclaimPrefix$matchId');
  }

  Future<String?> owner(String matchId) async {
    if (matchId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$matchId');
  }

  Future<bool> isPhoneScoringBlocked(String matchId) async {
    final provider = await owner(matchId);
    return provider != null && locksPhoneScoring(provider);
  }

  /// Clear lock when the match is no longer actively owned by a wearable
  /// (completed, abandoned, or user reclaim).
  Future<void> unlockIfPresent(String matchId) async {
    await unlock(matchId);
    await clearReclaim(matchId);
  }
}

final matchScoringLockProvider = Provider<MatchScoringLockService>(
  (_) => MatchScoringLockService(),
);
