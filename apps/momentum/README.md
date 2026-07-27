# RallyMate mobile

Flutter client for Android and iOS. Scoring and local history are offline-first;
account, social, cloud backup and Rally Pro Assistant require a configured
Supabase client build.

## Safe client configuration

Create a local file outside the repository:

```bash
mkdir -p "$HOME/.config/rallymate"
cp config/client.env.example "$HOME/.config/rallymate/client.env"
chmod 600 "$HOME/.config/rallymate/client.env"
```

Fill `SUPABASE_URL` and a client-safe `SUPABASE_ANON_KEY` (legacy anon JWT or
publishable key). Never put `service_role`, `sb_secret_*` or
`DEEPSEEK_API_KEY` in this file. DeepSeek is read only by the Supabase
`assistant` Edge Function.

The wrapper validates the file and supplies the same defines to every build:

```bash
tool/rallymate doctor
tool/rallymate run -d <device-id>
tool/rallymate build-apk --debug
tool/rallymate build-appbundle --release
tool/rallymate build-ios --debug --no-codesign
tool/rallymate build-ipa --release
```

Use another environment without changing the repository:

```bash
RALLYMATE_CLIENT_ENV="$HOME/.config/rallymate/staging.env" \
  tool/rallymate run -d <device-id>
```

### Xcode

Before launching directly from Xcode, regenerate Flutter's configuration with
the correct build mode, then open `ios/Runner.xcworkspace`:

```bash
tool/rallymate configure-ios --debug
open ios/Runner.xcworkspace
```

Before a Release archive use `tool/rallymate configure-ios --release`, or use
`tool/rallymate build-ipa --release` so the defines cannot be omitted.

`Runner.entitlements` must retain the Keychain Sharing capability used by the
secure Supabase session store. Keep that capability enabled for the App ID and
signing profile in Apple Developer. A no-codesign simulator build validates
compilation only; use `tool/rallymate run -d <simulator-id>` to exercise the
Keychain and authentication runtime.

In Supabase Auth URL Configuration, allow the mobile callback exactly as
`rallymate://auth-callback`. It is used for email confirmation and password
recovery on both platforms.

### Android Studio

Prefer `tool/rallymate run` for physical-device testing. For IDE launches,
add this Flutter run argument:

```text
--dart-define-from-file=$HOME/.config/rallymate/client.env
```

Google Play artifacts must be produced with
`tool/rallymate build-appbundle --release`; TestFlight artifacts with
`tool/rallymate build-ipa --release`.
