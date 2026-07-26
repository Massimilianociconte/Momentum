library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_service.dart';
import '../profile_image_service.dart';

const _friendsTimeout = Duration(seconds: 12);

class FriendConnection {
  const FriendConnection({
    required this.requestId,
    required this.userId,
    required this.direction,
    required this.status,
    required this.name,
    required this.nickname,
    required this.level,
    required this.availability,
    required this.homeArea,
    required this.club,
    required this.showOnlineStatus,
    required this.showActivity,
    this.avatarUrl,
    this.lastActiveAt,
  });

  final String requestId;
  final String userId;
  final String direction;
  final String status;
  final String name;
  final String nickname;
  final String? avatarUrl;
  final String level;
  final String availability;
  final String homeArea;
  final String club;
  final bool showOnlineStatus;
  final bool showActivity;
  final DateTime? lastActiveAt;

  String get displayName => nickname.isNotEmpty ? nickname : name;

  FriendConnection withAvatarUrl(String? value) => FriendConnection(
    requestId: requestId,
    userId: userId,
    direction: direction,
    status: status,
    name: name,
    nickname: nickname,
    level: level,
    availability: availability,
    homeArea: homeArea,
    club: club,
    showOnlineStatus: showOnlineStatus,
    showActivity: showActivity,
    avatarUrl: value,
    lastActiveAt: lastActiveAt,
  );

  factory FriendConnection.fromRow(Map<String, dynamic> row) =>
      FriendConnection(
        requestId: row['request_id'] as String,
        userId: row['other_user_id'] as String,
        direction: row['direction'] as String,
        status: row['status'] as String,
        name: (row['name'] as String?) ?? 'Giocatore',
        nickname: (row['nickname'] as String?) ?? '',
        avatarUrl: row['avatar_url'] as String?,
        level: (row['level'] as String?) ?? 'INTERMEDIATE',
        availability: (row['availability'] as String?) ?? 'FLEX',
        homeArea: (row['home_area'] as String?) ?? '',
        club: (row['club'] as String?) ?? '',
        showOnlineStatus: row['show_online_status'] as bool? ?? false,
        showActivity: row['show_activity'] as bool? ?? false,
        lastActiveAt: DateTime.tryParse(
          (row['last_active_at'] as String?) ?? '',
        ),
      );
}

class BlockedProfile {
  const BlockedProfile({
    required this.userId,
    required this.name,
    required this.nickname,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String nickname;
  final String? avatarUrl;

  String get displayName => nickname.isNotEmpty ? nickname : name;
}

class FriendsService {
  const FriendsService(this.ref);

  final Ref ref;

  SupabaseClient? get _client => cloudClient;

  Future<({List<FriendConnection> items, String? error})>
  relationships() async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return (items: const <FriendConnection>[], error: null);
    }
    try {
      final response = await client!
          .rpc('social_relationships')
          .timeout(_friendsTimeout);
      final rawItems = ((response as List?) ?? const [])
          .map(
            (row) =>
                FriendConnection.fromRow((row as Map).cast<String, dynamic>()),
          )
          .toList(growable: false);
      final signed = await ref
          .read(profileImageServiceProvider)
          .signedUrls(rawItems.map((item) => item.avatarUrl));
      final items = rawItems
          .map(
            (item) => item.avatarUrl?.startsWith('http') == true
                ? item
                : item.withAvatarUrl(signed[item.avatarUrl]),
          )
          .toList(growable: false);
      return (items: items, error: null);
    } on TimeoutException {
      return (
        items: const <FriendConnection>[],
        error: 'Rete lenta o assente. Riprova.',
      );
    } on PostgrestException catch (error) {
      return (items: const <FriendConnection>[], error: error.message);
    } on Exception {
      return (
        items: const <FriendConnection>[],
        error: 'Caricamento amicizie non riuscito.',
      );
    }
  }

  Future<({List<BlockedProfile> items, String? error})> blocked() async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return (items: const <BlockedProfile>[], error: null);
    }
    try {
      final response = await client!
          .rpc('blocked_users')
          .timeout(_friendsTimeout);
      final rawItems = ((response as List?) ?? const [])
          .map((raw) {
            final row = (raw as Map).cast<String, dynamic>();
            return BlockedProfile(
              userId: row['user_id'] as String,
              name: (row['name'] as String?) ?? 'Giocatore',
              nickname: (row['nickname'] as String?) ?? '',
              avatarUrl: row['avatar_url'] as String?,
            );
          })
          .toList(growable: false);
      final signed = await ref
          .read(profileImageServiceProvider)
          .signedUrls(rawItems.map((item) => item.avatarUrl));
      final items = rawItems
          .map(
            (item) => BlockedProfile(
              userId: item.userId,
              name: item.name,
              nickname: item.nickname,
              avatarUrl: item.avatarUrl?.startsWith('http') == true
                  ? item.avatarUrl
                  : signed[item.avatarUrl],
            ),
          )
          .toList(growable: false);
      return (items: items, error: null);
    } on PostgrestException catch (error) {
      return (items: const <BlockedProfile>[], error: error.message);
    } on Exception {
      return (
        items: const <BlockedProfile>[],
        error: 'Elenco blocchi non disponibile.',
      );
    }
  }

  Future<String?> respond(String requestId, {required bool accept}) => _rpc(
    'respond_friend_request',
    {'p_request_id': requestId, 'p_accept': accept},
  );

  Future<String?> cancel(String requestId) =>
      _rpc('cancel_friend_request', {'p_request_id': requestId});

  Future<String?> removeFriend(String userId) =>
      _rpc('remove_friend', {'p_other_id': userId});

  Future<String?> block(String userId) =>
      _rpc('block_user', {'p_other_id': userId});

  Future<String?> unblock(String userId) =>
      _rpc('unblock_user', {'p_other_id': userId});

  Future<String?> report(
    String userId, {
    required String category,
    String details = '',
  }) => _rpc('report_social_user', {
    'p_user_id': userId,
    'p_category': category,
    'p_details': details,
  });

  Future<String?> _rpc(String function, Map<String, Object?> params) async {
    final client = _client;
    if (client?.auth.currentUser == null) return 'Accedi prima al tuo account.';
    try {
      final response = await client!
          .rpc(function, params: params)
          .timeout(_friendsTimeout);
      if (response is bool) {
        return response ? null : 'Operazione non disponibile.';
      }
      if (response is Map) {
        final payload = response.cast<String, dynamic>();
        if (payload['ok'] == true) return null;
        return _message(payload['error']?.toString());
      }
      return null;
    } on TimeoutException {
      return 'Rete lenta o assente. Riprova.';
    } on PostgrestException catch (error) {
      return error.message;
    } on Exception {
      return 'Operazione non riuscita.';
    }
  }

  String _message(String? error) => switch (error) {
    'rate_limited' => 'Limite temporaneo raggiunto. Riprova più tardi.',
    'request_not_available' => 'La richiesta non è più disponibile.',
    'invalid_report' => 'Controlla motivo e dettagli della segnalazione.',
    _ => 'Operazione non riuscita.',
  };
}

final friendsServiceProvider = Provider(FriendsService.new);
