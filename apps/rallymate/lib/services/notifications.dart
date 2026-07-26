/// Native local notifications for match, training and sync events.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationPermissionStatus {
  granted,
  denied,
  notDetermined,
  unsupported,
}

class NotificationPermissionState {
  const NotificationPermissionState({
    required this.status,
    required this.granted,
    required this.canRequest,
  });

  final NotificationPermissionStatus status;
  final bool granted;
  final bool canRequest;

  factory NotificationPermissionState.unsupported() =>
      const NotificationPermissionState(
        status: NotificationPermissionStatus.unsupported,
        granted: false,
        canRequest: false,
      );

  factory NotificationPermissionState.fromMap(Map<Object?, Object?> map) {
    final status = switch (map['status']) {
      'granted' ||
      'authorized' ||
      'provisional' ||
      'ephemeral' => NotificationPermissionStatus.granted,
      'notDetermined' => NotificationPermissionStatus.notDetermined,
      'unsupported' => NotificationPermissionStatus.unsupported,
      _ => NotificationPermissionStatus.denied,
    };
    return NotificationPermissionState(
      status: status,
      granted:
          map['granted'] as bool? ??
          status == NotificationPermissionStatus.granted,
      canRequest: map['canRequest'] as bool? ?? false,
    );
  }

  String get label => switch (status) {
    NotificationPermissionStatus.granted => 'Attive',
    NotificationPermissionStatus.denied => 'Disattivate',
    NotificationPermissionStatus.notDetermined => 'Da autorizzare',
    NotificationPermissionStatus.unsupported => 'Non supportate',
  };
}

class RemotePushToken {
  const RemotePushToken({
    required this.token,
    required this.platform,
    required this.transport,
    required this.environment,
  });

  final String token;
  final String platform;
  final String transport;
  final String environment;

  static RemotePushToken? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final token = map['token']?.toString().trim() ?? '';
    final platform = map['platform']?.toString().trim().toUpperCase() ?? '';
    final transport = map['transport']?.toString().trim().toUpperCase() ?? '';
    final environment =
        map['environment']?.toString().trim().toUpperCase() ?? '';
    final tokenValid = switch (transport) {
      'APNS' => RegExp(r'^[0-9a-f]{64}$').hasMatch(token),
      'FCM' =>
        token.length >= 20 &&
            token.length <= 4096 &&
            !RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(token),
      _ => false,
    };
    if (token.isEmpty ||
        !tokenValid ||
        !const {'IOS', 'ANDROID', 'WATCHOS'}.contains(platform) ||
        !const {'APNS', 'FCM'}.contains(transport) ||
        !const {'SANDBOX', 'PRODUCTION'}.contains(environment)) {
      return null;
    }
    return RemotePushToken(
      token: token,
      platform: platform,
      transport: transport,
      environment: environment,
    );
  }
}

class RallyNotificationService {
  RallyNotificationService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.rallymate/notifications') {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  final MethodChannel _channel;
  final StreamController<Uri> _openedLinks = StreamController.broadcast();
  final StreamController<RemotePushToken> _remoteTokenChanges =
      StreamController.broadcast();

  Stream<Uri> get openedLinks => _openedLinks.stream;
  Stream<RemotePushToken> get remoteTokenChanges => _remoteTokenChanges.stream;

  Future<Uri?> initialOpenedLink() async {
    try {
      final value = await _channel.invokeMethod<String>('initialNotification');
      final uri = Uri.tryParse(value?.trim() ?? '');
      return uri?.scheme == 'rallymate' ? uri : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'notificationOpened':
        final value = call.arguments?.toString().trim() ?? '';
        final uri = Uri.tryParse(value);
        if (uri?.scheme == 'rallymate') _openedLinks.add(uri!);
        return;
      case 'remoteTokenChanged':
        final arguments = call.arguments;
        if (arguments is! Map) return;
        final token = RemotePushToken.fromMap(
          Map<Object?, Object?>.from(arguments),
        );
        if (token != null) _remoteTokenChanges.add(token);
        return;
      default:
        return;
    }
  }

  Future<RemotePushToken?> registerRemote() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'registerRemote',
      );
      return RemotePushToken.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> unregisterRemote() async {
    try {
      await _channel.invokeMethod<void>('unregisterRemote');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<NotificationPermissionState> status() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('status');
      if (map == null) return NotificationPermissionState.unsupported();
      return NotificationPermissionState.fromMap(map);
    } on MissingPluginException {
      return NotificationPermissionState.unsupported();
    } on PlatformException {
      return NotificationPermissionState.unsupported();
    }
  }

  Future<NotificationPermissionState> requestPermission() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'requestPermission',
      );
      if (map == null) return NotificationPermissionState.unsupported();
      return NotificationPermissionState.fromMap(map);
    } on MissingPluginException {
      return NotificationPermissionState.unsupported();
    } on PlatformException {
      return NotificationPermissionState.unsupported();
    }
  }

  Future<bool> show({
    required String id,
    required String title,
    required String body,
    String category = 'status',
    String? payload,
  }) async {
    final args = <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'category': category,
    };
    if (payload != null) args['payload'] = payload;
    try {
      return await _channel.invokeMethod<bool>('show', args) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String category = 'reminder',
    String? payload,
  }) async {
    final args = <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'scheduledAtMs': scheduledAt.millisecondsSinceEpoch,
      'category': category,
    };
    if (payload != null) args['payload'] = payload;
    try {
      return await _channel.invokeMethod<bool>('schedule', args) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _openedLinks.close();
    _remoteTokenChanges.close();
  }

  Future<bool> showMatchCompleted({
    required String score,
    String? matchId,
  }) {
    return show(
      id: 'match_completed_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Partita salvata',
      body:
          'Risultato finale: $score. Le statistiche sono pronte nello storico.',
      category: 'match',
      payload: matchId != null && matchId.isNotEmpty
          ? 'rallymate://match/${Uri.encodeComponent(matchId)}'
          : 'rallymate://match',
    );
  }

  Future<bool> showTrainingCompleted(String title) {
    return show(
      id: 'training_completed_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Allenamento registrato',
      body: '$title aggiunto al tuo percorso.',
      category: 'training',
      payload: 'rallymate://training',
    );
  }

  Future<bool> scheduleTrainingReminder(DateTime scheduledAt) {
    return schedule(
      id: 'training_reminder',
      title: 'Richiamo allenamento',
      body: 'Una sessione breve oggi mantiene il ritmo anche fuori partita.',
      scheduledAt: scheduledAt,
      category: 'training',
      payload: 'rallymate://training',
    );
  }

  Future<bool> scheduleWeeklyRecap(DateTime scheduledAt) {
    return schedule(
      id: 'weekly_recap',
      title: 'Riepilogo Padelandia',
      body: 'Controlla trend, partite e allenamenti della settimana.',
      scheduledAt: scheduledAt,
      category: 'recap',
      payload: 'rallymate://training',
    );
  }
}

final notificationServiceProvider = Provider<RallyNotificationService>((ref) {
  final service = RallyNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final notificationPermissionProvider =
    FutureProvider<NotificationPermissionState>((ref) {
      return ref.watch(notificationServiceProvider).status();
    });
