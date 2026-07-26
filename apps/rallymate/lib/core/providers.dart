/// App-wide providers (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rally_core/rally_core.dart';

import '../data/db/database.dart';
import '../data/repositories/repositories.dart';
import '../data/repositories/health_repository.dart';
import '../domain/entitlements.dart';
import '../services/cloud/cloud_config.dart';
import '../services/ble_heart_rate.dart';
import '../services/ble_heart_rate_provider.dart';
import '../services/health_connect.dart';
import '../services/system_health_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final playerRepoProvider = Provider(
  (ref) => PlayerRepository(ref.watch(databaseProvider)),
);
final teamRepoProvider = Provider(
  (ref) => TeamRepository(ref.watch(databaseProvider)),
);
final connectedDeviceRepoProvider = Provider(
  (ref) => ConnectedDeviceRepository(ref.watch(databaseProvider)),
);
final healthDataRepoProvider = Provider(
  (ref) => HealthDataRepository(ref.watch(databaseProvider)),
);
final bleHeartRateServiceProvider = Provider((ref) {
  final service = BleHeartRateService(ref.watch(healthDataRepoProvider));
  ref.onDispose(service.dispose);
  return service;
});
final bleHeartRateDataProvider = Provider(
  (ref) => BleHeartRateDataProvider(
    ref.watch(bleHeartRateServiceProvider),
    ref.watch(healthDataRepoProvider),
  ),
);
final systemHealthProvider = Provider(
  (ref) => SystemHealthDataProvider(
    ref.watch(healthConnectServiceProvider),
    ref.watch(healthDataRepoProvider),
  ),
);
final matchRepoProvider = Provider(
  (ref) => MatchRepository(ref.watch(databaseProvider)),
);
final trainingRepoProvider = Provider(
  (ref) => TrainingRepository(ref.watch(databaseProvider)),
);
final keyValueRepoProvider = Provider(
  (ref) => KeyValueRepository(ref.watch(databaseProvider)),
);

final meProvider = StreamProvider(
  (ref) => ref.watch(playerRepoProvider).watchMe(),
);

/// Cache in-memory dello stato onboarding, letta dal redirect del router a
/// ogni navigazione (il KV `onboarding_done` è la fonte persistente).
/// `null` = non ancora determinato.
final onboardingDoneProvider = StateProvider<bool?>((ref) => null);

/// Local-first bootstrap: the app must remain usable even before the user
/// completes onboarding. A default local profile prevents route guards and team
/// creation from collapsing into the onboarding screen.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  final players = ref.watch(playerRepoProvider);
  final trainings = ref.watch(trainingRepoProvider);
  await trainings.ensureSeeded();
  final me = await players.me();
  if (me != null) {
    // Installazione esistente: se il profilo è già personalizzato considera
    // l'onboarding fatto (retro-compatibilità con i DB creati prima del flag).
    final kv = ref.read(keyValueRepoProvider);
    if (await kv.get('onboarding_done') == null &&
        (me.name != 'Giocatore' || me.nickname.isNotEmpty)) {
      await kv.set('onboarding_done', 'true');
    }
    return;
  }
  await players.saveMe(
    name: 'Giocatore',
    nickname: '',
    hand: DominantHand.rightHand,
    role: PadelRole.undefined,
    level: PlayerLevel.intermediate,
    goal: '',
  );
});

final teamsProvider = StreamProvider(
  (ref) => ref.watch(teamRepoProvider).watchAll(),
);

final connectedDevicesProvider = StreamProvider(
  (ref) => ref.watch(connectedDeviceRepoProvider).watchAll(),
);

final healthDataSourcesProvider = StreamProvider(
  (ref) => ref.watch(healthDataRepoProvider).watchSources(),
);

final recentMatchesProvider = StreamProvider(
  (ref) => ref.watch(matchRepoProvider).watchRecent(),
);

final historyMatchesProvider = StreamProvider(
  (ref) => ref.watch(matchRepoProvider).watchCompleted(),
);

final trainingsProvider = StreamProvider(
  (ref) => ref.watch(trainingRepoProvider).watchAll(),
);

final trainingLogsProvider = StreamProvider(
  (ref) => ref.watch(trainingRepoProvider).watchLogs(),
);

/// User control: share synthetic training + team context with Pallino.
/// Default ON. Never includes platform health APIs. Store/GDPR toggle.
final assistantShareTrainingTeamProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(keyValueRepoProvider)
      .watch('assistant_share_training_team')
      .map((v) {
        if (v == null || v.isEmpty) return true;
        final n = v.trim().toLowerCase();
        return n != '0' && n != 'false' && n != 'off' && n != 'no';
      });
});

/// Plan persisted in the local KV store. Purchase flow (RevenueCat) writes
/// here after store validation; the rest of the app only reads
/// [entitlementsProvider].
final planProvider = StreamProvider<Plan>((ref) {
  return ref.watch(keyValueRepoProvider).watch('plan').map(Plan.fromName);
});

/// Override premium concesso dal backend (profiles.premium_override) a
/// tester/admin: mirror locale nel KV, scritto da CloudAuth al sync profilo.
final premiumOverrideProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(keyValueRepoProvider)
      .watch('premium_override')
      .map((v) => v == 'true');
});

final entitlementsProvider = Provider<Entitlements>((ref) {
  // Bypass di test esplicito: sblocca tutto il client senza pagare
  // (le feature server-side restano protette da RLS).
  if (CloudConfig.testPremium) {
    return const Entitlements(Plan.coach, premiumOverride: true);
  }
  final planAsync = ref.watch(planProvider);
  final overrideAsync = ref.watch(premiumOverrideProvider);
  // Prefer last known value while streams reconnect to avoid free-paywall flash.
  final plan = planAsync.valueOrNull ?? Plan.free;
  final override = overrideAsync.valueOrNull ?? false;
  return Entitlements(plan, premiumOverride: override);
});

/// Rules Assistant: pure local search over the FIP-based FAQ (PRD E2).
final rulesSearchProvider = Provider((ref) => RulesSearch(padelRules));

/// All completed match summaries (analytics source).
final summariesProvider = FutureProvider<List<MatchSummary>>((ref) {
  ref.watch(recentMatchesProvider); // recompute when matches change
  return ref.watch(matchRepoProvider).completedSummaries();
});

/// Rating Padelandia (PRD F5): serie elo-lite ricalcolata in locale dallo
/// storico dei match completati. Deterministico e senza stato persistito.
final ratingHistoryProvider = FutureProvider<RatingHistory>((ref) async {
  final summaries = await ref.watch(summariesProvider.future);
  return RatingHistory.compute(summaries);
});

/// Weekly summary for the Home dashboard (PRD B2).
final weeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  final summaries = await ref.watch(summariesProvider.future);
  final now = DateTime.now();
  final weekStart = now
      .subtract(Duration(days: now.weekday - 1))
      .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  final weekStartMs = weekStart.millisecondsSinceEpoch;
  final thisWeek = summaries.where((s) => s.endTimeMs >= weekStartMs).toList();
  return WeeklySummary.compute(weekStartMs, thisWeek);
});

/// Progressi/regressioni (PRD B3): last 5 vs previous 5.
final insightsProvider = FutureProvider<List<Insight>>((ref) async {
  final summaries = await ref.watch(summariesProvider.future);
  if (summaries.length < 4) return const [];
  final recent = summaries.take(5).toList();
  final baseline = summaries.skip(5).take(10).toList();
  if (baseline.length < 2) return const [];
  return ProgressAnalyzer.compare(recent: recent, baseline: baseline);
});
