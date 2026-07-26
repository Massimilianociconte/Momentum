/// Pallino Assistant — chatbot conversazionale premium (PRD E4).
///
/// Multi-turno con LLM via API key (OpenAI nano-class o Claude, deciso dal
/// backend), fonti FIP citate, contatore domande residue, limiti server-side.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/brand.dart';
import '../../core/mascot_3d.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../domain/assistant_local_context.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';

class ProChatScreen extends ConsumerStatefulWidget {
  const ProChatScreen({
    super.key,
    this.initialQuestion,
    this.mode = 'RULES',
    this.matchId,
    this.matchContext,
  });

  final String? initialQuestion;
  final String mode;
  final String? matchId;
  final String? matchContext;

  @override
  ConsumerState<ProChatScreen> createState() => _ProChatScreenState();
}

class _ChatMessage {
  _ChatMessage({
    required this.fromUser,
    required this.text,
    this.sources = const [],
    this.cached = false,
    this.questionForReport,
  });
  final bool fromUser;
  final String text;
  final List<Map<String, dynamic>> sources;
  final bool cached;
  final String? questionForReport;
}

class _ProChatScreenState extends ConsumerState<ProChatScreen> {
  final _messages = <_ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  int? _remaining;

  /// Prefer explicit POST_MATCH (post-match analysis) over LIVE when both
  /// matchId and mode are set (match detail always passes matchId).
  String get _mode {
    if (widget.mode == 'POST_MATCH') return 'POST_MATCH';
    if (widget.matchId != null && widget.matchId!.isNotEmpty) {
      return 'LIVE_MATCH';
    }
    return widget.mode;
  }

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ents = ref.read(entitlementsProvider);
        final auth = ref.read(cloudAuthProvider);
        if (!ents.llmAssistant ||
            !auth.profileLinked ||
            !CloudConfig.supabaseConfigured) {
          return;
        }
        unawaited(_send(q));
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _thinking) return;
    final ents = ref.read(entitlementsProvider);
    final auth = ref.read(cloudAuthProvider);
    if (!ents.llmAssistant ||
        !auth.profileLinked ||
        !CloudConfig.supabaseConfigured) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: q));
      _thinking = true;
      _input.clear();
    });
    _scrollDown();

    // Exclude error bubbles, then drop the current user turn (already in
    // `question`) so it is not duplicated inside history.
    final prior = _messages
        .where((m) => !m.text.startsWith('⚠️'))
        .toList();
    final withoutCurrent = prior.isEmpty
        ? prior
        : prior.sublist(0, prior.length - 1);
    final trimmed = withoutCurrent.length > 12
        ? withoutCurrent.sublist(withoutCurrent.length - 12)
        : withoutCurrent;
    final turns = trimmed
        .map(
          (m) => ChatTurn(
            role: m.fromUser ? 'user' : 'assistant',
            content: m.text,
          ),
        )
        .toList();

    late final String clientContext;
    try {
      clientContext = await _buildClientContext();
    } catch (error, stack) {
      debugPrint('Pallino clientContext failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(
          _ChatMessage(
            fromUser: false,
            text: '⚠️ Contesto locale non disponibile. Riprova.',
          ),
        );
      });
      _scrollDown();
      return;
    }
    if (!mounted) return;

    final r = await AssistantClient.ask(
      question: q,
      mode: _mode,
      // Live quota only for true live mode; post-match keeps matchId for context
      // but must not consume live-match slots.
      matchId: _mode == 'LIVE_MATCH' ? widget.matchId : null,
      matchContext: widget.matchContext,
      clientContext: clientContext,
      surface: 'mobile',
      history: turns,
    );
    if (!mounted) return;
    setState(() {
      _thinking = false;
      if (r.answer != null) {
        _messages.add(
          _ChatMessage(
            fromUser: false,
            text: r.answer!.answer,
            sources: r.answer!.sources,
            cached: r.answer!.cached,
            questionForReport: q,
          ),
        );
        _remaining = r.answer!.remainingToday;
      } else {
        _messages.add(
          _ChatMessage(
            fromUser: false,
            text: '⚠️ ${r.error ?? 'Errore sconosciuto'}',
          ),
        );
      }
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(entitlementsProvider);
    final auth = ref.watch(cloudAuthProvider);
    if (!entitlements.llmAssistant) {
      return _StaticAssistantScaffold(mode: _mode);
    }
    if (!CloudConfig.supabaseConfigured) {
      return _AssistantUnavailableScaffold(
        title: 'Servizio online non disponibile',
        subtitle:
            '${AppBrand.assistantFullName} non è raggiungibile da questa versione. '
            'Le regole e le FAQ locali restano disponibili senza rete.',
        icon: Icons.cloud_off_outlined,
        primaryLabel: 'Usa le FAQ offline',
        onPrimary: () => context.push('/rules'),
      );
    }
    if (!auth.signedIn) {
      return _AssistantUnavailableScaffold(
        title: 'Accedi per usare ${AppBrand.assistantName}',
        subtitle:
            'L’assistente verifica in modo sicuro il tuo piano sul server. '
            'Crea o accedi al tuo account per continuare.',
        icon: Icons.lock_outline,
        primaryLabel: 'Accedi',
        onPrimary: () => context.push(
          '/auth?returnTo=${Uri.encodeQueryComponent(_proChatReturnTo)}',
        ),
        secondaryLabel: 'Vedi piano Pro',
        onSecondary: () => pushPaywall(
          context,
          gate: 'llm_assistant',
          plan: Plan.pro,
          reason: gates['llm_assistant']?.pitch,
          returnTo: '/pro-chat',
        ),
      );
    }
    if (!auth.profileLinked) {
      return _AssistantUnavailableScaffold(
        title: 'Collega il profilo locale',
        subtitle:
            'Conferma il collegamento dei dati presenti su questo dispositivo '
            'prima di usare ${AppBrand.assistantFullName}.',
        icon: Icons.link,
        primaryLabel: 'Collega account',
        onPrimary: () => context.push(
          '/auth?returnTo=${Uri.encodeQueryComponent(_proChatReturnTo)}',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Mascot3d(
              kind: Mascot3dKind.assistant,
              size: 28,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(width: 8),
            Text(AppBrand.assistantName),
            const Spacer(),
            if (_remaining != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: RallyColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_remaining disponibili',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ),
            if (_messages.isNotEmpty) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Nuova conversazione',
                onPressed: _thinking
                    ? null
                    : () => setState(() {
                        _messages.clear();
                        _remaining = null;
                      }),
                icon: const Icon(Icons.delete_sweep_outlined, size: 19),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_thinking
                ? _emptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) return _typing();
                      return _bubble(_messages[i]);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Chiedi a ${AppBrand.assistantName}…',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      enabled: !_thinking,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _thinking ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: RallyColors.lime,
                      foregroundColor: const Color(0xFF15200A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Mascot3d(
              kind: Mascot3dKind.assistant,
              size: 96,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            const SizedBox(height: 12),
            Text(
              _emptyTitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _emptySubtitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prompt in _starterPrompts())
                  ActionChip(
                    label: Text(prompt),
                    onPressed: () => _send(prompt),
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitle() => switch (_mode) {
    'TRAINING' => 'Costruiamo il prossimo allenamento.',
    'APP_HELP' => 'Ti aiuto a usare Padelandia meglio.',
    'POST_MATCH' => 'Analizziamo la partita con lucidità.',
    'LIVE_MATCH' => 'Una risposta veloce per la partita.',
    _ => 'Chiedimi regole, tattica o come migliorare.',
  };

  String _emptySubtitle() => switch (_mode) {
    'LIVE_MATCH' => 'Ho il contesto della tua partita live.',
    'POST_MATCH' =>
      'Analizzo form, coppie e priorità di allenamento (senza dati salute di sistema).',
    'APP_HELP' => 'Posso spiegarti account, backup, social, watch e piani.',
    'TRAINING' =>
      'Uso catalogo training, log (RPE/minuti app) e form partite — mai dati salute di sistema.',
    _ => 'Posso usare form, allenamenti e team (se abilitati). Regole FIP citate.',
  };

  List<String> _starterPrompts() => switch (_mode) {
    'TRAINING' => const [
      'Preparami una routine sulla base dei miei log',
      'Come bilanciare carico e partite questa settimana?',
      'Quali sessioni premium mi servono di più?',
    ],
    'APP_HELP' => const [
      'Differenza Free e Pro',
      'Come funziona il backup?',
      'Come uso lo smartwatch?',
    ],
    'POST_MATCH' => const [
      'Analizza i miei punti deboli',
      'Quale coppia/team rende meglio?',
      'Che allenamento faccio domani?',
    ],
    'LIVE_MATCH' => const [
      'Come cambio ritmo adesso?',
      'Una scelta semplice sul golden point',
      'Come recupero se perdiamo rete?',
    ],
    _ => const [
      'Quando il servizio è let?',
      'Spiegami il golden point',
      'Quali sono le mie migliori coppie?',
    ],
  };

  /// Full /pro-chat location so auth return keeps mode/match/draft question.
  String get _proChatReturnTo {
    final params = <String, String>{
      'mode': _mode,
      if (widget.matchId != null && widget.matchId!.isNotEmpty)
        'matchId': widget.matchId!,
      if (widget.matchContext != null && widget.matchContext!.trim().isNotEmpty)
        'ctx': widget.matchContext!,
      if (widget.initialQuestion != null &&
          widget.initialQuestion!.trim().isNotEmpty)
        'q': widget.initialQuestion!,
    };
    return Uri(path: '/pro-chat', queryParameters: params).toString();
  }

  /// Builds privacy-minimized synthetic context via specialized local agents:
  /// form, training, team chemistry. Never includes platform health data.
  /// Awaits async providers only while still loading (not when legitimately empty).
  Future<String> _buildClientContext() async {
    final shareFlag =
        ref.read(assistantShareTrainingTeamProvider).valueOrNull ?? true;

    Player? me = ref.read(meProvider).valueOrNull;
    if (me == null && ref.read(meProvider).isLoading) {
      try {
        me = await ref.read(meProvider.future).timeout(
              const Duration(seconds: 4),
              onTimeout: () => null,
            );
      } catch (_) {}
    }

    List<MatchSummary> summaries =
        ref.read(summariesProvider).valueOrNull ?? const <MatchSummary>[];
    if (summaries.isEmpty && ref.read(summariesProvider).isLoading) {
      try {
        summaries = await ref.read(summariesProvider.future).timeout(
              const Duration(seconds: 4),
            );
      } catch (_) {}
    }

    WeeklySummary? weekly = ref.read(weeklySummaryProvider).valueOrNull;
    if (weekly == null && ref.read(weeklySummaryProvider).isLoading) {
      try {
        weekly = await ref.read(weeklySummaryProvider.future).timeout(
              const Duration(seconds: 4),
            );
      } catch (_) {}
    }

    List<Team> teams = ref.read(teamsProvider).valueOrNull ?? const <Team>[];
    if (teams.isEmpty && ref.read(teamsProvider).isLoading) {
      try {
        teams = await ref.read(teamsProvider.future).timeout(
              const Duration(seconds: 4),
            );
      } catch (_) {}
    }

    List<Training> trainings =
        ref.read(trainingsProvider).valueOrNull ?? const <Training>[];
    if (trainings.isEmpty && ref.read(trainingsProvider).isLoading) {
      try {
        trainings = await ref.read(trainingsProvider.future).timeout(
              const Duration(seconds: 4),
            );
      } catch (_) {}
    }

    List<TrainingLog> logs =
        ref.read(trainingLogsProvider).valueOrNull ?? const <TrainingLog>[];
    if (logs.isEmpty && ref.read(trainingLogsProvider).isLoading) {
      try {
        logs = await ref.read(trainingLogsProvider.future).timeout(
              const Duration(seconds: 4),
            );
      } catch (_) {}
    }

    return const AssistantLocalContextComposer().compose(
      AssistantContextInput(
        me: me,
        summaries: summaries,
        weekly: weekly,
        teams: teams,
        trainings: trainings,
        logs: logs,
        includeTrainingAndTeam: shareFlag,
      ),
    );
  }

  Widget _typing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            '${AppBrand.assistantName} sta pensando…',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    final canReport =
        !m.fromUser && m.questionForReport != null && !m.text.startsWith('⚠️');
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          // sizeOf: la bolla non deve ricostruirsi a ogni frame di
          // animazione della tastiera (viewInsets), solo se cambia la size.
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: m.fromUser ? RallyColors.court : RallyColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(m.fromUser ? 18 : 4),
            bottomRight: Radius.circular(m.fromUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.fromUser)
              Text(m.text, style: const TextStyle(height: 1.4))
            else
              _SafeAssistantRichText(m.text),
            if (m.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final s in m.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book,
                        size: 12,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${s['source']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (m.cached)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '⚡ risposta immediata dalla cache',
                  style: TextStyle(fontSize: 10.5, color: Colors.white30),
                ),
              ),
            if (canReport) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _reportMessage(m),
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('Segnala risposta'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reportMessage(_ChatMessage message) async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ReportAssistantDialog(),
    );
    if (payload == null || !mounted) return;
    final error = await AssistantClient.report(
      question: message.questionForReport ?? '',
      answer: message.text,
      mode: _mode,
      reason: payload['reason'] ?? 'other',
      details: payload['details'] ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Segnalazione inviata. Grazie, la controlleremo.',
        ),
      ),
    );
  }
}

class _StaticAssistantScaffold extends ConsumerStatefulWidget {
  const _StaticAssistantScaffold({required this.mode});

  final String mode;

  @override
  ConsumerState<_StaticAssistantScaffold> createState() =>
      _StaticAssistantScaffoldState();
}

class _StaticAssistantScaffoldState
    extends ConsumerState<_StaticAssistantScaffold> {
  final _input = TextEditingController();
  var _searched = false;
  var _query = '';
  List<RuleSearchResult> _results = const [];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _query = q;
      _searched = true;
      _input.text = q;
      _results = ref.read(rulesSearchProvider).search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(trainingsProvider).valueOrNull ?? const <Training>[];
    return Scaffold(
      appBar: AppBar(title: Text(AppBrand.assistantName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _FreeHeader(mode: widget.mode),
          const SizedBox(height: 14),
          TextField(
            controller: _input,
            maxLength: 180,
            decoration: const InputDecoration(
              hintText: 'Cerca una regola o un consiglio base',
              prefixIcon: Icon(Icons.search),
              counterText: '',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _run,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions(widget.mode))
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _run(suggestion),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_searched) _staticAnswer(training),
          const SizedBox(height: 14),
          _ProUpgradeCard(
            onTap: () => pushPaywall(
              context,
              gate: 'llm_assistant',
              plan: Plan.pro,
              reason: gates['llm_assistant']?.pitch,
              returnTo: '/pro-chat',
            ),
            pitch: gates['llm_assistant']!.pitch,
          ),
        ],
      ),
    );
  }

  Widget _staticAnswer(List<Training> trainings) {
    final confident =
        _results.isNotEmpty &&
        _results.first.score >= RulesSearch.minConfidence;
    if (confident) {
      return Column(
        children: [
          for (final result in _results.take(3))
            _StaticRuleCard(entry: result.entry),
        ],
      );
    }

    final trainingAnswer = _trainingAnswer(_query, trainings);
    if (trainingAnswer != null) {
      return _StaticTextCard(
        title: 'Consiglio training base',
        body: trainingAnswer,
        source: 'Training locale Padelandia',
      );
    }

    return _StaticTextCard(
      title: 'Non ho abbastanza certezza',
      body:
          'Nella versione Free rispondo solo con contenuti statici e verificati. '
          'Prova con una domanda su servizio, let, golden point, parete o '
          'allenamenti base.',
      source: 'FAQ locale, nessuna AI esterna',
      icon: Icons.help_outline,
    );
  }

  String? _trainingAnswer(String query, List<Training> trainings) {
    final q = query.toLowerCase();
    if (widget.mode != 'TRAINING' &&
        !q.contains('allen') &&
        !q.contains('training') &&
        !q.contains('routine') &&
        !q.contains('eserc')) {
      return null;
    }
    final freeTrainings = trainings.where((t) => !t.premium).take(4).toList();
    final titles = freeTrainings.isEmpty
        ? 'volée di controllo, uscita di parete, servizio + primo colpo'
        : freeTrainings
              .map((t) => '${t.title} (${t.durationMinutes} min)')
              .join(', ');
    if (q.contains('parete')) {
      return 'Lavora su uscita di parete: 10 minuti lettura rimbalzo, '
          '10 minuti colpo controllato verso il centro, 5 minuti lob alto. '
          'Obiettivo: uscire dalla difesa senza forzare.';
    }
    if (q.contains('serv')) {
      return 'Routine servizio base: 5 minuti riscaldamento spalla, '
          '15 minuti servizio profondo sul vetro laterale, 10 minuti primo '
          'colpo verso il centro. Obiettivo: iniziare lo scambio in vantaggio.';
    }
    if (q.contains('vol') || q.contains('rete')) {
      return 'Routine volée: 8 minuti split-step, 12 minuti volée profonda '
          'incrociata, 8 minuti chiusura facile. Mantieni gomito davanti e '
          'racchetta stabile.';
    }
    return 'Per iniziare scegli una routine breve tra: $titles. Registra RPE '
        'e minuti a fine sessione: dopo qualche settimana Padelandia collega '
        'meglio partite e allenamenti.';
  }

  List<String> _suggestions(String mode) => switch (mode) {
    'TRAINING' => const [
      'Routine volée 25 minuti',
      'Allenamento uscita di parete',
      'Come registro RPE?',
    ],
    'APP_HELP' => const [
      'Differenza Free e Pro',
      'Come funziona lo smartwatch?',
      'Come elimino l’account?',
    ],
    _ => const [
      'Cos’è il golden point?',
      'Quando il servizio è let?',
      'Posso colpire fuori dal campo?',
    ],
  };
}

class _FreeHeader extends StatelessWidget {
  const _FreeHeader({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final title = mode == 'TRAINING'
        ? 'Aiuto training base'
        : mode == 'APP_HELP'
        ? 'Aiuto app base'
        : 'FAQ e regole base';
    return Card(
      color: RallyColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Mascot3d(
              kind: Mascot3dKind.assistant,
              size: 58,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Free usa solo FAQ, regole e contenuti locali. Nessuna '
                    'chiamata AI esterna, nessun costo API.',
                    style: TextStyle(color: Colors.white60, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticRuleCard extends StatelessWidget {
  const _StaticRuleCard({required this.entry});

  final RuleEntry entry;

  @override
  Widget build(BuildContext context) {
    return _StaticTextCard(
      title: entry.question,
      body: entry.example == null
          ? entry.answer
          : '${entry.answer}\n\nEsempio: ${entry.example}',
      source: entry.source,
      icon: Icons.menu_book_outlined,
    );
  }
}

class _StaticTextCard extends StatelessWidget {
  const _StaticTextCard({
    required this.title,
    required this.body,
    required this.source,
    this.icon = Icons.lightbulb_outline,
  });

  final String title;
  final String body;
  final String source;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: RallyColors.lime, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _SafeAssistantRichText(body),
            const SizedBox(height: 10),
            Text(
              source,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProUpgradeCard extends StatelessWidget {
  const _ProUpgradeCard({required this.onTap, required this.pitch});

  final VoidCallback onTap;
  final String pitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: RallyColors.court.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RallyColors.lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF142006)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sblocca ${AppBrand.assistantFullName}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pitch,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantUnavailableScaffold extends StatelessWidget {
  const _AssistantUnavailableScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppBrand.assistantName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: RallyColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, color: RallyColors.lime, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeAssistantRichText extends StatelessWidget {
  const _SafeAssistantRichText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n');
    final children = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      final trimmed = line.trimLeft();
      final heading = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(trimmed);
      final numbered = RegExp(r'^(\d{1,2})\.\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 5),
            child: Text(
              _plain(heading.group(1)!),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        children.add(_bullet(trimmed.substring(2)));
      } else if (numbered != null) {
        children.add(_numbered(numbered.group(1)!, numbered.group(2)!));
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _inline(trimmed),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 5, color: RallyColors.lime),
          ),
          const SizedBox(width: 8),
          Expanded(child: _inline(text)),
        ],
      ),
    );
  }

  static Widget _numbered(String index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: const TextStyle(
              color: RallyColors.lime,
              fontWeight: FontWeight.w900,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _inline(text)),
        ],
      ),
    );
  }

  static Widget _inline(String input) {
    final sanitized = _plain(input);
    final spans = <TextSpan>[];
    var cursor = 0;
    final matches = RegExp(r'\*\*([^*]+)\*\*').allMatches(sanitized).toList();
    if (matches.isEmpty) {
      return Text(sanitized, style: const TextStyle(height: 1.4));
    }
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: sanitized.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
      cursor = match.end;
    }
    if (cursor < sanitized.length) {
      spans.add(TextSpan(text: sanitized.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, height: 1.4),
        children: spans,
      ),
    );
  }

  static String _plain(String value) =>
      value.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\t', ' ').trim();
}

class _ReportAssistantDialog extends StatefulWidget {
  const _ReportAssistantDialog();

  @override
  State<_ReportAssistantDialog> createState() => _ReportAssistantDialogState();
}

class _ReportAssistantDialogState extends State<_ReportAssistantDialog> {
  final _details = TextEditingController();
  String _reason = 'offensive_or_unsafe';

  static const _reasons = <String, String>{
    'offensive_or_unsafe': 'Contenuto offensivo o non sicuro',
    'dangerous_advice': 'Consiglio potenzialmente pericoloso',
    'wrong_rule': 'Regola o spiegazione errata',
    'privacy_issue': 'Problema privacy o dati personali',
    'other': 'Altro',
  };

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segnala risposta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: [
              for (final entry in _reasons.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _reason = value ?? 'other'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 3,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Dettagli facoltativi',
              hintText: 'Aiutaci a capire cosa correggere.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'reason': _reason,
            'details': _details.text.trim(),
          }),
          child: const Text('Invia'),
        ),
      ],
    );
  }
}
