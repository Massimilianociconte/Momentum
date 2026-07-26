/// Rules Assistant free (PRD E2): local FAQ database + textual search.
/// No cloud LLM, no invented answers — every entry cites its official
/// source (FIP Rules of Padel / Regolamento FIP-CONI).
library;

class RuleEntry {
  const RuleEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.source,
    this.example,
  });

  final String id;
  final String question;
  final String answer;
  final List<String> keywords;

  /// Official source citation, e.g. "FIP Rules of Padel — Regola 12".
  final String source;
  final String? example;
}

class RuleSearchResult {
  const RuleSearchResult(this.entry, this.score);
  final RuleEntry entry;
  final double score;
}

/// Deterministic local search: token overlap + keyword boost.
/// Good enough offline; premium assistant (LLM) builds on top of it.
class RulesSearch {
  RulesSearch(this.entries);

  final List<RuleEntry> entries;

  static final _splitter = RegExp(r'[^a-z0-9àèéìòù]+');

  static const _stopWords = {
    'il',
    'lo',
    'la',
    'i',
    'gli',
    'le',
    'un',
    'una',
    'uno',
    'di',
    'a',
    'da',
    'in',
    'con',
    'su',
    'per',
    'tra',
    'fra',
    'che',
    'chi',
    'cosa',
    'come',
    'quando',
    'dove',
    'perche',
    'perché',
    'e',
    'o',
    'ma',
    'se',
    'non',
    'si',
    'del',
    'della',
    'dei',
    'delle',
    'al',
    'alla',
    'ai',
    'alle',
    'nel',
    'nella',
    'posso',
    'puo',
    'può',
    'essere',
    'viene',
    'funziona',
    'vale',
  };

  static List<String> tokenize(String text) => text
      .toLowerCase()
      .split(_splitter)
      .where((t) => t.length > 1 && !_stopWords.contains(t))
      .toList();

  List<RuleSearchResult> search(String query, {int limit = 5}) {
    final qTokens = tokenize(query);
    if (qTokens.isEmpty) return const [];

    final results = <RuleSearchResult>[];
    for (final e in entries) {
      final keywordSet = e.keywords.map((k) => k.toLowerCase()).toSet();
      final questionTokens = tokenize(e.question).toSet();
      final answerTokens = tokenize(e.answer).toSet();

      var score = 0.0;
      for (final t in qTokens) {
        if (keywordSet.contains(t)) {
          score += 3.0;
        } else if (keywordSet.any((k) => k.startsWith(t) || t.startsWith(k))) {
          score += 1.5;
        }
        if (questionTokens.contains(t)) score += 2.0;
        if (answerTokens.contains(t)) score += 0.5;
      }
      if (score > 0) {
        results.add(RuleSearchResult(e, score / qTokens.length));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// Confidence gate: below this, UI must say "non ho abbastanza certezza"
  /// instead of guessing (PRD guardrail: nessuna risposta inventata).
  static const minConfidence = 1.5;
}
