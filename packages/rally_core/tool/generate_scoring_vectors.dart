/// Genera i vettori di conformità cross-piattaforma dello scoring.
///
/// L'engine Dart (rally_core) è il contratto: questo tool riproduce una
/// serie di scenari deterministici e registra lo snapshot atteso dopo ogni
/// operazione. I runner Kotlin (Wear OS), Swift (watchOS) e JavaScript
/// (Fitbit OS) rigiocano gli stessi passi sul proprio engine e confrontano.
///
///     dart run tool/generate_scoring_vectors.dart
///
/// Output: wear/shared/scoring_vectors.json (committato; il test
/// scoring_vectors_test.dart fallisce se engine e file divergono).
library;

import 'dart:convert';
import 'dart:io';

import 'package:rally_core/rally_core.dart';

/// Operazioni supportate da tutti i runner.
/// { "op": "point"|"undo"|"pause"|"resume"|"finish", "team": "TEAM_A"|null }
class _Step {
  const _Step(this.op, [this.team]);
  final String op;
  final TeamId? team;
}

class _Vector {
  const _Vector({
    required this.id,
    required this.description,
    required this.format,
    required this.steps,
    this.platforms = const ['dart', 'kotlin', 'swift', 'fitbit'],
  });

  final String id;
  final String description;
  final MatchFormat format;
  final List<_Step> steps;
  final List<String> platforms;
}

_Step _pA() => const _Step('point', TeamId.a);
_Step _pB() => const _Step('point', TeamId.b);

List<_Step> _game(TeamId team, {required bool golden}) =>
    List.filled(4, _Step('point', team));

List<_Step> _games(int aGames, int bGames) => [
  for (var i = 0; i < aGames; i++) ..._game(TeamId.a, golden: false),
  for (var i = 0; i < bGames; i++) ..._game(TeamId.b, golden: false),
];

/// Game alternati A,B,A,B… fino a [pairs] coppie: porta il set su un
/// punteggio pari (es. 6 coppie → 6-6) senza mai chiuderlo.
List<_Step> _alternatingGames(int pairs) => [
  for (var i = 0; i < pairs; i++) ...[
    ..._game(TeamId.a, golden: false),
    ..._game(TeamId.b, golden: false),
  ],
];

List<_Vector> _vectors() => [
  _Vector(
    id: 'adv_bo3_hold_to_game',
    description: 'Game a zero: etichette 0/15/30/40 e game 1-0.',
    format: MatchFormat.advantageBo3,
    steps: [_pA(), _pA(), _pA(), _pA()],
  ),
  _Vector(
    id: 'adv_bo3_deuce_battle',
    description: 'Parità, vantaggio A, parità, vantaggio B, game B.',
    format: MatchFormat.advantageBo3,
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // 40-40
      _pA(), // AD A
      _pB(), // deuce
      _pB(), // AD B
      _pB(), // game B
    ],
  ),
  _Vector(
    id: 'golden_bo3_golden_point',
    description: 'Golden point: sul 40-40 il punto successivo chiude.',
    format: MatchFormat.goldenPointBo3,
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // 40-40
      _pB(), // golden point → game B
    ],
  ),
  _Vector(
    id: 'adv_bo3_set_6_4',
    description: 'Set chiuso 6-4 con game a zero alternati.',
    format: MatchFormat.advantageBo3,
    steps: [
      ..._games(5, 4),
      ..._game(TeamId.a, golden: false), // 6-4 → set
    ],
  ),
  _Vector(
    id: 'adv_bo3_tiebreak_7_5',
    description: '6-6 → tie-break 7-5 → set 7-6 con dettaglio TB.',
    format: MatchFormat.advantageBo3,
    steps: [
      ..._alternatingGames(6), // 6-6 → parte il tie-break
      // Tie-break: A 7, B 5 (alternanza che tocca 5-5 poi 7-5).
      _pA(), _pB(), _pA(), _pB(), _pA(), _pB(), _pA(), _pB(), _pA(),
      _pB(), // 5-5
      _pA(), _pA(), // 7-5
    ],
  ),
  _Vector(
    id: 'super_tb_decider_10_8',
    description: 'Set pari → super tie-break 10-8 decide il match.',
    format: MatchFormat.superTieBreakBo3,
    steps: [
      ..._games(6, 0), // set 1 ad A
      ..._games(0, 6), // set 2 a B → parte il super TB
      for (var i = 0; i < 8; i++) ...[_pA(), _pB()], // 8-8
      _pA(), _pA(), // 10-8 → match A
    ],
  ),
  _Vector(
    id: 'single_set_6_0',
    description: 'Partita secca: 6-0 chiude il match.',
    format: MatchFormat.singleSet,
    steps: _games(6, 0),
  ),
  _Vector(
    id: 'training_free_play',
    description: 'Allenamento: contatori liberi, undo e finish.',
    format: MatchFormat.training,
    steps: [
      _pA(), _pA(), _pB(),
      const _Step('undo'), // annulla il punto B
      _pA(),
      const _Step('finish'), // vince chi è avanti nei punti liberi
    ],
  ),
  _Vector(
    id: 'undo_simple_and_exhausted',
    description: 'Doppio undo torna a 0-0; undo a vuoto è un no-op.',
    format: MatchFormat.advantageBo3,
    steps: [
      _pA(), _pB(),
      const _Step('undo'), // annulla B
      const _Step('undo'), // annulla A
      const _Step('undo'), // niente da annullare
    ],
  ),
  _Vector(
    id: 'undo_across_game_boundary',
    description: 'Undo dopo il game riporta al 40 precedente.',
    format: MatchFormat.advantageBo3,
    steps: [
      _pA(), _pA(), _pA(), _pA(), // game 1-0
      const _Step('undo'), // di nuovo 40-0, game 0-0
    ],
  ),
  _Vector(
    id: 'undo_across_set_boundary',
    description: 'Undo dopo il set riapre il set al 5-0 40-0.',
    format: MatchFormat.advantageBo3,
    steps: [
      ..._games(6, 0), // set 1-0
      const _Step('undo'),
    ],
  ),
  _Vector(
    id: 'duo_team_scoped_undo',
    description: 'Duo: ogni undo annulla solo l\'ultimo punto del team.',
    format: MatchFormat.goldenPointBo3,
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      _pA(), _pB(), _pA(),
      const _Step('undo', TeamId.a), // annulla il SECONDO punto A
      const _Step('undo', TeamId.b), // annulla il punto B
      const _Step('undo', TeamId.b), // no-op: B non ha altri punti
    ],
  ),
  _Vector(
    id: 'pause_logged_point_still_counts',
    description:
        'Replay canonico: un punto registrato in pausa conta comunque '
        '(la pausa blocca l\'input locale, non il log sincronizzato).',
    format: MatchFormat.advantageBo3,
    steps: [
      _pA(),
      const _Step('pause'),
      _pB(), // arrivato dal log: conta, lo stato resta in pausa
      const _Step('resume'),
      _pB(),
    ],
  ),
  _Vector(
    id: 'finish_manual_leading_by_games',
    description: 'Finish manuale: vince chi conduce nei game.',
    format: MatchFormat.advantageBo3,
    steps: [
      ..._game(TeamId.a, golden: false), // 1-0
      _pB(),
      const _Step('finish'),
    ],
  ),
  _Vector(
    id: 'finish_manual_tie_no_winner',
    description:
        'Finish manuale in perfetta parità: nessun vincitore (il '
        'vantaggio di soli punti nel game non decide).',
    format: MatchFormat.advantageBo3,
    steps: [_pA(), const _Step('finish')],
  ),
  _Vector(
    id: 'golden_bo3_full_match_2_0',
    description: 'Match completo golden point 2-0 (6-0 6-0).',
    format: MatchFormat.goldenPointBo3,
    steps: _games(12, 0),
  ),
];

Map<String, Object?> _snapshot(PadelScoringEngine engine) {
  final s = engine.state;
  String label(TeamId team) {
    if (engine.format.freePlay) {
      return '${team == TeamId.a ? s.freePlayA : s.freePlayB}';
    }
    if (s.inTieBreak || s.inSuperTieBreak) {
      return '${team == TeamId.a ? s.tieBreakA : s.tieBreakB}';
    }
    return s.points.labelFor(team);
  }

  return {
    'completed': s.isCompleted,
    'paused': s.status == MatchStatus.paused,
    'winner': s.winner?.wire,
    'setsA': s.setsA,
    'setsB': s.setsB,
    'gamesA': s.gamesA,
    'gamesB': s.gamesB,
    'labelA': label(TeamId.a),
    'labelB': label(TeamId.b),
    'advantage': s.points.advantage?.wire,
    'inTieBreak': s.inTieBreak,
    'inSuperTieBreak': s.inSuperTieBreak,
    'tieBreakA': s.tieBreakA,
    'tieBreakB': s.tieBreakB,
    'freePlayA': s.freePlayA,
    'freePlayB': s.freePlayB,
    'completedSets': [
      for (final set in s.completedSets)
        {
          'gamesA': set.gamesA,
          'gamesB': set.gamesB,
          'tieBreakA': set.tieBreakA,
          'tieBreakB': set.tieBreakB,
          'superTieBreak': set.isSuperTieBreak,
        },
    ],
  };
}

/// Costruisce il JSON dei vettori (pure: usato anche dal drift-guard test).
Map<String, Object?> buildVectorsDocument() {
  final vectors = <Map<String, Object?>>[];
  for (final vector in _vectors()) {
    var tick = 0;
    final engine = PadelScoringEngine(
      matchId: 'vec_${vector.id}',
      format: vector.format,
      clock: () => 1750000000000 + (++tick) * 1000,
      idGenerator: () => 'evt_${vector.id}_${++tick}',
    );
    engine.start();

    final steps = <Map<String, Object?>>[];
    for (final step in vector.steps) {
      switch (step.op) {
        case 'point':
          engine.addPoint(step.team!);
        case 'undo':
          engine.undo(team: step.team);
        case 'pause':
          engine.pause();
        case 'resume':
          engine.resume();
        case 'finish':
          engine.finish(winner: step.team);
        default:
          throw StateError('Operazione sconosciuta: ${step.op}');
      }
      steps.add({
        'op': step.op,
        'team': step.team?.wire,
        'expect': _snapshot(engine),
      });
    }

    vectors.add({
      'id': vector.id,
      'description': vector.description,
      'platforms': vector.platforms,
      'format': vector.format.toJson(),
      'steps': steps,
    });
  }

  return {
    'version': 1,
    'generator': 'packages/rally_core/tool/generate_scoring_vectors.dart',
    'contract':
        'rally_core PadelScoringEngine è il riferimento: ogni engine watch '
        'deve riprodurre questi snapshot passo per passo.',
    'vectors': vectors,
  };
}

File sharedVectorsFile() {
  var dir = Directory.current;
  while (true) {
    final candidate = Directory('${dir.path}/wear/shared');
    if (candidate.existsSync()) {
      return File('${candidate.path}/scoring_vectors.json');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Cartella wear/shared non trovata sopra $dir');
    }
    dir = parent;
  }
}

void main() {
  final file = sharedVectorsFile();
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(buildVectorsDocument())}\n');
  final vectors = buildVectorsDocument()['vectors'] as List;
  stdout.writeln('Scritti ${vectors.length} vettori in ${file.path}');
}
