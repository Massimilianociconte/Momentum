import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/providers.dart';
import 'core/navigation_targets.dart';
import 'core/theme.dart';
import 'services/cloud/cloud_config.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/cloud_diagnostics_screen.dart';
import 'features/coach/coach_profile_screen.dart';
import 'features/coach/coach_screen.dart';
import 'features/duo/duo_lobby_screen.dart';
import 'features/devices/devices_screen.dart';
import 'features/devices/health_provider_setup_screen.dart';
import 'features/devices/watch_setup_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live/live_scoring_screen.dart';
import 'features/match_detail/match_detail_screen.dart';
import 'features/match_setup/match_setup_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/privacy/privacy_screen.dart';
import 'features/profile/profile_edit_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rules/pro_chat_screen.dart';
import 'features/rules/rules_assistant_screen.dart';
import 'features/social/social_screen.dart';
import 'features/social/friend_groups_screen.dart';
import 'features/social/friends_screen.dart';
import 'features/social/invite_redeem_screen.dart';
import 'features/social/qr_scanner_screen.dart';
import 'features/splash/startup_splash.dart';
import 'features/teams/team_detail_screen.dart';
import 'features/teams/teams_screen.dart';
import 'features/training/training_screen.dart';
import 'features/wrapped/wrapped_screen.dart';
import 'services/cloud/cloud_service.dart';
import 'services/cloud/duo_service.dart';
import 'services/cloud/purchases_service.dart';
import 'services/cloud/push_registration_service.dart';
import 'services/cloud/social_service.dart';
import 'services/cloud/team_cloud_service.dart';
import 'services/watch_sync.dart';
import 'services/health_connect.dart';
import 'services/profile_image_service.dart';
import 'services/match_health_sync.dart';
import 'services/notifications.dart';
import 'services/team_image_service.dart';
import 'services/wearable_cloud_sync.dart';
import 'services/wearable_match_dispatcher.dart';
import 'services/wearable_provider_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    // Primo avvio → onboarding. Lo stato vive nel KV `onboarding_done`;
    // la StateProvider evita una lettura DB a ogni navigazione.
    redirect: (context, state) async {
      if (state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/paywall' ||
          state.matchedLocation == '/auth' ||
          state.matchedLocation.startsWith('/invite/')) {
        return null;
      }
      var done = ref.read(onboardingDoneProvider);
      if (done == null) {
        final kv = ref.read(keyValueRepoProvider);
        done = await kv.get('onboarding_done') == 'true';
        if (!done) {
          // Retro-compatibilità: profilo già personalizzato = onboarding fatto.
          final me = await ref.read(playerRepoProvider).me();
          if (me != null &&
              (me.name != 'Giocatore' || me.nickname.isNotEmpty)) {
            done = true;
            await kv.set('onboarding_done', 'true');
          }
        }
        ref.read(onboardingDoneProvider.notifier).state = done;
      }
      return done ? null : '/onboarding';
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        redirect: (_, state) =>
            state.uri.queryParameters['edit'] == '1' ? '/profile/edit' : null,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (_, _) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/training',
                builder: (_, _) => const TrainingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, state) => ProfileScreen(
                  focus: ProfileSectionTarget.fromQuery(
                    state.uri.queryParameters['focus'],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/match/new',
        builder: (_, state) => MatchSetupScreen(
          initialDuo: state.uri.queryParameters['duo'] == '1',
          initialOpponentName: state.uri.queryParameters['opponentName'],
          linkedMatchId: state.uri.queryParameters['linkedMatchId'],
          proposalId: state.uri.queryParameters['proposalId'],
        ),
      ),
      GoRoute(
        path: '/match/:id/duo',
        builder: (_, state) =>
            DuoLobbyScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/live',
        builder: (_, state) => LiveScoringScreen(
          matchId: state.pathParameters['id']!,
          resumeOnOpen: state.uri.queryParameters['resume'] == '1',
        ),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (_, state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/wrapped',
        builder: (_, state) =>
            WrappedScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/teams', builder: (_, _) => const TeamsScreen()),
      GoRoute(path: '/devices', builder: (_, _) => const DevicesScreen()),
      GoRoute(
        path: '/devices/setup',
        builder: (_, _) => const WatchSetupScreen(),
      ),
      GoRoute(
        path: '/devices/health/:provider',
        builder: (_, state) => HealthProviderSetupScreen(
          providerId: state.pathParameters['provider']!,
        ),
      ),
      GoRoute(
        path: '/social',
        builder: (_, state) => SocialScreen(
          initialPlayerId: state.uri.queryParameters['player'],
          initialFocus: state.uri.queryParameters['focus'],
        ),
      ),
      GoRoute(
        path: '/friends',
        builder: (_, state) => FriendsScreen(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(path: '/groups', builder: (_, _) => const FriendGroupsScreen()),
      GoRoute(
        path: '/groups/:id',
        builder: (_, state) =>
            FriendGroupDetailScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invite/scan',
        builder: (_, _) => const InviteQrScannerScreen(),
      ),
      GoRoute(
        path: '/invite/:secret',
        builder: (_, state) =>
            InviteRedeemScreen(secret: state.pathParameters['secret']!),
      ),
      GoRoute(
        path: '/teams/:id',
        builder: (_, state) =>
            TeamDetailScreen(teamId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/rules', builder: (_, _) => const RulesAssistantScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, state) => AuthScreen(
          startMode: state.uri.queryParameters['mode'] ?? 'signin',
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/dev/cloud-diagnostics',
        builder: (_, _) => const CloudDiagnosticsScreen(),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(
        path: '/paywall',
        builder: (_, state) => PaywallScreen(
          recommendedPlan: state.uri.queryParameters['plan'],
          gateKey: state.uri.queryParameters['gate'],
          reason: state.uri.queryParameters['reason'],
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(path: '/coach', builder: (_, _) => const CoachScreen()),
      GoRoute(
        path: '/coach/profile/:id',
        builder: (_, state) =>
            CoachProfileScreen(coachId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pro-chat',
        builder: (_, state) => ProChatScreen(
          initialQuestion: state.uri.queryParameters['q'],
          mode: state.uri.queryParameters['mode'] ?? 'RULES',
          matchId: state.uri.queryParameters['matchId'],
          matchContext: state.uri.queryParameters['ctx'],
        ),
      ),
      // Public recap pages live on the web; open the hosted page when possible.
      GoRoute(
        path: '/recap/:slug',
        redirect: (_, state) {
          final slug = state.pathParameters['slug'];
          if (slug != null &&
              slug.isNotEmpty &&
              CloudConfig.supabaseConfigured) {
            final url = CloudConfig.recapUrl(slug);
            // Fire-and-forget external open; still land on history in-app.
            unawaited(launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ));
          }
          return '/history';
        },
      ),
    ],
  );
});

class RallyMateApp extends ConsumerStatefulWidget {
  const RallyMateApp({super.key});

  @override
  ConsumerState<RallyMateApp> createState() => _RallyMateAppState();
}

class _RallyMateAppState extends ConsumerState<RallyMateApp>
    with WidgetsBindingObserver {
  /// Costruito una sola volta: ThemeData è immutabile e ricrearlo a ogni
  /// rebuild della radice invalida le cache di stile a valle.
  static final ThemeData _theme = rallyTheme();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri>? _notificationLinkSubscription;
  StreamSubscription<void>? _healthRationaleSubscription;
  StreamSubscription<RemotePushToken>? _remotePushTokenSubscription;
  StreamSubscription<MethodCall>? _providerEventSubscription;
  Timer? _wearableSyncTimer;
  Timer? _cloudSyncTimer;
  Future<void>? _wearableSyncInFlight;
  Future<void>? _duoSyncInFlight;
  Future<void>? _storePlanSyncInFlight;
  DateTime? _lastCloudSyncAt;
  String? _lastHandledLink;
  DateTime? _lastHandledLinkAt;

  /// I timer periodici lavorano solo ad app in primo piano: in background il
  /// rientro è già coperto dal sync su `resumed`, quindi radio e CPU possono
  /// dormire. `null` (stato non ancora noto) è trattato come attivo.
  bool get _foreground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    unawaited(_handleInitialLink());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeRuntimeServices());
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _notificationLinkSubscription?.cancel();
    _healthRationaleSubscription?.cancel();
    _remotePushTokenSubscription?.cancel();
    _providerEventSubscription?.cancel();
    _wearableSyncTimer?.cancel();
    _cloudSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Server plan first, then store (store must not free-overwrite paid).
      unawaited(_reconcilePlansOnResume());
      unawaited(_syncCloudTeamsAndImages());
      unawaited(_syncPendingDuo());
      unawaited(_syncWearableProviders());
      // Drain native watch event queue after background (not only at cold start).
      unawaited(ref.read(watchSyncProvider.notifier).refresh());
      unawaited(_processHealthAssociationJobs());
      unawaited(ref.read(pushRegistrationServiceProvider).sync());
      unawaited(ref.read(socialServiceProvider).markActive());
    }
  }

  Future<void> _reconcilePlansOnResume() async {
    try {
      await ref.read(cloudAuthProvider.notifier).refreshServerPlanMirror();
    } catch (_) {}
    await _syncStorePlan();
  }

  /// Offline reconciliation: retry match↔health association jobs after
  /// Health Connect / HealthKit data or permissions become available.
  Future<void> _processHealthAssociationJobs() async {
    try {
      await ref.read(matchHealthSyncProvider).processDueJobs();
    } catch (_) {
      // Best-effort; scoring and local match data stay authoritative.
    }
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && mounted) _handleIncomingLink(uri);
    } on Exception {
      // A malformed or unavailable platform link must not block startup.
    }
  }

  void _handleIncomingLink(Uri uri) {
    final raw = uri.toString();
    final now = DateTime.now();
    final lastHandledAt = _lastHandledLinkAt;
    if (_lastHandledLink == raw &&
        lastHandledAt != null &&
        now.difference(lastHandledAt) < const Duration(seconds: 2)) {
      return;
    }
    String? location;
    if (uri.scheme == 'rallymate') {
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        location = '/invite/${Uri.encodeComponent(uri.pathSegments.first)}';
      } else if (uri.host == 'recap' && uri.pathSegments.isNotEmpty) {
        location = '/recap/${Uri.encodeComponent(uri.pathSegments.first)}';
      } else if (uri.host == 'devices' &&
          uri.pathSegments.firstOrNull == 'google-health') {
        location = '/devices/health/GOOGLE_HEALTH';
      } else if (uri.host == 'devices' &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'health') {
        final provider = uri.pathSegments[1].toUpperCase();
        if (RegExp(r'^[A-Z0-9_]{2,50}$').hasMatch(provider)) {
          location = '/devices/health/$provider';
        }
      } else if (uri.host == 'auth-callback') {
        // Supabase processes the PKCE token; restore any stashed returnTo so
        // OAuth does not drop the user on a bare /auth screen.
        _lastHandledLink = raw;
        _lastHandledLinkAt = now;
        location = '/auth';
        unawaited(_openAuthCallback());
        return;
      } else if (uri.host == 'friends') {
        final tab = uri.queryParameters['tab'];
        location = tab == null || tab.isEmpty
            ? '/friends'
            : Uri(
                path: '/friends',
                queryParameters: {'tab': tab},
              ).toString();
      } else if (uri.host == 'social') {
        final focus = uri.queryParameters['focus'];
        final player = uri.queryParameters['player'];
        final params = <String, String>{
          if (focus != null && focus.isNotEmpty) 'focus': focus,
          if (player != null && player.isNotEmpty) 'player': player,
        };
        location = params.isEmpty
            ? '/social'
            : Uri(path: '/social', queryParameters: params).toString();
      } else if (uri.host == 'teams') {
        location = uri.pathSegments.isEmpty
            ? '/teams'
            : '/teams/${Uri.encodeComponent(uri.pathSegments.first)}';
      } else if (uri.host == 'training') {
        location = '/training';
      } else if (uri.host == 'match') {
        if (uri.pathSegments.isEmpty) {
          location = '/history';
        } else if (uri.pathSegments.first == 'new') {
          // Push deep link: rallymate://match/new?opponentName=...&linkedMatchId=
          final params = Map<String, String>.from(uri.queryParameters);
          location = params.isEmpty
              ? '/match/new'
              : Uri(path: '/match/new', queryParameters: params).toString();
        } else {
          final matchId = Uri.encodeComponent(uri.pathSegments.first);
          if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'duo') {
            location = '/match/$matchId/duo';
          } else if (uri.pathSegments.length >= 2 &&
              uri.pathSegments[1] == 'live') {
            location = '/match/$matchId/live';
          } else {
            location = '/match/$matchId';
          }
        }
      } else if (uri.host == 'coach') {
        if (uri.pathSegments.length >= 2 &&
            uri.pathSegments.first == 'package') {
          location = '/coach';
        } else if (uri.pathSegments.isNotEmpty) {
          location =
              '/coach/profile/${Uri.encodeComponent(uri.pathSegments.first)}';
        } else {
          location = '/coach';
        }
      } else if (uri.host == 'devices') {
        if (uri.pathSegments.isEmpty) {
          location = '/devices';
        } else if (uri.pathSegments.first == 'setup') {
          location = '/devices/setup';
        }
      }
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 2) {
      if (uri.pathSegments.first == 'invite') {
        location = '/invite/${Uri.encodeComponent(uri.pathSegments[1])}';
      } else if (uri.pathSegments.first == 'recap') {
        location = '/recap/${Uri.encodeComponent(uri.pathSegments[1])}';
      }
    }
    if (location != null) {
      _lastHandledLink = raw;
      _lastHandledLinkAt = now;
      unawaited(_navigateRespectingOnboarding(location));
    }
  }

  Future<void> _openAuthCallback() async {
    final returnTo = await ref.read(cloudAuthProvider.notifier).takeAuthReturnTo();
    // Re-stash so AuthScreen finish can still consume it after session hydrates.
    if (returnTo != null) {
      await ref.read(cloudAuthProvider.notifier).stashAuthReturnTo(returnTo);
    }
    final target = returnTo == null
        ? '/auth'
        : Uri(
            path: '/auth',
            queryParameters: {'returnTo': returnTo},
          ).toString();
    if (!mounted) return;
    ref.read(routerProvider).go(target);
  }

  Future<void> _navigateRespectingOnboarding(String location) async {
    final path = Uri.tryParse(location)?.path ?? location;
    final exempt = path == '/onboarding' ||
        path == '/paywall' ||
        path == '/auth' ||
        path.startsWith('/invite/');
    var done = ref.read(onboardingDoneProvider);
    if (done == null) {
      done = await ref.read(keyValueRepoProvider).get('onboarding_done') == 'true';
      ref.read(onboardingDoneProvider.notifier).state = done;
    }
    if (!done && !exempt) {
      await ref.read(cloudAuthProvider.notifier).stashPendingDeepLink(location);
      if (!mounted) return;
      ref.read(routerProvider).go('/onboarding');
      return;
    }
    if (!mounted) return;
    ref.read(routerProvider).go(location);
  }

  Future<void> _initializeRuntimeServices() async {
    await Future.wait([
      _guardedInit('Dati locali', () => ref.read(appBootstrapProvider.future)),
      _guardedInit('Supabase', initCloud),
      _guardedInit('RevenueCat', PurchasesService.init),
    ]);
    if (!mounted) return;

    // CloudAuth may have been read during the very first frame. Rebuild it now
    // that the singleton is ready, then align the cached plan with the store.
    ref.invalidate(cloudAuthProvider);
    final cloudAuth = ref.read(cloudAuthProvider.notifier);
    await cloudAuth.migrateLegacyAccountState();
    await cloudAuth.reconcileCurrentSession();
    await _syncStorePlan();
    unawaited(_syncCloudTeamsAndImages());
    unawaited(_syncPendingDuo());
    final notifications = ref.read(notificationServiceProvider);
    _notificationLinkSubscription ??= notifications.openedLinks.listen(
      _handleIncomingLink,
    );
    _remotePushTokenSubscription ??= notifications.remoteTokenChanges.listen(
      (_) => unawaited(
        ref.read(pushRegistrationServiceProvider).sync(force: true),
      ),
    );
    final initialNotification = await notifications.initialOpenedLink();
    if (initialNotification != null && mounted) {
      _handleIncomingLink(initialNotification);
    }
    // Health Connect rationale (foglio permessi → "privacy policy"): mostra
    // la schermata Privacy e dati sia a freddo sia ad app già aperta.
    final healthConnect = ref.read(healthConnectServiceProvider);
    _healthRationaleSubscription ??= healthConnect.rationaleRequests.listen(
      (_) => unawaited(_navigateRespectingOnboarding('/privacy')),
    );
    if (await healthConnect.consumeRationaleRequest() && mounted) {
      unawaited(_navigateRespectingOnboarding('/privacy'));
    }
    unawaited(ref.read(pushRegistrationServiceProvider).sync(force: true));
    final wearableProviders = ref.read(wearableProviderServiceProvider);
    _providerEventSubscription ??= wearableProviders.nativeEvents.listen((
      event,
    ) {
      if (event.method == 'garminMessage') {
        unawaited(_syncWearableProviders());
      }
    });
    unawaited(_syncWearableProviders());
    _wearableSyncTimer ??= Timer.periodic(const Duration(minutes: 15), (_) {
      if (_foreground) unawaited(_syncWearableProviders());
    });
    _cloudSyncTimer ??= Timer.periodic(const Duration(minutes: 15), (_) {
      if (_foreground) {
        unawaited(_syncCloudTeamsAndImages(force: true));
        unawaited(_syncPendingDuo());
      }
    });
    if (ref.read(cloudAuthProvider).profileLinked) {
      unawaited(ref.read(socialServiceProvider).markActive());
    }
  }

  /// [force] salta il debounce (login, timer periodico). Il debounce evita di
  /// rifare 4 chiamate di rete a ogni `resumed`: su Android/iOS anche il
  /// ritorno da un picker o da un dialogo di permessi conta come resume.
  Future<void> _syncCloudTeamsAndImages({bool force = false}) async {
    if (!ref.read(cloudAuthProvider).profileLinked) return;
    final last = _lastCloudSyncAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastCloudSyncAt = DateTime.now();
    await ref.read(teamCloudServiceProvider).syncOwnedMetadata();
    await ref.read(teamCloudServiceProvider).syncMemberships();
    await ref.read(teamImageServiceProvider).syncPending();
    await ref.read(profileImageServiceProvider).syncPending();
    await ref.read(backupServiceProvider).backupIfDue();
  }

  Future<void> _syncWearableProviders() {
    final running = _wearableSyncInFlight;
    if (running != null) return running;
    late final Future<void> guarded;
    guarded = _syncWearableProvidersNow().whenComplete(() {
      if (identical(_wearableSyncInFlight, guarded)) {
        _wearableSyncInFlight = null;
      }
    });
    _wearableSyncInFlight = guarded;
    return guarded;
  }

  Future<void> _syncPendingDuo() {
    final running = _duoSyncInFlight;
    if (running != null) return running;
    late final Future<void> guarded;
    guarded = _syncPendingDuoNow().whenComplete(() {
      if (identical(_duoSyncInFlight, guarded)) _duoSyncInFlight = null;
    });
    _duoSyncInFlight = guarded;
    return guarded;
  }

  Future<void> _syncStorePlan() {
    final running = _storePlanSyncInFlight;
    if (running != null) return running;
    late final Future<void> next;
    next = _syncStorePlanNow().whenComplete(() {
      if (identical(_storePlanSyncInFlight, next)) {
        _storePlanSyncInFlight = null;
      }
    });
    _storePlanSyncInFlight = next;
    return next;
  }

  Future<void> _syncStorePlanNow() async {
    final userId = cloudClient?.auth.currentUser?.id;
    if (userId == null) return;
    final provider = storePlanSyncProvider(userId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (error) {
      debugPrint('Sync piano store non riuscita: $error');
    }
  }

  Future<void> _syncPendingDuoNow() async {
    if (!ref.read(cloudAuthProvider).profileLinked) return;
    try {
      await ref.read(duoServiceProvider).syncPendingMatches();
    } catch (error) {
      debugPrint('Sync Duo pendente rinviata: $error');
    }
  }

  Future<void> _syncWearableProvidersNow() async {
    if (!ref.read(cloudAuthProvider).profileLinked) return;
    try {
      final provider = ref.read(wearableProviderServiceProvider);
      await provider.syncGarminQueue(
        commitEventsToPhone: (events) async {
          await ref
              .read(wearableCloudSyncProvider)
              .commitGarminEvents(events);
        },
        onControlMessage: (nativeId, payload) => ref
            .read(wearableMatchDispatcherProvider)
            .handleGarminControlMessage(nativeId, payload),
      );
      await ref.read(wearableCloudSyncProvider).sync();
      final devices = await ref.read(connectedDeviceRepoProvider).all();
      final googleHealthConfigured = devices.any(
        (device) => device.platform == 'GOOGLE_HEALTH',
      );
      if (googleHealthConfigured &&
          ref.read(entitlementsProvider).healthConnectSync) {
        final status = await provider.googleHealthStatus();
        if (status.connected) await provider.syncGoogleHealthToday();
      }
    } catch (error) {
      debugPrint('Sync provider wearable rinviata: $error');
    }
  }

  Future<void> _guardedInit(
    String label,
    Future<void> Function() initialize,
  ) async {
    try {
      await initialize();
    } catch (error) {
      debugPrint('$label init fallita, si prosegue offline: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cloudAuthProvider, (previous, next) {
      if (next.profileLinked && previous?.profileLinked != true) {
        unawaited(_syncCloudTeamsAndImages(force: true));
        unawaited(_syncPendingDuo());
        unawaited(_syncWearableProviders());
        unawaited(ref.read(pushRegistrationServiceProvider).sync(force: true));
        unawaited(ref.read(socialServiceProvider).markActive());
      }
    });
    return MaterialApp.router(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          StartupSplashGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Partite',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analisi',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
