import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/domain/social_matching.dart';

void main() {
  test('compatibility bounded 0-100 and deterministic', () {
    final a = compatibilityScore(
      myScore: 70,
      otherScore: 72,
      myAvailability: 'TODAY',
      otherAvailability: 'TODAY',
      myStyles: ['control'],
      otherStyles: ['control'],
      myRole: 'LEFT',
      otherRole: 'RIGHT',
      otherReliability: 95,
    );
    final b = compatibilityScore(
      myScore: 70,
      otherScore: 72,
      myAvailability: 'TODAY',
      otherAvailability: 'TODAY',
      myStyles: ['control'],
      otherStyles: ['control'],
      myRole: 'LEFT',
      otherRole: 'RIGHT',
      otherReliability: 95,
    );
    expect(a, b);
    expect(a, inInclusiveRange(0, 100));
    expect(a, greaterThanOrEqualTo(85)); // match quasi perfetto
  });

  test('complementary roles beat same fixed side', () {
    int score(String myRole, String otherRole) => compatibilityScore(
      myScore: 70,
      otherScore: 70,
      myAvailability: 'FLEX',
      otherAvailability: 'FLEX',
      myStyles: const [],
      otherStyles: const [],
      myRole: myRole,
      otherRole: otherRole,
      otherReliability: 80,
    );
    expect(score('LEFT', 'RIGHT'), greaterThan(score('LEFT', 'LEFT')));
    expect(score('RIGHT', 'LEFT'), greaterThan(score('RIGHT', 'RIGHT')));
  });

  test('big skill gap tanks compatibility', () {
    int score(int other) => compatibilityScore(
      myScore: 60,
      otherScore: other,
      myAvailability: 'TODAY',
      otherAvailability: 'TODAY',
      myStyles: const ['control'],
      otherStyles: const ['control'],
      myRole: 'FLEX',
      otherRole: 'FLEX',
      otherReliability: 90,
    );
    expect(score(62), greaterThan(score(95)));
    expect(score(95), lessThan(70));
  });

  test('map position stable and inside bounds', () {
    final p1 = mapPositionFor('user_abc');
    final p2 = mapPositionFor('user_abc');
    expect(p1.dx, p2.dx);
    expect(p1.dy, p2.dy);
    expect(p1.dx, inInclusiveRange(0.10, 0.90));
    expect(p1.dy, inInclusiveRange(0.10, 0.90));
    expect(mapPositionFor('user_xyz').dx, isNot(p1.dx));
  });

  test('badge scale monotone', () {
    expect(badgeForScore(95), 'A+');
    expect(badgeForScore(75), 'B+');
    expect(badgeForScore(50), 'C');
  });
}
