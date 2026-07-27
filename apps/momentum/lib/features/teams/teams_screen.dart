/// Profili team (PRD A2): lista + creazione, limite 3 in free.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/navigation_targets.dart';
import '../../core/paywall_nav.dart';
import '../../core/providers.dart';
import '../../core/team_visuals.dart';
import '../../core/widgets.dart';
import '../../domain/entitlements.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider);
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei team'),
        leading: const SafeBackButton(fallback: AppLocations.home),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final count = (teams.value ?? const []).length;
          if (count >= ents.maxTeams) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Piano Free: massimo ${Entitlements.freeMaxTeams} team. '
                  'Passa a Plus per team illimitati.',
                ),
                action: SnackBarAction(
                  label: 'Plus',
                  onPressed: () => pushPaywall(
                    context,
                    plan: Plan.plus,
                    reason:
                        'Team illimitati, backup e analytics di coppia con Plus.',
                    returnTo: '/teams',
                  ),
                ),
              ),
            );
            return;
          }
          await _createDialog(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo team'),
      ),
      body: teams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  EmptyStateCard(
                    icon: Icons.groups_outlined,
                    title: 'Crea il tuo primo team',
                    message:
                        'Salva il compagno abituale, il lato preferito '
                        'e prepara le analytics di coppia per i prossimi match.',
                    primaryLabel: 'Nuovo team',
                    primaryIcon: Icons.add,
                    onPrimary: () => _createDialog(context, ref),
                    secondaryLabel: 'Inizia una partita',
                    secondaryIcon: Icons.sports_tennis,
                    onSecondary: () => context.push('/match/new'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = list[i];
                  return Card(
                    child: ListTile(
                      onTap: () => context.push('/teams/${t.id}'),
                      leading: TeamAvatar(
                        team: t,
                        size: 46,
                        heroTag: 'team-${t.id}',
                      ),
                      title: Text(
                        t.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: t.playerBName.isEmpty
                          ? null
                          : Text(
                              'con ${t.playerBName}',
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
                  );
                },
              ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final partner = TextEditingController();
    PadelRole myRole = PadelRole.undefined;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo team'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome team (es. Io + Luca)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: partner,
                decoration: const InputDecoration(labelText: 'Compagno'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<PadelRole>(
                segments: const [
                  ButtonSegment(value: PadelRole.left, label: Text('Io a SX')),
                  ButtonSegment(value: PadelRole.right, label: Text('Io a DX')),
                  ButtonSegment(value: PadelRole.flex, label: Text('Flex')),
                ],
                emptySelectionAllowed: true,
                selected: myRole == PadelRole.undefined ? {} : {myRole},
                onSelectionChanged: (s) => setLocal(
                  () => myRole = s.isEmpty ? PadelRole.undefined : s.first,
                ),
              ),
            ],
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
    final me = await ref.read(playerRepoProvider).me();
    if (me == null) return;
    final partnerTrim = partner.text.trim();
    final nameTrim = name.text.trim();
    if (nameTrim.isEmpty && partnerTrim.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inserisci un nome team o un compagno.'),
          ),
        );
      }
      return;
    }
    final p = partnerTrim.isEmpty
        ? null
        : await ref.read(playerRepoProvider).ensurePartner(partnerTrim);
    final created = await ref
        .read(teamRepoProvider)
        .create(
          name: nameTrim.isEmpty ? 'Io + $partnerTrim' : nameTrim,
          playerAId: me.id,
          playerBId: p?.id,
          playerBName: p?.name ?? '',
          roleA: myRole,
          roleB: switch (myRole) {
            PadelRole.left => PadelRole.right,
            PadelRole.right => PadelRole.left,
            _ => PadelRole.undefined,
          },
        );
    ref.invalidate(teamsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Team "${created.name}" creato.')),
    );
    // Immediate success path: open detail to invite / play.
    context.push('/teams/${created.id}');
  }
}
