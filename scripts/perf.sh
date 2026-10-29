#!/bin/bash
# CPU regression test: runs barn's demo in a few scenarios, from a quiet menu bar to
# `--stress` (24 agents, every effect, constant state changes), and measures the CPU time it
# really uses. Fails when a scenario's average or worst one-second spike goes over its budget.
#
#   ./scripts/perf.sh              build, run every scenario, print a table
#   SKIP_BUILD=1 ./scripts/perf.sh use the existing build/barn.app
#   ONLY=stress-list ./scripts/perf.sh
#   DURATION=30 WARMUP=8 ./scripts/perf.sh
#
# Writes build/perf/results.md and a `sample` profile per scenario (build/perf/<name>.sample.txt)
# to see where the time went. Needs a logged-in GUI session (CI's macOS runners have one).
# Settings come from launch arguments, which override your preferences without changing them.
set -euo pipefail
cd "$(dirname "$0")/.."

DURATION=${DURATION:-20} # seconds measured per scenario
WARMUP=${WARMUP:-6}      # seconds after launch before measuring
SCALE=${PERF_BUDGET_SCALE:-1} # multiply every budget, e.g. 2 on a slow machine
OUT=build/perf
APP=build/barn.app
BIN=$APP/Contents/MacOS/barn

# name | avg budget % | peak budget % | arguments
# On an M-series Mac the quiet scenarios use ~0.3% and stress ~28-30% (wiggle and bounce at 3x
# speed keep two dozen cards moving most of the time; that's SwiftUI layout, not waste). Budgets
# leave room for noise but catch a doubling, or effects drawn on the CPU again (~50% at rest).
SCENARIOS=(
  "menubar|1|5|"
  "deck|2|8|--deck"
  "deck-list|2|8|--deck -deckLayout list"
  "stress-tiles|45|60|--stress --deck"
  "stress-list|45|60|--stress --deck -deckLayout list"
  "stress-switcher|50|70|--stress --deck --switcher"
)
# Pinned so your own look and deck options don't change the numbers.
BASE=(--demo -activeLookID preset:barn -deckLayout tiles -deckSize m -deckFont system -deckOpacity 1
      -deckVisible NO -soundsOn NO -haptics NO)

[ -n "${SKIP_BUILD:-}" ] || ./scripts/build-app.sh >/dev/null
[ -x "$BIN" ] || { echo "no $BIN; build first"; exit 1; }
mkdir -p "$OUT"

now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
# Seconds of CPU a process has used ("[[dd-]hh:]mm:ss.cc" from ps).
cpu() { ps -o time= -p "$1" 2>/dev/null | tr - : | awk -F: '{ s = 0; for (i = 1; i <= NF; i++) s = s * 60 + $i; print s }'; }
pct() { awk -v c="$1" -v t="$2" 'BEGIN { printf "%.1f", (t > 0 ? 100 * c / t : 0) }'; }
over() { awk -v v="$1" -v b="$2" -v s="$SCALE" 'BEGIN { exit !(v > b * s) }'; }

WS=$(pgrep -x WindowServer | head -1 || true)
failed=0
rows=()

for scenario in "${SCENARIOS[@]}"; do
  IFS='|' read -r name avg_budget peak_budget args <<<"$scenario"
  [ -z "${ONLY:-}" ] || [ "$ONLY" = "$name" ] || continue
  # shellcheck disable=SC2086 # args are words on purpose
  "$BIN" "${BASE[@]}" $args >/dev/null 2>&1 &
  pid=$!
  sleep "$WARMUP"

  t0=$(now); c0=$(cpu $pid); w0=$([ -n "$WS" ] && cpu "$WS" || echo 0)
  pt=$t0; pc=$c0; peak=0; alive=1
  for _ in $(seq "$DURATION"); do
    sleep 1
    kill -0 $pid 2>/dev/null || { alive=0; break; }
    t=$(now); c=$(cpu $pid)
    p=$(pct "$(awk -v a="$c" -v b="$pc" 'BEGIN { print a - b }')" "$(awk -v a="$t" -v b="$pt" 'BEGIN { print a - b }')")
    awk -v p="$p" -v m="$peak" 'BEGIN { exit !(p > m) }' && peak=$p
    pt=$t; pc=$c
  done

  if [ $alive = 1 ]; then
    t=$(now); c=$(cpu $pid); w=$([ -n "$WS" ] && cpu "$WS" || echo 0)
    elapsed=$(awk -v a="$t" -v b="$t0" 'BEGIN { print a - b }')
    avg=$(pct "$(awk -v a="$c" -v b="$c0" 'BEGIN { print a - b }')" "$elapsed")
    ws=$(pct "$(awk -v a="$w" -v b="$w0" 'BEGIN { print a - b }')" "$elapsed")
    rss=$(( $(ps -o rss= -p $pid) / 1024 ))
    /usr/bin/sample $pid 3 -file "$OUT/$name.sample.txt" >/dev/null 2>&1 || true
    kill $pid 2>/dev/null; wait $pid 2>/dev/null || true
    verdict=ok
    if over "$avg" "$avg_budget" || over "$peak" "$peak_budget"; then verdict=FAIL; failed=1; fi
  else
    avg=-; peak=-; ws=-; rss=-; verdict="FAIL (exited)"; failed=1
  fi
  rows+=("| $name | $avg% | $peak% | ≤ $avg_budget% / $peak_budget% | ${rss} MB | $ws% | $verdict |")
  echo "$name: avg $avg%, peak $peak%, $rss MB, WindowServer $ws% → $verdict"
done

{
  echo "### barn CPU (${DURATION}s per scenario, budgets ×$SCALE)"
  echo
  echo "| scenario | avg CPU | worst 1 s | budget avg / peak | memory | WindowServer | |"
  echo "|---|---|---|---|---|---|---|"
  printf '%s\n' "${rows[@]}"
  echo
  echo "WindowServer is for context only: it also draws everything else on screen."
} >"$OUT/results.md"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || cat "$OUT/results.md" >>"$GITHUB_STEP_SUMMARY"
echo; cat "$OUT/results.md"
exit $failed
