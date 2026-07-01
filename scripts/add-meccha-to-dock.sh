#!/usr/bin/env bash
#
# Pin MECCHA CHAMELEON.app to the macOS Dock (stays after quit).
# Usage: bash scripts/add-meccha-to-dock.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"

APP="$INSTALL_APP_DIR/MECCHA CHAMELEON.app"
[[ -d "$APP" ]] || { echo "Run: bash scripts/install-meccha-app.sh" >&2; exit 1; }
APP="$(cd "$APP" && pwd)"

# Remove stale / duplicate tiles for this app (broken file:// entries don't stick).
python3 <<PY
import plistlib, os

app = """$APP"""
label = "MECCHA CHAMELEON"
plist_path = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")

with open(plist_path, "rb") as f:
    dock = plistlib.load(f)

apps = dock.get("persistent-apps", [])
filtered = []
for tile in apps:
    data = tile.get("tile-data", {})
    fd = data.get("file-data", {})
    url = fd.get("_CFURLString", "")
    bl = data.get("file-label", data.get("bundle-identifier", ""))
    if app in url or label in str(bl) or "meccha-chameleon" in str(bl).lower():
        continue
    filtered.append(tile)

filtered.append({
    "tile-data": {
        "file-data": {
            "_CFURLString": app,
            "_CFURLStringType": 0,
        }
    }
})
dock["persistent-apps"] = filtered

with open(plist_path, "wb") as f:
    plistlib.dump(dock, f)
PY

killall Dock 2>/dev/null || true
echo "Pinned MECCHA CHAMELEON to the Dock (persists after quit)."
open -R "$APP"
