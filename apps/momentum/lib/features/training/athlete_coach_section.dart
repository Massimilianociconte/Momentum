/// Sezione "Il tuo coach" negli Allenamenti (PRD I4, lato atleta):
/// collegamento con codice coach, schede ricevute, log sessioni e feedback.
///
/// Gratis per l'atleta: il valore in-app monetizza il piano Coach di chi
/// assegna (PRD I4 anti-bypass), non chi si allena.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories/repositories.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/coach_athletes_service.dart';

final myCoachesProvider = FutureProvider.autoDispose(
  (ref) => CoachAthletesService.myCoaches(),
);

final myAssignmentsProvider = FutureProvider.autoDispose(
  (ref) => CoachAthletesService.myAssignments(),
);

class AthleteCoachSection extends ConsumerWidget {
  const AthleteCoachSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(cloudAuthProvider).profileLinked;
    if (!signedIn) return const SizedBox.shrink();

    final coaches = ref.watch(myCoachesProvider);
    final assignments = ref.watch(myAssignmentsProvider);

    return SectionCard(
      title: 'IL TUO COACH',
      trailing: IconButton(
        tooltip: 'Collega un coach',
        icon: const Icon(Icons.person_add_alt, size: 18),
        onPressed: () => _joinDialog(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          coaches.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (list) => list.isEmpty
                ? const Text(
                    'Hai un coach? Fatti dare il suo codice Momentum e '
                    'ricevi schede e feedback direttamente qui.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white60,
                      height: 1.35,
                    ),
                  )
                : Column(
                    children: [
                      for (final c in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: RallyColors.surfaceHigh,
                                foregroundImage: c.avatarUrl?.isNotEmpty == true
                                    ? NetworkImage(c.avatarUrl!)
                                    : null,
                                child: Text(
                                  c.displayName.isNotEmpty
                                      ? c.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${c.displayName}'
                                  '${c.club.isNotEmpty ? ' · ${c.club}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (c.verified)
                                const Icon(
                                  Icons.verified,
                                  size: 15,
                                  color: RallyColors.lime,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          assignments.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (list) {
              final active = list
                  .where((a) => a.status != 'COMPLETED')
                  .toList();
              final done = list.where((a) => a.status == 'COMPLETED').length;
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  for (final a in active)
                    _AthleteAssignmentTile(
                      assignment: a,
                      onLogged: () {
                        ref.invalidate(myAssignmentsProvider);
                        // La sessione entra anche nel carico settimanale.
                        ref.invalidate(trainingLogsProvider);
                      },
                    ),
                  if (done > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$done sched${done == 1 ? 'a completata' : 'e completate'} 💪',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _joinDialog(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collega il tuo coach'),
        content: TextField(
          controller: code,
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Codice coach (8 caratteri)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Collega'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await CoachAthletesService.joinCoach(code.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Coach collegato! Le schede arrivano qui.'
              : result.error!,
        ),
      ),
    );
    if (result.ok) {
      ref.invalidate(myCoachesProvider);
      ref.invalidate(myAssignmentsProvider);
    }
  }
}

class _AthleteAssignmentTile extends ConsumerWidget {
  const _AthleteAssignmentTile({
    required this.assignment,
    required this.onLogged,
  });

  final CoachAssignment assignment;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = assignment;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (a.notes.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                a.notes,
                style: const TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
            ],
            if (a.drills.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final d in a.drills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• ${d['minutes'] ?? 10}\' ${d['name'] ?? ''}'
                    '${(d['note'] as String?)?.isNotEmpty == true ? ' — ${d['note']}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: a.completion,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      color: RallyColors.lime,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${a.sessionsDone}/${a.sessionsTarget}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (a.feedback.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Coach: ${a.feedback}',
                style: const TextStyle(
                  fontSize: 12,
                  color: RallyColors.lime,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _logSession(context, ref),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Sessione fatta'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logSession(BuildContext context, WidgetRef ref) async {
    final minutes = TextEditingController(
      text:
          '${assignment.drills.fold<int>(0, (s, d) => s + ((d['minutes'] as num?)?.toInt() ?? 10))}',
    );
    final note = TextEditingController();
    var rpe = 6.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Registra sessione'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Minuti'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Nota per il coach (opzionale)',
                ),
              ),
              const SizedBox(height: 6),
              // RPE: la sessione coach alimenta il carico settimanale (ACWR)
              // come ogni altro allenamento.
              Row(
                children: [
                  const Text('Sforzo', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: rpe,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: 'RPE ${rpe.round()}',
                      onChanged: (v) => setLocal(() => rpe = v),
                    ),
                  ),
                  Text(
                    '${rpe.round()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: RallyColors.lime,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final parsedMinutes = int.tryParse(minutes.text) ?? 30;
    final error = await CoachAthletesService.logAssignmentSession(
      assignment: assignment,
      minutes: parsedMinutes,
      note: note.text,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Doppia scrittura voluta: cloud per il coach, log locale per il carico
    // settimanale dell'atleta (template nascosto, FK su Trainings).
    final trainingRepo = ref.read(trainingRepoProvider);
    await trainingRepo.ensureCoachAssignedTemplate();
    await trainingRepo.logCompletion(
      TrainingRepository.coachAssignedTrainingId,
      notes: assignment.title,
      rpe: rpe.round(),
      minutes: parsedMinutes,
    );
    onLogged();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessione registrata. Il coach la vede!')),
    );
  }
}
