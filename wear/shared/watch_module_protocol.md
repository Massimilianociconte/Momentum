# Padelandia Watch Module Protocol

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
  "protocolVersion": 1,
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
  "format": {
    "id": "ADV_BO3",
    "setsToWin": 2,
    "gamesPerSet": 6,
    "goldenPoint": false,
    "tieBreakAtGamesAll": true,
    "tieBreakPoints": 7,
    "superTieBreakDecider": false,
    "superTieBreakPoints": 10,
    "freePlay": false
  }
}
```

Provider commands expire, target one authenticated device token and remain in
the queue until `APPLIED` or `REJECTED`. A repeated `matchId` is idempotent.

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

If an external exercise already owns the platform recorder, Padelandia runs in
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

- Generator: `cd packages/rally_core && dart run tool/generate_scoring_vectors.dart`
- Drift guard (Dart): `packages/rally_core/test/scoring_vectors_test.dart`
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
| Garmin | Connect IQ / Monkey C | Yes, exported targets | Firmware/user-controlled low-power behavior | Padelandia-owned FIT session; Padel sub-sport on API 4.1.6+ | Connect IQ Mobile SDK to phone, then authenticated gateway |
| Fitbit Air | Google Health API | No on-device UI, screenless | Not applicable | Auto/manual activity in Google Health/Fitbit ecosystem | Google Health API OAuth |
| Fitbit OS | Fitbit SDK 4/5 legacy | Yes on listed Versa/Sense targets outside blocked regions | `display.aodActive` with `access_aod` | Manual Padelandia scoring only; no cross-app start callback | Fitbit companion + authenticated gateway |
| Samsung Tizen | Retired distribution platform | No new Padelandia app | Not applicable | Not applicable | Migration guidance to Wear OS only |
