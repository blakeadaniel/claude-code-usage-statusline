# Claude Code Statusline — Setup Prompt

Paste the text below (everything inside the line) as a message to Claude Code to
install and configure the statusline.

---

Please set up the Claude Code statusline for me by following these steps:

**1. Copy the script**

Copy `statusline-command.sh` from this repo to `~/.claude/statusline-command.sh`
and make it executable (`chmod +x`).

**2. Ask me for my threshold preferences**

Ask me the following six questions (you can ask them all at once):

- **Session context — warning threshold** (default 20%): At what % of the 1M-token
  context window should the bar start turning yellow?
- **Session context — danger threshold** (default 50%): At what % should it turn red?
- **5h usage — warning threshold** (default 50%): At what % of your 5-hour rolling
  usage allowance should the bar start turning yellow?
- **5h usage — danger threshold** (default 90%): At what % should it turn red?
- **7d usage — warning threshold** (default 50%): At what % of your 7-day rolling
  usage allowance should the bar start turning yellow?
- **7d usage — danger threshold** (default 90%): At what % should it turn red?

Convert each percentage answer to a decimal fraction (e.g. 20% → 0.20) and edit
the following constants near the top of the Python block in
`~/.claude/statusline-command.sh`:

```
CONTEXT_WARN   = 0.20   ← session context warning
CONTEXT_DANGER = 0.50   ← session context danger
USAGE_5H_WARN   = 0.50  ← 5h warning
USAGE_5H_DANGER = 0.90  ← 5h danger
USAGE_7D_WARN   = 0.50  ← 7d warning
USAGE_7D_DANGER = 0.90  ← 7d danger
```

**3. Wire it into Claude Code settings**

Open `~/.claude/settings.json` (create it if it doesn't exist) and add or merge
this key at the top level:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

**4. Confirm**

Tell me what thresholds you set and confirm the `statusLine` entry is in
`~/.claude/settings.json`.
