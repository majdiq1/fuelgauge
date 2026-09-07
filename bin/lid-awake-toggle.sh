#!/bin/bash
# Toggle lid-close sleep. Called by the click handler on the usage widget.
#
# If /etc/sudoers.d/lid-awake exists, this runs without a password.
# Otherwise it falls back to macOS's own administrator prompt, so the
# password goes to the system dialog — never through this script.

STATE_DIR="$HOME/.cache/ai-usage"
SINCE="$STATE_DIR/lid-awake-since"
WIDGET="$HOME/Library/Application Support/Übersicht/widgets/usage.jsx"
mkdir -p "$STATE_DIR"

is_on() { pmset -g | grep -qE 'SleepDisabled[[:space:]]+1'; }

set_sleep() {   # $1 = 0 or 1
  # -n means "never prompt": succeeds only if the sudoers rule is installed.
  if sudo -n /usr/bin/pmset -a disablesleep "$1" 2>/dev/null; then
    return 0
  fi
  osascript -e "do shell script \"pmset -a disablesleep $1\" with administrator privileges" >/dev/null 2>&1
}

if is_on; then
  set_sleep 0
  is_on || rm -f "$SINCE"
else
  set_sleep 1
  is_on && date +%s > "$SINCE"
fi

# Nudge the widget file so Übersicht reloads it right away instead of
# waiting out the 10-minute refresh.
touch "$WIDGET" 2>/dev/null
