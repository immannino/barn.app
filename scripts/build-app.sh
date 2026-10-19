#!/bin/sh
# Build barn.app.
#   ./scripts/build-app.sh                 release build for this Mac, ad-hoc signed
#   UNIVERSAL=1 ./scripts/build-app.sh     arm64 + x86_64
#   BARN_SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh
#                                          hardened runtime + timestamp, ready to notarize
set -eu
cd "$(dirname "$0")/.."

VERSION="${BARN_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BARN_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
IDENTITY="${BARN_SIGN_IDENTITY:--}"

if [ "${UNIVERSAL:-0}" = 1 ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=.build/apple/Products/Release/barn
else
  swift build -c release
  BIN=.build/release/barn
fi

APP=build/barn.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/barn"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - --entitlements Resources/barn.entitlements "$APP" >/dev/null
else
  codesign --force --sign "$IDENTITY" --options runtime --timestamp \
    --entitlements Resources/barn.entitlements "$APP"
fi
echo "built $APP ($VERSION, $IDENTITY)"
