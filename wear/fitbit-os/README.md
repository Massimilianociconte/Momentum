# Momentum Fitbit OS

Native Fitbit OS application for the supported Versa/Sense generation. This is
separate from Fitbit Air, which has no screen and uses Google Health instead.

> **Distribution status (Italy/EEA):** Google removed installation of
> third-party Fitbit apps and clocks for EEA users in June 2024. This module is
> retained for legacy devices, private development and countries where the
> provider still permits distribution. It must not be advertised as an
> installable Italian/EEA production feature.

## Implemented

- Fitbit OS 5 targets: Versa 3 and Sense.
- Fitbit OS 4 targets: Versa, Versa Lite and Versa 2, built as a separate FBA.
- Advantage, Golden Point, tie-break, super tie-break and free-play scoring.
- Wearable-first start screen with remembered format presets, including
  advantage, Golden Point, super tie-break, single set and free training.
- Offline event persistence, deterministic replay, stable event IDs and
  team-scoped Duo undo.
- Event-sourced undo, pause/resume and explicit match completion with a local
  confirmation screen; the session survives app/display lifecycle changes.
- Acknowledged outbox: events are removed only after server acceptance.
- PeerSocket batches measured below Fitbit's 1027-byte serialized limit.
- Expiring one-time pairing code, revocable device credential and server-side
  Plus entitlement verification.
- Durable, token-targeted `START_MATCH` commands polled by the companion and
  acknowledged by the watch.
- High-contrast touch UI, haptics, Always-On display handling and an explicit
  first-install subscription notice.
- Completed matches expose visible New Match navigation while unsent events
  from prior matches remain in the acknowledged outbox.
- App unload stops and saves only the exercise Momentum still owns; the match
  remains resumable without leaving an Exercise API session active or reopening
  it automatically.
- Workout start remains an explicit action inside Momentum. Fitbit OS exposes
  no documented cross-app callback that can wake this app when the system or a
  different app starts an exercise.

The app requests `access_aod`, `access_exercise`, `access_internet` and
`run_background`. It does not directly read Fitbit health sensors. Scoring
works offline and synchronizes when the phone companion and network become
available.

## Local Verification

```bash
cd wear/fitbit-os
npm ci
npm test
npm audit --omit=dev
npm run build
npm run build:legacy
```

Expected artifacts:

```text
build/app.fba                       Fitbit OS 5
build/rallymate-fitbit-os4.fba      Fitbit OS 4
```

The legacy Fitbit SDK has deprecated development dependencies. They are
isolated to the temporary OS 4 build directory and are not shipped as Node
runtime dependencies in the watch package.

## Release Endpoint

The committed runtime config points only to local Supabase. A release build is
blocked unless a public HTTPS gateway is supplied:

```bash
export RALLYMATE_WEARABLE_GATEWAY_URL='https://<project-ref>.supabase.co/functions/v1/wearable-gateway'
npm run check:release
npm run build:release
npm run build:legacy
```

Do not commit the generated public project endpoint if environments differ;
produce release artifacts in controlled CI for the selected environment.

## Fitbit App Gallery (Only Where Provider Distribution Is Available)

- Confirm the target country still permits third-party installation before
  preparing a listing. Do not submit an Italian/EEA availability claim.
- Where available, upload OS 4 and OS 5 binaries to one Gallery listing.
- Mark the listing as **Paid** because access depends on a Momentum Plus
  subscription managed through Apple/Google stores.
- Keep the in-app first-install notice aligned with the actual localized store
  price; never advertise a trial unless configured in both stores.
- Supply the transparent 80x80 icon required by the pinned Fitbit build tool
  (the Gallery guide also permits 160x160) and exact-resolution screenshots.
- A real Fitbit OS device linked to the developer account is required before
  publication. Simulator/build success alone is not final acceptance.
- Test startup under five seconds, reconnect, phone loss, network loss, queue
  replay, duplicate delivery and subscription downgrade on physical hardware.

Official references:
- https://support.google.com/googlehealth/answer/14237121
- https://dev.fitbit.com/build/guides/publishing/
- https://dev.fitbit.com/legal/app-gallery-guidelines/
- https://dev.fitbit.com/build/guides/communications/messaging/
