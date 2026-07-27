/// Rules Assistant (PRD Modulo E): mascotte Pallino + FAQ locale gratis,
/// teaser Pallino Assistant (LLM) per il piano Pro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/brand.dart';
import '../../core/mascot_3d.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../services/cloud/cloud_config.dart';

class RulesAssistantScreen extends StatelessWidget {
  const RulesAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${AppBrand.assistantName} · Regole')),
      body: const RulesAssistantSheet(),
    );
  }
}

class RulesAssistantSheet extends ConsumerStatefulWidget {
  const RulesAssistantSheet({
    super.key,
    this.scrollController,
    this.matchId,
    this.matchContext,
  });

  final ScrollController? scrollController;

  /// Se aperto durante una partita live: contesto per Pallino.
  final String? matchId;
  final String? matchContext;

  @override
  ConsumerState<RulesAssistantSheet> createState() =>
      _RulesAssistantSheetState();
}

class _RulesAssistantSheetState extends ConsumerState<RulesAssistantSheet> {
  final _query = TextEditingController();
  List<RuleSearchResult> _results = const [];
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static const _suggestions = [
    'Quando è let?',
    'Quando si cambia campo?',
    'Come funziona lo Star Point?',
    'Come funziona il golden point?',
    'Posso colpire oltre la rete?',
    'La palla può toccare la griglia?',
    'Come si calcola il tie-break?',
  ];

  void _run(String q) {
    final search = ref.read(rulesSearchProvider);
    setState(() {
      _query.text = q;
      _results = search.search(q);
      _searched = true;
    });
  }

  /// Escalation al chatbot conversazionale Pallino (PRD E4): FAQ prima,
  /// LLM solo su richiesta esplicita e solo per il piano Pro.
  void _openProChat() {
    final params = <String, String>{
      if (_query.text.trim().isNotEmpty) 'q': _query.text.trim(),
      'mode': widget.matchId != null ? 'LIVE_MATCH' : 'RULES',
      if (widget.matchId != null) 'matchId': widget.matchId!,
      if (widget.matchContext != null) 'ctx': widget.matchContext!,
    };
    context.push(Uri(path: '/pro-chat', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final ents = ref.watch(entitlementsProvider);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Mascot3d(
              kind: Mascot3dKind.assistant,
              size: 54,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ciao, sono ${AppBrand.assistantName}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Chiedimi qualsiasi regola del padel.',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _query,
          decoration: InputDecoration(
            hintText: 'Es. quando è let?',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _run(_query.text),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _run,
        ),
        const SizedBox(height: 12),
        if (!_searched) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                ActionChip(label: Text(s), onPressed: () => _run(s)),
            ],
          ),
        ],
        if (_searched && _bestIsConfident) ...[
          for (final r in _results.take(3)) _answerCard(r.entry),
        ] else if (_searched) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Non ho abbastanza certezza 😅',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Non ho trovato una regola che risponda con sicurezza. '
                    'Prova a riformulare la domanda.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Forse cercavi:',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    for (final r in _results.take(3))
                      TextButton(
                        onPressed: () => _run(r.entry.question),
                        child: Text(r.entry.question),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (ents.llmAssistant && CloudConfig.supabaseConfigured)
          Card(
            color: RallyColors.court.withValues(alpha: 0.30),
            child: ListTile(
              onTap: _openProChat,
              leading: const Icon(Icons.auto_awesome, color: RallyColors.lime),
              title: Text(
                'Chatta con ${AppBrand.assistantName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                widget.matchId != null
                    ? 'Ha il contesto della partita in corso.'
                    : 'Conversazione libera con fonti FIP citate.',
                style: const TextStyle(fontSize: 12.5),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          )
        else if (ents.llmAssistant && !CloudConfig.supabaseConfigured)
          Card(
            color: RallyColors.court.withValues(alpha: 0.30),
            child: ListTile(
              leading: const Icon(
                Icons.cloud_off_outlined,
                color: Colors.white54,
              ),
              title: Text(
                '${AppBrand.assistantName} offline',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Cloud non configurato in questa build. Restano le FAQ locali.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          )
        else if (!ents.llmAssistant)
          Card(
            color: RallyColors.court.withValues(alpha: 0.35),
            child: ListTile(
              onTap: () => pushPaywall(context),
              leading: const Icon(Icons.auto_awesome, color: RallyColors.lime),
              title: Text(
                AppBrand.assistantFullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Domande sulla TUA partita, consigli tattici e fonti '
                'verificate. Incluso nel piano Pro.',
                style: TextStyle(fontSize: 12.5),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Le risposte gratuite provengono da un database locale curato a '
          'mano sul $padelRulesEdition: ogni voce cita fonte e numero di '
          'regola. Non sono generate da un modello, ma non sostituiscono il '
          'regolamento ufficiale né la decisione del giudice di gara.',
          style: TextStyle(fontSize: 11.5, color: Colors.white38),
        ),
      ],
    );
  }

  bool get _bestIsConfident =>
      _results.isNotEmpty && _results.first.score >= RulesSearch.minConfidence;

  Widget _answerCard(RuleEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.question,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(e.answer, style: const TextStyle(height: 1.45)),
            if (e.example != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RallyColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        e.example!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fonte: ${e.citation}',
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
      ),
    );
  }
}
