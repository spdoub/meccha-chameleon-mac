#!/usr/bin/env bash
# Shared helpers for MECCHA launch, doctor, and bootstrap scripts.

meccha_notify() {
  /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true
}

meccha_detect_display_size() {
  local bounds width height
  bounds=$(/usr/bin/osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)
  if [[ "$bounds" =~ ,[[:space:]]*([0-9]+),[[:space:]]*([0-9]+)$ ]]; then
    width="${BASH_REMATCH[1]}"
    height="${BASH_REMATCH[2]}"
    if [[ "$width" -gt 0 && "$height" -gt 0 ]]; then
      echo "${width}x${height}"
      return 0
    fi
  fi
  echo "1440x900"
}

meccha_kill_prefix() {
  local prefix="${1:-$WINEPREFIX}"
  local wineserver="${2:-$WINESERVER}"
  if [[ -x "$wineserver" ]]; then
    WINEPREFIX="$prefix" "$wineserver" -k 2>/dev/null || true
    sleep 2
  fi
  local patterns='steam\.exe|steamwebhelper|steamservice|wineserver|wine64-preloader|winedevice|explorer\.exe'
  local to_kill
  to_kill=$(/usr/bin/pgrep -f "$patterns" 2>/dev/null || true)
  if [[ -n "$to_kill" ]]; then
    # shellcheck disable=SC2086
    /bin/kill -9 $to_kill 2>/dev/null || true
    sleep 2
  fi
}

meccha_build_game_flags() {
  local flags="${GAME_FLAGS:--dx11 -force-d3d11-no-singlethreaded}"
  if [[ "${MECCHA_FULLSCREEN:-0}" == "1" ]]; then
    flags="$flags -screen-fullscreen 1"
  else
    flags="$flags -screen-fullscreen 0"
  fi
  echo "$flags"
}

meccha_focus_wine() {
  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  repeat with p in (every process whose name contains "wine")
    try
      set frontmost of p to true
      repeat with w in (every window of p)
        try
          perform action "AXRaise" of w
        end try
      end repeat
    end try
  end repeat
end tell
APPLESCRIPT
}

meccha_latest_crash() {
  find "$WINEPREFIX/drive_c/users" -path '*/Chameleon/Saved/Crashes/*/*.xml' 2>/dev/null \
    | /usr/bin/xargs /bin/ls -t 2>/dev/null | head -n1
}

meccha_report_crash() {
  local log="${1:-$LOG_DIR/meccha-launch.log}"
  local crash
  crash=$(meccha_latest_crash)
  if [[ -n "$crash" && -f "$crash" ]]; then
    {
      echo ""
      echo "=== Latest crash report: $crash ==="
      /usr/bin/head -80 "$crash"
    } >>"$log"
    meccha_notify "MECCHA CHAMELEON" "Game crashed — see logs/meccha-launch.log"
  fi
}

meccha_remove_steam_from_dock() {
  /usr/bin/python3 <<'PY'
import plistlib, os, subprocess

plist_path = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")
steam_markers = ("Steam on M1 Wine", "Wine Stable", "wine-stable")

with open(plist_path, "rb") as f:
    dock = plistlib.load(f)

apps = dock.get("persistent-apps", [])
filtered = []
removed = 0
for tile in apps:
    data = tile.get("tile-data", {})
    fd = data.get("file-data", {})
    url = fd.get("_CFURLString", "")
    label = str(data.get("file-label", ""))
    if any(m in url or m in label for m in steam_markers):
        removed += 1
        continue
    filtered.append(tile)

if removed:
    dock["persistent-apps"] = filtered
    with open(plist_path, "wb") as f:
        plistlib.dump(dock, f)
    subprocess.run(["killall", "Dock"], check=False)
PY
}

meccha_wine_version() {
  /usr/bin/arch -x86_64 "$WINE_BIN" --version 2>/dev/null | /usr/bin/head -n1 || echo "unknown"
}

meccha_check_wine_version() {
  local current known_file="$PROJECT_ROOT/.known-wine-version"
  current=$(meccha_wine_version)
  if [[ ! -f "$known_file" ]]; then
    echo "$current" >"$known_file"
    return 0
  fi
  local known
  known=$(/bin/cat "$known_file")
  if [[ "$current" != "$known" ]]; then
    echo "WARN: Wine changed ($known -> $current). Run: bash scripts/preflight-launch.sh" >&2
    echo "      To pin: brew pin wine-stable  (after install)" >&2
    return 1
  fi
  return 0
}
