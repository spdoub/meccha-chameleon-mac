#!/usr/bin/env bash
#
# Launch MECCHA CHAMELEON via Steam applaunch on the Wine 11 stack.
# Uses ~/.wine-steam prefix (Wine 11 + CEF wrapper — actually boots Steam).

set -euo pipefail

APP_ID="${APP_ID:-4704690}"
NOTPOP="$HOME/Games/steam-on-m1-wine"
export WINE_APP="${WINE_APP:-$HOME/Applications/Wine Stable.app}"
export WINE_BIN="${WINE_BIN:-$WINE_APP/Contents/Resources/wine/bin/wine}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-steam}"
GAME_FLAGS="${GAME_FLAGS:--dx11}"

STEAM_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/Steam.exe"
GAME_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/MECCHA CHAMELEON/Chameleon/Binaries/Win64/PenguinHotel-Win64-Shipping.exe"

if [[ ! -f "$STEAM_EXE" ]]; then
  echo "Steam not ready — launching Steam first..."
  bash "$(dirname "$0")/launch-steam.sh"
  sleep 30
fi

if [[ ! -f "$GAME_EXE" ]]; then
  echo "MECCHA CHAMELEON not installed yet."
  echo "Steam should be open — log in and install the game, then run this again."
  open "$HOME/Applications/Steam on M1 Wine.app" 2>/dev/null || bash "$(dirname "$0")/launch-steam.sh"
  exit 1
fi

# Ensure wrapper is deployed.
if [[ -x "$NOTPOP/scripts/06-install-wrapper.sh" ]]; then
  bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
fi

export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d;steam_api64=n,b"

echo "Launching MECCHA CHAMELEON via steam.exe -applaunch $APP_ID $GAME_FLAGS"

cd "$WINEPREFIX/drive_c/Program Files (x86)/Steam"
exec /usr/bin/arch -x86_64 env WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
  "$WINE_BIN" explorer.exe "/desktop=steam-on-m1-wine,1470x956" \
  "C:\\Program Files (x86)\\Steam\\Steam.exe" \
  -applaunch "$APP_ID" $GAME_FLAGS \
  -no-cef-sandbox -cef-single-process -noverifyfiles
