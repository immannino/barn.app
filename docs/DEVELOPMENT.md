# Developing barn

## Build and run

```sh
make run            # build barn.app (ad-hoc signed) and launch it
swift test          # unit tests
make install        # build into /Applications and launch
make cli            # link /Applications/barn.app/Contents/MacOS/barn → /usr/local/bin/barn
make icon           # regenerate Resources/AppIcon.icns from scripts/make-icon.swift
```

Requirements: Xcode 26 (macOS 26 SDK, for Liquid Glass) and Swift 6. The app runs on macOS 14+. Before 26 it falls back to frosted materials.

Launch flags, for development and screenshots (`open build/barn.app --args …`):

| flag | |
|---|---|
| `--switcher` / `--deck` | open the switcher or deck on launch |
| `--settings <tab>` | open settings on `general`, `looks`, `shortcuts`, `agents` or `about` |
| `--focus <pid>` | run the jump-to-terminal path for one agent |
| `--demo` | made-up agents, no scanning (marketing screenshots). Jumps do nothing. |
| `--demo --stress` | worst case for perf: 24 agents, every effect on every state, a state change every 0.25 s. |
| `--demo --demo-script` | a ~17 s scripted story over a brand backdrop, then quits. `./scripts/record-demo.sh` records it to `build/demo/` (MP4, GIF, poster); run that on macOS 26 for Liquid Glass. |

For a live demo with real agents, `./scripts/fill-the-barn.sh` opens five silly Claude Code sessions in toy repos at `~/barn-farm`. Some ask you a question or for permission and some just finish. `./scripts/fill-the-barn.sh stop` quits them.

CLI modes of the same binary: `barn --dump` prints what detection sees, and `barn hook <harness>` is the hook handler. The log is at `~/Library/Logs/barn.log`.

## Performance

barn lives in the menu bar all day, so it should sit near 0% CPU. `./scripts/perf.sh` runs the demo in a
few scenarios (menu bar only, deck, list, `--stress`) and fails if CPU goes over a budget. CI runs it on
every push and puts the table in the run summary, with a `sample` profile of each scenario as an artifact.

Animations stay cheap by running in Core Animation (`LookEffects.swift`, `StateDot`, `Marquee`). The window
server plays them, so barn does no work between changes. Avoid `TimelineView(.animation)`,
`.repeatForever()` and similar per-frame SwiftUI updates for anything that runs while idle: each one
re-lays out the whole deck every frame.

## How detection works

You don't have to start your agents through barn. Every second, a background queue combines these sources, most trusted first:

1. **`~/.barn/status/<pid>.json`**: `{"state":"working|waiting|idle","detail":"…","title":"…"}`. It's written by `barn hook` or anything else. A report from a child process (an npm wrapper's native binary) counts toward the nearest tracked parent. barn deletes files whose process has exited.
2. **The agent's own session files:**
   - **Claude Code**: `~/.claude/sessions/<pid>.json` has `status: busy|idle|waiting` plus `waitingFor`. The transcript tail supplies `ai-title`/`custom-title` and the current tool.
   - **Mistral Vibe**: `~/.vibe/logs/session/active/*.lock` maps pid to session id. `session_<date>_<id8>/meta.json` has the title and cwd, and `messages.jsonl` has the last role and tool calls. A pending tool call with a quiet CPU means needs you.
3. **Process activity**: a recognized process using more than 4% CPU in the last 4 seconds counts as working.

**Recognition.** barn lists every process with `sysctl KERN_PROC_ALL`. For tty-attached processes you own, it matches argv (`KERN_PROCARGS2`) against `AgentKind`: argv[0]'s basename, or for node/bun/deno/python the script or package path in the next few arguments. A matched process whose parent also matched is folded into that parent. cwd comes from `proc_pidinfo`. The host app comes from walking parent pids to the first `NSRunningApplication`, or tmux.

**ready.** A working → idle transition shows as **ready** until you jump to that agent.

## Hooks

`barn hook <harness>` reads the hook's JSON on stdin. It maps `hook_event_name` (Claude style: `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `Notification`, `Stop`, `SessionEnd`…; Gemini: `BeforeAgent`, `AfterAgent`, `Notification`; Copilot: `agentStop`) to a state. It then writes the status file for the nearest parent process that isn't a shell, and always exits 0 right away.

Settings → agents → **set up** (`Integrations.swift`) merges these entries into each tool's config:

| Tool | Config | Events |
|---|---|---|
| Codex | `~/.codex/hooks.json` (trust once via `/hooks`) | UserPromptSubmit, PermissionRequest `*`, Stop, SessionEnd |
| Gemini CLI | `~/.gemini/settings.json` | BeforeAgent, Notification `*`, AfterAgent, SessionEnd |
| Factory Droid | `~/.factory/settings.json` | UserPromptSubmit, Notification, Stop, SessionEnd |
| Qwen Code | `~/.qwen/settings.json` | UserPromptSubmit, Notification, Stop, SessionEnd |
| Auggie | `~/.augment/settings.json` | PreToolUse, Stop, SessionEnd |
| Copilot CLI | `~/.copilot/hooks/barn.json` (barn's own file) | userPromptSubmitted, preToolUse, agentStop |

Every other key is preserved. The original is backed up once to `<file>.barn-backup`, files that aren't plain JSON are refused, and removal takes out only entries whose command ends in `hook <id>`. On launch, hooks pointing at an old barn.app path get re-pointed.

Aider has no hooks file: `aider --notifications --notifications-command "barn hook aider"`.

## Jumping to the terminal

| Host | How |
|------|-----|
| Ghostty 1.3+ | AppleScript windows → tabs → terminals. barn tries a cached id for the tty, then the only terminal in the cwd, then a unique title match. If none of those works, it writes an invisible OSC 2 title to the agent's tty, sees which terminal takes it, and restores it. Then it raises the window, selects the tab, and focuses the split. |
| tmux | the pane by tty → `select-window` and `select-pane`, then `switch-client` on the most relevant attached client. It then raises the terminal running that client, using the rows here. |
| iTerm2 / Terminal.app | matched by tty |
| VS Code / Cursor / Windsurf / Zed | opens the cwd with that app, which raises the matching window |
| anything else | activates the host app |

macOS 14+ uses cooperative activation: a background app can't bring another app forward. barn activates itself on the user's click or hotkey, then calls `yieldActivation(to:)` to hand activation to the terminal.

## Layout

```
Sources/barn/main.swift   calls BarnApp.main() (all code is in BarnKit so tests can import it)
Sources/BarnKit/
  App.swift               app delegate, menu bar, global shortcuts, CLI modes, dev flags
  AgentStore.swift        1s poll; merges sources; ready/acknowledge; --demo data
  ProcessScanner.swift    sysctl/libproc: processes, argv, cwd, tty, host app, CPU, ancestry
  ClaudeSessions.swift    ~/.claude/sessions + transcript tail
  AgentSources.swift      Mistral Vibe sessions, ~/.barn/status files
  HookCommand.swift       `barn hook <harness>`
  Integrations.swift      one-click hook install/remove
  Notifier.swift          needs-you / finished notifications
  Chimes.swift            optional synthesized sounds + trackpad haptics
  Look.swift / LookEffects.swift / LooksPane.swift   per-state looks: model + JSON sharing, effects, editor
  DeckStyle.swift         deck layout/size/font options, list rows, marquee
  Focus.swift             jump to the exact terminal tab or tmux pane
  Launcher.swift          switcher panel
  Deck.swift              floating deck
  SettingsWindow.swift    settings UI + shortcut recorder
  Settings.swift          preferences, KeyCombo, system-shortcut conflict check
  HotKey.swift            Carbon global hotkeys (no Accessibility permission needed)
  Brand.swift / Glass.swift   palette, grain, mesh backdrop, wordmark; Liquid Glass helpers
Tests/barnTests/          classification, hook mapping, config merge
scripts/                  build-app, release, make-icon(s), set-owner
site/                     barn.ope.cool (GitHub Pages)
packaging/barn.rb         Homebrew cask template
```

## Adding an agent

1. Add an `AgentKind` to `AgentKind.builtIns` (`Agent.swift`): id, display name, badge, executable names, package fragments.
2. Add a case to `ClassifyTests`.
3. If it has hooks, add an `Integration` and check its event names map in `HookCommand.state(for:)`.
4. If it writes live session files, add a reader next to `VibeSessions` and merge it in `AgentStore.refresh()`.
