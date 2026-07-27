# Momentum Wearable Implementation Report

Date: 12 July 2026

## Executive Result

Momentum now has separate, native and testable implementations for Apple
Watch, Wear OS, Garmin Connect IQ and Fitbit OS, plus a server-side Google
Health integration for Fitbit Air and other screenless health sources.

Samsung Tizen is deliberately not shipped: Samsung no longer accepts new or
updated Tizen watch apps. The mobile compatibility catalog and onboarding mark
it as retired and guide users to Galaxy Watch4 or later with Wear OS.

No statement in the app claims that Fitbit Air can display scoring controls or
that Tizen can be newly published.

## Garmin Connect IQ

Implemented in `wear/garmin-connectiq`:

- Monkey C watch app for 95 explicitly declared Connect IQ product profiles.
- Offline event-sourced scoring and persistent pending queue.
- Advantage, Golden Point, tie-break, super tie-break, single-set and free-play.
- Assigned-team Duo Mode and team-scoped undo.
- Touch, hardware buttons, haptics, high-contrast score and low-power-safe UI.
- Native action menu for watch-first format selection, pause/resume, explicit
  sync and manual finish with a separate confirmation.
- Premium responsive visual system for AMOLED, compact MIP/Instinct and
  rectangular displays, with Italian/English resources and shared draw/hit-test
  geometry.
- Explicit ACK protocol: transport success alone never deletes a score event.
- PING, test haptic, state request and start-match commands.
- Official Connect IQ Mobile SDK bridges in Android and iOS.
- Server ingestion with JWT/plan verification, idempotency and cloud inbox ACK.

Verified:

- SDK 9.2.0 `monkeyc` app build: passed.
- SDK 9.2.0 unit-test binary compilation: passed.
- iOS simulator build with Garmin Swift Package 1.8.0: passed.
- Android APK build with Garmin companion SDK 2.4.0: passed.
- Full 95-profile build matrix: passed.
- Current Run No Evil suites: 15/15 on Venu 3 and 15/15 on Instinct 2,
  including pause/resume/manual finish and touch-menu routing.
- Signed Connect IQ export: 162/162 device/language/part variants, manifest and
  signature verified; store icon and hero assets prepared.
- Interactive UI QA of the current redesign is pending because the macOS UI
  session was locked. The previous UI had been inspected, but that receipt is
  deliberately not reused for the redesigned screen.
- Pixel 10 Pro ADB bridge: SDK ready in TETHERED mode, simulator CONNECTED,
  Momentum app registered and PING accepted with transport status SUCCESS.
- Final Android debug APK installed successfully on the USB-connected Pixel 10
  Pro. Garmin Connect and Connect IQ were present and authenticated; no physical
  Garmin watch was paired, so hardware PING/PONG acceptance remains pending.

Not falsely marked as complete:

- Connect IQ SDK 9.2.0 closed the simulator ADB socket after a successful
  Android-to-watch send, before returning PONG. The bridge now keeps TETHERED
  socket I/O off the Android main thread and handles late CONNECTED callbacks,
  but bidirectional release acceptance still requires a physical Garmin paired
  through Garmin Connect.

## Fitbit OS

Implemented in `wear/fitbit-os`:

- Separate Fitbit OS 5 and OS 4 binaries in the same source tree.
- Supported listed devices: Versa 3/Sense (OS 5) and Versa, Versa Lite,
  Versa 2 (OS 4).
- Offline deterministic scoring, persistent outbox, duplicate protection,
  assigned-team Duo and scoped undo.
- Wearable-first format selection, persistent event-sourced undo,
  pause/resume, explicit completion confirmation and completed-match Home/New
  navigation.
- PeerSocket batching measured below the official 1027-byte serialized limit.
- One-time ten-minute pairing code and revocable scoped device token.
- Plus entitlement rechecked server-side for pairing, ingestion and commands.
- Durable token-targeted `START_MATCH` queue with expiry and watch ACK.
- Always-On handling, haptics and a clear first-install paid/subscription notice.
- Transparent 80x80 Gallery icon accepted by the pinned OS 4/5 SDK.

Verified:

- Node scoring/protocol tests: 11 passed.
- Fitbit OS 5 build: passed, `build/app.fba`.
- Fitbit OS 4 build: passed, `build/rallymate-fitbit-os4.fba`.
- Production dependency audit: 0 vulnerabilities.
- Release endpoint validation rejects localhost/example/empty endpoints.

Provider limitation:

- Fitbit Developer Bridge requires OAuth login and a Fitbit OS device linked to
  the developer account. Fitbit also requires real-device validation before
  Gallery publication. Build success is not represented as that acceptance.

## Fitbit Air And Google Health

Implemented in Supabase Edge Functions and Flutter:

- Screenless Fitbit Air is health-only; scoring dispatch rejects it.
- Pro-only Google OAuth with read-only activity/fitness and health-measurement
  scopes.
- Access and refresh tokens encrypted server-side with AES-256-GCM and
  per-user authenticated data.
- Civil-day rollups from 00:00 to the following 00:00, never a rolling 24-hour
  query.
- Steps, active energy, active minutes and optional average heart rate.
- Active-app refresh every 15 minutes and a signed/idempotent webhook path.
- Maximum 30-day aggregate retention.
- Disconnect revokes Google, destroys token material and deletes summaries.
- Health data is excluded from ads, social ranking and AI context.

Verified:

- Deno format, lint and typecheck: passed.
- Civil-day boundary tests: 3 passed, including month/year/leap-day rollover.
- Privacy policies, Store Compliance and Apple Privacy Manifest now distinguish
  local HealthKit/Health Connect from server-side opt-in Google Health.

External requirements:

- Google Cloud OAuth consent and Google Health project approval.
- Independent security assessment before scaling beyond 100 users.
- Public privacy/terms URLs and exact OAuth redirect URI.

## Tizen

`wear/tizen-retired/README.md` is the authoritative module status. No legacy
SAP/Tizen package was created because it could not be registered or updated.

The app provides a real onboarding state with:

- retired-platform explanation;
- no fake pairing or connection test;
- no scoring/Duo readiness;
- migration guidance to Wear OS Galaxy Watch.

## Mobile UX And Dispatch

- A seven-step provider-aware setup flow detects iOS/Android locally.
- Garmin, Fitbit OS, Google Health, Apple Watch, Wear OS and retired Tizen have
  different instructions and diagnostics.
- Device registry supports status, last contact/sync, rename, default device,
  reconnect and revoke/remove.
- Homepage and Duo Mode now consider ready Garmin/Fitbit devices as watches.
- Health-only or retired providers can never satisfy scoring readiness.
- A health-only default device can no longer intercept a match intended for a
  scoring-capable wearable.
- iPhone Simulator QA covered the device list and all four provider-specific
  paths with no overflow or dead navigation.
- Apple Watch Series 11 Simulator QA covered launch, score tap and undo.
- Apple Watch 40 mm and 42 mm simulator QA covered wearable-first start,
  scoring, deuce/advantage, split Noi/Loro, pause, finish confirmation,
  completed state and offline queued state.

## Apple Physical Delivery

Verified on 12 July 2026:

- Signed iPhone device bundle passed strict nested code-signature validation.
- `Runner.app` embeds `RallyMateWatchApp.app` in its `Watch` directory.
- The phone bundle is `com.rallymate.rallymate`; the watch bundle is
  `com.rallymate.rallymate.watchkitapp`; `WKCompanionAppBundleIdentifier`
  correctly points back to the phone bundle.
- The watch UI now prioritizes the current score, separates Set/Game metadata,
  exposes explicit sync state, uses visible high-contrast Noi/Loro controls and
  contains no inactive circular-arrow action.
- A match can be created, paused, resumed, terminated and recovered entirely on
  the Watch. Local persistence happens before WatchConnectivity; pending
  matches remain discoverable even after leaving the completed screen.
- Voice commands use short deterministic phrases (`Noi`, `Loro`, `Team A`,
  `Team B`, `Annulla`, `Pausa`, `Riprendi`, `Termina partita`) and destructive
  or low-confidence commands require confirmation.
- The Profile iPhone bundle contains no Debug kernel asset and launches from
  the Home screen without Flutter tooling, resolving the iOS 14+ Debug launch
  warning shown in the supplied screenshot.
- The Profile app was installed over the existing app on the connected physical
  iPhone 15; CoreDevice launched it successfully and confirmed the process.
- The embedded Profile companion was installed directly on the paired physical
  Apple Watch SE, launched successfully and confirmed as a running process.
- A later diagnostic process query hit an intermittent CoreDevice wireless
  tunnel timeout. This does not invalidate the earlier install/launch receipts,
  but prolonged physical WatchConnectivity, voice and HKWorkout interaction
  still require hands-on observation on the watch face.
- Final Flutter verification passed with zero analyzer findings and 48 tests;
  watchOS Swift tests passed 29/29, including offline finish/relaunch recovery.

## Backend Security

New/updated database controls:

- provider token material is server-only and client roles have no table grant;
- device credentials are random and stored only as hashes;
- pairing codes are single-use, expiring and rate-limited;
- wearable event uniqueness is scoped by user, provider and external event ID;
- Fitbit commands use a composite foreign key so a command cannot target
  another account's device token;
- trigger function search path is pinned;
- RLS exposes only owner Google Health aggregates;
- Free clients cannot bypass Plus/Pro gates through the UI or direct requests.

Verification:

- Supabase migration reset: passed.
- pgTAP: 67 tests passed.
- Public-schema lint: no project errors.
- Security advisor: no security warnings after the search-path migration.
- Secret scan: no committed live credential pattern found.

Residual advisor output: 34 `auth_rls_initplan` and 15 multiple-permissive-policy
performance warnings in older non-wearable policies. They are not wearable
security failures and should be consolidated in a dedicated schema-performance
change with regression tests rather than rewritten during provider release work.

The public recap renderer was also hardened before deployment: opaque slug
validation, HTTPS-only image/store URLs, escaped metadata, no inline script,
CSP/security headers and four dedicated tests. It remains undeployed until the
real store URLs and an HTML-capable custom/static domain exist.

## CI/CD

`.github/workflows/rallymate-ci.yml` now verifies:

- Flutter, Dart core and Android phone;
- Wear OS tests/build;
- iOS simulator and watchOS Swift tests;
- Fitbit tests, audit, OS 5 build and OS 4 build with artifacts;
- Garmin manifest/source always, and licensed compile when private SDK/key
  secrets are configured;
- Supabase reset, public-schema lint, pgTAP, advisors, Deno tests/typecheck;
- legal/privacy manifest presence and secret patterns through local CI.

Garmin CI secrets:

```text
GARMIN_CONNECTIQ_SDK_ARCHIVE_URL
GARMIN_DEVELOPER_KEY_BASE64
```

## Supabase Deployment

Remote state was verified on 12 July 2026:

- all repository migrations match the linked project history;
- `assistant`, `google-health`, `google-health-webhook`, `wearable-gateway` and
  `delete-account` are ACTIVE;
- unauthenticated wearable pairing is rejected with HTTP 401;
- wearable token encryption and rate-limit secrets are configured;
- `delete-account` GET returns HTTP 200, while the shared Supabase domain
  intentionally forces HTML to `text/plain`. Publish the legal/deletion pages
  on the Momentum site or a Supabase custom domain.
- `assistant` version 12 uses the official `deepseek-v4-flash` model name and
  its privacy knowledge now matches the implemented local HealthKit/Health
  Connect and optional 30-day Google Health aggregate flows.

Remaining deployment commands, only when their product configuration exists:

```bash
supabase functions deploy revenuecat-webhook --no-verify-jwt --workdir backend
supabase functions deploy recap --no-verify-jwt --workdir backend
```

Required secrets:

```text
GOOGLE_HEALTH_CLIENT_ID
GOOGLE_HEALTH_CLIENT_SECRET
GOOGLE_HEALTH_REDIRECT_URI
WEARABLE_TOKEN_ENCRYPTION_KEY
GOOGLE_HEALTH_WEBHOOK_AUTHORIZATION
RALLYMATE_ALLOWED_ORIGINS
REVENUECAT_WEBHOOK_SECRET
RALLYMATE_APP_STORE_URL
RALLYMATE_PLAY_STORE_URL
```

The `--no-verify-jwt` endpoints are not unprotected: wearable-gateway validates
JWT or scoped device credentials per action; google-health validates mobile JWT
and one-time OAuth state; the webhook validates authorization plus Google's
rotating Tink ECDSA signature.

## Store/Provider Actions

Apple/App Store:

- Keep Health/Fitness privacy labels aligned with Google Health opt-in.
- Test Apple Watch workout and WatchConnectivity on a physical paired set.
- Provide reviewer credentials and hardware notes.

Google Play:

- Complete Health app/Data Safety declarations.
- Test Wear OS at 192 dp and 227 dp plus physical Samsung/Pixel hardware.
- Publish only maintained Wear OS support, never legacy Tizen support.

Fitbit:

- Create one Paid Gallery listing with OS 4 and OS 5 builds.
- Add physical-device screenshots, support/privacy URLs and test account.

Garmin:

- Configure CI secrets, inspect the current UI on representative simulator and
  physical AMOLED/MIP/rectangular devices, then submit the existing UUID and
  signed `.iq` to Connect IQ Store review.

Google Health:

- Configure OAuth, webhook, verification, policy review and the security
  assessment threshold described above.

Cross-store release:

- Android release AAB generation, native-symbol verification and archive
  signature validation passed with the explicit local debug-signing fallback.
  Configure the real upload key before producing the Play artifact.
- Publish public Privacy, Terms and account-deletion URLs.
- Configure real store listing URLs before deploying the recap page.
- Configure RevenueCat products, offering and signed webhook before enabling
  production subscriptions.
- Accept the Android SDK licenses in the local/CI toolchain; the build works,
  but `flutter doctor` still reports license status as unknown on this Mac.

## Official Sources

- Apple App Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Apple WatchConnectivity:
  https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity
- Wear OS quality:
  https://developer.android.com/docs/quality-guidelines/wear-app-quality
- Garmin Connect IQ:
  https://developer.garmin.com/connect-iq/
- Garmin publishing:
  https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/
- Fitbit publishing:
  https://dev.fitbit.com/build/guides/publishing/
- Fitbit Gallery guidelines:
  https://dev.fitbit.com/legal/app-gallery-guidelines/
- Google Health policy:
  https://developers.google.com/health/policies/health-api-developer-user-data-policy
- Google Health setup:
  https://developers.google.com/health/setup
- Samsung Tizen discontinuation:
  https://developer.samsung.com/galaxy-watch-tizen/notice.html

## Principal Files

- `wear/garmin-connectiq/**`
- `wear/fitbit-os/**`
- `wear/fitbit-google-health/README.md`
- `wear/tizen-retired/README.md`
- `wear/shared/watch_module_protocol.md`
- `apps/rallymate/lib/features/devices/**`
- `apps/rallymate/lib/services/wearable_*.dart`
- `apps/rallymate/ios/Runner/GarminConnectIqBridge.swift`
- `apps/rallymate/android/app/src/main/kotlin/com/rallymate/rallymate/GarminConnectIqBridge.kt`
- `backend/supabase/functions/{wearable-gateway,google-health,google-health-webhook}/**`
- `backend/supabase/migrations/20260711223214_wearable_provider_integrations.sql`
- `backend/supabase/migrations/20260712023000_scope_wearable_event_idempotency.sql`
- `backend/supabase/migrations/20260712024500_fitbit_command_queue.sql`
- `backend/supabase/migrations/20260712003034_harden_duo_guard_search_path.sql`
- `.github/workflows/rallymate-ci.yml`
- `scripts/ci_local.sh`
