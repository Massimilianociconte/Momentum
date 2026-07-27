# Momentum Wearable Workout Start Detection

Verified against official platform documentation on 13 July 2026. This file is
the product and engineering contract for the optional workout-start prompt. It
does not infer capabilities from marketing names and does not treat delayed
health synchronization as a live wearable callback.

## Decision Matrix

| Platform | Conclusion | Public APIs used | Minimum / compatible targets | Allowed behavior | Not supported / prohibited | Permissions | Offline and battery profile | Momentum implementation and fallback |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Apple Watch | **Implementable only when Momentum starts the workout.** No public live interception of a workout started by Apple Workout or another app. | `StartWorkoutIntent`, App Shortcuts, `HKWorkoutSession`, `HKLiveWorkoutBuilder`, HealthKit observer queries only for saved samples | Momentum deployment target watchOS 10+. `StartWorkoutIntent` exists from watchOS 9. Action Button path is Apple Watch Ultra only; app/Siri shortcut works on supported watchOS devices. | User invokes Momentum, Siri/shortcut or Action Button; Momentum opens, creates the match locally and starts its own HealthKit workout. | No cross-app current-workout callback; no forced launch; no parallel session over another active workout; no claim that `.other` is a native Padel type. | HealthKit read/write types already declared; explicit authorization. Notifications only if separately used. | Match journal is fully offline. HealthKit owns workout execution. No polling. If HealthKit is unavailable/busy, scoring continues without health metrics. | Implemented `StartRallyMateWorkoutIntent` with last format, advantages, Golden Point and training. The request is consumed once and starts the normal offline-first flow. Manual New Match remains the fallback. |
| Wear OS | **Live detection and notification are implementable when the source exposes the exercise through Health Services.** Not guaranteed for every OEM/source app. | Health Services `PassiveMonitoringClient`, `PassiveListenerService`, `ExerciseClient.getCurrentExerciseInfoAsync`, Tile/notification patterns, own `ExerciseClient` session | Wear OS 3+ with Health Services; Momentum min SDK 30. Includes compatible Galaxy Watch4+, Pixel Watch and other Wear OS 3+ products after runtime capability check. Model name alone is not sufficient. | Event-driven `OTHER_APP_IN_PROGRESS` detection; normal interactive notification; explicit actions: Quick Start, Configure, Ignore. Momentum may start its own exercise only when no other app owns one. | No auto-open/full-screen takeover; no polling; no continuous microphone/location; no superseding an external exercise; no guarantee that Google Fit, Fitbit, Samsung Health or every OEM publishes current state. | `ACTIVITY_RECOGNITION`; `POST_NOTIFICATIONS` where required. Health permissions are requested separately only for Momentum's own workout metrics. | Passive callback plus one foreground inspection, no periodic worker. Match and score journal remain offline. Sync uses UUID/idempotency and radio backoff. | Implemented. Optional modes: Off, Ask, Quick Start. Racket-only filter accepts Tennis, Badminton, Squash, Racquetball and Table Tennis because Health Services has no Padel type. Any external exercise keeps Momentum in scoring-only mode. |
| Garmin Connect IQ | **Not implementable for an external activity start with public APIs. Implementable as a Momentum-owned sport app.** | `Activity.getActivityInfo`, `ActivityRecording.createSession`, `Session.start/stop/save`; documented background Activity Completed event | Connect IQ min API 2.4 and the exact products declared in `wear/garmin-connectiq/manifest.xml`. FIT recording is compiled per target. Padel sub-sport is used only on API 4.1.6+; older targets use Tennis + generic sub-sport. | User opens Momentum and starts/quick-starts a match; scoring and a native FIT session begin together. At foreground entry Momentum may identify that the system timer is already busy. | No background Activity Started event; no automatic prompt while another app is foreground; never adopt/stop/save another app's singleton recording session; no universal model claim outside the manifest. | Connect IQ `Fit` and `Communications`. No GPS or high-rate sensor permission/listener added for detection. | FIT recorder is event/lifecycle driven. Match journal remains offline. Session ownership is persisted with match ID and start time; sync keeps exponential backoff. | Implemented native FIT ownership, pause/resume, automatic/manual completion and crash recovery. If another activity exists, a local notice is shown and scoring proceeds without a Momentum FIT session. |
| Pixel Watch / Fitbit on Wear OS | **Same as Wear OS.** | Wear OS Health Services | Pixel Watch generations running supported Wear OS/Health Services | Same notification and explicit-start path as Wear OS. | Fitbit branding does not create a separate Fitbit OS callback. | Same as Wear OS. | Same as Wear OS. | Uses `wear/wearos`; no duplicate Fitbit implementation. |
| Fitbit OS proprietary | **No public live cross-app trigger. Available only on some legacy devices/regions.** | Fitbit SDK app/companion lifecycle and manual app launch | Momentum binaries target Fitbit OS 5 Versa 3/Sense and separate OS 4 legacy targets. Google removed third-party app installation in the EEA in June 2024, so this is not an Italian production path. | Manual/quick start inside the Momentum Fitbit app where provider distribution is still available. | No external exercise-start callback; no Italian/EEA installability claim; no support claim for Sense 2/Versa 4 or devices without the third-party runtime. | Existing AOD, Internet and background permissions only; no health sensor permission for detection. | Offline score journal and companion queue. No detection loop or new background timer. | Existing manual wearable-first flow retained for legacy/private/non-EEA use. Mobile UI explains the limitation. |
| Fitbit Air / screenless Fitbit trackers | **No on-device prompt or app UI. Detection is delayed only.** | Google Health API on the backend/phone after provider sync | Devices exposed to the Google Health account; Fitbit Air is screenless. | With separate Pro OAuth consent, Momentum can later refresh allowed daily aggregates and may show a non-live suggestion on the phone. | No wearable app, notification action, score UI or real-time activity-start callback. Do not label delayed API data as automatic live detection. | Google OAuth read scopes; no wearable permission. | Provider-controlled sync latency; no watch workload. | Google Health integration remains health-summary only. Pixel Watch follows Wear OS instead. |

## Trigger Policy

The live Wear OS prompt is eligible only when all of the following are true:

1. the user explicitly selected Ask or Quick Start;
2. `ACTIVITY_RECOGNITION` and notification access are available;
3. Health Services reports `OTHER_APP_IN_PROGRESS`;
4. no Momentum match is already active;
5. the same source/type/time fingerprint was not handled or ignored;
6. if racket-only is enabled, the documented exercise type is in the validated
   racket whitelist.

No heart rate, location, calendar event, club geofence, advertising identifier
or undocumented worn-state heuristic participates in the trigger. This is
deliberately more conservative than probabilistic motion classification and
prevents invasive false positives.

Quick Start still requires one explicit notification tap. It selects the last
valid format and creates the match locally before attempting any network or
phone communication. Configure opens the wearable New Match flow. Ignore is
scoped to that activity fingerprint.

## Session Ownership And Conflict Safety

- A provider permits only one active workout recorder. Momentum checks the
  current owner before starting its own session.
- Wear OS `OTHER_APP_IN_PROGRESS` and Garmin's active timer always force
  scoring-only mode.
- Garmin ownership recovery requires both the same Momentum `matchId` and an
  activity start timestamp within ten seconds. Ambiguous evidence fails closed.
- Apple HealthKit errors or an already active workout never block scoring.
- Match events are committed locally before sync. Every event retains a UUID,
  source device, timestamp and logical sequence; retries do not create a new
  match or point.

## User Controls And Privacy

The mobile Devices screen contains the optional modes Off, Ask and Quick Start
for the only live-capable path, Wear OS. Unsupported platforms display their
real manual/shortcut/delayed behavior and keep the automatic controls disabled.
The racket-only filter is local. The reserved `onlyWhenWorn` field remains
disabled because there is no uniform public signal reliable enough across the
supported providers.

The preferences payload contains only mode, racket filter, disabled worn flag,
schema version and update time. It travels through the local WatchConnectivity
or Wear OS Data Layer bridge and contains no account, health metric or location.

## Store And Provider Review Notes

- Apple: explain in review notes that Momentum starts its own HealthKit workout
  only after a user action; it does not monitor other apps or force navigation.
- Google Play: declare physical activity/Health Services permissions and the
  exact core feature; the prompt uses a normal notification and remains useful
  when notification permission is denied through manual New Match.
- Garmin: the Connect IQ listing must disclose `Fit`, activity recording and
  the fallback on older API targets. Complete physical-watch QA before claims.
- Fitbit: do not list proprietary Fitbit OS availability in Italy/EEA. Google
  Health OAuth and health summaries are a separate consented feature.

## Official Sources

### Apple

- <https://developer.apple.com/documentation/appintents/startworkoutintent>
- <https://developer.apple.com/documentation/healthkit/hkworkoutsession>
- <https://developer.apple.com/documentation/healthkit/hkworkout>
- <https://developer.apple.com/documentation/healthkit/executing-observer-queries>
- <https://developer.apple.com/documentation/workoutkit>
- <https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks>
- <https://developer.apple.com/app-store/review/guidelines/>

### Google / Wear OS

- <https://developer.android.com/health-and-fitness/health-services>
- <https://developer.android.com/reference/androidx/health/services/client/ExerciseClient>
- <https://developer.android.com/reference/androidx/health/services/client/PassiveMonitoringClient>
- <https://developer.android.com/reference/androidx/health/services/client/PassiveListenerService>
- <https://developer.android.com/reference/androidx/health/services/client/data/ExerciseType>
- <https://developer.android.com/health-and-fitness/health-services/permissions>
- <https://developer.android.com/health-and-fitness/health-services/active-data>
- <https://developer.android.com/training/wearables/notifications>

### Garmin

- <https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>
- <https://developer.garmin.com/connect-iq/core-topics/backgrounding/>
- <https://developer.garmin.com/connect-iq/core-topics/activity-recording/>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html>
- <https://developer.garmin.com/connect-iq/compatible-devices/>

### Fitbit / Google Health

- <https://support.google.com/googlehealth/answer/14237121>
- <https://support.google.com/googlehealth/thread/437070658/introducing-the-next-phase-of-the-fitbit-web-api>
- <https://developers.google.com/health>
- <https://developers.google.com/health/policies/health-api-developer-user-data-policy>

## Remaining Physical Acceptance

Simulator/unit builds validate policy, storage, idempotency, layout and compile
availability, but cannot prove OEM interoperability or actual battery impact.
Before a public claim, run these physical tests:

- Apple Watch: shortcut/Siri start, Health permission denied/granted, another
  workout already active, phone absent, completion and recovery.
- Galaxy Watch and Pixel Watch: external exercise from every claimed source,
  notification denied, duplicate callbacks, source not exposing Health
  Services, offline quick start and 90-minute battery trace.
- Garmin: AMOLED and MIP targets, another activity active, process restart while
  recording/paused, FIT save and Garmin Connect appearance.
- Fitbit OS only in a provider-supported test region/device; Fitbit Air only as
  delayed Google Health data with no wearable prompt claim.
