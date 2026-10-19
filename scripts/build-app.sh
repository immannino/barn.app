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
  PRODUCTS=.build/apple/Products/Release
else
  swift build -c release
  PRODUCTS=.build/release
fi

APP=build/barn.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCTS/barn" "$APP/Contents/MacOS/barn"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/barn"
# Sparkle (updates). Its XPC services are only for sandboxed apps, which barn isn't.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
ditto "$PRODUCTS/Sparkle.framework" "$SPARKLE"
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# Inside out: Sparkle's helpers, the framework, then the app.
if [ "$IDENTITY" = "-" ]; then set -- --sign -; else set -- --sign "$IDENTITY" --options runtime --timestamp; fi
for code in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
  codesign --force "$@" "$code" 2>&1 | grep -v 'replacing existing signature' || true
done
codesign --force "$@" --entitlements Resources/barn.entitlements "$APP" 2>&1 | grep -v 'replacing existing signature' || true
echo "built $APP ($VERSION, $IDENTITY)"
