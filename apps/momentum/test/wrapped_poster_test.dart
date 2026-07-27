/// Il poster Wrapped viene condiviso come immagine: un overflow o un widget
/// che sfora non si vede in anteprima ma finisce dentro il PNG pubblicato.
/// Questi test renderizzano davvero il poster a dimensione di export nei casi
/// limite (nomi lunghi, tre set, allenamento libero, dati assenti).
///
/// `WRAPPED_POSTER_DUMP_DIR=/percorso flutter test test/wrapped_poster_test.dart`
/// salva anche i PNG per un'ispezione visiva.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/features/wrapped/wrapped_poster.dart';
import 'package:rally_core/rally_core.dart';

/// Serie di momentum plausibile: parte in equilibrio, va sotto, rimonta.
List<int> _momentum() {
  final series = <int>[];
  var diff = 0;
  for (var i = 0; i < 96; i++) {
    diff += switch (i % 7) {
      0 || 1 || 4 => 1,
      2 || 5 => -1,
      _ => i < 40 ? -1 : 1,
    };
    series.add(diff);
  }
  return series;
}

MatchWrappedData _card({
  bool won = true,
  bool freePlay = false,
  List<WrappedSetScore> sets = const [
    WrappedSetScore(us: 6, them: 4),
    WrappedSetScore(us: 4, them: 6),
    WrappedSetScore(us: 7, them: 6, tieBreakUs: 7, tieBreakThem: 5),
  ],
  List<WrappedStat> stats = const [
    WrappedStat(label: 'Break point', value: '60%', detail: '3/5'),
    WrappedStat(label: 'Al servizio', value: '64%', detail: '41/64'),
    WrappedStat(label: 'Tie-break', value: '58%', detail: '7/12'),
  ],
  String teamLabel = 'vs Marco & Giulia',
  String headline = 'Rimonta da campioni: match point annullato!',
  String? keyMoment = 'Match point annullato sul 4-5 del terzo set',
  List<int> momentum = const [],
}) {
  return MatchWrappedData(
    resultLine: '6-4 4-6 7-6',
    durationMinutes: 92,
    teamLabel: teamLabel,
    totalPoints: 143,
    bestStreak: 7,
    keyMoment: keyMoment,
    clutchScore: 78,
    opponentDifficulty: OpponentDifficulty.harder,
    rolePlayed: PadelRole.left,
    statisticalMvp: 'Clutch score 78/100',
    headline: headline,
    won: won,
    sets: sets,
    pointsWon: 76,
    pointsLost: 67,
    momentum: momentum.isEmpty ? _momentum() : momentum,
    stats: stats,
    formatLabel: 'Golden point — meglio di 3',
    playedAt: DateTime(2026, 7, 26, 19, 30),
    freePlay: freePlay,
  );
}

/// Nel motore di test il font predefinito disegna blocchi pieni: per un
/// controllo visivo servono glifi veri, quindi in fase di dump si carica un
/// font di sistema. Nei test normali resta il font di default, che essendo
/// monospazio pieno è anche il caso peggiore per gli ingombri.
const _previewFontFamily = 'WrappedPreview';
var _previewFontLoaded = false;

Future<bool> _loadPreviewFont() async {
  if (_previewFontLoaded) return true;
  const candidates = [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Supplemental/Helvetica.ttc',
    '/System/Library/Fonts/Geneva.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader(_previewFontFamily)
      ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
    _previewFontLoaded = true;
    return true;
  }
  return false;
}

Future<void> _render(
  WidgetTester tester, {
  required MatchWrappedData card,
  required WrappedPosterFormat format,
  required String name,
  bool watermark = false,
}) async {
  // Dimensione logica dell'export: 1080 px a devicePixelRatio 3.
  //
  // La larghezza è imposta dal SizedBox, non dalla superficie di test: il
  // poster è proporzionale a essa e `setSurfaceSize` in questo contesto può
  // restare appeso in teardown.
  const width = 360.0;
  final height = width / format.aspectRatio;
  // La superficie di test predefinita è 800x600: una story 9:16 è più alta e
  // finirebbe fuori dal viewport, con un errore in flushSemantics che non ha
  // nulla a che vedere con il layout del poster.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height + 40);
  addTearDown(tester.view.reset);

  final dumpDir = Platform.environment['WRAPPED_POSTER_DUMP_DIR'];
  final dumping = dumpDir != null && dumpDir.isNotEmpty;
  final realFont = dumping && await _loadPreviewFont();

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: realFont ? _previewFontFamily : null,
          color: const Color(0xFFFFFFFF),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: width,
              child: WrappedPoster(
                card: card,
                format: format,
                showWatermark: watermark,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  // Il logo è un asset: senza decodifica il poster esce senza marchio, che è
  // esattamente il difetto che questi PNG devono poter mostrare.
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(wrappedLogoAsset),
      key.currentContext!,
    );
  });
  await tester.pump();

  // Un overflow in un poster condiviso finisce dentro il PNG: qui deve
  // fallire il test, non arrivare su Instagram.
  expect(tester.takeException(), isNull, reason: 'overflow o errore in $name');

  if (!dumping) return;
  // La codifica dell'immagine è lavoro asincrono vero: fuori da `runAsync`
  // la zona di test finta non lo porta a termine e il test resta appeso.
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(dumpDir).createSync(recursive: true);
    File(
      '$dumpDir/$name.png',
    ).writeAsBytesSync(Uint8List.view(bytes!.buffer), flush: true);
  });
}

void main() {
  testWidgets('poster feed 4:5 con tre set e tie-break', (tester) async {
    await _render(
      tester,
      card: _card(),
      format: WrappedPosterFormat.post,
      name: 'post_win',
      watermark: true,
    );
  });

  testWidgets('poster story 9:16 con tre set e tie-break', (tester) async {
    await _render(
      tester,
      card: _card(),
      format: WrappedPosterFormat.story,
      name: 'story_win',
      watermark: true,
    );
  });

  testWidgets('sconfitta a due set', (tester) async {
    await _render(
      tester,
      card: _card(
        won: false,
        sets: const [
          WrappedSetScore(us: 4, them: 6),
          WrappedSetScore(us: 6, them: 7, tieBreakUs: 6, tieBreakThem: 8),
        ],
        headline: 'Sconfitta di misura: nei punti decisivi c\'eri.',
        keyMoment: null,
      ),
      format: WrappedPosterFormat.post,
      name: 'post_loss',
    );
  });

  testWidgets('super tie-break decisivo', (tester) async {
    await _render(
      tester,
      card: _card(
        sets: const [
          WrappedSetScore(us: 6, them: 3),
          WrappedSetScore(us: 4, them: 6),
          WrappedSetScore(
            us: 1,
            them: 0,
            tieBreakUs: 10,
            tieBreakThem: 8,
            isSuperTieBreak: true,
          ),
        ],
      ),
      format: WrappedPosterFormat.post,
      name: 'post_super_tb',
    );
  });

  testWidgets('allenamento libero senza set', (tester) async {
    await _render(
      tester,
      card: _card(
        freePlay: true,
        sets: const [],
        keyMoment: null,
        stats: const [],
        headline: 'Sessione di allenamento: 143 punti giocati.',
      ),
      format: WrappedPosterFormat.post,
      name: 'post_training',
    );
  });

  testWidgets('nessuna metrica con campione e nomi lunghi', (tester) async {
    await _render(
      tester,
      card: _card(
        stats: const [],
        momentum: const [0, 1],
        keyMoment: null,
        teamLabel:
            'vs Alessandro Maria Bonaventura & Giovanni Battista Della Rovere',
        headline:
            'Una partita lunghissima con un titolo che non finisce mai e '
            'continua ancora per parecchie parole di troppo.',
      ),
      format: WrappedPosterFormat.post,
      name: 'post_edge',
    );
  });

  testWidgets('cinque set non deformano lo scoreboard', (tester) async {
    await _render(
      tester,
      card: _card(
        sets: const [
          WrappedSetScore(us: 6, them: 4),
          WrappedSetScore(us: 4, them: 6),
          WrappedSetScore(us: 6, them: 3),
          WrappedSetScore(us: 3, them: 6),
          WrappedSetScore(us: 7, them: 6, tieBreakUs: 7, tieBreakThem: 4),
        ],
      ),
      format: WrappedPosterFormat.post,
      name: 'post_five_sets',
    );
  });
}
