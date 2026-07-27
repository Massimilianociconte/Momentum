import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/match_scoring_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Garmin and Fitbit lock phone scoring; native watches do not', () {
    expect(MatchScoringLockService.locksPhoneScoring('GARMIN_CONNECT_IQ'), isTrue);
    expect(MatchScoringLockService.locksPhoneScoring('FITBIT_OS'), isTrue);
    expect(MatchScoringLockService.locksPhoneScoring('APPLE_WATCH'), isFalse);
    expect(MatchScoringLockService.locksPhoneScoring('WEAR_OS'), isFalse);
  });

  test('lock persists and blocks until unlock', () async {
    final service = MatchScoringLockService();
    await service.lock('match-1', 'GARMIN_CONNECT_IQ');
    expect(await service.owner('match-1'), 'GARMIN_CONNECT_IQ');
    expect(await service.isPhoneScoringBlocked('match-1'), isTrue);
    await service.unlock('match-1');
    expect(await service.isPhoneScoringBlocked('match-1'), isFalse);
  });

  test('Apple Watch dispatch does not create a lock', () async {
    final service = MatchScoringLockService();
    await service.lock('match-2', 'APPLE_WATCH');
    expect(await service.owner('match-2'), isNull);
    expect(await service.isPhoneScoringBlocked('match-2'), isFalse);
  });
}
