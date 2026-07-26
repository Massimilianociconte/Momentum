/// Profilo coach pubblico (PRD I1): bio, club, certificazioni,
/// specializzazioni, badge verified, rating e pacchetti attivi.
///
/// La stessa schermata serve la vista pubblica (da marketplace) e, per il
/// coach proprietario, l'accesso all'editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/coach_athletes_service.dart';

final coachPublicProfileProvider = FutureProvider.autoDispose
    .family<CoachPublicProfile?, String>(
      (ref, coachId) => CoachAthletesService.publicProfile(coachId),
    );

class CoachProfileScreen extends ConsumerWidget {
  const CoachProfileScreen({super.key, required this.coachId});

  final String coachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(coachPublicProfileProvider(coachId));
    final isMe = CoachAthletesService.currentUserId == coachId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo coach'),
        actions: [
          if (isMe)
            IconButton(
              tooltip: 'Modifica profilo',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await showCoachProfileEditor(
                  context,
                  profile.valueOrNull,
                );
                if (saved == true) {
                  ref.invalidate(coachPublicProfileProvider(coachId));
                }
              },
            ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (p) {
          if (p == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyStateCard(
                  icon: Icons.sports,
                  title: 'Profilo non disponibile',
                  message: isMe
                      ? 'Crea il tuo profilo pubblico: bio, club, '
                            'certificazioni e specializzazioni.'
                      : 'Questo coach non ha ancora un profilo pubblico.',
                  primaryLabel: isMe ? 'Crea profilo' : 'Aggiorna',
                  primaryIcon: isMe ? Icons.add : Icons.refresh,
                  onPrimary: () async {
                    if (isMe) {
                      final saved = await showCoachProfileEditor(context, null);
                      if (saved == true) {
                        ref.invalidate(coachPublicProfileProvider(coachId));
                      }
                    } else {
                      ref.invalidate(coachPublicProfileProvider(coachId));
                    }
                  },
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: RallyColors.surfaceHigh,
                    foregroundImage:
                        p.avatarUrl != null && p.avatarUrl!.startsWith('http')
                        ? NetworkImage(p.avatarUrl!)
                        : null,
                    child: Text(
                      p.displayName.isNotEmpty
                          ? p.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (p.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                size: 18,
                                color: RallyColors.lime,
                              ),
                            ],
                          ],
                        ),
                        if (p.club.isNotEmpty)
                          Text(
                            p.club,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white60,
                            ),
                          ),
                        if (p.ratingCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: RallyColors.lime,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${p.ratingAvg.toStringAsFixed(1)} '
                                  '(${p.ratingCount})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Condividi profilo',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Coach ${p.displayName} su Padelandia'
                            '${p.club.isNotEmpty ? ' · ${p.club}' : ''} — '
                            'programmi e lezioni di padel.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (p.bio.isNotEmpty) ...[
                SectionCard(
                  title: 'BIO',
                  child: Text(
                    p.bio,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (p.certifications.isNotEmpty) ...[
                SectionCard(
                  title: 'CERTIFICAZIONI',
                  child: _chips(p.certifications, Icons.workspace_premium),
                ),
                const SizedBox(height: 12),
              ],
              if (p.specializations.isNotEmpty) ...[
                SectionCard(
                  title: 'SPECIALIZZAZIONI',
                  child: _chips(p.specializations, Icons.sports_tennis),
                ),
                const SizedBox(height: 12),
              ],
              SectionCard(
                title: 'PACCHETTI ATTIVI',
                child: p.packages.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nessun pacchetto attivo al momento.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Column(
                        children: [
                          for (final pkg in p.packages)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                pkg['title'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                pkg['description'] as String? ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                              trailing: Text(
                                '${(((pkg['priceCents'] as num?) ?? 0) / 100).toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: RallyColors.lime,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chips(List<String> items, IconData icon) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: RallyColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: RallyColors.lime),
                const SizedBox(width: 6),
                Text(
                  item,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Editor del profilo coach (bio, club, certificazioni, specializzazioni).
/// Ritorna true se salvato.
Future<bool?> showCoachProfileEditor(
  BuildContext context,
  CoachPublicProfile? current,
) {
  final bio = TextEditingController(text: current?.bio ?? '');
  final club = TextEditingController(text: current?.club ?? '');
  final certifications = TextEditingController(
    text: current?.certifications.join(', ') ?? '',
  );
  final specializations = TextEditingController(
    text: current?.specializations.join(', ') ?? '',
  );

  List<String> parseList(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .take(10)
      .toList();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RallyColors.night,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profilo coach pubblico',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visibile a tutti nel marketplace (PRD I1).',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: bio,
            maxLines: 3,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Bio (esperienza, metodo)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: club,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Club',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: certifications,
            decoration: const InputDecoration(
              labelText: 'Certificazioni (separate da virgola)',
              hintText: 'es. FIP Base, FIP Avanzato',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: specializations,
            decoration: const InputDecoration(
              labelText: 'Specializzazioni (separate da virgola)',
              hintText: 'es. bandeja, gioco di coppia, preparazione torneo',
            ),
          ),
          const SizedBox(height: 16),
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
                  final error = await CoachAthletesService.updateMyProfile(
                    bio: bio.text,
                    club: club.text,
                    certifications: parseList(certifications.text),
                    specializations: parseList(specializations.text),
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
                child: const Text('Salva'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
