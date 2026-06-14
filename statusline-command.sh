#!/usr/bin/env bash
# Claude Code statusLine — model, effort, context-window bar, 5h/7d usage from Anthropic headers.
# Renders e.g.:  Opus 4.8 [high] [██████░░░░░░░░░░░░░░] 18% 177k / 1000k tokens  │  5h: ████░░ 66% 4h46m  │  7d: ██░░░░ 30% 1d12h
input=$(cat)

# ── Unified rate-limit headers (cached 60 s, async background refresh) ───────
LIMITS_CACHE="/tmp/claude-unified-limits-cache.json"
CREDS_FILE="${HOME}/.claude/.credentials.json"
CACHE_TTL=60

now_s=$(date +%s)
cache_age=9999
if [[ -f "$LIMITS_CACHE" ]]; then
    cache_mtime=$(stat -c %Y "$LIMITS_CACHE" 2>/dev/null || echo 0)
    cache_age=$(( now_s - cache_mtime ))
fi

if [[ $cache_age -gt $CACHE_TTL && -f "$CREDS_FILE" ]]; then
    (
        python3 - "$CREDS_FILE" <<'PY' > "${LIMITS_CACHE}.tmp" 2>/dev/null \
            && mv "${LIMITS_CACHE}.tmp" "$LIMITS_CACHE"
import json, urllib.request, sys
with open(sys.argv[1]) as f:
    token = json.load(f)["claudeAiOauth"]["accessToken"]
req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=json.dumps({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "x"}],
    }).encode(),
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "claude-code-20250219",
    },
    method="POST",
)
try:
    resp = urllib.request.urlopen(req, timeout=8)
    hdrs = dict(resp.headers)
except urllib.error.HTTPError as e:
    hdrs = dict(e.headers)
result = {k: v for k, v in hdrs.items() if "ratelimit-unified" in k.lower()}
if result:
    print(json.dumps(result))
PY
    ) &
    disown $!
fi

LIMITS_JSON=""
[[ -f "$LIMITS_CACHE" ]] && LIMITS_JSON=$(cat "$LIMITS_CACHE")

# ── Render ────────────────────────────────────────────────────────────────────
EFFORT="${CLAUDE_EFFORT:-?}" \
LIMITS_JSON="$LIMITS_JSON" \
python3 - "$input" <<'PY'
import json, os, sys, datetime

CONTEXT_MAX = 1_000_000
BAR_WIDTH    = 20

# Thresholds: fraction at which the bar transitions green→yellow (warn) and yellow→red (danger)
CONTEXT_WARN   = 0.20
CONTEXT_DANGER = 0.50
USAGE_5H_WARN   = 0.50
USAGE_5H_DANGER = 0.90
USAGE_7D_WARN   = 0.50
USAGE_7D_DANGER = 0.90

try:
    data = json.loads(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].strip() else {}
except Exception:
    data = {}

model      = (data.get("model") or {}).get("display_name") or "Claude"
effort     = os.environ.get("EFFORT", "?")
transcript = data.get("transcript_path") or ""

# ── Current context usage ────────────────────────────────────────────────────
used = None
if transcript and os.path.exists(transcript):
    try:
        last = None
        with open(transcript) as fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                u = (rec.get("message") or {}).get("usage") or rec.get("usage")
                if isinstance(u, dict) and ("input_tokens" in u or "cache_read_input_tokens" in u):
                    last = u
        if last:
            used = (last.get("input_tokens", 0)
                    + last.get("cache_creation_input_tokens", 0)
                    + last.get("cache_read_input_tokens", 0))
    except Exception:
        used = None

# ── Colors ────────────────────────────────────────────────────────────────────
RESET  = "\033[0m"
GREY   = "\033[90m"
BOLD   = "\033[1m"
GREEN  = (40, 200, 40)
YELLOW = (230, 210, 0)
RED    = (220, 40, 40)

def _lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def color_for(frac, warn=0.20, danger=0.50):
    if frac <= warn:
        r, g, b = _lerp(GREEN, YELLOW, frac / warn)
    elif frac <= danger:
        r, g, b = _lerp(YELLOW, RED, (frac - warn) / (danger - warn))
    else:
        r, g, b = RED
    return f"\033[38;2;{r};{g};{b}m"

def usage_color(frac, warn, danger):
    return color_for(frac, warn=warn, danger=danger)

def kfmt(n):
    return f"{round(n / 1000)}k"

def usage_bar(frac, warn, danger, width=6):
    filled = max(0, min(width, round(frac * width)))
    cells = []
    for j in range(width):
        if j < filled:
            cells.append(f"{usage_color((j + 1) / width, warn, danger)}█")
        else:
            cells.append(f"{GREY}░")
    return "[" + "".join(cells) + RESET + "]"

def fmt_countdown(ts):
    """Unix timestamp → compact countdown string."""
    secs = max(0, int(ts) - int(datetime.datetime.now(datetime.timezone.utc).timestamp()))
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        h, m = divmod(secs, 3600)
        return f"{h}h{m // 60:02d}m" if m >= 60 else f"{h}h"
    d, rem = divmod(secs, 86400)
    return f"{d}d{rem // 3600}h"

# ── Context window bar ────────────────────────────────────────────────────────
parts = [f"{BOLD}{model}{RESET}", f"{GREY}[{effort}]{RESET}"]

if used is not None:
    frac   = used / CONTEXT_MAX
    pct    = frac * 100
    filled = max(0, min(BAR_WIDTH, round(frac * BAR_WIDTH)))
    cells  = []
    for j in range(BAR_WIDTH):
        if j < filled:
            cells.append(f"{color_for((j + 1) / BAR_WIDTH, warn=CONTEXT_WARN, danger=CONTEXT_DANGER)}█")
        else:
            cells.append(f"{GREY}░")
    bar = "".join(cells) + RESET
    clr = color_for(frac, warn=CONTEXT_WARN, danger=CONTEXT_DANGER)
    parts.append(f"[{bar}]")
    parts.append(f"{clr}{pct:.0f}%{RESET}")
    parts.append(f"{GREY}{kfmt(used)} / {kfmt(CONTEXT_MAX)} tokens{RESET}")
else:
    empty = f"{GREY}{'░' * BAR_WIDTH}{RESET}"
    parts.append(f"[{empty}]")
    parts.append(f"{GREY}-- / {kfmt(CONTEXT_MAX)} tokens{RESET}")

# ── 5h / 7d from Anthropic unified rate-limit headers ────────────────────────
SEP = f"  {GREY}│{RESET}  "
limits_raw = os.environ.get("LIMITS_JSON", "")
h = {}
if limits_raw:
    try:
        h = json.loads(limits_raw)
    except Exception:
        pass

u5h    = h.get("anthropic-ratelimit-unified-5h-utilization")
u7d    = h.get("anthropic-ratelimit-unified-7d-utilization")
reset5 = h.get("anthropic-ratelimit-unified-5h-reset")
reset7 = h.get("anthropic-ratelimit-unified-7d-reset")

if u5h is not None:
    frac5 = float(u5h)
    clr5  = usage_color(frac5, USAGE_5H_WARN, USAGE_5H_DANGER)
    pct5  = f"{clr5}{frac5 * 100:.0f}%{RESET}"
    b5    = usage_bar(frac5, USAGE_5H_WARN, USAGE_5H_DANGER)
    cd5   = f" {GREY}{fmt_countdown(reset5)}{RESET}" if reset5 else ""
    parts.append(f"{SEP}{GREY}5h:{RESET} {b5} {pct5}{cd5}")

if u7d is not None:
    frac7 = float(u7d)
    clr7  = usage_color(frac7, USAGE_7D_WARN, USAGE_7D_DANGER)
    pct7  = f"{clr7}{frac7 * 100:.0f}%{RESET}"
    b7    = usage_bar(frac7, USAGE_7D_WARN, USAGE_7D_DANGER)
    cd7   = f" {GREY}{fmt_countdown(reset7)}{RESET}" if reset7 else ""
    parts.append(f"{SEP}{GREY}7d:{RESET} {b7} {pct7}{cd7}")

sys.stdout.write(" ".join(parts))
PY
