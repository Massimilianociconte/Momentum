/// Configurazione cloud — l'app funziona AL 100% anche senza (offline-first).
///
/// Le credenziali si passano in build/run senza toccare il codice:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=REVENUECAT_ANDROID_KEY=goog_... \
///     --dart-define=REVENUECAT_IOS_KEY=appl_... \
///     --dart-define=RALLYMATE_PRIVACY_URL=https://... \
///     --dart-define=RALLYMATE_TERMS_URL=https://...
///
/// Se una chiave manca, la relativa feature si disattiva con messaggi
/// chiari in UI (nessun crash, nessun costo).
library;

import 'dart:convert';

enum CloudConfigIssue { none, missing, invalidUrl, invalidKey, privilegedKey }

class CloudConfigValidation {
  const CloudConfigValidation(this.issue, this.message);

  final CloudConfigIssue issue;
  final String message;

  bool get isValid => issue == CloudConfigIssue.none;
}

CloudConfigValidation validateCloudClientConfig(String rawUrl, String rawKey) {
  final url = rawUrl.trim();
  final key = rawKey.trim();
  if (url.isEmpty || key.isEmpty) {
    return const CloudConfigValidation(
      CloudConfigIssue.missing,
      'Configurazione cloud assente in questa build.',
    );
  }

  final uri = Uri.tryParse(url);
  final localHost = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
  final validScheme =
      uri?.scheme == 'https' || (localHost && uri?.scheme == 'http');
  if (uri == null || uri.host.isEmpty || !validScheme) {
    return const CloudConfigValidation(
      CloudConfigIssue.invalidUrl,
      'URL cloud non valido.',
    );
  }

  if (key.startsWith('sb_secret_') || _jwtRole(key) == 'service_role') {
    return const CloudConfigValidation(
      CloudConfigIssue.privilegedKey,
      'La build contiene una chiave server non consentita.',
    );
  }
  final validPublishable = key.startsWith('sb_publishable_');
  final validLegacyAnon = _jwtRole(key) == 'anon';
  if (!validPublishable && !validLegacyAnon) {
    return const CloudConfigValidation(
      CloudConfigIssue.invalidKey,
      'Chiave cloud pubblica non valida.',
    );
  }
  return const CloudConfigValidation(CloudConfigIssue.none, 'Cloud pronto.');
}

String? _jwtRole(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    return payload is Map ? payload['role']?.toString() : null;
  } catch (_) {
    return null;
  }
}

String buildFunctionsBase(String rawSupabaseUrl) {
  final normalized = rawSupabaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  return normalized.isEmpty ? '' : '$normalized/functions/v1';
}

abstract final class CloudConfig {
  // Canonical names. The compact aliases keep older CI/Xcode configurations
  // working during the migration, but all new build tooling writes the names
  // with underscores.
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _legacySupabaseUrl = String.fromEnvironment('SUPABASEURL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacySupabaseAnonKey = String.fromEnvironment(
    'SUPABASEANONKEY',
  );

  static String get supabaseUrl => _supabaseUrl.trim().isNotEmpty
      ? _supabaseUrl.trim()
      : _legacySupabaseUrl.trim();

  static String get supabaseAnonKey {
    if (_supabaseAnonKey.trim().isNotEmpty) return _supabaseAnonKey.trim();
    if (_supabasePublishableKey.trim().isNotEmpty) {
      return _supabasePublishableKey.trim();
    }
    return _legacySupabaseAnonKey.trim();
  }

  static const revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );
  static const revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const privacyPolicyUrl = String.fromEnvironment(
    'RALLYMATE_PRIVACY_URL',
  );
  static const termsUrl = String.fromEnvironment('RALLYMATE_TERMS_URL');

  /// BYPASS DI TEST (mai in produzione): sblocca tutti i piani in locale.
  ///   flutter run --dart-define=RALLYMATE_TEST_PREMIUM=true
  /// Nota: sblocca solo il client. Le feature server-side (backup, LLM,
  /// coach) restano protette da RLS sul piano reale del profilo — per
  /// testarle end-to-end imposta il piano sul DB:
  ///   update profiles set plan='pro' where user_id='...';
  /// Neutralizzato in release (dart.vm.product): una build store non può
  /// attivare il bypass nemmeno passando il dart-define per errore.
  static const testPremium =
      bool.fromEnvironment('RALLYMATE_TEST_PREMIUM') &&
      !bool.fromEnvironment('dart.vm.product');

  static CloudConfigValidation get validation =>
      validateCloudClientConfig(supabaseUrl, supabaseAnonKey);

  static bool get supabaseConfigured => validation.isValid;

  /// Native callback used by email confirmation, email change and password
  /// recovery. Add this exact URL to Supabase Auth > Redirect URLs.
  static const authCallbackUrl = 'rallymate://auth-callback';

  /// Canonical Supabase Edge Functions URL. Keeping `/functions/v1` on the
  /// project URL also works for local development and custom domains.
  static String get functionsBase => buildFunctionsBase(supabaseUrl);

  /// URL pubblico di un recap condiviso.
  static String recapUrl(String slug) => '$functionsBase/recap?slug=$slug';

  /// URL pubblico richiesto da Google Play per eliminare l'account via web.
  static String get deleteAccountUrl =>
      supabaseConfigured ? '$functionsBase/delete-account' : '';
}
