/// Analytics di coppia (PRD A2/F4): record, compatibilità, rendimento
/// per difficoltà avversari, streak, suggerimenti.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/team_visuals.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../services/team_image_service.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/team_cloud_service.dart';
import '../social/invite_share_sheet.dart';

final teamMatchesProvider = FutureProvider.autoDispose
    .family<List<MatchSummary>, String>((ref, teamId) async {
      final all = await ref.watch(summariesProvider.future);
      return all.where((m) => m.teamId == teamId).toList();
    });

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamsProvider);

    final teams = teamAsync.value ?? const <Team>[];
    final cloudLocalId = 'tm_cloud_${teamId.replaceAll('-', '')}';
    final team = teams.where((t) => t.id == teamId).firstOrNull ??
        teams.where((t) => t.cloudId == teamId).firstOrNull ??
        teams.where((t) => t.id == cloudLocalId).firstOrNull;
    final matchesAsync = ref.watch(
      teamMatchesProvider(team?.id ?? teamId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(team?.name ?? 'Team'),
        leading: const SafeBackButton(fallback: AppLocations.teams),
      ),
      body: team == null
          ? (teamAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      EmptyStateCard(
                        icon: Icons.groups_outlined,
                        title: 'Team non trovato',
                        message:
                            'Il team non è ancora sincronizzato su questo '
                            'dispositivo. Apri Team e aggiorna, oppure '
                            'accetta di nuovo l’invito.',
                        primaryLabel: 'Torna ai team',
                        primaryIcon: Icons.arrow_back,
                        onPrimary: () => context.go(AppLocations.teams),
                      ),
                    ],
                  ))
          : matchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (matches) {
                final wins = matches.where((m) => m.won).length;
                final losses = matches.length - wins;
                final compat = matches.isEmpty
                    ? 0
                    : TeamWrappedData.compatibility(matches);

                var streak = 0, best = 0;
                for (final m in matches.reversed) {
                  streak = m.won ? streak + 1 : 0;
                  if (streak > best) best = streak;
                }

                final decisiveRate = _decisiveRate(matches);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _TeamIdentityCard(
                      team: team,
                      canManage: team.cloudRole != 'MEMBER',
                      onImage: () => _editImage(context, ref, team),
                      onInvite: () => _inviteTeam(context, ref, team),
                      onStyle: (style) => _updateAppearance(
                        context,
                        ref,
                        team,
                        scoringStyle: style,
                      ),
                      onColor: (color) => _updateAppearance(
                        context,
                        ref,
                        team,
                        colorArgb: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (matches.isEmpty) ...[
                      EmptyStateCard(
                        icon: Icons.sports_tennis,
                        title: 'Il team è pronto',
                        message:
                            'Sceglilo nella prossima partita: storico e analytics '
                            'si compileranno automaticamente con dati reali.',
                        primaryLabel: 'Nuova partita',
                        primaryIcon: Icons.add,
                        onPrimary: () => context.push('/match/new'),
                      ),
                    ] else ...[
                      SectionCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            StatTile(
                              label: 'Record',
                              value: '${wins}V-${losses}S',
                              color: wins >= losses
                                  ? RallyColors.win
                                  : RallyColors.loss,
                            ),
                            StatTile(
                              label: 'Compatibilità',
                              value: '$compat/100',
                            ),
                            StatTile(label: 'Best streak', value: '$best'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'RENDIMENTO PER DIFFICOLTÀ',
                        child: Column(children: _byDifficulty(matches)),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'GAME E SET DECISIVI',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Punti decisivi vinti: ${(decisiveRate * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              decisiveRate >= 0.55
                                  ? 'Coppia solida nei momenti chiave.'
                                  : 'Nei momenti chiave perdete più punti del '
                                        'normale: provate schemi più semplici sul '
                                        'golden point.',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (team.roleA != 'UNDEFINED' ||
                          team.roleB != 'UNDEFINED')
                        SectionCard(
                          title: 'RUOLI',
                          child: Text(
                            'Tu: ${_roleLabel(team.roleA)} · '
                            '${team.playerBName.isEmpty ? 'Compagno' : team.playerBName}: '
                            '${_roleLabel(team.roleB)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (team.tacticalNotes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SectionCard(
                          title: 'NOTE TATTICHE',
                          child: Text(team.tacticalNotes),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _editImage(
    BuildContext context,
    WidgetRef ref,
    Team team,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RallyColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Immagine del team',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Viene ritagliata e compressa prima del salvataggio.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Scegli dalla galleria'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Scatta una foto'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              if (team.imageLocalPath != null || team.imageCloudPath != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: RallyColors.loss,
                  ),
                  title: const Text('Rimuovi immagine'),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    TeamImageResult result;
    if (action == 'remove') {
      await ref.read(teamImageServiceProvider).remove(team);
      result = const TeamImageResult(saved: true);
    } else {
      result = await ref
          .read(teamImageServiceProvider)
          .pickAndSave(
            team,
            action == 'camera'
                ? TeamImageSource.camera
                : TeamImageSource.gallery,
          );
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.saved
                  ? 'Immagine del team aggiornata.'
                  : 'Operazione non riuscita.'),
        ),
      ),
    );
  }

  Future<void> _inviteTeam(
    BuildContext context,
    WidgetRef ref,
    Team team,
  ) async {
    if (!ref.read(cloudAuthProvider).profileLinked) {
      context.push('/auth');
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final cloudId = await ref
          .read(teamImageServiceProvider)
          .ensureCloudTeam(team);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showInviteShareSheet(
        context,
        ref,
        kind: 'TEAM_JOIN',
        teamId: cloudId,
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invito team non disponibile: $error')),
      );
    }
  }

  Future<void> _updateAppearance(
    BuildContext context,
    WidgetRef ref,
    Team team, {
    String? scoringStyle,
    int? colorArgb,
  }) async {
    await ref
        .read(teamRepoProvider)
        .updateAppearance(
          id: team.id,
          scoringStyle: scoringStyle,
          colorArgb: colorArgb,
        );
    final updated = await ref.read(teamRepoProvider).byId(team.id);
    if (updated == null) return;
    final error = await ref
        .read(teamCloudServiceProvider)
        .syncOwnedTeam(updated);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  double _decisiveRate(List<MatchSummary> matches) {
    final played = matches.fold(0, (a, m) => a + m.decisivePointsPlayed);
    if (played == 0) return 0.5;
    return matches.fold(0, (a, m) => a + m.decisivePointsWon) / played;
  }

  List<Widget> _byDifficulty(List<MatchSummary> matches) {
    final byDiff = <int, List<MatchSummary>>{};
    for (final m in matches) {
      byDiff.putIfAbsent(m.opponentDifficulty.score, () => []).add(m);
    }
    final keys = byDiff.keys.toList()..sort();
    return [
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  'Difficoltà $k/5',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value:
                        byDiff[k]!.where((m) => m.won).length /
                        byDiff[k]!.length,
                    minHeight: 9,
                    backgroundColor: Colors.white10,
                    color: RallyColors.lime,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '  ${byDiff[k]!.where((m) => m.won).length}/${byDiff[k]!.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  String _roleLabel(String wire) => switch (wire) {
    'LEFT' => 'sinistra',
    'RIGHT' => 'destra',
    'FLEX' => 'flex',
    _ => 'da definire',
  };
}

class _TeamIdentityCard extends StatelessWidget {
  const _TeamIdentityCard({
    required this.team,
    required this.canManage,
    required this.onImage,
    required this.onInvite,
    required this.onStyle,
    required this.onColor,
  });

  final Team team;
  final bool canManage;
  final VoidCallback onImage;
  final VoidCallback onInvite;
  final ValueChanged<String> onStyle;
  final ValueChanged<int> onColor;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  TeamAvatar(team: team, size: 78, heroTag: 'team-${team.id}'),
                  if (canManage)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: IconButton.filled(
                        onPressed: onImage,
                        icon: const Icon(Icons.photo_camera_outlined, size: 17),
                        tooltip: 'Modifica immagine team',
                        style: IconButton.styleFrom(
                          backgroundColor: RallyColors.lime,
                          foregroundColor: RallyColors.night,
                          minimumSize: const Size.square(36),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.playerBName.isEmpty
                          ? 'Aggiungi un compagno quando crei la partita'
                          : 'Con ${team.playerBName}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (canManage)
            OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invita nel team'),
            )
          else
            const Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: RallyColors.win),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sei membro del team. Immagine e stile sono gestiti dal proprietario.',
                    style: TextStyle(fontSize: 12.5, color: Colors.white60),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          const Text(
            'ASPETTO PULSANTI PUNTEGGIO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'AUTO',
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Auto'),
              ),
              ButtonSegment(
                value: 'COLOR',
                icon: Icon(Icons.palette_outlined),
                label: Text('Colore'),
              ),
              ButtonSegment(
                value: 'IMAGE',
                icon: Icon(Icons.image_outlined),
                label: Text('Foto'),
              ),
            ],
            selected: {team.scoringStyle},
            onSelectionChanged: canManage
                ? (values) => onStyle(values.first)
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Auto usa la foto quando disponibile e applica un overlay ad alto contrasto.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          const Text(
            'COLORE TEAM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in const [
                0xFFC8F135,
                0xFF32D6C8,
                0xFF5DA9FF,
                0xFFFFB44A,
                0xFFFF6F7D,
              ])
                Semantics(
                  button: true,
                  selected: team.colorArgb == color,
                  label: 'Scegli colore team',
                  child: InkWell(
                    onTap: canManage ? () => onColor(color) : null,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(color),
                        border: Border.all(
                          color: team.colorArgb == color
                              ? Colors.white
                              : Colors.white24,
                          width: team.colorArgb == color ? 3 : 1,
                        ),
                      ),
                      child: team.colorArgb == color
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: RallyColors.night,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
