#!/usr/bin/env bash
# Shared Wine 11 + MECCHA paths. Source from other scripts:
#   source "$(dirname "$0")/wine11-env.sh"

: "${HOME:=$(eval echo ~)}"
: "${PROJECT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${NOTPOP:=${NOTPOP:-$HOME/Games/steam-on-m1-wine}}"

# Homebrew installs wine-stable to /Applications; DXMT patches use ~/Applications.
# Resolve whichever exists, preferring the user-local copy.
if [[ -z "${WINE_APP:-}" ]]; then
  if [[ -x "$HOME/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine" ]]; then
    WINE_APP="$HOME/Applications/Wine Stable.app"
  elif [[ -x "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine" ]]; then
    WINE_APP="/Applications/Wine Stable.app"
  else
    WINE_APP="$HOME/Applications/Wine Stable.app"
  fi
fi
: "${WINE_BIN:=$WINE_APP/Contents/Resources/wine/bin/wine}"
: "${WINESERVER:=$WINE_APP/Contents/Resources/wine/bin/wineserver}"
: "${WINEPREFIX:=${WINEPREFIX:-$HOME/.wine-steam}}"
: "${INSTALL_APP_DIR:=${INSTALL_APP_DIR:-$HOME/Applications}}"
: "${DXMT_SRC:=${DXMT_SRC:-$HOME/dev/dxmt}}"
: "${DXMT_VENV:=${DXMT_VENV:-$HOME/dev/dxmt-venv311}}"
: "${APP_ID:=4704690}"
: "${LOG_DIR:=$PROJECT_ROOT/logs}"

export PROJECT_ROOT NOTPOP WINE_APP WINE_BIN WINESERVER WINEPREFIX INSTALL_APP_DIR DXMT_SRC DXMT_VENV APP_ID LOG_DIR

STEAM_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
GAME_EXE="$STEAM_DIR/steamapps/common/MECCHA CHAMELEON/Chameleon/Binaries/Win64/PenguinHotel-Win64-Shipping.exe"

ensure_notpop() {
  if [[ ! -d "$NOTPOP/scripts" ]]; then
    mkdir -p "$(dirname "$NOTPOP")"
    git clone --depth 1 https://github.com/notpop/steam-on-m1-wine.git "$NOTPOP"
  fi
}
