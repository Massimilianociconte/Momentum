library;

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart' show generateEventId;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../notifications.dart';

const _installationIdKey = 'push_installation_id_v1';

Future<String> pushInstallationId(Ref ref) async {
  final kv = ref.read(keyValueRepoProvider);
  final existing = (await kv.get(_installationIdKey))?.trim() ?? '';
  if (_uuid.hasMatch(existing)) return existing;
  final created = generateEventId();
  await kv.set(_installationIdKey, created);
  return created;
}

Future<void> registerPushDevice(
  Ref ref,
  SupabaseClient client,
  RemotePushToken token,
) async {
  final installationId = await pushInstallationId(ref);
  await client.rpc(
    'register_my_push_device',
    params: {
      'p_installation_id': installationId,
      'p_platform': token.platform,
      'p_transport': token.transport,
      'p_environment': token.environment,
      'p_token': token.token,
      'p_app_version': const String.fromEnvironment('RALLYMATE_APP_VERSION'),
      'p_locale': _localeTag(),
    },
  );
  await ref
      .read(keyValueRepoProvider)
      .set('last_push_registration_at', DateTime.now().toUtc().toIso8601String());
}

Future<void> deactivatePushInstallation(
  Ref ref,
  SupabaseClient client,
) async {
  final raw = await ref.read(keyValueRepoProvider).get(_installationIdKey);
  final installationId = raw?.trim() ?? '';
  if (!_uuid.hasMatch(installationId)) return;
  await client.rpc(
    'deactivate_my_push_device',
    params: {'p_installation_id': installationId},
  );
}

String _localeTag() {
  // Kept dependency-free: the OS locale is diagnostics only and never used
  // for identity or ad profiling.
  final value = PlatformDispatcher.instance.locale.toLanguageTag();
  return value.length <= 24 ? value : value.substring(0, 24);
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
