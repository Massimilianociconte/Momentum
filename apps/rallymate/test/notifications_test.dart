import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/notifications.dart';

void main() {
  group('RemotePushToken', () {
    test('accepts valid APNs and FCM payloads', () {
      final apns = RemotePushToken.fromMap({
        'token': ''.padLeft(64, 'a'),
        'platform': 'ios',
        'transport': 'apns',
        'environment': 'sandbox',
      });
      final fcm = RemotePushToken.fromMap(const {
        'token': 'cdefghijklmnopqrstuvwx',
        'platform': 'ANDROID',
        'transport': 'FCM',
        'environment': 'PRODUCTION',
      });

      expect(apns?.platform, 'IOS');
      expect(apns?.transport, 'APNS');
      expect(fcm?.platform, 'ANDROID');
      expect(fcm?.transport, 'FCM');
    });

    test('rejects incomplete or unsupported native payloads', () {
      expect(RemotePushToken.fromMap(null), isNull);
      expect(
        RemotePushToken.fromMap(const {
          'token': '',
          'platform': 'IOS',
          'transport': 'APNS',
          'environment': 'SANDBOX',
        }),
        isNull,
      );
      expect(
        RemotePushToken.fromMap(const {
          'token': 'token',
          'platform': 'WEB',
          'transport': 'FCM',
          'environment': 'PRODUCTION',
        }),
        isNull,
      );
    });
  });

  test('Android FCM remains consent-gated and uses the FID API', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final bridge = File(
      'android/app/src/main/kotlin/com/rallymate/rallymate/'
      'NotificationBridge.kt',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/rallymate/rallymate/'
      'RallyMateFirebaseMessagingService.kt',
    ).readAsStringSync();
    final iosDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(
      manifest,
      contains('android:name="firebase_messaging_auto_init_enabled"'),
    );
    expect(
      manifest,
      contains('android:name="firebase_analytics_collection_enabled"'),
    );
    expect(
      manifest,
      contains('android:name="firebase_messaging_installation_id_enabled"'),
    );
    expect(bridge, contains('messaging.setAutoInitEnabled(true)'));
    expect(bridge, contains('messaging.setAutoInitEnabled(false)'));
    expect(bridge, contains('messaging.register()'));
    expect(bridge, contains('messaging.unregister()'));
    expect(bridge, isNot(contains('messaging.deleteToken()')));
    expect(
      service,
      contains('override fun onRegistered(installationId: String)'),
    );
    expect(service, isNot(contains('override fun onNewToken')));
    expect(bridge, contains('.addAction('));
    expect(iosDelegate, contains('center.setNotificationCategories'));
    expect(iosDelegate, contains('title: "Apri Momentum"'));
  });
}
