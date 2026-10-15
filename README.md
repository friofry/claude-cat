# ClaudeCat

A pixel-art pet that sits on top of the macOS Dock and shows what your Claude Code sessions are doing,
in the spirit of the Codex desktop pet.

![Skins: cat, Clawd, slime in idle, working, waiting, happy and sleeping](docs/skins.png)

| Pet | Meaning |
| --- | --- |
| tapping paws (cat), marching (Clawd), breathing (slime) | a session is working |
| hopping, red `!`, orange card | a session waits for you (question, permission, plan approval) |
| happy eyes, sparkles, green card | a session just finished; the card shows its title and last reply |
| blinking | nothing running, recent activity |
| asleep, `z` | no activity for 20 minutes |

Each running, waiting or just-finished session gets a card above the pet, most urgent on top, at most
four. A running card shows what the session is doing right now ("Run the wallet unit tests",
"Правит Cards.swift") with a shimmer; a finished card shows the last reply until you dismiss it or
30 minutes pass. Hover a card for × (dismiss) and ↵ (open).

Click a card to open its session in Claude Desktop; click the pet to open the top card's session.
Sessions started with the `claude` CLI just bring Claude forward. Drag the pet anywhere; right-click it
for the session list, skin (cat, Clawd, slime), size, "hide all cards", "forget all sessions",
"back to the Dock" and quit.

The interface is in Russian; every string lives in `Sources/ClaudeCat/Strings.swift`.

## Install

Requires macOS 13+ and Xcode or the Swift toolchain.

```bash
./install.sh           # build, copy to ~/Applications, register hooks, launch
./install.sh --login   # same, and start at login
./uninstall.sh         # remove the app, LaunchAgent, hooks and state
```

`install.sh` backs up `~/.claude/settings.json` to `settings.json.bak-claude-cat` before adding the hooks,
and running it again replaces ClaudeCat's hooks instead of duplicating them. Claude Code picks up the
hooks in running sessions too.

## How it works

```
Claude Code ──hook JSON on stdin──▶ claude-cat-hook ──writes──▶ ~/.claude-cat/sessions/<id>.json
                                                                        │ directory events
                                                                        ▼
                                          ClaudeCat.app ◀── Board decides cards + pet mode
```

- **`claude-cat-hook`** runs for `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
  `PermissionRequest`, `Notification`, `Stop` and `SessionEnd`. It turns the event into a new session record
  and writes it atomically. It prints nothing and always exits 0, so it cannot change Claude's behavior,
  and it takes a few milliseconds because it links only Foundation.
- **Records hold facts, not words**: state, title (from the transcript's `custom-title`/`ai-title`
  entries, else the folder name), what the session is doing (`command`, `editing(file)`, …), why it
  waits, and the last reply as one plain line.
- **`ClaudeCat.app`** watches the directory, asks `Board` which sessions get cards and what the pet does
  (waiting > working > just finished > idle > asleep), and renders them.
- **Opening a session**: Claude Desktop keeps a `local_<uuid>.json` per Code session with the CLI id in
  `cliSessionId`, and opens one from `claude://code/continue?session=local_<uuid>`. This is not a
  documented interface; if it stops resolving, a click just brings Claude forward.

## Code

| Path | What |
| --- | --- |
| `Sources/ClaudeCatCore` | Foundation-only logic, fully unit-tested: session record and store, hook input and transitions, transcript titles, `Board`, desktop session index, sprites |
| `Sources/claude-cat-hook` | the hook executable, a few lines over the core |
| `Sources/ClaudeCat` | the AppKit app: pet window, cards, menu, strings, preferences |
| `Tests/ClaudeCatCoreTests` | XCTest suite for the core |

```bash
swift test                                                     # run the tests
swift run ClaudeCat --render-sheet docs/skins.png              # redraw the preview above
```

A new pet is one `PetSkin` struct in `Sprites.swift`, an entry in `Skins.all` and a name in `Strings.skin`.
