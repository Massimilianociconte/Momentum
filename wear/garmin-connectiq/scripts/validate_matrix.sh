#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCTS=$(
  xmllint --xpath '//*[local-name()="product"]/@id' "$ROOT/manifest.xml" |
    tr ' ' '\n' |
    sed -n 's/^id="\([^"]*\)"$/\1/p'
)
TOTAL=$(printf '%s\n' "$PRODUCTS" | wc -l | tr -d ' ')
INDEX=0

while IFS= read -r device; do
  [ -n "$device" ] || continue
  INDEX=$((INDEX + 1))
  printf '[%s/%s] %s\n' "$INDEX" "$TOTAL" "$device"
  "$ROOT/scripts/build.sh" "$device"
done <<< "$PRODUCTS"

printf 'Garmin matrix validated: %s targets.\n' "$TOTAL"
