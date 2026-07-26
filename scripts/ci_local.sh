#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

if [[ -d "$ANDROID_JBR" && -z "${JAVA_HOME:-}" ]]; then
  export JAVA_HOME="$ANDROID_JBR"
fi

section() {
  printf '\n\033[1;36m==> %s\033[0m\n' "$1"
}

run_secret_scan() {
  section "Secret scan"
  if rg -l --hidden \
    --glob '!**/.git/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/.build/**' \
    --glob '!**/build/**' \
    --glob '!**/Pods/**' \
    --glob '!**/*.lock' \
    '(sk_live_[0-9A-Za-z]{20,}|sk-[0-9A-Za-z_-]{20,}|sb_secret_[0-9A-Za-z_-]{20,}|ghp_[0-9A-Za-z]{30,}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----)' \
    "$ROOT"; then
    echo "Potential live secret found. Remove it or add a narrow audited exception." >&2
    exit 1
  fi
}

run_core() {
  section "Dart core"
  (cd "$ROOT/packages/rally_core" && dart pub get && dart analyze && dart test)
}

run_flutter() {
  section "Flutter app"
  (
    cd "$ROOT/apps/rallymate"
    local client_env="${RALLYMATE_CLIENT_ENV:-$HOME/.config/rallymate/client.env}"
    flutter pub get
    dart run build_runner build
    flutter analyze
    flutter test
    RALLYMATE_CLIENT_ENV="$client_env" tool/rallymate build-apk --debug
    (cd android && ./gradlew :app:lintDebug)
  )
}

run_ios() {
  section "iOS simulator build and native tests"
  (
    cd "$ROOT/apps/rallymate"
    RALLYMATE_CLIENT_ENV="${RALLYMATE_CLIENT_ENV:-$HOME/.config/rallymate/client.env}" \
      tool/rallymate build-ios --simulator --no-codesign
    local simulator_id
    simulator_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
    [[ -n "$simulator_id" ]] || {
      echo "No available iPhone simulator for RunnerTests." >&2
      exit 1
    }
    xcodebuild test \
      -quiet \
      -workspace ios/Runner.xcworkspace \
      -scheme Runner \
      -destination "platform=iOS Simulator,id=$simulator_id" \
      CODE_SIGNING_ALLOWED=NO
  )
}

run_store_compliance() {
  section "Store compliance smoke checks"

  for file in \
    "$ROOT/docs/legal/PRIVACY_POLICY.md" \
    "$ROOT/docs/legal/PRIVACY_POLICY_EN.md" \
    "$ROOT/docs/legal/TERMS_OF_SERVICE.md" \
    "$ROOT/docs/legal/STORE_COMPLIANCE.md" \
    "$ROOT/apps/rallymate/ios/Runner/PrivacyInfo.xcprivacy"; do
    [[ -f "$file" ]] || {
      echo "Missing compliance file: $file" >&2
      exit 1
    }
  done

  plutil -lint \
    "$ROOT/apps/rallymate/ios/Runner/Info.plist" \
    "$ROOT/apps/rallymate/ios/Runner/PrivacyInfo.xcprivacy" \
    "$ROOT/apps/rallymate/ios/Runner/Runner.entitlements"

  local manifest="$ROOT/apps/rallymate/build/app/intermediates/packaged_manifests/debug/processDebugManifestForPackage/AndroidManifest.xml"
  [[ -f "$manifest" ]] || manifest="$ROOT/apps/rallymate/build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml"
  [[ -f "$manifest" ]] || {
    echo "Android manifest not found. Run flutter build apk --debug first." >&2
    exit 1
  }

  rg 'android:targetSdkVersion="(3[5-9]|[4-9][0-9])"' "$manifest" >/dev/null || {
    echo "Android targetSdkVersion must be >= 35 for Play readiness." >&2
    exit 1
  }
  rg 'android:allowBackup="false"' "$manifest" >/dev/null || {
    echo "Android Auto Backup must remain disabled for local-first data." >&2
    exit 1
  }
  rg 'android:dataExtractionRules="@xml/data_extraction_rules"' "$manifest" >/dev/null || {
    echo "Android 12+ backup and device-transfer rules are missing." >&2
    exit 1
  }
  if rg 'HealthKit non viene letto|DeepSeek comporta trasferimento dati verso la Cina' \
    "$ROOT/docs/legal" "$ROOT/apps/rallymate/lib" >/dev/null; then
    echo "Found stale privacy/compliance wording; update docs/UI before release." >&2
    exit 1
  fi
}

run_wearos() {
  section "Wear OS"
  (cd "$ROOT/wear/wearos" && ./gradlew testDebugUnitTest assembleDebug)
}

run_watchos() {
  section "watchOS Swift package"
  (cd "$ROOT/wear/watchos/RallyMateCore" && swift test)
}

run_supabase() {
  if ! command -v deno >/dev/null 2>&1; then
    section "Supabase Edge Functions"
    echo "Deno not installed; skipping local Supabase TypeScript checks."
    return
  fi
  section "Supabase Edge Functions"
  (
    cd "$ROOT/backend/supabase"
    deno fmt --check functions
    deno lint functions
    deno check functions/*/index.ts
    deno test functions/_shared/*_test.ts functions/*/*_test.ts
  )
}

run_supabase_db() {
  if ! command -v supabase >/dev/null 2>&1; then
    section "Supabase schema and RLS"
    echo "Supabase CLI not installed; skipping local pgTAP checks."
    return
  fi
  section "Supabase schema and RLS"
  (
    cd "$ROOT/backend"
    supabase db reset
    supabase db lint --schema public --level warning --fail-on error
    supabase test db
    supabase db advisors --local
  )
}

run_fitbit() {
  if ! command -v npm >/dev/null 2>&1; then
    section "Fitbit OS"
    echo "Node/npm not installed; skipping Fitbit OS checks."
    return
  fi
  section "Fitbit OS 5 and OS 4"
  (
    cd "$ROOT/wear/fitbit-os"
    npm ci
    npm test
    npm audit --omit=dev
    RALLYMATE_WEARABLE_GATEWAY_URL="https://ci.rallymate.invalid/functions/v1/wearable-gateway" \
      npm run check:release
    npm run build
    npm run build:legacy
  )
}

run_garmin() {
  section "Garmin Connect IQ"
  xmllint --noout "$ROOT/wear/garmin-connectiq/manifest.xml"
  test -s "$ROOT/wear/garmin-connectiq/resources-ita/strings/strings.xml"
  test -s "$ROOT/docs/store-assets/garmin/rallymate_connectiq_store_icon_500.png"
  test -s "$ROOT/docs/store-assets/garmin/rallymate_connectiq_hero_1440x720.jpg"
  if [[ -x "${GARMIN_CONNECTIQ_SDK:-}/bin/monkeyc" && -f "${GARMIN_DEVELOPER_KEY:-}" ]]; then
    "$ROOT/wear/garmin-connectiq/scripts/validate_matrix.sh"
    for device in venu3 instinct2 venusq; do
      "${GARMIN_CONNECTIQ_SDK}/bin/monkeyc" \
        -f "$ROOT/wear/garmin-connectiq/test.jungle" \
        -d "$device" \
        -o "$ROOT/wear/garmin-connectiq/build/RallyMate-$device-tests.prg" \
        -y "$GARMIN_DEVELOPER_KEY" \
        -l 0 -w -t
    done
    "$ROOT/wear/garmin-connectiq/scripts/export.sh"
    if [[ "${RUN_GARMIN_SIMULATOR_TESTS:-0}" == "1" ]]; then
      for device in venu3 instinct2 venusq; do
        "$ROOT/wear/garmin-connectiq/scripts/test.sh" "$device"
      done
    fi
  else
    echo "Licensed Garmin SDK/key not configured; static checks only."
  fi
}

run_secret_scan
run_core
run_flutter
run_store_compliance
run_wearos
run_watchos
run_fitbit
run_garmin
run_supabase_db
run_supabase

if [[ "${RUN_IOS:-1}" == "1" ]]; then
  run_ios
fi

section "CI local completed"
