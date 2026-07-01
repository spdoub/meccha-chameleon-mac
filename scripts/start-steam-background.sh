#!/usr/bin/env bash
# Launch Steam detached — no terminal spam, brings window to front.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

LOG="$LOG_DIR/steam-$(date +%Y%m%d-%H%M%S).log"

# Clean slate.
pkill -f "steam.exe|steamwebhelper" 2>/dev/null || true
run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null || true
sleep 2

require_steam

echo "Starting Steam in background (log: $LOG)..."
echo "CEF args: $STEAM_CEF_ARGS"
echo ""

{
  echo "# Steam background launch — $(date -Iseconds)"
  echo "# Args: $STEAM_CEF_ARGS"
  echo ""
} >>"$LOG"

# shellcheck disable=SC2206
nohup bash -c "source '$ROOT/scripts/common.sh' && run_steam" >>"$LOG" 2>&1 &
STEAM_PID=$!
disown "$STEAM_PID" 2>/dev/null || true

for i in $(seq 1 30); do
  sleep 5
  if pgrep -f "steamwebhelper" >/dev/null 2>&1; then
    osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  repeat with proc in (every application process whose visible is true)
    set n to name of proc
    if n contains "wine" or n contains "Wine" or n contains "Steam" then
      set frontmost of proc to true
      exit repeat
    end if
  end repeat
end tell
APPLESCRIPT
    echo "Steam is running (webhelper active after $((i * 5))s)."
    echo "Log: $LOG"
    exit 0
  fi
done

echo "Steam process started (pid $STEAM_PID) but UI may still be loading."
echo "Check Dock for Steam/Wine icon. Log: $LOG"
