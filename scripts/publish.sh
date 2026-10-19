#!/bin/sh
# Ship a release from your own Mac: sign + notarize, tag, GitHub Release, Homebrew tap.
#
#   ./scripts/publish.sh 0.2.0
#
# Needs: Developer ID identity in your keychain, `xcrun notarytool store-credentials barn-notary …`
# done once, and `gh auth login`. Set TAP_DIR to a local clone of <you>/homebrew-tap to also
# bump the cask (skipped otherwise). See docs/RELEASING.md.
set -eu
cd "$(dirname "$0")/.."
VERSION="${1:?usage: publish.sh <version>}"
TAG="v$VERSION"

[ -z "$(git status --porcelain)" ] || { echo "commit or stash your changes first"; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "$TAG already exists"; exit 1; }

./scripts/release.sh "$VERSION"

git tag -a "$TAG" -m "barn $VERSION"
git push origin "$TAG"
gh release create "$TAG" build/barn.dmg "build/barn-$VERSION.zip" build/checksums.txt \
  --title "barn $VERSION" --generate-notes

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
