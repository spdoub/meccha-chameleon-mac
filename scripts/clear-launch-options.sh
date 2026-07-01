#!/usr/bin/env bash
#
# Detect and remove Steam launch options that point directly at
# PenguinHotel-Win64-Shipping.exe (the CrossOver/Whisky "VC++ bypass" hack).
# That hack lets the game render but kills Steam/EOS authentication.
#
# Usage:
#   bash scripts/clear-launch-options.sh --check-only
#   bash scripts/clear-launch-options.sh --fix
#   bash scripts/clear-launch-options.sh --fix --set "-dx11"

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

MODE="check"
NEW_OPTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) MODE="check" ;;
    --fix) MODE="fix" ;;
    --set) shift; NEW_OPTS="${1:-}" ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

require_prefix

USERDATA="$WINEPREFIX/drive_c/Program Files (x86)/Steam/userdata"
if [[ ! -d "$USERDATA" ]]; then
  echo "No Steam userdata yet (log into Steam first)." >&2
  exit 1
fi

FOUND=0
while IFS= read -r -d '' vdf; do
  if grep -q "LaunchOptions" "$vdf" 2>/dev/null; then
    opts="$(grep -A0 '"LaunchOptions"' "$vdf" | head -1 || true)"
    if echo "$opts" | grep -qiE 'PenguinHotel|Win64-Shipping|Chameleon\\\\Binaries'; then
      FOUND=1
      echo "DIRECT_EXE_BYPASS"
      echo "File: $vdf"
      echo "Current: $opts"
      if [[ "$MODE" == "fix" ]]; then
        cp "$vdf" "${vdf}.bak.$(date +%Y%m%d%H%M%S)"
        # Remove the LaunchOptions block for this app (best-effort VDF edit).
        python3 - "$vdf" "$APP_ID" "$NEW_OPTS" <<'PY'
import re, sys
path, app_id, new_opts = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8", errors="replace").read()
pattern = rf'(\s*"{app_id}"\s*\{{[^}}]*?"LaunchOptions"\s*)".*?"'
if not re.search(pattern, text, re.DOTALL):
    print(f"No LaunchOptions for app {app_id} in {path}", file=sys.stderr)
    sys.exit(0)
if new_opts:
    repl = rf'\1"{new_opts}"'
else:
    # Delete LaunchOptions line entirely.
    repl = r'\1'
    text = re.sub(rf'(\s*"{app_id}"\s*\{{[^}}]*?)"LaunchOptions"\s*"[^"]*"\s*\n', r'\1', text, count=1, flags=re.DOTALL)
    open(path, "w", encoding="utf-8").write(text)
    print(f"Cleared LaunchOptions for app {app_id}")
    sys.exit(0)
text = re.sub(pattern, repl, text, count=1, flags=re.DOTALL)
open(path, "w", encoding="utf-8").write(text)
print(f"Set LaunchOptions for app {app_id} to: {new_opts or '(empty)'}")
PY
      fi
    fi
  fi
done < <(find "$USERDATA" -name localconfig.vdf -print0 2>/dev/null)

if [[ "$FOUND" -eq 0 ]]; then
  echo "OK: No direct Shipping.exe bypass in Steam launch options."
fi

# Also check shortcut VDF in steamapps
SHORTCUTS=$(find "$WINEPREFIX/drive_c/Program Files (x86)/Steam/userdata" -path "*/config/shortcuts.vdf" 2>/dev/null || true)
for sf in $SHORTCUTS; do
  if grep -qiE 'PenguinHotel|Win64-Shipping' "$sf" 2>/dev/null; then
    echo "NOTE: shortcuts.vdf references Shipping.exe — use Steam library Play, not a custom shortcut."
    echo "  $sf"
  fi
done
