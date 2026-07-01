#!/usr/bin/env bash
#
# Primary fix: launch MECCHA CHAMELEON through Steam's process chain so the
# Steam + Epic Online Services auth handshake completes (required for online play).
#
# Do NOT launch PenguinHotel-Win64-Shipping.exe directly — that bypasses Steam/EOS
# and produces "invalid or missing authentication token for user".
#
# Usage:
#   bash scripts/launch-meccha.sh
#   GAME_FLAGS="-dx11 -windowed" bash scripts/launch-meccha.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

echo "==> MECCHA CHAMELEON — Steam applaunch (AppID $APP_ID)"
echo "    Prefix: $WINEPREFIX"
[[ "$DXMT_INSTALLED" == "1" ]] && echo "    Graphics: DXMT (D3D11→Metal)" || echo "    Graphics: D3DMetal"
echo ""

require_steam

if ! game_installed; then
  echo "Game binaries not found yet at:"
  echo "  $GAME_EXE_UNIX"
  echo ""
  echo "Install MECCHA CHAMELEON from Windows Steam first, then re-run this script."
  echo "You can open Steam with: bash scripts/launch-steam.sh"
  exit 1
fi

# Warn if someone left a direct-exe bypass in Steam launch options.
if bash "$ROOT/scripts/clear-launch-options.sh" --check-only 2>/dev/null | grep -q "DIRECT_EXE_BYPASS"; then
  echo "WARNING: Steam launch options bypass the launcher with Shipping.exe."
  echo "That breaks EOS auth. Clearing them now..."
  bash "$ROOT/scripts/clear-launch-options.sh" --fix
  echo ""
fi

STEAM_ARGS=( -applaunch "$APP_ID" )

# Game flags passed after -applaunch (still inside Steam's chain).
# UE5 on GPTK/DXMT usually needs -dx11.
GAME_FLAGS="${GAME_FLAGS:--dx11}"
if [[ -n "$GAME_FLAGS" ]]; then
  # shellcheck disable=SC2206
  STEAM_ARGS+=( $GAME_FLAGS )
fi

echo "Launch command:"
echo "  steam.exe ${STEAM_ARGS[*]}"
echo ""
echo "Steam will start (if not running), authenticate, then spawn the game."
echo "First launch can take several minutes under Rosetta + Wine."
echo ""

exec run_steam "${STEAM_ARGS[@]}"
