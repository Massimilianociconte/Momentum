# Momentum wearable power audit - 12 July 2026

## Scope and non-negotiable behavior

This pass reduces display, CPU, storage and radio wake-ups without delaying the
local scoring path. A point still follows this order:

1. update the deterministic scoring engine;
2. commit the event to local durable storage;
3. update UI and haptics;
4. synchronize pending events on a best-effort, idempotent path.

Network coalescing therefore cannot lose a point or make the score feel slower.

## Official platform guidance used

### Apple Watch

- Apple says the Always On state updates at a much lower rate and recommends
  system-managed date styles for timers. Momentum now uses `Text(...,
  style: .timer)` and a reduced-luminance score surface instead of a 1 Hz
  application timeline.
- Wrist-down is an `inactive` transition before the app is actually backgrounded.
  Momentum persists locally on inactive and performs a radio retry only on a
  true background or active/reconnected transition.
- A real match uses `HKWorkoutSession`; it is not emulated with a generic
  extended runtime session. HealthKit callbacks are rendered at most every five
  seconds while the system continues collecting at its appropriate cadence.
- Team/profile images are downsampled to a 256 px envelope before reaching the
  SwiftUI tree.

Sources:

- <https://developer.apple.com/documentation/watchOS-Apps/designing-your-app-for-the-always-on-state>
- <https://developer.apple.com/documentation/watchkit/background-execution>
- <https://developer.apple.com/documentation/HealthKit/HKWorkoutSession>
- <https://developer.apple.com/videos/play/wwdc2025/226/>

### Wear OS, Pixel Watch and Galaxy Watch

- Ambient mode now has a separate mostly-black score-only surface. It omits
  buttons, imagery, branding and sync work.
- No manual wake lock is requested. The active workout uses Health Services and
  Ongoing Activity, which allow the CPU to sleep between system callbacks.
- Phone node discovery is cached and backs off from 2 to 30 seconds when the
  phone is absent. A user point still commits immediately and a connection
  event/foreground transition retries the queue.
- Only pending event IDs are transmitted; already acknowledged history is not
  resent on every point.
- Team images are sampled into a small RGB565 bitmap before Compose renders
  them.
- Health Services capabilities are fetched once when starting the workout, and
  the callback is cleared when the service ends.

Momentum intentionally keeps the cross-vendor Health Services implementation
for heart rate and calories. Samsung Health Sensor SDK is appropriate only when
raw or Samsung-exclusive BioActive data is required. Adding it for the same
heart-rate value would duplicate listeners and reduce compatibility. If a future
feature needs raw PPG/ECG/IBI, use Samsung batching and always unset listeners
and disconnect the service.

Sources:

- <https://developer.android.com/training/wearables/always-on>
- <https://developer.android.com/training/wearables/apps/power>
- <https://developer.android.com/training/wearables/principles>
- <https://developer.android.com/health-and-fitness/health-services>
- <https://developer.samsung.com/health/sensor/overview.html>
- <https://developer.samsung.com/health/sensor/guide/getting-started.html>

### Garmin Connect IQ

- The device app has no explicit GPS or high-rate sensor listener and redraws
  only after model/user events. A user-started match now owns one native FIT
  recording session; Garmin's recorder handles its lifecycle without polling.
- A pre-existing activity forces scoring-only mode. Momentum never acquires
  the singleton recording object unless persisted match ID and start time prove
  ownership.
- Transport retries now use 5, 15, 30, 60 and 120 second intervals instead of a
  permanent 5 second timer. ACK or explicit user activity resets the backoff.
- The timer is stopped during app shutdown. Events remain locally pending until
  an explicit ACK, not merely a transport-complete callback.
- Compact titles are geometrically centered and footer actions have equal width,
  improving 176 px and other small layouts without adding bitmaps or animation.

Garmin background temporal events are not used for live start detection or
scoring: the official API exposes Activity Completed but no Activity Started
event, and background services have limited execution windows. Community
battery reports reinforce the need to stop timers/listeners on exit, but
community posts are treated as test signals, not as API contracts.

Sources:

- <https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>
- <https://developer.garmin.com/connect-iq/core-topics/activity-recording/>
- <https://developer.garmin.com/connect-iq/core-topics/backgrounding/>
- <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-create-a-connect-iq-background-service/>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/System/ServiceDelegate.html>
- <https://forums.garmin.com/developer/connect-iq/f/showcase/430196/battery-drain-tester-app>
- <https://forums.garmin.com/developer/connect-iq/f/discussion/872/battery-drain-when-connectiq-app-is-not-running/1731716>

### Fitbit OS and Google Fitbit Air

- The legacy Fitbit OS device app no longer runs an unconditional 30 second
  timer. It retries only with pending data, an open peer socket and an active
  non-AOD display.
- In AOD it shows only score, set/game and the relevant deuce/advantage state on
  black; controls, team fills, sync and branding are hidden.
- Companion background wake is five minutes only during an active match or with
  pending events, and 30 minutes while idle. The companion queue is persisted.
- This remains a Fitbit OS module for Versa 3 and Sense targets. It must not be
  presented as a native app for devices that do not run third-party Fitbit OS
  apps.
- Google Fitbit Air is officially screenless and syncs through the Google Health
  phone app. It cannot host Momentum scoring UI. Momentum can consume allowed
  health data through the phone integration, but there is no Air-side app loop,
  AOD, title layout or battery workload to optimize.

Sources:

- <https://dev.fitbit.com/static/publishing-checklist.pdf>
- <https://store.google.com/us/product/google_fitbit_air_specs>
- <https://support.google.com/googlehealth/answer/17033101>

## Small-screen visual rules

- watchOS navigation titles use a centered overlay with equal 34 pt leading and
  trailing footprints. The score header gives equal width to sensor and sync
  columns, so the score cannot drift horizontally.
- Wear OS titles use a full-width centered layer with the back action overlaid at
  the start edge.
- Garmin headings and footer controls are centered from the display geometry,
  not from neighboring label widths.
- Fitbit headings use the fixed center axis and AOD hides all nonessential text.
- Text can scale down within bounded lines, while primary actions keep their
  touch target. No viewport-scaled font formulas are used.

## Verification protocol

Build/simulator checks validate behavior and rendering, but cannot prove a
battery percentage improvement. Release acceptance requires physical traces.

### Apple Watch physical test

1. Install a Profile/Release build, charge to at least 80%, and disable unrelated
   third-party workouts.
2. Record a 90 minute match with the same AOD and heart-rate settings before and
   after the change.
3. Capture Xcode Instruments Power Profiler and SwiftUI updates, including 15
   minutes wrist-up, 60 minutes wrist-down and 15 minutes mixed interaction.
4. Verify no 1 Hz Momentum timer, no repeated `WCSession` retry on every
   inactive transition, and no workout left active after finish.

### Wear OS physical test

1. Reset batterystats before a repeatable 90 minute match:
   `adb shell dumpsys batterystats --reset`.
2. Exercise interactive, ambient, phone-near and phone-absent phases.
3. Inspect `adb shell dumpsys batterystats com.rallymate.rallymate`, Perfetto,
   wakelocks and Health Services state.
4. Verify at least 85% black pixels in ambient screenshots and no manual
   Momentum wake lock.

### Garmin physical test

1. Use the same firmware, brightness and activity settings for baseline and new
   builds.
2. Run a 90 minute scoring session plus a two-hour post-exit observation.
3. Record battery percent/hour and verify the retry cadence with phone absent.
4. Confirm no callback or timer fires after clean app shutdown.

### Fitbit OS physical test

1. Run identical 90 minute sessions on each supported physical target.
2. Compare normal, AOD and peer-disconnected phases.
3. Confirm the device timer stops when the display turns off and the companion
   uses the idle 30 minute interval after match completion/ACK.

## Residual limits

- Simulator and compiler success do not measure battery chemistry, radio quality,
  firmware regressions, thermal state or display hardware.
- Exact percent/hour targets must be baselined per model and firmware; one number
  is not credible across Apple Watch SE/Ultra, AMOLED/MIP Garmin, Galaxy/Pixel
  Watch and legacy Fitbit devices.
- OS-managed heart-rate sampling is intentionally not reduced below the workout
  service's policy. Momentum only reduces UI publication frequency.
