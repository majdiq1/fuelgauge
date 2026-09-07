#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGETS="$HOME/Library/Application Support/Übersicht/widgets"
say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
[ "$(uname)" = "Darwin" ] || { echo "macOS only."; exit 1; }

say "Übersicht"
if [ -d "/Applications/Übersicht.app" ]; then ok "already installed"
elif command -v brew >/dev/null 2>&1; then brew install --cask ubersicht && ok "installed"
else warn "install it from https://tracesof.net/uebersicht/ then run this again"; exit 1; fi
mkdir -p "$WIDGETS"

say "Widget"
cp "$SRC/widget/usage.jsx" "$WIDGETS/usage.jsx"; ok "usage.jsx"

say "Scripts"
for f in ai-usage.sh lid-awake.sh lid-awake-toggle.sh; do
  cp "$SRC/bin/$f" "$HOME/.$f"; chmod +x "$HOME/.$f"; ok "~/.$f"
done
mkdir -p "$HOME/.cache/ai-usage"

say "Providers"
mkdir -p "$HOME/.config/dev-hud/providers"
for f in "$SRC"/providers/*; do
  n="$(basename "$f")"; d="$HOME/.config/dev-hud/providers/$n"
  if [ -e "$d" ]; then ok "$n (kept yours)"; else
    cp "$f" "$d"
    case "$n" in *.example) chmod 644 "$d";; *) chmod +x "$d";; esac
    ok "$n"
  fi
done
echo
echo "  Check what they report:  bash ~/.ai-usage.sh --debug"

say "Done"
echo "  Übersicht menu bar → Refresh All Widgets"
echo "  Remove it again with ./uninstall.sh"
