library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists Supabase refresh/access tokens in Keychain (iOS) or Keystore-backed
/// encrypted storage (Android). Existing Supabase Flutter SharedPreferences
/// sessions are migrated once and then removed.
class RallyMateSecureSessionStorage extends LocalStorage {
  RallyMateSecureSessionStorage({required this.projectRef})
    : _storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accountName: 'com.rallymate.auth.$projectRef',
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
        aOptions: AndroidOptions(
          storageNamespace: 'rallymate_auth_$projectRef',
          migrateWithBackup: true,
          resetOnError: true,
        ),
      );

  final String projectRef;
  final FlutterSecureStorage _storage;
  late SharedPreferences _preferences;

  String get _sessionKey => 'rallymate.$projectRef.supabase.session.v2';
  String get _secureInstallKey => 'rallymate.$projectRef.install';
  String get _localInstallKey => 'rallymate_${projectRef}_install';
  String get _legacyHostKey => 'sb-$projectRef-auth-token';

  @override
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await _handleFreshInstall();
    await _migrateLegacySession();
    final current = await _storage.read(key: _sessionKey);
    if (current != null && !isStructurallyValidSupabaseSession(current)) {
      await removePersistedSession();
    }
  }

  /// Keychain survives an iOS uninstall. A marker mirrored in ordinary app
  /// storage lets us distinguish an upgrade from a reinstall and prevents a
  /// previous owner session from silently returning after reinstall.
  Future<void> _handleFreshInstall() async {
    final localMarker = _preferences.getString(_localInstallKey);
    final secureMarker = await _storage.read(key: _secureInstallKey);
    if (localMarker == null && secureMarker != null) {
      await _storage.deleteAll();
    } else if (localMarker != null &&
        secureMarker != null &&
        localMarker != secureMarker) {
      await _storage.deleteAll();
    }

    final marker = localMarker ?? _newMarker();
    await _preferences.setString(_localInstallKey, marker);
    await _storage.write(key: _secureInstallKey, value: marker);
  }

  Future<void> _migrateLegacySession() async {
    if (await _storage.containsKey(key: _sessionKey)) return;
    final candidates = <String>[_legacyHostKey, supabasePersistSessionKey];
    for (final key in candidates) {
      final legacy = _preferences.getString(key);
      if (legacy == null) continue;
      if (isStructurallyValidSupabaseSession(legacy)) {
        await _storage.write(key: _sessionKey, value: legacy);
      }
      await _preferences.remove(key);
      if (await _storage.containsKey(key: _sessionKey)) return;
    }
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
    await _preferences.remove(_legacyHostKey);
    await _preferences.remove(supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (!isStructurallyValidSupabaseSession(persistSessionString)) {
      await removePersistedSession();
      return;
    }
    await _storage.write(key: _sessionKey, value: persistSessionString);
    await _preferences.remove(_legacyHostKey);
    await _preferences.remove(supabasePersistSessionKey);
  }

  GotrueAsyncStorage get pkceStorage =>
      RallyMateSecurePkceStorage(_storage, projectRef);

  String _newMarker() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

class RallyMateSecurePkceStorage extends GotrueAsyncStorage {
  RallyMateSecurePkceStorage(this._storage, this._projectRef);

  final FlutterSecureStorage _storage;
  final String _projectRef;

  String _key(String key) => 'rallymate.$_projectRef.pkce.$key';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);
}

bool isStructurallyValidSupabaseSession(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return false;
    final refreshToken = decoded['refresh_token']?.toString() ?? '';
    final accessToken = decoded['access_token']?.toString() ?? '';
    final user = decoded['user'];
    return refreshToken.isNotEmpty &&
        accessToken.split('.').length == 3 &&
        user is Map &&
        (user['id']?.toString().isNotEmpty ?? false);
  } catch (_) {
    return false;
  }
}
