#!/usr/bin/env bash
# Start Windows Steam inside the GPTK prefix (for installing the game).

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

echo "==> Starting Windows Steam"
echo "    Prefix: $WINEPREFIX"
echo ""

SETUP="$HOME/Downloads/SteamSetup.exe"

if [[ ! -f "$STEAM_EXE_UNIX" ]]; then
  if [[ ! -f "$SETUP" ]]; then
    echo "Downloading Windows Steam installer to ~/Downloads..."
    curl -fL "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" \
      -o "$SETUP" || {
      echo "Download failed. Manually download from:" >&2
      echo "  https://store.steampowered.com/about/download" >&2
      echo "Save the Windows installer as ~/Downloads/SteamSetup.exe" >&2
      exit 1
    }
  fi
  echo "Steam not installed — running SteamSetup.exe..."
  echo "Follow the installer prompts in the window that appears."
  run_wine "$SETUP"
  exit 0
fi

# Kill any stuck Steam from a previous crash-loop.
if pgrep -f "steam.exe" >/dev/null 2>&1; then
  echo "Stopping previous Steam instance..."
  pkill -f "steam.exe|steamwebhelper" 2>/dev/null || true
  run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null || true
  sleep 2
fi

echo "Launching Steam (first open can take 2–5 minutes)..."
echo ""
echo "  • The terminal will show Wine messages — that's normal, ignore them."
echo "  • Check your Dock for a Steam or Wine icon and click it."
echo "  • If no window after 5 min, press Ctrl+C and run this script again."
echo ""

run_steam "$@"
