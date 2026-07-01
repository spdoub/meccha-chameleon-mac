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

run_steam "$@"
