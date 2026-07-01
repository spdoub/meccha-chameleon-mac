#!/usr/bin/env bash
#
# Idempotent preflight before every launch — safe after days/weeks idle.
# Clears stale locks, aligns the prefix, redeploys the CEF wrapper, and
# verifies WoW64 + DXMT are still intact (e.g. after brew upgrade wine-stable).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

ensure_notpop

# Homebrew wine-stable lands in /Applications; patches live in ~/Applications.
if [[ -d "/Applications/Wine Stable.app" && ! -e "$HOME/Applications/Wine Stable.app" ]]; then
  mkdir -p "$HOME/Applications"
  ln -sf "/Applications/Wine Stable.app" "$HOME/Applications/Wine Stable.app"
  export WINE_APP="$HOME/Applications/Wine Stable.app"
  export WINE_BIN="$WINE_APP/Contents/Resources/wine/bin/wine"
fi

[[ -x "$WINE_BIN" ]] || {
  echo "Wine not found at $WINE_APP — run: bash install.sh" >&2
  exit 1
}

# Gatekeeper quarantine returns after re-downloading Wine.
if xattr -l "$WINE_APP" 2>/dev/null | grep -q com.apple.quarantine; then
  xattr -dr com.apple.quarantine "$WINE_APP"
fi

# Prefix must exist and have WoW64 for Steam.
if [[ ! -d "$WINEPREFIX/drive_c/windows" ]]; then
  echo "Wine prefix missing — run: bash install.sh" >&2
  exit 1
fi
wow64_count=0
if [[ -d "$WINEPREFIX/drive_c/windows/syswow64" ]]; then
  wow64_count=$(find "$WINEPREFIX/drive_c/windows/syswow64" -maxdepth 1 | wc -l | tr -d ' ')
  wow64_count=$((wow64_count - 1))
fi
if (( wow64_count < 100 )); then
  echo "WoW64 broken (syswow64=$wow64_count) — run: bash scripts/fix-wow64-steam.sh --fix" >&2
  exit 1
fi

# Align prefix with installed Wine after idle / upgrade (fixes version mismatch 931/930).
/usr/bin/arch -x86_64 env WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all \
  "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true

# Chromium SingletonLock left by crashes → next launch is silent / invisible.
HTMLCACHE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Steam/htmlcache"
if [[ -d "$HTMLCACHE" ]]; then
  find "$HTMLCACHE" -maxdepth 2 \
    \( -name 'Singleton*' -o -name '*.lock' \) \
    -delete 2>/dev/null || true
fi

# Steam may restore real steamwebhelper and break the CEF wrapper.
if [[ -x "$NOTPOP/scripts/06-install-wrapper.sh" ]]; then
  bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
fi

# brew upgrade --cask wine-stable clobbers DXMT DLLs + winemac patch.
WINEMAC_SO="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix/winemac.so"
D3D11_DLL="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-windows/d3d11.dll"
if [[ -f "$ROOT/.dxmt-fork-built" ]]; then
  d3d_size=$(stat -f%z "$D3D11_DLL" 2>/dev/null || echo 0)
  if (( d3d_size < 15000000 )) || ! nm -gU "$WINEMAC_SO" 2>/dev/null | grep -q macdrv_view_create_metal_view; then
    echo "DXMT fork missing after Wine update — rebuilding (may take a while)..."
    bash "$ROOT/scripts/patch-winemac.sh"
    bash "$ROOT/scripts/build-dxmt-fork.sh"
  fi
fi

# shellcheck source=meccha-common.sh
source "$ROOT/scripts/meccha-common.sh"
meccha_check_wine_version || true

# Game is installed but graphics fork missing → fail fast with a clear message.
meccha_require_dxmt_for_play "$ROOT" "$GAME_EXE" || exit 1
