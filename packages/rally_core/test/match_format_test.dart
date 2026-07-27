import 'package:rally_core/rally_core.dart';
import 'package:test/test.dart';

void main() {
  group('MatchFormat schema v3', () {
    test('Star Point round-trips as a distinct game scoring mode', () {
      final encoded = MatchFormat.starPointBo3.toJson();
      final decoded = MatchFormat.fromJson(encoded);

      expect(encoded['formatSchemaVersion'], 3);
      expect(encoded['gameScoringMode'], 'STAR_POINT');
      expect(encoded['goldenPoint'], isFalse);
      expect(decoded.id, 'STAR_POINT_BO3');
      expect(decoded.formatSchemaVersion, 3);
      expect(decoded.gameScoringMode, GameScoringMode.starPoint);
      expect(decoded.goldenPoint, isFalse);
    });

    test('deciding-set tie-break flag round-trips and defaults to true', () {
      final encoded = MatchFormat.advantageDecidingSetBo3.toJson();
      final decoded = MatchFormat.fromJson(encoded);

      expect(encoded['tieBreakInDecidingSet'], isFalse);
      expect(decoded.tieBreakInDecidingSet, isFalse);
      expect(decoded.requiresDecidingSetProtocol, isTrue);

      // Schema v1/v2 payloads never carried the flag: they always played the
      // deciding set with a tie-break.
      final legacy = MatchFormat.fromJson({'id': 'LEGACY', 'goldenPoint': true});
      expect(legacy.tieBreakInDecidingSet, isTrue);
      expect(legacy.requiresDecidingSetProtocol, isFalse);
    });

    test('new FIP formats are exposed as presets', () {
      final ids = MatchFormat.presets.map((format) => format.id).toList();
      expect(
        ids,
        containsAll({'MINI_SET_BO3', 'MATCH_TB7_BO3', 'ADV_NO_TB_THIRD_BO3'}),
      );
      expect(MatchFormat.miniSetBo3.gamesPerSet, 4);
      expect(MatchFormat.matchTieBreak7Bo3.superTieBreakDecider, isTrue);
      expect(MatchFormat.matchTieBreak7Bo3.superTieBreakPoints, 7);
    });

    test('legacy goldenPoint booleans preserve their original semantics', () {
      final legacyGolden = MatchFormat.fromJson({
        'id': 'LEGACY_GOLDEN',
        'goldenPoint': true,
      });
      final legacyAdvantage = MatchFormat.fromJson({
        'id': 'LEGACY_ADVANTAGE',
        'goldenPoint': false,
      });

      expect(legacyGolden.gameScoringMode, GameScoringMode.goldenPoint);
      expect(legacyAdvantage.gameScoringMode, GameScoringMode.advantage);
      expect(legacyGolden.formatSchemaVersion, 3);
      expect(legacyAdvantage.formatSchemaVersion, 3);
    });

    test('valid mode wins over the compatibility boolean', () {
      final decoded = MatchFormat.fromJson({
        'id': 'V2_STAR',
        'gameScoringMode': 'STAR_POINT',
        'goldenPoint': true,
      });

      expect(decoded.gameScoringMode, GameScoringMode.starPoint);
    });

    test('unknown mode falls back through the legacy boolean', () {
      final decoded = MatchFormat.fromJson({
        'id': 'FUTURE_MODE',
        'gameScoringMode': 'UNKNOWN_FUTURE_MODE',
        'goldenPoint': false,
      });

      expect(decoded.gameScoringMode, GameScoringMode.advantage);
    });

    test('all three game modes are available as separate BO3 presets', () {
      expect(
        MatchFormat.presets.map((format) => format.gameScoringMode),
        containsAll({
          GameScoringMode.advantage,
          GameScoringMode.starPoint,
          GameScoringMode.goldenPoint,
        }),
      );
      expect(MatchFormat.presets.first, MatchFormat.goldenPointBo3);
    });
  });
}
