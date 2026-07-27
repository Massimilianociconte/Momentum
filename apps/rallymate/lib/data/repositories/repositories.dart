/// Repositories: thin, testable data access over Drift + rally_core mapping.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:rally_core/rally_core.dart';

import '../db/database.dart';

final _idEntropy = Random();

/// Timestamp + salt casuale: il solo microsecondo può collidere in creazioni
/// ravvicinate (import batch, loop di seed).
String _newId(String prefix) {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _idEntropy.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
  return '${prefix}_${ts}_$salt';
}

int _nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

const _maxPlausibleMatchDurationMs = 12 * 60 * 60 * 1000;
const _futureClockToleranceMs = 5 * 60 * 1000;

int normalizedMatchEndTime({
  required int? startTimeMs,
  required Iterable<int> eventTimestamps,
  int? nowMs,
}) {
  final clock = nowMs ?? _nowMs();
  final latestAllowedByClock = clock + _futureClockToleranceMs;
  final timestamps = eventTimestamps.toList(growable: false);
  if (timestamps.isEmpty) {
    return (startTimeMs ?? clock).clamp(0, latestAllowedByClock).toInt();
  }
  final earliestEvent = timestamps.reduce((a, b) => a < b ? a : b);
  final candidate = timestamps.reduce((a, b) => a > b ? a : b);
  final start = (startTimeMs ?? earliestEvent)
      .clamp(0, latestAllowedByClock)
      .toInt();
  final latestAllowed = min(
    latestAllowedByClock,
    start + _maxPlausibleMatchDurationMs,
  );
  return candidate.clamp(start, latestAllowed).toInt();
}

// --------------------------------------------------------------- players

class PlayerRepository {
  PlayerRepository(this.db);
  final AppDatabase db;

  Future<Player?> me() async =>
      (db.select(db.players)
            ..where((p) => p.isMe.equals(true))
            ..limit(1))
          .getSingleOrNull();

  Stream<Player?> watchMe() =>
      (db.select(db.players)
            ..where((p) => p.isMe.equals(true))
            ..limit(1))
          .watchSingleOrNull();

  Future<Player> saveMe({
    required String name,
    required String nickname,
    required DominantHand hand,
    required PadelRole role,
    required PlayerLevel level,
    required String goal,
    String? clubs,
    String? bio,
    String? homeArea,
    String? preferredSide,
    String? preferredTime,
    String? playFrequency,
  }) async {
    final existing = await me();
    final id = existing?.id ?? _newId('pl');
    final row = PlayersCompanion.insert(
      id: id,
      name: name,
      nickname: Value(nickname),
      isMe: const Value(true),
      dominantHand: Value(hand.wire),
      preferredRole: Value(role.wire),
      level: Value(level.wire),
      goal: Value(goal),
      clubs: Value(clubs ?? existing?.clubs ?? ''),
      bio: Value(bio ?? existing?.bio ?? ''),
      homeArea: Value(homeArea ?? existing?.homeArea ?? ''),
      preferredSide: Value(
        preferredSide ?? existing?.preferredSide ?? 'UNDEFINED',
      ),
      preferredTime: Value(preferredTime ?? existing?.preferredTime ?? ''),
      playFrequency: Value(playFrequency ?? existing?.playFrequency ?? ''),
      avatarLocalPath: Value(existing?.avatarLocalPath),
      avatarCloudPath: Value(existing?.avatarCloudPath),
      avatarVersion: Value(existing?.avatarVersion ?? 0),
      avatarCloudVersion: Value(existing?.avatarCloudVersion ?? 0),
      createdAtMs: existing?.createdAtMs ?? _nowMs(),
    );
    await db.into(db.players).insertOnConflictUpdate(row);
    return (db.select(db.players)..where((p) => p.id.equals(id))).getSingle();
  }

  Future<Player> ensurePartner(String name) async {
    final found =
        await (db.select(db.players)
              ..where((p) => p.name.equals(name) & p.isMe.equals(false))
              ..limit(1))
            .getSingleOrNull();
    if (found != null) return found;
    final id = _newId('pl');
    await db
        .into(db.players)
        .insert(
          PlayersCompanion.insert(id: id, name: name, createdAtMs: _nowMs()),
        );
    return (db.select(db.players)..where((p) => p.id.equals(id))).getSingle();
  }

  Future<void> updatePrivacy(String privacy) async {
    final meRow = await me();
    if (meRow == null) return;
    await (db.update(db.players)..where((p) => p.id.equals(meRow.id))).write(
      PlayersCompanion(privacy: Value(privacy)),
    );
  }

  /// Preferenze matchmaking (disponibilità + tag stile csv).
  Future<void> updateSocialPrefs({
    required String availability,
    required List<String> styleTags,
  }) async {
    final meRow = await me();
    if (meRow == null) return;
    await (db.update(db.players)..where((p) => p.id.equals(meRow.id))).write(
      PlayersCompanion(
        availability: Value(availability),
        styleTags: Value(styleTags.join(',')),
      ),
    );
  }

  Future<void> updateAvatar({
    required String id,
    String? localPath,
    String? cloudPath,
    bool remove = false,
  }) async {
    final current = await (db.select(
      db.players,
    )..where((player) => player.id.equals(id))).getSingleOrNull();
    if (current == null) return;
    await (db.update(
      db.players,
    )..where((player) => player.id.equals(id))).write(
      PlayersCompanion(
        avatarLocalPath: Value(remove ? null : localPath),
        avatarCloudPath: cloudPath == null
            ? const Value.absent()
            : Value(cloudPath),
        avatarVersion: Value(current.avatarVersion + 1),
      ),
    );
  }

  Future<void> restoreAvatar({
    required String id,
    required String localPath,
    required String cloudPath,
  }) async {
    final current = await (db.select(
      db.players,
    )..where((player) => player.id.equals(id))).getSingleOrNull();
    if (current == null) return;
    final nextVersion = current.avatarVersion + 1;
    await (db.update(
      db.players,
    )..where((player) => player.id.equals(id))).write(
      PlayersCompanion(
        avatarLocalPath: Value(localPath),
        avatarCloudPath: Value(cloudPath),
        avatarVersion: Value(nextVersion),
        avatarCloudVersion: Value(nextVersion),
      ),
    );
  }

  Future<void> markAvatarCloudSynced({
    required String id,
    required int version,
    required String? cloudPath,
  }) async {
    await (db.update(
      db.players,
    )..where((player) => player.id.equals(id))).write(
      PlayersCompanion(
        avatarCloudPath: Value(cloudPath),
        avatarCloudVersion: Value(version),
      ),
    );
  }
}

// ----------------------------------------------------------------- teams

class TeamRepository {
  TeamRepository(this.db);
  final AppDatabase db;

  Stream<List<Team>> watchAll() =>
      (db.select(db.teams)
            ..where((t) => t.archived.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)]))
          .watch();

  Future<List<Team>> all() =>
      (db.select(db.teams)..where((t) => t.archived.equals(false))).get();

  Future<Team?> byId(String id) =>
      (db.select(db.teams)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Team?> byCloudId(String cloudId) => (db.select(
    db.teams,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<int> count() async {
    final c = db.teams.id.count();
    final q = db.selectOnly(db.teams)
      ..addColumns([c])
      ..where(db.teams.archived.equals(false));
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  Future<Team> create({
    required String name,
    required String playerAId,
    String? playerBId,
    String playerBName = '',
    PadelRole roleA = PadelRole.undefined,
    PadelRole roleB = PadelRole.undefined,
    String notes = '',
  }) async {
    final id = _newId('tm');
    await db
        .into(db.teams)
        .insert(
          TeamsCompanion.insert(
            id: id,
            name: name,
            playerAId: playerAId,
            playerBId: Value(playerBId),
            playerBName: Value(playerBName),
            roleA: Value(roleA.wire),
            roleB: Value(roleB.wire),
            tacticalNotes: Value(notes),
            createdAtMs: _nowMs(),
          ),
        );
    return (db.select(db.teams)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> archive(String id) =>
      (db.update(db.teams)..where((t) => t.id.equals(id))).write(
        const TeamsCompanion(archived: Value(true)),
      );

  Future<void> updateAppearance({
    required String id,
    String? localImagePath,
    bool removeImage = false,
    String? scoringStyle,
    int? colorArgb,
  }) async {
    final current = await byId(id);
    if (current == null) throw StateError('Team non trovato');
    final imageChanged = removeImage || localImagePath != null;
    await (db.update(db.teams)..where((t) => t.id.equals(id))).write(
      TeamsCompanion(
        imageLocalPath: removeImage
            ? const Value(null)
            : localImagePath == null
            ? const Value.absent()
            : Value(localImagePath),
        imageVersion: imageChanged
            ? Value(current.imageVersion + 1)
            : const Value.absent(),
        scoringStyle: scoringStyle == null
            ? const Value.absent()
            : Value(scoringStyle),
        colorArgb: colorArgb == null ? const Value.absent() : Value(colorArgb),
      ),
    );
  }

  Future<void> linkCloudTeam({
    required String id,
    required String cloudId,
  }) async {
    await (db.update(db.teams)..where((t) => t.id.equals(id))).write(
      TeamsCompanion(cloudId: Value(cloudId), cloudRole: const Value('OWNER')),
    );
  }

  Future<Team> importCloudMembership({
    required String cloudId,
    required String name,
    required String playerAId,
    required String cloudRole,
    required String ownerName,
    required String? avatarPath,
    required int imageVersion,
    required String scoringStyle,
    required int colorArgb,
  }) async {
    final existing = await byCloudId(cloudId);
    final now = _nowMs();
    if (existing == null) {
      final localId = 'tm_cloud_${cloudId.replaceAll('-', '')}';
      await db
          .into(db.teams)
          .insertOnConflictUpdate(
            TeamsCompanion.insert(
              id: localId,
              name: name,
              playerAId: playerAId,
              playerBName: Value(cloudRole == 'MEMBER' ? ownerName : ''),
              imageCloudPath: Value(avatarPath),
              imageVersion: Value(imageVersion),
              imageCloudVersion: Value(imageVersion),
              scoringStyle: Value(scoringStyle),
              colorArgb: Value(colorArgb),
              cloudId: Value(cloudId),
              cloudRole: Value(cloudRole),
              createdAtMs: now,
            ),
          );
      return (db.select(
        db.teams,
      )..where((team) => team.id.equals(localId))).getSingle();
    }

    final localImagePending =
        existing.imageVersion > existing.imageCloudVersion;
    final remoteImageChanged = imageVersion != existing.imageCloudVersion;
    await (db.update(
      db.teams,
    )..where((team) => team.id.equals(existing.id))).write(
      TeamsCompanion(
        name: Value(name),
        playerBName: Value(cloudRole == 'MEMBER' ? ownerName : ''),
        imageLocalPath:
            remoteImageChanged && (!localImagePending || cloudRole == 'MEMBER')
            ? const Value(null)
            : const Value.absent(),
        imageCloudPath: Value(avatarPath),
        imageVersion: localImagePending && cloudRole == 'OWNER'
            ? const Value.absent()
            : Value(imageVersion),
        imageCloudVersion: Value(imageVersion),
        scoringStyle: Value(scoringStyle),
        colorArgb: Value(colorArgb),
        cloudRole: Value(cloudRole),
        archived: const Value(false),
      ),
    );
    return (db.select(
      db.teams,
    )..where((team) => team.id.equals(existing.id))).getSingle();
  }

  Future<void> reconcileCloudMemberships(Set<String> activeCloudIds) async {
    final memberships = await (db.select(
      db.teams,
    )..where((team) => team.cloudRole.equals('MEMBER'))).get();
    for (final team in memberships) {
      if (team.cloudId == null || activeCloudIds.contains(team.cloudId)) {
        continue;
      }
      await (db.update(db.teams)..where((row) => row.id.equals(team.id))).write(
        const TeamsCompanion(archived: Value(true)),
      );
    }
  }

  Future<void> markImageCloudSynced({
    required String id,
    required int imageVersion,
    required String? cloudImagePath,
  }) => (db.update(db.teams)..where((t) => t.id.equals(id))).write(
    TeamsCompanion(
      imageCloudPath: Value(cloudImagePath),
      imageCloudVersion: Value(imageVersion),
    ),
  );
}

// ------------------------------------------------------ connected devices

class ConnectedDeviceRepository {
  ConnectedDeviceRepository(this.db);
  final AppDatabase db;

  Stream<List<ConnectedDevice>> watchAll() =>
      (db.select(db.connectedDevices)..orderBy([
            (d) => OrderingTerm.desc(d.isDefault),
            (d) => OrderingTerm.desc(d.lastSeenAtMs),
          ]))
          .watch();

  Future<List<ConnectedDevice>> all() => (db.select(
    db.connectedDevices,
  )..orderBy([(d) => OrderingTerm.desc(d.isDefault)])).get();

  Future<ConnectedDevice?> byId(String id) => (db.select(
    db.connectedDevices,
  )..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<ConnectedDevice> upsertDiagnostics({
    String? id,
    required String platform,
    required String family,
    required String displayName,
    required String status,
    required String capabilitiesJson,
    required bool companionInstalled,
    required bool permissionsComplete,
    required int setupStep,
    bool connected = false,
  }) async {
    final resolvedId =
        id ??
        'watch_${platform.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}';
    final existing = await byId(resolvedId);
    var existingCount = 1;
    if (existing == null) {
      final count = db.connectedDevices.id.count();
      final row = await (db.selectOnly(
        db.connectedDevices,
      )..addColumns([count])).getSingle();
      existingCount = row.read(count) ?? 0;
    }
    final now = _nowMs();
    await db
        .into(db.connectedDevices)
        .insertOnConflictUpdate(
          ConnectedDevicesCompanion.insert(
            id: resolvedId,
            platform: platform,
            family: Value(
              existing?.family.isNotEmpty == true ? existing!.family : family,
            ),
            displayName: Value(displayName),
            alias: Value(existing?.alias ?? ''),
            status: Value(status),
            capabilitiesJson: Value(capabilitiesJson),
            companionInstalled: Value(companionInstalled),
            permissionsComplete: Value(permissionsComplete),
            isDefault: Value(existing?.isDefault ?? existingCount == 0),
            setupStep: Value(setupStep),
            lastSeenAtMs: connected
                ? Value(now)
                : Value(existing?.lastSeenAtMs),
            lastSyncAtMs: Value(existing?.lastSyncAtMs),
            createdAtMs: existing?.createdAtMs ?? now,
          ),
        );
    return (db.select(
      db.connectedDevices,
    )..where((d) => d.id.equals(resolvedId))).getSingle();
  }

  Future<void> markSynced(String id) =>
      (db.update(db.connectedDevices)..where((d) => d.id.equals(id))).write(
        ConnectedDevicesCompanion(lastSyncAtMs: Value(_nowMs())),
      );

  Future<void> updateConnectionState(
    String id, {
    required String status,
    bool markSeen = false,
    bool markSynced = false,
  }) {
    final now = _nowMs();
    return (db.update(
      db.connectedDevices,
    )..where((d) => d.id.equals(id))).write(
      ConnectedDevicesCompanion(
        status: Value(status),
        lastSeenAtMs: markSeen ? Value(now) : const Value.absent(),
        lastSyncAtMs: markSynced ? Value(now) : const Value.absent(),
      ),
    );
  }

  Future<void> rename(String id, String alias) =>
      (db.update(db.connectedDevices)..where((d) => d.id.equals(id))).write(
        ConnectedDevicesCompanion(alias: Value(alias.trim())),
      );

  Future<void> saveSetup({
    required String id,
    required String family,
    required int step,
  }) => (db.update(db.connectedDevices)..where((d) => d.id.equals(id))).write(
    ConnectedDevicesCompanion(family: Value(family), setupStep: Value(step)),
  );

  Future<void> setDefault(String id) async {
    await db.transaction(() async {
      await db
          .update(db.connectedDevices)
          .write(const ConnectedDevicesCompanion(isDefault: Value(false)));
      await (db.update(db.connectedDevices)..where((d) => d.id.equals(id)))
          .write(const ConnectedDevicesCompanion(isDefault: Value(true)));
    });
  }

  Future<void> remove(String id) =>
      (db.delete(db.connectedDevices)..where((d) => d.id.equals(id))).go();
}

// --------------------------------------------------------------- matches

class MatchWithSummary {
  const MatchWithSummary(this.row, this.summary);
  final MatchRow row;
  final MatchSummary? summary;
}

class MatchReplaySnapshot {
  const MatchReplaySnapshot({required this.row, required this.engine});

  final MatchRow row;
  final PadelScoringEngine engine;
}

class MatchRepository {
  MatchRepository(this.db);
  final AppDatabase db;

  Future<MatchRow> create({
    required MatchFormat format,
    String? teamId,
    PadelRole myRole = PadelRole.undefined,
    String opponentLabel = '',
    Set<OpponentTag> tags = const {},
    OpponentDifficulty difficulty = OpponentDifficulty.sameLevel,
    String location = '',
    String? matchId,
    bool duoMode = false,
    TeamId? duoTeam,
    TeamId firstServer = TeamId.a,
  }) async {
    // Duo Mode: chi entra con un codice riusa il matchId condiviso della
    // sessione, così entrambi i telefoni parlano della stessa partita.
    final id = matchId ?? _newId('mt');
    await db
        .into(db.matches)
        .insert(
          MatchesCompanion.insert(
            id: id,
            teamId: Value(teamId),
            formatJson: jsonEncode(format.toJson()),
            firstServer: Value(firstServer.wire),
            status: const Value('IN_PROGRESS'),
            startTimeMs: Value(_nowMs()),
            myRole: Value(myRole.wire),
            opponentLabel: Value(opponentLabel),
            opponentTags: Value(tags.map((t) => t.wire).join(',')),
            opponentDifficulty: Value(difficulty.score),
            location: Value(location),
            duoMode: Value(duoMode),
            duoTeam: Value(duoTeam?.wire),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (db.select(db.matches)..where((m) => m.id.equals(id))).getSingle();
  }

  /// Collega la partita locale alla sessione Duo cloud (id + codice invito).
  Future<void> linkDuoSession(
    String matchId, {
    required String sessionId,
    required String ownerUserId,
    String? joinCode,
    TeamId? duoTeam,
    String? cloudStatus,
  }) => (db.update(db.matches)..where((m) => m.id.equals(matchId))).write(
    MatchesCompanion(
      duoMode: const Value(true),
      duoSessionId: Value(sessionId),
      duoJoinCode: Value(joinCode),
      duoTeam: duoTeam == null ? const Value.absent() : Value(duoTeam.wire),
      duoOwnerUserId: Value(ownerUserId),
      duoCloudStatus: Value(cloudStatus),
    ),
  );

  /// Persist the idempotency key before contacting the Duo RPC. If the
  /// response is lost after the server commit, the same local match can retry
  /// with the same [matchId] and recover the already-created session.
  Future<bool> markDuoCreationPending(String matchId) async {
    final updated =
        await (db.update(db.matches)..where(
              (match) =>
                  match.id.equals(matchId) &
                  match.duoMode.equals(true) &
                  match.duoSessionId.isNull(),
            ))
            .write(const MatchesCompanion(duoCloudStatus: Value('CREATING')));
    return updated == 1;
  }

  /// Compensating cleanup for a Duo creation that failed before the local row
  /// could be linked to a cloud session. The predicates deliberately make the
  /// delete a no-op once a session exists, so a late UI callback can never
  /// remove a valid shared match.
  Future<bool> discardUnlinkedDuoMatch(String matchId) async {
    final deleted =
        await (db.delete(db.matches)..where(
              (match) =>
                  match.id.equals(matchId) &
                  match.duoMode.equals(true) &
                  match.duoSessionId.isNull() &
                  match.status.equals(MatchStatus.inProgress.wire),
            ))
            .go();
    return deleted > 0;
  }

  Future<MatchRow?> byId(String id) =>
      (db.select(db.matches)..where((m) => m.id.equals(id))).getSingleOrNull();

  Stream<List<MatchRow>> watchRecent({int limit = 50}) =>
      (db.select(db.matches)
            ..orderBy([(m) => OrderingTerm.desc(m.startTimeMs)])
            ..limit(limit))
          .watch();

  /// Complete local history. Dashboard consumers intentionally use the
  /// bounded recent stream; the dedicated history screen must not silently
  /// hide older matches.
  Stream<List<MatchRow>> watchCompleted() =>
      (db.select(db.matches)
            ..where((match) => match.status.equals(MatchStatus.completed.wire))
            ..orderBy([
              (match) => OrderingTerm.desc(match.endTimeMs),
              (match) => OrderingTerm.desc(match.startTimeMs),
            ]))
          .watch();

  /// Every match the user may still resume, most recent first.
  /// Shared with the wearables so a paused match is a synchronised resource
  /// and not a value that only lives in the phone's memory.
  Future<List<MatchRow>> resumableMatches({int limit = 12}) =>
      (db.select(db.matches)
            ..where(
              (m) => m.status.isIn([
                MatchStatus.inProgress.wire,
                MatchStatus.paused.wire,
              ]),
            )
            ..orderBy([(m) => OrderingTerm.desc(m.startTimeMs)])
            ..limit(limit))
          .get();

  Future<MatchRow?> latestInProgress() async =>
      (db.select(db.matches)
            ..where((m) => m.status.isIn(['IN_PROGRESS', 'PAUSED']))
            ..orderBy([(m) => OrderingTerm.desc(m.startTimeMs)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<MatchEvent>> eventsFor(String matchId) async {
    final rows =
        await (db.select(db.matchEventRows)
              ..where((e) => e.matchId.equals(matchId))
              ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
            .get();
    return rows
        .map(
          (r) => MatchEvent(
            eventId: r.eventId,
            matchId: r.matchId,
            timestampMs: r.timestampMs,
            type: MatchEventType.fromWire(r.type),
            teamId: r.teamId == null ? null : TeamId.fromWire(r.teamId!),
            scoreBefore: r.scoreBefore,
            scoreAfter: r.scoreAfter,
            sourceDevice: SourceDevice.fromWire(r.sourceDevice),
            sourceMethod: SourceMethod.fromWire(r.sourceMethod),
            synced: r.synced,
            payload: r.payloadJson == null
                ? null
                : (jsonDecode(r.payloadJson!) as Map).cast<String, Object?>(),
            sourceUserId: r.sourceUserId,
            sourceTeamId: r.sourceTeamId == null
                ? null
                : TeamId.fromWire(r.sourceTeamId!),
            duoMode: r.duoMode,
            createdLocallyAtMs: r.createdLocallyAtMs,
          ),
        )
        .toList();
  }

  Future<void> appendEvents(
    String matchId,
    List<MatchEvent> events, {
    bool cloudSynced = false,
  }) async {
    if (events.isEmpty) return;
    // Transazione: maxSeq e insert devono essere atomici, altrimenti un tap
    // live concorrente con un merge dal watch produce seq duplicati e
    // l'ordine di replay diventa ambiguo.
    await db.transaction(() async {
      final maxSeq = await _maxSeq(matchId);
      await db.batch((b) {
        var seq = maxSeq;
        for (final e in events) {
          seq++;
          b.insert(
            db.matchEventRows,
            MatchEventRowsCompanion.insert(
              eventId: e.eventId,
              matchId: matchId,
              seq: seq,
              timestampMs: e.timestampMs,
              type: e.type.wire,
              teamId: Value(e.teamId?.wire),
              scoreBefore: Value(e.scoreBefore),
              scoreAfter: Value(e.scoreAfter),
              sourceDevice: Value(e.sourceDevice.wire),
              sourceMethod: Value(e.sourceMethod.wire),
              synced: Value(e.synced),
              payloadJson: Value(
                e.payload == null ? null : jsonEncode(e.payload),
              ),
              sourceUserId: Value(e.sourceUserId),
              sourceTeamId: Value(e.sourceTeamId?.wire),
              duoMode: Value(e.duoMode),
              createdLocallyAtMs: Value(e.createdLocallyAtMs),
              cloudSynced: Value(cloudSynced),
            ),
            mode: InsertMode.insertOrIgnore, // idempotent for watch re-sync
          );
        }
      });
    });
  }

  // ------------------------------------------------------------- duo sync

  /// Eventi locali non ancora sulla timeline cloud della sessione Duo.
  Future<List<MatchEventRow>> duoUnsyncedRows(String matchId) =>
      (db.select(db.matchEventRows)
            ..where(
              (e) => e.matchId.equals(matchId) & e.cloudSynced.equals(false),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
          .get();

  Future<void> markCloudSynced(String matchId, Set<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (db.update(db.matchEventRows)..where(
          (e) => e.matchId.equals(matchId) & e.eventId.isIn(eventIds.toList()),
        ))
        .write(const MatchEventRowsCompanion(cloudSynced: Value(true)));
  }

  /// Partite Duo che richiedono ancora push, pull o conferma di finalizzazione.
  /// Le righe legacy senza owner vengono adottate soltanto se il log contiene
  /// un evento già attribuito all'account corrente.
  Future<List<MatchRow>> duoSyncCandidates(
    String userId, {
    int limit = 30,
  }) async {
    final rows =
        await (db.select(db.matches)
              ..where(
                (m) =>
                    m.duoMode.equals(true) &
                    m.duoSessionId.isNotNull() &
                    (m.duoOwnerUserId.equals(userId) |
                        m.duoOwnerUserId.isNull()) &
                    (m.duoCloudStatus.isNull() |
                        m.duoCloudStatus.isNotIn(['COMPLETED', 'CANCELLED'])),
              )
              ..orderBy([(m) => OrderingTerm.desc(m.startTimeMs)])
              ..limit(limit * 2))
            .get();
    final candidates = <MatchRow>[];
    for (final row in rows) {
      if (row.duoOwnerUserId == userId) {
        candidates.add(row);
      } else {
        final attributed =
            await (db.select(db.matchEventRows)
                  ..where(
                    (event) =>
                        event.matchId.equals(row.id) &
                        event.sourceUserId.equals(userId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (attributed == null) continue;
        await markDuoOwner(row.id, userId);
        candidates.add((await byId(row.id))!);
      }
      if (candidates.length >= limit) break;
    }
    return candidates;
  }

  Future<void> markDuoOwner(String matchId, String userId) =>
      (db.update(db.matches)
            ..where((m) => m.id.equals(matchId) & m.duoOwnerUserId.isNull()))
          .write(MatchesCompanion(duoOwnerUserId: Value(userId)));

  Future<void> updateDuoCloudState(String matchId, String status) =>
      (db.update(db.matches)..where((m) => m.id.equals(matchId))).write(
        MatchesCompanion(
          duoCloudStatus: Value(status),
          duoLastSyncAtMs: Value(_nowMs()),
        ),
      );

  /// Riallinea la sequenza locale all'ordine logico autorevole del backend.
  ///
  /// Il backend ordina per timestamp locale validato e usa la sequenza di
  /// arrivo come spareggio deterministico. Entrambi i telefoni riscrivono seq
  /// secondo quell'ordine, così il replay converge allo stesso punteggio. Gli
  /// eventi solo-locali restano in coda nel loro ordine relativo.
  Future<bool> realignDuoOrder(
    String matchId,
    List<String> serverOrderedIds,
  ) async {
    if (serverOrderedIds.isEmpty) return false;
    var changed = false;
    await db.transaction(() async {
      final rows =
          await (db.select(db.matchEventRows)
                ..where((e) => e.matchId.equals(matchId))
                ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
              .get();
      final byId = {for (final r in rows) r.eventId: r};
      // Skip server IDs not present locally to avoid null in non-nullable list.
      final ordered = <MatchEventRow>[
        for (final id in serverOrderedIds) ?byId.remove(id),
      ];
      final localTail = rows.where((r) => byId.containsKey(r.eventId));
      var seq = 0;
      for (final r in [...ordered, ...localTail]) {
        seq++;
        // In regime stazionario l'ordine è già allineato: riscrivere solo i
        // seq cambiati evita N update SQLite a ogni pull della sessione Duo.
        if (r.seq == seq) continue;
        changed = true;
        await (db.update(db.matchEventRows)
              ..where((e) => e.eventId.equals(r.eventId)))
            .write(MatchEventRowsCompanion(seq: Value(seq)));
      }
    });
    return changed;
  }

  /// Merges events received from a watch.
  ///
  /// Watch-originated matches can be started standalone, before the phone has a
  /// header row. In that case the event log itself becomes the recovery source:
  /// create the missing header, insert the idempotent log, then finalize the
  /// cached summary if the received log already contains a completed match.
  Future<void> mergeSyncedEvents({
    required String matchId,
    required List<MatchEvent> events,
    MatchFormat? format,
  }) async {
    if (events.isEmpty) return;

    var row = await byId(matchId);
    if (row == null) {
      final inferredFormat = format ?? MatchFormat.goldenPointBo3;
      final startMs = events
          .map((e) => e.timestampMs)
          .reduce((a, b) => a < b ? a : b);
      await db
          .into(db.matches)
          .insert(
            MatchesCompanion.insert(
              id: matchId,
              formatJson: jsonEncode(inferredFormat.toJson()),
              status: const Value('IN_PROGRESS'),
              startTimeMs: Value(startMs),
              opponentLabel: const Value('Watch standalone'),
            ),
          );
      row = await byId(matchId);
    }

    await appendEvents(matchId, events);

    await reconcileFromEventLog(matchId);
  }

  /// Replays the durable log and reconciles the cached match header.
  ///
  /// This deliberately also runs for rows already marked COMPLETED. A delayed
  /// watch/Duo UNDO can legitimately reopen an automatically completed match;
  /// keeping the old summary in that case would make history disagree with the
  /// source-of-truth event log.
  Future<MatchReplaySnapshot?> reconcileFromEventLog(String matchId) async {
    var row = await byId(matchId);
    if (row == null) return null;
    final events = await eventsFor(matchId);
    final format = MatchFormat.fromJson(
      (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
    );
    final engine = PadelScoringEngine.replay(
      matchId: matchId,
      format: format,
      events: events,
      firstServer: row.firstServerTeam,
      duoMode: row.duoMode,
      assignedTeam: row.duoTeam == null ? null : TeamId.fromWire(row.duoTeam!),
    );

    switch (engine.state.status) {
      case MatchStatus.completed:
        if (engine.state.winner == null) {
          final endMs = normalizedMatchEndTime(
            startTimeMs: row.startTimeMs,
            eventTimestamps: engine.events.map((event) => event.timestampMs),
          );
          await (db.update(
            db.matches,
          )..where((m) => m.id.equals(matchId))).write(
            MatchesCompanion(
              status: Value(MatchStatus.abandoned.wire),
              endTimeMs: Value(endMs),
              wonByUs: const Value(null),
              summaryJson: const Value(null),
            ),
          );
        } else {
          await complete(match: row, engine: engine);
        }
        break;
      case MatchStatus.paused:
      case MatchStatus.inProgress:
        await (db.update(db.matches)..where((m) => m.id.equals(matchId))).write(
          MatchesCompanion(
            status: Value(engine.state.status.wire),
            endTimeMs: const Value(null),
            wonByUs: const Value(null),
            summaryJson: const Value(null),
          ),
        );
        break;
      case MatchStatus.abandoned:
        await setStatus(matchId, MatchStatus.abandoned);
        break;
      case MatchStatus.created:
        // Duo lifecycle events may exist before MATCH_STARTED. The header is
        // intentionally kept IN_PROGRESS so the lobby remains recoverable.
        break;
    }
    row = (await byId(matchId))!;
    return MatchReplaySnapshot(row: row, engine: engine);
  }

  Future<int> _maxSeq(String matchId) async {
    final maxSeq = db.matchEventRows.seq.max();
    final q = db.selectOnly(db.matchEventRows)
      ..addColumns([maxSeq])
      ..where(db.matchEventRows.matchId.equals(matchId));
    final row = await q.getSingle();
    return row.read(maxSeq) ?? 0;
  }

  Future<void> setStatus(String matchId, MatchStatus status) =>
      (db.update(db.matches)..where((m) => m.id.equals(matchId))).write(
        MatchesCompanion(status: Value(status.wire)),
      );

  /// Finalizes a match: computes and caches the MatchSummary from events.
  ///
  /// Duo Mode: la timeline condivisa è canonica (TEAM_A/TEAM_B decisi alla
  /// creazione), ma lo storico locale è sempre "noi vs loro" — la
  /// prospettiva è il team assegnato a questo device (duoTeam).
  Future<void> complete({
    required MatchRow match,
    required PadelScoringEngine engine,
  }) async {
    final summary = _buildSummary(match: match, engine: engine);
    await (db.update(db.matches)..where((m) => m.id.equals(match.id))).write(
      MatchesCompanion(
        status: Value(MatchStatus.completed.wire),
        endTimeMs: Value(summary.endTimeMs),
        wonByUs: Value(summary.won),
        summaryJson: Value(jsonEncode(_summaryToJson(summary))),
      ),
    );
  }

  MatchSummary _buildSummary({
    required MatchRow match,
    required PadelScoringEngine engine,
  }) {
    final myTeam = match.duoTeam == null
        ? TeamId.a
        : TeamId.fromWire(match.duoTeam!);
    final s = engine.state;
    // Fine partita = timestamp dell'ultimo evento: resta corretto anche
    // quando il match arriva in ritardo da un sync watch.
    final endMs = engine.events.isEmpty
        ? match.endTimeMs ?? _nowMs()
        : normalizedMatchEndTime(
            startTimeMs: match.startTimeMs,
            eventTimestamps: engine.events.map((event) => event.timestampMs),
          );
    final activeDurationMs = activeMatchDurationMs(
      events: engine.events,
      fallbackStartTimeMs: match.startTimeMs,
      fallbackEndTimeMs: endMs,
      nowMs: _nowMs(),
    );
    final stats = MatchStats.fromRecords(
      engine.pointRecords,
      durationMsOverride: activeDurationMs,
    );
    final us = stats.forTeam(myTeam);
    final won = s.winner == null ? match.wonByUs ?? false : s.winner == myTeam;
    final mirror = myTeam == TeamId.b;
    final advanced = AdvancedMatchAnalytics.analyze(
      records: engine.pointRecords,
      format: engine.format,
      perspectiveTeam: myTeam,
      matchWinner: s.winner,
    );
    return MatchSummary(
      matchId: match.id,
      endTimeMs: endMs,
      won: won,
      pointsFor: us.pointsWon,
      pointsAgainst: us.pointsLost,
      gamesFor: mirror
          ? s.completedSets.fold(0, (a, x) => a + x.gamesB) + s.gamesB
          : s.completedSets.fold(0, (a, x) => a + x.gamesA) + s.gamesA,
      gamesAgainst: mirror
          ? s.completedSets.fold(0, (a, x) => a + x.gamesA) + s.gamesA
          : s.completedSets.fold(0, (a, x) => a + x.gamesB) + s.gamesB,
      setsFor: mirror ? s.setsB : s.setsA,
      setsAgainst: mirror ? s.setsA : s.setsB,
      clutchScore: advanced.clutchScore == null
          ? us.clutchScore
          : (advanced.clutchScore! * 100).round(),
      bestStreak: us.bestStreak,
      durationMs: stats.durationMs,
      teamId: match.teamId,
      roleplayed: PadelRole.fromWire(match.myRole),
      opponentDifficulty: OpponentDifficulty.fromScore(
        match.opponentDifficulty,
      ),
      opponentTags: match.opponentTags.isEmpty
          ? const {}
          : match.opponentTags
                .split(',')
                .map(OpponentTag.tryFromWire)
                .whereType<OpponentTag>()
                .toSet(),
      tieBreakPointsWon: us.tieBreakPointsWon,
      tieBreakPointsPlayed: us.tieBreakPointsPlayed,
      superTieBreakPointsWon: us.superTieBreakPointsWon,
      superTieBreakPointsPlayed: us.superTieBreakPointsPlayed,
      decisivePointsWon: us.decisivePointsWon,
      decisivePointsPlayed: us.decisivePointsPlayed,
      advancedAnalysis: advanced,
    );
  }

  static Map<String, Object?> _summaryToJson(MatchSummary s) => {
    'matchId': s.matchId,
    'endTimeMs': s.endTimeMs,
    'won': s.won,
    'pointsFor': s.pointsFor,
    'pointsAgainst': s.pointsAgainst,
    'gamesFor': s.gamesFor,
    'gamesAgainst': s.gamesAgainst,
    'setsFor': s.setsFor,
    'setsAgainst': s.setsAgainst,
    'clutchScore': s.clutchScore,
    'bestStreak': s.bestStreak,
    'durationMs': s.durationMs,
    'teamId': s.teamId,
    'role': s.roleplayed.wire,
    'difficulty': s.opponentDifficulty.score,
    'tags': s.opponentTags.map((t) => t.wire).toList(),
    'tbWon': s.tieBreakPointsWon,
    'tbPlayed': s.tieBreakPointsPlayed,
    'stbWon': s.superTieBreakPointsWon,
    'stbPlayed': s.superTieBreakPointsPlayed,
    'decWon': s.decisivePointsWon,
    'decPlayed': s.decisivePointsPlayed,
    if (s.advancedAnalysis != null)
      'advancedAnalysis': s.advancedAnalysis!.toJson(),
  };

  static MatchSummary summaryFromJson(Map<String, Object?> j) => MatchSummary(
    matchId: j['matchId'] as String,
    endTimeMs: j['endTimeMs'] as int,
    won: j['won'] as bool,
    pointsFor: j['pointsFor'] as int,
    pointsAgainst: j['pointsAgainst'] as int,
    gamesFor: j['gamesFor'] as int,
    gamesAgainst: j['gamesAgainst'] as int,
    setsFor: j['setsFor'] as int,
    setsAgainst: j['setsAgainst'] as int,
    clutchScore: j['clutchScore'] as int,
    bestStreak: j['bestStreak'] as int,
    durationMs: j['durationMs'] as int,
    teamId: j['teamId'] as String?,
    roleplayed: PadelRole.fromWire(j['role'] as String? ?? 'UNDEFINED'),
    opponentDifficulty: OpponentDifficulty.fromScore(
      j['difficulty'] as int? ?? 3,
    ),
    opponentTags: (j['tags'] as List? ?? const [])
        .map((t) => OpponentTag.tryFromWire(t as String))
        .whereType<OpponentTag>()
        .toSet(),
    tieBreakPointsWon: j['tbWon'] as int? ?? 0,
    tieBreakPointsPlayed: j['tbPlayed'] as int? ?? 0,
    superTieBreakPointsWon: j['stbWon'] as int? ?? 0,
    superTieBreakPointsPlayed: j['stbPlayed'] as int? ?? 0,
    decisivePointsWon: j['decWon'] as int? ?? 0,
    decisivePointsPlayed: j['decPlayed'] as int? ?? 0,
    advancedAnalysis: j['advancedAnalysis'] is Map
        ? AdvancedMatchAnalysis.fromJson(
            (j['advancedAnalysis'] as Map).cast<String, Object?>(),
          )
        : null,
  );

  static MatchSummary? summaryOf(MatchRow row) {
    if (row.summaryJson == null) return null;
    return summaryFromJson(
      (jsonDecode(row.summaryJson!) as Map).cast<String, Object?>(),
    );
  }

  Future<List<MatchSummary>> completedSummaries() async {
    final rows =
        await (db.select(db.matches)
              ..where((m) => m.status.equals('COMPLETED'))
              ..orderBy([(m) => OrderingTerm.desc(m.endTimeMs)]))
            .get();
    final summaries = <MatchSummary>[];
    for (final row in rows) {
      var summary = summaryOf(row);
      final analysis = summary?.advancedAnalysis;
      if (summary == null ||
          analysis == null ||
          analysis.version != AdvancedMatchAnalysis.currentVersion) {
        final events = await eventsFor(row.id);
        final format = MatchFormat.fromJson(
          (jsonDecode(row.formatJson) as Map).cast<String, Object?>(),
        );
        final myTeam = row.duoTeam == null
            ? TeamId.a
            : TeamId.fromWire(row.duoTeam!);
        // Same replay parameters as reconcileFromEventLog: a Duo log replayed
        // without duoMode/assignedTeam would filter events differently.
        final engine = PadelScoringEngine.replay(
          matchId: row.id,
          format: format,
          events: events,
          firstServer: row.firstServerTeam,
          duoMode: row.duoMode,
          assignedTeam: row.duoTeam == null ? null : myTeam,
        );
        final upgraded = AdvancedMatchAnalytics.analyze(
          records: engine.pointRecords,
          format: format,
          perspectiveTeam: myTeam,
          matchWinner: engine.state.winner,
        );
        summary = summary == null
            ? _buildSummary(match: row, engine: engine)
            : summary.copyWith(
                clutchScore: upgraded.clutchScore == null
                    ? summary.clutchScore
                    : (upgraded.clutchScore! * 100).round(),
                advancedAnalysis: upgraded,
              );
        await (db.update(db.matches)..where((m) => m.id.equals(row.id))).write(
          MatchesCompanion(
            summaryJson: Value(jsonEncode(_summaryToJson(summary))),
          ),
        );
      }
      summaries.add(summary);
    }
    return summaries;
  }
}

// -------------------------------------------------------------- trainings

class TrainingRepository {
  TrainingRepository(this.db);
  final AppDatabase db;

  Stream<List<Training>> watchAll() => db.select(db.trainings).watch();

  /// Seed v1 (primo avvio) + upgrade contenuti per installazioni esistenti:
  /// i template nuovi si aggiungono con insertOrIgnore, mai sovrascrivendo.
  Future<void> ensureSeeded() async {
    await seedIfEmpty();
    final row = await (db.select(
      db.keyValues,
    )..where((k) => k.key.equals('training_seed_version'))).getSingleOrNull();
    final version = int.tryParse(row?.value ?? '') ?? 1;
    if (version < 2) {
      await db.batch(
        (b) =>
            b.insertAll(db.trainings, _v2Seed, mode: InsertMode.insertOrIgnore),
      );
      await db
          .into(db.keyValues)
          .insertOnConflictUpdate(
            KeyValuesCompanion.insert(key: 'training_seed_version', value: '2'),
          );
    }
  }

  /// Contenuti v2: riscaldamento pre-partita free + programmi premium
  /// specifici (smash, transizioni, condizionamento, pressione al servizio).
  static final _v2Seed = <TrainingsCompanion>[
    _t(
      'tr_warmup',
      'Riscaldamento pre-partita',
      'UNDEFINED',
      false,
      15,
      [
        ('Mobilità dinamica', 5, 'Caviglie, anche, spalle: mai da fermo'),
        ('Attivazione con palla', 5, 'Scambi corti a rete, ritmo crescente'),
        ('Sprint + cambio direzione', 5, '4 navette leggere, 2 al 90%'),
      ],
      'Arriva al primo game già caldo: meno errori, meno infortuni.',
    ),
    _t(
      'tr_p_smash',
      'Programma smash: decidere sopra la testa',
      'LEFT',
      true,
      40,
      [
        ('Lettura del lob', 10, 'Bandeja, vibora o smash? Chiama a voce'),
        ('Smash per 3 / per 4', 15, '5 serie per zona, precisione > potenza'),
        ('Recupero post-smash', 15, 'Torna a rete entro 2 secondi'),
      ],
      'Il punto non finisce con lo smash: finisce quando lo chiudi.',
    ),
    _t(
      'tr_p_transition',
      'Transizione difesa → attacco',
      'FLEX',
      true,
      40,
      [
        ('Lob profondo + salita', 15, 'Sali solo su lob oltre la metà campo'),
        ('Chiquita + presa di rete', 15, 'Bassa sui piedi, poi avanti'),
        ('Punto 2 vs 2 a tema', 10, 'Si parte sempre da fondo campo'),
      ],
      'I punti si vincono a rete: allena il viaggio per arrivarci.',
    ),
    _t(
      'tr_p_pressure',
      'Servizio e risposta sotto pressione',
      'UNDEFINED',
      true,
      30,
      [
        ('Servizio a bersagli', 10, 'Vetro, T, corpo: 10 per zona'),
        ('Risposta bloccata', 10, 'Blocco corto sui piedi del server'),
        ('Game secchi 0-30', 10, 'Parti sotto: rimonta o riparti'),
      ],
      'Simula lo svantaggio: il cervello impara a giocarci dentro.',
    ),
    _t(
      'tr_p_condition',
      'Condizionamento padel-specifico',
      'UNDEFINED',
      true,
      35,
      [
        ('Footwork a scaletta', 10, 'Appoggi corti, sguardo avanti'),
        ('Affondi multidirezionali', 10, '3x8 per gamba, controllo'),
        ('Core anti-rotazione', 10, 'Plank laterale + pallof press'),
        ('Scatti brevi', 5, '6x10m, recupero completo'),
      ],
      'Gambe e core reggono il quinto set: costruiscili fuori dal campo.',
    ),
  ];

  Future<void> seedIfEmpty() async {
    final count = await db.select(db.trainings).get();
    if (count.isNotEmpty) return;
    // PRD H1 free templates + H2/H3 premium per-role programs.
    final seed = <TrainingsCompanion>[
      _t(
        'tr_volee',
        'Volée di controllo',
        'UNDEFINED',
        false,
        30,
        [
          ('Volée diritto incrociata', 10, 'Punta alla riga di servizio'),
          ('Volée rovescio lungolinea', 10, 'Controllo, non potenza'),
          ('Volée alternate in coppia', 10, 'Ritmo costante'),
        ],
        'Controllo di rete: la base del padel.',
      ),
      _t(
        'tr_parete',
        'Uscita di parete',
        'UNDEFINED',
        false,
        30,
        [
          ('Uscita di fondo semplice', 10, 'Aspetta la palla, piegati'),
          ('Uscita laterale', 10, 'Spalle alla parete laterale'),
          ('Doppia parete', 10, 'Lettura anticipata'),
        ],
        'Leggere il rimbalzo e rimettere profondo.',
      ),
      _t('tr_bandeja', 'Bandeja base', 'LEFT', false, 30, [
        ('Bandeja da metà campo', 15, 'Contatto alto, palla a rientrare'),
        ('Bandeja + recupero rete', 15, 'Chiudi sempre a rete'),
      ], 'Il colpo che difende la rete.'),
      _t(
        'tr_servizio',
        'Servizio + primo colpo',
        'UNDEFINED',
        false,
        25,
        [
          ('Servizio al vetro', 10, 'Rimbalzo basso vicino al vetro'),
          ('Servizio + volée', 15, 'Sali subito dopo il servizio'),
        ],
        'Partire avanti nel punto.',
      ),
      _t(
        'tr_difesa',
        'Difesa e lob',
        'RIGHT',
        false,
        30,
        [
          ('Lob difensivo incrociato', 15, 'Altezza prima della profondità'),
          ('Recupero + contrattacco', 15, 'Riprendi la rete col lob'),
        ],
        'Ribaltare i punti dalla difesa.',
      ),
      // Premium (PRD H2/H3)
      _t(
        'tr_p_sx',
        'Programma sinistra: chiusura',
        'LEFT',
        true,
        45,
        [
          ('Smash controllato x3 zone', 15, 'Per 3, per 4, al centro'),
          ('Vibora da posizione alta', 15, 'Effetto laterale'),
          ('Gestione punto aggressivo', 15, 'Costruisci e chiudi'),
        ],
        'Settimana tipo per il giocatore di sinistra.',
      ),
      _t(
        'tr_p_dx',
        'Programma destra: regia',
        'RIGHT',
        true,
        45,
        [
          ('Uscita parete rovescio', 15, 'Blocco corto + profondo'),
          ('Lob difensivo di precisione', 15, 'Sopra il giocatore di sinistra'),
          ('Costruzione del punto', 15, 'Pazienza, cambio ritmo'),
        ],
        'Solidità e preparazione del punto.',
      ),
      _t(
        'tr_p_flex',
        'Programma flex: entrambi i lati',
        'FLEX',
        true,
        60,
        [
          ('Transizioni destra/sinistra', 20, 'Cambio lato ogni 5 punti'),
          ('Colpo neutro dal centro', 20, 'Scelta rapida'),
          ('Pattern tattici misti', 20, 'Adatta al partner'),
        ],
        'Per chi gioca ovunque.',
      ),
      _t(
        'tr_p_tb',
        'Clutch: tie-break training',
        'UNDEFINED',
        true,
        30,
        [
          ('Tie-break simulati', 20, 'Ogni punto conta doppio'),
          ('Respirazione tra i punti', 10, 'Routine pre-punto'),
        ],
        'Allena la freddezza nei momenti decisivi.',
      ),
    ];
    await db.batch((b) => b.insertAll(db.trainings, seed));
  }

  static TrainingsCompanion _t(
    String id,
    String title,
    String role,
    bool premium,
    int minutes,
    List<(String, int, String)> drills,
    String desc,
  ) => TrainingsCompanion.insert(
    id: id,
    title: title,
    description: Value(desc),
    role: Value(role),
    premium: Value(premium),
    durationMinutes: Value(minutes),
    drillsJson: Value(
      jsonEncode([
        for (final d in drills) {'name': d.$1, 'minutes': d.$2, 'note': d.$3},
      ]),
    ),
  );

  /// Template nascosto per i log delle sessioni assegnate dal coach (PRD I4):
  /// TrainingLogs richiede una FK su Trainings, ma la scheda coach vive sul
  /// cloud. Le sessioni contano così nel carico settimanale (RPE/ACWR).
  /// Escluso dalle liste template in training_screen.
  static const coachAssignedTrainingId = 'tr_coach_assigned';

  Future<void> ensureCoachAssignedTemplate() => db
      .into(db.trainings)
      .insert(
        _t(
          coachAssignedTrainingId,
          'Sessione scheda coach',
          'UNDEFINED',
          false,
          30,
          const [],
          'Registro delle sessioni assegnate dal tuo coach.',
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// [rpe] = sforzo percepito 1-10 (0 se non registrato), [minutes] = durata
  /// effettiva: alimentano il carico settimanale in training_insights.dart.
  Future<void> logCompletion(
    String trainingId, {
    String notes = '',
    int rpe = 0,
    int minutes = 0,
  }) => db
      .into(db.trainingLogs)
      .insert(
        TrainingLogsCompanion.insert(
          id: _newId('tl'),
          trainingId: trainingId,
          dateMs: _nowMs(),
          completed: const Value(true),
          notes: Value(notes),
          rpe: Value(rpe.clamp(0, 10)),
          minutes: Value(minutes.clamp(0, 600)),
        ),
      );

  Stream<List<TrainingLog>> watchLogs() => (db.select(
    db.trainingLogs,
  )..orderBy([(l) => OrderingTerm.desc(l.dateMs)])).watch();
}

// ------------------------------------------------------------- key-value

class KeyValueRepository {
  KeyValueRepository(this.db);
  final AppDatabase db;

  Future<String?> get(String key) async {
    final row = await (db.select(
      db.keyValues,
    )..where((k) => k.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) => db
      .into(db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (db.delete(db.keyValues)..where((row) => row.key.equals(key))).go();

  Stream<String?> watch(String key) => (db.select(
    db.keyValues,
  )..where((k) => k.key.equals(key))).watchSingleOrNull().map((r) => r?.value);
}
