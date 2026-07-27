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
/// {
///   "op": "point"|"edit"|"undo"|"pause"|"resume"|"finish",
///   "team": "TEAM_A"|null,
///   "payload": { ... }|null
/// }
class _Step {
  const _Step(this.op, [this.team, this.payload]);
  final String op;
  final TeamId? team;
  final Map<String, int>? payload;
}

class _Vector {
  const _Vector({
    required this.id,
    required this.description,
    required this.format,
    required this.steps,
    this.platforms = const ['dart', 'kotlin', 'swift', 'fitbit', 'garmin'],
  });

  final String id;
  final String description;
  final MatchFormat format;
  final List<_Step> steps;
  final List<String> platforms;
}

_Step _pA() => const _Step('point', TeamId.a);
_Step _pB() => const _Step('point', TeamId.b);
_Step _edit({
  required int pointsA,
  required int pointsB,
  required int gamesA,
  required int gamesB,
  int? deuceNumber,
}) => _Step('edit', null, {
  'pointsA': pointsA,
  'pointsB': pointsB,
  'gamesA': gamesA,
  'gamesB': gamesB,
  'deuceNumber': ?deuceNumber,
});

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
    id: 'star_point_bo3_full_cycle',
    description:
        'Star Point FIP: parità 1, vantaggio 1, parità 2, vantaggio 2, '
        'parità 3 e punto decisivo.',
    format: MatchFormat.starPointBo3,
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // parità 1
      _pA(), // vantaggio 1 A
      _pB(), // parità 2
      _pB(), // vantaggio 2 B
      _pA(), // parità 3 / Star Point
      _pA(), // punto decisivo → game A
    ],
  ),
  _Vector(
    id: 'star_point_bo3_advantage_two_conversion',
    description: 'Star Point FIP: il titolare di vantaggio 2 chiude il game.',
    format: MatchFormat.starPointBo3,
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // parità 1
      _pA(), // vantaggio 1 A
      _pB(), // parità 2
      _pB(), // vantaggio 2 B
      _pB(), // conversione → game B
    ],
  ),
  _Vector(
    id: 'star_point_bo3_undo_game_to_decider',
    description:
        'Star Point FIP: undo dopo il game ripristina parità 3 e il punto '
        'decisivo.',
    format: MatchFormat.starPointBo3,
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // parità 1
      _pA(), // vantaggio 1 A
      _pB(), // parità 2
      _pB(), // vantaggio 2 B
      _pA(), // parità 3 / Star Point
      _pA(), // punto decisivo → game A
      const _Step('undo'), // torna allo Star Point
    ],
  ),
  _Vector(
    id: 'star_point_score_edit_replay_normalization',
    description:
        'Replay SCORE_EDITED Star Point: un edit legacy dopo parità 2 '
        'riparte da parità 1; AD 3 è limitato ad AD 2 e i punteggi '
        'malformati 4-4/4-2 sono normalizzati.',
    format: MatchFormat.starPointBo3,
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      _pA(), _pA(), _pA(), // 40-0
      _pB(), _pB(), _pB(), // parità 1
      _pA(), // vantaggio 1 A
      _pB(), // parità 2
      _edit(
        pointsA: 3,
        pointsB: 3,
        gamesA: 0,
        gamesB: 0,
      ), // payload legacy: non eredita parità 2
      _edit(
        pointsA: 4,
        pointsB: 3,
        gamesA: 0,
        gamesB: 0,
        deuceNumber: 3,
      ), // Star Point non ammette AD 3: diventa AD 2
      _edit(
        pointsA: 4,
        pointsB: 4,
        gamesA: 0,
        gamesB: 0,
        deuceNumber: 3,
      ), // 4-4 malformato: parità 3 / Star Point
      _edit(
        pointsA: 4,
        pointsB: 2,
        gamesA: 0,
        gamesB: 0,
        deuceNumber: 3,
      ), // 4-2 malformato: 40-30, fuori dal ciclo Star
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
    id: 'mini_set_4_games',
    description:
        'Mini-set FIP: il set si chiude a 4 game con 2 di scarto (4-2).',
    format: MatchFormat.miniSetBo3,
    steps: [
      ..._games(2, 2), // 2-2
      ..._games(2, 0), // 4-2 → set
    ],
  ),
  _Vector(
    id: 'match_tie_break_7_decider',
    description:
        'Tie-break decisivo FIP a 7 punti al posto dell\'ultimo set (7-5).',
    format: MatchFormat.matchTieBreak7Bo3,
    steps: [
      ..._games(6, 0), // set 1 ad A
      ..._games(0, 6), // set 2 a B → parte il tie-break decisivo
      for (var i = 0; i < 5; i++) ...[_pA(), _pB()], // 5-5
      _pA(), _pA(), // 7-5 → match A
    ],
  ),
  _Vector(
    id: 'deciding_set_without_tie_break_8_6',
    description:
        'Terzo set senza tie-break: sul 6-6 si prosegue fino a due game di '
        'scarto (8-6).',
    format: MatchFormat.advantageDecidingSetBo3,
    // Schema v3: solo gli engine che leggono tieBreakInDecidingSet.
    platforms: const ['dart', 'kotlin', 'swift'],
    steps: [
      ..._games(6, 0), // set 1 ad A
      ..._games(0, 6), // set 2 a B → set decisivo
      ..._alternatingGames(6), // 6-6 senza tie-break
      ..._games(2, 0), // 8-6 → set e match ad A
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
    // Fitbit non modella l'assegnazione Duo; Garmin sì
    // (RallyMateScoreEngine.lastUndoableEventIdIn con assignedTeam).
    platforms: const ['dart', 'kotlin', 'swift', 'garmin'],
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
    'deuceNumber': s.points.deuceNumber,
    'isStarPoint': s.points.isStarPoint,
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
        case 'edit':
          final payload = step.payload!;
          engine.editScore(
            pointsA: payload['pointsA']!,
            pointsB: payload['pointsB']!,
            gamesA: payload['gamesA']!,
            gamesB: payload['gamesB']!,
            deuceNumber: payload['deuceNumber'],
          );
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
        if (step.payload != null) 'payload': step.payload,
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
    'version': 2,
    'generator': 'packages/momentum_core/tool/generate_scoring_vectors.dart',
    'contract':
        'rally_core PadelScoringEngine è il riferimento: ogni engine watch '
        'deve riprodurre questi snapshot passo per passo.',
    'vectors': vectors,
  };
}

Directory repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/wear/shared').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Cartella wear/shared non trovata sopra $dir');
    }
    dir = parent;
  }
}

File sharedVectorsFile() =>
    File('${repoRoot().path}/wear/shared/scoring_vectors.json');

File garminVectorsFile() => File(
  '${repoRoot().path}/wear/garmin-connectiq/test-resources/'
  'scoring_vectors_garmin.json',
);

/// Proiezione compatta dei vettori per Connect IQ.
///
/// Il documento canonico supera i 200 KB minificati: `Application.loadResource`
/// lo materializza tutto in RAM e su un orologio Connect IQ questo esaurisce
/// la memoria dell'app. Qui ogni step diventa una tupla posizionale con i soli
/// campi che l'engine Monkey C modella, il che riduce il payload di circa un
/// ordine di grandezza.
///
/// Campi volutamente esclusi: `winner`, `advantage`, `deuceNumber`,
/// `isStarPoint`, `completedSets`. L'engine Garmin è un terminale di scoring —
/// il vincitore e il riepilogo li deriva il telefono al merge — e Star Point
/// non è supportato (i relativi vettori non dichiarano `garmin`).
///
/// Layout di uno step:
/// `[op, team, completed, paused, setsA, setsB, gamesA, gamesB, labelA, labelB,
///   inTieBreak, inSuperTieBreak]`
/// con `op` in `p|u|P|R|f` e `team` in `A|B|null`.
Map<String, Object?> buildGarminVectorsDocument() {
  const opCodes = {
    'point': 'p',
    'undo': 'u',
    'pause': 'P',
    'resume': 'R',
    'finish': 'f',
  };
  final source = buildVectorsDocument();
  final vectors = <Map<String, Object?>>[];

  for (final raw in source['vectors']! as List) {
    final vector = raw as Map<String, Object?>;
    final platforms = (vector['platforms']! as List).cast<String>();
    if (!platforms.contains('garmin')) continue;

    final format = vector['format']! as Map<String, Object?>;
    final steps = <List<Object?>>[];
    for (final rawStep in vector['steps']! as List) {
      final step = rawStep as Map<String, Object?>;
      final op = opCodes[step['op']];
      if (op == null) {
        throw StateError(
          'Operazione "${step['op']}" non rappresentabile su Garmin '
          '(vettore ${vector['id']}). Escludi il vettore o estendi il runner.',
        );
      }
      final expect = step['expect']! as Map<String, Object?>;
      final team = step['team'] as String?;
      steps.add([
        op,
        team == null ? null : (team == 'TEAM_A' ? 'A' : 'B'),
        expect['completed'],
        expect['paused'],
        expect['setsA'],
        expect['setsB'],
        expect['gamesA'],
        expect['gamesB'],
        expect['labelA'],
        expect['labelB'],
        expect['inTieBreak'],
        expect['inSuperTieBreak'],
      ]);
    }

    vectors.add({
      'id': vector['id'],
      // Solo le chiavi lette da RallyMateScoreEngine.
      'format': {
        'setsToWin': format['setsToWin'],
        'gamesPerSet': format['gamesPerSet'],
        'tieBreakPoints': format['tieBreakPoints'],
        'superTieBreakPoints': format['superTieBreakPoints'],
        'goldenPoint': format['goldenPoint'],
        'tieBreakAtGamesAll': format['tieBreakAtGamesAll'],
        'superTieBreakDecider': format['superTieBreakDecider'],
        'freePlay': format['freePlay'],
      },
      'steps': steps,
    });
  }

  return {
    'version': 1,
    'generator': 'packages/momentum_core/tool/generate_scoring_vectors.dart',
    'source': 'wear/shared/scoring_vectors.json',
    'vectors': vectors,
  };
}

void main() {
  final document = buildVectorsDocument();
  const encoder = JsonEncoder.withIndent('  ');
  final file = sharedVectorsFile();
  file.writeAsStringSync('${encoder.convert(document)}\n');
  stdout.writeln(
    'Scritti ${(document['vectors']! as List).length} vettori in ${file.path}',
  );

  // La proiezione Garmin è derivata, mai scritta a mano: rigenerarla insieme
  // al documento canonico è l'unico modo per impedire che divergano.
  final garmin = buildGarminVectorsDocument();
  final garminFile = garminVectorsFile();
  garminFile.parent.createSync(recursive: true);
  garminFile.writeAsStringSync('${jsonEncode(garmin)}\n');
  stdout.writeln(
    'Scritti ${(garmin['vectors']! as List).length} vettori Garmin in '
    '${garminFile.path} (${garminFile.lengthSync()} byte)',
  );
}
