#!/usr/bin/env bash
#
# Fallback: ensure steam_api64.dll resolves through the running Steam client.
# Use if applaunch still fails auth after clearing direct-exe launch options.
#
# Sets per-prefix DLL override: steam_api64 = native,builtin
# (native = game's/Steam's DLL first; builtin = Wine stub fallback)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

echo "==> Configuring steam_api64.dll overrides"
echo "    Prefix: $WINEPREFIX"
echo ""

require_prefix

# Method 1: WINEDLLOVERRIDES env (session-level, appended to common.sh exports)
export WINEDLLOVERRIDES="steam_api64=n,b${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
echo "Set WINEDLLOVERRIDES=$WINEDLLOVERRIDES"

# Method 2: Persist in prefix registry (DllOverrides)
run_wine reg add 'HKCU\Software\Wine\DllOverrides' /v steam_api64 /t REG_SZ /d native,builtin /f >/dev/null 2>&1 || true
echo "Registry: HKCU\\Software\\Wine\\DllOverrides\\steam_api64 = native,builtin"

# Method 3: Also set steam_api (32-bit stub) for completeness
run_wine reg add 'HKCU\Software\Wine\DllOverrides' /v steam_api /t REG_SZ /d native,builtin /f >/dev/null 2>&1 || true

# Report what the game ships with
GAME_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/$GAME_NAME"
if [[ -d "$GAME_DIR" ]]; then
  echo ""
  echo "steam_api64.dll locations under game install:"
  find "$GAME_DIR" -iname 'steam_api64.dll' 2>/dev/null | while read -r f; do
    echo "  $f ($(wc -c < "$f" | tr -d ' ') bytes)"
  done
  STEAM_CLIENT_DLL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam_api64.dll"
  if [[ -f "$STEAM_CLIENT_DLL" ]]; then
    echo ""
    echo "Steam client steam_api64.dll present — native,builtin should prefer it when Steam is running."
  else
    echo ""
    echo "NOTE: Steam client steam_api64.dll not found. Ensure Steam is running before launch."
  fi
else
  echo ""
  echo "Game not installed yet — overrides are set for when you install."
fi

echo ""
echo "Done. Re-launch with: bash scripts/launch-meccha.sh"
echo "If auth still fails, run: bash scripts/debug-auth.sh"
