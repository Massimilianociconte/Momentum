/// Gruppi amici + classifiche private (PRD 8 Pro, migration 20260713120000).
///
/// Il gruppo vive sul cloud: si crea con piano Pro, si entra con un codice
/// invito a 8 caratteri (stile Duo). La classifica confronta SOLO aggregati
/// (partite, vittorie, streak) che ogni membro pubblica dal proprio storico
/// locale — nessun evento-partita lascia il device.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'cloud_service.dart';

const _netTimeout = Duration(seconds: 12);
const _timeoutMessage = 'Rete lenta o assente. Riprova.';

SupabaseClient? get _client => cloudClient;

class FriendGroup {
  const FriendGroup({
    required this.groupId,
    required this.name,
    required this.inviteCode,
    required this.isOwner,
    required this.memberCount,
  });

  final String groupId;
  final String name;
  final String inviteCode;
  final bool isOwner;
  final int memberCount;

  static FriendGroup fromRow(Map<String, dynamic> r) => FriendGroup(
    groupId: r['group_id'] as String,
    name: r['name'] as String? ?? '',
    inviteCode: r['invite_code'] as String? ?? '',
    isOwner: r['is_owner'] as bool? ?? false,
    memberCount: (r['member_count'] as num?)?.toInt() ?? 0,
  );
}

class GroupMemberStanding {
  const GroupMemberStanding({
    required this.userId,
    required this.displayName,
    required this.level,
    required this.skillScore,
    required this.matches,
    required this.wins,
    required this.streak,
    required this.isOwner,
    this.avatarUrl,
    this.statsUpdatedAt,
  });

  final String userId;
  final String displayName;
  final String level;
  final int skillScore;
  final int matches;
  final int wins;
  final int streak;
  final bool isOwner;
  final String? avatarUrl;
  final DateTime? statsUpdatedAt;

  double get winRate => matches == 0 ? 0 : wins / matches;

  static GroupMemberStanding fromRow(Map<String, dynamic> r) {
    final nickname = r['nickname'] as String? ?? '';
    final name = r['name'] as String? ?? '';
    return GroupMemberStanding(
      userId: r['user_id'] as String,
      displayName: nickname.isNotEmpty ? nickname : name,
      level: r['level'] as String? ?? '',
      skillScore: (r['skill_score'] as num?)?.toInt() ?? 0,
      matches: (r['stat_matches'] as num?)?.toInt() ?? 0,
      wins: (r['stat_wins'] as num?)?.toInt() ?? 0,
      streak: (r['stat_streak'] as num?)?.toInt() ?? 0,
      isOwner: r['is_owner'] as bool? ?? false,
      avatarUrl: r['avatar_url'] as String?,
      statsUpdatedAt: DateTime.tryParse(r['stats_updated_at'] as String? ?? ''),
    );
  }
}

/// Risultato uniforme delle RPC jsonb {ok, error, ...}.
typedef GroupActionResult = ({
  bool ok,
  String? error,
  Map<String, dynamic> data,
});

class FriendGroupsService {
  static bool get available => _client != null;

  static String _translate(String? code) => switch (code) {
    'auth_required' => 'Accedi prima al tuo account.',
    'pro_required' => 'La creazione di gruppi richiede il piano Pro.',
    'invalid_name' => 'Dai un nome al gruppo (max 40 caratteri).',
    'too_many_groups' => 'Hai raggiunto il limite di 10 gruppi creati.',
    'invalid_code' => 'Il codice invito ha 8 caratteri.',
    'not_found' => 'Nessun gruppo trovato con questo codice.',
    'group_full' => 'Il gruppo è al completo (32 membri).',
    'rate_limited' => 'Troppi tentativi: riprova tra qualche minuto.',
    'not_available' => 'Operazione non disponibile.',
    'not_owner' => 'Solo chi ha creato il gruppo può farlo.',
    'use_leave' => 'Per uscire usa "Lascia gruppo".',
    'retry' => 'Riprova: generazione codice non riuscita.',
    _ => 'Operazione non riuscita. Riprova.',
  };

  static Future<GroupActionResult> _rpc(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final c = _client;
    if (c == null) {
      return (
        ok: false,
        error: 'Servizi online non disponibili.',
        data: const <String, dynamic>{},
      );
    }
    try {
      final raw = await c.rpc(fn, params: params).timeout(_netTimeout);
      final map = (raw as Map).cast<String, dynamic>();
      if (map['ok'] == true) return (ok: true, error: null, data: map);
      return (ok: false, error: _translate(map['error'] as String?), data: map);
    } on TimeoutException {
      return (
        ok: false,
        error: _timeoutMessage,
        data: const <String, dynamic>{},
      );
    } on PostgrestException catch (e) {
      return (ok: false, error: e.message, data: const <String, dynamic>{});
    } catch (_) {
      return (
        ok: false,
        error: 'Operazione non riuscita.',
        data: const <String, dynamic>{},
      );
    }
  }

  static Future<List<FriendGroup>> myGroups() async {
    final c = _client;
    if (c == null || c.auth.currentUser == null) return const [];
    final rows = await c.rpc('my_friend_groups').timeout(_netTimeout);
    return (rows as List)
        .map((r) => FriendGroup.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<GroupActionResult> create(String name) =>
      _rpc('create_friend_group', {'p_name': name});

  static Future<GroupActionResult> join(String code) =>
      _rpc('join_friend_group', {'p_code': code});

  static Future<GroupActionResult> leave(String groupId) =>
      _rpc('leave_friend_group', {'p_group_id': groupId});

  static Future<GroupActionResult> removeMember(
    String groupId,
    String userId,
  ) =>
      _rpc('remove_group_member', {'p_group_id': groupId, 'p_user_id': userId});

  static Future<List<GroupMemberStanding>> leaderboard(String groupId) async {
    final c = _client;
    if (c == null) return const [];
    final rows = await c
        .rpc('friend_group_leaderboard', params: {'p_group_id': groupId})
        .timeout(_netTimeout);
    return (rows as List)
        .map(
          (r) =>
              GroupMemberStanding.fromRow((r as Map).cast<String, dynamic>()),
        )
        .toList();
  }
}

/// Pubblica su profiles gli aggregati usati dalle classifiche di gruppo.
/// Best-effort: non solleva mai; il prossimo refresh riallinea.
Future<void> publishGroupStats(Ref ref) async {
  final c = _client;
  final uid = c?.auth.currentUser?.id;
  if (c == null || uid == null) return;
  try {
    final summaries = await ref.read(matchRepoProvider).completedSummaries();
    var streak = 0;
    for (final m in summaries) {
      if (!m.won) break;
      streak++;
    }
    await c
        .from('profiles')
        .update({
          'stat_matches': summaries.length,
          'stat_wins': summaries.where((m) => m.won).length,
          'stat_streak': streak,
          'stats_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', uid)
        .timeout(_netTimeout);
  } catch (_) {
    // Silenzioso: la classifica mostrerà l'ultimo aggiornamento riuscito.
  }
}
