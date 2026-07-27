import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/services/cloud/duo_service.dart';

void main() {
  test(
    'Duo accepts existing scoring modes and fails closed for Star Point',
    () {
      expect(supportsDuoScoring(MatchFormat.goldenPointBo3), isTrue);
      expect(supportsDuoScoring(MatchFormat.advantageBo3), isTrue);
      expect(supportsDuoScoring(MatchFormat.starPointBo3), isFalse);
      expect(
        duoStarPointUnsupportedMessage,
        contains('protocollo di punteggio v2'),
      );
    },
  );

  test('Duo service rejects Star Point before any cloud dependency', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container
        .read(duoServiceProvider)
        .createSession(
          matchId: 'local-star-match',
          format: MatchFormat.starPointBo3,
        );

    expect(result.session, isNull);
    expect(result.error, duoStarPointUnsupportedMessage);
    expect(result.canDiscardLocal, isTrue);
  });
}
