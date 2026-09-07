#!/usr/bin/env bash
#
# Collects plan usage from every provider script and prints one JSON blob
# for the usage widget.
#
#   bash ~/.ai-usage.sh            normal output
#   bash ~/.ai-usage.sh --debug    run each provider and show its raw output
#
# Providers live in ~/.config/dev-hud/providers/ — any executable file.
# Each one prints a single JSON object on stdout:
#
#   {"name":"Z.ai","tier":"max","windows":[
#      {"label":"5-hour","pct":12,"resets":1788616200000}]}
#
#   name    what to show as the heading
#   tier    optional badge, e.g. your plan name
#   pct     percent USED, 0-100 (the widget shows what's left)
#   resets  optional, epoch milliseconds
#
# On failure print {"name":"Z.ai","error":"no key"} — the widget shows it
# rather than pretending the provider isn't there.
#
# Files are run in filename order, so name them 10-, 20-, 30- to control it.
# Anything not executable is skipped, so `chmod -x` disables a provider.

set -uo pipefail

PROVIDERS="${DEV_HUD_PROVIDERS:-$HOME/.config/dev-hud/providers}"
CACHE="$HOME/.cache/ai-usage"
mkdir -p "$CACHE"

if [ "${1:-}" = "--debug" ]; then
  echo "providers directory: $PROVIDERS"
  if [ ! -d "$PROVIDERS" ]; then echo "  MISSING — nothing will show"; exit 1; fi
  for p in "$PROVIDERS"/*; do
    [ -f "$p" ] || continue
    if [ -x "$p" ]; then
      echo; echo "--- $(basename "$p") ---"
      "$p" 2>&1 | head -20
    else
      echo; echo "--- $(basename "$p") (disabled, not executable) ---"
    fi
  done
  exit 0
fi

# ── run every provider ───────────────────────────────────────────────────────
BLOBS=""
if [ -d "$PROVIDERS" ]; then
  for p in "$PROVIDERS"/*; do
    [ -x "$p" ] || continue
    OUT="$("$p" 2>/dev/null)"
    [ -n "$OUT" ] && BLOBS="$BLOBS$OUT"$'\n'
  done
fi

# ── lid-close state (read-only, no sudo) ─────────────────────────────────────
LID_ON=""
pmset -g 2>/dev/null | grep -qE 'SleepDisabled[[:space:]]+1' && LID_ON=1
BATT=$(pmset -g batt 2>/dev/null | sed -n '2p' | grep -oE '[0-9]+%' | head -1 | tr -d '%')
PLUGGED=""
pmset -g batt 2>/dev/null | grep -qi "AC Power" && PLUGGED=1
LID_SINCE=""
[ -f "$CACHE/lid-awake-since" ] && LID_SINCE=$(cat "$CACHE/lid-awake-since")

BLOBS="$BLOBS" LID_ON="$LID_ON" BATT="$BATT" PLUGGED="$PLUGGED" \
LID_SINCE="$LID_SINCE" python3 - <<'PY'
import json, os, time

now_ms = int(time.time() * 1000)
out = {"providers": []}

for line in (os.environ.get("BLOBS") or "").splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if not isinstance(d, dict) or not d.get("name"):
        continue
    if d.get("error"):
        out["providers"].append({"name": d["name"], "ok": False, "err": d["error"]})
        continue
    wins = []
    for w in d.get("windows") or []:
        p = w.get("pct")
        if p is None:
            continue
        wins.append({"label": w.get("label") or "window",
                     "pct": max(0, min(100, round(p))),
                     "resets": w.get("resets")})
    if wins:
        e = {"name": d["name"], "ok": True, "windows": wins}
        if d.get("tier"):
            e["tier"] = d["tier"]
        out["providers"].append(e)
    else:
        out["providers"].append({"name": d["name"], "ok": False,
                                 "err": "no data returned"})

lid = {"on": bool(os.environ.get("LID_ON")),
       "plugged": bool(os.environ.get("PLUGGED"))}
try:
    lid["batt"] = int(os.environ.get("BATT") or 0)
except ValueError:
    lid["batt"] = 0
since = os.environ.get("LID_SINCE") or ""
if lid["on"] and since.isdigit():
    lid["mins"] = int((time.time() - int(since)) / 60)
lid["risk"] = lid["on"] and not lid["plugged"]
out["lid"] = lid
out["now"] = now_ms

print(json.dumps(out))
PY
