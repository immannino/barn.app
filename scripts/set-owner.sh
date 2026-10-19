#!/bin/sh
# Replace the OWNER placeholder with your GitHub user/org in the site, README, docs and cask.
#   ./scripts/set-owner.sh your-github-name
set -eu
cd "$(dirname "$0")/.."
NEW="${1:?usage: set-owner.sh <github-user-or-org>}"
grep -rl --exclude-dir=.build --exclude-dir=build --exclude-dir=.git --exclude=set-owner.sh 'OWNER' \
  README.md site docs packaging | while read -r f; do
  sed -i '' "s/OWNER/$NEW/g" "$f" && echo "updated $f"
done
