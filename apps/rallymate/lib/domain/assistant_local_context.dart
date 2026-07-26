/// Specialized local-context agents for Pallino Assistant (paid Pro/Coach).
///
/// Architecture (parallel pure “agents”, composed on-device):
/// - [MatchFormContextAgent] — form from completed matches (no health)
/// - [TrainingContextAgent] — trainings catalog + logs / load (self-logged RPE)
/// - [TeamChemistryContextAgent] — pairs/teams, winrates, matchups
/// - [AssistantLocalContextComposer] — budgeted, privacy-minimized string
///
/// Hard rules (store / GDPR):
/// - Never include HealthKit / Health Connect / Google Health / HR / sleep /
///   calories from health APIs.
/// - Never include email, account ids, cloud UUIDs, image paths, payment data.
/// - Prefer aggregates; partner labels only as user-owned sports names.
/// - Char-capped synthetic text for the edge function `clientContext` channel.
library;

import 'package:rally_core/rally_core.dart';

import '../data/db/database.dart';
import 'training_insights.dart';

/// Privacy + product policy for assistant local context.
abstract final class AssistantContextPolicy {
  /// Client-side hard cap (server allows 2200).
  static const maxClientContextChars = 2100;

  /// KV key: "1" share training+team blocks (default), "0" strip them.
  static const shareTrainingTeamKey = 'assistant_share_training_team';

  static bool parseShareFlag(String? raw) {
    if (raw == null || raw.isEmpty) return true;
    final v = raw.trim().toLowerCase();
    return v != '0' && v != 'false' && v != 'off' && v != 'no';
  }

  /// Scrub free text that might hold secrets / PII.
  static String scrubLabel(String value, {int max = 40}) {
    final clean = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[<>@"|]'), '')
        .replaceAll(RegExp(r'\b[\w.+-]+@[\w.-]+\.\w+\b'), '')
        .trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 1)}…';
  }
}

/// Input snapshot for all agents (no health tables).
class AssistantContextInput {
  const AssistantContextInput({
    required this.me,
    required this.summaries,
    required this.weekly,
    required this.teams,
    required this.trainings,
    required this.logs,
    required this.includeTrainingAndTeam,
    this.now,
  });

  final Player? me;
  final List<MatchSummary> summaries;
  final WeeklySummary? weekly;
  final List<Team> teams;
  final List<Training> trainings;
  final List<TrainingLog> logs;
  final bool includeTrainingAndTeam;
  final DateTime? now;
}

/// Profile + recent form (always included for paid assistant).
class MatchFormContextAgent {
  const MatchFormContextAgent();

  List<String> build(AssistantContextInput input) {
    final parts = <String>[];
    final me = input.me;
    if (me != null) {
      final goal = AssistantContextPolicy.scrubLabel(me.goal, max: 80);
      final goalPart = goal.isEmpty ? '' : ', obiettivo="$goal"';
      parts.add(
        'Profilo sportivo: ruolo=${me.preferredRole}, '
        'livello=${me.level}, mano=${me.dominantHand}$goalPart.',
      );
    }

    final summaries = input.summaries;
    if (summaries.isEmpty) {
      parts.add(
        'Storico partite: nessun match completato. Dai consigli per primo '
        'utilizzo e raccolta dati.',
      );
    } else {
      final recent = summaries.take(12).toList();
      final wins = recent.where((m) => m.won).length;
      final pointsFor = recent.fold(0, (sum, m) => sum + m.pointsFor);
      final pointsAgainst = recent.fold(0, (sum, m) => sum + m.pointsAgainst);
      final clutch =
          recent.fold(0, (sum, m) => sum + m.clutchScore) / recent.length;
      final decisivePlayed = recent.fold(
        0,
        (sum, m) => sum + m.decisivePointsPlayed,
      );
      final decisiveWon = recent.fold(0, (sum, m) => sum + m.decisivePointsWon);

      // Role form
      final byRole = <String, List<MatchSummary>>{};
      for (final m in recent) {
        final r = m.roleplayed.name;
        byRole.putIfAbsent(r, () => []).add(m);
      }
      final roleBits = byRole.entries
          .where((e) => e.value.length >= 2)
          .map((e) {
            final w = e.value.where((m) => m.won).length;
            final wr = (w / e.value.length * 100).round();
            return '${e.key}:${e.value.length}m $wr%';
          })
          .take(4)
          .join(', ');

      // Difficulty mix (matchup hardness, not health)
      final byDiff = <String, int>{};
      for (final m in recent) {
        final d = m.opponentDifficulty.name;
        byDiff[d] = (byDiff[d] ?? 0) + 1;
      }
      final diffBits = byDiff.entries
          .map((e) => '${e.key}:${e.value}')
          .take(4)
          .join(', ');

      parts.add(
        'Ultimi ${recent.length} match: winrate=${(wins / recent.length * 100).round()}%, '
        'punti=$pointsFor-$pointsAgainst, clutch=${clutch.round()}/100'
        '${decisivePlayed > 0 ? ', decisivi=$decisiveWon/$decisivePlayed' : ''}'
        '${roleBits.isEmpty ? '' : '; ruoli=[$roleBits]'}'
        '${diffBits.isEmpty ? '' : '; difficoltà_avversari=[$diffBits]'}.',
      );
    }

    final weekly = input.weekly;
    if (weekly != null) {
      parts.add(
        'Settimana: match=${weekly.matchesPlayed}, vittorie=${weekly.wins}, '
        'miglior striscia=${weekly.bestStreak}, clutch medio=${weekly.avgClutch.round()}'
        '${weekly.bestRole != null ? ', miglior ruolo=${weekly.bestRole!.name}' : ''}.',
      );
    }

    final focus = recommendFocus(summaries);
    parts.add(
      'Focus consigliato: ${focus.title}; focus=${focus.focus}; '
      'metrica=${focus.metric}; micro-obiettivo=${focus.microGoal}.',
    );
    return parts;
  }
}

/// Catalog + self-logged training history (RPE/minutes from app logs only).
class TrainingContextAgent {
  const TrainingContextAgent();

  List<String> build(AssistantContextInput input) {
    if (!input.includeTrainingAndTeam) {
      return const [
        'Contesto allenamento: disabilitato dall’utente (impostazione privacy).',
      ];
    }

    final parts = <String>[];
    final trainings = input.trainings;
    final logs = input.logs;
    final now = input.now ?? DateTime.now();
    final byId = {for (final t in trainings) t.id: t};

    if (trainings.isNotEmpty) {
      final free = trainings.where((t) => !t.premium).length;
      final premium = trainings.where((t) => t.premium).length;
      final top = trainings
          .take(8)
          .map((t) {
            final tier = t.premium ? 'premium' : 'free';
            final role = AssistantContextPolicy.scrubLabel(t.role, max: 16);
            return '${AssistantContextPolicy.scrubLabel(t.title, max: 36)}'
                '(${t.durationMinutes}min,$tier'
                '${role.isEmpty ? '' : ',$role'})';
          })
          .join('; ');
      parts.add(
        'Catalogo training: totali=${trainings.length} (free=$free, premium=$premium). '
        'Esempi: $top.',
      );
    } else {
      parts.add('Catalogo training: vuoto sul dispositivo.');
    }

    final completed = logs.where((l) => l.completed).toList()
      ..sort((a, b) => b.dateMs.compareTo(a.dateMs));

    if (completed.isEmpty) {
      parts.add(
        'Log allenamento: nessuna sessione completata. Suggerisci di registrare '
        'RPE e minuti a fine sessione (dati app, non salute di sistema).',
      );
      return parts;
    }

    final load = TrainingLoad.compute(now, logs);
    parts.add(
      'Carico training (log app, non HealthKit/HC): sessioni settimana='
      '${load.sessionsThisWeek}, minuti=${load.minutesThisWeek}, '
      'RPE medio 7g=${load.avgRpe7d.toStringAsFixed(1)}, ACWR=${load.acwr}, '
      'zona=${load.zoneLabel}; streak giorni=${load.streakDays}.',
    );

    // Adherence last 28 days
    final day28 = now
        .subtract(const Duration(days: 28))
        .millisecondsSinceEpoch;
    final recent28 = completed.where((l) => l.dateMs >= day28).toList();
    final withRpe = recent28.where((l) => l.rpe > 0).length;
    final avgMin = recent28.isEmpty
        ? 0
        : (recent28.fold(0, (a, l) => a + (l.minutes > 0 ? l.minutes : 30)) /
                  recent28.length)
              .round();
    parts.add(
      'Adesione 28g: sessioni=${recent28.length}, con RPE=$withRpe, '
      'minuti medi≈$avgMin.',
    );

    // Last sessions (titles via catalog)
    final recentLines = <String>[];
    for (final log in completed.take(6)) {
      final t = byId[log.trainingId];
      final title = t == null
          ? 'sessione'
          : AssistantContextPolicy.scrubLabel(t.title, max: 28);
      final when = DateTime.fromMillisecondsSinceEpoch(log.dateMs);
      final stamp =
          '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}';
      final rpe = log.rpe > 0 ? ' RPE${log.rpe}' : '';
      final min = log.minutes > 0 ? ' ${log.minutes}min' : '';
      recentLines.add('$stamp $title$rpe$min');
    }
    if (recentLines.isNotEmpty) {
      parts.add('Ultime sessioni: ${recentLines.join(' | ')}.');
    }

    // Most trained premium/free themes
    final counts = <String, int>{};
    for (final log in recent28) {
      final t = byId[log.trainingId];
      if (t == null) continue;
      final key = AssistantContextPolicy.scrubLabel(t.title, max: 24);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final topThemes = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topThemes.isNotEmpty) {
      parts.add(
        'Temi più allenati 28g: ${topThemes.take(4).map((e) => '${e.key}×${e.value}').join(', ')}.',
      );
    }

    return parts;
  }
}

/// Best pairs / teams / matchup hardness from local match history.
class TeamChemistryContextAgent {
  const TeamChemistryContextAgent();

  List<String> build(AssistantContextInput input) {
    if (!input.includeTrainingAndTeam) {
      return const [
        'Contesto team: disabilitato dall’utente (impostazione privacy).',
      ];
    }

    final parts = <String>[];
    final teams = input.teams.where((t) => !t.archived).toList();
    final summaries = input.summaries;
    final teamById = {for (final t in teams) t.id: t};

    if (teams.isEmpty) {
      parts.add(
        'Team: nessuno creato. Consiglia di creare un team abituale per '
        'analisi di coppia.',
      );
      return parts;
    }

    // Roster snapshot (no cloud ids / images)
    final roster = teams
        .take(8)
        .map((t) {
          final partner = AssistantContextPolicy.scrubLabel(
            t.playerBName.isNotEmpty ? t.playerBName : 'partner',
            max: 24,
          );
          final name = AssistantContextPolicy.scrubLabel(t.name, max: 28);
          return '$name(partner=$partner, ruoli=${t.roleA}/${t.roleB})';
        })
        .join('; ');
    parts.add('Team attivi=${teams.length}: $roster.');

    // Aggregate per teamId from all summaries (min 2 matches)
    final byTeam = <String, List<MatchSummary>>{};
    for (final m in summaries) {
      final id = m.teamId;
      if (id == null || id.isEmpty) continue;
      byTeam.putIfAbsent(id, () => []).add(m);
    }

    final rankings = <_TeamRank>[];
    for (final entry in byTeam.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      final wins = list.where((m) => m.won).length;
      final clutch =
          list.fold(0, (a, m) => a + m.clutchScore) / list.length;
      final pf = list.fold(0, (a, m) => a + m.pointsFor);
      final pa = list.fold(0, (a, m) => a + m.pointsAgainst);
      final decP = list.fold(0, (a, m) => a + m.decisivePointsPlayed);
      final decW = list.fold(0, (a, m) => a + m.decisivePointsWon);
      // Opponent difficulty average if enum has score - use name frequency
      final hard = list
          .where(
            (m) =>
                m.opponentDifficulty == OpponentDifficulty.harder ||
                m.opponentDifficulty == OpponentDifficulty.muchHarder,
          )
          .length;
      rankings.add(
        _TeamRank(
          teamId: entry.key,
          matches: list.length,
          wins: wins,
          winRate: wins / list.length,
          avgClutch: clutch,
          pointsFor: pf,
          pointsAgainst: pa,
          decisiveRate: decP == 0 ? 0 : decW / decP,
          toughMatches: hard,
        ),
      );
    }

    rankings.sort((a, b) {
      final wr = b.winRate.compareTo(a.winRate);
      if (wr != 0) return wr;
      final n = b.matches.compareTo(a.matches);
      if (n != 0) return n;
      return b.avgClutch.compareTo(a.avgClutch);
    });

    if (rankings.isEmpty) {
      parts.add(
        'Chimica team: storico insufficiente (servono ≥2 match per team).',
      );
      return parts;
    }

    String labelFor(String teamId) {
      final t = teamById[teamId];
      if (t == null) return 'team';
      final name = AssistantContextPolicy.scrubLabel(t.name, max: 24);
      final partner = AssistantContextPolicy.scrubLabel(
        t.playerBName.isNotEmpty ? t.playerBName : '',
        max: 18,
      );
      return partner.isEmpty ? name : '$name+$partner';
    }

    final best = rankings.take(4).map((r) {
      final wr = (r.winRate * 100).round();
      final dec = r.decisiveRate <= 0
          ? ''
          : ', decisivi=${(r.decisiveRate * 100).round()}%';
      return '${labelFor(r.teamId)}: ${r.matches}m WR$wr% '
          'clutch=${r.avgClutch.round()} '
          'punti=${r.pointsFor}-${r.pointsAgainst}$dec'
          '${r.toughMatches > 0 ? ' tough=${r.toughMatches}' : ''}';
    }).join(' | ');
    parts.add('Migliori coppie/team (per WR, min 2 match): $best.');

    // Weakest pair (help coaching)
    if (rankings.length >= 2) {
      final worst = rankings.last;
      if (worst.matches >= 2 && worst.winRate < 0.45) {
        parts.add(
          'Coppia da lavorare: ${labelFor(worst.teamId)} '
          '(${worst.matches}m, WR=${(worst.winRate * 100).round()}%, '
          'clutch=${worst.avgClutch.round()}).',
        );
      }
    }

    // Head-to-head style: most common opponent tags (if any)
    final tagCounts = <String, int>{};
    for (final m in summaries.take(40)) {
      for (final tag in m.opponentTags) {
        final t = AssistantContextPolicy.scrubLabel(tag.wire, max: 20);
        if (t.isEmpty) continue;
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topTags.isNotEmpty) {
      parts.add(
        'Scontri/tag avversari più frequenti: '
        '${topTags.take(5).map((e) => '${e.key}×${e.value}').join(', ')}.',
      );
    }

    final weekly = input.weekly;
    if (weekly?.bestTeamId != null) {
      parts.add(
        'Miglior team settimana: ${labelFor(weekly!.bestTeamId!)}.',
      );
    }

    return parts;
  }
}

class _TeamRank {
  const _TeamRank({
    required this.teamId,
    required this.matches,
    required this.wins,
    required this.winRate,
    required this.avgClutch,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.decisiveRate,
    required this.toughMatches,
  });

  final String teamId;
  final int matches;
  final int wins;
  final double winRate;
  final double avgClutch;
  final int pointsFor;
  final int pointsAgainst;
  final double decisiveRate;
  final int toughMatches;
}

/// Composes parallel agents into one `clientContext` string.
class AssistantLocalContextComposer {
  const AssistantLocalContextComposer({
    this.formAgent = const MatchFormContextAgent(),
    this.trainingAgent = const TrainingContextAgent(),
    this.teamAgent = const TeamChemistryContextAgent(),
  });

  final MatchFormContextAgent formAgent;
  final TrainingContextAgent trainingAgent;
  final TeamChemistryContextAgent teamAgent;

  String compose(AssistantContextInput input) {
    final blocks = <String>[
      ...formAgent.build(input),
      ...trainingAgent.build(input),
      ...teamAgent.build(input),
      'Policy contesto: solo dati sportivi locali sintetici; esclusi dati salute '
          'di sistema, email, ID account e immagini. Non inventare metriche assenti.',
    ];
    return _compact(blocks.join('\n'), AssistantContextPolicy.maxClientContextChars);
  }

  static String _compact(String value, int maxChars) {
    final clean = value
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[<>]'), '')
        .trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars - 1)}…';
  }
}
