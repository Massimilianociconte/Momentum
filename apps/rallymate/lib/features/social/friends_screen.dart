library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation_targets.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/friends_service.dart';
import '../../services/cloud/social_service.dart';
import '../../services/cloud/invite_service.dart';
import 'invite_share_sheet.dart';

final friendRelationshipsProvider = FutureProvider.autoDispose(
  (ref) => ref.read(friendsServiceProvider).relationships(),
);

final blockedProfilesProvider = FutureProvider.autoDispose(
  (ref) => ref.read(friendsServiceProvider).blocked(),
);

final friendSuggestionsProvider = FutureProvider.autoDispose((ref) async {
  final discovery = await ref.read(socialServiceProvider).discover();
  if (discovery.error != null) return discovery;
  final relationships = await ref.read(friendsServiceProvider).relationships();
  final existing = relationships.items
      .where((item) => item.status == 'ACCEPTED' || item.status == 'PENDING')
      .map((item) => item.userId)
      .toSet();
  return (
    players: discovery.players
        .where((player) => !existing.contains(player.userId))
        .toList(growable: false),
    error: relationships.error,
  );
});

final activeInvitesProvider = FutureProvider.autoDispose(
  (ref) => ref.read(inviteServiceProvider).active(),
);

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key, this.initialTab});

  /// Deep-link tab: friends | requests | suggested | invites | blocked
  final String? initialTab;

  static int _tabIndex(String? tab) => switch (tab) {
        'requests' => 1,
        'suggested' || 'suggestions' => 2,
        'invites' || 'links' => 3,
        'blocked' => 4,
        _ => 0,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(cloudAuthProvider);
    if (!auth.profileLinked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Amici'),
          leading: const SafeBackButton(fallback: AppLocations.profile),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyStateCard(
              icon: Icons.people_outline,
              title: auth.signedIn
                  ? 'Collega il profilo locale'
                  : 'Accedi per collegarti ai giocatori',
              message:
                  'L’account gratuito salva richieste e relazioni essenziali. '
                  'Le partite restano locali salvo backup Premium.',
              primaryLabel: auth.signedIn ? 'Collega profilo' : 'Accedi',
              primaryIcon: auth.signedIn ? Icons.link : Icons.login,
              onPrimary: () => context.push(
                '/auth?returnTo=${Uri.encodeQueryComponent('/friends')}',
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      initialIndex: _tabIndex(initialTab),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amici'),
          leading: const SafeBackButton(fallback: AppLocations.profile),
          actions: [
            IconButton(
              onPressed: () => context.push('/groups'),
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Gruppi e classifiche private',
            ),
            IconButton(
              onPressed: () =>
                  showInviteShareSheet(context, ref, kind: 'FRIEND'),
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Il mio invito',
            ),
            IconButton(
              onPressed: () => context.push('/invite/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona invito',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Amici'),
              Tab(text: 'Richieste'),
              Tab(text: 'Suggeriti'),
              Tab(text: 'Link attivi'),
              Tab(text: 'Bloccati'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ConnectionsTab(mode: 'friends'),
            _ConnectionsTab(mode: 'requests'),
            _SuggestionsTab(),
            _ActiveInvitesTab(),
            _BlockedTab(),
          ],
        ),
      ),
    );
  }
}

class _ActiveInvitesTab extends ConsumerWidget {
  const _ActiveInvitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(activeInvitesProvider);
    return invites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _RetryState(
        message: '$error',
        onRetry: () => ref.invalidate(activeInvitesProvider),
      ),
      data: (result) {
        if (result.error != null) {
          return _RetryState(
            message: result.error!,
            onRetry: () => ref.invalidate(activeInvitesProvider),
          );
        }
        if (result.items.isEmpty) {
          return _RetryState(
            icon: Icons.link_off,
            message: 'Nessun link attivo. Creane uno dal pulsante QR.',
            onRetry: () => ref.invalidate(activeInvitesProvider),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: result.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final invite = result.items[index];
            return SectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: RallyColors.lime),
                title: Text(
                  _inviteKind(invite.kind),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Scade ${_shortDate(invite.expiresAt)} · '
                  '${invite.useCount}/${invite.maxUses} utilizzi · …${invite.hint}',
                ),
                trailing: IconButton(
                  onPressed: () => _revoke(context, ref, invite.id),
                  icon: const Icon(Icons.link_off),
                  tooltip: 'Revoca invito',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String inviteId,
  ) async {
    final error = await ref.read(inviteServiceProvider).revoke(inviteId);
    if (!context.mounted) return;
    ref.invalidate(activeInvitesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Invito revocato.')));
  }

  String _inviteKind(String kind) => switch (kind) {
    'PROFILE' => 'Profilo condiviso',
    'TEAM_JOIN' => 'Invito team',
    'TEAM_LINK' => 'Collegamento team',
    'MATCH' => 'Invito partita',
    'DUO' => 'Invito Duo Mode',
    _ => 'Invito amicizia',
  };

  String _shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ConnectionsTab extends ConsumerWidget {
  const _ConnectionsTab({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationships = ref.watch(friendRelationshipsProvider);
    return relationships.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Errore: $error')),
      data: (result) {
        if (result.error != null) {
          return _RetryState(
            message: result.error!,
            onRetry: () => ref.invalidate(friendRelationshipsProvider),
          );
        }
        final items = result.items.where((item) {
          if (mode == 'friends') return item.status == 'ACCEPTED';
          return item.status == 'PENDING';
        }).toList();
        if (items.isEmpty) {
          return _RetryState(
            icon: mode == 'friends'
                ? Icons.people_outline
                : Icons.mark_email_read_outlined,
            message: mode == 'friends'
                ? 'Nessun amico ancora. Usa QR, codice o suggerimenti per collegarti.'
                : 'Nessuna richiesta in attesa.',
            onRetry: () => ref.invalidate(friendRelationshipsProvider),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(friendRelationshipsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ConnectionCard(
              connection: items[index],
              requestMode: mode == 'requests',
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.connection, required this.requestMode});

  final FriendConnection connection;
  final bool requestMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        connection.showOnlineStatus &&
        connection.lastActiveAt != null &&
        DateTime.now().difference(connection.lastActiveAt!).inMinutes <= 10;
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              _NetworkAvatar(
                label: connection.displayName,
                url: connection.avatarUrl,
                online: online,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      [
                        _level(connection.level),
                        _availability(connection.availability),
                        connection.homeArea,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => _menu(context, ref, action),
                itemBuilder: (_) => [
                  if (!requestMode)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Rimuovi amico'),
                    ),
                  const PopupMenuItem(value: 'block', child: Text('Blocca')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (requestMode)
            Row(
              children: [
                if (connection.direction == 'INCOMING') ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _respond(context, ref, true),
                      child: const Text('Accetta'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond(context, ref, false),
                      child: const Text('Rifiuta'),
                    ),
                  ),
                ] else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancel(context, ref),
                      icon: const Icon(Icons.close),
                      label: const Text('Annulla richiesta'),
                    ),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _propose(context, ref, duo: false),
                  icon: const Icon(Icons.sports_tennis, size: 18),
                  label: const Text('Partita'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/teams'),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Crea team'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _propose(context, ref, duo: true),
                  icon: const Icon(Icons.watch_outlined, size: 18),
                  label: const Text('Duo'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    bool accept,
  ) async {
    final error = await ref
        .read(friendsServiceProvider)
        .respond(connection.requestId, accept: accept);
    if (!context.mounted) return;
    _finish(
      context,
      ref,
      error,
      accept ? 'Amicizia confermata.' : 'Richiesta rifiutata.',
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(friendsServiceProvider)
        .cancel(connection.requestId);
    if (!context.mounted) return;
    _finish(context, ref, error, 'Richiesta annullata.');
  }

  Future<void> _propose(
    BuildContext context,
    WidgetRef ref, {
    required bool duo,
  }) async {
    final error = await ref
        .read(socialServiceProvider)
        .proposeMatch(
          connection.userId,
          message: duo
              ? 'Ti propongo una partita Momentum in Duo Mode.'
              : 'Ti va una partita con Momentum?',
        );
    if (!context.mounted) return;
    if (error == null && duo) context.push('/match/new?duo=1');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Proposta inviata.')));
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final service = ref.read(friendsServiceProvider);
    final error = action == 'block'
        ? await service.block(connection.userId)
        : await service.removeFriend(connection.userId);
    if (!context.mounted) return;
    _finish(
      context,
      ref,
      error,
      action == 'block' ? 'Utente bloccato.' : 'Amicizia rimossa.',
    );
  }

  void _finish(
    BuildContext context,
    WidgetRef ref,
    String? error,
    String success,
  ) {
    ref.invalidate(friendRelationshipsProvider);
    ref.invalidate(blockedProfilesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? success)));
  }
}

class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(friendSuggestionsProvider);
    return suggestions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Errore: $error')),
      data: (result) {
        if (result.error != null) {
          return _RetryState(
            message: result.error!,
            onRetry: () => ref.invalidate(friendSuggestionsProvider),
          );
        }
        if (result.players.isEmpty) {
          return _RetryState(
            icon: Icons.person_search_outlined,
            message:
                'Nessun suggerimento disponibile. Attiva il profilo social o usa un invito diretto.',
            onRetry: () => ref.invalidate(friendSuggestionsProvider),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: result.players.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final player = result.players[index];
            return SectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _NetworkAvatar(
                  label: player.displayName,
                  url: player.avatarUrl,
                ),
                title: Text(
                  player.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${_level(player.level)} · ${player.homeArea}'),
                trailing: IconButton.filledTonal(
                  onPressed: () async {
                    final error = await ref
                        .read(socialServiceProvider)
                        .sendContactRequest(player.userId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error ?? 'Richiesta inviata.')),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Invia richiesta',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BlockedTab extends ConsumerWidget {
  const _BlockedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedProfilesProvider);
    return blocked.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Errore: $error')),
      data: (result) {
        if (result.items.isEmpty) {
          return _RetryState(
            icon: Icons.block,
            message: result.error ?? 'Non hai bloccato nessun utente.',
            onRetry: () => ref.invalidate(blockedProfilesProvider),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: result.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = result.items[index];
            return SectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _NetworkAvatar(
                  label: user.displayName,
                  url: user.avatarUrl,
                ),
                title: Text(user.displayName),
                trailing: TextButton(
                  onPressed: () async {
                    final error = await ref
                        .read(friendsServiceProvider)
                        .unblock(user.userId);
                    ref.invalidate(blockedProfilesProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error ?? 'Utente sbloccato.')),
                    );
                  },
                  child: const Text('Sblocca'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({required this.label, this.url, this.online = false});

  final String label;
  final String? url;
  final bool online;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CircleAvatar(
        radius: 23,
        backgroundColor: RallyColors.surfaceHigh,
        foregroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
        onForegroundImageError: url?.isNotEmpty == true ? (_, _) {} : null,
        child: Text(
          label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase(),
          style: const TextStyle(
            color: RallyColors.lime,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (online)
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: RallyColors.win,
              shape: BoxShape.circle,
              border: Border.all(color: RallyColors.night, width: 2),
            ),
          ),
        ),
    ],
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({
    required this.message,
    required this.onRetry,
    this.icon = Icons.refresh,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      EmptyStateCard(
        icon: icon,
        title: 'Amici Momentum',
        message: message,
        primaryLabel: 'Aggiorna',
        primaryIcon: Icons.refresh,
        onPrimary: onRetry,
      ),
    ],
  );
}

String _level(String value) => switch (value) {
  'BEGINNER' => 'Principiante',
  'IMPROVER' => 'In crescita',
  'ADVANCED' => 'Avanzato',
  'COMPETITION' => 'Agonista',
  _ => 'Intermedio',
};

String _availability(String value) => switch (value) {
  'TODAY' => 'Disponibile oggi',
  'EVENING' => 'Sera',
  'WEEKEND' => 'Weekend',
  _ => 'Flessibile',
};
