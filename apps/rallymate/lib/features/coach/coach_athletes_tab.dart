/// Tab "Atleti" dell'area coach (PRD I4): codice di collegamento, roster,
/// assegnazione schede, tracking completamento, feedback e report condiviso.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/coach_athletes_service.dart';

final coachAthletesProvider = FutureProvider.autoDispose(
  (ref) => CoachAthletesService.athletes(),
);

final coachLinkCodeProvider = FutureProvider.autoDispose((ref) async {
  final result = await CoachAthletesService.myLinkCode();
  return result.ok ? result.data['code'] as String? : null;
});

final athleteAssignmentsProvider = FutureProvider.autoDispose
    .family<List<CoachAssignment>, String>(
      (ref, athleteId) =>
          CoachAthletesService.coachAssignments(athleteId: athleteId),
    );

class CoachAthletesTab extends ConsumerWidget {
  const CoachAthletesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(coachAthletesProvider);
    final code = ref.watch(coachLinkCodeProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(coachAthletesProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SectionCard(
            title: 'CODICE ATLETI',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Condividi questo codice con i tuoi allievi: lo inseriscono '
                  'in Allenamenti → "Il tuo coach" per collegarsi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white60,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                code.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => const Text(
                    'Codice non disponibile. Riprova.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  data: (value) => value == null
                      ? const Text(
                          'Codice non disponibile: verifica il piano Coach.',
                          style: TextStyle(color: Colors.white54),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 5,
                                  color: RallyColors.lime,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copia',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: value),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Codice copiato'),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Condividi',
                              icon: const Icon(Icons.ios_share, size: 18),
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Collegati a me su Padelandia! Apri '
                                      'Allenamenti → "Il tuo coach" e inserisci '
                                      'il codice: $value',
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          athletes.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => EmptyStateCard(
              icon: Icons.cloud_off,
              title: 'Atleti non raggiungibili',
              message: 'Controlla la connessione e riprova.',
              primaryLabel: 'Riprova',
              primaryIcon: Icons.refresh,
              onPrimary: () => ref.invalidate(coachAthletesProvider),
            ),
            data: (list) => list.isEmpty
                ? EmptyStateCard(
                    icon: Icons.group_add_outlined,
                    title: 'Nessun atleta collegato',
                    message:
                        'Condividi il codice qui sopra: appena un allievo lo '
                        'inserisce, lo vedrai in questa lista con schede e '
                        'progressi.',
                    primaryLabel: 'Aggiorna',
                    primaryIcon: Icons.refresh,
                    onPrimary: () => ref.invalidate(coachAthletesProvider),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _openAthleteSheet(context, ref, a),
                            leading: CircleAvatar(
                              backgroundColor: RallyColors.surfaceHigh,
                              foregroundImage:
                                  a.avatarUrl != null &&
                                      a.avatarUrl!.startsWith('http')
                                  ? NetworkImage(a.avatarUrl!)
                                  : null,
                              child: Text(
                                a.displayName.isNotEmpty
                                    ? a.displayName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              a.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${a.assignmentsCompleted}/${a.assignmentsTotal} '
                              'schede completate'
                              '${a.lastProgressAt != null ? ' · attivo '
                                        '${_ago(a.lastProgressAt!)}' : ''}',
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
        ],
      ),
    );
  }

  static String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inDays >= 7) return '${d.inDays ~/ 7} sett. fa';
    if (d.inDays >= 1) return '${d.inDays} g fa';
    if (d.inHours >= 1) return '${d.inHours} h fa';
    return 'ora';
  }

  void _openAthleteSheet(
    BuildContext context,
    WidgetRef ref,
    CoachAthlete athlete,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RallyColors.night,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) =>
            _AthleteDetailSheet(athlete: athlete, scrollController: scroll),
      ),
    );
  }
}

class _AthleteDetailSheet extends ConsumerWidget {
  const _AthleteDetailSheet({
    required this.athlete,
    required this.scrollController,
  });

  final CoachAthlete athlete;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(
      athleteAssignmentsProvider(athlete.athleteId),
    );
    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: RallyColors.surfaceHigh,
                foregroundImage:
                    athlete.avatarUrl != null &&
                        athlete.avatarUrl!.startsWith('http')
                    ? NetworkImage(athlete.avatarUrl!)
                    : null,
                child: Text(
                  athlete.displayName.isNotEmpty
                      ? athlete.displayName[0].toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      athlete.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_levelLabel(athlete.level)} · ${_roleLabel(athlete.role)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'report') {
                    await _shareReport(ref);
                  } else if (v == 'unlink') {
                    await _unlink(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Condividi report progressi'),
                  ),
                  PopupMenuItem(
                    value: 'unlink',
                    child: Text('Scollega atleta'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final assigned = await showAssignTrainingSheet(
                context,
                athlete.athleteId,
              );
              if (assigned == true) {
                ref.invalidate(athleteAssignmentsProvider(athlete.athleteId));
                ref.invalidate(coachAthletesProvider);
              }
            },
            icon: const Icon(Icons.assignment_add),
            label: const Text('Assegna nuova scheda'),
          ),
          const SizedBox(height: 16),
          const Text(
            'SCHEDE ASSEGNATE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          assignments.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text(
              'Errore: $e',
              style: const TextStyle(color: Colors.white54),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nessuna scheda ancora. Assegna la prima!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        _AssignmentCard(
                          assignment: a,
                          onFeedback: (text) async {
                            final error =
                                await CoachAthletesService.setAssignmentFeedback(
                                  assignmentId: a.assignmentId,
                                  feedback: text,
                                );
                            if (context.mounted && error != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                            ref.invalidate(
                              athleteAssignmentsProvider(athlete.athleteId),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReport(WidgetRef ref) async {
    // Report condiviso (I4): riassunto testuale dei progressi.
    final list = await CoachAthletesService.coachAssignments(
      athleteId: athlete.athleteId,
    );
    final completed = list.where((a) => a.status == 'COMPLETED').length;
    final sessions = list.fold<int>(0, (s, a) => s + a.sessionsDone);
    final minutes = list.fold<int>(0, (s, a) => s + a.minutesDone);
    final buffer = StringBuffer()
      ..writeln('Report progressi — ${athlete.displayName}')
      ..writeln('Schede: $completed/${list.length} completate')
      ..writeln('Sessioni svolte: $sessions · Minuti: $minutes')
      ..writeln();
    for (final a in list.take(8)) {
      buffer.writeln(
        '• ${a.title}: ${a.sessionsDone}/${a.sessionsTarget} sessioni '
        '(${_statusLabel(a.status)})',
      );
    }
    buffer.write('\nGenerato con Padelandia Coach');
    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final uid = CoachAthletesService.currentUserId;
    if (uid == null) return;
    final result = await CoachAthletesService.endLink(
      coachId: uid,
      athleteId: athlete.athleteId,
    );
    if (!context.mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    ref.invalidate(coachAthletesProvider);
    Navigator.pop(context);
  }

  static String _levelLabel(String wire) => switch (wire) {
    'BEGINNER' => 'Principiante',
    'INTERMEDIATE' => 'Intermedio',
    'ADVANCED' => 'Avanzato',
    'COMPETITIVE' => 'Agonista',
    _ => wire,
  };

  static String _roleLabel(String wire) => switch (wire) {
    'LEFT' => 'sinistra',
    'RIGHT' => 'destra',
    'FLEX' => 'flex',
    _ => 'ruolo libero',
  };

  static String _statusLabel(String status) => switch (status) {
    'ASSIGNED' => 'assegnata',
    'IN_PROGRESS' => 'in corso',
    'COMPLETED' => 'completata',
    'EXPIRED' => 'scaduta',
    _ => status,
  };
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, required this.onFeedback});

  final CoachAssignment assignment;
  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final statusColor = switch (a.status) {
      'COMPLETED' => RallyColors.win,
      'IN_PROGRESS' => RallyColors.lime,
      _ => Colors.white54,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _AthleteDetailSheet._statusLabel(a.status),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: a.completion,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: a.completion >= 1 ? RallyColors.win : RallyColors.lime,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${a.sessionsDone}/${a.sessionsTarget} sessioni · '
              '${a.minutesDone} min',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            if (a.athleteNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Nota atleta: ${a.athleteNote}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (a.feedback.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Tuo feedback: ${a.feedback}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: RallyColors.lime,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final controller = TextEditingController(text: a.feedback);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Feedback per l\'atleta'),
                        content: TextField(
                          controller: controller,
                          maxLines: 3,
                          maxLength: 280,
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Invia'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onFeedback(controller.text);
                  },
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(a.feedback.isEmpty ? 'Feedback' : 'Modifica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet di assegnazione scheda (I4): titolo, note, sessioni target, drills.
/// Ritorna true se assegnata.
Future<bool?> showAssignTrainingSheet(BuildContext context, String athleteId) {
  final title = TextEditingController();
  final notes = TextEditingController();
  final drills = TextEditingController();
  var sessions = 4;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RallyColors.night,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuova scheda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Titolo (es. Settimana bandeja + chiusura)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 2,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Note per l\'atleta',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: drills,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Esercizi (uno per riga: "minuti nome — nota")',
                  hintText:
                      '10 Bandeja diagonale — controllo profondità\n'
                      '15 Chiusura a rete — volée decisa',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Sessioni richieste:'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: sessions > 1
                        ? () => setLocal(() => sessions--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$sessions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: sessions < 30
                        ? () => setLocal(() => sessions++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (title.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Dai un titolo alla scheda.'),
                          ),
                        );
                        return;
                      }
                      final parsedDrills = <Map<String, dynamic>>[];
                      for (final line in drills.text.split('\n')) {
                        final trimmed = line.trim();
                        if (trimmed.isEmpty) continue;
                        final match = RegExp(
                          r'^(\d{1,3})\s+(.+)$',
                        ).firstMatch(trimmed);
                        final minutes = int.tryParse(match?.group(1) ?? '');
                        final rest = match?.group(2) ?? trimmed;
                        final parts = rest.split('—');
                        parsedDrills.add({
                          'minutes': minutes ?? 10,
                          'name': parts.first.trim(),
                          if (parts.length > 1) 'note': parts[1].trim(),
                        });
                      }
                      final error = await CoachAthletesService.assignTraining(
                        athleteId: athleteId,
                        title: title.text,
                        notes: notes.text,
                        sessionsTarget: sessions,
                        drills: parsedDrills,
                      );
                      if (!ctx.mounted) return;
                      if (error != null) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Assegna'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
