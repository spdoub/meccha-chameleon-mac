#!/usr/bin/env bash
#
# Install VC++ / DirectX deps into the Wine 11 Steam prefix.
# Run after Steam + game are installed (or anytime — safe to re-run).

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

[[ -d "$WINEPREFIX/drive_c" ]] || { echo "Prefix missing — run install.sh first." >&2; exit 1; }

export WINE="$WINE_BIN"
export WINESERVER="$WINESERVER"
export WINEDEBUG=-all
export W_OPT_UNATTENDED=1
export WINETRICKS_LATEST_VERSION_CHECK=disabled

echo "==> Installing VC++ 2022 + core deps into $WINEPREFIX"
/usr/bin/arch -x86_64 env WINEPREFIX="$WINEPREFIX" WINE="$WINE" WINESERVER="$WINESERVER" \
  winetricks -q vcrun2022 vcrun2019 corefonts 2>&1 | tail -5
/usr/bin/arch -x86_64 env WINEPREFIX="$WINEPREFIX" "$WINESERVER" -w 2>/dev/null || true
echo "Done."
