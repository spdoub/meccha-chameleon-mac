#!/usr/bin/env bash
#
# Install DXMT (D3D11 → Metal) into the GPTK Wine environment.
# MECCHA CHAMELEON is UE5 / D3D11. GPTK's D3DMetal may report
# "A D3D11-compatible GPU is required" — DXMT fixes this.
#
# Downloads DXMT v0.80 (builtin build) from 3Shain/dxmt and places
# the DLLs into GPTK's Wine lib directory + the prefix's system32.
#
# Usage:
#   bash scripts/setup-dxmt.sh          # install DXMT
#   bash scripts/setup-dxmt.sh --undo   # revert to D3DMetal

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

DXMT_VER="v0.80"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/${DXMT_VER}/dxmt-${DXMT_VER}-builtin.tar.gz"
CACHE_DIR="$ROOT/.cache"
DXMT_TAR="$CACHE_DIR/dxmt.tar.gz"
DXMT_DIR="$CACHE_DIR/dxmt-extracted"

WINE_LIB="$GPTK_WINE_DIR/lib/wine"
BACKUP_DIR="$CACHE_DIR/d3dmetal-backup"
SYS32="$WINEPREFIX/drive_c/windows/system32"

if [[ "${1:-}" == "--undo" ]]; then
  echo "==> Reverting DXMT → D3DMetal"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "No backup found at $BACKUP_DIR — nothing to revert." >&2
    exit 1
  fi
  for f in d3d11.dll dxgi.dll d3d10core.dll; do
    [[ -f "$BACKUP_DIR/x86_64-windows/$f" ]] && cp "$BACKUP_DIR/x86_64-windows/$f" "$WINE_LIB/x86_64-windows/$f" 2>/dev/null || true
    [[ -f "$BACKUP_DIR/i386-windows/$f" ]] && cp "$BACKUP_DIR/i386-windows/$f" "$WINE_LIB/i386-windows/$f" 2>/dev/null || true
  done
  [[ -f "$BACKUP_DIR/x86_64-unix/winemetal.so" ]] && rm -f "$WINE_LIB/x86_64-unix/winemetal.so" 2>/dev/null || true
  rm -f "$SYS32/winemetal.dll" 2>/dev/null || true
  echo "Reverted. D3DMetal is now active."
  exit 0
fi

echo "==> Installing DXMT $DXMT_VER (D3D11 → Metal)"
echo "    GPTK Wine: $GPTK_WINE_DIR"
echo "    Prefix:    $WINEPREFIX"
echo ""

require_gptk

mkdir -p "$CACHE_DIR" "$DXMT_DIR"

# Download if not cached.
if [[ ! -f "$DXMT_TAR" ]]; then
  echo "Downloading DXMT $DXMT_VER (~18 MB)..."
  curl -fL "$DXMT_URL" -o "$DXMT_TAR" || { echo "Download failed" >&2; exit 1; }
fi

# Extract.
tar -xzf "$DXMT_TAR" -C "$DXMT_DIR" 2>/dev/null || tar -xf "$DXMT_TAR" -C "$DXMT_DIR"
DXMT_SRC="$DXMT_DIR/${DXMT_VER}"
[[ -d "$DXMT_SRC" ]] || { echo "Unexpected archive structure" >&2; ls -R "$DXMT_DIR" >&2; exit 1; }

echo "Backing up original D3DMetal DLLs..."
mkdir -p "$BACKUP_DIR/x86_64-windows" "$BACKUP_DIR/x86_64-unix" "$BACKUP_DIR/i386-windows"
for f in d3d11.dll dxgi.dll d3d10core.dll; do
  cp "$WINE_LIB/x86_64-windows/$f" "$BACKUP_DIR/x86_64-windows/$f" 2>/dev/null || true
  cp "$WINE_LIB/i386-windows/$f" "$BACKUP_DIR/i386-windows/$f" 2>/dev/null || true
done

echo "Installing DXMT into GPTK Wine lib..."

# Builtin build: DLLs go into Wine's lib dirs (no DLL override needed).
# x86_64 (primary — game is 64-bit)
cp "$DXMT_SRC/x86_64-windows/d3d11.dll"     "$WINE_LIB/x86_64-windows/d3d11.dll"
cp "$DXMT_SRC/x86_64-windows/dxgi.dll"      "$WINE_LIB/x86_64-windows/dxgi.dll"
cp "$DXMT_SRC/x86_64-windows/d3d10core.dll" "$WINE_LIB/x86_64-windows/d3d10core.dll" 2>/dev/null || true
cp "$DXMT_SRC/x86_64-windows/winemetal.dll" "$WINE_LIB/x86_64-windows/winemetal.dll"
cp "$DXMT_SRC/x86_64-windows/nvapi64.dll"   "$WINE_LIB/x86_64-windows/nvapi64.dll" 2>/dev/null || true

# i386 (Steam client itself is 32-bit)
cp "$DXMT_SRC/i386-windows/d3d11.dll"       "$WINE_LIB/i386-windows/d3d11.dll" 2>/dev/null || true
cp "$DXMT_SRC/i386-windows/dxgi.dll"        "$WINE_LIB/i386-windows/dxgi.dll" 2>/dev/null || true
cp "$DXMT_SRC/i386-windows/d3d10core.dll"   "$WINE_LIB/i386-windows/d3d10core.dll" 2>/dev/null || true
cp "$DXMT_SRC/i386-windows/winemetal.dll"   "$WINE_LIB/i386-windows/winemetal.dll" 2>/dev/null || true

# Unix side (winemetal.so — the Metal bridge)
cp "$DXMT_SRC/x86_64-unix/winemetal.so"     "$WINE_LIB/x86_64-unix/winemetal.so"

# Also place winemetal.dll in the prefix's system32 (required by DXMT runtime).
mkdir -p "$SYS32"
cp "$DXMT_SRC/x86_64-windows/winemetal.dll" "$SYS32/winemetal.dll"

echo ""
echo "DXMT $DXMT_VER installed."
echo "  Backup at: $BACKUP_DIR"
echo "  Revert:    bash scripts/setup-dxmt.sh --undo"
echo ""
echo "NOTE: This is a builtin build — no DLL override env vars needed."
echo "      DXMT replaces D3DMetal's D3D11 path. D3D12 still uses D3DMetal."
echo ""
echo "COMPATIBILITY: GPTK's Wine is based on Wine 7.7. DXMT officially targets"
echo "Wine 8+. If DXMT causes crashes, revert to D3DMetal (which supports D3D11"
echo "natively in GPTK 3.0+):"
echo "  bash scripts/setup-dxmt.sh --undo"
echo ""
echo "Next: bash scripts/launch-meccha.sh"
