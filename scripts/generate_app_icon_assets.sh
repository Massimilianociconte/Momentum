#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/momentum"
SOLID="$APP/assets/brand/rallymate_app_icon_1024.png"
FOREGROUND="$APP/assets/brand/rallymate_icon_foreground_1024.png"

resize() {
  local source="$1" size="$2" destination="$3"
  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
  sips -z "$size" "$size" "$destination" >/dev/null
}

IOS="$APP/ios/Runner/Assets.xcassets/AppIcon.appiconset"
while read -r size name; do
  resize "$SOLID" "$size" "$IOS/$name"
done <<'SIZES'
20 Icon-App-20x20@1x.png
40 Icon-App-20x20@2x.png
60 Icon-App-20x20@3x.png
29 Icon-App-29x29@1x.png
58 Icon-App-29x29@2x.png
87 Icon-App-29x29@3x.png
40 Icon-App-40x40@1x.png
80 Icon-App-40x40@2x.png
120 Icon-App-40x40@3x.png
120 Icon-App-60x60@2x.png
180 Icon-App-60x60@3x.png
76 Icon-App-76x76@1x.png
152 Icon-App-76x76@2x.png
167 Icon-App-83.5x83.5@2x.png
1024 Icon-App-1024x1024@1x.png
SIZES

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  case "$density" in
    mdpi) legacy=48; foreground=108; launch=96 ;;
    hdpi) legacy=72; foreground=162; launch=144 ;;
    xhdpi) legacy=96; foreground=216; launch=192 ;;
    xxhdpi) legacy=144; foreground=324; launch=288 ;;
    xxxhdpi) legacy=192; foreground=432; launch=384 ;;
  esac
  directory="$APP/android/app/src/main/res/mipmap-$density"
  resize "$SOLID" "$legacy" "$directory/ic_launcher.png"
  resize "$SOLID" "$legacy" "$directory/ic_launcher_round.png"
  resize "$FOREGROUND" "$foreground" "$directory/ic_launcher_foreground.png"
  resize "$FOREGROUND" "$launch" "$directory/launch_image.png"
done

LAUNCH="$APP/ios/Runner/Assets.xcassets/LaunchImage.imageset"
resize "$FOREGROUND" 168 "$LAUNCH/LaunchImage.png"
resize "$FOREGROUND" 336 "$LAUNCH/LaunchImage@2x.png"
resize "$FOREGROUND" 504 "$LAUNCH/LaunchImage@3x.png"

resize "$SOLID" 1024 \
  "$ROOT/wear/watchos/MomentumWatchApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
cp "$SOLID" "$APP/assets/rallymate_app_icon_1024.png"
