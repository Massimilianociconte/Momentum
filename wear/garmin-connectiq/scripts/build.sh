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
  -f "$ROOT/monkey.jungle" \
  -d "$DEVICE" \
  -o "$ROOT/build/RallyMate-$DEVICE.prg" \
  -y "$KEY" \
  -l 0 \
  -w \
  -O 2 2>&1) || {
    STATUS=$?
    printf '%s\n' "$OUTPUT"
    exit "$STATUS"
  }
printf '%s\n' "$OUTPUT"
UNEXPECTED_WARNINGS=$(printf '%s\n' "$OUTPUT" |
  grep '^WARNING:' |
  grep -v "launcher icon .* will be scaled to the target size" || true)
if [ -n "$UNEXPECTED_WARNINGS" ]; then
  printf '%s\n' "$UNEXPECTED_WARNINGS" >&2
  echo "Garmin build rejected compiler warnings for $DEVICE" >&2
  exit 2
fi
