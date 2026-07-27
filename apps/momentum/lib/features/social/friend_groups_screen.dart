/// Gruppi amici + classifiche private (PRD 8 Pro).
///
/// Lista dei gruppi dell'utente, creazione (gate Pro), ingresso con codice
/// invito e dettaglio con la classifica privata. Le stats personali vengono
/// ripubblicate a ogni apertura così la classifica resta fresca.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../domain/entitlements.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/friend_groups_service.dart';

final myGroupsProvider = FutureProvider.autoDispose((ref) async {
  final groups = await FriendGroupsService.myGroups();
  // Il flag KV permette l'aggiornamento best-effort delle stats a fine
  // partita (live_match_controller) senza round-trip cloud extra.
  await ref
      .read(keyValueRepoProvider)
      .set('has_friend_groups', groups.isNotEmpty ? 'true' : 'false');
  if (groups.isNotEmpty) await publishGroupStats(ref);
  return groups;
});

final groupLeaderboardProvider = FutureProvider.autoDispose
    .family<List<GroupMemberStanding>, String>((ref, groupId) async {
      // Prima di leggere la classifica pubblica le proprie stats aggregate:
      // chi apre la classifica vede anche i propri numeri aggiornati.
      // (Le stats si aggiornano anche a fine partita, vedi
      // live_match_controller._finalize.)
      await publishGroupStats(ref);
      return FriendGroupsService.leaderboard(groupId);
    });

class FriendGroupsScreen extends ConsumerWidget {
  const FriendGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(cloudAuthProvider);
    final ents = ref.watch(entitlementsProvider);

    if (!auth.profileLinked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppi amici')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyStateCard(
              icon: Icons.groups_outlined,
              title: auth.signedIn
                  ? 'Collega il profilo locale'
                  : 'Accedi per usare i gruppi',
              message:
                  'Le classifiche private confrontano solo statistiche '
                  'aggregate tra amici che scelgono di condividerle.',
              primaryLabel: auth.signedIn ? 'Collega profilo' : 'Accedi',
              primaryIcon: auth.signedIn ? Icons.link : Icons.login,
              onPrimary: () => context.push(
                '/auth?returnTo=${Uri.encodeQueryComponent('/groups')}',
              ),
            ),
          ],
        ),
      );
    }

    final groups = ref.watch(myGroupsProvider);
    if (!ents.friendGroups) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gruppi amici'),
          leading: const SafeBackButton(fallback: AppLocations.profile),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyStateCard(
              icon: Icons.emoji_events_outlined,
              title: 'Classifiche private Pro',
              message:
                  'Crea e unisciti a gruppi amici con classifiche private. '
                  'Funzione inclusa nel piano Pro.',
              primaryLabel: 'Sblocca con Pro',
              primaryIcon: Icons.workspace_premium,
              onPrimary: () => pushPaywall(
                context,
                gate: 'friend_groups',
                plan: Plan.pro,
                reason: gates['friend_groups']?.pitch,
                returnTo: '/groups',
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppi amici'),
        leading: const SafeBackButton(fallback: AppLocations.profile),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'group_create',
        onPressed: () => ents.friendGroups
            ? _createDialog(context, ref)
            : pushPaywall(
                context,
                gate: 'friend_groups',
                plan: Plan.pro,
                reason: gates['friend_groups']?.pitch,
                returnTo: '/groups',
              ),
        icon: Icon(ents.friendGroups ? Icons.add : Icons.lock, size: 20),
        label: const Text('Nuovo gruppo'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myGroupsProvider.future),
        child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateCard(
                icon: Icons.cloud_off,
                title: 'Gruppi non raggiungibili',
                message: 'Controlla la connessione e riprova.',
                primaryLabel: 'Riprova',
                primaryIcon: Icons.refresh,
                onPrimary: () => ref.invalidate(myGroupsProvider),
              ),
            ],
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (!ents.friendGroups)
                PremiumGate(
                  gateKey: 'friend_groups',
                  entitled: (e) => e.friendGroups,
                  child: const SizedBox.shrink(),
                ),
              if (!ents.friendGroups) const SizedBox(height: 12),
              _JoinByCodeCard(onJoined: () => ref.invalidate(myGroupsProvider)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyStateCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Nessun gruppo ancora',
                  message:
                      'Crea un gruppo (Pro) e condividi il codice, oppure '
                      'inserisci il codice ricevuto da un amico.',
                  primaryLabel: 'Aggiorna',
                  primaryIcon: Icons.refresh,
                  onPrimary: () => ref.invalidate(myGroupsProvider),
                )
              else
                for (final g in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => context.push('/groups/${g.groupId}'),
                      leading: CircleAvatar(
                        backgroundColor: RallyColors.surfaceHigh,
                        child: Icon(
                          g.isOwner ? Icons.star : Icons.groups,
                          color: RallyColors.lime,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        g.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${g.memberCount} membri'
                        '${g.isOwner ? ' · creato da te' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white38,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo gruppo'),
        content: TextField(
          controller: name,
          maxLength: 40,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome gruppo (es. Padel del giovedì)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await FriendGroupsService.create(name.text);
    if (!context.mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    ref.invalidate(myGroupsProvider);
    final code = result.data['inviteCode'] as String? ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gruppo creato. Codice invito: $code')),
    );
  }
}

class _JoinByCodeCard extends StatefulWidget {
  const _JoinByCodeCard({required this.onJoined});

  final VoidCallback onJoined;

  @override
  State<_JoinByCodeCard> createState() => _JoinByCodeCardState();
}

class _JoinByCodeCardState extends State<_JoinByCodeCard> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final result = await FriendGroupsService.join(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      _code.clear();
      widget.onJoined();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Sei nel gruppo "${result.data['name']}"!'
              : result.error!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'ENTRA CON CODICE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Codice invito (8 caratteri)',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entra'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Consenso informato: entrare = condividere gli aggregati col gruppo.
          const Text(
            'Entrando condividi con i membri del gruppo solo nickname, foto e '
            'totali aggregati (partite, vittorie, streak). Mai le singole '
            'partite.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white38,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dettaglio gruppo: classifica privata + gestione membri.
class FriendGroupDetailScreen extends ConsumerWidget {
  const FriendGroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    final standings = ref.watch(groupLeaderboardProvider(groupId));
    final group = groups.valueOrNull
        ?.where((g) => g.groupId == groupId)
        .firstOrNull;
    final myUid = cloudClient?.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Classifica'),
        actions: [
          if (group != null)
            IconButton(
              tooltip: 'Condividi codice invito',
              icon: const Icon(Icons.ios_share),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Unisciti al mio gruppo "${group.name}" su Momentum! '
                      'Codice invito: ${group.inviteCode}',
                ),
              ),
            ),
          if (group != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'leave') await _leave(context, ref, group);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'leave',
                  child: Text(
                    group.isOwner ? 'Sciogli gruppo' : 'Lascia gruppo',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(groupLeaderboardProvider(groupId).future),
        child: standings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateCard(
                icon: Icons.cloud_off,
                title: 'Classifica non disponibile',
                message: 'Controlla la connessione e riprova.',
                primaryLabel: 'Riprova',
                primaryIcon: Icons.refresh,
                onPrimary: () =>
                    ref.invalidate(groupLeaderboardProvider(groupId)),
              ),
            ],
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (group != null)
                SectionCard(
                  title: 'CODICE INVITO',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.inviteCode,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: RallyColors.lime,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copia',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.inviteCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Codice copiato')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'CLASSIFICA PRIVATA',
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nessun membro ancora. Condividi il codice!',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _StandingRow(
                              position: i + 1,
                              row: rows[i],
                              isMe: rows[i].userId == myUid,
                              canRemove:
                                  group?.isOwner == true &&
                                  rows[i].userId != myUid,
                              onRemove: () =>
                                  _removeMember(context, ref, rows[i]),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              const Text(
                'La classifica confronta partite, vittorie e streak che ogni '
                'membro pubblica dal proprio storico. Si aggiorna quando i '
                'membri aprono il gruppo.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white38,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    FriendGroup group,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(group.isOwner ? 'Sciogliere il gruppo?' : 'Uscire?'),
        content: Text(
          group.isOwner
              ? 'Il gruppo e la classifica verranno eliminati per tutti.'
              : 'Potrai rientrare con il codice invito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await FriendGroupsService.leave(group.groupId);
    if (!context.mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    ref.invalidate(myGroupsProvider);
    context.pop();
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    GroupMemberStanding member,
  ) async {
    final result = await FriendGroupsService.removeMember(
      groupId,
      member.userId,
    );
    if (!context.mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    ref.invalidate(groupLeaderboardProvider(groupId));
    ref.invalidate(myGroupsProvider);
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.position,
    required this.row,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
  });

  final int position;
  final GroupMemberStanding row;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final medal = switch (position) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              medal ?? '$position',
              style: TextStyle(
                fontSize: medal != null ? 18 : 14,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: RallyColors.surfaceHigh,
            foregroundImage: row.avatarUrl?.isNotEmpty == true
                ? NetworkImage(row.avatarUrl!)
                : null,
            child: Text(
              row.displayName.isNotEmpty
                  ? row.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${row.displayName} (tu)' : row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isMe ? RallyColors.lime : Colors.white,
                  ),
                ),
                Text(
                  '${row.matches} partite'
                  '${row.streak > 0 ? ' · streak ${row.streak}' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.wins} V',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: RallyColors.win,
                ),
              ),
              Text(
                row.matches == 0 ? '—' : '${(row.winRate * 100).round()}% win',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Rimuovi dal gruppo',
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: Colors.white38,
              ),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
