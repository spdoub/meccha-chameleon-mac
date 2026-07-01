#!/usr/bin/env bash
#
# Remove everything this project installed. Does NOT touch Homebrew or Rosetta.
#
# Usage: bash cleanup.sh

set -euo pipefail

echo ""
echo "MECCHA CHAMELEON GPTK — Cleanup"
echo "----------------------------------------------"

WINEPREFIX="${WINEPREFIX:-$HOME/Library/Application Support/MecchaChameleonGPTK}"
GPTK_APP="$HOME/Applications/Game Porting Toolkit.app"
STEAMSETUP="$HOME/Downloads/SteamSetup.exe"
PROJECT="$HOME/Games/meccha-chameleon-gptk"

echo "Will remove:"
echo ""
if [[ -d "$WINEPREFIX" ]]; then
  SZ=$(du -sh "$WINEPREFIX" 2>/dev/null | cut -f1)
  echo "  1. Wine prefix: $WINEPREFIX (~${SZ:-?})"
  echo "     Contains: Steam login, installed games, saved settings"
else
  echo "  1. (Wine prefix not found, skipping)"
fi

if [[ -d "$GPTK_APP" ]]; then
  SZ=$(du -sh "$GPTK_APP" 2>/dev/null | cut -f1)
  echo "  2. Game Porting Toolkit: $GPTK_APP (~${SZ:-?})"
else
  echo "  2. (GPTK app not found, skipping)"
fi

if [[ -f "$STEAMSETUP" ]]; then
  echo "  3. Steam installer: $STEAMSETUP"
else
  echo "  3. (SteamSetup.exe not found, skipping)"
fi

echo "  4. Project directory: $PROJECT"
echo ""
echo "Will NOT remove: Homebrew, Rosetta 2, winetricks, cabextract"
echo "----------------------------------------------"

printf "Type 'yes' to confirm: "
if [[ -e /dev/tty ]]; then
  read -r ans < /dev/tty
else
  read -r ans
fi
if [[ "$ans" != "yes" ]]; then
  echo "Cancelled — nothing was removed."
  exit 0
fi

echo ""

if [[ -d "$WINEPREFIX" ]]; then
  rm -rf "$WINEPREFIX" && echo "Removed Wine prefix"
fi

if [[ -d "$GPTK_APP" ]]; then
  rm -rf "$GPTK_APP" && echo "Removed Game Porting Toolkit"
fi

if [[ -f "$STEAMSETUP" ]]; then
  rm -f "$STEAMSETUP" && echo "Removed SteamSetup.exe"
fi

echo ""
echo "Cleanup complete."
echo ""
echo "To also remove the project scripts: rm -rf $PROJECT"
echo "To remove winetricks/cabextract: brew uninstall winetricks cabextract"
