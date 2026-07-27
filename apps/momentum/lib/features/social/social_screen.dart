/// Social leggero (PRD K): scoperta giocatori, profilo pubblico controllato,
/// matchmaking sicuro e niente feed/video costosi.
///
/// Con account + profilo visibile: giocatori REALI dal backend (RLS 0004),
/// richieste contatto/partita/team vere e inbox con accetta/rifiuta.
/// Senza account o cloud: stato vuoto esplicito, mai giocatori simulati.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation_targets.dart';
import '../../core/profile_visuals.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../domain/social_matching.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/friends_service.dart';
import '../../services/cloud/social_service.dart';
import '../../services/cloud/team_cloud_service.dart';
import '../../services/team_image_service.dart';
import 'invite_share_sheet.dart';

/// Giocatori visibili sul social (solo con account).
final socialDiscoveryProvider =
    FutureProvider.autoDispose<({List<SocialPlayer> players, String? error})>((
      ref,
    ) async {
      final auth = ref.watch(cloudAuthProvider);
      if (!auth.profileLinked) {
        return (players: const <SocialPlayer>[], error: null);
      }
      return ref.read(socialServiceProvider).discover();
    });

/// Richieste in attesa di risposta.
final socialInboxProvider =
    FutureProvider.autoDispose<({List<SocialInboxItem> items, String? error})>((
      ref,
    ) async {
      final auth = ref.watch(cloudAuthProvider);
      if (!auth.profileLinked) {
        return (items: const <SocialInboxItem>[], error: null);
      }
      return ref.read(socialServiceProvider).inbox();
    });

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key, this.initialPlayerId, this.initialFocus});

  final String? initialPlayerId;

  /// Deep-link focus: inbox | proposals | map
  final String? initialFocus;

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  String _availability = 'all';
  String _style = 'all';
  final Set<String> _busyPlayers = {};
  final GlobalKey _inboxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialPlayerId != null) {
        unawaited(_openSharedProfile(widget.initialPlayerId!));
      }
      if (widget.initialFocus == 'inbox' ||
          widget.initialFocus == 'proposals') {
        _scrollToInbox();
      }
    });
  }

  void _scrollToInbox() {
    final target = _inboxKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openSharedProfile(String userId) async {
    final result = await ref.read(socialServiceProvider).profile(userId);
    if (!mounted) return;
    final player = result.player;
    if (player == null) {
      _snack(result.error ?? 'Profilo non disponibile.');
      return;
    }
    final me = ref.read(meProvider).value;
    final summaries = ref.read(summariesProvider).value ?? const [];
    final score = compatibilityScore(
      myScore: playerScore(summaries),
      otherScore: player.skillScore,
      myAvailability: me?.availability ?? 'FLEX',
      otherAvailability: player.availability,
      myStyles: (me?.styleTags ?? '')
          .split(',')
          .where((tag) => tag.isNotEmpty)
          .toList(),
      otherStyles: player.styleTags,
      myRole: me?.preferredRole ?? 'UNDEFINED',
      otherRole: player.role,
      otherReliability: player.reliability,
    );
    _showPlayerSheet(player, score);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final summaries = ref.watch(summariesProvider).value ?? const [];
    final auth = ref.watch(cloudAuthProvider);
    final discovery = ref.watch(socialDiscoveryProvider);
    final myScore = playerScore(summaries);
    final visible = ref.watch(_socialEnabledProvider).value == 'true';

    final myStyles = (me?.styleTags ?? '')
        .split(',')
        .where((t) => t.isNotEmpty)
        .toList();
    final rawPlayers = discovery.value?.players ?? const <SocialPlayer>[];

    // Tutti i giocatori trovati in zona, ordinati per compatibilità: è ciò
    // che la mappa mostra SEMPRE — ogni marker apre il profilo completo,
    // senza dover passare dai filtri o dalla lista sottostante.
    final allPlayers =
        rawPlayers
            .map(
              (p) => (
                player: p,
                compatibility: compatibilityScore(
                  myScore: myScore,
                  otherScore: p.skillScore,
                  myAvailability: me?.availability ?? 'FLEX',
                  otherAvailability: p.availability,
                  myStyles: myStyles,
                  otherStyles: p.styleTags,
                  myRole: me?.preferredRole ?? 'UNDEFINED',
                  otherRole: p.role,
                  otherReliability: p.reliability,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.compatibility.compareTo(a.compatibility));

    // I filtri disponibilità/stile valgono solo per la lista qui sotto.
    final players = allPlayers
        .where((e) => _matchesFilters(e.player))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social padel'),
        leading: const SafeBackButton(fallback: AppLocations.home),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends'),
            icon: const Icon(Icons.people_outline),
            tooltip: 'Amici e richieste',
          ),
          IconButton(
            onPressed: () => context.push('/invite/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scansiona invito',
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(socialDiscoveryProvider);
              ref.invalidate(socialInboxProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(socialDiscoveryProvider);
          ref.invalidate(socialInboxProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _PrivacyBanner(
              signedIn: auth.signedIn,
              profileLinked: auth.profileLinked,
              visible: visible,
              onProfile: () => context.push(
                auth.profileLinked
                    ? '/privacy'
                    : '/auth?returnTo=${Uri.encodeQueryComponent('/social')}',
              ),
            ),
            const SizedBox(height: 12),
            if (auth.profileLinked) ...[
              _VisibilityCard(myScore: myScore),
              const SizedBox(height: 12),
            ],
            if (discovery.isLoading && auth.profileLinked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (discovery.value?.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ErrorCard(
                  message: discovery.value!.error!,
                  onRetry: () => ref.invalidate(socialDiscoveryProvider),
                ),
              ),
            _MapCard(
              entries: allPlayers,
              me: me,
              myScore: myScore,
              onSelected: (entry) =>
                  _showPlayerSheet(entry.player, entry.compatibility),
            ),
            const SizedBox(height: 12),
            _Filters(
              availability: _availability,
              style: _style,
              onAvailability: (v) => setState(() => _availability = v),
              onStyle: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: 12),
            if (auth.profileLinked)
              KeyedSubtree(key: _inboxKey, child: const _InboxSection()),
            Row(
              children: [
                Text(
                  'GIOCATORI COMPATIBILI',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.white54,
                  ),
                ),
                const Spacer(),
                Text(
                  '${players.length} trovati',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              EmptyStateCard(
                icon: Icons.travel_explore,
                title: 'Nessun match con questi filtri',
                message: auth.signedIn
                    ? 'Prova filtri diversi oppure rendi visibile il profilo '
                          'per partecipare al matchmaking.'
                    : 'Accedi gratis per cercare profili reali. Momentum non '
                          'mostra giocatori simulati.',
                primaryLabel: 'Reset filtri',
                primaryIcon: Icons.refresh,
                onPrimary: () => setState(() {
                  _availability = 'all';
                  _style = 'all';
                }),
              )
            else
              for (final entry in players) ...[
                _PlayerMatchCard(
                  player: entry.player,
                  compatibility: entry.compatibility,
                  busy: _busyPlayers.contains(entry.player.userId),
                  onDetails: () =>
                      _showPlayerSheet(entry.player, entry.compatibility),
                  onContact: () => _action(
                    entry.player,
                    () => ref
                        .read(socialServiceProvider)
                        .sendContactRequest(entry.player.userId),
                    okMessage:
                        'Richiesta di contatto inviata a '
                        '${entry.player.displayName}',
                  ),
                  onMatch: () => _action(
                    entry.player,
                    () => ref
                        .read(socialServiceProvider)
                        .proposeMatch(
                          entry.player.userId,
                          message: 'Ti va una partita? (via Momentum)',
                          levelHint: badgeForScore(myScore),
                        ),
                    okMessage:
                        'Proposta partita inviata a '
                        '${entry.player.displayName}',
                  ),
                  onTeam: () => unawaited(_inviteToMyTeam(entry.player)),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  bool _matchesFilters(SocialPlayer p) {
    if (_availability != 'all' && p.availability != _availability) {
      return false;
    }
    if (_style != 'all' && !p.styleTags.contains(_style)) return false;
    return true;
  }

  Future<void> _action(
    SocialPlayer player,
    Future<String?> Function() op, {
    required String okMessage,
  }) async {
    if (!ref.read(cloudAuthProvider).profileLinked) {
      context.push('/auth');
      return;
    }
    setState(() => _busyPlayers.add(player.userId));
    final error = await op();
    if (!mounted) return;
    setState(() => _busyPlayers.remove(player.userId));
    _snack(error ?? okMessage);
  }

  void _showPlayerSheet(SocialPlayer player, int compatibility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RallyColors.surface,
      builder: (sheetContext) => _PlayerDetailSheet(
        player: player,
        compatibility: compatibility,
        onContact: () {
          Navigator.pop(sheetContext);
          _action(
            player,
            () => ref
                .read(socialServiceProvider)
                .sendContactRequest(player.userId),
            okMessage: 'Richiesta inviata a ${player.displayName}',
          );
        },
        onMatch: () {
          Navigator.pop(sheetContext);
          _action(
            player,
            () => ref
                .read(socialServiceProvider)
                .proposeMatch(
                  player.userId,
                  message: 'Ti va una partita? (via Momentum)',
                ),
            okMessage: 'Proposta partita inviata.',
          );
        },
        onDuo: () async {
          Navigator.pop(sheetContext);
          final error = await ref
              .read(socialServiceProvider)
              .proposeMatch(
                player.userId,
                message: 'Ti propongo una partita in Duo Mode.',
              );
          if (!mounted) return;
          _snack(error ?? 'Proposta Duo inviata.');
          if (error == null) context.push('/match/new?duo=1');
        },
        onTeam: () {
          Navigator.pop(sheetContext);
          unawaited(_inviteToMyTeam(player));
        },
        onShare: () {
          Navigator.pop(sheetContext);
          showInviteShareSheet(
            context,
            ref,
            kind: 'PROFILE',
            targetUserId: player.userId,
          );
        },
        onBlock: () => _blockPlayer(sheetContext, player),
        onReport: () => _reportPlayer(sheetContext, player),
      ),
    );
  }

  Future<void> _blockPlayer(
    BuildContext sheetContext,
    SocialPlayer player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bloccare ${player.displayName}?'),
        content: const Text(
          'Non potrete più trovarvi sulla mappa, inviarvi richieste o '
          'visualizzare l’attività reciproca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await ref.read(friendsServiceProvider).block(player.userId);
    if (!mounted || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    ref.invalidate(socialDiscoveryProvider);
    _snack(error ?? 'Utente bloccato.');
  }

  Future<void> _reportPlayer(
    BuildContext sheetContext,
    SocialPlayer player,
  ) async {
    var category = 'SPAM';
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Segnala ${player.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'SPAM', child: Text('Spam')),
                  DropdownMenuItem(
                    value: 'HARASSMENT',
                    child: Text('Comportamento offensivo'),
                  ),
                  DropdownMenuItem(
                    value: 'IMPERSONATION',
                    child: Text('Identità falsa'),
                  ),
                  DropdownMenuItem(
                    value: 'PRIVACY',
                    child: Text('Problema privacy'),
                  ),
                  DropdownMenuItem(value: 'OTHER', child: Text('Altro')),
                ],
                onChanged: (value) =>
                    setLocal(() => category = value ?? 'SPAM'),
                decoration: const InputDecoration(labelText: 'Motivo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Dettagli facoltativi',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Invia'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) {
      details.dispose();
      return;
    }
    final error = await ref
        .read(friendsServiceProvider)
        .report(player.userId, category: category, details: details.text);
    details.dispose();
    if (!mounted || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    _snack(error ?? 'Segnalazione inviata. Grazie.');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Invite [player] into one of **my** local teams (ensures cloud team first).
  Future<void> _inviteToMyTeam(SocialPlayer player) async {
    if (!ref.read(cloudAuthProvider).profileLinked) {
      context.push('/auth');
      return;
    }
    final teams = ref.read(teamsProvider).value ?? const <Team>[];
    if (teams.isEmpty) {
      _snack('Crea prima un team, poi invita ${player.displayName}.');
      if (mounted) context.push('/teams');
      return;
    }
    final selected = teams.length == 1
        ? teams.first
        : await showModalBottomSheet<Team>(
            context: context,
            backgroundColor: RallyColors.surface,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Invita nel team',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'Scegli in quale team invitare ${player.displayName}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final team in teams)
                    ListTile(
                      leading: const Icon(Icons.groups_2_rounded),
                      title: Text(team.name),
                      subtitle: Text(
                        team.playerBName.isEmpty
                            ? 'Senza partner fisso'
                            : 'Con ${team.playerBName}',
                      ),
                      onTap: () => Navigator.pop(sheetContext, team),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
    if (selected == null || !mounted) return;
    setState(() => _busyPlayers.add(player.userId));
    try {
      final cloudTeamId = await ref
          .read(teamImageServiceProvider)
          .ensureCloudTeam(selected);
      final error = await ref
          .read(socialServiceProvider)
          .inviteToMyTeam(
            teamId: cloudTeamId,
            targetUserId: player.userId,
            message: 'Ti invito nel team ${selected.name}',
          );
      if (!mounted) return;
      _snack(
        error ??
            'Invito inviato a ${player.displayName} per «${selected.name}»',
      );
      ref.invalidate(socialInboxProvider);
    } on Exception catch (e) {
      if (!mounted) return;
      _snack('Invito non inviato: $e');
    } finally {
      if (mounted) setState(() => _busyPlayers.remove(player.userId));
    }
  }
}

class _PlayerDetailSheet extends StatelessWidget {
  const _PlayerDetailSheet({
    required this.player,
    required this.compatibility,
    required this.onContact,
    required this.onMatch,
    required this.onDuo,
    required this.onTeam,
    required this.onShare,
    required this.onBlock,
    required this.onReport,
  });

  final SocialPlayer player;
  final int compatibility;
  final VoidCallback onContact;
  final VoidCallback onMatch;
  final VoidCallback onDuo;
  final VoidCallback onTeam;
  final VoidCallback onShare;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final recentlyActive =
        player.showOnlineStatus &&
        player.lastActiveAt != null &&
        DateTime.now().difference(player.lastActiveAt!).inMinutes <= 10;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.58,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: RallyColors.surfaceHigh,
                    foregroundImage: player.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(player.avatarUrl!)
                        : null,
                    onForegroundImageError: player.avatarUrl?.isNotEmpty == true
                        ? (_, _) {}
                        : null,
                    child: Text(
                      player.displayName.isEmpty
                          ? '?'
                          : player.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 25,
                        color: RallyColors.lime,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (recentlyActive)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: RallyColors.win,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: RallyColors.surface,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _playerLevel(player.level),
                        _playerRole(player.role),
                        _availabilityText(player.availability),
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              _CompatibilityPill(value: compatibility),
            ],
          ),
          if (player.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(player.bio, style: const TextStyle(height: 1.4)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (player.homeArea.isNotEmpty)
                _DetailChip(
                  icon: Icons.location_on_outlined,
                  label: player.homeArea,
                ),
              if (player.club.isNotEmpty)
                _DetailChip(icon: Icons.stadium_outlined, label: player.club),
              _DetailChip(
                icon: Icons.sports_tennis,
                label:
                    'Mano ${player.dominantHand == 'LEFT' ? 'sinistra' : 'destra'}',
              ),
              if (player.preferredSide != 'UNDEFINED')
                _DetailChip(
                  icon: Icons.swap_horiz,
                  label: 'Lato ${_playerRole(player.preferredSide)}',
                ),
              if (player.preferredTime.isNotEmpty)
                _DetailChip(icon: Icons.schedule, label: player.preferredTime),
              if (player.mutualFriendsCount > 0)
                _DetailChip(
                  icon: Icons.people_outline,
                  label:
                      '${player.mutualFriendsCount} ${player.mutualFriendsCount == 1 ? 'amico' : 'amici'} in comune',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatTile(label: 'Score', value: '${player.skillScore}'),
                StatTile(
                  label: 'Affidabilità',
                  value: '${player.reliability}%',
                ),
                if (player.publicStatsEnabled)
                  StatTile(label: 'Vittorie', value: '${player.winRate}%')
                else
                  const StatTile(label: 'Partite', value: 'Private'),
              ],
            ),
          ),
          if (player.publicStatsEnabled) ...[
            const SizedBox(height: 8),
            Text(
              '${player.matchCount} partite pubbliche',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          if (player.badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final badge in player.badges) Chip(label: Text(badge)),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onMatch,
            icon: const Icon(Icons.sports_tennis),
            label: const Text('Proponi una partita'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onContact,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Amicizia'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDuo,
                  icon: const Icon(Icons.watch_outlined, size: 18),
                  label: const Text('Duo Mode'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onTeam,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Invita nel team'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Condividi'),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Segnala'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onBlock,
                  icon: const Icon(Icons.block),
                  label: const Text('Blocca'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label.isEmpty ? 'Zona non indicata' : label),
  );
}

String _playerLevel(String wire) => switch (wire) {
  'BEGINNER' => 'Principiante',
  'IMPROVER' => 'In crescita',
  'ADVANCED' => 'Avanzato',
  'COMPETITION' => 'Agonista',
  _ => 'Intermedio',
};

String _playerRole(String wire) => switch (wire) {
  'LEFT' => 'sinistra',
  'RIGHT' => 'destra',
  'FLEX' => 'flex',
  _ => '',
};

String _availabilityText(String wire) => switch (wire) {
  'TODAY' => 'Oggi',
  'EVENING' => 'Sera',
  'WEEKEND' => 'Weekend',
  _ => 'Flessibile',
};

// ------------------------------------------------------------- visibility

/// Presenza sul social: switch + disponibilità + stile, salvati in locale e
/// propagati al profilo cloud.
class _VisibilityCard extends ConsumerStatefulWidget {
  const _VisibilityCard({required this.myScore});
  final int myScore;

  @override
  ConsumerState<_VisibilityCard> createState() => _VisibilityCardState();
}

class _VisibilityCardState extends ConsumerState<_VisibilityCard> {
  bool _busy = false;
  bool? _enabledOverride;

  static const _styleOptions = [
    ('control', 'Controllo'),
    ('attack', 'Attacco'),
    ('defense', 'Difesa'),
    ('flex', 'Flex'),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final enabledStored = ref.watch(_socialEnabledProvider).value == 'true';
    final enabled = _enabledOverride ?? enabledStored;
    final availability = me?.availability ?? 'FLEX';
    final styles = (me?.styleTags ?? '')
        .split(',')
        .where((t) => t.isNotEmpty)
        .toSet();

    return SectionCard(
      title: 'LA TUA PRESENZA',
      trailing: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: _busy ? null : (v) => _push(enabled: v),
            title: const Text(
              'Visibile sul social',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            subtitle: const Text(
              'Pubblica solo profilo base e preferenze. Mai la posizione.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'DISPONIBILITÀ',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in const [
                ('TODAY', 'Oggi'),
                ('EVENING', 'Sera'),
                ('WEEKEND', 'Weekend'),
                ('FLEX', 'Flessibile'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: availability == value,
                  onSelected: _busy
                      ? null
                      : (_) => _push(enabled: enabled, availability: value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'STILE DI GIOCO',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _styleOptions)
                FilterChip(
                  label: Text(label),
                  selected: styles.contains(value),
                  onSelected: _busy
                      ? null
                      : (sel) {
                          final next = {...styles};
                          sel ? next.add(value) : next.remove(value);
                          _push(enabled: enabled, styleTags: next.toList());
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _push({
    required bool enabled,
    String? availability,
    List<String>? styleTags,
  }) async {
    final me = ref.read(meProvider).value;
    final nextAvailability = availability ?? me?.availability ?? 'FLEX';
    final nextStyles =
        styleTags ??
        (me?.styleTags ?? '').split(',').where((t) => t.isNotEmpty).toList();

    setState(() {
      _busy = true;
      _enabledOverride = enabled;
    });
    // Prima in locale (offline-first)...
    await ref
        .read(playerRepoProvider)
        .updateSocialPrefs(
          availability: nextAvailability,
          styleTags: nextStyles,
        );
    await ref
        .read(keyValueRepoProvider)
        .set('social_enabled', enabled ? 'true' : 'false');
    ref.invalidate(meProvider);
    // ...poi sul cloud.
    final error = await ref
        .read(socialServiceProvider)
        .updateVisibility(
          enabled: enabled,
          availability: nextAvailability,
          styleTags: nextStyles,
          skillScore: widget.myScore,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabledOverride = null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preferenze salvate sul device. $error')),
      );
    }
    ref.invalidate(socialDiscoveryProvider);
  }
}

final _socialEnabledProvider = StreamProvider.autoDispose<String?>(
  (ref) => ref.watch(keyValueRepoProvider).watch('social_enabled'),
);

// ------------------------------------------------------------------ inbox

class _InboxSection extends ConsumerStatefulWidget {
  const _InboxSection();

  @override
  ConsumerState<_InboxSection> createState() => _InboxSectionState();
}

class _InboxSectionState extends ConsumerState<_InboxSection> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(socialInboxProvider);
    final items = inbox.value?.items ?? const <SocialInboxItem>[];
    if (items.isEmpty && inbox.value?.error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: 'RICHIESTE RICEVUTE',
        trailing: Text(
          '${items.length}',
          style: const TextStyle(color: RallyColors.lime, fontSize: 12),
        ),
        child: Column(
          children: [
            if (inbox.value?.error != null)
              _ErrorCard(
                message: inbox.value!.error!,
                onRetry: () => ref.invalidate(socialInboxProvider),
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      switch (item.kind) {
                        'proposal' => Icons.sports_tennis,
                        'team' || 'team_invite' => Icons.groups_outlined,
                        _ => Icons.person_add_alt,
                      },
                      size: 20,
                      color: RallyColors.lime,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (item.kind) {
                              'proposal' =>
                                '${item.fromName} propone una partita',
                              'team' =>
                                '${item.fromName} vuole entrare nel team',
                              'team_invite' =>
                                '${item.fromName} ti invita nel team'
                                    '${item.teamName == null || item.teamName!.isEmpty ? '' : ' «${item.teamName}»'}',
                              _ => '${item.fromName} vuole aggiungerti',
                            },
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          if (item.message.isNotEmpty)
                            Text(
                              item.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_busy.contains(item.id))
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      IconButton(
                        onPressed: () => _respond(item, accept: true),
                        icon: const Icon(
                          Icons.check_circle,
                          color: RallyColors.win,
                        ),
                        tooltip: 'Accetta',
                      ),
                      IconButton(
                        onPressed: () => _respond(item, accept: false),
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: RallyColors.loss,
                        ),
                        tooltip: 'Rifiuta',
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(SocialInboxItem item, {required bool accept}) async {
    setState(() => _busy.add(item.id));
    final result = await ref
        .read(socialServiceProvider)
        .respond(item, accept: accept);
    if (!mounted) return;
    setState(() => _busy.remove(item.id));
    final okMessage = !accept
        ? 'Richiesta rifiutata'
        : switch (item.kind) {
            'proposal' => 'Proposta accettata. Configura la partita.',
            'team_invite' => 'Sei entrato nel team.',
            'team' => 'Giocatore aggiunto al team.',
            'contact' => 'Amicizia accettata.',
            _ => 'Richiesta accettata',
          };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? okMessage)),
    );
    ref.invalidate(socialInboxProvider);
    if (result.error != null || !accept || !mounted) return;

    if (item.kind == 'proposal') {
      final params = <String, String>{
        'opponentName': result.creatorName ?? item.fromName,
        if (result.linkedMatchId != null) 'linkedMatchId': result.linkedMatchId!,
        if (result.proposalId != null) 'proposalId': result.proposalId!,
      };
      context.push(Uri(path: '/match/new', queryParameters: params).toString());
    } else if (item.kind == 'team_invite' || item.kind == 'team') {
      // Sync cloud memberships so the new team appears locally.
      try {
        await ref.read(teamCloudServiceProvider).syncMemberships();
      } catch (_) {}
      if (!mounted) return;
      final teamId = result.teamId ?? item.teamId;
      if (teamId != null && teamId.isNotEmpty) {
        context.push('/teams');
      }
    } else if (item.kind == 'contact') {
      context.push('/friends');
    }
  }
}

// ------------------------------------------------------------------- misc

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RallyColors.loss.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RallyColors.loss.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: RallyColors.loss),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({
    required this.signedIn,
    required this.profileLinked,
    required this.visible,
    required this.onProfile,
  });

  final bool signedIn;
  final bool profileLinked;
  final bool visible;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final ok = profileLinked && visible;
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified_user_outlined : Icons.visibility_off_outlined,
            color: ok ? RallyColors.win : RallyColors.lime,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Profilo pronto: puoi ricevere e inviare richieste.'
                  : signedIn && !profileLinked
                  ? 'Collega i dati locali all’account per attivare social e inviti.'
                  : signedIn
                  ? 'Profilo privato: sei tu a decidere quando comparire.'
                  : 'Accedi gratis per il matchmaking reale: pubblichi '
                        'solo profilo base e preferenze.',
              style: const TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: onProfile,
            child: Text(
              profileLinked
                  ? 'Gestisci'
                  : signedIn
                  ? 'Collega'
                  : 'Accedi',
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- map

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.entries,
    required this.me,
    required this.myScore,
    required this.onSelected,
  });

  final List<({SocialPlayer player, int compatibility})> entries;
  final Player? me;
  final int myScore;
  final ValueChanged<({SocialPlayer player, int compatibility})> onSelected;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'MAPPA MATCHMAKING',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _MapBoard(
                entries: entries,
                me: me,
                myScore: myScore,
                onSelected: onSelected,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'La mappa mostra tutti i giocatori trovati in zona: tocca un '
            'marker per aprire il profilo e proporre subito una partita '
            '(i filtri valgono per la lista sotto). Le aree sono '
            'approssimative e offuscate, mai coordinate reali.',
            style: TextStyle(fontSize: 12.5, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _MapBoard extends StatefulWidget {
  const _MapBoard({
    required this.entries,
    required this.me,
    required this.myScore,
    required this.onSelected,
  });

  final List<({SocialPlayer player, int compatibility})> entries;
  final Player? me;
  final int myScore;
  final ValueChanged<({SocialPlayer player, int compatibility})> onSelected;

  @override
  State<_MapBoard> createState() => _MapBoardState();
}

class _MapBoardState extends State<_MapBoard> {
  int? _expandedCluster;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const marker = 56.0;
        final clusters = _cluster(widget.entries.take(20).toList());
        final playerMarkers = <Widget>[];
        for (
          var clusterIndex = 0;
          clusterIndex < clusters.length;
          clusterIndex++
        ) {
          final cluster = clusters[clusterIndex];
          final expanded = _expandedCluster == clusterIndex;
          if (cluster.entries.length > 1 && !expanded) {
            playerMarkers.add(
              _positioned(
                center: cluster.center,
                width: w,
                height: h,
                markerSize: marker,
                child: _ClusterMarker(
                  count: cluster.entries.length,
                  bestCompatibility: cluster.entries
                      .map((entry) => entry.compatibility)
                      .reduce(math.max),
                  onTap: () => setState(() => _expandedCluster = clusterIndex),
                ),
              ),
            );
            continue;
          }
          for (var index = 0; index < cluster.entries.length; index++) {
            final entry = cluster.entries[index];
            final angle = cluster.entries.length == 1
                ? 0.0
                : (math.pi * 2 * index / cluster.entries.length) - math.pi / 2;
            final center = expanded && cluster.entries.length > 1
                ? Offset(
                    (cluster.center.dx + math.cos(angle) * 0.14).clamp(
                      0.10,
                      0.90,
                    ),
                    (cluster.center.dy + math.sin(angle) * 0.18).clamp(
                      0.22,
                      0.88,
                    ),
                  )
                : cluster.center;
            playerMarkers.add(
              _positioned(
                center: center,
                width: w,
                height: h,
                markerSize: marker,
                child: _MapMarker(
                  label: entry.player.displayName,
                  avatarUrl: entry.player.avatarUrl,
                  badge: badgeForScore(entry.player.skillScore),
                  availability: entry.player.availability,
                  compatibility: entry.compatibility,
                  highlighted: entry.compatibility >= 85,
                  onTap: () => widget.onSelected(entry),
                ),
              ),
            );
          }
        }
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/maps/padel_matchmaking_map.jpg',
                fit: BoxFit.cover,
                cacheWidth: 1000,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      RallyColors.night.withValues(alpha: 0.08),
                      RallyColors.night.withValues(alpha: 0.36),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _MapLabel(text: 'Tu · score ${widget.myScore}'),
            ),
            Positioned(
              left: w * .50 - marker / 2,
              top: h * .50 - marker / 2,
              child: _MapMarker(
                label: 'Tu',
                badge: badgeForScore(widget.myScore),
                availability: 'TODAY',
                compatibility: 100,
                highlighted: true,
                // La foto profilo resta sincronizzata con il profilo utente:
                // PlayerAvatar risolve locale → cloud → iniziali da solo.
                avatar: PlayerAvatar(
                  player: widget.me,
                  size: 42,
                  semanticLabel: 'La tua foto profilo sulla mappa',
                ),
              ),
            ),
            ...playerMarkers,
            if (_expandedCluster != null)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _expandedCluster = null),
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Chiudi gruppo',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(34),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<_MarkerCluster> _cluster(
    List<({SocialPlayer player, int compatibility})> entries,
  ) {
    final clusters = <_MarkerCluster>[];
    for (final entry in entries) {
      final position = mapPositionFor(entry.player.userId);
      final point = Offset(position.dx, position.dy);
      _MarkerCluster? target;
      for (final cluster in clusters) {
        if ((cluster.center - point).distance < 0.16) {
          target = cluster;
          break;
        }
      }
      if (target == null) {
        clusters.add(_MarkerCluster(center: point, entries: [entry]));
      } else {
        final count = target.entries.length;
        target.center = Offset(
          (target.center.dx * count + point.dx) / (count + 1),
          (target.center.dy * count + point.dy) / (count + 1),
        );
        target.entries.add(entry);
      }
    }
    return clusters;
  }

  Widget _positioned({
    required Offset center,
    required double width,
    required double height,
    required double markerSize,
    required Widget child,
  }) => Positioned(
    left: (width * center.dx - markerSize / 2)
        .clamp(8.0, width - markerSize - 8)
        .toDouble(),
    top: (height * center.dy - markerSize / 2)
        .clamp(36.0, height - markerSize - 8)
        .toDouble(),
    child: child,
  );
}

class _MarkerCluster {
  _MarkerCluster({required this.center, required this.entries});

  Offset center;
  final List<({SocialPlayer player, int compatibility})> entries;
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.bestCompatibility,
    required this.onTap,
  });

  final int count;
  final int bestCompatibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count giocatori, migliore compatibilità $bestCompatibility%',
    child: InkResponse(
      onTap: onTap,
      radius: 34,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: RallyColors.night.withValues(alpha: 0.94),
          border: Border.all(color: RallyColors.lime, width: 3),
          boxShadow: RallyColors.glow(RallyColors.lime, blur: 12),
        ),
        alignment: Alignment.center,
        child: Text(
          '+$count',
          style: const TextStyle(
            color: RallyColors.lime,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RallyColors.night.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.badge,
    required this.availability,
    required this.compatibility,
    this.avatarUrl,
    this.avatar,
    this.onTap,
    this.highlighted = false,
  });

  final String label;
  final String badge;
  final String availability;
  final int compatibility;
  final String? avatarUrl;

  /// Avatar già risolto (es. [PlayerAvatar] per il marker "Tu"): ha la
  /// precedenza su [avatarUrl].
  final Widget? avatar;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? RallyColors.win : _availabilityColor();
    return Semantics(
      button: onTap != null,
      label: '$label, livello $badge, compatibilita $compatibility%',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RallyColors.night.withValues(alpha: 0.90),
                      border: Border.all(color: color, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.30),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child:
                        avatar ??
                        CircleAvatar(
                          backgroundColor: RallyColors.surfaceHigh,
                          foregroundImage: avatarUrl?.isNotEmpty == true
                              ? NetworkImage(avatarUrl!)
                              : null,
                          onForegroundImageError: avatarUrl?.isNotEmpty == true
                              ? (_, _) {}
                              : null,
                          child: Text(
                            _initials(label),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: RallyColors.lime,
                            ),
                          ),
                        ),
                  ),
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: RallyColors.night, width: 2),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Color(0xFF07100A),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -2,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _availabilityColor(),
                        border: Border.all(color: RallyColors.night, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: RallyColors.night.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  compatibility == 100 ? 'TU' : '$compatibility%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _availabilityColor() => switch (availability) {
    'TODAY' => RallyColors.win,
    'EVENING' => RallyColors.teamThem,
    'WEEKEND' => RallyColors.lime,
    _ => Colors.white70,
  };

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

// ----------------------------------------------------------------- filters

class _Filters extends StatelessWidget {
  const _Filters({
    required this.availability,
    required this.style,
    required this.onAvailability,
    required this.onStyle,
  });

  final String availability;
  final String style;
  final ValueChanged<String> onAvailability;
  final ValueChanged<String> onStyle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'FILTRI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('all', 'Tutti', availability, onAvailability),
              _chip('TODAY', 'Oggi', availability, onAvailability),
              _chip('EVENING', 'Sera', availability, onAvailability),
              _chip('WEEKEND', 'Weekend', availability, onAvailability),
              _chip('FLEX', 'Flessibile', availability, onAvailability),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('all', 'Ogni stile', style, onStyle),
              _chip('control', 'Controllo', style, onStyle),
              _chip('attack', 'Attacco', style, onStyle),
              _chip('defense', 'Difesa', style, onStyle),
              _chip('flex', 'Flex', style, onStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String value,
    String label,
    String selected,
    ValueChanged<String> onSelected,
  ) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) => onSelected(value),
  );
}

// -------------------------------------------------------------- player card

class _PlayerMatchCard extends StatelessWidget {
  const _PlayerMatchCard({
    required this.player,
    required this.compatibility,
    required this.busy,
    required this.onDetails,
    required this.onContact,
    required this.onMatch,
    required this.onTeam,
  });

  final SocialPlayer player;
  final int compatibility;
  final bool busy;
  final VoidCallback onDetails;
  final VoidCallback onContact;
  final VoidCallback onMatch;
  final VoidCallback onTeam;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (player.homeArea.isNotEmpty) player.homeArea,
      _levelLabel(player.level),
      _roleLabel(player.role),
      _availabilityLabel(player.availability),
    ].where((s) => s.isNotEmpty).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: RallyColors.lime.withValues(alpha: .16),
                    foregroundImage: player.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(player.avatarUrl!)
                        : null,
                    onForegroundImageError: player.avatarUrl?.isNotEmpty == true
                        ? (_, _) {}
                        : null,
                    child: Text(
                      player.displayName.isEmpty
                          ? '?'
                          : player.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: RallyColors.lime,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitleParts.join(' · '),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CompatibilityPill(value: compatibility),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatTile(label: 'Score', value: '${player.skillScore}'),
                  StatTile(
                    label: 'Affidabilità',
                    value: '${player.reliability}%',
                  ),
                  StatTile(
                    label: 'Stile',
                    value: player.styleTags.isEmpty
                        ? '—'
                        : player.styleTags.map(_styleShort).join('·'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : onMatch,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sports_tennis),
                    label: const Text('Partita'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onContact,
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Contatto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onTeam,
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Invita team'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _styleShort(String style) => switch (style) {
    'control' => 'CTR',
    'attack' => 'ATT',
    'defense' => 'DIF',
    'flex' => 'FLX',
    _ => style.toUpperCase(),
  };

  String _levelLabel(String wire) => switch (wire) {
    'BEGINNER' => 'principiante',
    'IMPROVER' => 'in crescita',
    'INTERMEDIATE' => 'intermedio',
    'ADVANCED' => 'avanzato',
    'COMPETITION' => 'agonista',
    _ => '',
  };

  String _roleLabel(String wire) => switch (wire) {
    'LEFT' => 'sinistra',
    'RIGHT' => 'destra',
    'FLEX' => 'flex',
    _ => '',
  };

  String _availabilityLabel(String wire) => switch (wire) {
    'TODAY' => 'oggi',
    'EVENING' => 'sera',
    'WEEKEND' => 'weekend',
    'FLEX' => 'flessibile',
    _ => '',
  };
}

class _CompatibilityPill extends StatelessWidget {
  const _CompatibilityPill({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 85 ? RallyColors.win : RallyColors.lime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
