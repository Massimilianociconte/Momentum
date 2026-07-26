import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/services/wearable_match_dispatcher.dart';

ConnectedDevice device({
  required String platform,
  String status = 'READY',
  String capabilitiesJson = '{}',
}) => ConnectedDevice(
  id: 'test-$platform',
  platform: platform,
  family: platform,
  displayName: platform,
  alias: '',
  status: status,
  capabilitiesJson: capabilitiesJson,
  companionInstalled: true,
  permissionsComplete: true,
  isDefault: false,
  setupStep: 6,
  createdAtMs: 1,
);

void main() {
  test('health-only and retired providers never qualify for scoring', () {
    expect(isScoringWearableReady(device(platform: 'GOOGLE_HEALTH')), isFalse);
    expect(isScoringWearableReady(device(platform: 'TIZEN_RETIRED')), isFalse);
  });

  test('Garmin and Fitbit qualify only after a READY diagnostic', () {
    expect(
      isScoringWearableReady(device(platform: 'GARMIN_CONNECT_IQ')),
      isTrue,
    );
    expect(isScoringWearableReady(device(platform: 'FITBIT_OS')), isTrue);
    expect(
      isScoringWearableReady(
        device(platform: 'FITBIT_OS', status: 'NOT_REACHABLE'),
      ),
      isFalse,
    );
  });

  test('provider in capabilities overrides legacy platform label', () {
    final fitbit = device(
      platform: 'CLOUD_PROVIDER',
      capabilitiesJson: '{"provider":"FITBIT_OS"}',
    );
    expect(wearableProviderFor(fitbit), 'FITBIT_OS');
    expect(isScoringWearableReady(fitbit), isTrue);
  });
}
