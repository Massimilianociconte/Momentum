# Momentum Watch Module Protocol

This contract keeps Apple Watch, Wear OS, Garmin Connect IQ, Fitbit OS and
Google Health integrations aligned without forcing different platforms into a
fictional common runtime.

## Principles

- The phone/cloud remains the source of truth for user identity, subscription,
  team state, and cloud backup.
- The watch module must be able to score a match offline and retry sync later.
- Health/fitness data is opt-in, minimal, and never required for basic scoring.
- Device modules exchange structured events, not free-form text.
- Every newly-created event must have a lowercase RFC 4122 UUID v4 `eventId`
  so retries are idempotent across providers. Readers continue accepting legacy
  identifiers from app versions already in the field.

## Event Envelope

```json
{
  "protocolVersion": 2,
  "deviceFamily": "apple_watch|wear_os|garmin_connect_iq|fitbit_os|google_health",
  "deviceId": "opaque-device-id",
  "messageType": "match_started|score_event|match_completed|workout_metrics|sync_ack",
  "matchId": "mt_...",
  "eventId": "7a786f4a-5433-4b27-9b38-2f29012e4a67",
  "timestampMs": 1783375200000,
  "payload": {}
}
```

## Score Event Payload

```json
{
  "type": "POINT_TEAM_A|POINT_TEAM_B|UNDO|MATCH_PAUSED|MATCH_RESUMED|MATCH_COMPLETED",
  "sourceMethod": "TAP|VOICE|BLIND_TAP|AUTO|MANUAL_EDIT",
  "scoreBefore": "optional-json-string",
  "scoreAfter": "optional-json-string"
}
```

`teamId` is mandatory for Duo points. An `UNDO` carries `targetEventId` and may
only cancel an event emitted for the same assigned team. Events are sorted by
the canonical backend timeline; device sequence and timestamp are retained for
diagnostics, never trusted as the sole conflict-resolution key.

`MATCH_COMPLETED` with `sourceMethod: MANUAL_EDIT` is an explicit user action
from the wearable. An automatic `MATCH_COMPLETED` remains a derived audit event
and must not make an undone championship point impossible to replay.

## Start Match Command

```json
{
  "type": "START_MATCH",
  "commandId": "uuid-for-durable-provider-command",
  "matchId": "mt_...",
  "assignedTeam": "TEAM_A",
  "firstServer": "TEAM_A",
  "format": {
    "id": "STAR_POINT_BO3",
    "formatSchemaVersion": 3,
    "setsToWin": 2,
    "gamesPerSet": 6,
    "gameScoringMode": "STAR_POINT",
    "goldenPoint": false,
    "tieBreakAtGamesAll": true,
    "tieBreakPoints": 7,
    "tieBreakInDecidingSet": true,
    "superTieBreakDecider": false,
    "superTieBreakPoints": 10,
    "freePlay": false
  }
}
```

Provider commands expire, target one authenticated device token and remain in
the queue until `APPLIED` or `REJECTED`. A repeated `matchId` is idempotent.

`gameScoringMode` is the authoritative scoring discriminator in format schema
2 and accepts exactly `ADVANTAGE`, `STAR_POINT`, or `GOLDEN_POINT`.
`goldenPoint` remains on the wire for readers released before schema 2:
`true` maps to `GOLDEN_POINT`, while `false` maps to `ADVANTAGE`. A schema-2
writer serializes Star Point with `goldenPoint: false`, but that legacy field
cannot represent Star Point and must never be treated as a compatibility
mechanism. A companion must advertise
`star_point_v1` (scoring protocol version 2) before the phone dispatches a Star
Point match; silently changing the selected format is forbidden.
The native `refreshStatus` response sets `scoringCapabilityProbed: true` only
after an actual watch reply (Apple Watch) or a successful all-node capability
query (Wear OS). Persisted diagnostics never authorize a v2 dispatch.

Format schema 3 adds `tieBreakInDecidingSet` (FIP Rule 1, Option 1.4: the
deciding set can be played to two games of margin instead of a tie-break). A
reader older than schema 3 ignores the field and would open a tie-break at
6-6, so a format with `tieBreakInDecidingSet: false` requires the companion to
advertise the additive capability `deciding_set_no_tiebreak_v1` — declared as
the Wear OS capability `rallymate_scoring_v3` and in the watchOS
`scoringCapabilities` list. The scoring protocol version stays at 2: capability
tokens are additive so a phone or watch on the previous build still negotiates
Star Point. The format is not offered in the on-watch pickers, because a
watch-authored match reaches the phone without a handshake.

`firstServer` (`TEAM_A` / `TEAM_B`) carries the serving rotation of the match
(FIP Rule 4). It is a property of the match, not of the format: serve, return,
break and hold statistics all derive from it, so a companion replaying the
journal without it would attribute every hold and break to the wrong pair. It
is absent on payloads from a phone older than this protocol revision, where
`TEAM_A` is both the stored default and what that phone's engine assumed.

Wear OS reserves versioned Data Layer paths for payloads that contain Star
Point state:

- `/rallymate/v2/start_match`
- `/rallymate/v2/lifecycle`
- `/rallymate/v2/resumable`
- `/rallymate/v2/events`
- `/rallymate/v2/events_ack`
- `/rallymate/v2/request_state`
- `/rallymate/v2/state_response`

The updated companion listens to both v1 and v2 paths. A legacy companion never
receives a v2 Data Item, including one persisted before it reconnects. Because
Data Items are broadcast rather than addressed to one node, the Android phone
must prove that every installed `rallymate_scoring` node also advertises
`rallymate_scoring_v2`; mixed v1/v2 installations fail closed.
Star Point requests, events, acknowledgements and state responses stay on the
v2 lane for their entire retry cycle. Advantage and Golden Point keep their
existing v1 lanes; a response arriving on the wrong versioned lane is not an
acknowledgement and cannot clear the wearable journal.

Apple WatchConnectivity uses the same versioned paths for Star Point start,
lifecycle and resumable payloads. `transferUserInfo` and `applicationContext`
can outlive the capability probe, so a queued v2 payload must remain on its v2
path even after a watch-app downgrade. The application-context envelope stores
legacy `resumable` and `resumableV2` snapshots under separate keys: a current
watch consumes both scopes, while a schema-v1 watch enumerates only the legacy
key and ignores every v2 path.

Watch-authored Apple scoring traffic is versioned as well:

- Advantage and Golden Point retain `/rallymate/events` and
  `/rallymate/request_state`.
- Star Point uses `/rallymate/v2/events` and
  `/rallymate/v2/request_state`; both dictionaries include the exact
  schema-2 `format`, `scoringProtocolVersion: 2`, and capability
  `star_point_v1`.
- The iPhone rejects Star Point on either v1 path, rejects a non-Star format
  (or a missing v2 capability declaration) on either v2 path, and performs
  this check before writing the native event queue or invoking Dart.
- For a v2 inbound payload, `formatSchemaVersion` must be an integer between
  `2` and `1000` — schema 2 is the first that can represent Star Point and
  later schemas only add fields, while fractional or runaway values stay
  rejected as malformed — `gameScoringMode` must be `STAR_POINT`, and
  `goldenPoint` must be `false`. On the legacy lane an explicit `ADVANTAGE` requires
  `goldenPoint: false`, while an explicit `GOLDEN_POINT` requires
  `goldenPoint: true`; unknown or contradictory modes are rejected.
- A live `/rallymate/v2/events` reply is a commit acknowledgement only when
  `ok: true`, `scoringProtocolVersion >= 2`, and `star_point_v1` are all
  present. The iPhone emits it only after Dart has committed the idempotent
  event batch, as for v1. An `ok`-only reply from a schema-v1 iPhone is not a
  Star Point acknowledgement.
- A rejected, missing, or malformed v2 acknowledgement leaves every event
  pending in the watch's `LocalMatchStore` journal. The watch may additionally
  enqueue the same v2 envelope with `transferUserInfo`; retries remain safe
  because event IDs are idempotent. A schema-v1 iPhone ignores that unknown v2
  path and therefore cannot reinterpret the format as Advantage.

Every Apple `START_MATCH` dictionary includes one persisted monotonic
`startDispatchedAtMs`; its live message, queued user-info copy and
application-context copy retain the same value. The watch persists the last
accepted versioned start, ignores equal or older deliveries, and still accepts
timestamp-less legacy starts until that first versioned boundary exists.

Phone-authored lifecycle payloads carry the same `authoritySource`,
`authorityScope` and monotonic `authorityVersion` contract as resumable
snapshots. A lifecycle older than the latest accepted snapshot generation for
its scope cannot resurrect a match cleared by a newer snapshot.

The Star Point state machine follows FIP Rule 1, Option 2:

1. the first 40-40 is Deuce 1;
2. losing Advantage 1 returns to Deuce 2;
3. losing Advantage 2 returns to Deuce 3, the Star Point;
4. the next rally wins the game.

The receiving pair chooses the receiving side for the Star Point without
changing receiver positions. In a mixed match, the receiver must be the same
sex as the server. The current engine derives `deuceNumber` (0-3) entirely from
the event journal. `SCORE_EDITED` carries it explicitly because an absolute
40-40 correction would otherwise be ambiguous; a legacy edit at 40-40 starts
from Deuce 1.

## Workout Detection Preferences

The phone sends this device-local configuration through WatchConnectivity or
the Wear OS Data Layer path `/rallymate/workout_detection_preferences`:

```json
{
  "schemaVersion": 1,
  "mode": "OFF|ASK|QUICK_START",
  "racketSportsOnly": true,
  "onlyWhenWorn": false,
  "updatedAt": 1783375200000
}
```

`onlyWhenWorn` is reserved and must remain false until a provider exposes a
reliable public worn-state signal for this use. The payload contains no health
metric, location, hardware serial or account identifier.

Only Wear OS currently consumes a live external-exercise trigger. It accepts
only `OTHER_APP_IN_PROGRESS` from Health Services, deduplicates the candidate,
and presents a normal interactive notification. It never launches a screen or
starts a new exercise without a user action. `QUICK_START` changes the primary
notification action; it is not unattended match creation.

If an external exercise already owns the platform recorder, Momentum runs in
scoring-only mode. It must never supersede, adopt, pause, end or save another
app's workout. Apple Watch, Garmin and Fitbit use their provider-specific
manual/shortcut/deferred paths described in the compatibility matrix.

## Workout Metrics Payload

```json
{
  "startedAtMs": 1783375200000,
  "elapsedSeconds": 1840,
  "heartRateBpm": 142,
  "activeEnergyKcal": 245,
  "distanceMeters": null,
  "source": "healthkit|health_services|garmin_activity|google_health_api",
  "confidence": "device_reported|estimated|unavailable"
}
```

## Scoring Conformance Vectors

`wear/shared/scoring_vectors.json` is the executable contract for scoring
semantics. It is generated from the canonical Dart engine and replayed by the
platform engines step by step:

- Generator: `cd packages/momentum_core && dart run tool/generate_scoring_vectors.dart`
- Drift guard (Dart): `packages/momentum_core/test/scoring_vectors_test.dart`
  fails when the committed file no longer matches the engine.
- Runners: `ScoringVectorConformanceTest.kt` (Wear OS/JVM),
  `ScoringVectorConformanceTests.swift` (watchOS package),
  `test/scoring_vectors.test.mjs` (Fitbit OS/Node).

Canonical semantics locked by the vectors include: a point recorded in the
log always counts unless the match is completed (pause gates local input,
never synced replay), and a manual `MATCH_COMPLETED` without a team resolves
the winner by sets, then games, then free-play rallies — never by mid-game
points. Garmin has no host-side runner (Connect IQ tests need the licensed
SDK/simulator); its device app only replays self-generated logs, where these
edge cases cannot occur.

## Compatibility Matrix

| Module | Native runtime | Live scoring UI | Always On | Workout session | Cloud sync path |
| --- | --- | --- | --- | --- | --- |
| Apple Watch | watchOS + HealthKit | Yes | `isLuminanceReduced` UI + `HKWorkoutSession` | `HKWorkoutSession` + `HKLiveWorkoutBuilder` | WatchConnectivity |
| Wear OS, incl. Samsung Galaxy Watch | Android Wear + Health Services | Yes | Ambient mode + Ongoing Activity | Health Services `ExerciseClient` | Data Layer |
| Garmin | Connect IQ / Monkey C | Yes, exported targets | Firmware/user-controlled low-power behavior | Momentum-owned FIT session; Padel sub-sport on API 4.1.6+ | Connect IQ Mobile SDK to phone, then authenticated gateway |
| Fitbit Air | Google Health API | No on-device UI, screenless | Not applicable | Auto/manual activity in Google Health/Fitbit ecosystem | Google Health API OAuth |
| Fitbit OS | Fitbit SDK 4/5 legacy | Yes on listed Versa/Sense targets outside blocked regions | `display.aodActive` with `access_aod` | Manual Momentum scoring only; no cross-app start callback | Fitbit companion + authenticated gateway |
| Samsung Tizen | Retired distribution platform | No new Momentum app | Not applicable | Not applicable | Migration guidance to Wear OS only |
