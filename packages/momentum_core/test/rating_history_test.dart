import 'package:rally_core/rally_core.dart';
import 'package:test/test.dart';

MatchSummary _match(
  String id,
  int endTimeMs, {
  required bool won,
  OpponentDifficulty difficulty = OpponentDifficulty.sameLevel,
}) {
  return MatchSummary(
    matchId: id,
    endTimeMs: endTimeMs,
    won: won,
    pointsFor: 40,
    pointsAgainst: 30,
    gamesFor: 12,
    gamesAgainst: 6,
    setsFor: 2,
    setsAgainst: 0,
    clutchScore: 60,
    bestStreak: 4,
    durationMs: 60 * 60 * 1000,
    opponentDifficulty: difficulty,
  );
}

void main() {
  test('nessuno storico: rating iniziale, delta zero', () {
    final history = RatingHistory.compute(const []);
    expect(history.isEmpty, isTrue);
    expect(history.current, RatingEngine.initial);
    expect(history.deltaOverLast(5), 0);
  });

  test('vittoria alla pari aumenta, sconfitta diminuisce (simmetriche)', () {
    final win = RatingHistory.compute([_match('m1', 1000, won: true)]);
    final loss = RatingHistory.compute([_match('m1', 1000, won: false)]);
    expect(win.current, greaterThan(RatingEngine.initial));
    expect(loss.current, lessThan(RatingEngine.initial));
    // Contro un pari livello il guadagno e la perdita sono speculari.
    expect(
      win.current - RatingEngine.initial,
      closeTo(RatingEngine.initial - loss.current, 1e-9),
    );
    expect(win.points.single.delta, closeTo(RatingEngine.kFactor / 2, 1e-9));
  });

  test('battere un avversario più forte vale più di uno alla pari', () {
    final vsHarder = RatingHistory.compute([
      _match('m1', 1000, won: true, difficulty: OpponentDifficulty.muchHarder),
    ]);
    final vsSame = RatingHistory.compute([_match('m1', 1000, won: true)]);
    expect(vsHarder.current, greaterThan(vsSame.current));
  });

  test('perdere contro un avversario più debole costa più caro', () {
    final vsEasier = RatingHistory.compute([
      _match('m1', 1000, won: false, difficulty: OpponentDifficulty.muchEasier),
    ]);
    final vsSame = RatingHistory.compute([_match('m1', 1000, won: false)]);
    expect(vsEasier.current, lessThan(vsSame.current));
  });

  test('ordine di input irrilevante: la serie è cronologica e stabile', () {
    final matches = [
      _match('m3', 3000, won: true),
      _match('m1', 1000, won: false),
      _match('m2', 2000, won: true),
    ];
    final a = RatingHistory.compute(matches);
    final b = RatingHistory.compute(matches.reversed.toList());
    expect(a.points.map((p) => p.matchId), ['m1', 'm2', 'm3']);
    expect(a.current, b.current);
    expect(
      a.points.map((p) => p.rating).toList(),
      b.points.map((p) => p.rating).toList(),
    );
  });

  test('pari endTimeMs: spareggio deterministico per matchId', () {
    final a = RatingHistory.compute([
      _match('m_b', 1000, won: true),
      _match('m_a', 1000, won: false),
    ]);
    expect(a.points.map((p) => p.matchId), ['m_a', 'm_b']);
  });

  test('deltaOverLast copre finestre più lunghe dello storico', () {
    final history = RatingHistory.compute([
      _match('m1', 1000, won: true),
      _match('m2', 2000, won: true),
    ]);
    expect(
      history.deltaOverLast(5),
      closeTo(history.current - RatingEngine.initial, 1e-9),
    );
    expect(history.deltaOverLast(1), closeTo(history.points.last.delta, 1e-9));
  });

  test('la somma dei delta ricostruisce il rating corrente', () {
    final history = RatingHistory.compute([
      _match('m1', 1000, won: true),
      _match('m2', 2000, won: false, difficulty: OpponentDifficulty.harder),
      _match('m3', 3000, won: true, difficulty: OpponentDifficulty.muchHarder),
    ]);
    final sum = history.points.fold<double>(0, (a, p) => a + p.delta);
    expect(RatingEngine.initial + sum, closeTo(history.current, 1e-9));
  });
}
