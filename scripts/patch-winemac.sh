#!/usr/bin/env bash
#
# Rebuild Wine 11 winemac.so with -fvisibility=default so DXMT can dlsym
# macdrv Metal APIs. Required for UE5's D3D11 Feature Level 11.0 check.
#
# One-time ~5 min build; idempotent after that.

set -euo pipefail

WINE_APP="${WINE_APP:-$HOME/Applications/Wine Stable.app}"
WINE_BUILD_SRC="${WINE_BUILD_SRC:-$HOME/dev/wine-build/wine}"
WINE_BUILD_BRANCH="${WINE_BUILD_BRANCH:-wine-11.0}"
WINE_UNIX="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix"
INSTALLED="$WINE_UNIX/winemac.so"

export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:${PATH:-}"

if nm -gU "$INSTALLED" 2>/dev/null | rg -q "macdrv_view_create_metal_view"; then
  echo "winemac.so already patched ($(nm -gU "$INSTALLED" | rg 'macdrv_' | wc -l | tr -d ' ') macdrv symbols)."
  exit 0
fi

echo "==> Building patched winemac.so (DXMT needs exported macdrv symbols)"

if [[ ! -d "$WINE_BUILD_SRC/.git" ]]; then
  mkdir -p "$(dirname "$WINE_BUILD_SRC")"
  git clone --branch "$WINE_BUILD_BRANCH" --depth 1 \
    https://gitlab.winehq.org/wine/wine.git "$WINE_BUILD_SRC"
fi

rm -rf "$WINE_BUILD_SRC/build"
mkdir -p "$WINE_BUILD_SRC/build"
(
  cd "$WINE_BUILD_SRC/build"
  arch -x86_64 env \
    CC="clang -target x86_64-apple-macosx" \
    CXX="clang++ -target x86_64-apple-macosx" \
    PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/freetype/lib/pkgconfig" \
    ../configure \
      --enable-win64 \
      --disable-tests \
      --without-freetype \
      CFLAGS='-fvisibility=default -O2 -Wno-error' \
      CXXFLAGS='-fvisibility=default -O2 -Wno-error'
)

ncpu=$(sysctl -n hw.logicalcpu)
arch -x86_64 make -C "$WINE_BUILD_SRC/build" -j"$ncpu" dlls/winemac.drv/winemac.so

BUILT="$WINE_BUILD_SRC/build/dlls/winemac.drv/winemac.so"
[[ -f "$BUILT" ]] || { echo "Build failed — see $WINE_BUILD_SRC/build" >&2; exit 1; }

[[ -f "${INSTALLED}.gcenx-backup" ]] || cp "$INSTALLED" "${INSTALLED}.gcenx-backup"
cp "$BUILT" "$INSTALLED"
echo "Installed patched winemac.so ($(nm -gU "$INSTALLED" | rg 'macdrv_' | wc -l | tr -d ' ') macdrv symbols)"
