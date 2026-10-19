#!/bin/sh
# Ship a release from your own Mac: sign + notarize, tag, GitHub Release, Sparkle appcast,
# Homebrew tap.
#
#   ./scripts/publish.sh 0.2.0
#
# Needs: Developer ID identity in your keychain, `xcrun notarytool store-credentials barn-notary …`
# done once, `gh auth login`, and the Sparkle signing key (keychain account "barn"). Set TAP_DIR
# to a local clone of <you>/homebrew-tap to also bump the cask (skipped otherwise).
# See docs/RELEASING.md.
set -eu
cd "$(dirname "$0")/.."
VERSION="${1:?usage: publish.sh <version>}"
TAG="v$VERSION"

[ "$(git branch --show-current)" = main ] || { echo "switch to main first"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "commit or stash your changes first"; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "$TAG already exists"; exit 1; }

# The update signing key must be the one shipped apps trust, or they'll reject this update.
swift package resolve
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
KEY=$("$SPARKLE_BIN/generate_keys" --account barn -p 2>/dev/null) || {
  echo "no Sparkle key in the keychain (account barn); see docs/RELEASING.md"; exit 1; }
[ "$KEY" = "$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' Resources/Info.plist)" ] || {
  echo "the keychain's Sparkle key doesn't match SUPublicEDKey in Resources/Info.plist"; exit 1; }

./scripts/release.sh "$VERSION"

git push origin main
git tag -a "$TAG" -m "barn $VERSION"
git push origin "$TAG"
gh release create "$TAG" build/barn.dmg "build/barn-$VERSION.zip" build/checksums.txt \
  --title "barn $VERSION" --generate-notes

# Sparkle feed: lists only the newest release. The pages workflow deploys it on push.
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' build/barn.app/Contents/Info.plist)
SIGNATURE=$("$SPARKLE_BIN/sign_update" --account barn "build/barn-$VERSION.zip")
cat > site/appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>barn</title>
    <link>https://barn.ope.cool/appcast.xml</link>
    <item>
      <title>barn $VERSION</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/$REPO/releases/tag/$TAG</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/barn-$VERSION.zip"
                 type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
APPCAST
git add site/appcast.xml
git commit -m "appcast: barn $VERSION"
git push origin main
echo "appcast updated"

if [ -n "${TAP_DIR:-}" ]; then
  SHA=$(shasum -a 256 "build/barn-$VERSION.zip" | cut -d' ' -f1)
  OWNER=$(gh repo view --json owner -q .owner.login)
  mkdir -p "$TAP_DIR/Casks"
  sed -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" \
      -e "s/OWNER/$OWNER/g" packaging/barn.rb > "$TAP_DIR/Casks/barn.rb"
  git -C "$TAP_DIR" add Casks/barn.rb
  git -C "$TAP_DIR" commit -m "barn $VERSION"
  git -C "$TAP_DIR" push
  echo "tap updated"
fi
echo "published $TAG"
