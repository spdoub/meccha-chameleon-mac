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
# UE5 on DXMT: windowed + avoid D3D11 single-threaded device path (steam-on-m1-wine).
GAME_FLAGS="${GAME_FLAGS:--dx11 -force-d3d11-no-singlethreaded -screen-fullscreen 0}"

STEAM_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/Steam.exe"
STEAM_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
GAME_EXE="$STEAM_DIR/steamapps/common/MECCHA CHAMELEON/Chameleon/Binaries/Win64/PenguinHotel-Win64-Shipping.exe"

if [[ ! -f "$GAME_EXE" ]]; then
  echo "MECCHA CHAMELEON not installed yet — open Steam and install it first."
  open "$HOME/Applications/Steam on M1 Wine.app" 2>/dev/null \
    || bash "$(dirname "$0")/launch-steam.sh"
  exit 1
fi

# Ensure wrapper is deployed.
if [[ -x "$NOTPOP/scripts/06-install-wrapper.sh" ]]; then
  bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
fi

# DXMT (D3D11→Metal) — required for UE5's Feature Level 11.0 check.
WINEMETAL_SO="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix/winemetal.so"
WINEMAC_SO="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix/winemac.so"
if [[ ! -f "$WINEMETAL_SO" ]] && [[ -x "$NOTPOP/scripts/04-install-dxmt.sh" ]]; then
  echo "DXMT not found — installing (D3D11 → Metal)..."
  bash "$NOTPOP/scripts/04-install-dxmt.sh"
fi
if ! nm -gU "$WINEMAC_SO" 2>/dev/null | rg -q "macdrv_view_create_metal_view"; then
  echo "Patching winemac.so for DXMT Metal views..."
  bash "$(dirname "$0")/patch-winemac.sh"
fi

# Prefer DXMT fork if installed (fixes D3D11 present-path crash on UE5).
if [[ -x "$NOTPOP/scripts/07-build-dxmt-fork.sh" ]] \
    && [[ ! -f "$NOTPOP/.dxmt-fork-installed" ]] \
    && [[ ! -f "$HOME/Games/meccha-chameleon-gptk/.dxmt-fork-built" ]]; then
  echo ""
  echo "NOTE: Game may flash and exit until the DXMT fork is built."
  echo "      Run once (≈30–60 min): bash $NOTPOP/scripts/07-build-dxmt-fork.sh"
  echo ""
fi

export WINEESYNC=0
export WINEFSYNC=0
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d;steam_api64=n,b"

steam_running() {
  pgrep -f "Steam/Steam.exe|Steam\\\\Steam.exe" >/dev/null 2>&1 \
    || pgrep -f "Steam.exe" >/dev/null 2>&1
}

if ! steam_running; then
  echo "Starting Steam (Wine 11)..."
  bash "$NOTPOP/scripts/launch-steam.sh" --detach
  for _ in $(seq 1 45); do
    steam_running && break
    sleep 2
  done
  steam_running || { echo "Steam did not start — check ~/Applications/Steam on M1 Wine.app" >&2; exit 1; }
  sleep 5
fi

echo "Launching MECCHA CHAMELEON via steam.exe -applaunch $APP_ID"
echo "  Game flags: $GAME_FLAGS"

cd "$STEAM_DIR"
# IMPORTANT: Do NOT pass -cef-* / -noverifyfiles here — Steam forwards them to the game
# and UE5 aborts (see crash CommandLine in AppData/Local/Chameleon/Saved/Crashes).
exec /usr/bin/arch -x86_64 env \
  WINEPREFIX="$WINEPREFIX" \
  WINEESYNC=0 \
  WINEFSYNC=0 \
  WINEDEBUG="${WINEDEBUG:--all}" \
  WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
  "$WINE_BIN" "C:\\Program Files (x86)\\Steam\\Steam.exe" \
  -applaunch "$APP_ID" $GAME_FLAGS
