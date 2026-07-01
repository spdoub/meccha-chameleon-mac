#!/usr/bin/env bash
#
# Bootstrap MECCHA CHAMELEON on a new Mac.
# Auto-detects a prefix tarball or runs fresh install.
#
# Usage:
#   bash scripts/bootstrap-mac.sh
#   bash scripts/bootstrap-mac.sh ~/Downloads/wine-steam.tgz

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

TARBALL="${1:-}"
if [[ -z "$TARBALL" ]]; then
  for candidate in \
    "$HOME/Desktop/wine-steam.tgz" \
    "$HOME/Downloads/wine-steam.tgz" \
    "$HOME/wine-steam.tgz"; do
    [[ -f "$candidate" ]] && TARBALL="$candidate" && break
  done
fi

echo "==> MECCHA CHAMELEON bootstrap"

if [[ -n "$TARBALL" && -f "$TARBALL" ]]; then
  echo "Found prefix backup: $TARBALL"
  /usr/bin/pkill -9 -f 'steam\.exe|wineserver' 2>/dev/null || true
  rm -rf "$WINEPREFIX"
  echo "Extracting prefix (~1–3 min)..."
  tar -xzf "$TARBALL" -C "$HOME"
  echo "Prefix restored to $WINEPREFIX"
  bash "$ROOT/install.sh"
else
  echo "No wine-steam.tgz found — running full install."
  bash "$ROOT/install.sh"
fi

bash "$ROOT/scripts/doctor.sh"
