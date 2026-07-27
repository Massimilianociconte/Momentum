/// Momentum Wrapped (PRD Modulo G): card partita condivisibile come immagine.
/// Free: card con firma discreta. Plus: illimitato + link pubblico.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../core/theme.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import '../match_detail/match_detail_screen.dart';
import 'wrapped_poster.dart';

/// Larghezza in pixel dell'immagine esportata: 1080 è la larghezza nativa di
/// un post Instagram, quindi 1080x1350 (feed) e 1080x1920 (story).
const _exportWidthPx = 1080.0;

class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  WrappedPosterFormat _format = WrappedPosterFormat.post;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Il logo è un asset: se non è ancora decodificato quando si cattura il
    // RepaintBoundary, l'immagine condivisa esce senza marchio.
    unawaited(precacheImage(const AssetImage(wrappedLogoAsset), context));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(matchDetailProvider(widget.matchId));
    final ents = ref.watch(entitlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Momentum Wrapped')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (d) {
          final card = _buildCard(d);
          final media = MediaQuery.of(context);
          // La story è alta: si limita l'altezza dell'anteprima così resta
          // tutta visibile senza scroll dentro la card.
          final previewMaxHeight = media.size.height * 0.62;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _FormatSwitcher(
                value: _format,
                onChanged: _sharing
                    ? null
                    : (value) => setState(() => _format = value),
              ),
              const SizedBox(height: 14),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: previewMaxHeight),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: WrappedPoster(
                      card: card,
                      format: _format,
                      showWatermark: !ents.unlimitedWrapped,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _sharing ? null : () => _share(card),
                icon: const Icon(Icons.ios_share),
                label: Text(
                  _sharing ? 'Preparo…' : 'Condividi ${_format.label}',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _sharing ? null : () => _copyCaption(card),
                icon: const Icon(Icons.short_text),
                label: const Text('Copia didascalia'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Colors.white,
                ),
              ),
              if (ents.unlimitedWrapped && CloudConfig.supabaseConfigured) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _sharing ? null : () => _publishLink(card),
                  icon: const Icon(Icons.link),
                  label: const Text('Crea link pubblico'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                ents.unlimitedWrapped
                    ? 'Immagine esportata a ${_exportWidthPx.toInt()} px di '
                          'larghezza: nessuna compressione visibile su '
                          'Instagram.'
                    : 'Piano Free: una card a settimana, con firma Momentum. '
                          'Con Plus card illimitate, senza firma, e link '
                          'pubblico.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          );
        },
      ),
    );
  }

  MatchWrappedData _buildCard(
    ({
      MatchRow row,
      PadelScoringEngine engine,
      MatchStats stats,
      AdvancedMatchAnalysis advanced,
    })
    d,
  ) {
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

    return MatchWrappedData.build(
      stats: d.stats,
      ourTeam: myTeam,
      won: won,
      resultLine: resultLine,
      teamLabel: d.row.opponentLabel.isEmpty
          ? 'Partita di padel'
          : 'vs ${d.row.opponentLabel}',
      difficulty: OpponentDifficulty.fromScore(d.row.opponentDifficulty),
      role: PadelRole.fromWire(d.row.myRole),
      completedSets: s.completedSets,
      formatLabel: d.engine.format.name,
      playedAt: d.row.startTimeMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(d.row.startTimeMs!),
      freePlay: d.engine.format.freePlay,
    );
  }

  /// Didascalia pronta da incollare: risultato vero, niente claim inventati.
  String _caption(MatchWrappedData card) {
    final parts = <String>[
      card.headline,
      if (!card.freePlay) 'Risultato: ${card.resultLine}',
      if (card.keyMoment != null) card.keyMoment!,
      '${card.totalPoints} punti giocati · clutch ${card.clutchScore}/100',
      '#padel #padeltime #Momentum',
    ];
    return parts.join('\n');
  }

  Future<void> _copyCaption(MatchWrappedData card) async {
    await Clipboard.setData(ClipboardData(text: _caption(card)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Didascalia copiata ✍️')),
    );
  }

  /// Link pubblico Momentum Wrapped (PRD G5): pagina /recap + deep link.
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
          ShareParams(text: '${card.headline}\n${result.url} #padel #Momentum'),
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
      // Seconda garanzia: la condivisione può partire prima che il precache
      // di didChangeDependencies sia arrivato in fondo.
      if (mounted) {
        await precacheImage(const AssetImage(wrappedLogoAsset), context);
      }
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      // L'anteprima è larga quanto lo schermo lo consente: si esporta sempre
      // a 1080 px indipendentemente dal device, così la qualità non dipende
      // dal telefono di chi condivide.
      final pixelRatio = (_exportWidthPx / boundary.size.width).clamp(1.0, 6.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final suffix = _format == WrappedPosterFormat.story ? 'story' : 'post';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.view(bytes.buffer),
              mimeType: 'image/png',
              name: 'momentum_wrapped_$suffix.png',
            ),
          ],
          text: _caption(card),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<bool> _consumeFreeWrappedShare() async {
    final now = DateTime.now();
    final week =
        '${now.year}-W${((now.difference(DateTime(now.year)).inDays) / 7).floor() + 1}';
    final key = 'wrapped_share_count_$week';
    final kv = ref.read(keyValueRepoProvider);
    final count = int.tryParse(await kv.get(key) ?? '0') ?? 0;
    if (count >= Entitlements.freeWrappedPerWeek) return false;
    await kv.set(key, '${count + 1}');
    return true;
  }
}

class _FormatSwitcher extends StatelessWidget {
  const _FormatSwitcher({required this.value, required this.onChanged});

  final WrappedPosterFormat value;
  final ValueChanged<WrappedPosterFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WrappedPosterFormat>(
      segments: [
        for (final format in WrappedPosterFormat.values)
          ButtonSegment(
            value: format,
            label: Text(format.label),
            icon: Icon(
              format == WrappedPosterFormat.story
                  ? Icons.smartphone
                  : Icons.crop_portrait,
              size: 18,
            ),
          ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: RallyColors.lime.withValues(alpha: 0.2),
        selectedForegroundColor: RallyColors.lime,
        foregroundColor: Colors.white70,
      ),
    );
  }
}
