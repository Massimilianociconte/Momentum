/// Poster condivisibile di Momentum Wrapped.
///
/// Tutto quello che compare qui viene da dati reali della partita: punteggio
/// set per set, differenziale punti punto per punto, metriche con campione.
/// Una metrica senza campione non viene inventata: sparisce dal poster.
///
/// Il layout è proporzionale alla larghezza (`_u`), così lo stesso albero di
/// widget rende identico a 1080x1350 (feed) e 1080x1920 (story) e alla
/// risoluzione di cattura, senza overflow.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';

/// Logo originale dell'app usato nel poster. Esposto perché chi cattura
/// l'immagine deve precaricarlo: un asset non ancora decodificato produce un
/// poster senza marchio.
const String wrappedLogoAsset = 'assets/logo.png';

enum WrappedPosterFormat {
  /// Post di feed 4:5, il formato con più superficie su Instagram.
  post(4 / 5, 'Post 4:5'),

  /// Story / Reel 9:16 a schermo pieno.
  story(9 / 16, 'Story 9:16');

  const WrappedPosterFormat(this.aspectRatio, this.label);

  final double aspectRatio;
  final String label;
}

class WrappedPoster extends StatelessWidget {
  const WrappedPoster({
    super.key,
    required this.card,
    required this.format,
    this.showWatermark = false,
  });

  final MatchWrappedData card;
  final WrappedPosterFormat format;

  /// Piano Free: firma discreta in basso, non un timbro sopra la card.
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: format.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final u = constraints.maxWidth / 100;
          final tall = format == WrappedPosterFormat.story;
          // Spaziatura fra i blocchi bassi. Sul 4:5 il budget verticale è
          // stretto: ogni unità recuperata qui finisce nel grafico, che è
          // l'elemento con più resa visiva.
          final gap = u * (tall ? 6 : 3);
          return ClipRRect(
            borderRadius: BorderRadius.circular(u * 6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _PosterBackdrop(),
                CustomPaint(painter: _CourtLinesPainter()),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    u * 8,
                    u * (tall ? 10 : 8),
                    u * 8,
                    u * (tall ? 9 : 7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(u: u, card: card),
                      SizedBox(height: u * (tall ? 8 : 5)),
                      _Outcome(u: u, card: card),
                      SizedBox(height: u * 3),
                      _Scoreline(u: u, card: card, tall: tall),
                      SizedBox(height: gap),
                      _Headline(u: u, card: card, tall: tall),
                      SizedBox(height: gap),
                      // Il grafico assorbe l'altezza libera: su 9:16 diventa
                      // il respiro della composizione invece di lasciare un
                      // vuoto al centro del poster.
                      if (card.momentum.length > 3)
                        Expanded(child: _MomentumBlock(u: u, card: card))
                      else
                        // Senza una curva da mostrare lo spazio resterebbe
                        // vuoto: si riempie con un dato che esiste sempre,
                        // non con un grafico finto.
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _HeroCount(u: u, card: card),
                          ),
                        ),
                      SizedBox(height: gap),
                      if (card.pointShare != null) ...[
                        _PointShare(u: u, card: card),
                        SizedBox(height: gap),
                      ],
                      _StatStrip(u: u, card: card, tall: tall),
                      SizedBox(height: gap),
                      _Footer(u: u, card: card, showWatermark: showWatermark),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ sfondo

class _PosterBackdrop extends StatelessWidget {
  const _PosterBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12294A), Color(0xFF0B111D), Color(0xFF080C15)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        // Alone del campo dietro il punteggio.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.55, -0.45),
              radius: 1.05,
              colors: [
                RallyColors.court.withValues(alpha: 0.55),
                RallyColors.court.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // Riflesso lime in basso a destra: tiene insieme brand e profondità.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, 1.0),
              radius: 0.9,
              colors: [
                RallyColors.lime.withValues(alpha: 0.16),
                RallyColors.lime.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        // Vignettatura: spinge l'occhio al centro anche in anteprima piccola.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0.6, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo da padel stilizzato in filigrana.
///
/// Disegnato per intero e dentro i margini: un campo tagliato dai bordi
/// leggerebbe come righe casuali invece che come un campo.
class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.78;
    final h = w * 0.5; // 20 x 10 metri
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.004
      // Filigrana, non decorazione: a 0.055 le righe attraversavano il
      // titolo e sembravano un wireframe rimasto lì per sbaglio.
      ..color = Colors.white.withValues(alpha: 0.03);

    canvas.save();
    // Spostato in basso: sotto il grafico e le metriche c'è superficie
    // libera, sopra ci sono punteggio e titolo.
    canvas.translate(size.width * 0.5, size.height * 0.63);
    canvas.rotate(-0.1);

    final court = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(court, Radius.circular(size.width * 0.006)),
      line,
    );

    // Rete al centro, un filo più marcata.
    canvas.drawLine(
      Offset(0, court.top),
      Offset(0, court.bottom),
      Paint()
        ..strokeWidth = line.strokeWidth
        ..color = Colors.white.withValues(alpha: 0.055),
    );

    // Linee di servizio a 6,95 m dalla rete su una metà da 10 m.
    final serve = (w / 2) * (6.95 / 10);
    canvas.drawLine(Offset(-serve, court.top), Offset(-serve, court.bottom), line);
    canvas.drawLine(Offset(serve, court.top), Offset(serve, court.bottom), line);

    // Linea centrale di servizio, presente solo tra rete e linea di servizio.
    canvas.drawLine(Offset(-serve, 0), Offset(serve, 0), line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CourtLinesPainter oldDelegate) => false;
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({required this.u, required this.card});
  final double u;
  final MatchWrappedData card;

  @override
  Widget build(BuildContext context) {
    // Solo la data: accanto al wordmark lo spazio è poco e qualsiasi altra
    // voce finiva troncata dai tre puntini. Formato e durata stanno nel footer.
    final meta = card.playedAt == null
        ? <String>[]
        : <String>[_formatDate(card.playedAt!)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BrandMark(size: u * 9.2),
        SizedBox(width: u * 2.6),
        Text(
          AppBrand.nameUpper,
          style: TextStyle(
            fontSize: u * 4.2,
            fontWeight: FontWeight.w900,
            letterSpacing: u * 0.22,
            color: Colors.white,
            height: 1,
          ),
        ),
        const Spacer(),
        if (meta.isNotEmpty)
          Flexible(
            child: Text(
              meta.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: u * 2.9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    const months = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

/// Logo originale dell'app, ritagliato sul suo riquadro opaco.
///
/// `assets/logo.png` è 1536x1024 ma l'icona vera occupa solo 589x599 al
/// centro: tutto il resto è alone trasparente. Disegnandolo "come sta" il
/// logo risulterebbe grande poco più di metà del badge, quindi si ingrandisce
/// finché il riquadro opaco riempie lo spazio e si ritaglia l'alone.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  /// Altezza del riquadro opaco sull'altezza dell'asset (599 / 1024).
  static const _tileHeightFraction = 0.585;

  /// Centro verticale del riquadro dentro l'asset, in coordinate di
  /// allineamento: (469.5 - 512) / 512. Orizzontalmente è già centrato.
  static const _tileCenterY = -0.083;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        // Il riquadro del logo è più scuro del poster: senza un bordo chiaro
        // e un alone leggero legherebbe come una macchia nera.
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: size * 0.03,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Transform.scale(
          scale: 1 / _tileHeightFraction,
          alignment: const Alignment(0, _tileCenterY),
          child: Image.asset(
            wrappedLogoAsset,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.medium,
            // Un poster condiviso non può contenere l'icona di errore di
            // Flutter: se l'asset manca si ripiega sul segno vettoriale.
            errorBuilder: (_, _, _) =>
                CustomPaint(painter: _BallMarkPainter()),
          ),
        ),
      ),
    );
  }
}

/// Pallina da padel disegnata a vettore, usata solo come ripiego quando
/// l'asset del logo non è disponibile.
class _BallMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4FF74), RallyColors.lime],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..color = RallyColors.night.withValues(alpha: 0.75);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(-r * 0.45, r), radius: r * 1.05),
      -0.85,
      1.7,
      false,
      seam,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r * 2.45, r), radius: r * 1.05),
      math.pi - 0.85,
      1.7,
      false,
      seam,
    );
  }

  @override
  bool shouldRepaint(covariant _BallMarkPainter oldDelegate) => false;
}

// ------------------------------------------------------------------ esito

class _Outcome extends StatelessWidget {
  const _Outcome({required this.u, required this.card});
  final double u;
  final MatchWrappedData card;

  @override
  Widget build(BuildContext context) {
    final color = card.won ? RallyColors.lime : RallyColors.teamThem;
    final label = card.freePlay
        ? 'ALLENAMENTO'
        : (card.won ? 'VITTORIA' : 'SCONFITTA');
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: u * 3.2,
            vertical: u * 1.5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(u * 2),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: u * 2.9,
              fontWeight: FontWeight.w900,
              letterSpacing: u * 0.2,
              color: color,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: u * 2.5),
        Expanded(
          child: Text(
            card.teamLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: u * 3.4,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- punteggio

class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.u, required this.card, required this.tall});
  final double u;
  final MatchWrappedData card;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    if (card.sets.isEmpty) {
      // Allenamento libero o partita chiusa senza set completati: si mostra
      // il punteggio così com'è, senza costruire set che non esistono.
      return FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          card.resultLine,
          style: TextStyle(
            fontSize: u * (tall ? 21 : 17),
            fontWeight: FontWeight.w900,
            height: 0.95,
            color: Colors.white,
            letterSpacing: -u * 0.2,
          ),
        ),
      );
    }
    // Scala l'intera fila invece di far traboccare il poster: cinque set
    // restano leggibili e allineati come tre.
    return SizedBox(
      height: u * (tall ? 24 : 17),
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        // IntrinsicHeight dà alla riga un'altezza finita: senza, `stretch`
        // sotto il FittedBox propagherebbe un vincolo infinito. Con
        // l'altezza intrinseca il riquadro più alto (super tie-break, che ha
        // una riga in più) detta la misura e il FittedBox rimpicciolisce
        // l'intera fila invece di far traboccare quel riquadro.
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < card.sets.length; i++) ...[
                if (i > 0) SizedBox(width: u * 2.2),
                _SetBox(u: u, set: card.sets[i], tall: tall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetBox extends StatelessWidget {
  const _SetBox({required this.u, required this.set, required this.tall});
  final double u;
  final WrappedSetScore set;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final win = set.wonByUs;
    // In un super tie-break il punteggio che conta è quello del gioco
    // decisivo: mostrare i game (1-0 con un piccolo 8 accanto) era
    // tecnicamente corretto ma illeggibile, e nessuno scrive così un 10-8.
    final superTb = set.isSuperTieBreak &&
        set.tieBreakUs != null &&
        set.tieBreakThem != null;
    final ourScore = superTb ? set.tieBreakUs! : set.us;
    final theirScore = superTb ? set.tieBreakThem! : set.them;
    final tb = superTb ? null : set.tieBreakLoserPoints;
    return Container(
      // Sulla story il punteggio è l'eroe della composizione: riquadri più
      // larghi e cifre più grandi occupano la larghezza disponibile.
      width: u * (tall ? 22 : 17),
      padding: EdgeInsets.symmetric(vertical: u * 1.6, horizontal: u * 1.2),
      decoration: BoxDecoration(
        color: win
            ? RallyColors.lime.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(u * 3),
        border: Border.all(
          color: win
              ? RallyColors.lime.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
          width: u * 0.14,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // La riga in alto è sempre la nostra: il lime segna noi, non chi
          // ha vinto il set. Marcare in lime il 6 degli avversari faceva
          // sembrare che il colore del brand festeggiasse loro.
          _sideRow(ourScore, ours: true, won: win, tieBreak: win ? null : tb),
          SizedBox(height: u * 0.8),
          Container(
            height: u * 0.14,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          SizedBox(height: u * 0.8),
          _sideRow(
            theirScore,
            ours: false,
            won: win,
            tieBreak: win ? tb : null,
          ),
          if (set.isSuperTieBreak) ...[
            SizedBox(height: u * 0.9),
            Text(
              'SUPER TB',
              style: TextStyle(
                fontSize: u * 1.7,
                fontWeight: FontWeight.w800,
                letterSpacing: u * 0.08,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sideRow(
    int games, {
    required bool ours,
    required bool won,
    int? tieBreak,
  }) {
    final color = ours
        ? (won ? RallyColors.lime : Colors.white)
        : Colors.white.withValues(alpha: 0.45);
    // Un super tie-break arriva a due cifre (10-8, 12-10) e con font larghi
    // sfora il riquadro: le cifre si rimpiccioliscono invece di uscire.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$games',
            style: TextStyle(
              fontSize: u * (tall ? 9 : 7.2),
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          if (tieBreak != null)
            Padding(
              padding: EdgeInsets.only(top: u * 0.4, left: u * 0.4),
              child: Text(
                '$tieBreak',
                style: TextStyle(
                  fontSize: u * 2.4,
                  fontWeight: FontWeight.w800,
                  color: color.withValues(alpha: 0.75),
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- headline

class _Headline extends StatelessWidget {
  const _Headline({required this.u, required this.card, required this.tall});
  final double u;
  final MatchWrappedData card;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.headline,
          maxLines: tall ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: u * 4.6,
            fontWeight: FontWeight.w800,
            height: 1.22,
            color: Colors.white,
          ),
        ),
        if (card.keyMoment != null) ...[
          SizedBox(height: u * 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: u * 0.9),
                width: u * 0.6,
                height: u * 3.2,
                decoration: BoxDecoration(
                  color: RallyColors.lime,
                  borderRadius: BorderRadius.circular(u),
                ),
              ),
              SizedBox(width: u * 2),
              Expanded(
                child: Text(
                  card.keyMoment!,
                  maxLines: tall ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: u * 3.1,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------- momentum

class _MomentumBlock extends StatelessWidget {
  const _MomentumBlock({required this.u, required this.card});
  final double u;
  final MatchWrappedData card;

  @override
  Widget build(BuildContext context) {
    final peak = card.momentum.reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(u: u, text: 'ANDAMENTO'),
            const Spacer(),
            Text(
              peak > 0 ? 'Max vantaggio +$peak' : 'Sempre in rincorsa',
              style: TextStyle(
                fontSize: u * 2.6,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: u * 2),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: CustomPaint(painter: _MomentumPainter(card.momentum)),
          ),
        ),
      ],
    );
  }
}

/// Differenziale punti reale: sopra la linea siamo avanti, sotto siamo sotto.
class _MomentumPainter extends CustomPainter {
  _MomentumPainter(this.series);
  final List<int> series;

  /// Massimo numero di punti disegnati.
  ///
  /// Il differenziale cambia di ±1 a ogni punto: su un centinaio di rally la
  /// linea grezza diventa una sega illeggibile. Campionando a indici
  /// equidistanti si disegnano valori reali del differenziale, solo più radi.
  static const _maxPlottedPoints = 44;

  static List<int> _sampled(List<int> source) {
    if (source.length <= _maxPlottedPoints) return source;
    return [
      for (var i = 0; i < _maxPlottedPoints; i++)
        source[(i * (source.length - 1) / (_maxPlottedPoints - 1)).round()],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final series = _sampled(this.series);
    if (series.length < 2) return;

    // Scala sul range reale, non su ±max: una partita sempre in vantaggio
    // occupava solo la metà alta del riquadro e sembrava piatta. Lo zero
    // resta sempre dentro il range, così la linea di parità è leggibile e
    // "sopra/sotto" continua a significare avanti/indietro.
    var minValue = 0;
    var maxValue = 0;
    for (final value in series) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }
    final span = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);
    final pad = span * 0.12;
    final top = maxValue + pad;
    final bottom = minValue - pad;

    double x(int i) => size.width * (i / (series.length - 1));
    double y(num v) => size.height * (1 - (v - bottom) / (top - bottom));
    final zeroY = y(0);

    // Linea di parità.
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = size.height * 0.012,
    );

    // Spline che passa per i punti medi dei segmenti: la linea resta ancorata
    // ai valori campionati e perde le spigolature.
    final path = Path()..moveTo(x(0), y(series.first));
    for (var i = 1; i < series.length; i++) {
      final px = x(i - 1);
      final py = y(series[i - 1]);
      final cx = x(i);
      final cy = y(series[i]);
      path.quadraticBezierTo(px, py, (px + cx) / 2, (py + cy) / 2);
    }
    path.lineTo(x(series.length - 1), y(series.last));

    final fill = Path.from(path)
      ..lineTo(size.width, zeroY)
      ..lineTo(0, zeroY)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RallyColors.lime.withValues(alpha: 0.35),
            RallyColors.lime.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.05
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = RallyColors.lime,
    );

    // Punto finale: dove è finita la partita.
    final endX = x(series.length - 1);
    final endY = y(series.last);
    canvas.drawCircle(
      Offset(endX, endY),
      size.height * 0.075,
      Paint()..color = RallyColors.lime.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      Offset(endX, endY),
      size.height * 0.038,
      Paint()..color = RallyColors.lime,
    );
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      oldDelegate.series != series;
}

/// Ripiego quando non c'è una curva da mostrare: il totale dei punti
/// giocati, che esiste sempre, come numero-eroe.
class _HeroCount extends StatelessWidget {
  const _HeroCount({required this.u, required this.card});
  final double u;
  final MatchWrappedData card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${card.totalPoints}',
          style: TextStyle(
            fontSize: u * 15,
            fontWeight: FontWeight.w900,
            height: 0.9,
            letterSpacing: -u * 0.3,
            color: Colors.white,
          ),
        ),
        SizedBox(height: u * 1.4),
        Text(
          // La durata è già nel piè di pagina: ripeterla qui era una
          // ridondanza in un poster che vive di poche informazioni.
          'PUNTI GIOCATI',
          style: TextStyle(
            fontSize: u * 2.4,
            fontWeight: FontWeight.w900,
            letterSpacing: u * 0.14,
            color: RallyColors.lime.withValues(alpha: 0.85),
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ quota punti

class _PointShare extends StatelessWidget {
  const _PointShare({required this.u, required this.card});
  final double u;
  final MatchWrappedData card;

  @override
  Widget build(BuildContext context) {
    final share = card.pointShare!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(u: u, text: 'PUNTI'),
            const Spacer(),
            Text(
              '${card.pointsWon} - ${card.pointsLost}',
              style: TextStyle(
                fontSize: u * 2.9,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: u * 1.8),
        ClipRRect(
          borderRadius: BorderRadius.circular(u),
          child: SizedBox(
            height: u * 2.2,
            width: double.infinity,
            child: Row(
              // Senza stretch i due riquadri ricevono vincoli laschi e, non
              // avendo figli, collassano ad altezza zero: la barra sparisce
              // dall'immagine condivisa.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: math.max(1, (share * 1000).round()),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [RallyColors.lime, Color(0xFF8FE04A)],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: math.max(1, ((1 - share) * 1000).round()),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- stats

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.u, required this.card, required this.tall});
  final double u;
  final MatchWrappedData card;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    // Clutch e streak esistono sempre; le altre solo se hanno campione.
    final tiles = <Widget>[
      _StatTile(
        u: u,
        label: 'Clutch',
        value: '${card.clutchScore}',
        detail: '/100',
        accent: true,
      ),
      _StatTile(
        u: u,
        label: 'Streak',
        value: '${card.bestStreak}',
        detail: 'punti',
      ),
      for (final stat in card.stats.take(tall ? 2 : 1))
        _StatTile(
          u: u,
          label: stat.label,
          value: stat.value,
          detail: stat.detail,
        ),
    ];
    if (!tall) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: u * 2.2),
            Expanded(child: tiles[i]),
          ],
        ],
      );
    }
    // Story: griglia 2x2. In una riga sola quattro etichette si troncano
    // ("BREAK POI…"), e la story ha altezza da spendere.
    //
    // Le celle hanno altezza fissa (vedi _StatTile): allineare con
    // IntrinsicHeight + CrossAxisAlignment.stretch imporrebbe ai figli
    // un'altezza infinita durante la misura.
    Widget row(List<Widget> cells) => Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: u * 2.2),
          Expanded(child: cells[i]),
        ],
        if (cells.length == 1) ...[
          SizedBox(width: u * 2.2),
          const Spacer(),
        ],
      ],
    );
    return Column(
      children: [
        row(tiles.take(2).toList()),
        if (tiles.length > 2) ...[
          SizedBox(height: u * 2.2),
          row(tiles.skip(2).toList()),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.u,
    required this.label,
    required this.value,
    this.detail,
    this.accent = false,
  });

  final double u;
  final String label;
  final String value;
  final String? detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Altezza fissa: le celle restano allineate senza IntrinsicHeight,
      // che sotto una Column non ha un'altezza da cui partire.
      height: u * 13.4,
      padding: EdgeInsets.symmetric(horizontal: u * 2.4, vertical: u * 2.2),
      decoration: BoxDecoration(
        color: accent
            ? RallyColors.lime.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(u * 2.6),
        border: Border.all(
          color: accent
              ? RallyColors.lime.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.1),
          width: u * 0.12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: u * 2.1,
              fontWeight: FontWeight.w800,
              letterSpacing: u * 0.06,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
          SizedBox(height: u * 1.2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: u * 5,
                    fontWeight: FontWeight.w900,
                    color: accent ? RallyColors.lime : Colors.white,
                    height: 1,
                  ),
                ),
                if (detail != null) ...[
                  SizedBox(width: u * 0.8),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: u * 2.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.u, required this.text});
  final double u;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: u * 2.2,
        fontWeight: FontWeight.w900,
        letterSpacing: u * 0.14,
        color: Colors.white.withValues(alpha: 0.42),
        height: 1,
      ),
    );
  }
}

// ----------------------------------------------------------------- footer

class _Footer extends StatelessWidget {
  const _Footer({
    required this.u,
    required this.card,
    required this.showWatermark,
  });
  final double u;
  final MatchWrappedData card;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            // Non l'MVP statistico: per costruzione ripete la metrica già
            // mostrata nelle tile qui sopra.
            [
              if (card.formatLabel != null) card.formatLabel!,
              if (card.durationMinutes > 0) '${card.durationMinutes} min',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: u * 2.7,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
        ),
        if (showWatermark) ...[
          SizedBox(width: u * 2),
          Text(
            'creato con ${AppBrand.name}',
            style: TextStyle(
              fontSize: u * 2.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.38),
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
