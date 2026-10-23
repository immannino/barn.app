# Sharing barn

Copy-paste posts for introducing barn to people who have never used an agent monitor or a
Stream Deck. Links preview with `site/assets/og.jpg` (regenerate with `./scripts/make-og.sh`).
Attach `build/demo/barn-demo.gif` or `.mp4` (from `./scripts/record-demo.sh`) wherever a
post allows media: a moving demo does more than any sentence.

**The one-liner:** barn is a free Mac menu bar app that shows which of your AI coding agents
needs you, and takes you to its terminal tab in one keystroke.

**The idea in plain words, for anyone new to it:** when you run several AI coding agents
(Claude Code, Codex, Gemini…) in different terminal tabs, they keep stopping to ask
permission or to say they're done, and you don't notice for ten minutes. barn watches all of
them and gives you a little board of glowing buttons, one per agent, like a Stream Deck: a
button lights up when its agent needs you, and clicking it (or pressing ⌃⌥Space) drops you
into the right tab.

Facts to keep straight: free and MIT-licensed · macOS 14+ · nothing to configure, it finds
agents on its own · no account, no telemetry; its only network request is a daily update
check you can turn off · `brew install --cask immannino/tap/barn` · https://barn.ope.cool

---

## X / Twitter

**Single post** (fits in 280):

> running 4 AI coding agents at once means one of them is always quietly waiting on you.
>
> I made barn: a tiny Mac menu bar app that lights up when an agent needs you. ⌃⌥Space jumps to its exact terminal tab.
>
> free + open source → barn.ope.cool

**Thread:**

> 1/ If you run Claude Code, Codex or Gemini in a few terminal tabs, you know the feeling: you come back 15 minutes later and one has been sitting on "allow this command?" the whole time.
>
> 2/ barn is a little Mac app that watches every agent for you. One dot per agent in your menu bar: 🔴 needs you, 🟢 done, 🔵 working.
>
> 3/ ⌃⌥Space opens a switcher. Pick an agent, hit ↵, and you're in its exact tab: Ghostty split, iTerm, Terminal, tmux pane or editor.
>
> 4/ Or float a deck of glass buttons on your screen, one per agent, like a Stream Deck for your AI. The one that needs you glows. Click it, you're there.
>
> 5/ No setup, no account, nothing leaves your Mac. Free and open source.
> barn.ope.cool

## Bluesky / Threads / Mastodon

> If you run more than one AI coding agent at a time, one is always waiting on you without you knowing.
>
> barn is a free Mac menu bar app that shows each agent's status (working, done, needs you) and jumps you to its terminal tab with ⌃⌥Space. Think Stream Deck, but the buttons are your agents.
>
> barn.ope.cool

## Reddit

Say up front that you made it, put the "what it is" in the first two lines, and lead with the
problem. Fits r/ClaudeAI, r/ClaudeCode, r/ChatGPTCoding, r/macapps, r/commandline (check
each sub's self-promo rules first; some want it in a weekly thread).

**Title:**

> I made a free Mac app that tells you which of your AI coding agents is waiting on you

**Body:**

> I usually have 3–5 agents going at once (Claude Code, Codex, Gemini) across terminal tabs, and I kept losing time to the one that had quietly stopped to ask "can I run this?" twenty minutes earlier.
>
> So I built **barn**, a little menu bar app that watches all of them:
>
> - **Menu bar dots**, one per agent: red = needs you, green = finished, blue = working.
> - **⌃⌥Space** opens a Spotlight-style switcher. Pick an agent and it takes you to the *exact* tab or split (Ghostty, iTerm, Terminal, tmux, VS Code/Cursor).
> - **A floating deck** of glass buttons, one per agent, like a Stream Deck. The one that needs you glows; click it to jump there.
> - **Notifications** when an agent needs you, if you want them.
>
> You don't launch agents through it or configure anything. It notices running agents on its own (Claude Code and Mistral Vibe report their exact state; Codex, Gemini, Copilot and a few others get exact state with one click; everything else is tracked by activity).
>
> No account, no telemetry. The only network request is a daily update check you can turn off. Free and MIT-licensed, macOS 14+.
>
> Site: https://barn.ope.cool
> Code: https://github.com/immannino/barn.app
> Install: `brew install --cask immannino/tap/barn`
>
> Happy to hear what agents or terminals you'd want it to support.

## Hacker News

**Title:**

> Show HN: Barn – see which of your AI coding agents needs you, from the menu bar

**First comment:**

> I run several coding agents in parallel and kept missing the moment one stopped for a permission prompt. barn is a small native macOS app (Swift, SwiftUI) that finds agent processes on its own: it reads the process table, Claude Code's and Mistral Vibe's session files, and optional hooks for Codex, Gemini and others. It shows each agent's state in the menu bar, a switcher (⌃⌥Space) and an optional floating deck.
>
> The part I'm happiest with is jumping to the *exact* terminal: it resolves the agent's tty to a Ghostty split, iTerm/Terminal tab or tmux pane via AppleScript and tmux, and hands focus over using macOS 14's cooperative activation.
>
> No telemetry; the only network call is a Sparkle update check. MIT licensed. Feedback on detection for other agents is very welcome.
>
> https://github.com/immannino/barn.app

## LinkedIn

> AI coding agents are fast, but they keep stopping to ask permission, and with several running at once it's easy to leave one waiting for half an hour.
>
> I built barn, a free, open-source Mac menu bar app that shows the status of every agent you're running and takes you to the one that needs you in one keystroke. Think of it as a Stream Deck for your AI agents.
>
> https://barn.ope.cool
