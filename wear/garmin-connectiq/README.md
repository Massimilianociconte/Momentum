# Padelandia Garmin Connect IQ

Native Connect IQ watch app, built with Monkey C and isolated from Flutter,
watchOS and Wear OS. The implementation follows the shared event contract in
`../shared/watch_module_protocol.md`.

## Implemented

- Offline-first scoring with stable event IDs, event replay and explicit ACKs.
- Advantage, Golden Point, tie-break, super tie-break, single-set and free-play
  formats.
- Duo assignment: one Garmin may score only its assigned team; undo is scoped to
  that team.
- Persistent pending queue. Transport completion never deletes an event; only a
  phone/backend ACK does.
- Touch and hardware-button controls, high-contrast score UI and haptic feedback.
- Responsive Padelandia visual system for round AMOLED, rectangular and compact
  MIP/Instinct displays, with one geometry source shared by rendering and hit
  testing.
- English and Italian UI resources, visible score actions, advantage state,
  team-scoped undo and non-invasive local/sync status.
- Native Connect IQ action menu for watch-first format selection, pause/resume,
  explicit sync and manual match completion with a separate confirmation.
- A match started in Padelandia owns a native FIT recording. It uses Tennis with
  Padel sub-sport on Connect IQ API 4.1.6+ and a generic sub-sport fallback on
  older declared products.
- Existing Garmin activities are never adopted, stopped or replaced. When the
  system timer is already active, Padelandia stays in scoring-only mode and
  shows a short local notice.
- FIT-session ownership is persisted by match ID and activity start time, so a
  restart can recover only the session Padelandia can prove it created.
- A Garmin system suspension (`onStop` with `:suspend`) preserves that owned
  session for resume; a real app exit stops and saves it once, leaving the match
  resumable without keeping the activity/app alive or silently restarting it.
- Lifecycle events are persisted before transport and replayed after restart;
  scoring is disabled while paused and manual completion remains queued offline.
- `PING`, `TEST_POINT`, `REQUEST_STATE` and `START_MATCH` phone commands.
- Native iOS and Android bridges using Garmin's official Connect IQ Mobile SDK.
- 95 explicit product profiles in `manifest.xml`, covering compatible Approach,
  D2/Descent, Enduro, epix, fenix, Forerunner, Instinct, MARQ, Venu and
  vivoactive families from Connect IQ API 2.4 onward.

The module requests `Communications` and `Fit`. It does not register a GPS or
high-rate sensor listener: the native Garmin recorder owns FIT timing and any
device-managed activity data. Scoring remains usable if recording is
unavailable or another activity is active. Garmin firmware and user settings
control low-power/always-on behavior; a Connect IQ app must not promise to
force the display permanently on.

Connect IQ does not expose a background **activity started** event. Padelandia
therefore cannot prompt at the instant another Garmin app starts an activity;
the documented background event is activity completion. The supported flow is
to open Padelandia and use Quick Start, which starts scoring and its own FIT
session together.

## Build And Test

Supported local toolchain: Connect IQ SDK 9.2.0 and JDK 17.

```bash
export GARMIN_CONNECTIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0"
export GARMIN_DEVELOPER_KEY="$HOME/.config/rallymate/garmin/developer_key.der"
wear/garmin-connectiq/scripts/build.sh venu3
wear/garmin-connectiq/scripts/test.sh venu3
wear/garmin-connectiq/scripts/validate_matrix.sh
wear/garmin-connectiq/scripts/export.sh
```

`scripts/build.sh` treats warnings as errors and enables release optimization.
`scripts/test.sh` compiles the unit-test binary and launches Garmin's simulator.
The test binary can be compiled headlessly in CI, but execution through
`monkeydo` requires an interactive Connect IQ simulator. Final acceptance also
requires at least one physical target watch paired through Garmin Connect.

Current local validation:

- 95/95 declared profiles compile with SDK 9.2.0.
- 20/20 Run No Evil tests pass in the current Venu 3 run,
  including pause/resume/manual completion and touch-menu routing.
- Touch hit zones, Duo assignment and visible undo are covered by unit tests.
- The signed `.iq` export builds 162 device/language/part variants and contains
  the required manifest and signature.
- Final visual acceptance of the current UI must still be repeated in the
  interactive simulator and on physical AMOLED, MIP and rectangular hardware.
- Android Mobile SDK 2.4.0 reaches the simulator through ADB, reports
  `CONNECTED`, registers the Padelandia Connect IQ app and accepts phone-to-watch
  transport with `SUCCESS`.

## Mobile SDK

- Android: `com.garmin.connectiq:ciq-companion-app-sdk:2.4.0@aar`.
- iOS: Garmin Swift Package `connectiq-companion-app-sdk-ios`, exact 1.8.0.
- iOS callback URLs are accepted only from Garmin Connect's bundle identifier.
- Garmin native device IDs stay on the phone. Cloud ingestion uses a revocable,
  hashed Padelandia device credential and server-side plan verification.

For an Android simulator bridge, install a debug APK and run:

```bash
adb forward tcp:7381 tcp:7381
adb shell am start -S \
  --ez rallymate_garmin_tethered true \
  -n com.rallymate.rallymate/.MainActivity
```

Then use **adb Connection > Start** in the Connect IQ simulator. Production
builds cannot enable `TETHERED`; they always use Garmin Connect Mobile through
`WIRELESS`. An additional debug-only `rallymate_garmin_smoke_test=true` extra
registers the simulator app and sends a PING. With SDK 9.2.0 the simulator may
close its ADB socket after an otherwise successful Android-to-watch send; this
is a simulator limitation also reproduced by current Garmin sample users, so a
physical Garmin remains the release gate for bidirectional PING/PONG.

## CI Secrets

The repository CI always validates the manifest and source layout. Licensed
compilation is enabled by repository secrets:

```text
GARMIN_CONNECTIQ_SDK_ARCHIVE_URL   Private HTTPS ZIP containing the SDK
GARMIN_DEVELOPER_KEY_BASE64        Base64-encoded developer_key.der
```

Never commit the SDK archive or developer key.

## Publication Checklist

1. Confirm product targets against the current Connect IQ device reference.
2. Run app and tests for every exported product family, then test real hardware.
3. Create the Connect IQ Store listing, support URL, privacy URL, icon and
   screenshots using the same application UUID as `manifest.xml`. Prepared
   assets live in `docs/store-assets/garmin` (500x500 icon and 1440x720 hero).
4. Verify reconnect, offline queue, duplicate delivery, Duo assignment and undo.
5. Do not advertise public Garmin support until Garmin approves the listing.

Official references:
- https://developer.garmin.com/connect-iq/
- https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html
- https://developer.garmin.com/connect-iq/core-topics/activity-recording/
- https://developer.garmin.com/connect-iq/core-topics/backgrounding/
- https://developer.garmin.com/connect-iq/core-topics/communicating-with-mobile-apps/
- https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/
- https://developer.garmin.com/connect-iq/core-topics/unit-testing/
