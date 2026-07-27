import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rally_core/rally_core.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/data/repositories/health_repository.dart';
import 'package:rallymate/data/repositories/repositories.dart';
import 'package:rallymate/services/health_connect.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('database creates indexes used by dashboard queries', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%'",
        )
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();

    expect(names, contains('idx_matches_recent'));
    expect(names, contains('idx_matches_status_end'));
    expect(names, contains('idx_match_events_match_seq'));
    expect(names, contains('idx_matches_duo_owner_sync'));
    expect(names, contains('idx_training_logs_date'));
  });

  test('BLE registry never persists a raw OS identifier or MAC', () async {
    final repository = HealthDataRepository(db);
    const rawIdentifier = 'AA:BB:CC:DD:EE:FF';

    await repository.saveBleSensor(
      localIdentifier: rawIdentifier,
      displayName: 'Heart Rate Sensor',
      manufacturer: '',
      connected: true,
    );

    final sensor = await db.select(db.bleSensorDevices).getSingle();
    expect(sensor.localIdentifier, isNot(rawIdentifier));
    expect(sensor.localIdentifier, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('health persistence never merges SDNN and RMSSD HRV', () async {
    final repository = HealthDataRepository(db);
    final start = DateTime(2026, 7, 13);
    final end = DateTime(2026, 7, 13, 8);

    HealthConnectSummary summary(String method) => HealthConnectSummary(
      start: start,
      end: end,
      steps: 0,
      activeCaloriesKcal: 0,
      averageHeartRateBpm: null,
      exerciseMinutes: 0,
      heartRateVariabilityMs: 48,
      heartRateVariabilityMethod: method,
      sleepMinutes: 0,
      sources: const [],
    );

    await repository.persistSummary(
      hubProvider: 'APPLE_HEALTH',
      summary: summary('SDNN'),
    );
    await repository.persistSummary(
      hubProvider: 'APPLE_HEALTH',
      summary: summary('RMSSD'),
    );

    final rows = await db.select(db.healthMetricRecords).get();
    expect(rows.map((row) => row.unit).toSet(), {'ms_sdnn', 'ms_rmssd'});
  });

  test('daily health aggregate updates one logical metric row', () async {
    final repository = HealthDataRepository(db);
    final start = DateTime(2026, 7, 18);

    HealthConnectSummary summary(DateTime end, int steps) =>
        HealthConnectSummary(
          start: start,
          end: end,
          steps: steps,
          activeCaloriesKcal: 0,
          averageHeartRateBpm: null,
          exerciseMinutes: 0,
          heartRateVariabilityMs: null,
          heartRateVariabilityMethod: 'RMSSD',
          sleepMinutes: 0,
          sources: const [],
        );

    final first = await repository.persistSummary(
      hubProvider: 'HEALTH_CONNECT',
      summary: summary(DateTime(2026, 7, 18, 8), 1000),
    );
    final second = await repository.persistSummary(
      hubProvider: 'HEALTH_CONNECT',
      summary: summary(DateTime(2026, 7, 18, 12), 2500),
    );

    final rows = await db.select(db.healthMetricRecords).get();
    expect(first.inserted, 1);
    expect(second.inserted, 0);
    expect(second.deduplicated, 1);
    expect(rows, hasLength(1));
    expect(rows.single.value, 2500);
    expect(
      rows.single.endTimeMs,
      DateTime(2026, 7, 18, 12).millisecondsSinceEpoch,
    );
  });

  test(
    'upgrade from schema 3 creates connected devices before its index',
    () async {
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            const legacyTables = [
              'CREATE TABLE players ('
                  'id TEXT PRIMARY KEY, is_me INTEGER NOT NULL DEFAULT 0, '
                  "availability TEXT NOT NULL DEFAULT 'FLEX', "
                  "style_tags TEXT NOT NULL DEFAULT '')",
              'CREATE TABLE teams ('
                  'id TEXT PRIMARY KEY, archived INTEGER NOT NULL DEFAULT 0, '
                  'created_at_ms INTEGER NOT NULL)',
              'CREATE TABLE matches ('
                  'id TEXT PRIMARY KEY, start_time_ms INTEGER, '
                  "status TEXT NOT NULL DEFAULT 'CREATED', end_time_ms INTEGER)",
              'CREATE TABLE match_event_rows ('
                  'event_id TEXT PRIMARY KEY, match_id TEXT NOT NULL, '
                  'seq INTEGER NOT NULL, synced INTEGER NOT NULL DEFAULT 0, '
                  'cloud_synced INTEGER NOT NULL DEFAULT 0)',
              'CREATE TABLE training_logs ('
                  'id TEXT PRIMARY KEY, date_ms INTEGER NOT NULL)',
            ];
            for (final statement in legacyTables) {
              raw.execute(statement);
            }
            raw.execute('PRAGMA user_version = 3');
          },
        ),
      );

      final table = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'connected_devices'",
          )
          .getSingle();
      final index = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_connected_devices_default_seen'",
          )
          .getSingle();

      expect(table.read<String>('name'), 'connected_devices');
      expect(index.read<String>('name'), 'idx_connected_devices_default_seen');
    },
  );

  test(
    'schema 10 upgrade tolerates Duo columns already shipped on device',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'rallymate-drift-upgrade-',
      );
      final file = File('${directory.path}/rallymate.sqlite');
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });

      // Reproduce the exact physical-device state: the full current schema was
      // present, but an older pre-release build left SQLite user_version at 10.
      db = AppDatabase.forTesting(NativeDatabase(file));
      await db.customSelect('SELECT 1').getSingle();
      await db.close();

      db = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) => raw.execute('PRAGMA user_version = 10'),
        ),
      );

      final columns = await db.customSelect('PRAGMA table_info(matches)').get();
      final names = columns.map((row) => row.read<String>('name')).toList();
      expect(names.where((name) => name == 'duo_owner_user_id'), hasLength(1));
      expect(names.where((name) => name == 'duo_cloud_status'), hasLength(1));
      expect(
        names.where((name) => name == 'duo_last_sync_at_ms'),
        hasLength(1),
      );
      // Schema 12 adds first_server through the same idempotent path, so a
      // device that already has the column is not a duplicate-column error.
      expect(names.where((name) => name == 'first_server'), hasLength(1));
      expect(
        await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((row) => row.read<int>('user_version')),
        12,
      );
    },
  );

  test('full match lifecycle: create → events → complete → summary', () async {
    final players = PlayerRepository(db);
    final teams = TeamRepository(db);
    final matches = MatchRepository(db);

    final me = await players.saveMe(
      name: 'Massi',
      nickname: 'Max',
      hand: DominantHand.rightHand,
      role: PadelRole.left,
      level: PlayerLevel.intermediate,
      goal: '',
    );
    final luca = await players.ensurePartner('Luca');
    final team = await teams.create(
      name: 'Io + Luca',
      playerAId: me.id,
      playerBId: luca.id,
    );

    final row = await matches.create(
      format: MatchFormat.singleSet,
      teamId: team.id,
      myRole: PadelRole.left,
      opponentLabel: 'Marco & Gio',
      difficulty: OpponentDifficulty.harder,
    );

    // Play: team A wins 6-0.
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.singleSet,
    );
    final started = engine.start();
    await matches.appendEvents(row.id, started.newEvents);
    while (!engine.state.isCompleted) {
      final r = engine.addPoint(TeamId.a);
      await matches.appendEvents(row.id, r.newEvents);
    }

    // Reload from DB and verify reconstruction.
    final events = await matches.eventsFor(row.id);
    final rebuilt = PadelScoringEngine.replay(
      matchId: row.id,
      format: MatchFormat.singleSet,
      events: events,
    );
    expect(rebuilt.state.isCompleted, isTrue);
    expect(rebuilt.state.winner, TeamId.a);

    await matches.complete(match: row, engine: rebuilt);
    final summaries = await matches.completedSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.won, isTrue);
    expect(summaries.single.setsFor, 1);
    expect(summaries.single.teamId, team.id);
    expect(summaries.single.opponentDifficulty, OpponentDifficulty.harder);
    expect(summaries.single.advancedAnalysis, isNotNull);
    expect(
      summaries.single.advancedAnalysis!.version,
      AdvancedMatchAnalysis.currentVersion,
    );
    expect(summaries.single.advancedAnalysis!.totalPoints, greaterThan(0));

    await (db.update(db.matches)..where((match) => match.id.equals(row.id)))
        .write(const MatchesCompanion(summaryJson: Value(null)));
    final rebuiltSummaries = await matches.completedSummaries();
    expect(rebuiltSummaries.single.advancedAnalysis, isNotNull);
    expect(
      MatchRepository.summaryOf((await matches.byId(row.id))!),
      isNotNull,
      reason: 'Il restore deve rigenerare e ricacheare le analytics derivate',
    );
  });

  test('appendEvents is idempotent (watch re-sync safe)', () async {
    final matches = MatchRepository(db);
    final row = await matches.create(format: MatchFormat.goldenPointBo3);
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.goldenPointBo3,
    );
    final r1 = engine.start();
    final r2 = engine.addPoint(TeamId.a);
    final all = [...r1.newEvents, ...r2.newEvents];
    await matches.appendEvents(row.id, all);
    await matches.appendEvents(row.id, all); // duplicate sync
    final events = await matches.eventsFor(row.id);
    expect(events.length, all.length);
  });

  test('watch sync can create and finalize a standalone match', () async {
    final matches = MatchRepository(db);
    const matchId = 'mt_watch_standalone';
    final engine = PadelScoringEngine(
      matchId: matchId,
      format: MatchFormat.singleSet,
    );
    final synced = <MatchEvent>[...engine.start().newEvents];
    while (!engine.state.isCompleted) {
      synced.addAll(engine.addPoint(TeamId.a).newEvents);
    }

    await matches.mergeSyncedEvents(
      matchId: matchId,
      events: synced,
      format: MatchFormat.singleSet,
    );
    await matches.mergeSyncedEvents(
      matchId: matchId,
      events: synced,
      format: MatchFormat.singleSet,
    );

    final row = await matches.byId(matchId);
    expect(row, isNotNull);
    expect(row!.status, MatchStatus.completed.wire);
    expect((await matches.eventsFor(matchId)).length, synced.length);
    final summary = MatchRepository.summaryOf(row);
    expect(summary, isNotNull);
    expect(summary!.won, isTrue);
    expect(summary.setsFor, 1);
  });

  test(
    'late synced undo reopens a completed match from the event log',
    () async {
      final matches = MatchRepository(db);
      final row = await matches.create(format: MatchFormat.singleSet);
      final engine = PadelScoringEngine(
        matchId: row.id,
        format: MatchFormat.singleSet,
      );
      await matches.appendEvents(row.id, engine.start().newEvents);
      while (!engine.state.isCompleted) {
        await matches.appendEvents(row.id, engine.addPoint(TeamId.a).newEvents);
      }
      await matches.complete(match: row, engine: engine);
      expect((await matches.byId(row.id))!.status, MatchStatus.completed.wire);

      final undo = engine.undo(device: SourceDevice.appleWatch);
      expect(undo.state.isCompleted, isFalse);
      await matches.mergeSyncedEvents(matchId: row.id, events: undo.newEvents);

      final reopened = (await matches.byId(row.id))!;
      expect(reopened.status, MatchStatus.inProgress.wire);
      expect(reopened.endTimeMs, isNull);
      expect(reopened.wonByUs, isNull);
      expect(reopened.summaryJson, isNull);

      final replayed = PadelScoringEngine.replay(
        matchId: row.id,
        format: MatchFormat.singleSet,
        events: await matches.eventsFor(row.id),
      );
      expect(replayed.state.isCompleted, isFalse);
      expect(replayed.state.display, undo.state.display);
    },
  );

  test('imported event keeps its transport acknowledgement state', () async {
    final matches = MatchRepository(db);
    final row = await matches.create(format: MatchFormat.goldenPointBo3);
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.goldenPointBo3,
    );
    final event = engine
        .start(device: SourceDevice.appleWatch)
        .newEvents
        .single
        .copyWith(synced: true);

    await matches.appendEvents(row.id, [event]);

    final persisted = await db.select(db.matchEventRows).getSingle();
    expect(persisted.synced, isTrue);
  });

  test('duo order reconciliation reports only real sequence changes', () async {
    final matches = MatchRepository(db);
    final row = await matches.create(
      format: MatchFormat.advantageBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.advantageBo3,
      duoMode: true,
      assignedTeam: TeamId.a,
    );
    final first = engine.start().newEvents.single;
    final second = engine.addPoint(TeamId.a).newEvents.first;
    await matches.appendEvents(row.id, [first, second]);

    expect(
      await matches.realignDuoOrder(row.id, [first.eventId, second.eventId]),
      isFalse,
    );
    expect(
      await matches.realignDuoOrder(row.id, [second.eventId, first.eventId]),
      isTrue,
    );
    expect((await matches.eventsFor(row.id)).map((event) => event.eventId), [
      second.eventId,
      first.eventId,
    ]);
  });

  test('pending Duo sync is scoped to its linked cloud account', () async {
    final matches = MatchRepository(db);
    final mine = await matches.create(
      matchId: 'duo_mine',
      format: MatchFormat.advantageBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );
    await matches.linkDuoSession(
      mine.id,
      sessionId: '11111111-1111-4111-8111-111111111111',
      ownerUserId: 'user-a',
      duoTeam: TeamId.a,
      cloudStatus: 'FINALIZING',
    );
    final other = await matches.create(
      matchId: 'duo_other',
      format: MatchFormat.advantageBo3,
      duoMode: true,
      duoTeam: TeamId.b,
    );
    await matches.linkDuoSession(
      other.id,
      sessionId: '22222222-2222-4222-8222-222222222222',
      ownerUserId: 'user-b',
      duoTeam: TeamId.b,
      cloudStatus: 'ACTIVE',
    );
    final done = await matches.create(
      matchId: 'duo_done',
      format: MatchFormat.advantageBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );
    await matches.linkDuoSession(
      done.id,
      sessionId: '33333333-3333-4333-8333-333333333333',
      ownerUserId: 'user-a',
      duoTeam: TeamId.a,
      cloudStatus: 'COMPLETED',
    );

    expect((await matches.duoSyncCandidates('user-a')).map((row) => row.id), [
      'duo_mine',
    ]);
    expect((await matches.duoSyncCandidates('user-b')).map((row) => row.id), [
      'duo_other',
    ]);
  });

  test(
    'legacy Duo row is adopted only from an attributed local event',
    () async {
      final matches = MatchRepository(db);
      final row = await matches.create(
        matchId: 'duo_legacy',
        format: MatchFormat.advantageBo3,
        duoMode: true,
        duoTeam: TeamId.a,
      );
      await (db.update(
        db.matches,
      )..where((match) => match.id.equals(row.id))).write(
        const MatchesCompanion(
          duoSessionId: Value('44444444-4444-4444-8444-444444444444'),
          duoCloudStatus: Value('ACTIVE'),
        ),
      );
      final engine = PadelScoringEngine(
        matchId: row.id,
        format: MatchFormat.advantageBo3,
        duoMode: true,
        assignedTeam: TeamId.a,
        sourceUserId: 'user-a',
      );
      await matches.appendEvents(row.id, engine.start().newEvents);

      expect(await matches.duoSyncCandidates('user-b'), isEmpty);
      expect((await matches.byId(row.id))!.duoOwnerUserId, isNull);
      expect(
        (await matches.duoSyncCandidates('user-a')).map((match) => match.id),
        ['duo_legacy'],
      );
      expect((await matches.byId(row.id))!.duoOwnerUserId, 'user-a');
    },
  );

  test('failed Duo creation discards only an unlinked active row', () async {
    final matches = MatchRepository(db);
    final orphan = await matches.create(
      matchId: 'duo_orphan',
      format: MatchFormat.goldenPointBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );
    final linked = await matches.create(
      matchId: 'duo_linked',
      format: MatchFormat.goldenPointBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );
    await matches.linkDuoSession(
      linked.id,
      sessionId: '55555555-5555-4555-8555-555555555555',
      ownerUserId: 'user-a',
      duoTeam: TeamId.a,
      cloudStatus: 'PENDING',
    );

    expect(await matches.discardUnlinkedDuoMatch(orphan.id), isTrue);
    expect(await matches.byId(orphan.id), isNull);
    expect(await matches.discardUnlinkedDuoMatch(linked.id), isFalse);
    expect((await matches.byId(linked.id))?.duoSessionId, isNotNull);
  });

  test('ambiguous Duo creation keeps its idempotency key for retry', () async {
    final matches = MatchRepository(db);
    final pending = await matches.create(
      matchId: 'duo_retry_same_match',
      format: MatchFormat.goldenPointBo3,
      duoMode: true,
      duoTeam: TeamId.a,
    );

    expect(await matches.markDuoCreationPending(pending.id), isTrue);
    final retained = await matches.byId(pending.id);
    expect(retained, isNotNull);
    expect(retained?.duoCloudStatus, 'CREATING');
    expect(retained?.duoSessionId, isNull);

    await matches.linkDuoSession(
      pending.id,
      sessionId: '77777777-7777-4777-8777-777777777777',
      ownerUserId: 'user-a',
      duoTeam: TeamId.a,
      cloudStatus: 'PENDING',
    );
    expect((await matches.byId(pending.id))?.duoSessionId, isNotNull);
  });

  test('watch pause and resume update the local match lifecycle', () async {
    final matches = MatchRepository(db);
    const matchId = 'mt_watch_lifecycle';
    final engine = PadelScoringEngine(
      matchId: matchId,
      format: MatchFormat.advantageBo3,
    );
    final events = <MatchEvent>[...engine.start().newEvents];
    events.addAll(engine.addPoint(TeamId.a).newEvents);
    events.addAll(engine.pause().newEvents);

    await matches.mergeSyncedEvents(
      matchId: matchId,
      events: events,
      format: MatchFormat.advantageBo3,
    );
    expect((await matches.byId(matchId))!.status, MatchStatus.paused.wire);

    events.addAll(engine.resume().newEvents);
    await matches.mergeSyncedEvents(
      matchId: matchId,
      events: events,
      format: MatchFormat.advantageBo3,
    );
    expect((await matches.byId(matchId))!.status, MatchStatus.inProgress.wire);
    expect((await matches.eventsFor(matchId)).length, events.length);
  });

  test('concurrent appendEvents never duplicate seq numbers', () async {
    final matches = MatchRepository(db);
    final row = await matches.create(format: MatchFormat.goldenPointBo3);
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.goldenPointBo3,
    );
    final batches = <List<MatchEvent>>[
      engine.start().newEvents,
      engine.addPoint(TeamId.a).newEvents,
      engine.addPoint(TeamId.b).newEvents,
      engine.addPoint(TeamId.a).newEvents,
    ];
    // Simula tap live + merge watch che scrivono in parallelo.
    await Future.wait([
      for (final b in batches) matches.appendEvents(row.id, b),
    ]);
    final rows = await db.select(db.matchEventRows).get();
    final seqs = rows.map((r) => r.seq).toList();
    expect(seqs.toSet().length, seqs.length, reason: 'seq deve essere unico');
  });

  test('complete() uses the last event timestamp as endTime', () async {
    final matches = MatchRepository(db);
    final row = await matches.create(format: MatchFormat.singleSet);
    final engine = PadelScoringEngine(
      matchId: row.id,
      format: MatchFormat.singleSet,
    );
    await matches.appendEvents(row.id, engine.start().newEvents);
    while (!engine.state.isCompleted) {
      await matches.appendEvents(row.id, engine.addPoint(TeamId.a).newEvents);
    }
    await matches.complete(match: row, engine: engine);
    final lastEventMs = engine.events
        .map((e) => e.timestampMs)
        .reduce((a, b) => a > b ? a : b);
    final summary = MatchRepository.summaryOf((await matches.byId(row.id))!);
    expect(summary!.endTimeMs, lastEventMs);
  });

  test(
    'summary duration counts active intervals for one-point manual finish',
    () async {
      const startMs = 1_000_000;
      final matches = MatchRepository(db);
      final created = await matches.create(format: MatchFormat.training);
      await (db.update(db.matches)
            ..where((match) => match.id.equals(created.id)))
          .write(const MatchesCompanion(startTimeMs: Value(startMs)));
      final row = (await matches.byId(created.id))!;
      var clockIndex = 0;
      final timestamps = [
        startMs,
        startMs + const Duration(minutes: 5).inMilliseconds,
        startMs + const Duration(minutes: 10).inMilliseconds,
        startMs + const Duration(days: 1).inMilliseconds,
        startMs + const Duration(days: 1, minutes: 5).inMilliseconds,
      ];
      final engine = PadelScoringEngine(
        matchId: row.id,
        format: MatchFormat.training,
        clock: () => timestamps[clockIndex++],
        idGenerator: () => 'duration-event-$clockIndex',
      );

      await matches.appendEvents(row.id, engine.start().newEvents);
      await matches.appendEvents(row.id, engine.addPoint(TeamId.a).newEvents);
      await matches.appendEvents(row.id, engine.pause().newEvents);
      await matches.appendEvents(row.id, engine.resume().newEvents);
      await matches.appendEvents(
        row.id,
        engine.finish(winner: TeamId.a).newEvents,
      );
      await matches.complete(match: row, engine: engine);

      final summary = MatchRepository.summaryOf((await matches.byId(row.id))!);
      expect(engine.pointRecords, hasLength(1));
      expect(summary?.durationMs, const Duration(minutes: 15).inMilliseconds);
    },
  );

  test('match end time rejects clock drift and future outliers', () {
    const start = 1_000_000;
    expect(
      normalizedMatchEndTime(
        startTimeMs: start,
        eventTimestamps: const [start + 2000, start + 1000],
        nowMs: start + 5000,
      ),
      start + 2000,
    );
    expect(
      normalizedMatchEndTime(
        startTimeMs: start,
        eventTimestamps: const [start + 1000, start + 999999999],
        nowMs: start + const Duration(minutes: 5).inMilliseconds,
      ),
      start + const Duration(minutes: 10).inMilliseconds,
    );
  });

  test(
    'manual completion without a winner is never stored as a loss',
    () async {
      final matches = MatchRepository(db);
      final row = await matches.create(format: MatchFormat.goldenPointBo3);
      final engine = PadelScoringEngine(
        matchId: row.id,
        format: MatchFormat.goldenPointBo3,
      );
      await matches.appendEvents(row.id, engine.start().newEvents);
      await matches.appendEvents(row.id, engine.finish().newEvents);

      final reconciled = await matches.reconcileFromEventLog(row.id);

      expect(reconciled?.row.status, MatchStatus.abandoned.wire);
      expect(reconciled?.row.wonByUs, isNull);
      expect(reconciled?.row.summaryJson, isNull);
    },
  );

  test('free plan team limit is enforced at repo count level', () async {
    final players = PlayerRepository(db);
    final teams = TeamRepository(db);
    final me = await players.saveMe(
      name: 'X',
      nickname: '',
      hand: DominantHand.rightHand,
      role: PadelRole.undefined,
      level: PlayerLevel.intermediate,
      goal: '',
    );
    for (var i = 0; i < 3; i++) {
      await teams.create(name: 'T$i', playerAId: me.id);
    }
    expect(await teams.count(), 3);
  });

  test('completed history is not truncated to the dashboard limit', () async {
    final matches = MatchRepository(db);
    for (var index = 0; index < 60; index++) {
      final row = await matches.create(format: MatchFormat.training);
      await (db.update(
        db.matches,
      )..where((match) => match.id.equals(row.id))).write(
        MatchesCompanion(
          status: const Value('COMPLETED'),
          endTimeMs: Value(1000 + index),
          wonByUs: Value(index.isEven),
        ),
      );
    }

    final history = await matches.watchCompleted().first;
    expect(history, hasLength(60));
    expect(history.first.endTimeMs, 1059);
    expect(history.last.endTimeMs, 1000);
  });

  test(
    'team image sync versions change only when image content changes',
    () async {
      final players = PlayerRepository(db);
      final teams = TeamRepository(db);
      final me = await players.saveMe(
        name: 'X',
        nickname: '',
        hand: DominantHand.rightHand,
        role: PadelRole.undefined,
        level: PlayerLevel.intermediate,
        goal: '',
      );
      final created = await teams.create(name: 'Team X', playerAId: me.id);

      await teams.updateAppearance(id: created.id, scoringStyle: 'IMAGE');
      var saved = (await teams.byId(created.id))!;
      expect(saved.scoringStyle, 'IMAGE');
      expect(saved.imageVersion, 0, reason: 'style must not trigger an upload');

      await teams.updateAppearance(
        id: created.id,
        localImagePath: '/app/team/avatar.jpg',
      );
      saved = (await teams.byId(created.id))!;
      expect(saved.imageVersion, 1);
      expect(saved.imageCloudVersion, 0);

      await teams.markImageCloudSynced(
        id: created.id,
        imageVersion: saved.imageVersion,
        cloudImagePath: 'user/team/avatar.jpg',
      );
      saved = (await teams.byId(created.id))!;
      expect(saved.imageCloudVersion, saved.imageVersion);

      await teams.updateAppearance(id: created.id, removeImage: true);
      saved = (await teams.byId(created.id))!;
      expect(saved.imageLocalPath, isNull);
      expect(saved.imageVersion, 2);
      expect(saved.imageCloudVersion, 1);
    },
  );

  test(
    'profile image remains local-first and survives profile edits',
    () async {
      final players = PlayerRepository(db);
      var me = await players.saveMe(
        name: 'Massi',
        nickname: 'Max',
        hand: DominantHand.rightHand,
        role: PadelRole.left,
        level: PlayerLevel.intermediate,
        goal: '',
      );

      await players.updateAvatar(
        id: me.id,
        localPath: '/app/profile/avatar.jpg',
      );
      me = (await players.me())!;
      expect(me.avatarLocalPath, '/app/profile/avatar.jpg');
      expect(me.avatarVersion, 1);
      expect(me.avatarCloudVersion, 0);

      await players.saveMe(
        name: 'Massimiliano',
        nickname: 'Max',
        hand: DominantHand.rightHand,
        role: PadelRole.left,
        level: PlayerLevel.advanced,
        goal: 'Torneo',
      );
      me = (await players.me())!;
      expect(me.avatarLocalPath, '/app/profile/avatar.jpg');
      expect(me.avatarVersion, 1);

      await players.markAvatarCloudSynced(
        id: me.id,
        version: me.avatarVersion,
        cloudPath: 'user-id/avatar.jpg',
      );
      me = (await players.me())!;
      expect(me.avatarCloudPath, 'user-id/avatar.jpg');
      expect(me.avatarCloudVersion, 1);

      await players.updateAvatar(
        id: me.id,
        cloudPath: me.avatarCloudPath,
        remove: true,
      );
      me = (await players.me())!;
      expect(me.avatarLocalPath, isNull);
      expect(me.avatarVersion, 2);
      expect(me.avatarCloudVersion, 1);
    },
  );

  test(
    'connected watch registry stores only logical local diagnostics',
    () async {
      final devices = ConnectedDeviceRepository(db);
      final created = await devices.upsertDiagnostics(
        platform: 'APPLE_WATCH',
        family: 'Apple Watch',
        displayName: 'Apple Watch',
        status: 'READY',
        capabilitiesJson: '["scoring","haptics"]',
        companionInstalled: true,
        permissionsComplete: true,
        setupStep: 6,
        connected: true,
      );

      expect(created.id, 'watch_apple_watch');
      expect(created.status, 'READY');
      expect(created.lastSeenAtMs, isNotNull);
      await devices.rename(created.id, 'Watch campo');
      await devices.markSynced(created.id);
      final saved = await devices.byId(created.id);
      expect(saved!.alias, 'Watch campo');
      expect(saved.lastSyncAtMs, isNotNull);
      expect(saved.capabilitiesJson, isNot(contains('serial')));
    },
  );

  test('cloud team membership reconciliation is idempotent', () async {
    final players = PlayerRepository(db);
    final teams = TeamRepository(db);
    final me = await players.saveMe(
      name: 'X',
      nickname: '',
      hand: DominantHand.rightHand,
      role: PadelRole.undefined,
      level: PlayerLevel.intermediate,
      goal: '',
    );

    const cloudId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await teams.importCloudMembership(
      cloudId: cloudId,
      name: 'Team condiviso',
      playerAId: me.id,
      cloudRole: 'MEMBER',
      ownerName: 'Luca',
      avatarPath: 'owner/team/avatar.jpg',
      imageVersion: 2,
      scoringStyle: 'AUTO',
      colorArgb: 0xFF32D6C8,
    );
    await teams.importCloudMembership(
      cloudId: cloudId,
      name: 'Team condiviso aggiornato',
      playerAId: me.id,
      cloudRole: 'MEMBER',
      ownerName: 'Luca',
      avatarPath: 'owner/team/avatar.jpg',
      imageVersion: 3,
      scoringStyle: 'IMAGE',
      colorArgb: 0xFF32D6C8,
    );

    final imported = await teams.byCloudId(cloudId);
    expect(await teams.count(), 1);
    expect(imported!.name, 'Team condiviso aggiornato');
    expect(imported.cloudRole, 'MEMBER');
    expect(imported.imageVersion, 3);
    expect(imported.imageCloudVersion, 3);

    await teams.reconcileCloudMemberships(<String>{});
    expect(await teams.count(), 0, reason: 'removed membership is archived');
  });

  test('training seed is idempotent', () async {
    final tr = TrainingRepository(db);
    await tr.seedIfEmpty();
    await tr.seedIfEmpty();
    final list = await db.select(db.trainings).get();
    expect(list.where((t) => !t.premium).length, greaterThanOrEqualTo(5));
    expect(list.where((t) => t.premium), isNotEmpty);
  });

  test(
    'duo: realignDuoOrder rewrites replay order to the server timeline',
    () async {
      final matches = MatchRepository(db);
      final row = await matches.create(
        format: MatchFormat.goldenPointBo3,
        matchId: 'mt_duo',
        duoMode: true,
        duoTeam: TeamId.b,
      );

      MatchEvent pt(String id, TeamId team, int ts) => MatchEvent(
        eventId: id,
        matchId: row.id,
        timestampMs: ts,
        type: team == TeamId.a
            ? MatchEventType.pointTeamA
            : MatchEventType.pointTeamB,
        teamId: team,
        duoMode: true,
        sourceTeamId: team,
      );

      // Ordine di arrivo locale: B poi A. Timeline server: A poi B.
      await matches.appendEvents(row.id, [
        pt('b1', TeamId.b, 2),
        pt('a1', TeamId.a, 1),
      ]);
      await matches.realignDuoOrder(row.id, ['a1', 'b1']);

      final events = await matches.eventsFor(row.id);
      expect(events.map((e) => e.eventId).toList(), ['a1', 'b1']);
      expect(events.first.sourceTeamId, TeamId.a);
      expect(events.first.duoMode, isTrue);
    },
  );

  test(
    'duo: summary uses the assigned team perspective (guest = TEAM_B)',
    () async {
      final matches = MatchRepository(db);
      final row = await matches.create(
        format: MatchFormat.singleSet,
        matchId: 'mt_duo_b',
        duoMode: true,
        duoTeam: TeamId.b,
      );

      // Team A vince 6-0: per il guest (TEAM_B) è una sconfitta 0-6.
      final engine = PadelScoringEngine(
        matchId: row.id,
        format: MatchFormat.singleSet,
      )..start();
      while (!engine.state.isCompleted) {
        engine.addPoint(TeamId.a);
      }
      await matches.appendEvents(row.id, engine.events);
      await matches.complete(match: row, engine: engine);

      final saved = await matches.byId(row.id);
      final summary = MatchRepository.summaryOf(saved!);
      expect(saved.wonByUs, isFalse);
      expect(summary!.won, isFalse);
      expect(summary.gamesFor, 0);
      expect(summary.gamesAgainst, 6);
    },
  );

  test(
    'coach-assigned sessions log into weekly load via the hidden template',
    () async {
      final trainings = TrainingRepository(db);

      // Idempotente: doppia chiamata non duplica il template.
      await trainings.ensureCoachAssignedTemplate();
      await trainings.ensureCoachAssignedTemplate();
      final templates = await db.select(db.trainings).get();
      expect(
        templates
            .where((t) => t.id == TrainingRepository.coachAssignedTrainingId)
            .length,
        1,
      );

      await trainings.logCompletion(
        TrainingRepository.coachAssignedTrainingId,
        notes: 'Settimana bandeja',
        rpe: 7,
        minutes: 45,
      );
      final logs = await db.select(db.trainingLogs).get();
      final log = logs.single;
      expect(log.trainingId, TrainingRepository.coachAssignedTrainingId);
      expect(log.completed, isTrue);
      expect(log.rpe, 7);
      expect(log.minutes, 45);
    },
  );
}
