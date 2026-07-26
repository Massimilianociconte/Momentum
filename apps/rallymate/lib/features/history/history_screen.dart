/// Storico partite locale (free, PRD 5.1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/team_visuals.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all'; // all | won | lost

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(historyMatchesProvider);
    final teams = ref.watch(teamsProvider).value ?? const <Team>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Storico partite')),
      body: matches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateCard(
          message: 'Impossibile caricare lo storico.',
          detail: '$e',
          onRetry: () => ref.invalidate(historyMatchesProvider),
        ),
        data: (rows) {
          final allCompleted =
              rows.where((r) => r.status == 'COMPLETED').toList();
          final completed = allCompleted.where((r) {
            if (_filter == 'won') return r.wonByUs == true;
            if (_filter == 'lost') return r.wonByUs == false;
            return true;
          }).toList();

          // Zero history: conversion surface only (no useless filter chrome).
          if (allCompleted.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyStateCard(
                  icon: Icons.sports_tennis,
                  title: 'Nessuna partita salvata',
                  message:
                      'Registra la prima partita per costruire '
                      'storico, trend, win rate e riepiloghi.',
                  primaryLabel: 'Nuova partita',
                  primaryIcon: Icons.play_arrow,
                  onPrimary: () => context.push('/match/new'),
                  secondaryLabel: 'Vai agli allenamenti',
                  secondaryIcon: Icons.fitness_center,
                  onSecondary: () => context.go('/training'),
                ),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Tutte')),
                    ButtonSegment(value: 'won', label: Text('Vinte')),
                    ButtonSegment(value: 'lost', label: Text('Perse')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: completed.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          EmptyStateCard(
                            icon: Icons.filter_alt_off_outlined,
                            title: _filter == 'won'
                                ? 'Nessuna vittoria ancora'
                                : 'Nessuna sconfitta registrata',
                            message:
                                'Cambia filtro o registra una nuova partita.',
                            primaryLabel: 'Nuova partita',
                            primaryIcon: Icons.play_arrow,
                            onPrimary: () => context.push('/match/new'),
                            secondaryLabel: 'Mostra tutte',
                            secondaryIcon: Icons.list_alt,
                            onSecondary: () =>
                                setState(() => _filter = 'all'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: completed.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final row = completed[i];
                          final s = MatchRepository.summaryOf(row);
                          final won = row.wonByUs ?? false;
                          final team = row.teamId == null
                              ? null
                              : teams
                                    .where((item) => item.id == row.teamId)
                                    .firstOrNull;
                          return Card(
                            child: ListTile(
                              onTap: () => context.push('/match/${row.id}'),
                              leading: team == null
                                  ? _ResultAvatar(won: won)
                                  : _TeamResultAvatar(team: team, won: won),
                              title: Text(
                                s == null
                                    ? '—'
                                    : '${s.setsFor}-${s.setsAgainst}'
                                          '${row.opponentLabel.isEmpty ? '' : '  vs ${row.opponentLabel}'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  formatDate(row.startTimeMs ?? 0),
                                  if (s != null)
                                    '${s.pointsFor}-${s.pointsAgainst} punti',
                                  if (row.location.isNotEmpty) row.location,
                                  if (row.duoMode) '⌚⌚ Duo',
                                ].join(' · '),
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
            ],
          );
        },
      ),
    );
  }
}

class _ResultAvatar extends StatelessWidget {
  const _ResultAvatar({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: (won ? RallyColors.win : RallyColors.loss).withValues(
      alpha: 0.15,
    ),
    child: Text(
      won ? 'V' : 'S',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: won ? RallyColors.win : RallyColors.loss,
      ),
    ),
  );
}

class _TeamResultAvatar extends StatelessWidget {
  const _TeamResultAvatar({required this.team, required this.won});

  final Team team;
  final bool won;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      TeamAvatar(team: team, size: 46),
      Positioned(
        right: -3,
        bottom: -3,
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: won ? RallyColors.win : RallyColors.loss,
            border: Border.all(color: RallyColors.night, width: 2),
          ),
          child: Text(
            won ? 'V' : 'S',
            style: const TextStyle(
              color: RallyColors.night,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ],
  );
}
