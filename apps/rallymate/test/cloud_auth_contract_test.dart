import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/cloud/cloud_config.dart';
import 'package:rallymate/services/cloud/cloud_service.dart';
import 'package:rallymate/services/cloud/secure_session_storage.dart';

void main() {
  group('client cloud configuration', () {
    test('rejects missing and malformed configuration', () {
      expect(validateCloudClientConfig('', '').issue, CloudConfigIssue.missing);
      expect(
        validateCloudClientConfig('not-an-url', 'sb_publishable_test').issue,
        CloudConfigIssue.invalidUrl,
      );
    });

    test('accepts publishable and legacy anon keys', () {
      expect(
        validateCloudClientConfig(
          'https://project.supabase.co',
          'sb_publishable_test_value',
        ).isValid,
        isTrue,
      );
      expect(
        validateCloudClientConfig(
          'https://project.supabase.co',
          _jwtForRole('anon'),
        ).isValid,
        isTrue,
      );
    });

    test('builds the canonical Edge Functions endpoint', () {
      expect(
        buildFunctionsBase('https://project.supabase.co'),
        'https://project.supabase.co/functions/v1',
      );
      expect(
        buildFunctionsBase('http://127.0.0.1:54321/'),
        'http://127.0.0.1:54321/functions/v1',
      );
      expect(
        buildFunctionsBase('https://api.rallymate.example/'),
        'https://api.rallymate.example/functions/v1',
      );
    });

    test('rejects every server-privileged key shape', () {
      expect(
        validateCloudClientConfig(
          'https://project.supabase.co',
          'sb_secret_private',
        ).issue,
        CloudConfigIssue.privilegedKey,
      );
      expect(
        validateCloudClientConfig(
          'https://project.supabase.co',
          _jwtForRole('service_role'),
        ).issue,
        CloudConfigIssue.privilegedKey,
      );
    });
  });

  group('secure session migration contract', () {
    test('accepts a complete persisted Supabase session', () {
      final raw = jsonEncode({
        'access_token': 'header.payload.signature',
        'refresh_token': 'refresh-token',
        'user': {'id': 'user-id'},
      });
      expect(isStructurallyValidSupabaseSession(raw), isTrue);
    });

    test('rejects corrupt, incomplete or user-less sessions', () {
      expect(isStructurallyValidSupabaseSession('not-json'), isFalse);
      expect(
        isStructurallyValidSupabaseSession(
          jsonEncode({
            'access_token': 'header.payload.signature',
            'refresh_token': '',
            'user': {'id': 'user-id'},
          }),
        ),
        isFalse,
      );
      expect(
        isStructurallyValidSupabaseSession(
          jsonEncode({
            'access_token': 'header.payload.signature',
            'refresh_token': 'refresh-token',
            'user': <String, Object?>{},
          }),
        ),
        isFalse,
      );
    });

    test('iOS runner signs with the Keychain Sharing entitlement', () {
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(entitlements, contains('<key>keychain-access-groups</key>'));
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
      );
    });
  });

  group('local profile ownership', () {
    test('old local data never becomes a cloud session', () {
      expect(
        resolveProfileLinkStatus(
          signedIn: false,
          hasCustomizedLocalProfile: true,
        ),
        ProfileLinkStatus.localOnly,
      );
    });

    test('requires explicit linking for customized local data', () {
      expect(
        resolveProfileLinkStatus(
          signedIn: true,
          signedInUserId: 'new-user',
          hasCustomizedLocalProfile: true,
        ),
        ProfileLinkStatus.linkRequired,
      );
    });

    test('detects a different previously linked account', () {
      expect(
        resolveProfileLinkStatus(
          signedIn: true,
          signedInUserId: 'user-b',
          linkedCloudUserId: 'user-a',
          hasCustomizedLocalProfile: true,
        ),
        ProfileLinkStatus.differentAccount,
      );
    });

    test('marks only matching ownership as linked', () {
      expect(
        resolveProfileLinkStatus(
          signedIn: true,
          signedInUserId: 'user-a',
          linkedCloudUserId: 'user-a',
          hasCustomizedLocalProfile: true,
          cloudProfileExists: true,
        ),
        ProfileLinkStatus.linked,
      );
      expect(
        resolveProfileLinkStatus(
          signedIn: true,
          signedInUserId: 'user-a',
          linkedCloudUserId: 'user-a',
          hasCustomizedLocalProfile: true,
          cloudProfileExists: false,
        ),
        ProfileLinkStatus.cloudProfileIncomplete,
      );
    });
  });

  group('assistant error privacy', () {
    test('never exposes provider configuration to end users', () {
      expect(
        assistantErrorMessage('no_llm_configured'),
        'Servizio temporaneamente non disponibile',
      );
      expect(
        assistantErrorMessage('llm_unavailable'),
        'Servizio temporaneamente non disponibile',
      );
    });

    test('distinguishes authentication and entitlement', () {
      expect(
        assistantErrorMessage('unauthorized'),
        contains('Sessione scaduta'),
      );
      expect(assistantErrorMessage('plan_required'), contains('Pro'));
    });
  });
}

String _jwtForRole(String role) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'role': role})}.signature';
}
