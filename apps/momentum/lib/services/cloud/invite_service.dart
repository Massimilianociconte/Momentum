library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_service.dart';

const _inviteTimeout = Duration(seconds: 12);
const _publicLinkBase = String.fromEnvironment('RALLYMATE_LINK_BASE_URL');

class CreatedInvite {
  const CreatedInvite({
    required this.id,
    required this.kind,
    required this.token,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String kind;
  final String token;
  final String code;
  final DateTime expiresAt;

  Uri get uri {
    final configured = Uri.tryParse(_publicLinkBase);
    if (configured != null &&
        configured.hasScheme &&
        configured.scheme == 'https' &&
        configured.host.isNotEmpty) {
      return configured.replace(path: '/invite/$token', query: null);
    }
    return Uri(scheme: 'rallymate', host: 'invite', path: token);
  }

  bool get hasPublicFallback => uri.scheme == 'https';
}

class ActiveInvite {
  const ActiveInvite({
    required this.id,
    required this.kind,
    required this.hint,
    required this.expiresAt,
    required this.useCount,
    required this.maxUses,
  });

  final String id;
  final String kind;
  final String hint;
  final DateTime expiresAt;
  final int useCount;
  final int maxUses;
}

class InvitePreview {
  const InvitePreview({
    required this.id,
    required this.kind,
    required this.inviterId,
    required this.inviterName,
    required this.expiresAt,
    this.teamId,
    this.teamName = '',
    this.matchId,
    this.duoSessionId,
    this.profileUserId,
    this.profileName = '',
    this.profileAvatarUrl,
    this.profileLevel = '',
  });

  final String id;
  final String kind;
  final String inviterId;
  final String inviterName;
  final DateTime expiresAt;
  final String? teamId;
  final String teamName;
  final String? matchId;
  final String? duoSessionId;
  final String? profileUserId;
  final String profileName;
  final String? profileAvatarUrl;
  final String profileLevel;
}

class InviteService {
  const InviteService();

  SupabaseClient? get _client => cloudClient;

  /// Default lifetime per invite kind.
  ///
  /// A friend or team invite must stay valid until the other person accepts
  /// it, so it uses the longest TTL the backend allows (7 days). Live pairing
  /// invites are deliberately short: a DUO code is useless once the session
  /// code itself expires after two hours.
  static int defaultTtlMinutes(String kind) => switch (kind) {
    'DUO' => 120,
    'MATCH' => 1440,
    // FRIEND, PROFILE, TEAM_JOIN, TEAM_LINK: persist until accepted.
    _ => 10080,
  };

  Future<({CreatedInvite? invite, String? error})> create({
    required String kind,
    String? teamId,
    String? targetTeamId,
    String? matchId,
    String? duoSessionId,
    String? targetUserId,
    int? ttlMinutes,
  }) async {
    final ttl = ttlMinutes ?? defaultTtlMinutes(kind);
    final client = _client;
    if (client?.auth.currentUser == null) {
      return (invite: null, error: 'Accedi prima al tuo account.');
    }
    try {
      final response = await client!
          .rpc(
            'create_invite',
            params: {
              'p_kind': kind,
              'p_team_id': teamId,
              'p_target_team_id': targetTeamId,
              'p_match_id': matchId,
              'p_duo_session_id': duoSessionId,
              'p_ttl_minutes': ttl,
              'p_target_user_id': targetUserId,
            },
          )
          .timeout(_inviteTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      if (payload['ok'] != true) {
        return (invite: null, error: _error(payload['error']?.toString()));
      }
      return (
        invite: CreatedInvite(
          id: payload['inviteId'] as String,
          kind: payload['kind'] as String,
          token: payload['token'] as String,
          code: payload['code'] as String,
          expiresAt: DateTime.parse(payload['expiresAt'] as String),
        ),
        error: null,
      );
    } on TimeoutException {
      return (invite: null, error: 'Rete lenta o assente. Riprova.');
    } on PostgrestException catch (error) {
      return (invite: null, error: error.message);
    } on Exception {
      return (invite: null, error: 'Creazione invito non riuscita.');
    }
  }

  Future<({InvitePreview? preview, String? error})> preview(
    String secret,
  ) async {
    final result = await _payload('preview_invite', secret);
    final payload = result.payload;
    if (payload == null) return (preview: null, error: result.error);
    return (
      preview: InvitePreview(
        id: payload['inviteId'] as String,
        kind: payload['kind'] as String,
        inviterId: payload['inviterId'] as String,
        inviterName: payload['inviterName'] as String,
        expiresAt: DateTime.parse(payload['expiresAt'] as String),
        teamId: payload['teamId'] as String?,
        teamName: (payload['teamName'] as String?) ?? '',
        matchId: payload['matchId'] as String?,
        duoSessionId: payload['duoSessionId'] as String?,
        profileUserId: payload['profileUserId'] as String?,
        profileName: (payload['profileName'] as String?) ?? '',
        profileAvatarUrl: payload['profileAvatarUrl'] as String?,
        profileLevel: (payload['profileLevel'] as String?) ?? '',
      ),
      error: null,
    );
  }

  Future<({Map<String, dynamic>? payload, String? error})> redeem(
    String secret,
  ) => _payload('redeem_invite', secret);

  Future<String?> revoke(String inviteId) async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return 'Accedi prima al tuo account.';
    }
    try {
      final revoked = await client!
          .rpc('revoke_invite', params: {'p_invite_id': inviteId})
          .timeout(_inviteTimeout);
      return revoked == true ? null : 'Invito già chiuso o non disponibile.';
    } on TimeoutException {
      return 'Rete lenta o assente. Riprova.';
    } on Exception {
      return 'Revoca invito non riuscita.';
    }
  }

  Future<({List<ActiveInvite> items, String? error})> active() async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return (items: const <ActiveInvite>[], error: null);
    }
    try {
      final rows = await client!
          .from('invite_tokens')
          .select(
            'invite_id, kind, token_hint, expires_at, use_count, max_uses',
          )
          .isFilter('revoked_at', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .timeout(_inviteTimeout);
      return (
        items: [
          for (final row in rows)
            ActiveInvite(
              id: row['invite_id'] as String,
              kind: row['kind'] as String,
              hint: (row['token_hint'] as String?) ?? '',
              expiresAt: DateTime.parse(row['expires_at'] as String),
              useCount: (row['use_count'] as num?)?.toInt() ?? 0,
              maxUses: (row['max_uses'] as num?)?.toInt() ?? 1,
            ),
        ],
        error: null,
      );
    } on TimeoutException {
      return (
        items: const <ActiveInvite>[],
        error: 'Rete lenta o assente. Riprova.',
      );
    } on Exception {
      return (
        items: const <ActiveInvite>[],
        error: 'Inviti attivi non disponibili.',
      );
    }
  }

  Future<({Map<String, dynamic>? payload, String? error})> _payload(
    String function,
    String secret,
  ) async {
    final client = _client;
    if (client?.auth.currentUser == null) {
      return (payload: null, error: 'Accedi prima al tuo account.');
    }
    try {
      final response = await client!
          .rpc(function, params: {'p_secret': secret.trim()})
          .timeout(_inviteTimeout);
      final payload = (response as Map).cast<String, dynamic>();
      if (payload['ok'] != true) {
        return (payload: null, error: _error(payload['error']?.toString()));
      }
      return (payload: payload, error: null);
    } on TimeoutException {
      return (payload: null, error: 'Rete lenta o assente. Riprova.');
    } on PostgrestException catch (error) {
      return (payload: null, error: error.message);
    } on Exception {
      return (payload: null, error: 'Invito non disponibile.');
    }
  }

  Future<void> share(CreatedInvite invite, {String? subject}) async {
    final text =
        'Unisciti a me su Momentum\n${invite.uri}\n'
        'Codice: ${invite.code}';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject ?? 'Invito Momentum'),
    );
  }

  String _error(String? code) => switch (code) {
    'rate_limited' => 'Troppi tentativi. Attendi qualche minuto.',
    'invite_not_available' => 'Invito scaduto, revocato o già utilizzato.',
    'team_not_owned' => 'Puoi invitare solo nei team che gestisci.',
    'duo_not_available' => 'La sessione Duo non è più disponibile.',
    'profile_not_available' => 'Il profilo non è più condivisibile.',
    _ => 'Invito non disponibile.',
  };
}

final inviteServiceProvider = Provider((_) => const InviteService());
