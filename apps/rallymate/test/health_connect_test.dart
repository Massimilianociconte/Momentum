import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/health_connect.dart';

void main() {
  test('current health window starts at local midnight, not 24 hours ago', () {
    final now = DateTime(2026, 7, 11, 13, 42, 18);

    final window = HealthDayWindow.current(now);

    expect(window.start, DateTime(2026, 7, 11));
    expect(window.end, now);
    expect(
      window.end.difference(window.start),
      const Duration(hours: 13, minutes: 42, seconds: 18),
    );
  });

  test('current health window rolls over at the next local midnight', () {
    final beforeMidnight = HealthDayWindow.current(
      DateTime(2026, 7, 11, 23, 59, 59),
    );
    final afterMidnight = HealthDayWindow.current(
      DateTime(2026, 7, 12, 0, 0, 1),
    );

    expect(beforeMidnight.start, DateTime(2026, 7, 11));
    expect(afterMidnight.start, DateTime(2026, 7, 12));
  });

  test('source attribution recognizes supported indirect providers', () {
    expect(
      HealthSourceMetadata.inferProvider(
        application: 'Oura',
        bundleId: 'com.ouraring.oura',
      ),
      'OURA_HEALTH_HUB',
    );
    expect(
      HealthSourceMetadata.inferProvider(
        application: 'RingConn',
        bundleId: 'com.ringconn.app',
      ),
      'RINGCONN_HEALTH_HUB',
    );
    expect(
      HealthSourceMetadata.inferProvider(
        application: 'Ultrahuman',
        bundleId: 'com.ultrahuman.app',
      ),
      'ULTRAHUMAN_HEALTH_HUB',
    );
    expect(
      HealthSourceMetadata.inferProvider(
        application: 'Zepp',
        bundleId: 'com.huami.watch.hmwatchmanager',
      ),
      'ZEPP_HEALTH_HUB',
    );
  });

  test('HRV keeps its native statistical method in the normalized unit', () {
    final sdnn = HealthConnectSummary.fromMap({
      'heartRateVariabilityMs': 52.4,
      'heartRateVariabilityMethod': 'SDNN',
    });
    final rmssd = HealthConnectSummary.fromMap({
      'heartRateVariabilityMs': 47.1,
      'heartRateVariabilityMethod': 'RMSSD',
    });

    expect(sdnn.heartRateVariabilityUnit, 'ms_sdnn');
    expect(rmssd.heartRateVariabilityUnit, 'ms_rmssd');
  });
}
