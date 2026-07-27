#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${GARMIN_CONNECTIQ_SDK:-$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0}"
KEY="${GARMIN_DEVELOPER_KEY:-$HOME/.config/rallymate/garmin/developer_key.der}"
DEVICE="${1:-venu3}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export JAVA_HOME
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

test -x "$SDK/bin/monkeyc"
test -f "$KEY"
mkdir -p "$ROOT/build"

OUTPUT=$("$SDK/bin/monkeyc" \
  -f "$ROOT/test.jungle" \
  -d "$DEVICE" \
  -o "$ROOT/build/RallyMate-$DEVICE-tests.prg" \
  -y "$KEY" \
  -l 0 \
  -w \
  -t 2>&1) || {
    STATUS=$?
    printf '%s\n' "$OUTPUT"
    exit "$STATUS"
  }
printf '%s\n' "$OUTPUT"
# La sola eccezione oltre all'icona è la dimensione dei vettori di conformità:
# è una risorsa presente unicamente nel binario di test (test.jungle), mai nel
# .prg di produzione, quindi non incide sulla memoria dell'app pubblicata.
# NON replicare questa eccezione in build.sh.
UNEXPECTED_WARNINGS=$(printf '%s\n' "$OUTPUT" |
  grep '^WARNING:' |
  grep -v "launcher icon .* will be scaled to the target size" |
  grep -v "record RallyMateScoringVectors is large" || true)
if [ -n "$UNEXPECTED_WARNINGS" ]; then
  printf '%s\n' "$UNEXPECTED_WARNINGS" >&2
  echo "Garmin test build rejected compiler warnings for $DEVICE" >&2
  exit 2
fi

"$SDK/bin/connectiq" >/tmp/rallymate-connectiq.log 2>&1 &
SIMULATOR_PID=$!
TEST_PID=""
TEST_OUTPUT_FILE=$(mktemp /tmp/rallymate-monkeydo.XXXXXX)
cleanup() {
  if [ -n "$TEST_PID" ] && kill -0 "$TEST_PID" 2>/dev/null; then
    kill "$TEST_PID" 2>/dev/null || true
    wait "$TEST_PID" 2>/dev/null || true
  fi
  kill "$SIMULATOR_PID" 2>/dev/null || true
  rm -f "$TEST_OUTPUT_FILE"
}
trap cleanup EXIT
sleep 3
TEST_STATUS=0
"$SDK/bin/monkeydo" "$ROOT/build/RallyMate-$DEVICE-tests.prg" "$DEVICE" -t >"$TEST_OUTPUT_FILE" 2>&1 &
TEST_PID=$!
FINISHED=false
for ((ATTEMPT = 0; ATTEMPT < 45; ATTEMPT += 1)); do
  if ! kill -0 "$TEST_PID" 2>/dev/null; then
    wait "$TEST_PID" || TEST_STATUS=$?
    TEST_PID=""
    FINISHED=true
    break
  fi
  sleep 1
done
if [ "$FINISHED" != true ]; then
  echo "Garmin test timed out for $DEVICE" >&2
  exit 124
fi
TEST_OUTPUT=$(cat "$TEST_OUTPUT_FILE")
printf '%s\n' "$TEST_OUTPUT"
if printf '%s\n' "$TEST_OUTPUT" | grep -q '^PASSED (passed=' &&
    ! printf '%s\n' "$TEST_OUTPUT" | grep -qE '^(FAILED|ERROR|ASSERTION FAILED)'; then
  exit 0
fi
if [ "$TEST_STATUS" -eq 0 ]; then
  echo "Garmin test runner exited without a PASSED receipt for $DEVICE" >&2
  exit 3
fi
exit "$TEST_STATUS"
