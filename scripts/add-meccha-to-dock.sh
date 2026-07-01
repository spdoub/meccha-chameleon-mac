#!/usr/bin/env bash
#
# Pin MECCHA CHAMELEON.app to the macOS Dock.
# Usage: bash scripts/add-meccha-to-dock.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

APP="$INSTALL_APP_DIR/MECCHA CHAMELEON.app"
[[ -d "$APP" ]] || { echo "Run: bash scripts/install-meccha-app.sh" >&2; exit 1; }

APP_PATH="file://$(python3 -c "import pathlib, urllib.parse; print(urllib.parse.quote(str(pathlib.Path('$APP').resolve()), safe=':/'))")"

if defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "MECCHA CHAMELEON"; then
  echo "MECCHA CHAMELEON already in Dock preferences."
else
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${APP_PATH}/</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>MECCHA CHAMELEON</string></dict></dict>"
  killall Dock 2>/dev/null || true
  echo "Pinned MECCHA CHAMELEON to the Dock."
fi

open -R "$APP"
