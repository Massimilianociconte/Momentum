/// Home dashboard: first-run friendly premium sport UI, fully backed by app
/// data and explicit empty states.
///
/// Visual language: night padel court, bold lime energy, editorial hierarchy.
/// Raster-safe: solid gradients, tight shadows, no BackdropFilter / heavy blur.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/mascot_3d.dart';
import '../../core/profile_visuals.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';
import '../../services/watch_sync.dart';
import '../../services/wearable_match_dispatcher.dart';
import '../training/training_session_draft.dart';
import '../training/training_session_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RallyColors.night,
      body: Stack(
        children: [
          const Positioned.fill(child: _HomeBackdrop()),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 112),
              // ignore: deprecated_member_use
              cacheExtent: 320,
              children: [
                const _HomeHeaderSection(),
                const SizedBox(height: 22),
                _NewMatchHero(onTap: () => context.push('/match/new')),
                const SizedBox(height: 14),
                // Matchmaking immediately under "Nuova partita" (no nav duplicates).
                const _FindPlayersCard(),
                const _ResumeMatchSection(),
                const _ResumeTrainingSection(),
                const SizedBox(height: 12),
                const _SetupSection(),
                const SizedBox(height: 28),
                const _HomeSectionHeading(
                  label: 'La tua settimana',
                  subtitle: 'Ritmo, volume e obiettivo',
                  icon: Icons.bolt_rounded,
                  color: RallyColors.lime,
                ),
                const SizedBox(height: 12),
                const _WeeklyOverviewSection(),
                const SizedBox(height: 28),
                const _HomeSectionHeading(
                  label: 'Continua a crescere',
                  subtitle: 'Partite, team e allenamento',
                  icon: Icons.auto_graph_rounded,
                  color: RallyColors.cyan,
                ),
                const SizedBox(height: 12),
                const _HomeGridSection(),
                const SizedBox(height: 18),
                const _TipSection(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _HomeBackdropPainter()),
      ),
    );
  }
}

class _HomeBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Layered night sky — solid paints only (no saveLayer / blur).
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF15243A),
          Color(0xFF0C1220),
          Color(0xFF080E18),
        ],
        stops: [0, 0.42, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Court-blue wash top-left.
    final blueWash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.95),
        radius: 1.15,
        colors: [
          RallyColors.court.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, blueWash);

    // Lime energy top-center.
    final limeWash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.15, -1.05),
        radius: 0.9,
        colors: [
          RallyColors.lime.withValues(alpha: 0.09),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, limeWash);

    // Stylized court lines (subtle brand signature).
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final accentLine = Paint()
      ..color = RallyColors.lime.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    final courtWidth = math.min(size.width * 1.05, 520.0);
    final courtLeft = (size.width - courtWidth) / 2;
    final court = Rect.fromLTWH(courtLeft, 28, courtWidth, 248);
    canvas.drawRRect(
      RRect.fromRectAndRadius(court, const Radius.circular(48)),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, court.top + 8),
      Offset(size.width / 2, court.bottom - 8),
      line,
    );
    canvas.drawLine(
      Offset(court.left + 18, court.center.dy),
      Offset(court.right - 18, court.center.dy),
      accentLine,
    );
    // Service boxes hint.
    final service = Rect.fromCenter(
      center: court.center,
      width: courtWidth * 0.42,
      height: 88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(service, const Radius.circular(14)),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading({
    required this.label,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeaderSection extends ConsumerWidget {
  const _HomeHeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider.select((value) => value.valueOrNull));
    return _HomeHeader(me: me);
  }
}

class _ResumeMatchSection extends ConsumerWidget {
  const _ResumeMatchSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMatch = ref.watch(
      recentMatchesProvider.select(
        (value) => (value.valueOrNull ?? const <MatchRow>[])
            .where(
              (match) =>
                  match.status == MatchStatus.inProgress.wire ||
                  match.status == MatchStatus.paused.wire,
            )
            .firstOrNull,
      ),
    );
    if (currentMatch == null) return const SizedBox.shrink();
    return _ResumeMatchCard(match: currentMatch);
  }
}

/// Resume interrupted guided training (local draft only — no cloud, no timer).
class _ResumeTrainingSection extends ConsumerStatefulWidget {
  const _ResumeTrainingSection();

  @override
  ConsumerState<_ResumeTrainingSection> createState() =>
      _ResumeTrainingSectionState();
}

class _ResumeTrainingSectionState
    extends ConsumerState<_ResumeTrainingSection> {
  TrainingSessionDraft? _draft;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final draft = await loadTrainingDraft(ref.read(keyValueRepoProvider));
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _draft == null) return const SizedBox.shrink();
    final draft = _draft!;
    final trainings =
        ref.watch(trainingsProvider).valueOrNull ?? const <Training>[];
    Training? training;
    for (final t in trainings) {
      if (t.id == draft.trainingId) {
        training = t;
        break;
      }
    }
    if (training == null) {
      unawaited(() async {
        await clearTrainingDraft(ref.read(keyValueRepoProvider));
        if (mounted) setState(() => _draft = null);
      }());
      return const SizedBox.shrink();
    }
    final t = training;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: const Color(0xFF111A26),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await showGuidedSession(context, ref, t, draft: draft);
            await _reload();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: RallyColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: RallyColors.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RIPRENDI ALLENAMENTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: RallyColors.cyan,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Esercizio ${draft.drillIndex + 1} · '
                        '${(draft.elapsedSeconds / 60).floor()} min fatti',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Scarta bozza',
                  onPressed: () async {
                    await clearTrainingDraft(ref.read(keyValueRepoProvider));
                    if (mounted) setState(() => _draft = null);
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
                const Icon(Icons.play_arrow_rounded, color: RallyColors.lime),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupSection extends ConsumerWidget {
  const _SetupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider.select((value) => value.valueOrNull));
    final hasTeam = ref.watch(
      teamsProvider.select((value) => value.valueOrNull?.isNotEmpty ?? false),
    );
    final nativeWatchConnected = ref.watch(
      watchSyncProvider.select((value) => value.connected),
    );
    final providerWatchConnected = ref.watch(
      connectedDevicesProvider.select(
        (value) => value.valueOrNull?.any(isScoringWearableReady) ?? false,
      ),
    );
    final watchConnected = nativeWatchConnected || providerWatchConnected;
    final roleReady =
        (me?.preferredRole ?? PadelRole.undefined.wire) !=
        PadelRole.undefined.wire;
    // Hide checklist when all three steps are done — less noise, more play.
    if (roleReady && hasTeam && watchConnected) {
      return const SizedBox.shrink();
    }
    return _SetupCard(me: me, hasTeam: hasTeam, watchConnected: watchConnected);
  }
}

class _WeeklyOverviewSection extends ConsumerWidget {
  const _WeeklyOverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklySummaryProvider).value;
    final summaries = ref.watch(summariesProvider).valueOrNull ?? const [];
    final logs = ref.watch(trainingLogsProvider).valueOrNull ?? const [];
    return _WeeklyOverviewCard(
      week: _ThisWeek.from(
        weekly: weekly,
        summaries: summaries,
        trainingLogs: logs,
      ),
    );
  }
}

class _HomeGridSection extends ConsumerWidget {
  const _HomeGridSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestMatch = ref.watch(
      recentMatchesProvider.select(
        (value) => (value.valueOrNull ?? const <MatchRow>[])
            .where((match) => match.status == MatchStatus.completed.wire)
            .firstOrNull,
      ),
    );
    final team = ref.watch(
      teamsProvider.select((value) => value.valueOrNull?.firstOrNull),
    );
    final me = ref.watch(meProvider.select((value) => value.valueOrNull));
    final trainings = ref.watch(trainingsProvider).valueOrNull ?? const [];
    final insights = ref.watch(insightsProvider).valueOrNull ?? const [];
    return _HomeGrid(
      latestMatch: latestMatch,
      team: team,
      training: _pickTraining(trainings, me),
      insights: insights,
    );
  }
}

class _TipSection extends ConsumerWidget {
  const _TipSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMatch = ref.watch(
      recentMatchesProvider.select(
        (value) => (value.valueOrNull ?? const <MatchRow>[]).any(
          (match) => match.status == MatchStatus.completed.wire,
        ),
      ),
    );
    final hasTeam = ref.watch(
      teamsProvider.select((value) => value.valueOrNull?.isNotEmpty ?? false),
    );
    final hasWatch = ref.watch(
      watchSyncProvider.select((value) => value.connected),
    );
    return _TipCard(hasMatch: hasMatch, hasTeam: hasTeam, hasWatch: hasWatch);
  }
}

Training? _pickTraining(List<Training> trainings, Player? me) {
  if (trainings.isEmpty) return null;
  final role = me?.preferredRole ?? PadelRole.undefined.wire;
  final freeRoleMatches = trainings.where(
    (training) =>
        !training.premium &&
        (training.role == role || training.role == PadelRole.undefined.wire),
  );
  if (freeRoleMatches.isNotEmpty) return freeRoleMatches.first;
  final free = trainings.where((training) => !training.premium);
  return free.isEmpty ? trainings.first : free.first;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.me});

  final Player? me;

  @override
  Widget build(BuildContext context) {
    final rawName = me?.nickname.isNotEmpty == true
        ? me!.nickname
        : (me?.name ?? '').trim();
    final firstName = rawName.isEmpty || rawName == 'Giocatore'
        ? ''
        : rawName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A2A40), Color(0xFF101A2A)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/brand/padelandia_app_icon_1024.png',
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.sports_tennis_rounded,
                        color: RallyColors.lime,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOMENTUM',
                          style: TextStyle(
                            color: RallyColors.lime.withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Padel companion',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _HeaderIconButton(
              icon: Icons.groups_2_rounded,
              semanticLabel: 'I miei team',
              onTap: () => context.push('/teams'),
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(
              icon: Icons.person_search_rounded,
              semanticLabel: 'Trova giocatori',
              onTap: () => context.push('/social'),
            ),
            const SizedBox(width: 8),
            _AvatarButton(me: me),
          ],
        ),
        const SizedBox(height: 18),
        _Greeting(firstName: firstName),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF121B2A),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.78)),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName});

  final String firstName;

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  static String _energyLine() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Scalda il braccio. Oggi si gioca.';
    if (hour < 18) return 'Il campo ti aspetta. Pronto al prossimo punto?';
    return 'Sotto le luci del campo. È il momento giusto.';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _timeGreeting();
    final title = firstName.isEmpty ? greeting : '$greeting, $firstName';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _energyLine(),
          maxLines: 2,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.me});

  final Player? me;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apri profilo',
      child: InkWell(
        onTap: () => context.go('/profile'),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: RallyColors.lime.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
          child: PlayerAvatar(
            player: me,
            size: 40,
            semanticLabel: 'Apri profilo',
          ),
        ),
      ),
    );
  }
}

class _NewMatchHero extends StatelessWidget {
  const _NewMatchHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Intrinsic height (no fixed height + Spacer): avoids clipping the CTA
    // on dense fonts, large text scale, or narrow widths.
    return Semantics(
      button: true,
      label: 'Crea una nuova partita',
      hint: 'Apre la configurazione della partita',
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1680D8),
                    Color(0xFF0C5CAB),
                    Color(0xFF083A6F),
                  ],
                  stops: [0, 0.5, 1],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _HeroPattern()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RallyColors.lime,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'GIOCA ORA',
                                      style: TextStyle(
                                        color: Color(0xFF0A1408),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Nuova partita',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Configura e scendi in campo',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.82),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Telefono · Apple Watch · Wear OS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.55),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF061018),
                                border: Border.all(
                                  color:
                                      RallyColors.lime.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Transform.scale(
                                scale: 1.28,
                                child: Image.asset(
                                  'assets/brand/rallymate_new_match_emblem.png',
                                  fit: BoxFit.cover,
                                  cacheWidth: 160,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: RallyColors.lime,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: RallyColors.lime
                                        .withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Inizia',
                                    style: TextStyle(
                                      color: Color(0xFF0A1408),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Color(0xFF0A1408),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.watch_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Scoring live sul polso',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPattern extends StatelessWidget {
  const _HeroPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HeroPatternPainter());
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Court net / diagonal energy lines — cheap strokes only.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 6; i++) {
      final y = size.height * 0.15 + i * 22.0;
      canvas.drawLine(
        Offset(size.width * 0.35, y),
        Offset(size.width + 20, y + 28),
        line,
      );
    }
    final arc = Paint()
      ..color = RallyColors.lime.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.2),
        radius: 54,
      ),
      math.pi * 0.6,
      math.pi * 1.1,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResumeMatchCard extends StatelessWidget {
  const _ResumeMatchCard({required this.match});

  final MatchRow match;

  @override
  Widget build(BuildContext context) {
    final paused = match.status == MatchStatus.paused.wire;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _GlassCard(
        accent: RallyColors.lime,
        onTap: () => context.push(
          match.duoMode
              ? '/match/${match.id}/duo'
              : '/match/${match.id}/live'
                    '${paused ? '?resume=1' : ''}',
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: RallyColors.lime.withValues(alpha: 0.14),
                border: Border.all(
                  color: RallyColors.lime.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                paused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: RallyColors.lime,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RallyColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        paused ? 'IN PAUSA' : 'LIVE',
                        style: TextStyle(
                          color: RallyColors.lime.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    match.duoMode
                        ? 'Partita Duo in corso'
                        : 'Partita in corso',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    match.opponentLabel.isEmpty
                        ? 'Riprendi dal telefono o dal watch'
                        : 'vs ${match.opponentLabel}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: RallyColors.lime),
          ],
        ),
      ),
    );
  }
}

class _FindPlayersCard extends StatelessWidget {
  const _FindPlayersCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/social'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF12253A), Color(0xFF0E1A28)],
            ),
            border: Border.all(
              color: RallyColors.cyan.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: RallyColors.cyan.withValues(alpha: 0.12),
                    border: Border.all(
                      color: RallyColors.cyan.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: RallyColors.cyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MATCHMAKING',
                        style: TextStyle(
                          color: RallyColors.cyan.withValues(alpha: 0.95),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Trova partner di gioco',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Livello · disponibilità · stile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RallyColors.cyan.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: RallyColors.cyan,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.me,
    required this.hasTeam,
    required this.watchConnected,
  });

  final Player? me;
  final bool hasTeam;
  final bool watchConnected;

  @override
  Widget build(BuildContext context) {
    final roleReady =
        (me?.preferredRole ?? PadelRole.undefined.wire) !=
        PadelRole.undefined.wire;
    final items = [
      _SetupItem(
        title: 'Imposta ruolo',
        subtitle: 'Sinistra, destra o flex',
        done: roleReady,
        onTap: () => context.push('/profile/edit'),
      ),
      _SetupItem(
        title: 'Crea il tuo team',
        subtitle: 'Compagni abituali',
        done: hasTeam,
        onTap: () => context.push('/teams'),
      ),
      _SetupItem(
        title: 'Collega smartwatch',
        subtitle: 'Scoring al polso',
        done: watchConnected,
        onTap: () => context.push('/devices/setup'),
      ),
    ];
    final done = items.where((i) => i.done).length;
    final progress = done / items.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF111A26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Setup iniziale',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '$done di ${items.length}',
                style: TextStyle(
                  color: RallyColors.lime.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(RallyColors.lime),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            _SetupStep(item: items[i]),
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SetupItem {
  const _SetupItem({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.item});

  final _SetupItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: !item.done,
      enabled: !item.done,
      label: item.title,
      value: item.done ? 'Completato' : 'In sospeso',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.done ? null : item.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: item.done
                  ? RallyColors.lime.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: item.done
                    ? RallyColors.lime.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.done
                        ? RallyColors.lime
                        : Colors.white.withValues(alpha: 0.06),
                    border: item.done
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                  ),
                  child: item.done
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF071009),
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.done ? 'Completato' : item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.done
                              ? RallyColors.lime.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.done)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyOverviewCard extends StatelessWidget {
  const _WeeklyOverviewCard({required this.week});

  final _ThisWeek week;

  @override
  Widget build(BuildContext context) {
    final empty = week.matches == 0;
    return _GlassCard(
      accent: RallyColors.lime,
      onTap: () => empty
          ? context.push('/match/new')
          : context.go('/analytics'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IN CAMPO QUESTA SETTIMANA',
                      style: TextStyle(
                        color: RallyColors.lime.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      empty
                          ? 'Nessun match ancora'
                          : week.matches == 1
                          ? '1 partita completata'
                          : '${week.matches} partite completate',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: RallyColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: RallyColors.cyan.withValues(alpha: 0.28),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dettagli',
                      style: TextStyle(
                        color: RallyColors.cyan,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: RallyColors.cyan, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 350;
              final metrics = _WeeklyMetricsRow(week: week);
              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        _GoalRing(percent: week.goalProgress, size: 100),
                        const SizedBox(width: 16),
                        Expanded(child: _GoalTargetPill(matches: week.matches)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    metrics,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _GoalRing(percent: week.goalProgress, size: 108),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        metrics,
                        const SizedBox(height: 12),
                        _GoalTargetPill(matches: week.matches),
                      ],
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
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.percent, this.size = 68});

  final double percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = percent.clamp(0.0, 1.0);
    final percentage = (normalized * 100).round();
    return Semantics(
      label: 'Obiettivo settimanale: $percentage per cento',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: size >= 96 ? 8 : 7,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: normalized,
                strokeWidth: size >= 96 ? 8 : 7,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(RallyColors.lime),
                strokeCap: StrokeCap.round,
              ),
            ),
            Container(
              width: size - 22,
              height: size - 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B1420),
                border: Border.all(
                  color: RallyColors.lime.withValues(alpha: 0.1),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: size >= 96 ? 24 : 17,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    'goal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: size >= 96 ? 11 : 10,
                      fontWeight: FontWeight.w700,
                    ),
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

class _WeeklyMetricsRow extends StatelessWidget {
  const _WeeklyMetricsRow({required this.week});

  final _ThisWeek week;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WeeklyMetric(
            value: '${week.matches}',
            label: 'match',
            color: RallyColors.lime,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _WeeklyMetric(
            value: '${week.minutes}',
            label: 'minuti',
            color: RallyColors.cyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _WeeklyMetric(
            value: '${week.trainings}',
            label: 'training',
            color: RallyColors.training,
          ),
        ),
      ],
    );
  }
}

class _WeeklyMetric extends StatelessWidget {
  const _WeeklyMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalTargetPill extends ConsumerStatefulWidget {
  const _GoalTargetPill({required this.matches});

  final int matches;

  @override
  ConsumerState<_GoalTargetPill> createState() => _GoalTargetPillState();
}

class _GoalTargetPillState extends ConsumerState<_GoalTargetPill>
    with SingleTickerProviderStateMixin {
  static const _kvKey = 'weekly_goal_celebrated_iso_week';
  bool _celebrating = false;
  AnimationController? _pulse;

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  String _isoWeekKey(DateTime d) {
    // ISO-ish week id for one-shot celebration per calendar week (local).
    final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)));
    final firstDay = DateTime(thursday.year);
    final week =
        ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    return '${thursday.year}-W$week';
  }

  Future<void> _maybeCelebrate() async {
    if (widget.matches < 3 || _celebrating) return;
    final kv = ref.read(keyValueRepoProvider);
    final key = _isoWeekKey(DateTime.now());
    final seen = await kv.get(_kvKey);
    if (seen == key || !mounted) return;
    await kv.set(_kvKey, key);
    if (!mounted) return;
    // Battery: one-shot haptic + brief pulse (no confetti particle loop).
    HapticFeedback.heavyImpact();
    _pulse?.dispose();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    setState(() => _celebrating = true);
    await _pulse!.forward();
    if (!mounted) return;
    setState(() => _celebrating = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obiettivo settimanale raggiunto: 3 match 🎉'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _GoalTargetPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matches >= 3 && oldWidget.matches < 3) {
      unawaited(_maybeCelebrate());
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.matches >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeCelebrate());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Product default: 3 completed matches / week.
    final done = widget.matches >= 3;
    final progressLabel = done ? 'Obiettivo raggiunto' : 'Obiettivo: 3 match';
    final scale = _celebrating && _pulse != null
        ? Tween<double>(begin: 1, end: 1.04).animate(
            CurvedAnimation(parent: _pulse!, curve: Curves.easeOutBack),
          )
        : const AlwaysStoppedAnimation(1.0);

    return ScaleTransition(
      scale: scale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: RallyColors.lime.withValues(alpha: done ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: RallyColors.lime.withValues(alpha: done ? 0.45 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.flag_rounded,
              color: RallyColors.lime,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RallyColors.lime,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${widget.matches}/3',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGrid extends StatelessWidget {
  const _HomeGrid({
    required this.latestMatch,
    required this.team,
    required this.training,
    required this.insights,
  });

  final MatchRow? latestMatch;
  final Team? team;
  final Training? training;
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phone dashboards stay single-column: these are navigation surfaces,
        // not compact metric tiles. The grid only returns when there is true
        // tablet width, so copy and actions keep enough breathing room.
        final twoColumns = constraints.maxWidth >= 720;
        if (!twoColumns) {
          return Column(
            children: [
              SizedBox(
                height: 168,
                child: _LastMatchMiniCard(match: latestMatch),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: _ProgressMiniCard(insights: insights),
              ),
              const SizedBox(height: 12),
              SizedBox(height: 168, child: _TeamMiniCard(team: team)),
              const SizedBox(height: 12),
              SizedBox(
                height: 184,
                child: _TrainingMiniCard(training: training),
              ),
            ],
          );
        }
        final cardHeight = (((constraints.maxWidth - 12) / 2) / 1.55).clamp(
          180.0,
          224.0,
        );
        return Column(
          children: [
            SizedBox(
              height: cardHeight,
              child: Row(
                children: [
                  Expanded(child: _LastMatchMiniCard(match: latestMatch)),
                  const SizedBox(width: 12),
                  Expanded(child: _ProgressMiniCard(insights: insights)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight,
              child: Row(
                children: [
                  Expanded(flex: 10, child: _TeamMiniCard(team: team)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 11,
                    child: _TrainingMiniCard(training: training),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LastMatchMiniCard extends StatelessWidget {
  const _LastMatchMiniCard({required this.match});

  final MatchRow? match;

  @override
  Widget build(BuildContext context) {
    final summary = match == null ? null : MatchRepository.summaryOf(match!);
    final won = match?.wonByUs;
    return _GlassCard(
      accent: RallyColors.cyan,
      onTap: match == null
          ? () => context.push('/match/new')
          : () => context.push('/match/${match!.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'ULTIMA SFIDA',
            icon: Icons.sports_tennis_rounded,
            color: RallyColors.cyan,
          ),
          const Spacer(),
          Row(
            children: [
              _NeonIcon(
                icon: won == null
                    ? Icons.calendar_month_outlined
                    : won
                    ? Icons.emoji_events_outlined
                    : Icons.replay_outlined,
                color: won == false ? RallyColors.loss : RallyColors.teamThem,
                small: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary == null
                      ? 'Le tue partite appariranno qui dopo la prima sfida.'
                      : '${summary.setsFor}-${summary.setsAgainst} set · ${summary.pointsFor} punti',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.white70,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _OutlinePill(
            label: match == null ? 'Gioca la prima partita' : 'Apri dettagli',
            color: RallyColors.cyan,
          ),
        ],
      ),
    );
  }
}

class _ProgressMiniCard extends StatelessWidget {
  const _ProgressMiniCard({required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    final insight = insights.firstOrNull;
    final empty = insight == null;
    return _GlassCard(
      accent: RallyColors.lime,
      onTap: () => empty
          ? context.push('/match/new')
          : context.go('/analytics'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'INSIGHT',
            icon: Icons.trending_up_rounded,
            color: RallyColors.lime,
          ),
          const Spacer(),
          Row(
            children: [
              _NeonIcon(
                icon: empty
                    ? Icons.bar_chart_rounded
                    : insight.direction == InsightDirection.regression
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                color: insight?.direction == InsightDirection.regression
                    ? RallyColors.loss
                    : RallyColors.lime,
                small: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight?.text ??
                      'Registra il primo match per sbloccare le analisi.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.white70,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _OutlinePill(
            label: empty ? 'Registra il primo match' : 'Apri analisi',
            color: const Color(0xFF40F3E8),
          ),
        ],
      ),
    );
  }
}

class _TeamMiniCard extends StatelessWidget {
  const _TeamMiniCard({required this.team});

  final Team? team;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: RallyColors.teamGold,
      onTap: () => team == null
          ? context.push('/teams')
          : context.push('/teams/${team!.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'IL TUO TEAM',
            icon: Icons.groups_2_rounded,
            color: RallyColors.teamGold,
          ),
          const Spacer(),
          Row(
            children: [
              _NeonIcon(
                icon: Icons.shield_outlined,
                color: RallyColors.teamGold,
                small: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  team == null
                      ? 'Non hai ancora un team. Crea il tuo e invita i compagni.'
                      : '${team!.name}\nPronto per la prossima partita.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.white70,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _OutlinePill(
            label: team == null ? 'Crea il tuo team' : 'Apri team',
            color: RallyColors.teamGold,
          ),
        ],
      ),
    );
  }
}

class _TrainingMiniCard extends StatelessWidget {
  const _TrainingMiniCard({required this.training});

  final Training? training;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: RallyColors.training,
      onTap: () => context.go('/training'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/rallymate_pro_fitness_cover.jpg',
              fit: BoxFit.cover,
              cacheWidth: 720,
              filterQuality: FilterQuality.low,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF20E1724),
                    Color(0xB3392B13),
                    Color(0x73351C0D),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    'SESSIONE CONSIGLIATA',
                    icon: Icons.fitness_center_rounded,
                    color: RallyColors.training,
                  ),
                  const Spacer(),
                  Text(
                    training?.title ?? 'Riscaldamento + volée di controllo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.signal_cellular_alt_rounded,
                        color: RallyColors.training,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          training?.premium == true
                              ? 'Premium'
                              : _trainingLevel(training),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${training?.durationMinutes ?? 18} min',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: RallyColors.training,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Color(0xFF071009),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _trainingLevel(Training? training) {
    return switch (training?.role) {
      'LEFT' => 'Sinistra',
      'RIGHT' => 'Destra',
      'FLEX' => 'Flex',
      _ => 'Principiante',
    };
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.hasMatch,
    required this.hasTeam,
    required this.hasWatch,
  });

  final bool hasMatch;
  final bool hasTeam;
  final bool hasWatch;

  @override
  Widget build(BuildContext context) {
    final tip = !hasMatch
        ? 'Registra una partita breve: anche un set solo sblocca insight utili.'
        : !hasTeam
        ? 'Crea il tuo team abituale: le analisi diventano più precise in coppia.'
        : !hasWatch
        ? 'Collega lo smartwatch per segnare i punti senza interrompere il gioco.'
        : 'Mantieni il gomito alto sulla volée: più controllo, meno errori.';
    final ctaLabel = !hasMatch
        ? 'Inizia ora'
        : !hasTeam
        ? 'Crea team'
        : !hasWatch
        ? 'Collega watch'
        : 'Apri regole';
    final action = !hasMatch
        ? () => context.push('/match/new')
        : !hasTeam
        ? () => context.push('/teams')
        : !hasWatch
        ? () => context.push('/devices/setup')
        : () => context.push('/rules');

    return _GlassCard(
      accent: RallyColors.lime,
      onTap: action,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: RallyColors.lime.withValues(alpha: 0.08),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Mascot3d(
              kind: Mascot3dKind.tip,
              size: 78,
              borderRadius: BorderRadius.all(Radius.circular(18)),
              // Opaque: near-transparent WebView bg blanks hybrid composition.
              backgroundColor: Color(0xFF0B1524),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COACH DEL GIORNO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RallyColors.lime.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tip,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _OutlinePill(label: ctaLabel, color: RallyColors.lime),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: RallyColors.lime.withValues(alpha: 0.7),
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fill = accent == null
        ? const Color(0xFF121C2A)
        : Color.alphaBlend(
            accent!.withValues(alpha: 0.07),
            const Color(0xFF121C2A),
          );
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: fill,
              border: Border.all(
                color:
                    accent?.withValues(alpha: 0.22) ??
                    Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _NeonIcon extends StatelessWidget {
  const _NeonIcon({
    required this.icon,
    required this.color,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 46.0 : 56.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(small ? 14 : 16),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.1),
      ),
      child: Icon(icon, color: color, size: small ? 24 : 30),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, {this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color ?? const Color(0xFFB8C5D8),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        if (icon != null) Icon(icon, size: 17, color: color ?? Colors.white70),
      ],
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 18),
        ],
      ),
    );
  }
}

class _ThisWeek {
  const _ThisWeek({
    required this.matches,
    required this.minutes,
    required this.trainings,
  });

  final int matches;
  final int minutes;
  final int trainings;

  /// Weekly activity goal: three completed matches (product default).
  double get goalProgress => (matches / 3).clamp(0, 1).toDouble();

  static _ThisWeek from({
    required WeeklySummary? weekly,
    required List<MatchSummary> summaries,
    required List<TrainingLog> trainingLogs,
  }) {
    final weekStartMs = weekly?.weekStartMs ?? _currentWeekStartMs();
    final weekSummaries = summaries
        .where((s) => s.endTimeMs >= weekStartMs)
        .toList();
    final trainingThisWeek = trainingLogs
        .where((l) => l.completed && l.dateMs >= weekStartMs)
        .toList();
    final matchMinutes = weekSummaries.fold<int>(
      0,
      (sum, s) => sum + (s.durationMs / 60000).round(),
    );
    final trainingMinutes = trainingThisWeek.fold<int>(
      0,
      (sum, l) => sum + l.minutes,
    );
    return _ThisWeek(
      matches: weekly?.matchesPlayed ?? weekSummaries.length,
      minutes: matchMinutes + trainingMinutes,
      trainings: trainingThisWeek.length,
    );
  }

  static int _currentWeekStartMs() {
    final now = DateTime.now();
    final weekStart = now
        .subtract(Duration(days: now.weekday - 1))
        .copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    return weekStart.millisecondsSinceEpoch;
  }
}
