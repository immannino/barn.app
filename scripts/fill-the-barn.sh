#!/bin/sh
# Fill the barn: start five silly Claude Code agents in farm-themed toy repos, a second or two
# apart, for recording a live demo. Start with an empty barn, run this, and watch them show up.
# Within a few seconds, some of them need you:
#
#   pancake-api    asks you a question (which syrup?)       → answer it in the switcher's tab
#   goat-tracker   wants permission to run a shell script   → approve it
#   rooster-alarm  wants permission to write a limerick     → approve it
#   hay-scheduler  reads around and writes a forecast       → just works, then ready
#   llama-ledger   hunts for a bug                          → just works, then ready
#
#   ./scripts/fill-the-barn.sh          open them in a new Ghostty window (Terminal.app if no Ghostty)
#   ./scripts/fill-the-barn.sh stop     quit the agents (the tabs stay open at a shell)
#
# The toy repos are rebuilt at ~/barn-farm on every run (FARM=… to move them). The first run, Claude
# asks whether you trust each folder; say yes once and later runs go straight in. Real sessions,
# real (tiny) token use. MODEL=haiku for snappier takes, GAP=… for seconds between launches.
set -eu
FARM="${FARM:-$HOME/barn-farm}"
GAP="${GAP:-1.5}"
PROJECTS="pancake-api goat-tracker hay-scheduler rooster-alarm llama-ledger"

if [ "${1:-}" = stop ]; then
  for pid in $(pgrep -x claude || true); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    case "$cwd" in "$FARM"/*) kill "$pid" && echo "stopped $(basename "$cwd")" ;; esac
  done
  exit 0
fi

CLAUDE=$(command -v claude) || { echo "needs Claude Code: https://claude.com/claude-code"; exit 1; }

# --- the toy repos (wiped and rebuilt each run; same paths, so folder trust sticks) ---
for p in $PROJECTS; do rm -rf "${FARM:?}/$p"; mkdir -p "$FARM/$p"; done
mkdir -p "$FARM/.launch"

cd "$FARM/pancake-api"
cat > README.md <<'EOF'
# pancake-api
The internet's most important breakfast API. `GET /breakfast` returns one (1) pancake.
EOF
cat > server.js <<'EOF'
const config = require("./config.json");
module.exports = (req, res) => res.json({ pancake: 1, syrup: config.syrup ?? null });
EOF
echo '{ "syrup": null, "stackHeight": 3 }' > config.json

cd "$FARM/goat-tracker"
cat > count-goats.sh <<'EOF'
#!/bin/sh
echo "counting goats..."; sleep 2
echo "goats in pen: 11"; echo "goats on the roof: 2"; echo "goats unaccounted for: 1 (probably Gerald)"
EOF
chmod +x count-goats.sh
printf "# goat-tracker\nKnows where every goat is. Mostly.\n" > README.md

cd "$FARM/hay-scheduler"
cat > fields.json <<'EOF'
{ "north": { "acres": 12, "cut": "2026-06-02" }, "creek": { "acres": 7, "cut": null },
  "hill": { "acres": 4, "cut": "2026-06-20", "note": "steep. the tractor complains" } }
EOF
cat > almanac.md <<'EOF'
# Farmer's almanac (unreliable edition)
- Cows lying down: rain within the day.
- Rooster crowing at noon: the rooster is confused.
- Hay must be dry three days running before baling.
EOF
cat > schedule.py <<'EOF'
import json

def next_field(fields):
    """Pick the uncut field with the most acres. Ignores weather, like a true optimist."""
    uncut = {k: v for k, v in fields.items() if not v["cut"]}
    return max(uncut, key=lambda k: uncut[k]["acres"]) if uncut else None

print(next_field(json.load(open("fields.json"))))
EOF

cd "$FARM/rooster-alarm"
cat > alarm.js <<'EOF'
// Wakes the farm. Volume is measured in roosters.
export const wake = (time = "05:00", volume = 11) => `COCK-A-DOODLE-DOO at ${time} (${volume} roosters)`;
EOF
printf "# rooster-alarm\nAn alarm clock that is just a rooster.\n" > README.md

cd "$FARM/llama-ledger"
cat > ledger.js <<'EOF'
// Tracks how many snacks each llama is owed.
export function settle(llamas) {
  let total = 0;
  for (let i = 1; i < llamas.length; i++) total += llamas[i].snacksOwed;
  return { total, perLlama: total / llamas.length };
}
EOF
cat > llamas.json <<'EOF'
[{ "name": "Dolly", "snacksOwed": 4 }, { "name": "Llarry", "snacksOwed": 2 }, { "name": "Kevin", "snacksOwed": 9 }]
EOF

# --- what each one is asked ---
prompt() {
  case $1 in
    pancake-api) echo "Before changing anything, use the AskUserQuestion tool to ask me which syrup GET /breakfast should default to (maple, blueberry, or 'surprise me'). Then set it in config.json and tell me in one cheerful sentence." ;;
    goat-tracker) echo "Run ./count-goats.sh and tell me, in one sentence, which goat is missing and where it might be." ;;
    hay-scheduler) echo "Read every file here, then write a short, dramatic weather-and-haymaking forecast for this week (one paragraph, in chat only, don't edit files)." ;;
    rooster-alarm) echo "Write a five-line limerick about a rooster who keeps oversleeping into LIMERICK.md." ;;
    llama-ledger) echo "Review ledger.js for bugs. Explain the worst one in two sentences, in chat only. Don't change anything." ;;
  esac
}
# pancake-api goes on by itself once you answer; the others ask before running or writing.
mode() { [ "$1" = pancake-api ] && echo acceptEdits || echo default; }

for p in $PROJECTS; do
  prompt "$p" > "$FARM/.launch/$p.prompt"
  cat > "$FARM/.launch/$p.sh" <<EOF
#!/bin/zsh
cd "$FARM/$p"
"$CLAUDE" --name "$p" --permission-mode $(mode "$p") ${MODEL:+--model "$MODEL"} "\$(cat "$FARM/.launch/$p.prompt")"
exec "\$SHELL" -l
EOF
  chmod +x "$FARM/.launch/$p.sh"
done

# --- open them, one tab each ---
if [ -d /Applications/Ghostty.app ] && [ "${TERMINAL_APP:-ghostty}" = ghostty ]; then
  script='tell application "Ghostty"
  activate
  set cfg to new surface configuration'
  first=1
  for p in $PROJECTS; do
    script="$script
  set command of cfg to \"$FARM/.launch/$p.sh\""
    if [ $first = 1 ]; then
      script="$script
  set w to new window with configuration cfg"
      first=0
    else
      script="$script
  delay $GAP
  new tab in w with configuration cfg"
    fi
  done
  osascript -e "$script
end tell" >/dev/null
else
  for p in $PROJECTS; do
    osascript -e "tell application \"Terminal\" to do script \"'$FARM/.launch/$p.sh'\"" >/dev/null
    sleep "$GAP"
  done
fi
echo "the barn is full. ⌃⌥Space to see who needs you; ./scripts/fill-the-barn.sh stop when done"
