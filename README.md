# herald

> Real audio notifications for Claude Code. Stop babysitting your terminal.

When Claude finishes a task, needs permission, or has a question — you hear it. Smart attention flow pings your phone if you don't respond. Reply from your phone and the answer auto-pastes into Claude.

Built for Windows. Zero external runtime dependencies (PowerShell 5 is built-in).

---

## Features

- **Real audio** — Uses pre-recorded voice packs from the [PeonPing ecosystem](https://github.com/PeonPing/og-packs) (50+ curated packs, 337+ community packs). Default: JARVIS (Paul Bettany-inspired, ElevenLabs quality).
- **Smart attention flow** — Fires a sound immediately on attention events (permission, question, input). If you don't respond within 45 seconds, sends a "Are you there?" push to your phone with Yes/Later buttons. All local sounds suspend until you reply — no spam.
- **Two-way mobile replies** — Tap Approve/Deny or Yes/No action buttons in the notification. Your reply auto-pastes into the Claude terminal. Powered by [ntfy.sh](https://ntfy.sh) (free, open-source).
- **Away/home mode** — Running errands? `herald --leaving` switches everything to phone. When you're back, `herald --home` plays "Welcome home, sir." and resumes local notifications.
- **Slash commands** — `/leaving-home` and `/iam-at-home` work directly inside Claude Code.
- **4 lifecycle hooks** — SessionStart, Stop, PostToolUse, UserPromptSubmit. Terminal banners for significant tools, silent for noise (Read/Grep/Glob).
- **Full CLI** — `herald.ps1 --status`, `--test`, `--packs`, `--set-pack`, `--toggle`, and more.

---

## Requirements

- Windows 10/11
- PowerShell 5.1 (built-in)
- Claude Code CLI

---

## Install

```powershell
git clone https://github.com/T-SCR/herald.git
cd herald
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Restart Claude Code after install. JARVIS will greet you.

---

## Sound Packs

Herald uses the PeonPing `openpeon.json` format. Browse and install packs:

```powershell
.\install-sounds.ps1 -List                          # Browse 337+ packs
.\install-sounds.ps1 -Packs jarvis-mk2,glados       # Install specific packs
.\herald.ps1 --packs                                 # List installed packs
.\herald.ps1 --set-pack jarvis-mk2                  # Switch active pack
.\herald.ps1 --set-volume 0.7                        # Adjust volume (0.0-1.0)
```

Packs are pulled from the [PeonPing registry](https://peonping.github.io/registry/index.json) and [og-packs](https://github.com/PeonPing/og-packs).

---

## Mobile Push (ntfy.sh)

Get notified on your phone when Claude needs attention — even when you've stepped away.

1. Install the [ntfy app](https://ntfy.sh) on iOS or Android (free)
2. Subscribe to two topics:
   - `your-topic` — outbound push (PC → phone)
   - `your-topic-in` — reply channel (phone → PC)
3. Configure:

```powershell
.\herald.ps1 --set-topic your-topic
```

Action buttons on notifications (Approve/Deny, Yes/No) auto-paste your reply into the Claude terminal via `engine/reply-listener.ps1`.

For private hosting, set `mobile.ntfy_server` in `config.json` to your own ntfy instance.

---

## Away / Home Mode

```powershell
.\herald.ps1 --leaving       # Away mode ON — all events push to phone, local silent
.\herald.ps1 --home          # Away mode OFF — resumes local + plays welcome back
```

Or use slash commands inside Claude Code:

```
/leaving-home
/iam-at-home
```

---

## CLI Reference

```powershell
.\herald.ps1 --status                    # All current settings
.\herald.ps1 --test                      # Fire all 4 event types + audio
.\herald.ps1 --mute / --unmute           # Quick silence / restore

# Audio
.\herald.ps1 --packs                     # List installed packs
.\herald.ps1 --set-pack <name>           # Switch active pack
.\herald.ps1 --set-volume 0.7            # Volume 0.0-1.0
.\herald.ps1 --toggle audio              # Toggle all sounds

# Tone
.\herald.ps1 --toggle tone               # Switch sir / Sharat (name) mode

# Alerts
.\herald.ps1 --toggle repeat             # Toggle are-you-there flow
.\herald.ps1 --set-interval 45           # Seconds before are-you-there push

# Notifications
.\herald.ps1 --toggle toast              # Toggle Windows toasts
.\herald.ps1 --toggle terminal           # Toggle terminal banners
.\herald.ps1 --toggle mobile             # Toggle phone push

# Away mode
.\herald.ps1 --leaving                   # Go away mode
.\herald.ps1 --home                      # Come home mode
```

---

## Configuration

All settings in `config.json`. Edit directly or use CLI toggles.

```json
{
  "enabled": true,
  "away_mode": false,
  "audio": {
    "enabled": true,
    "active_pack": "jarvis-mk2",
    "volume": 0.6,
    "play_on_tool": false
  },
  "alerts": {
    "repeat_enabled": true,
    "attention_wait_seconds": 45
  },
  "tone": {
    "mode": "sir",
    "name": "YourName"
  },
  "mobile": {
    "enabled": false,
    "ntfy_server": "https://ntfy.sh",
    "ntfy_topic": "",
    "reply_topic": "",
    "push_on_complete": false
  }
}
```

---

## How It Works

Herald hooks into Claude Code's lifecycle events via `~/.claude/settings.json`:

| Hook | When | What |
|------|------|------|
| `SessionStart` | Claude Code opens | JARVIS greeting |
| `Stop` | Claude finishes a turn | Classifies reason, plays sound, starts attention flow if needed |
| `PostToolUse` | After Write / Edit / Bash | Terminal banner (silent on Read/Grep/Glob) |
| `UserPromptSubmit` | You type anything | Clears attention state; plays acknowledge if returning from away |

The Stop hook reads the stop reason from the hook payload to classify the event (done / question / input / permission) and routes to the correct sound category in the active pack's `openpeon.json`.

---

## File Structure

```
herald/
├── install.ps1                  # One-command setup — registers hooks, copies config
├── install-sounds.ps1           # Download packs from registry + og-packs fallback
├── herald.ps1                   # CLI — all controls
├── config.json                  # Settings (edit directly or use CLI)
├── engine/
│   ├── play.ps1                 # WPF MediaPlayer audio engine
│   ├── repeat-alert.ps1         # Smart attention flow
│   ├── reply-listener.ps1       # ntfy reply poller — auto-pastes into terminal
│   ├── notify.ps1               # Dispatcher: audio + banner + toast
│   ├── toast.ps1                # Windows toast notifications
│   └── push.ps1                 # ntfy.sh push with action buttons
├── hooks/
│   ├── on-session-start.ps1     # SessionStart hook
│   ├── on-stop.ps1              # Stop hook
│   ├── on-tool-use.ps1          # PostToolUse hook
│   └── on-submit.ps1            # UserPromptSubmit hook
└── sounds/
    └── jarvis-mk2/              # Default pack (JARVIS voice)
        ├── openpeon.json        # Pack manifest
        └── sounds/              # MP3 files
```

---

## Uninstall

Remove the four hook entries from `~/.claude/settings.json` (those pointing to the herald directory), then delete the project folder.

---

## Roadmap

- [ ] Remote control from mobile — send commands to PC via ntfy relay (whitelisted)
- [ ] Wake-on-LAN — wake a sleeping laptop from phone
- [ ] Self-hosted ntfy — fully private push server option
- [ ] Taskbar status indicator
- [ ] macOS support (afplay / osascript)

---

## Contributing

Pull requests welcome. If you build a sound pack in the `openpeon.json` format, consider submitting it to the [PeonPing registry](https://github.com/PeonPing/og-packs).

For bugs and feature requests, open an issue.

---

## License

MIT — see [LICENSE](LICENSE).
