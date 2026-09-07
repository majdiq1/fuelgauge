#!/usr/bin/env bash
rm -f "$HOME/Library/Application Support/Übersicht/widgets/usage.jsx"
rm -f "$HOME/.ai-usage.sh" "$HOME/.lid-awake.sh" "$HOME/.lid-awake-toggle.sh"
echo "Widget and scripts removed."
[ "${1:-}" = "--all" ] && { rm -rf "$HOME/.config/dev-hud"; echo "Providers removed."; } \
  || echo "Kept ~/.config/dev-hud/providers — pass --all to remove them."
echo "If you turned off lid sleep: sudo pmset -a disablesleep 0"
