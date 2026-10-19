#!/bin/sh
# Record the scripted demo (made-up agents, ~17 s) for the site, README and marketing.
#
#   ./scripts/record-demo.sh            → build/demo/barn-demo.mp4, barn-demo.gif, barn-demo.png
#
# Run it on macOS 26 so the Liquid Glass shows. Needs ffmpeg (brew install ffmpeg) and Screen
# Recording permission for your terminal (System Settings → Privacy & Security). The demo covers
# the screen with barn's brand backdrop, so your windows stay out of it; just keep the pointer on
# the main display (the demo moves it out of frame) and don't touch anything for 20 seconds.
set -eu
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "needs ffmpeg: brew install ffmpeg"; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ] ||
  echo "warning: macOS $(sw_vers -productVersion) shows the frosted fallback, not Liquid Glass"

OUT=build/demo
RECORD_SECONDS=20   # the demo runs ~17 s after launch
TRIM_START=1        # skip app launch
LENGTH=16
POSTER_AT=10        # switcher open with "pan" typed (demo time + ~1 s launch)

./scripts/build-app.sh
rm -rf "$OUT" && mkdir -p "$OUT"
pkill -x barn 2>/dev/null && sleep 1 || true

echo "==> recording ${RECORD_SECONDS}s, hands off"
screencapture -x -v -V "$RECORD_SECONDS" "$OUT/raw.mov" &
REC=$!
sleep 0.5
open -n build/barn.app --args --demo --demo-script --demo-rect "$PWD/$OUT/rect.txt"
wait "$REC"
[ -s "$OUT/raw.mov" ] || { echo "no recording; does your terminal have Screen Recording permission?"; exit 1; }
[ -s "$OUT/rect.txt" ] || { echo "the demo didn't report its window position"; exit 1; }

# Crop around the switcher + deck with some room, widened to 16:9, kept inside the screen.
SIZE=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUT/raw.mov" | tr , ' ')
CROP=$(echo "$(cat "$OUT/rect.txt") $SIZE" | awk '{
  x=$1; y=$2; w=$3; h=$4; sw=$5; sh=$6; pad=0.12*w
  x-=pad; y-=pad; w+=2*pad; h+=2*pad
  if (w/h < 16/9) { nw=h*16/9; x-=(nw-w)/2; w=nw } else { nh=w*9/16; y-=(nh-h)/2; h=nh }
  if (w>sw) { w=sw } if (h>sh) { h=sh }
  if (x<0) x=0; if (y<0) y=0; if (x+w>sw) x=sw-w; if (y+h>sh) y=sh-h
  w=int(w/2)*2; h=int(h/2)*2
  printf "crop=%d:%d:%d:%d", w, h, int(x), int(y) }')
echo "==> $CROP"

ffmpeg -loglevel error -y -ss "$TRIM_START" -t "$LENGTH" -i "$OUT/raw.mov" \
  -vf "$CROP,scale=1920:-2:flags=lanczos,fps=60" \
  -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -movflags +faststart -an "$OUT/barn-demo.mp4"

ffmpeg -loglevel error -y -ss "$POSTER_AT" -i "$OUT/raw.mov" -frames:v 1 \
  -vf "$CROP,scale=1920:-2:flags=lanczos" "$OUT/barn-demo.png"

# GIF for the README (GitHub doesn't autoplay video there). Shrink until it's under 5 MB.
for spec in 960:15 800:12 640:10; do
  width=${spec%:*} fps=${spec#*:}
  ffmpeg -loglevel error -y -ss "$TRIM_START" -t "$LENGTH" -i "$OUT/raw.mov" -vf \
    "$CROP,fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$OUT/barn-demo.gif"
  [ "$(stat -f %z "$OUT/barn-demo.gif")" -lt 5000000 ] && break
done

[ -n "${KEEP_RAW:-}" ] || rm "$OUT/raw.mov" "$OUT/rect.txt"
ls -lh "$OUT"
