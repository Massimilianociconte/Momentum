/// Area Coach + marketplace (PRD Modulo I, acceptance criteria Coach).
///
/// - Piano Coach: crea/gestisce pacchetti (commissione calcolata e mostrata
///   in chiaro, PRD I3).
/// - Tutti: catalogo pacchetti attivi. L'acquisto resta nascosto finche
///   prodotti IAP e verifica ricevuta server-side non sono configurati.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import 'coach_athletes_tab.dart';

final marketplaceProvider = FutureProvider.autoDispose(
  (ref) => CoachService.marketplace(),
);
final myPackagesProvider = FutureProvider.autoDispose(
  (ref) => CoachService.myPackages(),
);

class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ents = ref.watch(entitlementsProvider);
    final auth = ref.watch(cloudAuthProvider);

    if (!CloudConfig.supabaseConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coach')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Il marketplace coach è temporaneamente non disponibile. '
              'Riprova più tardi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: ents.coachTools ? 3 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coach'),
          actions: [
            if (ents.coachTools && CoachService.currentUserId != null)
              IconButton(
                tooltip: 'Il mio profilo pubblico',
                icon: const Icon(Icons.badge_outlined),
                onPressed: () => context.push(
                  '/coach/profile/${CoachService.currentUserId}',
                ),
              ),
          ],
          bottom: TabBar(
            indicatorColor: RallyColors.lime,
            isScrollable: ents.coachTools,
            tabs: [
              const Tab(text: 'Marketplace'),
              if (ents.coachTools) const Tab(text: 'I miei pacchetti'),
              if (ents.coachTools) const Tab(text: 'Atleti'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Marketplace(signedIn: auth.signedIn),
            if (ents.coachTools) const _MyPackages(),
            if (ents.coachTools) const CoachAthletesTab(),
          ],
        ),
      ),
    );
  }
}

class _Marketplace extends ConsumerWidget {
  const _Marketplace({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(marketplaceProvider);
    return packages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'Nessun pacchetto disponibile al momento.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PackageCard(
            pkg: list[i],
            isMine: list[i].coachId == CoachService.currentUserId,
            unavailableLabel: signedIn
                ? 'Acquisto non ancora disponibile'
                : 'Accedi per salvare il pacchetto',
          ),
        );
      },
    );
  }
}

class _MyPackages extends ConsumerWidget {
  const _MyPackages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(myPackagesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo pacchetto'),
      ),
      body: packages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text(
                  'Crea il tuo primo pacchetto:\nprogrammi, schede, '
                  'lezioni 1:1.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.5),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _PackageCard(pkg: list[i], isMine: true),
              ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController(text: '49.00');
    var type = 'DIGITAL_PROGRAM';

    const typeLabels = {
      'DIGITAL_PROGRAM': 'Programma digitale',
      'WEEKLY_PLAN': 'Scheda settimanale',
      'MONTHLY_PLAN': 'Piano mensile',
      'PROGRESS_REVIEW': 'Revisione progressi',
      'PAIR_COACHING': 'Coaching di coppia',
      'TOURNAMENT_PREP': 'Preparazione torneo',
      'LIVE_1TO1': 'Lezione live 1:1',
      'GROUP_LESSON': 'Lezione di gruppo',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cents =
              ((double.tryParse(price.text.replaceAll(',', '.')) ?? 0) * 100)
                  .round();
          final rate = CoachService.commissionFor(type);
          return AlertDialog(
            title: const Text('Nuovo pacchetto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: [
                      for (final e in typeLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setLocal(() => type = v!),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Prezzo (€)'),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  // Trasparenza commissione (PRD I3).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Commissione ${(rate * 100).round()}%: '
                      '-${(cents * rate / 100).toStringAsFixed(2)} € · '
                      'Ricevi ${((cents * (1 - rate)) / 100).toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
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
                child: const Text('Pubblica'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final cents =
        ((double.tryParse(price.text.replaceAll(',', '.')) ?? 0) * 100).round();
    final error = await CoachService.createPackage(
      title: title.text.trim(),
      description: description.text.trim(),
      type: type,
      priceCents: cents,
    );
    ref.invalidate(myPackagesProvider);
    ref.invalidate(marketplaceProvider);
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.pkg,
    this.isMine = false,
    this.unavailableLabel = 'Non disponibile',
  });
  final CoachPackage pkg;
  final bool isMine;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      // I1: dal pacchetto si apre il profilo pubblico del coach.
      onTap: isMine
          ? null
          : () => context.push('/coach/profile/${pkg.coachId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pkg.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${pkg.priceEur.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: RallyColors.lime,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (pkg.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pkg.description,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Chip(label: Text(_typeLabel(pkg.type))),
              const Spacer(),
              if (isMine)
                Text(
                  'Ricevi ${((pkg.priceCents - pkg.commissionCents) / 100).toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                )
              else
                Flexible(
                  child: Text(
                    unavailableLabel,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white38,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
    'DIGITAL_PROGRAM' => 'Programma',
    'WEEKLY_PLAN' => 'Scheda settimanale',
    'MONTHLY_PLAN' => 'Piano mensile',
    'PROGRESS_REVIEW' => 'Revisione',
    'PAIR_COACHING' => 'Coppia',
    'TOURNAMENT_PREP' => 'Torneo',
    'LIVE_1TO1' => '1:1 live',
    'GROUP_LESSON' => 'Gruppo',
    'ACADEMY' => 'Academy',
    _ => t,
  };
}
