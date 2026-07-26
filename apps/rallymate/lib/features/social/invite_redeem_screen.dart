library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/invite_service.dart';
import '../../services/cloud/team_cloud_service.dart';

final invitePreviewProvider = FutureProvider.autoDispose
    .family<({InvitePreview? preview, String? error}), String>(
      (ref, secret) => ref.read(inviteServiceProvider).preview(secret),
    );

class InviteRedeemScreen extends ConsumerStatefulWidget {
  const InviteRedeemScreen({super.key, required this.secret});

  final String secret;

  @override
  ConsumerState<InviteRedeemScreen> createState() => _InviteRedeemScreenState();
}

class _InviteRedeemScreenState extends ConsumerState<InviteRedeemScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(cloudAuthProvider);
    if (!auth.profileLinked) {
      final returnTo = '/invite/${Uri.encodeComponent(widget.secret)}';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invito Padelandia'),
          leading: const SafeBackButton(fallback: AppLocations.home),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyStateCard(
              icon: Icons.mark_email_unread_outlined,
              title: auth.signedIn
                  ? 'Collega il profilo per vedere l’invito'
                  : 'Accedi per vedere l’invito',
              message:
                  'Prima di accettare vedrai chi invita e a quale attività. '
                  'Nessuna relazione viene creata automaticamente.',
              primaryLabel: auth.signedIn ? 'Collega profilo' : 'Accedi',
              primaryIcon: auth.signedIn ? Icons.link : Icons.login,
              onPrimary: () => context.go(
                Uri(
                  path: '/auth',
                  queryParameters: {'returnTo': returnTo},
                ).toString(),
              ),
            ),
          ],
        ),
      );
    }

    final preview = ref.watch(invitePreviewProvider(widget.secret));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invito Padelandia'),
        leading: const SafeBackButton(fallback: AppLocations.home),
      ),
      body: preview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (result) {
          final item = result.preview;
          if (item == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyStateCard(
                  icon: Icons.link_off,
                  title: 'Invito non disponibile',
                  message: result.error ?? 'Il link non è valido.',
                  primaryLabel: 'Torna agli amici',
                  primaryIcon: Icons.people_outline,
                  onPrimary: () => context.go('/friends'),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              SectionCard(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RallyColors.lime.withValues(alpha: 0.13),
                      ),
                      child:
                          item.kind == 'PROFILE' &&
                              item.profileAvatarUrl?.isNotEmpty == true
                          ? ClipOval(
                              child: Image.network(
                                item.profileAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_outline,
                                  size: 38,
                                  color: RallyColors.lime,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.sports_tennis,
                              size: 38,
                              color: RallyColors.lime,
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.kind == 'PROFILE'
                          ? item.profileName
                          : item.inviterName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description(item),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (item.teamName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Chip(
                        avatar: const Icon(Icons.groups_outlined, size: 17),
                        label: Text(item.teamName),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: RallyColors.lime),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Accettando colleghi solo i dati necessari a questa '
                        'azione. Puoi rimuovere amicizia, team o bloccare '
                        'l’utente in qualsiasi momento.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : () => _accept(item),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_cta(item.kind)),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.go('/home'),
                child: const Text('Non ora'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _accept(InvitePreview preview) async {
    setState(() => _busy = true);
    final result = await ref.read(inviteServiceProvider).redeem(widget.secret);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.error != null) {
      if (result.error!.toLowerCase().contains('premium')) {
        context.push('/paywall');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final payload = result.payload!;
    if (preview.kind == 'PROFILE') {
      final profileId =
          payload['profileUserId'] as String? ?? preview.profileUserId;
      if (profileId != null) {
        context.go(
          Uri(
            path: '/social',
            queryParameters: {'player': profileId},
          ).toString(),
        );
        return;
      }
    }
    if (preview.kind == 'MATCH') {
      context.go(
        Uri(
          path: '/match/new',
          queryParameters: {'opponentName': preview.inviterName},
        ).toString(),
      );
      return;
    }
    if (preview.kind == 'DUO') {
      final matchId = payload['matchId'] as String?;
      final sessionId = payload['duoSessionId'] as String?;
      final formatRaw = payload['format'];
      final teamRaw = payload['myTeam'] as String?;
      if (matchId != null &&
          sessionId != null &&
          formatRaw is Map &&
          teamRaw != null) {
        final format = MatchFormat.fromJson(
          jsonDecode(jsonEncode(formatRaw)) as Map<String, Object?>,
        );
        final team = TeamId.fromWire(teamRaw);
        await ref
            .read(matchRepoProvider)
            .create(
              matchId: matchId,
              format: format,
              duoMode: true,
              duoTeam: team,
            );
        await ref
            .read(matchRepoProvider)
            .linkDuoSession(
              matchId,
              sessionId: sessionId,
              ownerUserId: ref.read(cloudAuthProvider).userId!,
              duoTeam: team,
              cloudStatus: 'ACTIVE',
            );
        if (mounted) context.go('/match/$matchId/duo');
        return;
      }
    }
    if (!mounted) return;
    if (preview.kind == 'TEAM_JOIN' || preview.kind == 'TEAM_LINK') {
      await ref.read(teamCloudServiceProvider).syncMemberships();
      if (!mounted) return;
    }
    final destination = preview.kind == 'FRIEND' ? '/friends' : '/teams';
    context.go(destination);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invito accettato.')));
  }

  String _description(InvitePreview item) => switch (item.kind) {
    'PROFILE' => '${item.inviterName} ti ha condiviso questo profilo',
    'TEAM_JOIN' => 'ti invita a entrare nel team',
    'TEAM_LINK' => 'propone di collegare i vostri team',
    'MATCH' => 'ti invita a una partita',
    'DUO' => 'ti invita nella stessa partita in Duo Mode',
    _ => 'vuole aggiungerti agli amici Padelandia',
  };

  String _cta(String kind) => switch (kind) {
    'PROFILE' => 'Apri profilo',
    'TEAM_JOIN' => 'Entra nel team',
    'TEAM_LINK' => 'Collega team',
    'MATCH' => 'Accetta partita',
    'DUO' => 'Entra in Duo Mode',
    _ => 'Accetta amicizia',
  };
}
