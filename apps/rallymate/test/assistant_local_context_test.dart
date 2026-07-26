import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/domain/assistant_local_context.dart';

MatchSummary _m({
  required String id,
  required bool won,
  String? teamId,
  int clutch = 50,
  OpponentDifficulty diff = OpponentDifficulty.sameLevel,
  Set<OpponentTag> tags = const {},
}) =>
    MatchSummary(
      matchId: id,
      endTimeMs: 1,
      won: won,
      pointsFor: won ? 60 : 40,
      pointsAgainst: won ? 40 : 60,
      gamesFor: won ? 6 : 3,
      gamesAgainst: won ? 3 : 6,
      setsFor: won ? 2 : 0,
      setsAgainst: won ? 0 : 2,
      clutchScore: clutch,
      bestStreak: 3,
      durationMs: 3600000,
      teamId: teamId,
      opponentDifficulty: diff,
      opponentTags: tags,
    );

void main() {
  test('team agent ranks pairs and excludes health vocabulary', () {
    final teams = [
      Team(
        id: 't1',
        name: 'Alpha',
        playerAId: 'me',
        playerBName: 'Luca',
        roleA: 'LEFT',
        roleB: 'RIGHT',
        tacticalNotes: '',
        goals: '',
        imageVersion: 0,
        imageCloudVersion: 0,
        scoringStyle: 'AUTO',
        colorArgb: 0xFFC8F135,
        cloudRole: 'LOCAL',
        archived: false,
        createdAtMs: 1,
      ),
      Team(
        id: 't2',
        name: 'Beta',
        playerAId: 'me',
        playerBName: 'Marco',
        roleA: 'RIGHT',
        roleB: 'LEFT',
        tacticalNotes: '',
        goals: '',
        imageVersion: 0,
        imageCloudVersion: 0,
        scoringStyle: 'AUTO',
        colorArgb: 0xFFC8F135,
        cloudRole: 'LOCAL',
        archived: false,
        createdAtMs: 1,
      ),
    ];
    final summaries = [
      _m(id: '1', won: true, teamId: 't1', clutch: 70),
      _m(id: '2', won: true, teamId: 't1', clutch: 65),
      _m(id: '3', won: true, teamId: 't1', clutch: 80),
      _m(id: '4', won: false, teamId: 't2', clutch: 40),
      _m(id: '5', won: false, teamId: 't2', clutch: 35),
      _m(
        id: '6',
        won: true,
        teamId: 't1',
        tags: {OpponentTag.aggressive, OpponentTag.tournament},
      ),
    ];

    final text = const AssistantLocalContextComposer().compose(
      AssistantContextInput(
        me: null,
        summaries: summaries,
        weekly: null,
        teams: teams,
        trainings: const [],
        logs: const [],
        includeTrainingAndTeam: true,
      ),
    );

    expect(text, contains('Migliori coppie'));
    expect(text, contains('Alpha'));
    expect(text.toLowerCase(), isNot(contains('healthkit')));
    expect(text.toLowerCase(), isNot(contains('heart rate')));
    expect(text.length, lessThanOrEqualTo(AssistantContextPolicy.maxClientContextChars));
  });

  test('toggle off strips training and team blocks', () {
    final text = const AssistantLocalContextComposer().compose(
      const AssistantContextInput(
        me: null,
        summaries: [],
        weekly: null,
        teams: [],
        trainings: [],
        logs: [],
        includeTrainingAndTeam: false,
      ),
    );
    expect(text, contains('disabilitato'));
    expect(text, isNot(contains('Migliori coppie')));
  });
}
