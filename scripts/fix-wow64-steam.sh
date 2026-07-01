#!/usr/bin/env bash
#
# Diagnose and repair broken WoW64 (32-bit Windows) support in the Wine prefix.
# Steam's installer and bootstrap are 32-bit PE; without syswow64 populated,
# they fail with: wine: could not load kernel32.dll, status c0000135
#
# Usage:
#   bash scripts/fix-wow64-steam.sh          # diagnose only
#   bash scripts/fix-wow64-steam.sh --fix   # recreate prefix + retry Steam install

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

info(){ printf '\033[34m→ %s\033[0m\n' "$*"; }
ok(){ printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[33m! %s\033[0m\n' "$*"; }
fail(){ printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

resolve_wine_app() {
  local candidate
  for candidate in \
    "${WINE_APP:-}" \
    "$HOME/Applications/Wine Stable.app" \
    "/Applications/Wine Stable.app"; do
    [[ -n "$candidate" && -x "$candidate/Contents/Resources/wine/bin/wine" ]] || continue
    printf '%s' "$candidate"
    return 0
  done
  return 1
}

WINE_APP="$(resolve_wine_app)" || fail "Wine Stable.app not found. Run: brew install --cask wine-stable"
WINE_BIN="$WINE_APP/Contents/Resources/wine/bin/wine"
export WINE_APP WINE_BIN WINEPREFIX

I386_DIR="$WINE_APP/Contents/Resources/wine/lib/wine/i386-windows"
SYSWOW64="$WINEPREFIX/drive_c/windows/syswow64"

info "Wine app     : $WINE_APP"
info "Wine version : $(arch -x86_64 "$WINE_BIN" --version 2>&1 || echo unknown)"
info "WINEPREFIX   : $WINEPREFIX"

if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  fail "Rosetta 2 is not available. Run: softwareupdate --install-rosetta --agree-to-license"
fi
ok "Rosetta 2 OK"

if [[ ! -d "$I386_DIR" ]]; then
  fail "Missing i386-windows in Wine bundle ($I386_DIR). Reinstall: brew reinstall --cask wine-stable"
fi
i386_count=$(find "$I386_DIR" -maxdepth 1 -name '*.dll' | wc -l | tr -d ' ')
if (( i386_count < 100 )); then
  fail "Wine bundle looks incomplete ($i386_count i386 DLLs). Reinstall: brew reinstall --cask wine-stable"
fi
ok "Wine bundle has $i386_count i386-windows DLLs"

if ! pkgutil --pkgs | grep -q org.freedesktop.gstreamer; then
  warn "GStreamer.framework may be missing (required by wine-stable)."
  warn "Install: https://gstreamer.freedesktop.org/download/ — universal pkg, all users."
fi

# Prefer ~/Applications so DXMT / winemac patches stay in one place.
if [[ "$WINE_APP" == "/Applications/Wine Stable.app" && ! -d "$HOME/Applications/Wine Stable.app" ]]; then
  info "Linking Wine into ~/Applications (matches install.sh / patch-winemac.sh)"
  mkdir -p "$HOME/Applications"
  ln -sf "/Applications/Wine Stable.app" "$HOME/Applications/Wine Stable.app"
  WINE_APP="$HOME/Applications/Wine Stable.app"
  WINE_BIN="$WINE_APP/Contents/Resources/wine/bin/wine"
  export WINE_APP WINE_BIN
  ok "Linked $WINE_APP → /Applications/Wine Stable.app"
fi

if xattr -l "$WINE_APP" 2>/dev/null | grep -q com.apple.quarantine; then
  warn "Quarantine xattr on Wine — stripping (Gatekeeper exit 137 otherwise)"
  xattr -dr com.apple.quarantine "$WINE_APP"
  ok "Quarantine cleared"
fi

wow64_count=0
if [[ -d "$SYSWOW64" ]]; then
  wow64_count=$(find "$SYSWOW64" -maxdepth 1 | wc -l | tr -d ' ')
  wow64_count=$((wow64_count - 1))
fi
info "syswow64 entries: $wow64_count (expect 800+)"

test_prefix="$HOME/.wine-wow64-smoke-$$"
cleanup_test() { rm -rf "$test_prefix"; }
trap cleanup_test EXIT

info "Smoke test: fresh WINEARCH=win64 prefix"
pkill -9 -f wineserver 2>/dev/null || true
WINEPREFIX="$test_prefix" WINEARCH=win64 WINEDEBUG=-all \
  arch -x86_64 "$WINE_BIN" wineboot -i >/dev/null 2>&1 \
  || fail "wineboot -i failed on smoke prefix — Wine install is broken on this Mac"
smoke_count=$(find "$test_prefix/drive_c/windows/syswow64" -maxdepth 1 | wc -l | tr -d ' ')
smoke_count=$((smoke_count - 1))
if (( smoke_count < 100 )); then
  fail "WoW64 smoke test failed (syswow64=$smoke_count). Try: brew install --cask wine@staging"
fi
ok "Smoke prefix syswow64: $smoke_count files — Wine WoW64 works on this hardware"

if (( wow64_count >= 100 )); then
  ok "Existing prefix syswow64 looks populated"
  info "If Steam still fails, the prefix may be corrupt — re-run with --fix"
  exit 0
fi

warn "Existing prefix has empty/broken syswow64 — Steam cannot run until this is fixed"

if [[ "$FIX" != "1" ]]; then
  cat <<EOF

To recreate the prefix and reinstall Steam (destructive — removes $WINEPREFIX):

  bash scripts/fix-wow64-steam.sh --fix

Or copy a working prefix from your first Mac (fastest if install already succeeded there):

  # On working Mac:
  tar -czf ~/wine-steam-prefix.tgz -C ~ .wine-steam \\
    --exclude='.wine-steam/drive_c/Program Files (x86)/Steam/steamapps'

  # On this Mac (after scp):
  rm -rf ~/.wine-steam
  tar -xzf ~/wine-steam-prefix.tgz -C ~
  bash install.sh   # re-run from step 4 onward (DXMT, wrapper, apps)

EOF
  exit 1
fi

info "Stopping Wine processes"
pkill -9 -f 'wineserver|wine64-preloader|steam\.exe' 2>/dev/null || true
sleep 1

STEAM_BACKUP=""
if [[ -d "$WINEPREFIX/drive_c/Program Files (x86)/Steam" ]]; then
  STEAM_BACKUP="${TMPDIR:-/tmp}/steam-backup-$$"
  info "Backing up existing Steam tree to $STEAM_BACKUP"
  cp -a "$WINEPREFIX/drive_c/Program Files (x86)/Steam" "$STEAM_BACKUP/"
fi

info "Removing broken prefix: $WINEPREFIX"
rm -rf "$WINEPREFIX"

info "Creating fresh win64 prefix (WINEARCH=win64 wineboot -i)"
export WINEARCH=win64
WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all \
  arch -x86_64 "$WINE_BIN" wineboot -i

wow64_count=$(find "$SYSWOW64" -maxdepth 1 | wc -l | tr -d ' ')
wow64_count=$((wow64_count - 1))
(( wow64_count >= 100 )) || fail "Prefix recreate failed (syswow64=$wow64_count)"

if [[ -n "$STEAM_BACKUP" ]]; then
  info "Restoring Steam tree from backup"
  mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)"
  cp -a "$STEAM_BACKUP" "$WINEPREFIX/drive_c/Program Files (x86)/Steam"
  rm -rf "$STEAM_BACKUP"
else
  info "Running notpop Steam install"
  ensure_notpop
  export WINE_APP WINEPREFIX WINEARCH=win64
  bash "$NOTPOP/scripts/02-setup-prefix.sh"
  bash "$NOTPOP/scripts/03-install-steam.sh"
fi

ok "Prefix repaired (syswow64=$wow64_count). Launch Steam:"
echo "  bash scripts/launch-steam.sh"
echo "  # or re-run: bash install.sh  (idempotent from DXMT onward)"
