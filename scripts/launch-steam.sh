#!/usr/bin/env bash
# Launch Steam via the working Wine 11 stack (notpop/steam-on-m1-wine).
# GPTK Wine 7.7 cannot boot modern Steam — this path uses Wine 11 + CEF wrapper.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"
ensure_notpop

export WINE_APP WINEPREFIX
exec bash "$NOTPOP/scripts/launch-steam.sh" --detach "$@"
