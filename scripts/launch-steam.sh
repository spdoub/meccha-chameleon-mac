#!/usr/bin/env bash
# Launch Steam via the working Wine 11 stack (notpop/steam-on-m1-wine).
# GPTK Wine 7.7 cannot boot modern Steam — this path uses Wine 11 + CEF wrapper.

set -euo pipefail

NOTPOP="$HOME/Games/steam-on-m1-wine"
if [[ ! -d "$NOTPOP" ]]; then
  echo "Wine 11 Steam stack not found. Running setup..."
  git clone --depth 1 https://github.com/notpop/steam-on-m1-wine.git "$NOTPOP"
fi

exec bash "$NOTPOP/scripts/launch-steam.sh" --detach "$@"
