#!/usr/bin/env bash
#
# Fallback: capture Wine debug output while launching via Steam applaunch
# to pinpoint where Steam/EOS authentication fails.
#
# Usage:
#   bash scripts/debug-auth.sh              # default channels
#   DEBUG_CHANNELS="+steam,+relay" bash scripts/debug-auth.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

TS="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/auth-debug-$TS.log"

# Channels useful for Steam IPC + EOS/relay + module load failures.
# Trim noise with -all prefix on uninteresting classes if log is huge.
CHANNELS="${DEBUG_CHANNELS:--all,+steam,+relay,+file,+module,+loaddll,+seh,+tid}"

echo "==> Auth debug launch (AppID $APP_ID)"
echo "    Log: $LOG"
echo "    WINEDEBUG=$CHANNELS"
echo ""
echo "Launching via steam.exe -applaunch (correct path). Reproduce the auth error,"
echo "then quit Steam/game and inspect the log for steam_api, EOS, relay, 401, token."
echo ""

require_steam

{
  echo "# MECCHA CHAMELEON auth debug — $(date -Iseconds)"
  echo "# WINEDEBUG=$CHANNELS"
  echo "# Command: steam.exe -applaunch $APP_ID ${GAME_FLAGS:--dx11}"
  echo ""
} >>"$LOG"

export WINEDEBUG="$CHANNELS"

# Apply steam_api override if previously configured (harmless if not).
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-steam_api64=n,b}"

set +e
run_game -applaunch "$APP_ID" ${GAME_FLAGS:--dx11} 2>&1 | tee -a "$LOG"
EXIT=${PIPESTATUS[0]}
set -e

echo ""
echo "==> Session ended (exit $EXIT). Scanning log for auth clues..."
echo ""

PATTERNS=(
  'authentication'
  'auth token'
  'EOS'
  'Epic'
  'steam_api'
  'SteamAPI'
  'Invalid'
  '401'
  '403'
  'logged in'
  'Relay'
  'PenguinHotel'
  'err:'
  'fixme:steam'
)

for pat in "${PATTERNS[@]}"; do
  hits=$(grep -i "$pat" "$LOG" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$hits" -gt 0 ]]; then
    echo "--- $pat ($hits lines) ---"
    grep -i "$pat" "$LOG" | tail -20
    echo ""
  fi
done

echo "Full log: $LOG"
echo ""
echo "Next steps if auth still fails:"
echo "  1. bash scripts/fix-steam-api-overrides.sh"
echo "  2. In Windows Steam: Epic account linked (Epic Games Launcher → link Steam)"
echo "  3. Clear Shipping.exe launch options: bash scripts/clear-launch-options.sh --fix --set \"-dx11\""
echo "  4. Share $LOG (grep -i steam_api / EOS sections)"

exit "$EXIT"
