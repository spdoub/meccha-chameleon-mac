#!/usr/bin/env bash
#
# Export ~/.wine-steam for copying to another Mac (excludes game files).
# Usage: bash scripts/export-prefix.sh [output.tgz]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

OUT="${1:-$HOME/Desktop/wine-steam.tgz}"
/usr/bin/pkill -9 -f 'steam\.exe|wineserver' 2>/dev/null || true
sleep 1

echo "Creating $OUT (excluding steamapps game data)..."
tar -czf "$OUT" \
  --exclude='.wine-steam/drive_c/Program Files (x86)/Steam/steamapps/common' \
  --exclude='.wine-steam/drive_c/Program Files (x86)/Steam/steamapps/downloading' \
  --exclude='.wine-steam/drive_c/Program Files (x86)/Steam/steamapps/shadercache' \
  -C "$HOME" .wine-steam

ls -lh "$OUT"
echo "Copy to other Mac, then: bash scripts/bootstrap-mac.sh $OUT"
