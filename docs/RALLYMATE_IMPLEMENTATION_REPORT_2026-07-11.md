# Momentum - Implementation and release-readiness report

Date: 2026-07-11

## Executive status

The implemented Momentum path is now offline-first and uses real local or
Supabase data for teams, social discovery, friendship, invitations, scoring and
Duo Mode. Apple Watch and Wear OS remain the only watch runtimes declared as
supported. Garmin, Fitbit OS, Tizen and other non-Wear platforms are explicitly
excluded until separate provider applications complete their own development,
hardware validation and store certification.

No production Supabase project, public link domain or store listing was changed
from this local workspace. Those operations require the owner's final project
reference, domain, signing fingerprints and store URLs.

## Implemented

### Team images and scoring surfaces

- Gallery and camera selection with native crop, 640 px output, JPEG
  compression, file-signature validation and a 2 MB ceiling.
- Managed offline copy, replacement, removal and initials fallback.
- Private `team-avatars` Storage bucket with owner/member RLS.
- Cloud image upload only for entitled Premium accounts. Local images continue
  to work for Free accounts and while offline.
- Independent image-content versions prevent style/color changes from
  re-uploading the bitmap.
- `COLOR`, `IMAGE` and `AUTO` scoring styles with contrast overlays and
  deterministic fallback.
- Team visuals wired into team lists/details, setup, history, analytics, live
  scoring, Duo Mode, Apple Watch and Wear OS payloads.
- Watch image transfer uses native binary transports and a versioned local
  cache; Always On never decodes the large bitmap.

### Smartwatch onboarding and device management

- Central compatibility catalog at
  `assets/config/watch_compatibility.json`.
- Guided setup detects the phone platform and reads real WatchConnectivity or
  Wear Data Layer status where the operating system exposes it.
- Persisted progress; pairing, companion availability, permissions,
  reachability, ping/haptic and test-point checks; actionable recovery states.
- Local-only connected-device registry with rename, default selection, test,
  disconnect, last-sync and readiness state. Hardware advertising identifiers
  are not stored or uploaded.
- Home setup CTA deep-links to the exact smartwatch section rather than only
  opening the generic Profile page.
- Apple Watch uses WatchConnectivity, offline event storage, haptics, voice,
  HKWorkoutSession recovery and an Always On-safe score surface.
- Wear OS uses the official Data Layer, Health Services-compatible workout
  path, foreground lifecycle, offline queue and high-contrast scoring.

### Social, friends and invitations

- Account-gated privacy controls for discovery, approximate map visibility,
  online/activity state, club and public sport statistics.
- Social discovery returns only field-limited profiles allowed by RLS; exact
  coordinates are neither requested nor exposed.
- Real custom map markers with avatar/initials, level, compatibility and
  availability; overlap clustering and selected-marker expansion.
- Privacy-aware opponent sheet with profile, public statistics and guarded
  friend/match/team/block/report actions.
- Reciprocal friendship state machine: pending, accepted, declined, cancelled
  and blocked; received/sent requests, suggestions and blocked users.
- Opaque, hashed, expiring and revocable invite tokens for profiles, friends,
  teams, matches and Duo Mode. Redeeming an invite always shows the inviter and
  requires consent.
- Native share sheet, QR display/scanner and manual eight-character code.
- Backend rate limits, audit events, anti-enumeration responses and explicit
  RPC grants.
- Custom `rallymate://` cold-start and foreground routing is active. HTTPS
  Universal/App Links are prepared but intentionally not enabled against a fake
  domain.

### Teams and Duo Mode

- Cloud teams, memberships and team links are reconciled into the local
  database idempotently; removed memberships are archived instead of silently
  deleting match history.
- Match/team proposal creation is accepted only through guarded RPCs; direct
  client inserts are revoked.
- Duo authorization is enforced server-side for Premium/test/admin accounts.
- One shared match ID, immutable team assignment, source attribution,
  per-team scoring rights, per-team undo and idempotent event ingestion.
- Late/out-of-order events are realigned to the server timeline; duplicate event
  IDs are ignored; history is reconstructed from the event stream.
- The manual Duo code accepts the actual eight-character backend format.

### Security and privacy

- New exposed tables have RLS and explicit Data API grants.
- Privileged plan/admin/reliability fields cannot be self-promoted by profile
  updates.
- Security-definer RPCs authenticate the caller, validate ownership/blocking,
  pin `search_path`, revoke `PUBLIC` execution and grant only the intended role.
- Team media uses a private bucket and signed access, not public URLs.
- Account deletion removes private team media before deleting the auth user and
  fails closed if cloud cleanup is incomplete.
- AI/service keys remain server-side; the client contains no secret or service
  role key.
- Health data remains local or inside the operating-system health ecosystem.
  iPhone reads aggregates; Apple Watch may write a workout only after HealthKit
  consent. Android does not write to Health Connect.
- The unfinished Coach purchase path cannot manufacture a successful local
  transaction; checkout is disabled until real store-product and receipt
  verification exist.

### UI, startup and performance

- Regenerated iOS, Android adaptive/round and watch icons with safe transparent
  foregrounds and no manually rounded iOS corners.
- Native launch screen and Flutter splash share the same background and mark,
  eliminating the square-logo flash.
- Large splash/map/paywall images were converted to optimized bundled variants;
  image decode sizes are capped on high-traffic screens.
- Removed fake player initials from Home; fixed clipped hero/player copy and the
  square quick-action artwork.
- Added semantics, minimum touch areas, readable compact watch states and a
  non-technical `SESSIONE PRONTA` workout state.

## Database migration

Migration:
`backend/supabase/migrations/20260711192920_social_teams_devices_security.sql`

It adds or hardens:

- social/profile privacy fields and discovery RPCs;
- friendships, blocks, rate-limit/audit events;
- cloud teams, memberships and team connections;
- private team-avatar storage policies;
- secure invitations and redemption;
- match/team proposals;
- Duo membership, event attribution, idempotency and team isolation;
- field-limited cloud-team reconciliation.

The pgTAP contract is in
`backend/supabase/tests/social_duo_security_test.sql`.

## Supported watch matrix

| Family | Phone | Status | Minimum implemented target |
|---|---|---|---|
| Apple Watch Series 4+, SE, Ultra | iPhone | Full native module | watchOS 10 |
| Google Pixel Watch 1-4 | Android | Full Wear OS module | Wear OS 3 |
| Samsung Galaxy Watch4+, FE, Ultra | Android | Full Wear OS module | Wear OS 3 |
| Xiaomi Watch 2 / 2 Pro | Android with GMS | Full Wear OS module | Wear OS 3 |
| OnePlus Watch 2 / 2R / 3 | Android with GMS | Full Wear OS module | Wear OS 4 |
| TicWatch Pro 5 / Enduro / Atlas | Android with GMS | Full Wear OS module | Wear OS 3 |
| Other certified Wear OS 3+ devices | Android with GMS | Conditional | Device QA required |
| Garmin, Fitbit OS/Air, Tizen, Huawei, Amazfit | Varies | Not supported by this binary | Separate certified module required |

`FULL` means the source architecture and store target are present; final release
still requires at least one physical-device pass per primary family. It does not
mean every manufacturer firmware revision has already been certified.

## Verification completed

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| Flutter tests | 30/30 passed |
| `rally_core` analyze | 0 issues |
| `rally_core` tests | 52/52 passed |
| watchOS Swift tests | 23/23 passed |
| Wear OS unit/build tasks | passed |
| Supabase schema lint | no errors |
| Supabase pgTAP security suite | 42/42 passed |
| Edge Functions format/lint/type-check | passed for 5 functions |
| Android Flutter debug APK | built |
| iOS Simulator app with embedded watch companion | built and installed |
| Apple Watch simulator companion | installed, launched and visually checked |
| Secret-pattern scan | no client/service secret found |
| iOS plist/privacy/entitlement syntax | valid |

Simulator QA confirmed a nonblank mobile Home, readable compact Apple Watch
scoring, embedded companion installation and the native custom-link registration.

## External release requirements

### Blocking before production

1. Choose an owned HTTPS domain and publish AASA/`assetlinks.json` plus the
   invite fallback page. Add the final Associated Domains and Android
   `autoVerify` host only after both files return 200 without redirects.
2. Supply the Google Play App Signing SHA-256 and final App Store/Play Store
   URLs. Follow `docs/deployment/DEEP_LINKS.md`.
3. Link the intended Supabase project, review the project ref, run the migration,
   deploy Edge Functions and set server-side secrets. Local verification does
   not equal a production deployment.
4. Configure final RevenueCat products/offerings/entitlements in both stores and
   exercise purchase, restore, cancellation and webhook flows in sandbox.
5. Keep Coach purchases disabled until product IDs and server-side store receipt
   verification are implemented.
6. Complete physical-device matrices: iPhone + Apple Watch, Android + Samsung
   Galaxy Watch, and Android + Pixel Watch, including denied/revoked permissions,
   offline recovery, Always On and a long match.
7. Complete App Store Connect and Play Console privacy, Health, subscription,
   demo-account and data-safety declarations using the real production config.

### Non-blocking but recommended

- Run VoiceOver, TalkBack, Dynamic Type and reduced-motion manual passes on
  physical devices.
- Profile a 90-minute match for battery/thermal behavior and collect release-mode
  frame timings on representative low/mid-range Android hardware.
- Review dependency major-version upgrades separately; do not combine Riverpod,
  RevenueCat, SQLite and router migrations into the release candidate without a
  dedicated regression cycle.

## Principal changed areas

- `apps/momentum/lib/data/` and `lib/services/`
- `apps/momentum/lib/features/{teams,devices,social,duo,live,history,analytics,privacy,home}`
- `apps/momentum/android/app/src/main/`
- `apps/momentum/ios/Runner/` and Xcode watch target wiring
- `wear/watchos/` and `wear/wearos/`
- `backend/supabase/migrations/`, `functions/` and `tests/`
- `apps/momentum/assets/brand/`, native icon catalogs and launch assets
- `docs/deployment/`, `docs/legal/`, `.github/workflows/` and `scripts/ci_local.sh`

## Residual risk

- Public HTTPS deep links cannot be end-to-end verified before the final domain
  and signing fingerprint exist.
- Remote RLS/function behavior must be re-tested after production migration;
  only the local Supabase stack was changed here.
- Manufacturer-specific Wear OS firmware and real radio/background constraints
  cannot be fully represented by simulators.
- A separate Garmin/Fitbit application is a separate product effort, not a flag
  that can safely be enabled in the Apple Watch/Wear OS binaries.
