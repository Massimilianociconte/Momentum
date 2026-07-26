/// Match creation (PRD Modulo C): essentials first, advanced progressive.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/team_visuals.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/duo_service.dart';
import '../../services/watch_sync.dart';
import '../../services/wearable_match_dispatcher.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({
    super.key,
    this.initialDuo = false,
    this.initialOpponentName,
    this.linkedMatchId,
    this.proposalId,
  });

  final bool initialDuo;
  final String? initialOpponentName;

  /// Shared id allocated when a match proposal is accepted (mutual follow-up).
  final String? linkedMatchId;
  final String? proposalId;

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  MatchFormat _format = MatchFormat.goldenPointBo3;
  String? _teamId;
  final _partnerName = TextEditingController();
  final _teamName = TextEditingController();
  PadelRole _myRole = PadelRole.undefined;
  late final TextEditingController _opponents;
  final Set<OpponentTag> _tags = {};
  OpponentDifficulty _difficulty = OpponentDifficulty.sameLevel;
  final _location = TextEditingController();
  bool _creating = false;
  bool _showAdvanced = false;
  bool _didPrefill = false;

  /// Modalità scoring: un solo device (classica) o Duo Mode (premium).
  bool _duoMode = false;

  /// Duo: team che questo device segnerà nella timeline condivisa.
  TeamId _duoTeam = TeamId.a;

  /// Proposal/match linkage kept out of the user-facing location field.
  String? _linkedMatchId;
  String? _proposalId;

  @override
  void initState() {
    super.initState();
    _duoMode = widget.initialDuo;
    _opponents = TextEditingController(text: widget.initialOpponentName ?? '');
    _linkedMatchId = widget.linkedMatchId;
    _proposalId = widget.proposalId;
    // Prefill after first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDefaults());
  }

  Future<void> _prefillDefaults() async {
    if (!mounted || _didPrefill) return;
    _didPrefill = true;

    final teams = ref.read(teamsProvider).valueOrNull ?? const <Team>[];
    final me = ref.read(meProvider).valueOrNull;
    final recent =
        ref.read(recentMatchesProvider).valueOrNull ?? const <MatchRow>[];

    // Prefer last completed match defaults; fall back to profile/team list.
    MatchRow? last;
    for (final m in recent) {
      if (m.status == 'COMPLETED' || m.status == 'IN_PROGRESS') {
        last = m;
        break;
      }
    }

    MatchFormat format = _format;
    String? teamId = _teamId;
    PadelRole role = _myRole;
    String? opponents;
    String? location;

    if (last != null &&
        widget.linkedMatchId == null &&
        (widget.initialOpponentName == null ||
            widget.initialOpponentName!.isEmpty)) {
      try {
        format = MatchFormat.fromJson(
          (jsonDecode(last.formatJson) as Map).cast<String, Object?>(),
        );
      } catch (_) {}
      if (last.teamId != null &&
          teams.any((t) => t.id == last!.teamId)) {
        teamId = last.teamId;
      }
      if (last.myRole.isNotEmpty) {
        role = PadelRole.fromWire(last.myRole);
      }
      if (last.opponentLabel.isNotEmpty) {
        opponents = last.opponentLabel;
      }
      if (last.location.isNotEmpty &&
          !last.location.contains('linked:') &&
          !last.location.contains('proposal:')) {
        location = last.location;
      }
    }

    // Auto-select team when only one / first available.
    if (teamId == null && teams.isNotEmpty) {
      teamId = teams.first.id;
    }

    // Preferred role from profile when still undefined.
    if (role == PadelRole.undefined && me != null) {
      final preferred = PadelRole.fromWire(me.preferredRole);
      if (preferred != PadelRole.undefined) role = preferred;
    }

    // First-ever match: shorter format so time-to-value is minutes, not a BO3.
    if (last == null && recent.isEmpty) {
      format = MatchFormat.singleSet;
    }

    if (!mounted) return;
    setState(() {
      _format = format;
      _teamId = teamId;
      _myRole = role;
      if (opponents != null && _opponents.text.isEmpty) {
        _opponents.text = opponents;
      }
      if (location != null && _location.text.isEmpty) {
        _location.text = location;
      }
    });
  }

  @override
  void dispose() {
    _partnerName.dispose();
    _teamName.dispose();
    _opponents.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsProvider).value ?? const [];
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova partita')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _sectionTitle('FORMATO'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in MatchFormat.presets)
                ChoiceChip(
                  label: Text(f.name),
                  selected: _format.id == f.id,
                  onSelected: (_) => setState(() => _format = f),
                  selectedColor: RallyColors.lime.withValues(alpha: 0.22),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _format.id == f.id
                        ? RallyColors.lime
                        : Colors.white70,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _formatSubtitle(_format),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('TEAM'),
          if (teams.isNotEmpty)
            RadioGroup<String>(
              groupValue: _teamId,
              onChanged: (v) => setState(() => _teamId = v),
              child: Column(
                children: [
                  for (final t in teams)
                    RadioListTile<String>(
                      value: t.id,
                      secondary: TeamAvatar(team: t, size: 38),
                      title: Text(t.name),
                      activeColor: RallyColors.lime,
                      contentPadding: EdgeInsets.zero,
                    ),
                  const RadioListTile<String>(
                    value: '_new',
                    title: Text('Nuovo team…'),
                    activeColor: RallyColors.lime,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          if (teams.isEmpty || _teamId == '_new') ...[
            TextField(
              controller: _teamName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome team (es. Io + Luca)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _partnerName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Compagno'),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('IL TUO RUOLO OGGI'),
          SegmentedButton<PadelRole>(
            segments: const [
              ButtonSegment(value: PadelRole.left, label: Text('Sinistra')),
              ButtonSegment(value: PadelRole.right, label: Text('Destra')),
              ButtonSegment(value: PadelRole.flex, label: Text('Flex')),
            ],
            emptySelectionAllowed: true,
            selected: _myRole == PadelRole.undefined ? {} : {_myRole},
            onSelectionChanged: (s) => setState(
              () => _myRole = s.isEmpty ? PadelRole.undefined : s.first,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _opponents,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Avversari (opzionale)',
              hintText: 'es. Marco & Gio',
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _showAdvanced
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: RallyColors.lime,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAdvanced
                          ? 'Nascondi altre opzioni'
                          : 'Altre opzioni (Duo, tag, club…)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: RallyColors.lime,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            _sectionTitle('MODALITÀ SCORING'),
            _scoringModeSection(ents),
            const SizedBox(height: 16),
            _sectionTitle('TAG AVVERSARI'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in OpponentTag.values)
                  FilterChip(
                    label: Text(_tagLabel(t)),
                    selected: _tags.contains(t),
                    onSelected: (v) =>
                        setState(() => v ? _tags.add(t) : _tags.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle('DIFFICOLTÀ AVVERSARI (1-5)'),
            Slider(
              value: _difficulty.score.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '${_difficulty.score} — ${_difficultyLabel(_difficulty)}',
              activeColor: RallyColors.lime,
              onChanged: (v) => setState(
                () => _difficulty = OpponentDifficulty.fromScore(v),
              ),
            ),
            Center(
              child: Text(
                _difficultyLabel(_difficulty),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _location,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Club / campo (opzionale)',
              ),
            ),
          ],
          if (!ents.isPaid &&
              teams.length >= Entitlements.freeMaxTeams &&
              (_teamId == '_new' || _teamId == null && teams.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Piano Free: massimo ${Entitlements.freeMaxTeams} team. '
                'Passa a Plus per team illimitati.',
                style: const TextStyle(color: RallyColors.loss, fontSize: 13),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _creating ? null : () => _start(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Avvia sul telefono'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _creating ? null : () => _start(toWatch: true),
                  icon: const Icon(Icons.watch),
                  label: const Text('Al watch'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoringModeSection(Entitlements ents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<bool>(
          groupValue: _duoMode,
          onChanged: (v) {
            final wantDuo = v == true;
            if (wantDuo && !ents.duoMode) {
              // Paywall chiaro e non invasivo (Duo Mode §1).
              _showDuoPaywall();
              return;
            }
            setState(() => _duoMode = wantDuo);
          },
          child: Column(
            children: [
              const RadioListTile<bool>(
                value: false,
                title: Text('Singolo dispositivo'),
                subtitle: Text(
                  'Una persona segna i punti di entrambi i team',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                activeColor: RallyColors.lime,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: true,
                title: Row(
                  children: [
                    const Text('Duo Mode'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: RallyColors.lime.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ents.duoMode
                            ? (ents.premiumOverride ? 'TEST' : 'PLUS')
                            : 'PLUS',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: RallyColors.lime,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Ogni team segna i propri punti dal proprio smartwatch',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                activeColor: RallyColors.lime,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        if (_duoMode) ...[
          const SizedBox(height: 8),
          const Text(
            'Quale team segnerai da questo dispositivo?',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TeamId>(
            segments: const [
              ButtonSegment(value: TeamId.a, label: Text('Team A · Noi')),
              ButtonSegment(value: TeamId.b, label: Text('Team B · Loro')),
            ],
            selected: {_duoTeam},
            onSelectionChanged: (s) => setState(() => _duoTeam = s.first),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _joinWithCode,
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('Ho un codice: unisciti all’altro team'),
          ),
        ),
      ],
    );
  }

  void _showDuoPaywall() {
    final gate = gates['duo_mode']!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RallyColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⌚⌚ Duo Mode',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Disponibile con Plus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RallyColors.lime,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                gate.pitch,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  pushPaywall(
                    context,
                    gate: 'duo_mode',
                    plan: gate.requiredPlan,
                    reason: gate.pitch,
                    returnTo: '/match/new',
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text('Passa a ${gate.requiredPlan.label}'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Non ora'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinWithCode() async {
    final ents = ref.read(entitlementsProvider);
    if (!ents.duoMode) {
      _showDuoPaywall();
      return;
    }
    if (!ref.read(cloudAuthProvider).profileLinked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Per Duo Mode serve un account: accedi prima.'),
        ),
      );
      context.push('/auth?returnTo=${Uri.encodeQueryComponent('/match/new')}');
      return;
    }
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unisciti alla partita'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'Codice partita (8 caratteri)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Entra'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().length < 4 || !mounted) return;
    // Il backend ricontrolla comunque entitlement e ruolo: il gate client
    // evita solo un round-trip inutile e mostra subito il paywall corretto.
    assert(() {
      debugPrint('[DUO] join richiesto (override=${ents.premiumOverride})');
      return true;
    }());
    setState(() => _creating = true);
    final res = await ref.read(duoServiceProvider).joinByCode(code);
    if (!mounted) return;
    setState(() => _creating = false);
    if (res.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.error!)));
      return;
    }
    context.pushReplacement('/match/${res.session!.matchId}/duo');
  }

  /// Keeps proposal linkage out of the visible club field until save.
  String _composedLocation() {
    final club = _location.text.trim();
    final meta = <String>[
      if (_linkedMatchId != null && _linkedMatchId!.isNotEmpty)
        'linked:$_linkedMatchId',
      if (_proposalId != null && _proposalId!.isNotEmpty)
        'proposal:$_proposalId',
    ];
    if (meta.isEmpty) return club;
    if (club.isEmpty) return meta.join(' · ');
    return '${meta.join(' · ')} · $club';
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.white54,
      ),
    ),
  );

  String _formatSubtitle(MatchFormat f) {
    if (f.freePlay) return 'Conteggio punti libero, senza game e set';
    final parts = <String>[
      f.setsToWin == 1 ? '1 set' : 'Al meglio di ${f.maxSets} set',
      f.goldenPoint
          ? 'a 40 pari, prossimo punto decisivo'
          : 'a 40 pari, vantaggio AD e due punti di scarto',
      if (f.superTieBreakDecider) 'super tie-break al posto del 3° set',
    ];
    return parts.join(' · ');
  }

  String _tagLabel(OpponentTag t) => switch (t) {
    OpponentTag.beginners => 'Principianti',
    OpponentTag.sameLevel => 'Pari livello',
    OpponentTag.slightlyStronger => 'Leggermente superiori',
    OpponentTag.muchStronger => 'Molto superiori',
    OpponentTag.defensive => 'Difensivi',
    OpponentTag.aggressive => 'Aggressivi',
    OpponentTag.regular => 'Regolari',
    OpponentTag.irregular => 'Irregolari',
    OpponentTag.leftHanded => 'Mancini',
    OpponentTag.fixedPair => 'Coppia fissa',
    OpponentTag.occasionalPair => 'Coppia occasionale',
    OpponentTag.tournament => 'Torneo',
    OpponentTag.friendly => 'Amichevole',
  };

  String _difficultyLabel(OpponentDifficulty d) => switch (d) {
    OpponentDifficulty.muchEasier => 'Molto più facile',
    OpponentDifficulty.easier => 'Leggermente più facile',
    OpponentDifficulty.sameLevel => 'Pari livello',
    OpponentDifficulty.harder => 'Leggermente più difficile',
    OpponentDifficulty.muchHarder => 'Molto più difficile',
  };

  Future<void> _start({bool toWatch = false}) async {
    setState(() => _creating = true);
    try {
      final teams = ref.read(teamRepoProvider);
      final players = ref.read(playerRepoProvider);
      final ents = ref.read(entitlementsProvider);

      String? teamId = _teamId == '_new' ? null : _teamId;
      if (teamId == null &&
          (_teamName.text.trim().isNotEmpty ||
              _partnerName.text.trim().isNotEmpty)) {
        final count = await teams.count();
        if (count >= ents.maxTeams) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Limite team del piano Free raggiunto. Passa a Plus.',
                ),
              ),
            );
            pushPaywall(
              context,
              plan: Plan.plus,
              reason: 'Team illimitati con Plus. Le funzioni Free restano attive.',
              returnTo: '/match/new',
            );
          }
          setState(() => _creating = false);
          return;
        }
        final me = await players.me();
        if (me == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Profilo locale non pronto. Completa il profilo e riprova.',
                ),
              ),
            );
          }
          setState(() => _creating = false);
          return;
        }
        final partner = _partnerName.text.trim().isEmpty
            ? null
            : await players.ensurePartner(_partnerName.text.trim());
        final name = _teamName.text.trim().isNotEmpty
            ? _teamName.text.trim()
            : 'Io + ${_partnerName.text.trim()}';
        final t = await teams.create(
          name: name,
          playerAId: me.id,
          playerBId: partner?.id,
          playerBName: partner?.name ?? '',
          roleA: _myRole,
        );
        teamId = t.id;
      }

      if (_duoMode) {
        // Duo Mode: gate premium/test già verificato alla selezione, ma
        // ricontrollato qui (e comunque dal backend via RLS).
        if (!ents.duoMode) {
          _showDuoPaywall();
          return;
        }
        if (!ref.read(cloudAuthProvider).profileLinked) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Per Duo Mode serve un account: accedi prima.'),
              ),
            );
            context.push(
              '/auth?returnTo=${Uri.encodeQueryComponent('/match/new')}',
            );
          }
          return;
        }
        final match = await ref
            .read(matchRepoProvider)
            .create(
              format: _format,
              teamId: teamId,
              myRole: _myRole,
              opponentLabel: _opponents.text.trim(),
              tags: _tags,
              difficulty: _difficulty,
              location: _composedLocation(),
              duoMode: true,
              duoTeam: _duoTeam,
            );
        final res = await ref
            .read(duoServiceProvider)
            .createSession(
              matchId: match.id,
              format: _format,
              myTeam: _duoTeam,
            );
        if (res.error != null) {
          // Delete only after a definitive server rejection. A timeout or a
          // local link failure may happen after the RPC committed; in that
          // case the lobby retries the same idempotent matchId and recovers.
          if (res.canDiscardLocal) {
            await ref.read(matchRepoProvider).discardUnlinkedDuoMatch(match.id);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(res.error!)));
          if (!res.canDiscardLocal) {
            context.pushReplacement('/match/${match.id}/duo');
          }
          return;
        }
        if (!mounted) return;
        context.pushReplacement('/match/${match.id}/duo');
        return;
      }

      final match = await ref
          .read(matchRepoProvider)
          .create(
            format: _format,
            teamId: teamId,
            myRole: _myRole,
            opponentLabel: _opponents.text.trim(),
            tags: _tags,
            difficulty: _difficulty,
            location: _composedLocation(),
          );
      if (toWatch) {
        final devices =
            ref.read(connectedDevicesProvider).valueOrNull ?? const [];
        final ready = devices.where(isScoringWearableReady).toList();
        final native = ref.read(watchSyncProvider);
        final canDispatch = ready.isNotEmpty ||
            (native.companionInstalled && native.paired);
        if (!canDispatch) {
          if (mounted) {
            final goSetup = await showModalBottomSheet<bool>(
              context: context,
              backgroundColor: RallyColors.surface,
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nessun watch pronto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Completa la configurazione guidata dello smartwatch '
                        'prima di inviare la partita al polso. Puoi comunque '
                        'segnare sul telefono.',
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Configura smartwatch'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Continua sul telefono'),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (goSetup == true && mounted) {
              context.push('/devices/setup');
              return;
            }
          }
        } else {
          final watchTeam = teamId == null
              ? null
              : await ref.read(teamRepoProvider).byId(teamId);
          final delivery = await ref
              .read(wearableMatchDispatcherProvider)
              .startMatch(
                matchId: match.id,
                format: _format,
                teamName: watchTeam?.name,
                teamImagePath: watchTeam?.imageLocalPath,
                teamImageVersion: watchTeam?.imageVersion ?? 0,
                teamScoringStyle: watchTeam?.scoringStyle ?? 'AUTO',
              );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(delivery.message)));
          }
        }
      }
      if (mounted) context.pushReplacement('/match/${match.id}/live');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
