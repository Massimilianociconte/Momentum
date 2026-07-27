/// Export PDF dei report (PRD 8 Plus + H2 "export PDF").
///
/// Genera in locale (nessun cloud) un report della finestra di analisi
/// corrente: stats base (F1), premium (F2) e imprese per difficoltà (F5).
/// Il PDF viene condiviso con lo share sheet nativo via share_plus.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rally_core/rally_core.dart';

class PdfReportService {
  static const _night = PdfColor.fromInt(0xFF07101F);
  static const _lime = PdfColor.fromInt(0xFFC6FF33);
  static const _win = PdfColor.fromInt(0xFF39D98A);
  static const _loss = PdfColor.fromInt(0xFFFF5C5C);

  /// Report della stagione/finestra selezionata. [playerName] appare
  /// nell'intestazione; [windowLabel] descrive la finestra (es. "Ultime 20").
  static Future<Uint8List> seasonReport({
    required String playerName,
    required String windowLabel,
    required List<MatchSummary> summaries,
  }) async {
    final doc = pw.Document(
      title: 'Momentum — Report $windowLabel',
      author: 'Momentum',
    );

    final played = summaries.length;
    final wins = summaries.where((m) => m.won).length;
    final winRate = played == 0 ? 0.0 : wins / played;
    final pointsFor = summaries.fold<int>(0, (s, m) => s + m.pointsFor);
    final pointsAgainst = summaries.fold<int>(0, (s, m) => s + m.pointsAgainst);
    final avgClutch = played == 0
        ? 0
        : summaries.fold<int>(0, (s, m) => s + m.clutchScore) ~/ played;
    final totalMinutes =
        summaries.fold<int>(0, (s, m) => s + m.durationMs) ~/ 60000;

    final byRole = <PadelRole, List<MatchSummary>>{};
    for (final m in summaries) {
      if (m.roleplayed != PadelRole.undefined) {
        byRole.putIfAbsent(m.roleplayed, () => []).add(m);
      }
    }
    final byDiff = <int, List<MatchSummary>>{};
    for (final m in summaries) {
      byDiff.putIfAbsent(m.opponentDifficulty.score, () => []).add(m);
    }
    final st = OpponentDifficultyScore.stats(summaries);
    final byId = {for (final m in summaries) m.matchId: m};
    final bestWin = byId[st.bestWinMatchId];
    final worstLoss = byId[st.worstLossMatchId];
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          buildBackground: (_) => pw.Container(color: PdfColors.white),
        ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generato da Momentum · ${now.day}/${now.month}/${now.year}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Pagina ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          _header(playerName, windowLabel),
          pw.SizedBox(height: 18),
          _sectionTitle('RIEPILOGO'),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _stat('Partite', '$played'),
              _stat('Vittorie', '$wins', color: _win),
              _stat(
                'Win rate',
                '${(winRate * 100).round()}%',
                color: winRate >= 0.5 ? _win : _loss,
              ),
              _stat('Clutch medio', '$avgClutch/100'),
              _stat('Minuti giocati', '$totalMinutes'),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _stat('Punti fatti', '$pointsFor'),
              _stat('Punti subiti', '$pointsAgainst'),
              _stat(
                'Differenza',
                '${pointsFor - pointsAgainst >= 0 ? '+' : ''}'
                    '${pointsFor - pointsAgainst}',
                color: pointsFor >= pointsAgainst ? _win : _loss,
              ),
              _stat(
                'Media punti/partita',
                played == 0 ? '—' : (pointsFor / played).toStringAsFixed(1),
              ),
              pw.SizedBox(width: 40),
            ],
          ),
          pw.SizedBox(height: 18),
          if (byRole.isNotEmpty) ...[
            _sectionTitle('RENDIMENTO PER RUOLO'),
            pw.SizedBox(height: 8),
            _table(
              ['Ruolo', 'Partite', 'Vittorie', 'Win rate'],
              [
                for (final e in byRole.entries)
                  [
                    switch (e.key) {
                      PadelRole.left => 'Sinistra',
                      PadelRole.right => 'Destra',
                      PadelRole.flex => 'Flex',
                      PadelRole.undefined => '—',
                    },
                    '${e.value.length}',
                    '${e.value.where((m) => m.won).length}',
                    '${(e.value.where((m) => m.won).length * 100 ~/ e.value.length)}%',
                  ],
              ],
            ),
            pw.SizedBox(height: 18),
          ],
          _sectionTitle('RENDIMENTO PER DIFFICOLTÀ AVVERSARI'),
          pw.SizedBox(height: 8),
          _table(
            ['Difficoltà', 'Partite', 'Vittorie', 'Win rate'],
            [
              for (final k in (byDiff.keys.toList()..sort()))
                [
                  '$k/5',
                  '${byDiff[k]!.length}',
                  '${byDiff[k]!.where((m) => m.won).length}',
                  '${(byDiff[k]!.where((m) => m.won).length * 100 ~/ byDiff[k]!.length)}%',
                ],
            ],
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('IMPRESE (PRD F5)'),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _stat('Upset win', '${st.upsetWins}', color: _win),
              _stat('Vittorie vs più forti', '${st.winsVsHarder}'),
              _stat('Upset loss', '${st.upsetLosses}', color: _loss),
              _stat('Sconfitte vs più deboli', '${st.lossesVsEasier}'),
              _stat('Streak pari livello', '${st.bestStreakVsSameLevel}'),
            ],
          ),
          if (bestWin != null || worstLoss != null) ...[
            pw.SizedBox(height: 10),
            if (bestWin != null)
              _extremeLine('Miglior vittoria', bestWin, _win),
            if (worstLoss != null)
              _extremeLine('Peggior sconfitta', worstLoss, _loss),
          ],
          pw.SizedBox(height: 18),
          _sectionTitle('ULTIME PARTITE'),
          pw.SizedBox(height: 8),
          _table(
            ['Data', 'Esito', 'Set', 'Punti', 'Difficoltà', 'Clutch'],
            [
              for (final m in summaries.take(15))
                [
                  _date(m.endTimeMs),
                  m.won ? 'Vittoria' : 'Sconfitta',
                  '${m.setsFor}-${m.setsAgainst}',
                  '${m.pointsFor}-${m.pointsAgainst}',
                  '${m.opponentDifficulty.score}/5',
                  '${m.clutchScore}',
                ],
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(String playerName, String windowLabel) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _night,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Momentum',
                style: pw.TextStyle(
                  color: _lime,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Report padel — $windowLabel',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
            ],
          ),
          pw.Text(
            playerName,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 1.2,
      color: PdfColors.grey800,
    ),
  );

  static pw.Widget _stat(String label, String value, {PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color ?? _night,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _night),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: null,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }

  static pw.Widget _extremeLine(String label, MatchSummary m, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        '$label: ${m.setsFor}-${m.setsAgainst} set contro difficoltà '
        '${m.opponentDifficulty.score}/5 (${_date(m.endTimeMs)})',
        style: pw.TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}
