#!/usr/bin/env bash
#
# Install DXMT (D3D11 → Metal) into the Wine PREFIX only.
# Steam needs D3DMetal's global DLLs — never patch GPTK globally.
# winemetal.so is staged in .cache and loaded only at game launch.
#
# Usage:
#   bash scripts/setup-dxmt.sh          # install DXMT into prefix
#   bash scripts/setup-dxmt.sh --undo   # remove DXMT

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

DXMT_VER="v0.80"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/${DXMT_VER}/dxmt-${DXMT_VER}-builtin.tar.gz"
CACHE_DIR="$ROOT/.cache"
DXMT_TAR="$CACHE_DIR/dxmt.tar.gz"
DXMT_DIR="$CACHE_DIR/dxmt-extracted"
DXMT_STORE="$CACHE_DIR/dxmt-installed"
SYS32="$WINEPREFIX/drive_c/windows/system32"
WINE_LIB="$GPTK_WINE_DIR/lib/wine"

if [[ "${1:-}" == "--undo" ]]; then
  echo "==> Removing DXMT"
  for f in d3d11.dll dxgi.dll d3d10core.dll winemetal.dll; do
    rm -f "$SYS32/$f" 2>/dev/null || true
  done
  rm -rf "$DXMT_STORE"
  rm -f "$WINE_LIB/x86_64-unix/winemetal.so" 2>/dev/null || true
  echo "Done. Game launches will use D3DMetal."
  exit 0
fi

echo "==> Installing DXMT $DXMT_VER (Steam-safe, launch-time activation)"
echo "    Prefix: $WINEPREFIX"
echo ""

require_gptk
require_prefix

mkdir -p "$CACHE_DIR" "$DXMT_DIR" "$DXMT_STORE" "$SYS32"

if [[ ! -f "$DXMT_TAR" ]]; then
  echo "Downloading DXMT $DXMT_VER (~18 MB)..."
  curl -fL "$DXMT_URL" -o "$DXMT_TAR" || { echo "Download failed" >&2; exit 1; }
fi

tar -xzf "$DXMT_TAR" -C "$DXMT_DIR" 2>/dev/null || tar -xf "$DXMT_TAR" -C "$DXMT_DIR"
DXMT_SRC="$DXMT_DIR/${DXMT_VER}"
[[ -d "$DXMT_SRC" ]] || { echo "Unexpected archive structure" >&2; exit 1; }

# Ensure global GPTK DLLs are D3DMetal (Steam UI depends on these).
BACKUP_DIR="$CACHE_DIR/d3dmetal-backup"
if [[ -d "$BACKUP_DIR/x86_64-windows" ]]; then
  echo "Ensuring global GPTK uses D3DMetal..."
  cp "$BACKUP_DIR/x86_64-windows/d3d11.dll"     "$WINE_LIB/x86_64-windows/d3d11.dll" 2>/dev/null || true
  cp "$BACKUP_DIR/x86_64-windows/dxgi.dll"      "$WINE_LIB/x86_64-windows/dxgi.dll" 2>/dev/null || true
  cp "$BACKUP_DIR/x86_64-windows/d3d10core.dll" "$WINE_LIB/x86_64-windows/d3d10core.dll" 2>/dev/null || true
fi
# Remove any leftover global winemetal.so from prior installs.
rm -f "$WINE_LIB/x86_64-unix/winemetal.so" 2>/dev/null || true

# Stage DXMT in project cache + prefix system32 (activated via WINEDLLOVERRIDES at game launch).
echo "Staging DXMT DLLs..."
cp "$DXMT_SRC/x86_64-windows/d3d11.dll"     "$SYS32/d3d11.dll"
cp "$DXMT_SRC/x86_64-windows/dxgi.dll"      "$SYS32/dxgi.dll"
cp "$DXMT_SRC/x86_64-windows/d3d10core.dll" "$SYS32/d3d10core.dll" 2>/dev/null || true
cp "$DXMT_SRC/x86_64-windows/winemetal.dll" "$SYS32/winemetal.dll"
cp "$DXMT_SRC/x86_64-unix/winemetal.so"     "$DXMT_STORE/winemetal.so"

echo ""
echo "DXMT installed (Steam-safe)."
echo "  winemetal.so staged in .cache — loaded only when launching the game."
echo "  Steam uses D3DMetal and should show its window normally."
echo "  Remove: bash scripts/setup-dxmt.sh --undo"
