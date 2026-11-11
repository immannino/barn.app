#!/bin/sh
# Record each group of looks as it appears in settings, stacked, 5 s each, for the site, README
# and socials.
#
#   ./scripts/record-looks.sh                 → build/looks/<group>.gif, .mp4, .png for every group
#   ./scripts/record-looks.sh terminals aqua  → just those groups
#
# Groups: glass terminals desktops whimsy friends. Needs ffmpeg (brew install ffmpeg) and Screen
# Recording permission for your terminal. Each take covers the whole screen for ~8 s; keep the
# pointer on the main display and don't touch anything. Run on macOS 26 for Liquid Glass in "glass".
set -eu
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "needs ffmpeg: brew install ffmpeg"; exit 1; }

OUT=build/looks
LENGTH=5          # seconds in each GIF
RECORD_SECONDS=8  # launch + settle + LENGTH, with room to spare
TRIM_START=2      # skip app launch and the window fading in
WHICH=${*:-glass terminals desktops whimsy friends}

[ -n "${SKIP_BUILD:-}" ] || ./scripts/build-app.sh
mkdir -p "$OUT"
pkill -x barn 2>/dev/null && sleep 1 || true

for group in $WHICH; do
  echo "==> $group: recording ${RECORD_SECONDS}s, hands off"
  rm -f "$OUT/raw.mov" "$OUT/rect.txt"
  screencapture -x -v -V "$RECORD_SECONDS" "$OUT/raw.mov" &
  REC=$!
  sleep 0.5
  # Settings passed as arguments apply to this launch only; your saved ones stay as they are.
  open -n build/barn.app --args --demo --showcase "$group" --showcase-rect "$PWD/$OUT/rect.txt" \
    --showcase-seconds "$RECORD_SECONDS" -deckLayout tiles -deckFont system -deckOpacity 1
  wait "$REC"
  [ -s "$OUT/raw.mov" ] || { echo "no recording; does your terminal have Screen Recording permission?"; exit 1; }
  [ -s "$OUT/rect.txt" ] || { echo "barn didn't report where the previews are (unknown group \"$group\"?)"; exit 1; }
  CROP=$(awk '{ printf "crop=%d:%d:%d:%d", int($3/2)*2, int($4/2)*2, $1, $2 }' "$OUT/rect.txt")

  ffmpeg -loglevel error -y -ss "$TRIM_START" -t "$LENGTH" -i "$OUT/raw.mov" \
    -vf "$CROP,fps=60" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -movflags +faststart -an \
    "$OUT/$group.mp4"
  ffmpeg -loglevel error -y -ss "$TRIM_START" -i "$OUT/raw.mov" -frames:v 1 -vf "$CROP" "$OUT/$group.png"

  # GIF for the README (GitHub doesn't autoplay video there). Shrink until it's under 5 MB.
  for spec in 720:20 600:15 480:12; do
    width=${spec%:*} fps=${spec#*:}
    ffmpeg -loglevel error -y -ss "$TRIM_START" -t "$LENGTH" -i "$OUT/raw.mov" -vf \
      "$CROP,fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
      "$OUT/$group.gif"
    [ "$(stat -f %z "$OUT/$group.gif")" -lt 5000000 ] && break
  done
  sleep 1
done

[ -n "${KEEP_RAW:-}" ] || rm -f "$OUT/raw.mov" "$OUT/rect.txt"
ls -lh "$OUT"
