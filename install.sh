#!/usr/bin/env bash
#
# One-shot installer for MECCHA CHAMELEON on Apple Silicon (Wine 11 stack).
# Reproduces the full working setup on a fresh Mac from this GitHub repo.
#
# Usage:
#   git clone https://github.com/spdoub/meccha-chameleon-mac.git ~/Games/meccha-chameleon-gptk
#   cd ~/Games/meccha-chameleon-gptk
#   bash install.sh
#
# Optional:
#   SKIP_DXMT_FORK=1     Steam UI only (~15 min); add graphics later with build-dxmt-fork.sh
#   SKIP_STEAM=1         Skip downloading Windows Steam (prefix + Wine only)
#   SKIP_DOCK=1          Do not pin Dock icons

set -euo pipefail
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=scripts/wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

step(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok(){ printf '\033[32m✓ %s\033[0m\n' "$*"; }
die(){ printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

printf '\033[1m MECCHA CHAMELEON — Wine 11 installer — %s \033[0m\n' "$(date '+%Y-%m-%d %H:%M:%S')"

# --- 0. System ---
step "System checks"
[[ "$(uname -s)" == "Darwin" ]] || die "macOS only."
[[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]] || die "Apple Silicon only."
if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then ok "Rosetta ready"; else
  softwareupdate --install-rosetta --agree-to-license || die "Rosetta install failed"
  ok "Rosetta installed"
fi
command -v brew >/dev/null 2>&1 || eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || die "Install Homebrew: https://brew.sh"

# --- 1. Homebrew tools ---
step "Homebrew packages"
for pkg in winetricks cabextract python@3.11 git curl; do
  brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
  ok "$pkg"
done

# --- 2. notpop/steam-on-m1-wine (Wine 11 + Steam bootstrap) ---
step "Wine 11 + Steam stack (notpop/steam-on-m1-wine)"
ensure_notpop
export WINE_APP INSTALL_APP_DIR WINEPREFIX

NOTPOP_STEPS=(
  scripts/00-prereqs.sh
  scripts/01-install-wine.sh
  scripts/02-setup-prefix.sh
)
if [[ "${SKIP_STEAM:-0}" != "1" ]]; then
  NOTPOP_STEPS+=(scripts/03-install-steam.sh)
fi
NOTPOP_STEPS+=(
  scripts/04-install-dxmt.sh
  scripts/05-fix-ssl.sh
  scripts/06-install-wrapper.sh
)

for s in "${NOTPOP_STEPS[@]}"; do
  step "$(basename "$s")"
  bash "$NOTPOP/$s" || die "$s failed"
done
ok "Steam stack ready at $WINEPREFIX"

# --- 3. Graphics (DXMT + winemac) ---
step "winemac.so patch (DXMT Metal API export)"
bash "$ROOT/scripts/patch-winemac.sh"

if [[ "${SKIP_DXMT_FORK:-0}" != "1" ]]; then
  step "DXMT fork build (~30–60 min first run)"
  bash "$ROOT/scripts/build-dxmt-fork.sh"
else
  ok "Skipped DXMT fork (SKIP_DXMT_FORK=1) — run: bash scripts/build-dxmt-fork.sh"
fi

# --- 4. Prefix deps (after Steam exists) ---
if [[ "${SKIP_STEAM:-0}" != "1" ]]; then
  step "VC++ redistributables"
  bash "$ROOT/scripts/install-prefix-deps.sh"
fi

# --- 5. macOS apps + Dock ---
step "macOS launcher apps"
bash "$NOTPOP/scripts/09-install-macos-app.sh" || true
PIN_DOCK=1 bash "$ROOT/scripts/install-meccha-app.sh"
if [[ "${SKIP_DOCK:-0}" != "1" ]]; then
  bash "$NOTPOP/scripts/10-add-to-dock.sh" 2>/dev/null || true
fi

# --- Done ---
step "Install complete"
cat <<EOF

Next steps on this Mac:
  1. Open "Steam on M1 Wine" from ~/Applications (or Dock)
  2. Log in and install MECCHA CHAMELEON from your library
  3. Click "MECCHA CHAMELEON" in the Dock to play

Launch manually:
  bash scripts/launch-meccha.sh

Logs: $LOG_DIR/
Prefix: $WINEPREFIX
Wine:   $WINE_APP

EOF
