#!/bin/sh
# Signed + notarized release: build/barn.dmg (for people) and build/barn-<version>.zip (for Homebrew).
#
#   BARN_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/release.sh 0.2.0
#
# BARN_SIGN_IDENTITY can be left out when exactly one Developer ID identity is in the keychain.
# Notarization auth, pick one:
#   App Store Connect API key (recommended, what CI uses):
#     NOTARY_KEY_PATH=AuthKey_XXXX.p8 NOTARY_KEY_ID=XXXX NOTARY_ISSUER_ID=uuid
#   or a stored keychain profile (local):
#     xcrun notarytool store-credentials barn-notary --apple-id … --team-id … --password <app-specific>
#     NOTARY_PROFILE=barn-notary (the default)
# See docs/RELEASING.md.
set -eu
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version>}"

if [ -z "${BARN_SIGN_IDENTITY:-}" ]; then
  BARN_SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
fi
: "${BARN_SIGN_IDENTITY:?no Developer ID Application identity found; see docs/RELEASING.md}"
export BARN_SIGN_IDENTITY

if [ -n "${NOTARY_KEY_ID:-}" ]; then
  set -- --key "${NOTARY_KEY_PATH:?}" --key-id "$NOTARY_KEY_ID" --issuer "${NOTARY_ISSUER_ID:?}"
else
  set -- --keychain-profile "${NOTARY_PROFILE:-barn-notary}"
fi

echo "==> build $VERSION, signed as: $BARN_SIGN_IDENTITY"
BARN_VERSION="$VERSION" UNIVERSAL=1 ./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 build/barn.app

echo "==> dmg"
STAGE=$(mktemp -d)
cp -R build/barn.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/barn.dmg
hdiutil create -quiet -volname barn -srcfolder "$STAGE" -ov -format UDZO build/barn.dmg
rm -rf "$STAGE"
codesign --force --sign "$BARN_SIGN_IDENTITY" --timestamp build/barn.dmg

echo "==> notarize (usually a few minutes)"
xcrun notarytool submit build/barn.dmg "$@" --wait --timeout 30m
# The ticket covers the app inside the dmg too, so both can be stapled.
xcrun stapler staple build/barn.dmg
xcrun stapler staple build/barn.app

ZIP="build/barn-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/barn.app "$ZIP"

echo "==> verify"
spctl --assess --type execute --verbose build/barn.app
spctl --assess --type open --context context:primary-signature --verbose build/barn.dmg

(cd build && shasum -a 256 barn.dmg "barn-$VERSION.zip" > checksums.txt && cat checksums.txt)
echo "release ready: build/barn.dmg, $ZIP"
