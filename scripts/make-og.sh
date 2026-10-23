#!/bin/sh
# Render the link-preview image (scripts/og/og.html → site/assets/og.jpg, 1200×630 at 2×).
# JPEG because the grain makes a PNG ~3 MB, too heavy for link previews.
# Needs Google Chrome; the page loads the site's fonts from Google Fonts.
set -eu
cd "$(dirname "$0")/.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$CHROME" ] || { echo "needs Google Chrome (or CHROME=/path/to/chrome)"; exit 1; }

OUT=site/assets/og.jpg
TMP=$(mktemp -t og).png
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --window-size=1200,630 --virtual-time-budget=5000 \
  --screenshot="$TMP" "file://$PWD/scripts/og/og.html" 2>/dev/null
sips -s format jpeg -s formatOptions 88 "$TMP" --out "$OUT" >/dev/null
rm -f "$TMP"
sips -g pixelWidth -g pixelHeight "$OUT" | tail -2
ls -lh "$OUT" | awk '{print $5, $9}'
