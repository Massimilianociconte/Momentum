/// Allenamenti (PRD Modulo H): template free + programmi premium per ruolo,
/// focus settimanale guidato dai dati partita, carico allenamento (RPE/ACWR)
/// e sessioni guidate con timer per gli utenti premium.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/mascot_3d.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';
import '../../core/padelandia_video_player.dart';
import '../../core/training_videos.dart';
import '../../domain/entitlements.dart';
import '../../domain/training_insights.dart';
import 'athlete_coach_section.dart';
import 'training_session_sheet.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainings = ref.watch(trainingsProvider);
    final logs = ref.watch(trainingLogsProvider).value ?? const [];
    final summaries = ref.watch(summariesProvider).value ?? const [];
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Allenamenti')),
      body: trainings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) {
          // Il template di servizio dei log coach non è un allenamento
          // proponibile: resta fuori da tutte le liste.
          final visible = list
              .where((t) => t.id != TrainingRepository.coachAssignedTrainingId)
              .toList();
          final free = visible.where((t) => !t.premium).toList();
          final premium = visible.where((t) => t.premium).toList();
          final plan = recommendFocus(summaries);
          final byId = {for (final t in list) t.id: t};
          final suggested = plan.suggestedTrainingIds
              .map((id) => byId[id])
              .whereType<Training>()
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _TrainingDashboard(
                plan: plan,
                logs: logs,
                premiumUnlocked: ents.premiumTraining,
                llmUnlocked: ents.llmAssistant,
              ),
              const SizedBox(height: 12),
              _LoadCard(logs: logs),
              const SizedBox(height: 12),
              // PRD I4 lato atleta: schede dal coach collegato.
              const AthleteCoachSection(),
              const SizedBox(height: 12),
              if (suggested.isNotEmpty) ...[
                const Text(
                  'CONSIGLIATI PER IL TUO FOCUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: RallyColors.lime,
                  ),
                ),
                const SizedBox(height: 8),
                for (final t in suggested)
                  _tile(
                    context,
                    ref,
                    t,
                    unlocked: !t.premium || ents.premiumTraining,
                    guided: ents.premiumTraining,
                    highlighted: true,
                  ),
                const SizedBox(height: 16),
              ],
              const Text(
                'BASE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 8),
              for (final t in free)
                _tile(
                  context,
                  ref,
                  t,
                  unlocked: true,
                  guided: ents.premiumTraining,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!ents.premiumTraining)
                    const Icon(Icons.lock, size: 14, color: RallyColors.lime),
                ],
              ),
              const SizedBox(height: 8),
              for (final t in premium)
                _tile(
                  context,
                  ref,
                  t,
                  unlocked: ents.premiumTraining,
                  guided: ents.premiumTraining,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    Training t, {
    required bool unlocked,
    required bool guided,
    bool highlighted = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: RallyColors.lime.withValues(alpha: 0.4)),
            )
          : null,
      child: ListTile(
        onTap: () => unlocked
            ? _open(context, ref, t, guided: guided)
            : pushPaywall(
                context,
                plan: Plan.plus,
                reason: 'Allenamenti premium e routine complete con Plus.',
                returnTo: '/training',
              ),
        leading: CircleAvatar(
          backgroundColor: RallyColors.surfaceHigh,
          child: Icon(
            unlocked ? Icons.fitness_center : Icons.lock,
            color: unlocked ? RallyColors.teamThem : RallyColors.lime,
            size: 20,
          ),
        ),
        title: Text(
          t.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${t.durationMinutes} min'
          '${t.role != 'UNDEFINED' ? ' · ${_roleLabel(t.role)}' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    Training t, {
    required bool guided,
  }) {
    final drills = drillsOf(t);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RallyColors.night,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (t.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t.description,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  if (drills.isEmpty) return const SizedBox.shrink();
                  final preview = trainingVideoForDrill(drills.first.name);
                  if (preview == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PadelandiaVideoPlayer(
                      assetPath: preview,
                      maxHeight: 220,
                      autoPlay: false,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              for (final d in drills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: RallyColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${d.minutes}'",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: RallyColors.lime,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              d.note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (guided) ...[
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await showGuidedSession(context, ref, t);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Avvia sessione guidata'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await logTrainingDone(
                      context,
                      ref,
                      t,
                      minutes: t.durationMinutes,
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Segna come completato'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await logTrainingDone(
                      context,
                      ref,
                      t,
                      minutes: t.durationMinutes,
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Segna come completato'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String wire) => switch (wire) {
    'LEFT' => 'sinistra',
    'RIGHT' => 'destra',
    'FLEX' => 'flex',
    _ => '',
  };
}

/// Carico settimanale: sessioni, minuti, streak, RPE medio e zona ACWR.
class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.logs});

  final List<TrainingLog> logs;

  @override
  Widget build(BuildContext context) {
    final load = TrainingLoad.compute(DateTime.now(), logs);
    final zoneColor = switch (load.zone) {
      'optimal' => RallyColors.win,
      'high' => RallyColors.lime,
      'danger' => RallyColors.loss,
      _ => Colors.white54,
    };

    return SectionCard(
      title: 'CARICO ALLENAMENTO',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: zoneColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          load.zoneLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: zoneColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatTile(
                label: 'sessioni sett.',
                value: '${load.sessionsThisWeek}',
              ),
              StatTile(label: 'minuti sett.', value: '${load.minutesThisWeek}'),
              StatTile(
                label: 'streak giorni',
                value: '${load.streakDays}',
                color: load.streakDays >= 3 ? RallyColors.win : null,
              ),
              StatTile(
                label: 'RPE medio 7g',
                value: load.avgRpe7d == 0
                    ? '—'
                    : load.avgRpe7d.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            load.zoneAdvice,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingDashboard extends StatelessWidget {
  const _TrainingDashboard({
    required this.plan,
    required this.logs,
    required this.premiumUnlocked,
    required this.llmUnlocked,
  });

  final TrainingFocusPlan plan;
  final List<TrainingLog> logs;
  final bool premiumUnlocked;
  final bool llmUnlocked;

  @override
  Widget build(BuildContext context) {
    final completedThisWeek = _completedThisWeek();
    final weeklyGoal = premiumUnlocked ? 4 : 2;
    final progress = (completedThisWeek / weeklyGoal).clamp(0.0, 1.0);

    return SectionCard(
      title: 'COACH TRAINING',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Mascot3d(
                kind: Mascot3dKind.tip,
                size: 58,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    color: progress >= 1 ? RallyColors.win : RallyColors.lime,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedThisWeek/$weeklyGoal',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Obiettivo settimanale · ${plan.microGoal}',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FocusChip(icon: Icons.flag_outlined, label: plan.focus),
              _FocusChip(icon: Icons.query_stats, label: plan.metric),
              _FocusChip(
                icon: premiumUnlocked ? Icons.lock_open : Icons.lock_outline,
                label: premiumUnlocked ? 'programma completo' : 'base free',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pallino LLM requires Pro (`llmAssistant`), not only Plus training.
          if (llmUnlocked)
            FilledButton.icon(
              onPressed: () => context.push(
                Uri(
                  path: '/pro-chat',
                  queryParameters: {
                    'mode': 'TRAINING',
                    'q': 'Preparami una routine pratica per questa settimana.',
                    'ctx':
                        'Focus consigliato: ${plan.focus}. '
                        'Metrica chiave: ${plan.metric}. '
                        'Obiettivo: ${plan.microGoal}.',
                  },
                ).toString(),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: Text('Chiedi a ${AppBrand.assistantName}'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => pushPaywall(
                context,
                gate: llmUnlocked ? null : 'llm_assistant',
                plan: premiumUnlocked ? Plan.pro : Plan.plus,
                reason: premiumUnlocked
                    ? gates['llm_assistant']!.pitch
                    : 'Allenamenti premium e routine complete con Plus.',
                returnTo: '/training',
              ),
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: Text(
                premiumUnlocked
                    ? 'Routine AI con Pro (Pallino)'
                    : 'Sblocca routine personalizzate',
              ),
            ),
        ],
      ),
    );
  }

  int _completedThisWeek() {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startMs = weekStart.millisecondsSinceEpoch;
    return logs.where((l) => l.completed && l.dateMs >= startMs).length;
  }
}

class _FocusChip extends StatelessWidget {
  const _FocusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RallyColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: RallyColors.lime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
