#!/bin/bash
# lid-awake.sh — let work keep running with the MacBook lid closed.
#
#   ~/.lid-awake.sh on       keep running when the lid shuts
#   ~/.lid-awake.sh off      back to normal (do this when you're done)
#   ~/.lid-awake.sh status   what's true right now
#
# This sets the kernel's SleepDisabled flag, which is the only thing that
# survives a lid close. Power assertions (caffeinate, Amphetamine sessions,
# ZCode's keep-awake) stop the idle timer but the lid overrides them.
#
# It needs sudo, so it will ask for your password. It stays on until you
# turn it off — closing a still-awake Mac in a bag will cook it and drain
# the battery, so turn it off when the job is done.

STATE_DIR="$HOME/.cache/ai-usage"
SINCE="$STATE_DIR/lid-awake-since"
mkdir -p "$STATE_DIR"

is_on() { pmset -g | grep -qE 'SleepDisabled[[:space:]]+1'; }

# Uses the sudoers rule if installed, otherwise asks for your password.
set_sleep() {
  if sudo -n /usr/bin/pmset -a disablesleep "$1" 2>/dev/null; then
    return 0
  fi
  echo "  (needs your password)"
  sudo pmset -a disablesleep "$1"
}

batt() {
  pmset -g batt | sed -n '2p' | grep -oE '[0-9]+%;[^;]*' | head -1
}

case "${1:-status}" in
  on)
    if is_on; then
      echo "Already on — the lid won't sleep this Mac."
    else
      echo "Turning off lid-close sleep…"
      set_sleep 1 || { echo "Failed."; exit 1; }
      date +%s > "$SINCE"
      echo "On. Work continues with the lid shut."
    fi
    echo
    echo "Battery: $(batt)"
    echo "Keep it on a hard surface with the vents clear — not in a bag."
    echo "Run '~/.lid-awake.sh off' when you're done."
    ;;

  off)
    if is_on; then
      echo "Restoring normal sleep…"
      set_sleep 0 || { echo "Failed."; exit 1; }
    fi
    rm -f "$SINCE"
    echo "Off. The lid puts it to sleep again."
    ;;

  status)
    if is_on; then
      echo "LID-CLOSE: work keeps running"
      if [ -f "$SINCE" ]; then
        S=$(cat "$SINCE"); N=$(date +%s); M=$(( (N - S) / 60 ))
        if [ "$M" -ge 60 ]; then echo "  on for $((M / 60))h $((M % 60))m"
        else echo "  on for ${M}m"; fi
      fi
    else
      echo "LID-CLOSE: sleeps (work stops)"
    fi
    echo "Battery: $(batt)"
    echo
    echo "Holding sleep off right now:"
    pmset -g assertions 2>/dev/null | sed -n '/Listed by owning process/,$p' \
      | grep -oE 'pid [0-9]+\([^)]*\)' | sort -u | sed 's/^/  /' | head -8
    ;;

  *)
    echo "usage: ~/.lid-awake.sh [on|off|status]"; exit 1 ;;
esac
