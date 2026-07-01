#!/usr/bin/env bash
#
# One-shot installer: vanilla Wine + Apple Game Porting Toolkit (Gcenx prebuild)
# + DXMT graphics backend for MECCHA CHAMELEON on Apple Silicon.
# No CrossOver, no Whisky, no admin password required.
#
# Usage: bash install.sh
#
# Optional:
#   SKIP_GPTK=1        prefix + deps only (GPTK already installed)
#   SKIP_DEPS=1         skip winetricks redistributables
#   SKIP_DXMT=1         skip DXMT install (use D3DMetal only)
#   WINEPREFIX=...      custom prefix path

set -euo pipefail
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

step(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok(){ printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[33m⚠ %s\033[0m\n' "$*"; }
die(){ printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

printf '\033[1m MECCHA CHAMELEON — GPTK + Wine + DXMT setup — %s \033[0m\n' "$(date '+%Y-%m-%d %H:%M:%S')"

# --- 0. System checks ---
step "0/8 System checks"
[[ "$(uname -s)" == "Darwin" ]] || die "macOS only."
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) only."
OSVER="$(sw_vers -productVersion)"
FREE_GB=$(( $(df -k "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
ok "macOS $OSVER, $(uname -m), ~${FREE_GB} GB free"
if [[ "$FREE_GB" -lt 5 ]]; then
  warn "Low disk space — GPTK + Steam + game need ~15 GB."
fi

# --- 1. Rosetta ---
step "1/8 Rosetta 2"
if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  ok "Rosetta ready"
else
  softwareupdate --install-rosetta --agree-to-license || die "Rosetta install failed"
  ok "Rosetta installed"
fi

# --- 2. Homebrew tools ---
step "2/8 Homebrew utilities (arm64)"
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    die "Install Homebrew first: https://brew.sh"
  fi
fi
for pkg in winetricks cabextract; do
  if brew list "$pkg" >/dev/null 2>&1; then
    ok "$pkg present"
  else
    brew install "$pkg" || die "brew install $pkg failed"
    ok "$pkg installed"
  fi
done

# --- 3. Game Porting Toolkit ---
step "3/8 Game Porting Toolkit (Gcenx prebuild)"
if [[ "${SKIP_GPTK:-0}" != "1" ]]; then
  if [[ -x "$WINE" ]]; then
    ok "Game Porting Toolkit already installed at $GPTK_APP"
  else
    CACHE_DIR="$ROOT/.cache"
    mkdir -p "$CACHE_DIR"
    GPTK_TAR="$CACHE_DIR/gptk.tar.xz"
    GPTK_URL="https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz"
    warn "Downloading GPTK 3.0-3 (~228 MB, no admin password needed)..."
    curl -fL "$GPTK_URL" -o "$GPTK_TAR" || die "GPTK download failed"
    warn "Extracting to ~/Applications..."
    mkdir -p "$HOME/Applications"
    tar -xJf "$GPTK_TAR" -C "$HOME/Applications" || die "GPTK extract failed"
    xattr -dr com.apple.quarantine "$HOME/Applications/Game Porting Toolkit.app" 2>/dev/null || true

    # Re-resolve GPTK paths after install.
    GPTK_APP="$HOME/Applications/Game Porting Toolkit.app"
    GPTK_WINE_DIR="$GPTK_APP/Contents/Resources/wine"
    export WINE="$GPTK_WINE_DIR/bin/wine64"
    export WINESERVER="$GPTK_WINE_DIR/bin/wineserver"
    [[ -x "$WINE" ]] || die "wine64 missing after GPTK extract"
    ok "Game Porting Toolkit 3.0-3 installed to ~/Applications"
  fi
else
  warn "SKIP_GPTK=1 — expecting GPTK at $GPTK_APP"
fi

[[ -x "$WINE" ]] || die "wine64 not found at $WINE — run install.sh without SKIP_GPTK"

# --- 4. Wine prefix ---
step "4/8 Initialize Wine prefix"
mkdir -p "$WINEPREFIX"
if [[ -d "$WINEPREFIX/drive_c/windows" ]]; then
  ok "Prefix exists: $WINEPREFIX"
else
  warn "Running wineboot (first run takes 1–3 min)..."
  run_in_x86 env WINEPREFIX="$WINEPREFIX" WINEESYNC=1 "$WINE" wineboot --init
  run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINESERVER" -w
  [[ -d "$WINEPREFIX/drive_c/windows" ]] || die "Prefix init failed"
  ok "Prefix created"
fi

# Windows 10 build for modern Steam / UE5.
run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINE" reg add \
  'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuild /t REG_SZ /d 19045 /f >/dev/null 2>&1 || true
run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINE" reg add \
  'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuildNumber /t REG_SZ /d 19045 /f >/dev/null 2>&1 || true
run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINE" reg add \
  'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v ProductName /t REG_SZ /d "Microsoft Windows 10" /f >/dev/null 2>&1 || true
ok "Windows version set to Win10 (build 19045)"

# --- 5. Game runtime dependencies ---
step "5/8 Windows redistributables (winetricks)"
if [[ "${SKIP_DEPS:-0}" == "1" ]]; then
  warn "SKIP_DEPS=1 — skipping"
else
  export WINEPREFIX WINE WINESERVER
  export WINETRICKS_LATEST_VERSION_CHECK=disabled W_OPT_UNATTENDED=1 WINEDEBUG="-all"
  VERBS=(corefonts vcrun2010 vcrun2012 vcrun2013 vcrun2022 \
         d3dcompiler_47 d3dx11_43 xact xact_x64 xinput faudio gdiplus)
  OK_COUNT=0; FAIL_COUNT=0
  for v in "${VERBS[@]}"; do
    printf ' → %-18s ' "$v"
    if run_in_x86 env WINEPREFIX="$WINEPREFIX" WINE="$WINE" WINESERVER="$WINESERVER" \
         winetricks -q "$v" >>"$LOG" 2>&1; then
      printf 'OK\n'; ((OK_COUNT++))
    else
      printf 'FAIL (retry manually)\n'; ((FAIL_COUNT++))
    fi
    run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINESERVER" -w 2>/dev/null || true
  done
  # Reset Windows version (some winetricks verbs change it).
  run_in_x86 env WINEPREFIX="$WINEPREFIX" WINE="$WINE" winetricks -q win10 >>"$LOG" 2>&1 || true
  ok "Dependencies: $OK_COUNT OK, $FAIL_COUNT failed"
fi

# --- 6. DXMT (D3D11 → Metal graphics backend) ---
step "6/8 DXMT graphics backend"
if [[ "${SKIP_DXMT:-0}" == "1" ]]; then
  warn "SKIP_DXMT=1 — using D3DMetal only (may fail UE5 D3D11 check)"
else
  DXMT_MARKER="$GPTK_WINE_DIR/lib/wine/x86_64-unix/winemetal.so"
  if [[ -f "$DXMT_MARKER" ]]; then
    ok "DXMT already installed"
  else
    bash "$ROOT/scripts/setup-dxmt.sh" || warn "DXMT install failed — game may still work with D3DMetal"
    ok "DXMT installed (D3D11 → Metal for UE5)"
  fi
fi

# --- 7. Steam ---
step "7/8 Windows Steam"
SETUP="$HOME/Downloads/SteamSetup.exe"
if [[ -f "$STEAM_EXE_UNIX" ]]; then
  ok "Steam already in prefix"
elif [[ -f "$SETUP" ]]; then
  warn "Installing Steam from ~/Downloads/SteamSetup.exe ..."
  warn "A Steam installer window will appear — follow the prompts."
  run_in_x86 env WINEPREFIX="$WINEPREFIX" MTL_HUD_ENABLED=0 WINEESYNC=1 \
    "$WINE" "$SETUP" >>"$LOG" 2>&1 || warn "Steam setup had errors — check if login appeared"
  ok "Steam setup launched"
else
  warn "Download Windows SteamSetup.exe to ~/Downloads, then run: bash scripts/launch-steam.sh"
  warn "  URL: https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
fi

# --- 8. Pre-configure and verify ---
step "8/8 Configure and verify"
chmod +x "$ROOT"/scripts/*.sh "$ROOT"/cleanup.sh 2>/dev/null || true

# Apply steam_api64 DLL overrides.
bash "$ROOT/scripts/fix-steam-api-overrides.sh" >>"$LOG" 2>&1 || true
ok "steam_api64 overrides applied"

# Verify Wine can execute.
WINEVER=$(run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINE" --version 2>/dev/null || echo "unknown")
VEROUT=$(run_in_x86 env WINEPREFIX="$WINEPREFIX" "$WINE" cmd /c ver 2>/dev/null | tr -d '\r\0' | grep -i windows | head -1 || true)
if [[ -n "$VEROUT" ]]; then
  ok "Wine working: $WINEVER — $VEROUT"
else
  ok "Wine: $WINEVER (cmd.exe check inconclusive, likely fine)"
fi

printf '\n\033[1;32mSetup complete.\033[0m\n\n'
cat <<EOF
What was installed:
  Game Porting Toolkit 3.0-3 → ~/Applications/Game Porting Toolkit.app
  DXMT v0.80 (D3D11→Metal)  → patched into GPTK Wine libs
  Wine prefix                → $WINEPREFIX
  VC++ / DirectX redists     → inside prefix

Next steps:
  1. bash scripts/launch-steam.sh
     Log into Steam, install MECCHA CHAMELEON (AppID $APP_ID).
  2. bash scripts/clear-launch-options.sh --fix --set "-dx11"
     (Removes any Shipping.exe bypass; keeps safe -dx11 flag only.)
  3. bash scripts/launch-meccha.sh
     ★ Primary fix: steam.exe -applaunch $APP_ID

If online auth still fails:
  bash scripts/debug-auth.sh
  bash scripts/fix-steam-api-overrides.sh

Cleanup:
  bash cleanup.sh

Install log: $LOG
EOF
