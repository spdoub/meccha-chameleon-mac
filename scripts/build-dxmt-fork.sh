#!/usr/bin/env bash
#
# Build and install the notpop/dxmt fork (UE5 present-path fixes).
# Includes workarounds discovered on macOS 26 / GCC 16 / Meson 1.10.1.
#
# Usage: bash scripts/build-dxmt-fork.sh
# Env:   WINE_APP, WINEPREFIX, DXMT_SRC, DXMT_VENV (see wine11-env.sh)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"
# shellcheck source=meccha-common.sh
source "$ROOT/scripts/meccha-common.sh"

PATCH_DIR="$ROOT/patches"
LLVM_PREFIX="$DXMT_SRC/toolchains/llvm"
WINE_TOOLCHAIN="$DXMT_SRC/toolchains/wine"
MARKER="$ROOT/.dxmt-fork-built"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[32m✓ %s\033[0m\n' "$*"; }
die(){ printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

[[ -x "$WINE_BIN" ]] || die "Wine 11 not found at $WINE_BIN — run install.sh first."

if ! meccha_has_xcode; then
  die "Full Xcode required (App Store). Command Line Tools alone cannot build the DXMT Metal shader compiler."
fi

if [[ -f "$MARKER" ]] && [[ -f "$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-windows/d3d11.dll" ]]; then
  sz=$(stat -f%z "$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-windows/d3d11.dll" 2>/dev/null || echo 0)
  if (( sz > 10000000 )); then
    ok "DXMT fork already installed (d3d11.dll ${sz} bytes)"
    exit 0
  fi
fi

export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:$PATH"

# --- Meson 1.10.1 in Python 3.11 venv (Meson 1.11+ breaks DXMT; Py 3.14 breaks Meson 1.10) ---
log "Meson toolchain"
PY311="$(command -v python3.11 || true)"
[[ -n "$PY311" ]] || { brew install python@3.11 || die "Install python@3.11: brew install python@3.11"; PY311="$(command -v python3.11)"; }
if [[ ! -x "$DXMT_VENV/bin/meson" ]]; then
  "$PY311" -m venv "$DXMT_VENV"
  "$DXMT_VENV/bin/pip" install -q 'meson==1.10.1' ninja
fi
MESON="$DXMT_VENV/bin/meson"
NINJA="$DXMT_VENV/bin/ninja"

# Patch Meson 1.10.1 cpp_importstd KeyError (github.com/mesonbuild/meson/issues/15497)
MESON_NINJA="$DXMT_VENV/lib/python3.11/site-packages/mesonbuild/backend/ninjabackend.py"
if [[ -f "$MESON_NINJA" ]] && grep -q "cpp_importstd' not in self.environment" "$MESON_NINJA"; then
  MESON_NINJA="$MESON_NINJA" python3.11 <<'PY'
import os
from pathlib import Path
p = Path(os.environ["MESON_NINJA"])
text = p.read_text()
old = """    def target_uses_import_std(self, target: build.BuildTarget) -> bool:
        if 'cpp' not in target.compilers:
            return False
        if 'cpp_importstd' not in self.environment.coredata.optstore:
            return False
        if self.environment.coredata.get_option_for_target(target, 'cpp_importstd') == 'false':
            return False
        return True"""
new = """    def target_uses_import_std(self, target: build.BuildTarget) -> bool:
        if 'cpp' not in target.compilers:
            return False
        try:
            if self.environment.coredata.get_option_for_target(target, 'cpp_importstd') == 'true':
                return True
        except KeyError:
            return False
        return False"""
if old in text:
    p.write_text(text.replace(old, new))
PY
  ok "Patched Meson cpp_importstd handling"
fi

# --- DXMT source ---
log "DXMT fork source"
if [[ ! -d "$DXMT_SRC/.git" ]]; then
  git clone --branch debug/present-path-tracing --depth 1 \
    https://github.com/notpop/dxmt.git "$DXMT_SRC"
else
  git -C "$DXMT_SRC" fetch origin debug/present-path-tracing --depth 1 2>/dev/null || true
  git -C "$DXMT_SRC" checkout debug/present-path-tracing 2>/dev/null || true
fi
git -C "$DXMT_SRC" submodule update --init --recursive

# GCC 16: missing <iomanip> in com_guid.cpp
if [[ -f "$PATCH_DIR/dxmt-com-guid-iomanip.patch" ]]; then
  git -C "$DXMT_SRC" checkout -- src/util/com/com_guid.cpp 2>/dev/null || true
  patch -d "$DXMT_SRC" -p1 -N < "$PATCH_DIR/dxmt-com-guid-iomanip.patch" || true
fi

# --- LLVM 15 x86_64 (no zstd — avoids link errors on winemetal.so) ---
log "LLVM 15 for DXMT shader compiler"
LLVM_SRC="$DXMT_SRC/toolchains/llvm-src"
if [[ ! -f "$LLVM_PREFIX/lib/libLLVMCore.a" ]]; then
  log "Building LLVM 15 (~20–40 min first run)..."
  [[ -d "$LLVM_SRC/.git" ]] || git clone --branch llvmorg-15.0.7 --depth 1 \
    https://github.com/llvm/llvm-project.git "$LLVM_SRC"
  cmake -S "$LLVM_SRC/llvm" -B "$LLVM_SRC/build" \
    -DLLVM_ENABLE_PROJECTS="" \
    -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_BUILD_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    "-DCMAKE_OSX_ARCHITECTURES=x86_64" \
    "-DCMAKE_INSTALL_PREFIX=$LLVM_PREFIX"
  cmake --build "$LLVM_SRC/build" -j"$(sysctl -n hw.logicalcpu)"
  cmake --install "$LLVM_SRC/build"
else
  if [[ -f "$LLVM_SRC/build/lib/Support/libLLVMSupport.a" ]] && \
     nm "$LLVM_PREFIX/lib/libLLVMSupport.a" 2>/dev/null | grep -q ZSTD_compress; then
    log "Rebuilding LLVMSupport without zstd..."
    cmake -S "$LLVM_SRC/llvm" -B "$LLVM_SRC/build" -DLLVM_ENABLE_ZSTD=OFF 2>/dev/null || true
    cmake --build "$LLVM_SRC/build" --target LLVMSupport -j"$(sysctl -n hw.logicalcpu)"
    cmake --install "$LLVM_SRC/build" --component LLVMSupport 2>/dev/null || cmake --install "$LLVM_SRC/build"
  fi
  ok "LLVM 15 present"
fi

# --- 3Shain Wine toolchain for DXMT link ---
log "Wine toolchain for DXMT build"
TC="$DXMT_SRC/toolchains"
mkdir -p "$TC"
if [[ ! -x "$WINE_TOOLCHAIN/bin/winebuild" ]]; then
  if [[ ! -f "$TC/wine.tar.gz" ]]; then
    curl -fL -o "$TC/wine.tar.gz" \
      https://github.com/3Shain/wine/releases/download/v8.16-3shain/wine.tar.gz
  fi
  rm -rf "$TC/wine" "$TC/bin" "$TC/lib" "$TC/include" "$TC/share" 2>/dev/null || true
  tar -xzf "$TC/wine.tar.gz" -C "$TC"
  if [[ -x "$TC/bin/winebuild" && ! -d "$TC/wine" ]]; then
    mkdir -p "$TC/wine"
    mv "$TC/bin" "$TC/lib" "$TC/include" "$TC/share" "$TC/wine/"
  fi
  [[ -x "$WINE_TOOLCHAIN/bin/winebuild" ]] || die "winebuild missing after toolchain extract"
fi
ok "Wine toolchain ready"

# --- Build DXMT ---
log "Compiling DXMT fork (64-bit + 32-bit)"
cd "$DXMT_SRC"
rm -rf build build32
arch -arm64 env MESON="$MESON" "$MESON" setup \
  --cross-file build-win64.txt \
  -Dnative_llvm_path=toolchains/llvm \
  -Dwine_install_path=toolchains/wine \
  build --buildtype release
arch -arm64 env MESON="$MESON" "$MESON" compile -C build
arch -arm64 env MESON="$MESON" "$MESON" setup \
  --cross-file build-win32.txt \
  -Dwine_install_path=toolchains/wine \
  build32 --buildtype release
arch -arm64 env MESON="$MESON" "$MESON" compile -C build32

# --- Stage into Wine + prefix (same layout as notpop 07-build-dxmt-fork.sh step 8) ---
log "Installing DXMT fork into Wine"
WINE_UNIX="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix"
WINE_WIN64="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-windows"
WINE_WIN32="$WINE_APP/Contents/Resources/wine/lib/wine/i386-windows"
PREFIX_SYS32="$WINEPREFIX/drive_c/windows/system32"
PREFIX_SYSWOW64="$WINEPREFIX/drive_c/windows/syswow64"

install_file() { cp "$1" "$2"; }

install_file "$DXMT_SRC/build/src/winemetal/unix/winemetal.so" "$WINE_UNIX/winemetal.so"
for dll in d3d11.dll dxgi.dll d3d10core.dll winemetal.dll; do
  case "$dll" in
    d3d11.dll) s64="$DXMT_SRC/build/src/d3d11/d3d11.dll"; s32="$DXMT_SRC/build32/src/d3d11/d3d11.dll" ;;
    dxgi.dll) s64="$DXMT_SRC/build/src/dxgi/dxgi.dll"; s32="$DXMT_SRC/build32/src/dxgi/dxgi.dll" ;;
    d3d10core.dll) s64="$DXMT_SRC/build/src/d3d10/d3d10core.dll"; s32="$DXMT_SRC/build32/src/d3d10/d3d10core.dll" ;;
    winemetal.dll) s64="$DXMT_SRC/build/src/winemetal/winemetal.dll"; s32="$DXMT_SRC/build32/src/winemetal/winemetal.dll" ;;
  esac
  install_file "$s64" "$WINE_WIN64/$dll"
  install_file "$s32" "$WINE_WIN32/$dll"
done
mkdir -p "$PREFIX_SYS32" "$PREFIX_SYSWOW64"
for dll in d3d11.dll dxgi.dll d3d10core.dll winemetal.dll; do
  cp "$WINE_WIN64/$dll" "$PREFIX_SYS32/$dll"
  cp "$WINE_WIN32/$dll" "$PREFIX_SYSWOW64/$dll" 2>/dev/null || true
done

touch "$MARKER"
ok "DXMT fork installed — UE5 rendering should work"
ok "Marker: $MARKER"
