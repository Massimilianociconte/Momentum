/// Social-light (PRD K): scoperta giocatori, richieste contatto, proposte
/// partita e richieste team sul backend Supabase (migration 0004).
///
/// Regole di affidabilità: ogni chiamata ha timeout, ogni errore diventa un
/// messaggio italiano azionabile, gli errori RLS/duplicati sono distinti.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_service.dart';
import '../profile_image_service.dart';
import 'invite_service.dart';

const _netTimeout = Duration(seconds: 12);
const _timeoutMessage = 'Rete lenta o assente. Riprova.';

SupabaseClient? get _client => cloudClient;

/// Profilo pubblico essenziale di un giocatore visibile sul social.
class SocialPlayer {
  const SocialPlayer({
    required this.userId,
    required this.name,
    required this.nickname,
    required this.level,
    required this.role,
    required this.availability,
    required this.styleTags,
    required this.skillScore,
    required this.reliability,
    required this.homeArea,
    this.avatarUrl,
    this.preferredSide = 'UNDEFINED',
    this.dominantHand = 'RIGHT',
    this.club = '',
    this.bio = '',
    this.showOnlineStatus = false,
    this.showActivity = false,
    this.lastActiveAt,
    this.publicStatsEnabled = false,
    this.matchCount = 0,
    this.winRate = 0,
    this.badges = const [],
    this.preferredTime = '',
    this.mutualFriendsCount = 0,
  });

  final String userId;
  final String name;
  final String nickname;
  final String level;
  final String role;
  final String availability; // TODAY | EVENING | WEEKEND | FLEX
  final List<String> styleTags;
  final int skillScore;
  final int reliability;
  final String homeArea;
  final String? avatarUrl;
  final String preferredSide;
  final String dominantHand;
  final String club;
  final String bio;
  final bool showOnlineStatus;
  final bool showActivity;
  final DateTime? lastActiveAt;
  final bool publicStatsEnabled;
  final int matchCount;
  final int winRate;
  final List<String> badges;
  final String preferredTime;
  final int mutualFriendsCount;

  String get displayName => nickname.isNotEmpty ? nickname : name;

  SocialPlayer withAvatarUrl(String? value) => SocialPlayer(
    userId: userId,
    name: name,
    nickname: nickname,
    level: level,
    role: role,
    availability: availability,
    styleTags: styleTags,
    skillScore: skillScore,
    reliability: reliability,
    homeArea: homeArea,
    avatarUrl: value,
    preferredSide: preferredSide,
    dominantHand: dominantHand,
    club: club,
    bio: bio,
    showOnlineStatus: showOnlineStatus,
    showActivity: showActivity,
    lastActiveAt: lastActiveAt,
    publicStatsEnabled: publicStatsEnabled,
    matchCount: matchCount,
    winRate: winRate,
    badges: badges,
    preferredTime: preferredTime,
    mutualFriendsCount: mutualFriendsCount,
  );

  static SocialPlayer? fromRow(Map<String, dynamic> r) {
    final userId = r['user_id'] as String?;
    final name = (r['name'] as String?)?.trim() ?? '';
    if (userId == null || name.isEmpty) return null;
    return SocialPlayer(
      userId: userId,
      name: name,
      nickname: (r['nickname'] as String?) ?? '',
      level: (r['level'] as String?) ?? 'INTERMEDIATE',
      role: (r['preferred_role'] as String?) ?? 'UNDEFINED',
      availability: (r['availability'] as String?) ?? 'FLEX',
      styleTags: ((r['style_tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      skillScore: (r['skill_score'] as num?)?.toInt() ?? 60,
      reliability: (r['reliability_score'] as num?)?.toInt() ?? 80,
      homeArea: (r['home_area'] as String?) ?? '',
      avatarUrl: r['avatar_url'] as String?,
      preferredSide: (r['preferred_side'] as String?) ?? 'UNDEFINED',
      dominantHand: (r['dominant_hand'] as String?) ?? 'RIGHT',
      club: (r['club'] as String?) ?? '',
      bio: (r['bio'] as String?) ?? '',
      showOnlineStatus: r['show_online_status'] as bool? ?? false,
      showActivity: r['show_activity'] as bool? ?? false,
      lastActiveAt: DateTime.tryParse((r['last_active_at'] as String?) ?? ''),
      publicStatsEnabled: r['public_stats_enabled'] as bool? ?? false,
      matchCount: (r['public_match_count'] as num?)?.toInt() ?? 0,
      winRate: (r['public_win_rate'] as num?)?.toInt() ?? 0,
      badges: ((r['public_badges'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      preferredTime: (r['preferred_time'] as String?) ?? '',
      mutualFriendsCount: (r['mutual_friends_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SocialPrivacySettings {
  const SocialPrivacySettings({
    required this.socialEnabled,
    required this.mapVisibility,
    required this.showOnlineStatus,
    required this.showClub,
    required this.showActivity,
    required this.publicStatsEnabled,
  });

  final bool socialEnabled;
  final String mapVisibility; // PUBLIC | FRIENDS | HIDDEN
  final bool showOnlineStatus;
  final bool showClub;
  final bool showActivity;
  final bool publicStatsEnabled;

  SocialPrivacySettings copyWith({
    bool? socialEnabled,
    String? mapVisibility,
    bool? showOnlineStatus,
    bool? showClub,
    bool? showActivity,
    bool? publicStatsEnabled,
  }) => SocialPrivacySettings(
    socialEnabled: socialEnabled ?? this.socialEnabled,
    mapVisibility: mapVisibility ?? this.mapVisibility,
    showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    showClub: showClub ?? this.showClub,
    showActivity: showActivity ?? this.showActivity,
    publicStatsEnabled: publicStatsEnabled ?? this.publicStatsEnabled,
  );

  factory SocialPrivacySettings.fromRow(Map<String, dynamic> row) =>
      SocialPrivacySettings(
        socialEnabled: row['social_enabled'] as bool? ?? false,
        mapVisibility: row['map_visibility'] as String? ?? 'HIDDEN',
        showOnlineStatus: row['show_online_status'] as bool? ?? false,
        showClub: row['show_club'] as bool? ?? false,
        showActivity: row['show_activity'] as bool? ?? false,
        publicStatsEnabled: row['public_stats_enabled'] as bool? ?? false,
      );
}

/// Richiesta in arrivo (contatto, proposta partita, team join, invito team).
class SocialInboxItem {
  const SocialInboxItem({
    required this.id,
    required this.kind,
    required this.fromUserId,
    required this.fromName,
    required this.message,
    required this.createdAt,
    this.meta = const {},
  });

  final String id;

  /// 'contact' | 'proposal' | 'team' | 'team_invite'
  final String kind;
  final String fromUserId;
  final String fromName;
  final String message;
  final DateTime? createdAt;
  final Map<String, dynamic> meta;

  String? get teamId => meta['teamId']?.toString() ?? meta['targetTeamId']?.toString();
  String? get teamName => meta['teamName']?.toString();
  String? get linkedMatchId => meta['linkedMatchId']?.toString();
}

class SocialRespondResult {
  const SocialRespondResult({
    this.error,
    this.status,
    this.linkedMatchId,
    this.teamId,
    this.creatorName,
    this.proposalId,
  });

  final String? error;
  final String? status;
  final String? linkedMatchId;
  final String? teamId;
  final String? creatorName;
  final String? proposalId;

  bool get ok => error == null;
}

class SocialService {
  SocialService(this.ref);
  final Ref ref;

  static bool get available => _client != null;

  String? get _uid => _client?.auth.currentUser?.id;

  Future<({SocialPrivacySettings? settings, String? error})>
  privacySettings() async {
    final c = _client;
    final uid = _uid;
    if (c == null || uid == null) {
      return (settings: null, error: 'Accedi prima al tuo account.');
    }
    try {
      final row = await c
          .from('profiles')
          .select(
            'social_enabled,map_visibility,show_online_status,show_club,'
            'show_activity,public_stats_enabled',
          )
          .eq('user_id', uid)
          .single()
          .timeout(_netTimeout);
      return (settings: SocialPrivacySettings.fromRow(row), error: null);
    } on TimeoutException {
      return (settings: null, error: _timeoutMessage);
    } on PostgrestException catch (error) {
      return (settings: null, error: error.message);
    } on Exception {
      return (settings: null, error: 'Preferenze social non disponibili.');
    }
  }

  Future<String?> updatePrivacySettings(SocialPrivacySettings settings) async {
    final c = _client;
    final uid = _uid;
    if (c == null || uid == null) return 'Accedi prima al tuo account.';
    if (!const {
      'PUBLIC',
      'FRIENDS',
      'HIDDEN',
    }.contains(settings.mapVisibility)) {
      return 'Visibilità non valida.';
    }
    try {
      await c
          .from('profiles')
          .update({
            'social_enabled': settings.socialEnabled,
            'map_visibility': settings.mapVisibility,
            'show_online_status': settings.showOnlineStatus,
            'show_club': settings.showClub,
            'show_activity': settings.showActivity,
            'public_stats_enabled': settings.publicStatsEnabled,
          })
          .eq('user_id', uid)
          .timeout(_netTimeout);
      return null;
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (error) {
      return error.message;
    } on Exception {
      return 'Aggiornamento privacy non riuscito.';
    }
  }

  Future<void> markActive() async {
    final c = _client;
    final uid = _uid;
    if (c == null || uid == null) return;
    try {
      await c
          .from('profiles')
          .update({'last_active_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .timeout(_netTimeout);
    } on Exception {
      // Presence is best-effort and must never affect app startup or scoring.
    }
  }

  /// Giocatori visibili sul social (esclusi me e i profili nascosti).
  /// Ritorna lista + eventuale errore leggibile.
  Future<({List<SocialPlayer> players, String? error})> discover() async {
    final c = _client;
    if (c == null) {
      return (
        players: const <SocialPlayer>[],
        error: 'Servizi online non disponibili.',
      );
    }
    try {
      final response = await c
          .rpc('discover_social_players', params: {'p_limit': 50})
          .timeout(_netTimeout);
      final rows = ((response as List?) ?? const []).map(
        (row) => (row as Map).cast<String, dynamic>(),
      );
      final me = _uid;
      final rawPlayers = rows
          .map(SocialPlayer.fromRow)
          .whereType<SocialPlayer>()
          .where((p) => p.userId != me)
          .toList();
      final signed = await ref
          .read(profileImageServiceProvider)
          .signedUrls(rawPlayers.map((player) => player.avatarUrl));
      final players = rawPlayers
          .map(
            (player) => player.avatarUrl?.startsWith('http') == true
                ? player
                : player.withAvatarUrl(signed[player.avatarUrl]),
          )
          .toList(growable: false);
      return (players: players, error: null);
    } on TimeoutException {
      return (players: const <SocialPlayer>[], error: _timeoutMessage);
    } on PostgrestException catch (e) {
      return (players: const <SocialPlayer>[], error: e.message);
    } catch (_) {
      return (
        players: const <SocialPlayer>[],
        error: 'Ricerca giocatori non riuscita.',
      );
    }
  }

  Future<({SocialPlayer? player, String? error})> profile(String userId) async {
    final c = _client;
    if (c == null || _uid == null) {
      return (player: null, error: 'Accedi prima al tuo account.');
    }
    try {
      final response = await c
          .rpc('social_player_profile', params: {'p_user_id': userId})
          .timeout(_netTimeout);
      if (response is! Map || response['ok'] != true) {
        return (player: null, error: 'Profilo non disponibile.');
      }
      final player = SocialPlayer.fromRow(response.cast<String, dynamic>());
      if (player == null || player.avatarUrl?.startsWith('http') == true) {
        return (player: player, error: null);
      }
      final url = await ref
          .read(profileImageServiceProvider)
          .signedUrl(player.avatarUrl);
      return (player: player.withAvatarUrl(url), error: null);
    } on TimeoutException {
      return (player: null, error: _timeoutMessage);
    } on Exception {
      return (player: null, error: 'Profilo non disponibile.');
    }
  }

  /// Attiva/disattiva la presenza sul social e aggiorna preferenze
  /// matchmaking (disponibilità, stili, skill score calcolato in locale).
  Future<String?> updateVisibility({
    required bool enabled,
    required String availability,
    required List<String> styleTags,
    required int skillScore,
  }) async {
    final c = _client;
    final uid = _uid;
    if (c == null) return 'Servizi online non disponibili.';
    if (uid == null) return 'Accedi prima al tuo account';
    try {
      final current = await c
          .from('profiles')
          .select('map_visibility')
          .eq('user_id', uid)
          .single()
          .timeout(_netTimeout);
      final stored = current['map_visibility'] as String? ?? 'HIDDEN';
      final mapVisibility = enabled && stored == 'HIDDEN' ? 'PUBLIC' : stored;
      await c
          .from('profiles')
          .update({
            'social_enabled': enabled,
            'map_visibility': mapVisibility,
            'availability': availability,
            'style_tags': styleTags,
            'skill_score': skillScore.clamp(0, 100),
          })
          .eq('user_id', uid)
          .timeout(_netTimeout);
      return null;
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Aggiornamento visibilità non riuscito.';
    }
  }

  Future<String?> sendContactRequest(
    String receiverId, {
    String message = '',
  }) async {
    final c = _client;
    if (c == null || _uid == null) return 'Accedi prima al tuo account';
    try {
      final response = await c
          .rpc(
            'send_friend_request',
            params: {'p_receiver_id': receiverId, 'p_message': message},
          )
          .timeout(_netTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      if (payload['ok'] == true) return null;
      return _socialError(payload['error']?.toString());
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (error) {
      return error.message;
    } on Exception {
      return 'Invio richiesta non riuscito.';
    }
  }

  Future<String?> proposeMatch(
    String receiverId, {
    String message = '',
    String levelHint = '',
  }) => _guardedSocialRpc('send_match_proposal', {
    'p_receiver_id': receiverId,
    'p_message': message,
    'p_level_hint': levelHint,
  });

  /// Invite [targetUserId] into **my** cloud team (owner only).
  ///
  /// Uses the stable `create_invite` RPC (always present) so invites work
  /// without requiring a newer `invite_user_to_my_team` migration on the
  /// remote project. A targeted TEAM_JOIN invite still triggers push when the
  /// backend invite push trigger is deployed.
  Future<String?> inviteToMyTeam({
    required String teamId,
    required String targetUserId,
    String message = '',
  }) async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    if (_uid == null) return 'Accedi prima al tuo account';
    try {
      final response = await c
          .rpc(
            'create_invite',
            params: {
              'p_kind': 'TEAM_JOIN',
              'p_team_id': teamId,
              'p_target_user_id': targetUserId,
              // A targeted team invite must survive in the recipient's inbox
              // until they accept it, not expire after two days.
              'p_ttl_minutes': InviteService.defaultTtlMinutes('TEAM_JOIN'),
            },
          )
          .timeout(_netTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      if (payload['ok'] == true) return null;
      return _socialError(payload['error']?.toString());
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Invito non inviato. Riprova.';
    }
  }

  /// Legacy: request to join another owner's team (kept for reverse flow).
  Future<String?> requestTeamJoin(String ownerId, {String message = ''}) =>
      _guardedSocialRpc('send_team_join_request', {
        'p_owner_id': ownerId,
        'p_message': message,
      });

  Future<String?> _guardedSocialRpc(
    String function,
    Map<String, Object?> values,
  ) async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    if (_uid == null) return 'Accedi prima al tuo account';
    try {
      final response = await c
          .rpc(function, params: values)
          .timeout(_netTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      return payload['ok'] == true
          ? null
          : _socialError(payload['error']?.toString());
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Invio non riuscito. Riprova.';
    }
  }

  /// Richieste ricevute in attesa di risposta.
  Future<({List<SocialInboxItem> items, String? error})> inbox() async {
    final c = _client;
    final uid = _uid;
    if (c == null || uid == null) {
      return (items: const <SocialInboxItem>[], error: null);
    }
    try {
      final response = await c.rpc('social_inbox').timeout(_netTimeout);
      final rows = ((response as List?) ?? const []).map(
        (row) => (row as Map).cast<String, dynamic>(),
      );
      final items =
          <SocialInboxItem>[
            for (final row in rows)
              SocialInboxItem(
                id: row['item_id'] as String,
                kind: row['kind'] as String,
                fromUserId: row['from_user_id'] as String,
                fromName: (row['from_name'] as String?) ?? 'Giocatore',
                message: (row['message'] as String?) ?? '',
                createdAt: DateTime.tryParse(
                  (row['created_at'] as String?) ?? '',
                ),
                meta: (row['meta'] as Map?)?.cast<String, dynamic>() ??
                    const {},
              ),
          ]..sort(
            (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
              a.createdAt ?? DateTime(2000),
            ),
          );
      return (items: items, error: null);
    } on TimeoutException {
      return (items: const <SocialInboxItem>[], error: _timeoutMessage);
    } on PostgrestException catch (e) {
      return (items: const <SocialInboxItem>[], error: e.message);
    } catch (_) {
      return (
        items: const <SocialInboxItem>[],
        error: 'Caricamento richieste non riuscito.',
      );
    }
  }

  /// Accetta o rifiuta una richiesta dell'inbox (con payload strutturato).
  Future<SocialRespondResult> respond(
    SocialInboxItem item, {
    required bool accept,
  }) async {
    final c = _client;
    if (c == null || _uid == null) {
      return const SocialRespondResult(error: 'Accedi prima al tuo account');
    }
    if (item.kind == 'contact') {
      try {
        final response = await c
            .rpc(
              'respond_friend_request',
              params: {'p_request_id': item.id, 'p_accept': accept},
            )
            .timeout(_netTimeout);
        final payload = (response as Map).cast<String, dynamic>();
        if (payload['ok'] == true) {
          return SocialRespondResult(status: accept ? 'ACCEPTED' : 'DECLINED');
        }
        return SocialRespondResult(
          error: _socialError(payload['error']?.toString()),
        );
      } on TimeoutException {
        return const SocialRespondResult(error: _timeoutMessage);
      } on PostgrestException catch (error) {
        return SocialRespondResult(error: error.message);
      }
    }
    try {
      final response = await c
          .rpc(
            'respond_social_item',
            params: {
              'p_kind': item.kind,
              'p_item_id': item.id,
              'p_accept': accept,
            },
          )
          .timeout(_netTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      if (payload['ok'] != true) {
        return SocialRespondResult(
          error: _socialError(payload['error']?.toString()),
        );
      }
      return SocialRespondResult(
        status: payload['status']?.toString(),
        linkedMatchId: payload['linkedMatchId']?.toString(),
        teamId: payload['teamId']?.toString(),
        creatorName: payload['creatorName']?.toString(),
        proposalId: payload['proposalId']?.toString() ?? item.id,
      );
    } on TimeoutException {
      return const SocialRespondResult(error: _timeoutMessage);
    } on PostgrestException catch (e) {
      return SocialRespondResult(error: e.message);
    } catch (_) {
      return const SocialRespondResult(error: 'Risposta non inviata. Riprova.');
    }
  }
}

String _socialError(String? code) => switch (code) {
  'rate_limited' => 'Hai inviato troppe richieste. Riprova più tardi.',
  'already_member' => 'Il giocatore è già nel team.',
  'team_not_owned' => 'Puoi invitare solo nei team di cui sei proprietario.',
  'team_not_found' => 'Crea o sincronizza un team cloud prima di invitare.',
  'invite_not_available' => 'Invito scaduto o non più disponibile.',
  'not_available' => 'Questo profilo non accetta richieste al momento.',
  'auth_required' => 'Accedi prima al tuo account.',
  'invalid_receiver' => 'Destinatario non valido.',
  'message_too_long' => 'Il messaggio è troppo lungo.',
  'request_not_available' => 'La richiesta non è più disponibile.',
  _ => 'Operazione non riuscita. Riprova.',
};

final socialServiceProvider = Provider((ref) => SocialService(ref));
