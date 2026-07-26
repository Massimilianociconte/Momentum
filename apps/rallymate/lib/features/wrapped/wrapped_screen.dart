/// Padelandia Wrapped (PRD Modulo G): card partita condivisibile come immagine.
/// Free: card base con watermark. Plus: illimitato + link pubblico.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import '../match_detail/match_detail_screen.dart';

class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(matchDetailProvider(widget.matchId));
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Padelandia Wrapped')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (d) {
          final s = d.engine.state;
          // Duo Mode: la timeline è canonica (A/B), la card è sempre nella
          // prospettiva del team assegnato a questo device.
          final myTeam = d.row.duoMode && d.row.duoTeam != null
              ? TeamId.fromWire(d.row.duoTeam!)
              : TeamId.a;
          final mirror = myTeam == TeamId.b;
          final won = s.winner == myTeam;
          final resultLine = s.completedSets.isEmpty
              ? (mirror
                    ? '${s.freePlayB}-${s.freePlayA}'
                    : '${s.freePlayA}-${s.freePlayB}')
              : s.completedSets
                    .map(
                      (x) => x.isSuperTieBreak
                          ? (mirror
                                ? '${x.tieBreakB}-${x.tieBreakA}'
                                : '${x.tieBreakA}-${x.tieBreakB}')
                          : (mirror
                                ? '${x.gamesB}-${x.gamesA}'
                                : '${x.gamesA}-${x.gamesB}'),
                    )
                    .join(' ');
          final card = MatchWrappedData.build(
            stats: d.stats,
            ourTeam: myTeam,
            won: won,
            resultLine: resultLine,
            teamLabel: d.row.opponentLabel.isEmpty
                ? 'Padelandia match'
                : 'vs ${d.row.opponentLabel}',
            difficulty: OpponentDifficulty.fromScore(d.row.opponentDifficulty),
            role: PadelRole.fromWire(d.row.myRole),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: _WrappedCard(card: card, won: won),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sharing ? null : () => _share(card),
                icon: const Icon(Icons.ios_share),
                label: Text(_sharing ? 'Preparo…' : 'Condividi immagine'),
              ),
              const SizedBox(height: 8),
              if (ents.unlimitedWrapped && CloudConfig.supabaseConfigured)
                OutlinedButton.icon(
                  onPressed: _sharing ? null : () => _publishLink(card),
                  icon: const Icon(Icons.link),
                  label: const Text('Crea link pubblico'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 8),
              if (!ents.unlimitedWrapped)
                const Text(
                  'Piano Free: card con watermark. Con Plus ottieni card '
                  'illimitate e link pubblici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Link pubblico Padelandia Wrapped (PRD G5): pagina /recap + deep link.
  Future<void> _publishLink(MatchWrappedData card) async {
    setState(() => _sharing = true);
    try {
      final result = await WrappedLinkService.publish(
        type: 'MATCH',
        payload: {
          'headline': card.headline,
          'resultLine': card.resultLine,
          'teamLabel': card.teamLabel,
          'totalPoints': card.totalPoints,
          'bestStreak': card.bestStreak,
          'clutchScore': card.clutchScore,
          if (card.keyMoment != null) 'keyMoment': card.keyMoment,
        },
      );
      if (!mounted) return;
      if (result.url != null) {
        await Clipboard.setData(ClipboardData(text: result.url!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copiato negli appunti 🔗')),
          );
        }
        await SharePlus.instance.share(
          ShareParams(
            text: '${card.headline}\n${result.url} #padel #Padelandia',
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.error ?? 'Errore')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _share(MatchWrappedData card) async {
    final ents = ref.read(entitlementsProvider);
    if (!ents.unlimitedWrapped) {
      final allowed = await _consumeFreeWrappedShare();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hai già usato la card Free di questa settimana. '
              'Passa a Plus per card illimitate.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.view(bytes.buffer),
              mimeType: 'image/png',
              name: 'rallymate_wrapped.png',
            ),
          ],
          text: '${card.headline} #padel #Padelandia',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<bool> _consumeFreeWrappedShare() async {
    final now = DateTime.now();
    final week = '${now.year}-W${((now.difference(DateTime(now.year)).inDays) / 7).floor() + 1}';
    final key = 'wrapped_share_count_$week';
    final kv = ref.read(keyValueRepoProvider);
    final count = int.tryParse(await kv.get(key) ?? '0') ?? 0;
    if (count >= Entitlements.freeWrappedPerWeek) return false;
    await kv.set(key, '${count + 1}');
    return true;
  }
}

class _WrappedCard extends ConsumerWidget {
  const _WrappedCard({required this.card, required this.won});
  final MatchWrappedData card;
  final bool won;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ents = ref.watch(entitlementsProvider);
    return AspectRatio(
      aspectRatio: 4 / 5, // Instagram-friendly
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: won
                ? [const Color(0xFF0E5AA7), const Color(0xFF0C1220)]
                : [const Color(0xFF37246B), const Color(0xFF0C1220)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎾', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                const Text(
                  'Padelandia',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  won ? 'VITTORIA' : 'BATTAGLIA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: won ? RallyColors.lime : Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.resultLine,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.teamLabel,
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Text(
              card.headline,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (card.keyMoment != null) ...[
              const SizedBox(height: 8),
              Text(
                '🔥 ${card.keyMoment}',
                style: const TextStyle(fontSize: 13.5, color: Colors.white70),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                _chip('${card.totalPoints} punti'),
                const SizedBox(width: 8),
                _chip('Streak ${card.bestStreak}'),
                const SizedBox(width: 8),
                _chip('Clutch ${card.clutchScore}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(card.statisticalMvp, accent: true),
                const Spacer(),
                if (!ents.unlimitedWrapped)
                  const Text(
                    'Padelandia',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? RallyColors.lime.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent ? RallyColors.lime : Colors.white,
        ),
      ),
    );
  }
}
