import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/core/providers.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/services/watch_sync.dart';
import 'package:rallymate/services/wearable_match_dispatcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _watchChannel = MethodChannel('com.rallymate/watch');
const _authorityVersionStorageKey = 'watch_sync_phone_authority_version_v1';

Map<String, Object?> watchStatus({
  required int protocolVersion,
  required bool probed,
}) => <String, Object?>{
  'supported': true,
  'paired': true,
  'companionInstalled': true,
  'reachable': true,
  'connected': true,
  'permissionsComplete': true,
  'platform': 'Wear OS',
  'deviceName': 'Pixel Watch test',
  'status': 'READY',
  'capabilities': <String>[
    'scoring',
    if (protocolVersion >= 2) 'star_point_v1',
  ],
  'scoringProtocolVersion': protocolVersion,
  'scoringCapabilityProbed': probed,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    // Let the service's documented best-effort snapshot refreshes finish
    // before disposing their in-memory repositories.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_watchChannel, null);
    container.dispose();
    await db.close();
  });

  test(
    'cached v2 plus failed fresh probe never sends a Star Point start',
    () async {
      var refreshCalls = 0;
      var startCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                refreshCalls++;
                if (refreshCalls == 1) {
                  // Startup diagnostics cache a real v2 status.
                  return watchStatus(protocolVersion: 2, probed: true);
                }
                // The explicit dispatch probe fails: cached v2 is forbidden.
                throw PlatformException(code: 'probe_failed');
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                return true;
              case 'startMatch':
                startCalls++;
                return true;
            }
            return null;
          });
      final row = await container
          .read(matchRepoProvider)
          .create(format: MatchFormat.starPointBo3);

      final result = await container
          .read(wearableMatchDispatcherProvider)
          .startMatch(matchId: row.id, format: MatchFormat.starPointBo3);

      expect(refreshCalls, greaterThanOrEqualTo(2));
      expect(container.read(watchSyncProvider).scoringProtocolVersion, 2);
      expect(result.sent, isFalse);
      expect(result.message, contains('Aggiorna Momentum sul watch'));
      expect(startCalls, 0);
    },
  );

  test('fresh v2 proof sends Star Point exactly once', () async {
    var refreshCalls = 0;
    var startCalls = 0;
    String? sentFormat;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_watchChannel, (call) async {
          switch (call.method) {
            case 'refreshStatus':
              refreshCalls++;
              return watchStatus(protocolVersion: 2, probed: true);
            case 'drainEvents':
              return '[]';
            case 'publishResumableMatches':
              return true;
            case 'startMatch':
              startCalls++;
              sentFormat =
                  (call.arguments as Map<Object?, Object?>)['format']
                      as String?;
              return true;
          }
          return null;
        });
    final row = await container
        .read(matchRepoProvider)
        .create(format: MatchFormat.starPointBo3);

    final result = await container
        .read(wearableMatchDispatcherProvider)
        .startMatch(matchId: row.id, format: MatchFormat.starPointBo3);

    expect(refreshCalls, greaterThanOrEqualTo(2));
    expect(result.sent, isTrue);
    expect(startCalls, 1);
    expect(
      (jsonDecode(sentFormat!) as Map<String, Object?>)['gameScoringMode'],
      GameScoringMode.starPoint.wire,
    );
  });

  test(
    'v2 advertisement without a confirmed native probe fails closed',
    () async {
      var startCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 2, probed: false);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                return true;
              case 'startMatch':
                startCalls++;
                return true;
            }
            return null;
          });
      final row = await container
          .read(matchRepoProvider)
          .create(format: MatchFormat.starPointBo3);

      final result = await container
          .read(wearableMatchDispatcherProvider)
          .startMatch(matchId: row.id, format: MatchFormat.starPointBo3);

      expect(result.sent, isFalse);
      expect(startCalls, 0);
    },
  );

  test('Star Point lifecycle fails closed before the native send', () async {
    var lifecycleCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_watchChannel, (call) async {
          switch (call.method) {
            case 'refreshStatus':
              throw PlatformException(code: 'probe_failed');
            case 'drainEvents':
              return '[]';
            case 'publishResumableMatches':
              return true;
            case 'matchLifecycle':
              lifecycleCalls++;
              return true;
          }
          return null;
        });
    final row = await container
        .read(matchRepoProvider)
        .create(format: MatchFormat.starPointBo3);

    final sent = await container
        .read(watchSyncProvider.notifier)
        .sendMatchLifecycle(
          matchId: row.id,
          action: 'PAUSED',
          format: MatchFormat.starPointBo3,
          events: const <MatchEvent>[],
        );

    expect(sent, isFalse);
    expect(lifecycleCalls, 0);
  });

  test(
    'lifecycle and following snapshot share monotonic phone authority',
    () async {
      Map<String, Object?>? lifecycle;
      final snapshots = <Map<String, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 2, probed: true);
              case 'drainEvents':
                return '[]';
              case 'matchLifecycle':
                lifecycle = (call.arguments as Map<Object?, Object?>)
                    .cast<String, Object?>();
                return true;
              case 'publishResumableMatches':
                snapshots.add(
                  (call.arguments as Map<Object?, Object?>)
                      .cast<String, Object?>(),
                );
                return true;
            }
            return null;
          });
      final row = await container
          .read(matchRepoProvider)
          .create(format: MatchFormat.starPointBo3);
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      snapshots.clear();

      expect(
        await service.sendMatchLifecycle(
          matchId: row.id,
          action: 'PAUSED',
          format: MatchFormat.starPointBo3,
          events: const <MatchEvent>[],
        ),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sentLifecycle = lifecycle;
      expect(sentLifecycle, isNotNull);
      expect(sentLifecycle!['authoritySource'], 'PHONE');
      expect(sentLifecycle['authorityScope'], 'STAR_POINT');
      final lifecycleVersion = sentLifecycle['authorityVersion']! as int;
      expect(lifecycleVersion, isPositive);
      expect(
        snapshots
            .where(
              (snapshot) =>
                  snapshot['authorityScope'] == 'STAR_POINT' &&
                  (snapshot['authorityVersion']! as int) > lifecycleVersion,
            )
            .isNotEmpty,
        isTrue,
      );
    },
  );

  test(
    'legacy snapshot excludes Star Point but keeps compatible matches',
    () async {
      final snapshots = <Map<String, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 1, probed: true);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                snapshots.add(
                  (call.arguments as Map<Object?, Object?>)
                      .cast<String, Object?>(),
                );
                return true;
            }
            return null;
          });
      final repo = container.read(matchRepoProvider);
      final classic = await repo.create(
        matchId: 'classic-resumable',
        format: MatchFormat.advantageBo3,
      );
      final star = await repo.create(
        matchId: 'star-resumable',
        format: MatchFormat.starPointBo3,
      );
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      snapshots.clear();

      expect(await service.publishResumableMatches(), isTrue);

      expect(snapshots, hasLength(2));
      expect(snapshots.first['requiresScoringV2'], isTrue);
      expect(snapshots.first['clearScoringV2Slot'], isTrue);
      expect(snapshots.first['authoritative'], isTrue);
      expect(snapshots.first['authoritySource'], 'PHONE');
      expect(snapshots.first['authorityScope'], 'STAR_POINT');
      expect(jsonDecode(snapshots.first['matches']! as String), isEmpty);
      expect(snapshots.last['requiresScoringV2'], isFalse);
      expect(snapshots.last['authorityScope'], 'NON_STAR_POINT');
      final matches = (jsonDecode(snapshots.last['matches']! as String) as List)
          .cast<Map<String, Object?>>();
      expect(matches.map((entry) => entry['matchId']), contains(classic.id));
      expect(
        matches.map((entry) => entry['matchId']),
        isNot(contains(star.id)),
      );
    },
  );

  test('proven v2 snapshot publishes filtered v1 before full v2', () async {
    final snapshots = <Map<String, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_watchChannel, (call) async {
          switch (call.method) {
            case 'refreshStatus':
              return watchStatus(protocolVersion: 2, probed: true);
            case 'drainEvents':
              return '[]';
            case 'publishResumableMatches':
              snapshots.add(
                (call.arguments as Map<Object?, Object?>)
                    .cast<String, Object?>(),
              );
              return true;
          }
          return null;
        });
    final repo = container.read(matchRepoProvider);
    final classic = await repo.create(
      matchId: 'classic-v2-resumable',
      format: MatchFormat.advantageBo3,
    );
    final star = await repo.create(
      matchId: 'star-v2-resumable',
      format: MatchFormat.starPointBo3,
    );
    final service = container.read(watchSyncProvider.notifier);
    await service.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    snapshots.clear();

    expect(await service.publishResumableMatches(), isTrue);

    expect(snapshots, hasLength(2));
    expect(snapshots.map((snapshot) => snapshot['requiresScoringV2']), <bool>[
      false,
      true,
    ]);
    expect(snapshots.first['authorityScope'], 'NON_STAR_POINT');
    expect(snapshots.last['authorityScope'], 'STAR_POINT');
    expect(snapshots.first['authorityVersion'], isPositive);
    expect(
      snapshots.last['authorityVersion'],
      snapshots.first['authorityVersion'],
    );
    final legacy = (jsonDecode(snapshots.first['matches']! as String) as List)
        .cast<Map<String, Object?>>();
    final v2 = (jsonDecode(snapshots.last['matches']! as String) as List)
        .cast<Map<String, Object?>>();
    expect(legacy.map((entry) => entry['matchId']), contains(classic.id));
    expect(legacy.map((entry) => entry['matchId']), isNot(contains(star.id)));
    expect(
      v2.map((entry) => entry['matchId']),
      containsAll(<String>[classic.id, star.id]),
    );
  });

  test(
    'capability downgrade publishes authoritative v2 clear before legacy snapshot',
    () async {
      var nativeStatus = watchStatus(protocolVersion: 2, probed: true);
      final snapshots = <Map<String, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return nativeStatus;
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                snapshots.add(
                  (call.arguments as Map<Object?, Object?>)
                      .cast<String, Object?>(),
                );
                return true;
            }
            return null;
          });
      final repo = container.read(matchRepoProvider);
      final classic = await repo.create(
        matchId: 'classic-after-downgrade',
        format: MatchFormat.advantageBo3,
      );
      final star = await repo.create(
        matchId: 'star-after-downgrade',
        format: MatchFormat.starPointBo3,
      );
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      snapshots.clear();

      expect(await service.publishResumableMatches(), isTrue);
      final provenGeneration = snapshots.last['authorityVersion'] as int;
      snapshots.clear();

      nativeStatus = watchStatus(protocolVersion: 1, probed: true);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(snapshots.length, greaterThanOrEqualTo(2));
      final downgrade = snapshots.sublist(snapshots.length - 2);
      expect(downgrade.map((snapshot) => snapshot['requiresScoringV2']), <bool>[
        true,
        false,
      ]);
      final clear = downgrade.first;
      expect(clear['clearScoringV2Slot'], isTrue);
      expect(clear['authoritative'], isTrue);
      expect(clear['authoritySource'], 'PHONE');
      expect(clear['authorityScope'], 'STAR_POINT');
      expect(jsonDecode(clear['matches']! as String), isEmpty);
      expect(clear['authorityVersion'], greaterThan(provenGeneration));
      expect(downgrade.last['authorityVersion'], clear['authorityVersion']);
      final legacy = (jsonDecode(downgrade.last['matches']! as String) as List)
          .cast<Map<String, Object?>>();
      expect(legacy.map((entry) => entry['matchId']), contains(classic.id));
      expect(legacy.map((entry) => entry['matchId']), isNot(contains(star.id)));
    },
  );

  test(
    'concurrent snapshot refreshes stay FIFO for reconnect authority',
    () async {
      final generations = <int>[];
      var nativePublicationCall = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 1, probed: true);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                nativePublicationCall++;
                if (nativePublicationCall.isOdd) {
                  await Future<void>.delayed(const Duration(milliseconds: 5));
                }
                final args = (call.arguments as Map<Object?, Object?>)
                    .cast<String, Object?>();
                generations.add(args['authorityVersion']! as int);
                return true;
            }
            return null;
          });
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      // Barrier: drain every best-effort publication triggered by startup and
      // capability changes before measuring the two concurrent calls below.
      expect(await service.publishResumableMatches(), isTrue);
      generations.clear();

      final results = await Future.wait(<Future<bool>>[
        service.publishResumableMatches(),
        service.publishResumableMatches(),
      ]);

      expect(results, everyElement(isTrue));
      expect(generations, hasLength(4));
      expect(generations[0], generations[1]);
      expect(generations[2], generations[3]);
      expect(generations[2], greaterThan(generations[0]));
    },
  );

  test(
    'concurrent lifecycle allocations use one atomic persistent FIFO',
    () async {
      final lifecycleGenerations = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 1, probed: true);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                return true;
              case 'matchLifecycle':
                final args = (call.arguments as Map<Object?, Object?>)
                    .cast<String, Object?>();
                lifecycleGenerations.add(args['authorityVersion']! as int);
                return true;
            }
            return null;
          });
      final repo = container.read(matchRepoProvider);
      final first = await repo.create(
        matchId: 'concurrent-authority-a',
        format: MatchFormat.advantageBo3,
      );
      final second = await repo.create(
        matchId: 'concurrent-authority-b',
        format: MatchFormat.advantageBo3,
      );
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        await Future.wait(<Future<bool>>[
          service.sendMatchLifecycle(
            matchId: first.id,
            action: 'PAUSED',
            format: MatchFormat.advantageBo3,
            events: const <MatchEvent>[],
          ),
          service.sendMatchLifecycle(
            matchId: second.id,
            action: 'PAUSED',
            format: MatchFormat.advantageBo3,
            events: const <MatchEvent>[],
          ),
        ]),
        everyElement(isTrue),
      );

      expect(lifecycleGenerations, hasLength(2));
      expect(lifecycleGenerations[1], greaterThan(lifecycleGenerations[0]));
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt(_authorityVersionStorageKey),
        greaterThanOrEqualTo(lifecycleGenerations.last),
      );
    },
  );

  test(
    'persisted authority survives service relaunch with wall clock behind it',
    () async {
      final futureHighWater =
          DateTime.now().microsecondsSinceEpoch +
          const Duration(days: 3650).inMicroseconds;
      SharedPreferences.setMockInitialValues(<String, Object>{
        _authorityVersionStorageKey: futureHighWater,
      });
      final lifecycleGenerations = <String, int>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 1, probed: true);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                return true;
              case 'matchLifecycle':
                final args = (call.arguments as Map<Object?, Object?>)
                    .cast<String, Object?>();
                lifecycleGenerations[args['matchId']! as String] =
                    args['authorityVersion']! as int;
                return true;
            }
            return null;
          });
      final repo = container.read(matchRepoProvider);
      final first = await repo.create(
        matchId: 'authority-before-relaunch',
        format: MatchFormat.advantageBo3,
      );
      final second = await repo.create(
        matchId: 'authority-after-relaunch',
        format: MatchFormat.advantageBo3,
      );
      var service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        await service.sendMatchLifecycle(
          matchId: first.id,
          action: 'PAUSED',
          format: MatchFormat.advantageBo3,
          events: const <MatchEvent>[],
        ),
        isTrue,
      );
      // Drain the lifecycle-triggered best-effort publication and one explicit
      // publication so the persisted high-water is stable before relaunch.
      expect(await service.publishResumableMatches(), isTrue);
      final beforeRelaunch = lifecycleGenerations[first.id]!;
      expect(beforeRelaunch, greaterThan(futureHighWater));
      final preferences = await SharedPreferences.getInstance();
      final persistedBeforeRelaunch = preferences.getInt(
        _authorityVersionStorageKey,
      )!;
      expect(persistedBeforeRelaunch, greaterThanOrEqualTo(beforeRelaunch));

      container.dispose();
      // Recreate the preferences singleton from its durable value to model a
      // process relaunch, while the real wall clock remains behind the seed.
      SharedPreferences.setMockInitialValues(<String, Object>{
        _authorityVersionStorageKey: persistedBeforeRelaunch,
      });
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        await service.sendMatchLifecycle(
          matchId: second.id,
          action: 'PAUSED',
          format: MatchFormat.advantageBo3,
          events: const <MatchEvent>[],
        ),
        isTrue,
      );
      final afterRelaunch = lifecycleGenerations[second.id]!;
      expect(afterRelaunch, greaterThan(persistedBeforeRelaunch));
    },
  );

  test(
    'wrong-type authority storage fails closed without native publication',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        _authorityVersionStorageKey: 'corrupt',
      });
      var lifecycleCalls = 0;
      var snapshotCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_watchChannel, (call) async {
            switch (call.method) {
              case 'refreshStatus':
                return watchStatus(protocolVersion: 1, probed: true);
              case 'drainEvents':
                return '[]';
              case 'publishResumableMatches':
                snapshotCalls++;
                return true;
              case 'matchLifecycle':
                lifecycleCalls++;
                return true;
            }
            return null;
          });
      final row = await container
          .read(matchRepoProvider)
          .create(format: MatchFormat.advantageBo3);
      final service = container.read(watchSyncProvider.notifier);
      await service.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(await service.publishResumableMatches(), isFalse);
      expect(
        await service.sendMatchLifecycle(
          matchId: row.id,
          action: 'PAUSED',
          format: MatchFormat.advantageBo3,
          events: const <MatchEvent>[],
        ),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(snapshotCalls, 0);
      expect(lifecycleCalls, 0);
    },
  );
}
