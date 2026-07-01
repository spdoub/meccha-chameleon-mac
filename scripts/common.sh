#!/usr/bin/env bash
# Shared paths and Wine/GPTK environment for MECCHA CHAMELEON on Apple Silicon.

set -euo pipefail

export APP_ID="${APP_ID:-4704690}"
export GAME_NAME="${GAME_NAME:-MECCHA CHAMELEON}"

# Dedicated prefix — keeps Steam + game isolated from other Wine installs.
export WINEPREFIX="${WINEPREFIX:-$HOME/Library/Application Support/MecchaChameleonGPTK}"

# Gcenx prebuilt Game Porting Toolkit (vanilla Wine + Apple D3DMetal).
# Prefer user-local install (no admin); fall back to system /Applications.
if [[ -d "$HOME/Applications/Game Porting Toolkit.app" ]]; then
  GPTK_APP="$HOME/Applications/Game Porting Toolkit.app"
elif [[ -d "/Applications/Game Porting Toolkit.app" ]]; then
  GPTK_APP="/Applications/Game Porting Toolkit.app"
else
  GPTK_APP="${GPTK_APP:-$HOME/Applications/Game Porting Toolkit.app}"
fi
GPTK_WINE_DIR="$GPTK_APP/Contents/Resources/wine"
export WINE="${WINE:-$GPTK_WINE_DIR/bin/wine64}"
export WINESERVER="${WINESERVER:-$GPTK_WINE_DIR/bin/wineserver}"

STEAM_EXE_UNIX="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"

GAME_REL="steamapps/common/$GAME_NAME/Chameleon/Binaries/Win64/PenguinHotel-Win64-Shipping.exe"
GAME_EXE_UNIX="$WINEPREFIX/drive_c/Program Files (x86)/Steam/$GAME_REL"

# Project root (resolves regardless of which script sources this file).
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "$HOME/Games/meccha-chameleon-gptk")}"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
mkdir -p "$LOG_DIR"

# Performance / compatibility defaults for GPTK on Apple Silicon.
export MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}"
export WINEESYNC="${WINEESYNC:-1}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}"

# DXMT: prefix-local install; winemetal.so staged in .cache (never global during Steam).
DXMT_STORE="${PROJECT_ROOT}/.cache/dxmt-installed"
DXMT_MARKER="$WINEPREFIX/drive_c/windows/system32/d3d11.dll"
if [[ -f "$DXMT_MARKER" ]] && [[ -f "$DXMT_STORE/winemetal.so" ]]; then
  export DXMT_INSTALLED=1
else
  export DXMT_INSTALLED=0
fi

# DXMT overrides — only applied for game launch, not Steam.
export DXMT_OVERRIDES="dxgi,d3d11,d3d10core=n,b"

# Required for Steam's CEF UI on Wine/GPTK (prevents webhelper crash loop).
# See winetricks bug 49839 workaround on macOS.
export STEAM_CEF_ARGS="${STEAM_CEF_ARGS:--allosarches -cef-force-32bit -cef-in-process-gpu -cef-disable-sandbox}"

enable_dxmt_runtime() {
  # Temporarily install winemetal.so for DXMT game sessions only.
  [[ "$DXMT_INSTALLED" == "1" ]] || return 0
  local dest="$GPTK_WINE_DIR/lib/wine/x86_64-unix/winemetal.so"
  cp "$DXMT_STORE/winemetal.so" "$dest"
}

disable_dxmt_runtime() {
  rm -f "$GPTK_WINE_DIR/lib/wine/x86_64-unix/winemetal.so" 2>/dev/null || true
}

require_gptk() {
  if [[ ! -x "$WINE" ]]; then
    echo "Game Porting Toolkit not found at: $GPTK_APP" >&2
    echo "Run: bash install.sh" >&2
    exit 1
  fi
}

require_prefix() {
  if [[ ! -d "$WINEPREFIX/drive_c" ]]; then
    echo "Wine prefix not initialized: $WINEPREFIX" >&2
    echo "Run: bash install.sh" >&2
    exit 1
  fi
}

require_steam() {
  if [[ ! -f "$STEAM_EXE_UNIX" ]]; then
    echo "Windows Steam not found in prefix." >&2
    echo "Run install.sh or: bash scripts/launch-steam.sh (after placing SteamSetup.exe in ~/Downloads)" >&2
    exit 1
  fi
}

run_in_x86() {
  if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "Rosetta 2 is required. Run: softwareupdate --install-rosetta --agree-to-license" >&2
    exit 1
  fi
  /usr/bin/arch -x86_64 "$@"
}

run_wine() {
  require_gptk
  require_prefix
  run_in_x86 env \
    WINEPREFIX="$WINEPREFIX" \
    WINEESYNC="${WINEESYNC:-1}" \
    MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}" \
    WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}" \
    "$WINE" "$@"
}

run_steam() {
  require_steam
  disable_dxmt_runtime
  # shellcheck disable=SC2206
  local cef_args=( $STEAM_CEF_ARGS )
  # Steam must use D3DMetal — never pass DXMT overrides here.
  run_in_x86 env \
    WINEPREFIX="$WINEPREFIX" \
    WINEESYNC="${WINEESYNC:-1}" \
    MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}" \
    WINEDEBUG="${WINEDEBUG:--all}" \
    WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}" \
    "$WINE" "$STEAM_EXE_UNIX" "${cef_args[@]}" "$@"
}

run_game() {
  require_steam
  local overrides="${WINEDLLOVERRIDES:-}"
  if [[ "$DXMT_INSTALLED" == "1" ]]; then
    enable_dxmt_runtime
    overrides="${DXMT_OVERRIDES}${overrides:+;$overrides}"
  fi
  # shellcheck disable=SC2206
  local cef_args=( $STEAM_CEF_ARGS )
  run_in_x86 env \
    WINEPREFIX="$WINEPREFIX" \
    WINEESYNC="${WINEESYNC:-1}" \
    MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}" \
    WINEDEBUG="${WINEDEBUG:--all}" \
    WINEDLLOVERRIDES="$overrides" \
    "$WINE" "$STEAM_EXE_UNIX" "${cef_args[@]}" "$@"
  local exit_code=$?
  disable_dxmt_runtime
  return "$exit_code"
}

game_installed() {
  [[ -f "$GAME_EXE_UNIX" ]]
}
