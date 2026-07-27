library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications.dart';
import 'cloud_service.dart';
import 'push_device_repository.dart';

enum PushRegistrationResult {
  registered,
  signedOut,
  profileNotLinked,
  permissionDenied,
  nativeUnavailable,
  networkDeferred,
}

class PushRegistrationService {
  PushRegistrationService(this.ref);

  final Ref ref;
  Future<PushRegistrationResult>? _inFlight;
  DateTime? _lastSuccess;

  Future<PushRegistrationResult> sync({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    if (!force &&
        _lastSuccess != null &&
        DateTime.now().difference(_lastSuccess!) <
            const Duration(minutes: 10)) {
      return Future.value(PushRegistrationResult.registered);
    }
    late final Future<PushRegistrationResult> guarded;
    guarded = _syncNow()
        .then((result) {
          if (result == PushRegistrationResult.registered) {
            _lastSuccess = DateTime.now();
          }
          return result;
        })
        .whenComplete(() {
          if (identical(_inFlight, guarded)) _inFlight = null;
        });
    _inFlight = guarded;
    return guarded;
  }

  Future<PushRegistrationResult> _syncNow() async {
    final client = cloudClient;
    if (client?.auth.currentUser == null) {
      return PushRegistrationResult.signedOut;
    }
    if (!ref.read(cloudAuthProvider).profileLinked) {
      return PushRegistrationResult.profileNotLinked;
    }

    final notifications = ref.read(notificationServiceProvider);
    final permission = await notifications.status();
    if (!permission.granted) {
      try {
        await deactivatePushInstallation(ref, client!);
      } catch (_) {
        // Disabling notifications locally is authoritative. Server cleanup is
        // retried on the next foreground session.
      }
      await notifications.unregisterRemote();
      return PushRegistrationResult.permissionDenied;
    }

    final token = await notifications.registerRemote();
    if (token == null) return PushRegistrationResult.nativeUnavailable;
    try {
      final session = await freshCloudSession();
      if (session == null) return PushRegistrationResult.signedOut;
      await registerPushDevice(
        ref,
        client!,
        token,
      ).timeout(const Duration(seconds: 12));
      return PushRegistrationResult.registered;
    } on TimeoutException {
      return PushRegistrationResult.networkDeferred;
    } on PostgrestException {
      return PushRegistrationResult.networkDeferred;
    } catch (_) {
      return PushRegistrationResult.networkDeferred;
    }
  }
}

final pushRegistrationServiceProvider = Provider(
  (ref) => PushRegistrationService(ref),
);
