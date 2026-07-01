#!/usr/bin/env bash
#
# One-screen health check for the MECCHA CHAMELEON Wine stack.
# Usage: bash scripts/doctor.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"
# shellcheck source=meccha-common.sh
source "$ROOT/scripts/meccha-common.sh"

pass(){ printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail(){ printf '  \033[31m✗\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

echo "MECCHA CHAMELEON — doctor"
echo "========================="

# Rosetta
if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then pass "Rosetta 2"; else fail "Rosetta 2 missing"; fi

# Wine
if [[ -x "$WINE_BIN" ]]; then
  pass "Wine: $(meccha_wine_version) at $WINE_APP"
  meccha_check_wine_version || warn "Wine version drift — preflight may rebuild DXMT"
else
  fail "Wine missing at $WINE_APP"
fi

# WoW64
wow64=0
[[ -d "$WINEPREFIX/drive_c/windows/syswow64" ]] \
  && wow64=$(find "$WINEPREFIX/drive_c/windows/syswow64" -maxdepth 1 | wc -l | tr -d ' ')
wow64=$((wow64 - 1))
if (( wow64 >= 100 )); then pass "WoW64 syswow64: $wow64 files"; else fail "WoW64 broken ($wow64) — bash scripts/fix-wow64-steam.sh --fix"; fi

# DXMT fork
d3d="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-windows/d3d11.dll"
winemac="$WINE_APP/Contents/Resources/wine/lib/wine/x86_64-unix/winemac.so"
if meccha_dxmt_fork_ready "$ROOT" "$WINE_APP"; then
  sz=$(stat -f%z "$d3d" 2>/dev/null || echo 0)
  pass "DXMT fork installed (${sz} byte d3d11.dll)"
elif [[ -f "$GAME_EXE" ]]; then
  fail "DXMT fork missing — game will crash on D3D11 startup"
  if meccha_has_xcode; then
    echo "       Run: bash scripts/build-dxmt-fork.sh  (~30–60 min)"
  else
    echo "       Install Xcode from the App Store, then: bash scripts/build-dxmt-fork.sh"
    echo "       (Command Line Tools alone cannot compile the Metal shader compiler.)"
  fi
elif [[ -f "$ROOT/.dxmt-fork-built" ]]; then
  fail "DXMT fork missing — bash scripts/build-dxmt-fork.sh"
else
  warn "DXMT fork not built — required before playing"
fi

# Game
if [[ -f "$GAME_EXE" ]]; then pass "Game installed"; else warn "Game not installed — use Steam once to download"; fi

# App
if [[ -d "$INSTALL_APP_DIR/MECCHA CHAMELEON.app" ]]; then pass "Dock app installed"; else fail "Run: bash scripts/install-meccha-app.sh"; fi

# Wrapper (quick)
wrapper_ok=0
if [[ -d "$NOTPOP/wrapper" ]]; then wrapper_ok=1; pass "CEF wrapper present"; else warn "notpop wrapper missing — bash install.sh"; fi

echo ""
echo "Quick fixes:"
echo "  bash scripts/preflight-launch.sh   # idle-week recovery"
echo "  bash scripts/launch-meccha.sh      # play"
echo "  bash scripts/launch-steam.sh       # Steam UI only (install/update)"
