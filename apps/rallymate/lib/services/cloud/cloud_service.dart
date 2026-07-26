/// Servizi cloud Supabase: auth, backup Plus, wrapped link, assistant Pro,
/// coach marketplace. Tutto degrada con grazia se non configurato.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart'
    show DominantHand, PadelRole, PlayerLevel;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../domain/entitlements.dart';
import 'backup_payload.dart';
import 'cloud_config.dart';
import 'purchases_service.dart';
import 'push_device_repository.dart';
import 'secure_session_storage.dart';
import '../notifications.dart';

/// Budget massimo per ogni chiamata di rete: oltre, meglio fallire con un
/// messaggio chiaro che lasciare la UI appesa.
const _netTimeout = Duration(seconds: 12);
const _timeoutMessage = 'Rete lenta o assente. Riprova.';

Future<void>? _cloudInitialization;
bool _cloudInitialized = false;
String? _cloudInitializationError;

enum CloudRuntimeStatus { unavailable, initializing, ready, failed }

CloudRuntimeStatus get cloudRuntimeStatus {
  if (!CloudConfig.supabaseConfigured) return CloudRuntimeStatus.unavailable;
  if (_cloudInitialized) return CloudRuntimeStatus.ready;
  if (_cloudInitializationError != null) return CloudRuntimeStatus.failed;
  return CloudRuntimeStatus.initializing;
}

String? get cloudInitializationError => _cloudInitializationError;

/// Init idempotente, eseguito dopo il primo frame per non rallentare il lancio.
Future<void> initCloud() {
  if (!CloudConfig.supabaseConfigured || _cloudInitialized) {
    return Future.value();
  }
  return _cloudInitialization ??= _initializeCloud();
}

Future<void> _initializeCloud() async {
  try {
    final projectRef = Uri.parse(CloudConfig.supabaseUrl).host.split('.').first;
    final secureStorage = RallyMateSecureSessionStorage(projectRef: projectRef);
    await Supabase.initialize(
      url: CloudConfig.supabaseUrl,
      publishableKey: CloudConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: secureStorage,
        pkceAsyncStorage: secureStorage.pkceStorage,
      ),
    );
    _cloudInitialized = true;
    _cloudInitializationError = null;
  } catch (error) {
    _cloudInitializationError = error.runtimeType.toString();
    _cloudInitialization = null;
    rethrow;
  }
}

SupabaseClient? get cloudClient =>
    CloudConfig.supabaseConfigured && _cloudInitialized
    ? Supabase.instance.client
    : null;

SupabaseClient? get _client => cloudClient;

/// Riallinea il mirror locale solo mentre Supabase e RevenueCat rappresentano
/// ancora lo stesso utente. I controlli prima e dopo CustomerInfo impediscono a
/// uno switch account concorrente di scrivere il piano dell'utente precedente.
final storePlanSyncProvider = FutureProvider.family<void, String>((
  ref,
  userId,
) async {
  if (_client?.auth.currentUser?.id != userId) return;
  final snapshot = await PurchasesService.verifiedActivePlan(userId);
  if (_client?.auth.currentUser?.id != userId) return;
  final kv = ref.read(keyValueRepoProvider);
  await applyVerifiedStorePlan(
    supabaseUserId: userId,
    snapshot: snapshot,
    readAccountRole: () => kv.get('account_role'),
    readCurrentPlan: () async => Plan.fromName(await kv.get('plan')),
    readPremiumOverride: () async => (await kv.get('premium_override')) == 'true',
    // Background resume must not free-overwrite a paid mirror while RC lags.
    allowFreeDowngrade: false,
    writePlan: (plan) async {
      if (_client?.auth.currentUser?.id == userId &&
          ref.read(cloudAuthProvider).profileLinked) {
        await kv.set('plan', plan.name);
      }
    },
  );
});

Future<Session?> freshCloudSession() async {
  final client = _client;
  var session = client?.auth.currentSession;
  if (client == null || session == null) return null;
  if (!session.isExpired) return session;
  try {
    session = (await client.auth.refreshSession().timeout(_netTimeout)).session;
    return session;
  } catch (_) {
    return null;
  }
}

// ------------------------------------------------------------------ auth

enum ProfileLinkStatus {
  unknown,
  noLocalProfile,
  localOnly,
  registeredSignedOut,
  pendingEmailVerification,
  linkRequired,
  linked,
  differentAccount,
  cloudProfileIncomplete,
}

const _accountStateSchemaKey = 'cloud_account_state_schema';
const _accountStateSchemaVersion = '2';
const _linkedCloudUserIdKey = 'linked_cloud_user_id';
const _pendingProfileLinkEmailKey = 'pending_profile_link_email';
const _passwordRecoveryKey = 'password_recovery_active';
const _pendingAuthReturnToKey = 'pending_auth_return_to';
const _pendingDeepLinkKey = 'pending_deep_link';

ProfileLinkStatus resolveProfileLinkStatus({
  required bool signedIn,
  required bool hasCustomizedLocalProfile,
  String? signedInUserId,
  String? linkedCloudUserId,
  String? pendingEmail,
  bool? cloudProfileExists,
}) {
  final linkedId = linkedCloudUserId?.trim() ?? '';
  final pending = pendingEmail?.trim() ?? '';
  if (!signedIn || signedInUserId == null) {
    if (pending.isNotEmpty) return ProfileLinkStatus.pendingEmailVerification;
    if (linkedId.isNotEmpty) return ProfileLinkStatus.registeredSignedOut;
    return hasCustomizedLocalProfile
        ? ProfileLinkStatus.localOnly
        : ProfileLinkStatus.noLocalProfile;
  }
  if (linkedId.isNotEmpty && linkedId != signedInUserId) {
    return ProfileLinkStatus.differentAccount;
  }
  if (linkedId == signedInUserId) {
    return cloudProfileExists == false
        ? ProfileLinkStatus.cloudProfileIncomplete
        : ProfileLinkStatus.linked;
  }
  return hasCustomizedLocalProfile
      ? ProfileLinkStatus.linkRequired
      : ProfileLinkStatus.cloudProfileIncomplete;
}

class AuthState {
  const AuthState({
    this.userId,
    this.email,
    this.emailConfirmed = false,
    this.profileLinkStatus = ProfileLinkStatus.unknown,
    this.sessionExpired = false,
    this.passwordRecovery = false,
  });
  final String? userId;
  final String? email;
  final bool emailConfirmed;
  final ProfileLinkStatus profileLinkStatus;
  final bool sessionExpired;
  final bool passwordRecovery;

  bool get signedIn => userId != null;
  bool get profileLinked => profileLinkStatus == ProfileLinkStatus.linked;
  bool get requiresProfileLink =>
      profileLinkStatus == ProfileLinkStatus.linkRequired ||
      profileLinkStatus == ProfileLinkStatus.differentAccount ||
      profileLinkStatus == ProfileLinkStatus.cloudProfileIncomplete;
  static const signedOut = AuthState();

  factory AuthState.fromUser(
    User user, {
    ProfileLinkStatus profileLinkStatus = ProfileLinkStatus.unknown,
    bool passwordRecovery = false,
  }) => AuthState(
    userId: user.id,
    email: user.email,
    emailConfirmed: user.emailConfirmedAt != null,
    profileLinkStatus: profileLinkStatus,
    passwordRecovery: passwordRecovery,
  );
}

/// Esito di un'operazione auth: successo, successo-con-avviso (es. profilo
/// sincronizzato a metà) o errore. Distingue anche il caso "account creato,
/// serve confermare la email" che NON è un errore.
class AuthResult {
  const AuthResult._(
    this.ok,
    this.message, {
    this.emailConfirmationRequired = false,
    this.profileLinkRequired = false,
    this.profileLinkConflict = false,
  });

  const AuthResult.success({
    String? message,
    bool profileLinkRequired = false,
    bool profileLinkConflict = false,
  }) : this._(
         true,
         message,
         profileLinkRequired: profileLinkRequired,
         profileLinkConflict: profileLinkConflict,
       );
  const AuthResult.failure(String message) : this._(false, message);
  const AuthResult.emailConfirmation()
    : this._(
        true,
        'Controlla la posta per confermare l’accesso. Se avevi già un '
        'account, usa Accedi o Recupera password.',
        emailConfirmationRequired: true,
      );

  final bool ok;
  final String? message;
  final bool emailConfirmationRequired;
  final bool profileLinkRequired;
  final bool profileLinkConflict;
}

class CloudAuth extends Notifier<AuthState> {
  StreamSubscription<dynamic>? _sub;
  bool _reconciliationRunning = false;
  bool _reconciliationDirty = false;
  bool _passwordRecoveryActive = false;

  @override
  AuthState build() {
    final c = _client;
    if (c == null) return AuthState.signedOut;
    _sub?.cancel();
    _sub = c.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        unawaited(_hydrateAccountState(null));
        return;
      }
      final u = event.session?.user ?? c.auth.currentUser;
      if (u == null) {
        unawaited(_hydrateAccountState(null));
      } else {
        if (event.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryActive = true;
          unawaited(
            ref.read(keyValueRepoProvider).set(_passwordRecoveryKey, 'true'),
          );
        }
        state = AuthState.fromUser(
          u,
          passwordRecovery: _passwordRecoveryActive,
        );
        unawaited(reconcileCurrentSession());
      }
    });
    ref.onDispose(() => _sub?.cancel());
    final session = c.auth.currentSession;
    Future.microtask(() => reconcileCurrentSession());
    return session == null
        ? AuthState.signedOut
        : AuthState.fromUser(session.user);
  }

  bool get available => _client != null;

  Future<AuthResult> signUp(String email, String password) async {
    final c = _client;
    if (c == null) {
      return const AuthResult.failure('Servizi online non disponibili.');
    }
    await _clearPasswordRecoveryState();
    try {
      final res = await c.auth
          .signUp(
            email: email,
            password: password,
            emailRedirectTo: CloudConfig.authCallbackUrl,
          )
          .timeout(_netTimeout);
      // Supabase anti-enumeration: existing emails often return a user with
      // empty identities and no session — treat as "already registered".
      final identities = res.user?.identities;
      if (res.user != null &&
          res.session == null &&
          (identities == null || identities.isEmpty)) {
        return const AuthResult.failure(
          'Esiste già un account con questa email. Accedi oppure recupera la password.',
        );
      }
      if (res.session == null && c.auth.currentUser == null) {
        await ref
            .read(keyValueRepoProvider)
            .set(_pendingProfileLinkEmailKey, email.trim().toLowerCase());
        await _hydrateAccountState(null);
        return const AuthResult.emailConfirmation();
      }
      final linked = await linkLocalProfile();
      return linked.ok
          ? const AuthResult.success(
              message: 'Account creato, profilo collegato.',
            )
          : AuthResult.success(
              message:
                  'Account creato. Collega ora i dati di questo dispositivo.',
              profileLinkRequired: true,
            );
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Registrazione non riuscita. Riprova.');
    }
  }

  /// Persist destination across OAuth / email deep links (`auth-callback`).
  Future<void> stashAuthReturnTo(String? returnTo) async {
    final kv = ref.read(keyValueRepoProvider);
    final value = returnTo?.trim() ?? '';
    if (value.startsWith('/') &&
        !value.startsWith('/auth') &&
        !value.startsWith('//')) {
      await kv.set(_pendingAuthReturnToKey, value);
    } else {
      await kv.remove(_pendingAuthReturnToKey);
    }
  }

  Future<String?> takeAuthReturnTo() async {
    final kv = ref.read(keyValueRepoProvider);
    final value = await kv.get(_pendingAuthReturnToKey);
    await kv.remove(_pendingAuthReturnToKey);
    if (value == null ||
        !value.startsWith('/') ||
        value.startsWith('/auth') ||
        value.startsWith('//')) {
      return null;
    }
    return value;
  }

  Future<void> stashPendingDeepLink(String? location) async {
    final kv = ref.read(keyValueRepoProvider);
    final value = location?.trim() ?? '';
    if (value.startsWith('/') && !value.startsWith('//')) {
      await kv.set(_pendingDeepLinkKey, value);
    }
  }

  Future<String?> takePendingDeepLink() async {
    final kv = ref.read(keyValueRepoProvider);
    final value = await kv.get(_pendingDeepLinkKey);
    await kv.remove(_pendingDeepLinkKey);
    if (value == null || !value.startsWith('/') || value.startsWith('//')) {
      return null;
    }
    return value;
  }

  /// Login/registrazione con Google: OAuth nel browser di sistema, ritorno
  /// via deep link rallymate://auth-callback. La sessione arriva dal
  /// listener onAuthStateChange (che esegue reconcileCurrentSession); qui
  /// si avvia solo il flusso.
  Future<AuthResult> signInWithGoogle({String? returnTo}) async {
    final c = _client;
    if (c == null) {
      return const AuthResult.failure('Servizi online non disponibili.');
    }
    await _clearPasswordRecoveryState();
    await stashAuthReturnTo(returnTo);
    try {
      final launched = await c.auth
          .signInWithOAuth(
            OAuthProvider.google,
            redirectTo: CloudConfig.authCallbackUrl,
            authScreenLaunchMode: LaunchMode.externalApplication,
          )
          .timeout(_netTimeout);
      return launched
          ? const AuthResult.success(
              message: "Completa l'accesso con Google nel browser.",
            )
          : const AuthResult.failure(
              'Impossibile aprire la pagina di accesso Google.',
            );
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Accesso Google non riuscito. Riprova.');
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    final c = _client;
    if (c == null) {
      return const AuthResult.failure('Servizi online non disponibili.');
    }
    await _clearPasswordRecoveryState();
    try {
      final response = await c.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_netTimeout);
      final user = response.user;
      if (user == null) {
        return const AuthResult.failure('Accesso non riuscito. Riprova.');
      }

      final kv = ref.read(keyValueRepoProvider);
      await kv.remove(_pendingProfileLinkEmailKey);
      final linkedId = await kv.get(_linkedCloudUserIdKey);
      final me = await ref.read(playerRepoProvider).me();
      final customized = _isCustomizedLocalProfile(me);

      if (linkedId != null && linkedId.isNotEmpty && linkedId != user.id) {
        await _hydrateAccountState(user);
        return const AuthResult.success(
          message:
              'Accesso effettuato. Conferma a quale account collegare i dati locali.',
          profileLinkRequired: true,
          profileLinkConflict: true,
        );
      }
      if (linkedId == user.id) {
        await syncBasicProfile(allowUnlinked: true);
        await _hydrateAccountState(user);
        return const AuthResult.success();
      }
      if (customized) {
        await _hydrateAccountState(user);
        return const AuthResult.success(
          message:
              'Accesso effettuato. Collega i dati già presenti su questo dispositivo.',
          profileLinkRequired: true,
        );
      }

      final pull = await _pullBasicProfile(force: true);
      if (pull == _RemoteProfilePullResult.unavailable) {
        await _hydrateAccountState(user);
        return const AuthResult.success(
          message:
              'Accesso effettuato. Il profilo cloud sarà recuperato appena torna la connessione.',
          profileLinkRequired: true,
        );
      }
      if (pull == _RemoteProfilePullResult.absent) {
        final error = await syncBasicProfile(allowUnlinked: true);
        if (error != null) {
          await _hydrateAccountState(user);
          return AuthResult.success(
            message: 'Accesso effettuato. $error',
            profileLinkRequired: true,
          );
        }
      }
      await _markCurrentProfileLinked(user.id);
      await _syncServerPlanMirror(c, user.id);
      await PurchasesService.logIn(user.id);
      await _hydrateAccountState(user);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Accesso non riuscito. Riprova.');
    }
  }

  /// Logout completo: chiude la sessione, scollega RevenueCat e riallinea il
  /// piano locale allo store (o Free). I dati locali restano sul device.
  Future<void> signOut() async {
    final c = _client;
    if (c == null) return;
    try {
      await deactivatePushInstallation(ref, c).timeout(_netTimeout);
    } catch (_) {
      // Account logout must remain available offline. Native unregistration
      // below invalidates the routing token even if this RPC could not reach
      // Supabase.
    }
    await ref.read(notificationServiceProvider).unregisterRemote();
    try {
      await c.auth.signOut().timeout(_netTimeout);
    } catch (_) {
      // Rete assente: chiudi comunque la sessione locale.
      try {
        await c.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
    try {
      await PurchasesService.logOut();
    } catch (_) {
      // Il logout locale deve completarsi anche se il billing SDK è guasto.
    }
    final kv = ref.read(keyValueRepoProvider);
    // Una sessione disconnessa non deve conservare un entitlement ottenuto da
    // CustomerInfo dell'account precedente o dal nuovo utente anonimo.
    await kv.set('plan', Plan.free.name);
    await kv.set('account_role', '');
    await kv.set('premium_override', 'false');
    await _clearPasswordRecoveryState();
    await _hydrateAccountState(null);
  }

  /// Eliminazione DEFINITIVA di account e dati cloud (requisito Google Play
  /// "Account deletion" e Apple 5.1.1(v)). La edge function verifica il JWT
  /// e cancella auth.users → cascata su tutte le tabelle. I dati locali
  /// restano sul dispositivo.
  Future<String?> deleteAccount() async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    if (c.auth.currentUser == null) return 'Accedi prima al tuo account';
    try {
      final res = await _invokeAuthenticatedFunction(
        c,
        'delete-account',
        body: const {},
      );
      final ok = (res.data as Map?)?['deleted'] == true;
      if (!ok) return 'Eliminazione non riuscita. Riprova o scrivici.';
    } on TimeoutException {
      return _timeoutMessage;
    } on FunctionException {
      return 'Eliminazione non riuscita. Riprova o scrivici.';
    } catch (_) {
      return 'Eliminazione non riuscita. Riprova o scrivici.';
    }
    // Account sparito sul server: remove the native APNs/FCM registration as
    // well. The database row has already been removed by the auth cascade.
    try {
      await ref.read(notificationServiceProvider).unregisterRemote();
    } catch (_) {
      // Account deletion is already final. Auto-registration remains disabled
      // and a later sign-in will create a fresh routing identifier.
    }

    // Pulizia locale della sessione e del piano.
    try {
      await c.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    try {
      await PurchasesService.logOut();
    } catch (_) {
      // L'account remoto è già eliminato: completa sempre la pulizia locale.
    }
    final kv = ref.read(keyValueRepoProvider);
    await kv.set('plan', Plan.free.name);
    await kv.set('account_role', '');
    await kv.set('premium_override', 'false');
    await kv.remove(_linkedCloudUserIdKey);
    await kv.remove(_pendingProfileLinkEmailKey);
    await kv.remove(_passwordRecoveryKey);
    _passwordRecoveryActive = false;
    state = AuthState.signedOut;
    return null;
  }

  Future<AuthResult> resetPassword(String email) async {
    final c = _client;
    if (c == null) {
      return const AuthResult.failure('Servizi online non disponibili.');
    }
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return const AuthResult.failure('Inserisci una email valida.');
    }
    try {
      // Built-in Supabase Auth mailer (or project SMTP) delivers recovery
      // messages. redirectTo must be allow-listed in Auth URL configuration.
      await c.auth
          .resetPasswordForEmail(
            normalized,
            redirectTo: CloudConfig.authCallbackUrl,
          )
          .timeout(_netTimeout);
      return const AuthResult.success(
        message:
            'Se l’email è registrata riceverai un messaggio di recupero. '
            'Apri il link dall’email per impostare una nuova password.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Invio non riuscito. Riprova.');
    }
  }

  /// Changes the login email without ever storing it in the local profile DB.
  /// Supabase Secure Email Change confirms the operation through email.
  Future<AuthResult> updateEmail(String email) async {
    final c = _client;
    final current = c?.auth.currentUser;
    if (c == null || current == null) {
      return const AuthResult.failure('Accedi prima al tuo account');
    }
    if (current.email?.toLowerCase() == email.toLowerCase()) {
      return const AuthResult.failure(
        'Questa email è già associata all’account.',
      );
    }
    try {
      await c.auth
          .updateUser(
            UserAttributes(email: email),
            emailRedirectTo: CloudConfig.authCallbackUrl,
          )
          .timeout(_netTimeout);
      return const AuthResult.success(
        message:
            'Richiesta inviata. Conferma il cambio dai messaggi ricevuti via email.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Cambio email non riuscito. Riprova.');
    }
  }

  Future<AuthResult> updateRecoveredPassword(String password) async {
    final c = _client;
    if (c == null || c.auth.currentUser == null) {
      return const AuthResult.failure(
        'Sessione scaduta. Richiedi un nuovo link.',
      );
    }
    try {
      await c.auth
          .updateUser(UserAttributes(password: password))
          .timeout(_netTimeout);
      await _clearPasswordRecoveryState();
      await _hydrateAccountState(c.auth.currentUser);
      return const AuthResult.success(
        message: 'Password aggiornata. Il tuo account è di nuovo protetto.',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(translateAuthError(error));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Aggiornamento non riuscito. Riprova.');
    }
  }

  /// Rinvia la email di conferma dopo un signUp non ancora confermato.
  Future<AuthResult> resendConfirmation(String email) async {
    final c = _client;
    if (c == null) {
      return const AuthResult.failure('Servizi online non disponibili.');
    }
    try {
      await c.auth
          .resend(type: OtpType.signup, email: email)
          .timeout(_netTimeout);
      return const AuthResult.success(
        message: 'Email di conferma inviata di nuovo.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(translateAuthError(e));
    } on TimeoutException {
      return const AuthResult.failure(_timeoutMessage);
    } catch (_) {
      return const AuthResult.failure('Invio non riuscito. Riprova.');
    }
  }

  /// Sync silenziosa: usata dopo modifiche al profilo locale (onboarding,
  /// privacy). No-op se l'utente non è loggato; non solleva mai eccezioni.
  Future<void> maybeSyncBasicProfile() async {
    if (!state.profileLinked) return;
    try {
      await syncBasicProfile();
    } catch (_) {
      // Best-effort: il prossimo sync esplicito riallinea.
    }
  }

  /// Free account continuity: syncs only generic profile data.
  ///
  /// This intentionally does not upload match logs, events, training logs or
  /// full local snapshots. Complete backup remains gated by Plus/Pro RLS.
  Future<String?> syncBasicProfile({bool allowUnlinked = false}) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null) return 'Servizi online non disponibili.';
    if (uid == null) return 'Accedi prima al tuo account';
    final linkedId = await ref
        .read(keyValueRepoProvider)
        .get(_linkedCloudUserIdKey);
    if (!allowUnlinked && linkedId != uid) {
      return 'Collega prima il profilo di questo dispositivo.';
    }
    final me = await ref.read(playerRepoProvider).me();
    String? upsertError;
    try {
      await c
          .from('profiles')
          .upsert({
            'user_id': uid,
            'name': me?.name ?? '',
            'nickname': me?.nickname ?? '',
            'dominant_hand': me?.dominantHand ?? 'RIGHT',
            'preferred_role': me?.preferredRole ?? 'UNDEFINED',
            'level': me?.level ?? 'INTERMEDIATE',
            'privacy': me?.privacy ?? 'PRIVATE',
            'last_basic_sync_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(_netTimeout);
      await ref
          .read(keyValueRepoProvider)
          .set('last_basic_profile_sync', DateTime.now().toIso8601String());
      await _syncServerPlanMirror(c, uid);
    } on PostgrestException catch (e) {
      upsertError = e.message;
    } on AuthException catch (e) {
      upsertError = translateAuthError(e);
    } on TimeoutException {
      upsertError = _timeoutMessage;
    } catch (_) {
      upsertError = 'Sync profilo non riuscita';
    }
    // RevenueCat logIn is independent of profile upsert: the billing identity
    // must be aligned even when the profile write fails (network blip, RLS, etc.)
    // so the webhook can associate future plan events to this user.
    try {
      await PurchasesService.logIn(uid);
    } catch (_) {
      // Best-effort: billing identity will be retried on next reconciliation.
    }
    if (upsertError == null && allowUnlinked) {
      await _markCurrentProfileLinked(uid);
    }
    return upsertError;
  }

  /// Ripristino del profilo base da cloud (continuità free su nuovo device).
  ///
  /// Il profilo remoto vince SOLO se quello locale è ancora il default di
  /// bootstrap: un profilo locale personalizzato non viene mai sovrascritto
  /// (verrà pushato subito dopo da [syncBasicProfile]).
  Future<_RemoteProfilePullResult> _pullBasicProfile({
    bool force = false,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return _RemoteProfilePullResult.unavailable;
    try {
      final row = await c
          .from('profiles')
          .select(
            'name, nickname, dominant_hand, preferred_role, level, privacy',
          )
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(_netTimeout);
      final remoteName = (row?['name'] as String?)?.trim() ?? '';
      if (row == null || remoteName.isEmpty) {
        return _RemoteProfilePullResult.absent;
      }

      final players = ref.read(playerRepoProvider);
      final me = await players.me();
      final localCustomized =
          me != null &&
          ((me.name.trim().isNotEmpty && me.name != 'Giocatore') ||
              me.nickname.trim().isNotEmpty);
      if (localCustomized && !force) return _RemoteProfilePullResult.skipped;

      await players.saveMe(
        name: remoteName,
        nickname: (row['nickname'] as String?) ?? '',
        hand: DominantHand.fromWire((row['dominant_hand'] as String?) ?? ''),
        role: PadelRole.fromWire((row['preferred_role'] as String?) ?? ''),
        level: PlayerLevel.fromWire((row['level'] as String?) ?? ''),
        goal: me?.goal ?? '',
        bio: me?.bio ?? '',
        homeArea: me?.homeArea ?? '',
        clubs: me?.clubs ?? '',
        preferredSide: me?.preferredSide ?? 'UNDEFINED',
        preferredTime: me?.preferredTime ?? '',
      );
      await players.updatePrivacy((row['privacy'] as String?) ?? 'PRIVATE');
      // Profilo ripristinato: l'onboarding non serve più.
      await ref.read(keyValueRepoProvider).set('onboarding_done', 'true');
      ref.invalidate(meProvider);
      return _RemoteProfilePullResult.restored;
    } catch (_) {
      return _RemoteProfilePullResult.unavailable;
    }
  }

  /// One-time cleanup for account flags written by pre-cloud builds. Local
  /// matches, teams and preferences are intentionally preserved.
  Future<void> migrateLegacyAccountState() async {
    final kv = ref.read(keyValueRepoProvider);
    if (await kv.get(_accountStateSchemaKey) == _accountStateSchemaVersion) {
      return;
    }
    for (final key in const {
      'is_logged_in',
      'auth_user_id',
      'cloud_user_id',
      'user_email',
      'supabase_user_id',
    }) {
      await kv.remove(key);
    }
    if (_client?.auth.currentSession == null) {
      await kv.set('account_role', '');
      await kv.set('premium_override', 'false');
    }
    await kv.set(_accountStateSchemaKey, _accountStateSchemaVersion);
  }

  /// Restores a cached session, refreshes it when necessary and reconciles it
  /// with the local profile without ever uploading to an unrelated account.
  ///
  /// Re-arm: if a concurrent auth event arrives while reconciliation is
  /// already running, the dirty flag ensures we run again after completion
  /// so no event is silently dropped.
  Future<void> reconcileCurrentSession() async {
    if (_reconciliationRunning) {
      _reconciliationDirty = true;
      return;
    }
    final c = _client;
    if (c == null) return;
    _reconciliationRunning = true;
    try {
      await _reconcileInner(c);
    } finally {
      _reconciliationRunning = false;
      if (_reconciliationDirty) {
        _reconciliationDirty = false;
        unawaited(reconcileCurrentSession());
      }
    }
  }

  Future<void> _reconcileInner(SupabaseClient c) async {
    await migrateLegacyAccountState();
    var session = c.auth.currentSession;
    if (session == null) {
      await _hydrateAccountState(null);
      return;
    }
    if (session.isExpired) {
      final cachedUser = session.user;
      try {
        session = (await c.auth.refreshSession().timeout(
          _netTimeout,
        )).session;
      } on AuthException {
        await c.auth.signOut(scope: SignOutScope.local);
        await _clearAccountRuntimeState();
        await _hydrateAccountState(null, sessionExpired: true);
        return;
      } on TimeoutException {
        await _hydrateAccountState(cachedUser);
        return;
      } catch (_) {
        // Network errors do not invalidate a locally cached session. The
        // user can keep using Padelandia offline and retry later.
        await _hydrateAccountState(cachedUser);
        return;
      }
    }
    final user = session?.user ?? c.auth.currentUser;
    if (user == null) {
      await _hydrateAccountState(null);
      return;
    }

    final kv = ref.read(keyValueRepoProvider);
    final pendingEmail = await kv.get(_pendingProfileLinkEmailKey);
    if (pendingEmail?.toLowerCase() == user.email?.toLowerCase()) {
      await linkLocalProfile();
      return;
    }

    final linkedId = await kv.get(_linkedCloudUserIdKey);
    if (linkedId == user.id) {
      await syncBasicProfile(allowUnlinked: true);
      await _hydrateAccountState(user);
      return;
    }
    if (linkedId != null && linkedId.isNotEmpty) {
      await _hydrateAccountState(user);
      return;
    }

    final me = await ref.read(playerRepoProvider).me();
    if (_isCustomizedLocalProfile(me)) {
      await _hydrateAccountState(user);
      return;
    }
    final pull = await _pullBasicProfile(force: true);
    if (pull == _RemoteProfilePullResult.restored) {
      await _markCurrentProfileLinked(user.id);
      await _syncServerPlanMirror(c, user.id);
      await PurchasesService.logIn(user.id);
    } else if (pull == _RemoteProfilePullResult.absent) {
      await syncBasicProfile(allowUnlinked: true);
    }
    await _hydrateAccountState(user);
  }

  /// Explicit, non-destructive ownership decision. Free accounts upload only
  /// generic profile fields; Premium accounts also enqueue their full backup.
  Future<AuthResult> linkLocalProfile() async {
    final c = _client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) {
      return const AuthResult.failure('Accedi prima al tuo account.');
    }
    final me = await ref.read(playerRepoProvider).me();
    String? error;
    if (_isCustomizedLocalProfile(me)) {
      error = await syncBasicProfile(allowUnlinked: true);
    } else {
      final pull = await _pullBasicProfile(force: true);
      if (pull == _RemoteProfilePullResult.unavailable) {
        return const AuthResult.failure(
          'Connessione non disponibile. I dati locali sono al sicuro: riprova più tardi.',
        );
      }
      if (pull == _RemoteProfilePullResult.absent) {
        error = await syncBasicProfile(allowUnlinked: true);
      }
    }
    if (error != null) return AuthResult.failure(error);

    await _markCurrentProfileLinked(user.id);
    final kv = ref.read(keyValueRepoProvider);
    await kv.remove(_pendingProfileLinkEmailKey);
    await _syncServerPlanMirror(c, user.id);
    await PurchasesService.logIn(user.id);
    await _hydrateAccountState(user);

    if (ref.read(entitlementsProvider).cloudBackup) {
      unawaited(BackupService(ref).backupNow());
    }
    return const AuthResult.success(
      message: 'Profilo collegato senza perdere i dati del dispositivo.',
    );
  }

  Future<void> _markCurrentProfileLinked(String userId) async {
    await ref.read(keyValueRepoProvider).set(_linkedCloudUserIdKey, userId);
  }

  Future<void> _hydrateAccountState(
    User? user, {
    bool sessionExpired = false,
  }) async {
    final kv = ref.read(keyValueRepoProvider);
    final me = await ref.read(playerRepoProvider).me();
    final linkedId = await kv.get(_linkedCloudUserIdKey);
    final pendingEmail = await kv.get(_pendingProfileLinkEmailKey);
    if (await kv.get(_passwordRecoveryKey) == 'true') {
      _passwordRecoveryActive = true;
    }
    bool? cloudProfileExists;
    if (user != null && linkedId == user.id) {
      cloudProfileExists = await _cloudProfileExists(user.id);
    }
    state = user == null
        ? AuthState(
            email: pendingEmail?.isEmpty == false ? pendingEmail : null,
            profileLinkStatus: resolveProfileLinkStatus(
              signedIn: false,
              hasCustomizedLocalProfile: _isCustomizedLocalProfile(me),
              linkedCloudUserId: linkedId,
              pendingEmail: pendingEmail,
            ),
            sessionExpired: sessionExpired,
          )
        : AuthState.fromUser(
            user,
            profileLinkStatus: resolveProfileLinkStatus(
              signedIn: true,
              signedInUserId: user.id,
              hasCustomizedLocalProfile: _isCustomizedLocalProfile(me),
              linkedCloudUserId: linkedId,
              pendingEmail: pendingEmail,
              cloudProfileExists: cloudProfileExists,
            ),
            passwordRecovery: _passwordRecoveryActive,
          );
  }

  Future<bool?> _cloudProfileExists(String userId) async {
    try {
      final row = await _client!
          .from('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_netTimeout);
      return row != null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearAccountRuntimeState() async {
    await PurchasesService.logOut();
    final kv = ref.read(keyValueRepoProvider);
    await kv.set('plan', Plan.free.name);
    await kv.set('account_role', '');
    await kv.set('premium_override', 'false');
    await _clearPasswordRecoveryState();
  }

  Future<void> _clearPasswordRecoveryState() async {
    _passwordRecoveryActive = false;
    await ref.read(keyValueRepoProvider).remove(_passwordRecoveryKey);
  }

  /// Re-pull server plan/override into the local KV (public for resume reconcile).
  Future<void> refreshServerPlanMirror() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    await _syncServerPlanMirror(c, uid);
  }

  Future<void> _syncServerPlanMirror(SupabaseClient c, String uid) async {
    try {
      final row = await c
          .from('profiles')
          .select('plan, account_role, premium_override, plan_expires_at')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(_netTimeout);
      final role = row?['account_role'] as String?;
      final serverPlan = row?['plan'] as String?;
      final isAdmin = role == 'admin' || role == 'super_admin';
      // Fail closed on expiry: past plan_expires_at means free unless override/admin.
      final expiresRaw = row?['plan_expires_at']?.toString();
      final expiresAt = expiresRaw == null || expiresRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresRaw);
      final expired = expiresAt != null && !expiresAt.isAfter(DateTime.now());
      final localPlan = isAdmin
          ? Plan.coach.name
          : expired
          ? Plan.free.name
          : Plan.fromName(serverPlan).name;
      // Tester/admin: sblocco premium senza acquisto (Duo Mode §11). Il flag
      // resta separato dal piano così i log distinguono i test user.
      final override = isAdmin || row?['premium_override'] == true;
      await ref.read(keyValueRepoProvider).set('plan', localPlan);
      await ref
          .read(keyValueRepoProvider)
          .set('premium_override', override ? 'true' : 'false');
      if (expiresRaw != null) {
        await ref
            .read(keyValueRepoProvider)
            .set('plan_expires_at', expiresRaw);
      } else {
        await ref.read(keyValueRepoProvider).remove('plan_expires_at');
      }
      if (role != null) {
        await ref.read(keyValueRepoProvider).set('account_role', role);
      }
    } catch (_) {
      // Older schemas may not expose role fields yet. Sync base should still
      // succeed; server-side features remain protected by the edge function.
    }
  }
}

enum _RemoteProfilePullResult { restored, absent, skipped, unavailable }

bool _isCustomizedLocalProfile(Player? player) =>
    player != null &&
    ((player.name.trim().isNotEmpty && player.name != 'Giocatore') ||
        player.nickname.trim().isNotEmpty ||
        player.bio.trim().isNotEmpty ||
        player.homeArea.trim().isNotEmpty ||
        player.clubs.trim().isNotEmpty);

/// Messaggi auth in italiano per i codici GoTrue più comuni.
String translateAuthError(AuthException e) {
  final code = (e.code ?? '').toLowerCase();
  final message = e.message.toLowerCase();
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      message.contains('already registered') ||
      message.contains('user already registered') ||
      message.contains('already been registered')) {
    return 'Esiste già un account con questa email. Accedi oppure recupera la password.';
  }
  return switch (code) {
    'invalid_credentials' => 'Email o password errati.',
    'email_not_confirmed' =>
      'Email non ancora confermata: apri il link che ti abbiamo inviato.',
    'weak_password' => 'Password troppo debole: usa almeno 8 caratteri.',
    'over_request_rate_limit' || 'over_email_send_rate_limit' =>
      'Troppi tentativi: attendi qualche minuto e riprova.',
    'user_not_found' => 'Nessun account trovato con questa email.',
    'same_password' => 'La nuova password deve essere diversa da quella attuale.',
    'validation_failed' => 'Controlla email e password inserite.',
    'refresh_token_not_found' ||
    'refresh_token_already_used' ||
    'session_not_found' => 'Sessione scaduta. Accedi nuovamente.',
    _ => 'Operazione non riuscita. Riprova.',
  };
}

final cloudAuthProvider = NotifierProvider<CloudAuth, AuthState>(CloudAuth.new);

// ---------------------------------------------------------------- backup

/// Backup Plus (PRD 8): snapshot jsonb dell'intero DB locale, 1 riga per
/// device. Economico e ripristinabile in un colpo solo.
class BackupService {
  BackupService(this.ref);
  final Ref ref;
  bool _autoBackupRunning = false;

  AppDatabase get _db => ref.read(databaseProvider);

  static const _portablePreferenceKeys = <String>{
    'onboarding_done',
    'social_enabled',
  };

  /// Stable per-install backup slot. Avoids multi-device last-writer-wins on a
  /// shared `primary` row while remaining compatible with legacy restores.
  Future<String> resolveBackupDeviceId([String? preferred]) async {
    if (preferred != null &&
        preferred != 'primary' &&
        _validDeviceId(preferred)) {
      return preferred;
    }
    final kv = ref.read(keyValueRepoProvider);
    final existing = await kv.get('backup_device_id');
    if (existing != null && _validDeviceId(existing)) return existing;
    final generated =
        'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_'
        '${Object.hash(DateTime.now().microsecondsSinceEpoch, hashCode).toUnsigned(32).toRadixString(16)}';
    final id = generated.length > 64 ? generated.substring(0, 64) : generated;
    await kv.set('backup_device_id', id);
    return id;
  }

  Future<String?> backupNow([String? deviceId]) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Accedi prima al tuo account';
    if (!ref.read(entitlementsProvider).cloudBackup) {
      return 'Il backup cloud richiede il piano Plus';
    }
    final resolved = await resolveBackupDeviceId(deviceId);
    if (!_validDeviceId(resolved)) return 'Identificativo backup non valido';

    // Do not snapshot a half-written live match into the cloud slot.
    final active = await ref.read(matchRepoProvider).latestInProgress();
    if (active != null) {
      return 'Chiudi o termina la partita in corso prima del backup.';
    }

    try {
      final payload = await _exportLocalDb();
      await c
          .from('backups')
          .upsert({
            'user_id': uid,
            'device_id': resolved,
            'payload': payload,
            'schema_ver': BackupPayloadCodec.currentVersion,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(_netTimeout);
      // One-shot legacy migration: write `primary` only if it does not exist
      // yet, so multi-device backups no longer last-writer-wins that slot.
      if (resolved != 'primary') {
        try {
          final existing = await c
              .from('backups')
              .select('device_id')
              .eq('user_id', uid)
              .eq('device_id', 'primary')
              .maybeSingle()
              .timeout(_netTimeout);
          if (existing == null) {
            await c
                .from('backups')
                .insert({
                  'user_id': uid,
                  'device_id': 'primary',
                  'payload': payload,
                  'schema_ver': BackupPayloadCodec.currentVersion,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .timeout(_netTimeout);
          }
        } catch (_) {
          // Non-fatal: device slot already stored above.
        }
      }
      await ref
          .read(keyValueRepoProvider)
          .set('last_full_backup_at', DateTime.now().toUtc().toIso8601String());
      await ref.read(keyValueRepoProvider).remove('backup_paused_by_user');
      return null;
    } on PostgrestException catch (e) {
      // 42501 = RLS: piano non Plus / entitlement non ancora sul server.
      return e.code == '42501'
          ? 'Il backup cloud richiede il piano Plus attivo sul server. '
                'Attendi qualche istante dopo l’acquisto e riprova.'
          : e.message;
    } on TimeoutException {
      return _timeoutMessage;
    } on FormatException catch (error) {
      return 'Backup non valido: ${error.message}';
    } catch (_) {
      return 'Backup non riuscito. Riprova.';
    }
  }

  /// Low-cost automatic safety net. It runs only for an authenticated Premium
  /// account and never more often than [minimumInterval]. Manual backups remain
  /// available from the account screen.
  Future<void> backupIfDue([
    String? deviceId,
    Duration minimumInterval = const Duration(minutes: 15),
  ]) async {
    if (_autoBackupRunning || _client?.auth.currentUser == null) return;
    if (!ref.read(entitlementsProvider).cloudBackup) return;
    final paused = await ref.read(keyValueRepoProvider).get('backup_paused_by_user');
    if (paused == 'true') return;

    final value = await ref
        .read(keyValueRepoProvider)
        .get('last_full_backup_at');
    final last = DateTime.tryParse(value ?? '');
    if (last != null &&
        DateTime.now().toUtc().difference(last) < minimumInterval) {
      return;
    }

    _autoBackupRunning = true;
    try {
      await backupNow(deviceId);
    } finally {
      _autoBackupRunning = false;
    }
  }

  Future<String?> restore([String? deviceId]) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Accedi prima al tuo account';
    if (!ref.read(entitlementsProvider).cloudBackup) {
      return 'Il ripristino cloud richiede il piano Plus';
    }
    final resolved = await resolveBackupDeviceId(deviceId);
    final candidates = <String>{
      if (deviceId != null && _validDeviceId(deviceId)) deviceId,
      resolved,
      'primary',
    }.toList(growable: false);
    final active = await ref.read(matchRepoProvider).latestInProgress();
    if (active != null) {
      return 'Termina o sospendi e chiudi la partita in corso prima del ripristino.';
    }
    try {
      Map<String, dynamic>? row;
      for (final id in candidates) {
        row = await c
            .from('backups')
            .select('payload, schema_ver')
            .eq('user_id', uid)
            .eq('device_id', id)
            .maybeSingle()
            .timeout(_netTimeout);
        if (row != null) break;
      }
      if (row == null) return 'Nessun backup trovato per questo dispositivo';
      final rawPayload = row['payload'];
      if (rawPayload is! Map) throw const FormatException('Payload assente');
      final payload = rawPayload.cast<String, Object?>();
      final schemaVersion = row['schema_ver'] as int? ?? 0;
      if (schemaVersion > BackupPayloadCodec.currentVersion) {
        return 'Backup creato da una versione più recente dell’app: '
            'aggiorna Padelandia per ripristinarlo.';
      }
      await _importLocalDb(BackupPayloadCodec.decode(payload));
      // Force live/history rebuild after external DB mutation.
      ref.invalidate(recentMatchesProvider);
      ref.invalidate(summariesProvider);
      ref.invalidate(meProvider);
      ref.invalidate(teamsProvider);
      return null;
    } on PostgrestException catch (e) {
      return e.code == '42501'
          ? 'Il ripristino cloud richiede il piano Plus'
          : e.message;
    } on TimeoutException {
      return _timeoutMessage;
    } on FormatException catch (error) {
      return 'Ripristino non riuscito: ${error.message}';
    } catch (_) {
      return 'Ripristino non riuscito: backup danneggiato o rete assente.';
    }
  }

  /// Privacy control available even after a downgrade. Deletes the install
  /// slot and the legacy `primary` mirror so UI "elimina backup" is complete.
  Future<String?> deleteBackup(String deviceId) async {
    final c = _client;
    if (c?.auth.currentUser == null) return 'Accedi prima al tuo account';
    if (!_validDeviceId(deviceId)) return 'Identificativo backup non valido';
    try {
      await c!
          .rpc('delete_my_backup', params: {'p_device_id': deviceId})
          .timeout(_netTimeout);
      if (deviceId != 'primary') {
        try {
          await c
              .rpc('delete_my_backup', params: {'p_device_id': 'primary'})
              .timeout(_netTimeout);
        } catch (_) {
          // Primary may already be absent.
        }
      }
      await ref.read(keyValueRepoProvider).set('last_full_backup_at', '');
      // Pause auto-backup until the user runs a manual backup again.
      await ref.read(keyValueRepoProvider).set('backup_paused_by_user', 'true');
      return null;
    } on TimeoutException {
      return _timeoutMessage;
    } on PostgrestException catch (error) {
      return error.message;
    } catch (_) {
      return 'Eliminazione backup non riuscita. Riprova.';
    }
  }

  Future<Map<String, Object?>> _exportLocalDb() async {
    // Wrap all reads in a single transaction to prevent a torn snapshot when
    // concurrent writes land between individual SELECT statements.
    return _db.transaction(() async {
      final players = await _db.select(_db.players).get();
      final teams = await _db.select(_db.teams).get();
      final matches = await _db.select(_db.matches).get();
      final events = await (_db.select(
        _db.matchEventRows,
      )..orderBy([(e) => OrderingTerm.asc(e.seq)])).get();
      final logs = await _db.select(_db.trainingLogs).get();
      final preferences = await (_db.select(
        _db.keyValues,
      )..where((row) => row.key.isIn(_portablePreferenceKeys))).get();

      return BackupPayloadCodec.encode(
        players: players.map((row) => row.toJson()).toList(growable: false),
        teams: teams
            .map((row) {
              final json = row.toJson();
              // A sandbox path from one device is never valid on another device.
              json['imageLocalPath'] = null;
              return json;
            })
            .toList(growable: false),
        matches: matches.map((row) => row.toJson()).toList(growable: false),
        events: events
            .map((row) {
              final json = row.toJson();
              // Restored events must not be replayed to a newly paired watch.
              json['synced'] = true;
              return json;
            })
            .toList(growable: false),
        trainingLogs: logs.map((row) => row.toJson()).toList(growable: false),
        preferences: {for (final row in preferences) row.key: row.value},
      );
    });
  }

  Future<void> _importLocalDb(BackupData data) async {
    final localMe =
        await (_db.select(_db.players)
              ..where((player) => player.isMe.equals(true))
              ..limit(1))
            .getSingleOrNull();
    final portable = reconcileBackupIdentity(data, localMeId: localMe?.id);
    String? restoredMeId;
    for (final row in portable.players) {
      if (row['isMe'] == true) {
        restoredMeId = row['id'] as String?;
        break;
      }
    }
    await _db.transaction(() async {
      if (restoredMeId != null) {
        await _db
            .update(_db.players)
            .write(const PlayersCompanion(isMe: Value(false)));
      }
      for (final row in portable.players) {
        await _db
            .into(_db.players)
            .insertOnConflictUpdate(Player.fromJson(_playerDefaults(row)));
      }
      for (final row in portable.teams) {
        await _db
            .into(_db.teams)
            .insertOnConflictUpdate(Team.fromJson(_teamDefaults(row)));
      }
      for (final row in portable.matches) {
        await _db
            .into(_db.matches)
            .insertOnConflictUpdate(MatchRow.fromJson(_matchDefaults(row)));
      }
      for (final row in portable.events) {
        await _db
            .into(_db.matchEventRows)
            .insertOnConflictUpdate(
              MatchEventRow.fromJson(_eventDefaults(row)),
            );
      }
      for (final row in portable.trainingLogs) {
        await _db
            .into(_db.trainingLogs)
            .insertOnConflictUpdate(
              TrainingLog.fromJson(_trainingLogDefaults(row)),
            );
      }
      for (final entry in portable.preferences.entries) {
        if (_portablePreferenceKeys.contains(entry.key)) {
          await _db
              .into(_db.keyValues)
              .insertOnConflictUpdate(
                KeyValuesCompanion.insert(key: entry.key, value: entry.value),
              );
        }
      }
    });
    ref.invalidate(meProvider);
    ref.invalidate(recentMatchesProvider);
    ref.invalidate(summariesProvider);
    ref.invalidate(teamsProvider);
    ref.invalidate(trainingLogsProvider);
    ref.invalidate(onboardingDoneProvider);
  }

  static bool _validDeviceId(String value) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(value);

  static Map<String, Object?> _playerDefaults(Map<String, Object?> row) {
    final result = <String, Object?>{
      'nickname': '',
      'isMe': false,
      'dominantHand': 'RIGHT',
      'preferredRole': 'UNDEFINED',
      'level': 'INTERMEDIATE',
      'goal': '',
      'clubs': '',
      'bio': '',
      'homeArea': '',
      'preferredSide': 'UNDEFINED',
      'preferredTime': '',
      'playFrequency': '',
      'privacy': 'PRIVATE',
      'availability': 'FLEX',
      'styleTags': '',
      'createdAtMs': 0,
      ...row,
    };
    // A path from another app sandbox is invalid and may disclose device-local
    // directory structure. Cloud object paths remain portable.
    result['avatarLocalPath'] = null;
    return result;
  }

  static Map<String, Object?> _teamDefaults(Map<String, Object?> row) {
    final result = <String, Object?>{
      'playerBId': null,
      'playerBName': '',
      'roleA': 'UNDEFINED',
      'roleB': 'UNDEFINED',
      'tacticalNotes': '',
      'goals': '',
      'imageLocalPath': null,
      'imageCloudPath': null,
      'imageVersion': 0,
      'imageCloudVersion': 0,
      'scoringStyle': 'AUTO',
      'colorArgb': 0xFFC8F135,
      'cloudId': null,
      'cloudRole': 'LOCAL',
      'archived': false,
      'createdAtMs': 0,
      ...row,
    };
    // Never trust a path originating from another device or legacy backup.
    result['imageLocalPath'] = null;
    return result;
  }

  static Map<String, Object?> _matchDefaults(Map<String, Object?> row) =>
      <String, Object?>{
        'teamId': null,
        'status': 'CREATED',
        'startTimeMs': null,
        'endTimeMs': null,
        'wonByUs': null,
        'myRole': 'UNDEFINED',
        'opponentLabel': '',
        'opponentTags': '',
        'opponentDifficulty': 3,
        'location': '',
        'notes': '',
        'summaryJson': null,
        'duoMode': false,
        'duoTeam': null,
        'duoSessionId': null,
        'duoJoinCode': null,
        ...row,
      };

  static Map<String, Object?> _eventDefaults(Map<String, Object?> row) {
    final result = <String, Object?>{
      'teamId': null,
      'scoreBefore': null,
      'scoreAfter': null,
      'sourceDevice': 'PHONE',
      'sourceMethod': 'TAP',
      'synced': true,
      'payloadJson': null,
      'sourceUserId': null,
      'sourceTeamId': null,
      'duoMode': false,
      'createdLocallyAtMs': null,
      'cloudSynced': false,
      ...row,
    };
    result['synced'] = true;
    return result;
  }

  static Map<String, Object?> _trainingLogDefaults(Map<String, Object?> row) =>
      <String, Object?>{
        'completed': false,
        'notes': '',
        'rpe': 0,
        'minutes': 0,
        ...row,
      };
}

final backupServiceProvider = Provider((ref) => BackupService(ref));

// ------------------------------------------------------------ wrapped link

class WrappedLinkService {
  /// Crea il link pubblico del recap (PRD G5). Ritorna l'URL o un errore.
  static Future<({String? url, String? error})> publish({
    required String type,
    required Map<String, Object?> payload,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null) {
      return (url: null, error: 'Servizi online non disponibili.');
    }
    if (uid == null) return (url: null, error: 'Accedi prima al tuo account');

    // Retry su collisione slug (23505): con slug casuali è rarissimo, ma
    // costa nulla gestirlo.
    for (var attempt = 0; attempt < 3; attempt++) {
      final slug = _slug();
      try {
        await c
            .from('wrapped_cards')
            .insert({
              'user_id': uid,
              'slug': slug,
              'type': type,
              'payload': payload,
              'privacy': 'PUBLIC',
            })
            .timeout(_netTimeout);
        return (url: CloudConfig.recapUrl(slug), error: null);
      } on PostgrestException catch (e) {
        if (e.code == '23505') continue;
        return (url: null, error: e.message);
      } on TimeoutException {
        return (url: null, error: _timeoutMessage);
      } catch (_) {
        return (url: null, error: 'Pubblicazione non riuscita. Riprova.');
      }
    }
    return (url: null, error: 'Pubblicazione non riuscita. Riprova.');
  }

  /// Slug pubblico non indovinabile (Random.secure, 36^10 combinazioni).
  static String _slug() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

// --------------------------------------------------------------- assistant

class AssistantAnswer {
  const AssistantAnswer({
    required this.answer,
    required this.sources,
    required this.cached,
    required this.remainingToday,
  });
  final String answer;
  final List<Map<String, dynamic>> sources;
  final bool cached;
  final int remainingToday;
}

class AssistantHealth {
  const AssistantHealth({
    required this.reachable,
    required this.authenticated,
    required this.profileReady,
    required this.entitled,
    required this.assistantEnabled,
    required this.providerConfigured,
    required this.modelConfigured,
    this.error,
  });

  final bool reachable;
  final bool authenticated;
  final bool profileReady;
  final bool entitled;
  final bool assistantEnabled;
  final bool providerConfigured;
  final bool modelConfigured;
  final String? error;
}

class ChatTurn {
  const ChatTurn({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AssistantClient {
  static Future<AssistantHealth> health() async {
    final c = _client;
    if (c == null) {
      return const AssistantHealth(
        reachable: false,
        authenticated: false,
        profileReady: false,
        entitled: false,
        assistantEnabled: false,
        providerConfigured: false,
        modelConfigured: false,
        error: 'Servizi online non disponibili in questa build.',
      );
    }
    if (c.auth.currentSession == null) {
      return const AssistantHealth(
        reachable: false,
        authenticated: false,
        profileReady: false,
        entitled: false,
        assistantEnabled: false,
        providerConfigured: false,
        modelConfigured: false,
        error: 'Accedi per eseguire il test.',
      );
    }
    try {
      final response = await _invokeAuthenticatedFunction(
        c,
        'assistant',
        body: const {'action': 'health'},
      );
      final data = (response.data as Map?)?.cast<String, dynamic>() ?? const {};
      return AssistantHealth(
        reachable: data['ok'] == true,
        authenticated: data['authenticated'] == true,
        profileReady: data['profileReady'] == true,
        entitled: data['entitled'] == true,
        assistantEnabled: data['assistantEnabled'] == true,
        providerConfigured: data['providerConfigured'] == true,
        modelConfigured: data['modelConfigured'] == true,
      );
    } on _CloudSessionExpired {
      return const AssistantHealth(
        reachable: true,
        authenticated: false,
        profileReady: false,
        entitled: false,
        assistantEnabled: false,
        providerConfigured: false,
        modelConfigured: false,
        error: 'Sessione scaduta. Accedi nuovamente.',
      );
    } catch (_) {
      return const AssistantHealth(
        reachable: false,
        authenticated: true,
        profileReady: false,
        entitled: false,
        assistantEnabled: false,
        providerConfigured: false,
        modelConfigured: false,
        error: 'Servizio temporaneamente non disponibile.',
      );
    }
  }

  /// Pallino Assistant (PRD E4) via edge function con limiti/cache.
  /// [history] rende il chatbot conversazionale (multi-turno).
  static Future<({AssistantAnswer? answer, String? error})> ask({
    required String question,
    String mode = 'RULES',
    String? matchId,
    String? matchContext,
    String? clientContext,
    String surface = 'mobile',
    List<ChatTurn> history = const [],
  }) async {
    final c = _client;
    if (c == null) {
      return (answer: null, error: 'Servizio temporaneamente non disponibile');
    }
    if (c.auth.currentUser == null) {
      return (answer: null, error: 'Accedi per utilizzare Pallino Assistant');
    }
    try {
      final res = await _invokeAuthenticatedFunction(
        c,
        'assistant',
        body: {
          'question': question,
          'mode': mode,
          'surface': surface,
          'matchId': ?matchId,
          'matchContext': ?matchContext,
          'clientContext': ?clientContext,
          if (history.isNotEmpty)
            'history': history.map((t) => t.toJson()).toList(),
        },
        timeout: const Duration(seconds: 45),
      );
      final data = (res.data as Map).cast<String, dynamic>();
      return (
        answer: AssistantAnswer(
          answer: data['answer'] as String? ?? '',
          sources: (data['sources'] as List? ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList(),
          cached: data['cached'] as bool? ?? false,
          remainingToday: data['remainingToday'] as int? ?? 0,
        ),
        error: null,
      );
    } on FunctionException catch (e) {
      final detail = (e.details is Map)
          ? ((e.details as Map)['error']?.toString() ?? '')
          : '';
      return (
        answer: null,
        error: assistantErrorMessage(detail, status: e.status),
      );
    } on _CloudSessionExpired {
      return (answer: null, error: 'Sessione scaduta. Accedi nuovamente');
    } on TimeoutException {
      return (answer: null, error: 'Risposta troppo lenta, riprova.');
    } catch (_) {
      return (answer: null, error: 'Errore di rete');
    }
  }

  /// Segnalazione in-app di una risposta AI. Serve per moderazione interna e
  /// per rispettare le policy Google sui contenuti generati da AI.
  static Future<String?> report({
    required String question,
    required String answer,
    required String mode,
    required String reason,
    String details = '',
  }) async {
    final c = _client;
    if (c == null) return 'Servizio temporaneamente non disponibile.';
    if (c.auth.currentUser == null) {
      return 'Accedi per utilizzare Pallino Assistant.';
    }
    try {
      await _invokeAuthenticatedFunction(
        c,
        'assistant',
        body: {
          'action': 'report',
          'question': question,
          'answer': answer,
          'mode': mode,
          'reason': reason,
          'details': details,
        },
      );
      return null;
    } on _CloudSessionExpired {
      return 'Sessione scaduta. Accedi nuovamente.';
    } on TimeoutException {
      return _timeoutMessage;
    } on FunctionException {
      return 'Segnalazione non inviata. Riprova.';
    } catch (_) {
      return 'Segnalazione non inviata. Riprova.';
    }
  }
}

String assistantErrorMessage(String detail, {int? status}) => switch (detail) {
  'plan_required' => 'Pallino Assistant è incluso nel piano Pro',
  'assistant_disabled' => 'Pallino Assistant non è attivo per questo account',
  'daily_limit' => 'Hai esaurito le domande disponibili per oggi',
  'live_limit' => 'Limite di domande live per questa partita raggiunto',
  'unauthorized' => 'Sessione scaduta. Accedi nuovamente',
  'no_llm_configured' ||
  'llm_unavailable' => 'Servizio temporaneamente non disponibile',
  _ when status == 401 => 'Sessione scaduta. Accedi nuovamente',
  _ => 'Servizio temporaneamente non disponibile',
};

class _CloudSessionExpired implements Exception {
  const _CloudSessionExpired();
}

Future<FunctionResponse> _invokeAuthenticatedFunction(
  SupabaseClient client,
  String functionName, {
  required Map<String, dynamic> body,
  Duration timeout = _netTimeout,
}) async {
  var session = client.auth.currentSession;
  if (session == null) throw const _CloudSessionExpired();
  if (session.isExpired) {
    try {
      session = (await client.auth.refreshSession().timeout(
        _netTimeout,
      )).session;
    } catch (_) {
      throw const _CloudSessionExpired();
    }
    if (session == null) throw const _CloudSessionExpired();
  }

  try {
    return await client.functions
        .invoke(functionName, body: body)
        .timeout(timeout);
  } on FunctionException catch (error) {
    if (error.status != 401) rethrow;
    try {
      final refreshed = await client.auth.refreshSession().timeout(_netTimeout);
      if (refreshed.session == null) throw const _CloudSessionExpired();
      return await client.functions
          .invoke(functionName, body: body)
          .timeout(timeout);
    } catch (_) {
      throw const _CloudSessionExpired();
    }
  }
}

// ------------------------------------------------------------------ coach

class CoachPackage {
  const CoachPackage({
    required this.packageId,
    required this.coachId,
    required this.title,
    required this.description,
    required this.type,
    required this.priceCents,
    required this.commissionRate,
    required this.status,
  });

  final String packageId;
  final String coachId;
  final String title;
  final String description;
  final String type;
  final int priceCents;
  final double commissionRate;
  final String status;

  double get priceEur => priceCents / 100;
  int get commissionCents => (priceCents * commissionRate).round();

  static CoachPackage fromRow(Map<String, dynamic> r) => CoachPackage(
    packageId: r['package_id'] as String,
    coachId: r['coach_id'] as String,
    title: r['title'] as String,
    description: r['description'] as String? ?? '',
    type: r['type'] as String,
    priceCents: r['price_cents'] as int,
    commissionRate: double.parse(r['commission_rate'].toString()),
    status: r['status'] as String,
  );
}

class CoachService {
  static bool get available => _client != null;
  static String? get currentUserId => _client?.auth.currentUser?.id;

  /// Marketplace: tutti i pacchetti attivi.
  static Future<List<CoachPackage>> marketplace() async {
    final c = _client;
    if (c == null) return const [];
    final rows = await c
        .from('coach_packages')
        .select()
        .eq('status', 'ACTIVE')
        .order('created_at', ascending: false)
        .timeout(_netTimeout);
    return rows.map((r) => CoachPackage.fromRow(r)).toList();
  }

  static Future<List<CoachPackage>> myPackages() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    final rows = await c
        .from('coach_packages')
        .select()
        .eq('coach_id', uid)
        .order('created_at', ascending: false)
        .timeout(_netTimeout);
    return rows.map((r) => CoachPackage.fromRow(r)).toList();
  }

  /// PRD I3: 15% digitali, 10% 1:1. Solo per preview UI: il valore
  /// autorevole lo impone il DB (trigger coach_packages_enforce_commission).
  static double commissionFor(String type) =>
      type == 'LIVE_1TO1' || type == 'GROUP_LESSON' ? 0.10 : 0.15;

  static Future<String?> createPackage({
    required String title,
    required String description,
    required String type,
    required int priceCents,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Accedi prima al tuo account';
    try {
      // Il profilo coach deve esistere (RLS verifica piano coach).
      await c
          .from('coach_profiles')
          .upsert({'coach_id': uid})
          .timeout(_netTimeout);
      await c
          .from('coach_packages')
          .insert({
            'coach_id': uid,
            'title': title,
            'description': description,
            'type': type,
            'price_cents': priceCents,
            'includes_live_session':
                type == 'LIVE_1TO1' || type == 'GROUP_LESSON',
          })
          .timeout(_netTimeout);
      return null;
    } on PostgrestException catch (e) {
      return e.code == '42501'
          ? 'La creazione pacchetti richiede il piano Coach'
          : e.message;
    } on TimeoutException {
      return _timeoutMessage;
    }
  }

  /// Acquisto: in produzione l'IAP store avviene PRIMA e qui si passa il
  /// vero storeTxId; la edge function valida e calcola la commissione.
  static Future<String?> purchase(
    CoachPackage pkg, {
    required String storeTxId,
    required String store,
  }) async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    if (c.auth.currentUser == null) return 'Accedi prima al tuo account';
    try {
      await c.functions
          .invoke(
            'coach-checkout',
            body: {
              'packageId': pkg.packageId,
              'store': store,
              'storeTxId': storeTxId,
            },
          )
          .timeout(_netTimeout);
      return null;
    } on TimeoutException {
      return _timeoutMessage;
    } on FunctionException catch (e) {
      final detail = (e.details is Map)
          ? ((e.details as Map)['error']?.toString() ?? '')
          : '';
      return switch (detail) {
        'cannot_buy_own_package' => 'Non puoi comprare il tuo pacchetto',
        'duplicate_or_failed' => 'Acquisto già registrato',
        _ => 'Acquisto non riuscito (${jsonEncode(e.details)})',
      };
    }
  }
}
