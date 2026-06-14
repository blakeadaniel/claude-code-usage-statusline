# claude-code-statusline

A terminal status line for [Claude Code](https://claude.ai/code) that shows your current model, effort level, session context usage, and rolling rate-limit consumption — all in one compact bar.

```
Opus 4.8 [high] [██████░░░░░░░░░░░░░░] 18% 177k / 1000k tokens  │  5h: ████░░ 66% 4h46m  │  7d: ██░░░░ 30% 1d12h
```

The bar colors shift green → yellow → red as you approach configurable warning and danger thresholds.

## What it shows

| Segment | Description |
|---|---|
| `Opus 4.8 [high]` | Active model and effort level |
| `[██████░░░░░░░░░░░░░░] 18% 177k / 1000k tokens` | Session context window usage |
| `5h: ████░░ 66% 4h46m` | 5-hour rolling usage — percentage used, time until reset |
| `7d: ██░░░░ 30% 1d12h` | 7-day rolling usage — percentage used, time until reset |

The 5h and 7d gauges are fetched from Anthropic's rate-limit response headers and cached for 60 seconds in the background so they don't slow down the status line render.

## Install

```sh
npx claude-code-statusline
```

The installer will:

1. Show the default color thresholds
2. Ask if you want to customize them
3. Copy the script to `~/.claude/statusline-command.sh`
4. Add the `statusLine` entry to `~/.claude/settings.json`

Restart Claude Code after installing.

## Thresholds

Color thresholds control when each bar transitions from green → yellow → red. The defaults are:

| Meter | Warning | Danger |
|---|---|---|
| Session context window | 20% | 50% |
| 5-hour usage | 50% | 90% |
| 7-day usage | 50% | 90% |

To change them, re-run `npx claude-code-statusline` and answer `y` at the customize prompt, or edit the constants directly in `~/.claude/statusline-command.sh`:

```python
CONTEXT_WARN   = 0.20
CONTEXT_DANGER = 0.50
USAGE_5H_WARN   = 0.50
USAGE_5H_DANGER = 0.90
USAGE_7D_WARN   = 0.50
USAGE_7D_DANGER = 0.90
```

## Manual setup

If you prefer not to use `npx`, copy `statusline-command.sh` anywhere and add this to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash /path/to/statusline-command.sh"
}
```

## Requirements

- Claude Code
- bash
- Python 3 (standard library only)
- Node.js ≥ 18 (installer only)
